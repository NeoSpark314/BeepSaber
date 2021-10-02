extends Node

signal heartbeat()
signal download_complete(filepath)
signal request_failed()

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
onready var heartbeat_timer_ := $HeartbeatTimer

# request heartbeat from BeatSage every couple seconds when song is processing
# Note: BeatSage website itself seems to use ~3s request rate so we will too
const HEARTBEAT_PERIOD = 3

var state_ = State.eIdle
var request_id_ = null

func _ready():
	_transition_state(State.eIdle)

func request(request_data):
	var okay = true
	var data_to_send = '--boundary\nContent-Disposition: form-data; name="youtube_url"\n\nhttps://www.youtube.com/watch?v=uD4SrW5m8NE\n--boundary\nContent-Disposition: form-data; name="audio_metadata_title"\n\nHeartbreak Anthem\n--boundary\nContent-Disposition: form-data; name="audio_metadata_artist"\n\nGalantis, David Guetta, Little Mix\n--boundary\nContent-Disposition: form-data; name="difficulties"\n\nHard,Expert,Normal,ExpertPlus\n--boundary\nContent-Disposition: form-data; name="modes"\n\nStandard\n--boundary\nContent-Disposition: form-data; name="events"\n\nDotBlocks\n--boundary\nContent-Disposition: form-data; name="environment"\n\nDefaultEnvironment\n--boundary\nContent-Disposition: form-data; name="system_tag"\n\nv2\n--boundary--'
	var headers = ["Content-Type: multipart/form-data; boundary=boundary"]
	
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

func _transition_state(next_state):
	match (next_state):
		State.eIdle:
			heartbeat_timer_.stop()
			request_id_ = null
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
		var zippath = "beatsage_download.zip"
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

func _on_HeartbeatTimer_timeout():
	var okay = true
	
	emit_signal("heartbeat")
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
