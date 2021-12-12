extends Node

signal progress_update(progress, max_progress)
signal download_complete(filepath)
signal request_failed()
signal youtube_metadata_available(metadata)
signal youtube_metadata_request_failed()

enum State {
	# Idle:
	# ready for a new create request
	eIdle,
	# Requested:
	# sent create request, and waiting for response from BeatSage
	# response should contain JSON {"id":"<request_id>"} if successful
	eRequested,
	# Pending:
	# BeatSage is processing the custom song. We periodically send heartbeat
	# requests to see the current status.
	ePending,
	# Downloading:
	# BeatSage finished processing the custom song and we can now download it.
	# We'll exit this state once we finish download the song data.
	eDownloading
}

onready var create_request_ := $CreateRequest
onready var heartbeat_request_ := $HeartbeatRequest
onready var download_request_ := $DownloadRequest
onready var youtube_metadata_request_ := $YouTubeMetadataRequest
onready var heartbeat_timer_ := $HeartbeatTimer

# request heartbeat from BeatSage every couple seconds when song is processing
# Note: BeatSage website itself seems to use ~3s request rate so we will too
const HEARTBEAT_PERIOD = 3

var state_ = State.eIdle
var request_id_ = null
var download_dir = ""

# the name of the zip file for the current request
# Note: cleared once return back to idle state
var _zip_filename = ""

# seconds into song processing
var _progress = 0
# for now assume 2mins max for processing time
var _progress_max = 120

func _ready():
	_transition_state(State.eIdle)

func request_custom_level(request_obj):
	var okay = true
	var data_to_send = _build_request_data(request_obj)
	var headers = ["Content-Type: multipart/form-data; boundary=boundary"]
	_zip_filename = _get_zipname(request_obj)
	# sanatize filepath
	_zip_filename = _zip_filename.replace('/','')
	
	# initiate request
	var res = create_request_.request(
		"https://beatsage.com/beatsaber_custom_level_create",
		headers,
		false,# use ssl
		HTTPClient.METHOD_POST,
		data_to_send)
		
	# check response
	if res != HTTPRequest.RESULT_SUCCESS:
		vr.log_error("Failed to request Beat Sage custom level")
		okay = false
	
	# perform state transition
	if okay:
		_transition_state(State.eRequested)
	else:
		emit_signal("request_failed")
		_transition_state(State.eIdle)
	
	return okay
	
func request_youtube_metadata(youtube_url):
	var okay = true
	var data_to_send = '{"youtube_url": "%s"}' % youtube_url
	var headers = ["Content-Type: text/plain;charset=UTF-8"]
	
	# initiate request
	var res = youtube_metadata_request_.request(
		"https://beatsage.com/youtube_metadata",
		headers,
		false,# use ssl
		HTTPClient.METHOD_POST,
		data_to_send)
		
	# check response
	if res != HTTPRequest.RESULT_SUCCESS:
		vr.log_error("Failed to request youtube metadata")
		okay = false
	
	if ! okay:
		emit_signal("youtube_metadata_request_failed")
	
	return okay
	
func cancel_custom_level_request():
	create_request_.cancel_request()
	heartbeat_request_.cancel_request()
	download_request_.cancel_request()
	heartbeat_timer_.stop()
	_transition_state(State.eIdle)
	
func cancel_youtube_metadata_request():
	youtube_metadata_request_.cancel_request()

func _get_zipname(request_obj):
	var filename = "BeatSage_"
	filename += request_obj['audio_metadata_title'] + " - "
	filename += request_obj['audio_metadata_artist'] + " ("
	filename += request_obj['system_tag'] + " "
	
	for diff in request_obj['difficulties'].split(','):
		if diff == "Hard":
			filename += 'H'
		elif diff == "Expert":
			filename += 'E'
		elif diff == "Normal":
			filename += 'N'
		elif diff == "ExpertPlus":
			filename += 'E+'
	filename += ','
	
	for mode in request_obj['modes'].split(','):
		if mode == 'Standard':
			filename += 'S'
		elif mode == 'NoArrows':
			filename += 'N'
		elif mode == 'OneSaber':
			filename += 'O'
	filename += ','
	
	for event in request_obj['events'].split(','):
		if event == 'DotBlocks':
			filename += 'D'
		elif event == 'Obstacles':
			filename += 'O'
		elif event == 'Bombs':
			filename += 'B'
	filename += ').zip'
	
	return filename

func _build_request_data(request_obj):
	var request_data = ""
	for key in request_obj.keys():
		var value = request_obj[key]
		request_data += "--boundary\n"
		request_data += 'Content-Disposition: form-data; name="%s"\n\n' % key
		request_data += '%s\n' % str(value)
	
	request_data += "--boundary--\n"
	
	return request_data

func _transition_state(next_state):
	match (next_state):
		State.eIdle:
			heartbeat_timer_.stop()
			request_id_ = null
			_zip_filename = ""
			_progress = 0
		State.eRequested:
			heartbeat_timer_.stop()
		State.ePending:
			heartbeat_timer_.start(HEARTBEAT_PERIOD)# kick off heartbeat requests
		State.eDownloading:
			heartbeat_timer_.stop()

func _on_CreateRequest_request_completed(result, response_code, headers, body):
	var okay = true
	
	if response_code == HTTPClient.RESPONSE_OK:
		var res_str = body.get_string_from_utf8()
		var json = JSON.parse(res_str)
		if json.error == OK:
			var json_res = json.result
			if json_res.has('id'):
				request_id_ = json_res['id']
			else:
				vr.log_error("No BeatSage response id received!")
				print(json_res)
				okay = false;
		else:
			vr.log_error("Received JSON error %s" % json.error)
			okay = false;
	else:
		vr.log_error("Received server error from BeatSage create custom song request!")
		print('result = %s' % result)
		print('response_code = %s' % response_code)
		print('headers = %s' % headers)
		print('body = %s' % body)
		okay = false
		
	# perform state transition
	if okay:
		_transition_state(State.ePending)
	else:
		emit_signal("request_failed")
		_transition_state(State.eIdle)
		
	return okay

func _on_HeartbeatRequest_request_completed(result, response_code, headers, body):
	var song_ready = false
	var okay = true
	
	# handle results
	if response_code == HTTPClient.RESPONSE_OK:
		var res_str = body.get_string_from_utf8()
		var json = JSON.parse(res_str)
		if json.error == OK:
			var json_res = json.result
			if json_res.has('status'):
				var status = json_res['status']
				if status == "PENDING":
					# keep waiting...
					pass
				elif status == "DONE":
					song_ready = true
				else:
					vr.log_error('Received unexpected heartbeat status "%s"!' % status)
					okay = false
			else:
				vr.log_error("Received unexpected heartbeat response from BeatSage!")
				print(json_res)
				okay = false;
		else:
			vr.log_error("Received JSON error %s" % json.error)
			okay = false;
	else:
		vr.log_error("Received server error from BeatSage heartbeat request!")
		print('result = %s' % result)
		print('response_code = %s' % response_code)
		print('headers = %s' % headers)
		print('body = %s' % body)
		okay = false
	
	# handle transitions
	if okay && ! song_ready:
		# song isn't ready yet, so schedule another heartbeat request
		heartbeat_timer_.start(HEARTBEAT_PERIOD)
	elif okay && song_ready:
		# request download of custom song
		var res = download_request_.request(
			'http://beatsage.com/beatsaber_custom_level_download/%s' % request_id_)
			
		# check response
		if res == HTTPRequest.RESULT_SUCCESS:
			_transition_state(State.eDownloading)
		else:
			vr.log_error("Failed to request download for request_id_ %s" % request_id_)
			okay = false
	
	if ! okay:
		emit_signal("request_failed")
		_transition_state(State.eIdle)
		
	return okay

func _on_DownloadRequest_request_completed(result, response_code, headers, body):
	var okay = true
	
	if response_code == HTTPClient.RESPONSE_OK:
		# store downloaded song data
		var zippath = download_dir + _zip_filename
		var file = File.new()
		if file.open(zippath,File.WRITE) == OK:
			file.store_buffer(body)
			file.close()
			emit_signal("download_complete",zippath)
		else:
			vr.log_error(
				"Failed to save song zip to '%s'" % zippath)
			okay = false
	else:
		vr.log_error("Received server error from BeatSage download request!")
		print('result = %s' % result)
		print('response_code = %s' % response_code)
		print('headers = %s' % headers)
		print('body = %s' % body)
		okay = false
		
	if ! okay:
		emit_signal("request_failed")
		
	_transition_state(State.eIdle)

func _on_YouTubeMetadataRequest_request_completed(result, response_code, headers, body):
	var song_ready = false
	var okay = true
	
	# handle results
	if response_code == HTTPClient.RESPONSE_OK:
		var res_str = body.get_string_from_utf8()
		var json = JSON.parse(res_str)
		if json.error == OK:
			var json_res = json.result
			emit_signal("youtube_metadata_available", json_res)
		else:
			vr.log_error("Received JSON error %s" % json.error)
			okay = false;
	else:
		vr.log_error("Received server error from youtube metadata request!")
		print('result = %s' % result)
		print('response_code = %s' % response_code)
		print('headers = %s' % headers)
		print('body = %s' % body.get_string_from_utf8())
		okay = false
		
	if ! okay:
		emit_signal("youtube_metadata_request_failed")

func _on_HeartbeatTimer_timeout():
	var okay = true
	
	# notify caller of progress being made
	_progress += HEARTBEAT_PERIOD
	_progress = min(_progress, _progress_max)# saturate to max
	emit_signal("progress_update", _progress, _progress_max)
	
	# request another heartbeat from server
	var res = heartbeat_request_.request(
		'http://beatsage.com/beatsaber_custom_level_heartbeat/%s' % request_id_)
	
	# check response
	if res != HTTPRequest.RESULT_SUCCESS:
		vr.log_error("Failed to request BeatSage heartbeat for request_id_ %s" % request_id_)
		okay = false
	
	if ! okay:
		emit_signal("request_failed")
		_transition_state(State.eIdle)
		
	return okay
