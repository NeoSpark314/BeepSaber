extends Node

signal failed_request()
signal search_complete(videos)

onready var search_request_ = $SearchRequest

const DEBUG_SEARCH = false
func search(search_text: String):
	if DEBUG_SEARCH:
		var result_data = _get_search_result_data_from_html_file()
		var videos = _get_videos_from_search_result(result_data)
		emit_signal("search_complete",videos)
		return
	
	var search_query = search_text.replace(' ','+')
	var res = search_request_.request(
		'https://www.youtube.com/results?search_query=%s' % search_query)
	if res == OK:
		pass
	else:
		vr.log_error('Failed to request YouTube search for text "%s"' % search_text)
		emit_signal("failed_request")

func _get_videos_from_search_file():
	var file = File.new()
	var videos = []
	if file.open('youtube_search.json', File.READ) == OK:
		var json = JSON.parse(file.get_as_text())
		if json.error == OK:
			videos = _get_videos_from_search_result(json.result)
		else:
			vr.log_error('Failed to parse YouTube search JSON')
			emit_signal("failed_request")
		
		file.close()
		
	return videos
	
func _get_search_result_data_from_html_file():
	var file = File.new()
	var search_results = {}
	if file.open('youtube_search.html', File.READ) == OK:
		var html_text = file.get_as_text()
		search_results = _get_search_result_data_from_html(html_text)
		
		file.close()
	else:
		vr.log_error('failed to open file')
		
	return search_results
	
const YT_INIT_DATA_TEXT = "var ytInitialData = "
func _get_search_result_data_from_html(html_text: String):
	var search_results = {}
	var init_data_idx = html_text.find(YT_INIT_DATA_TEXT)
	var start_idx = init_data_idx + YT_INIT_DATA_TEXT.length()
	var end_idx = html_text.find("</script>", init_data_idx) - 1
	var result_str = html_text.substr(start_idx,(end_idx-start_idx))
	var json = JSON.parse(result_str)
	if json.error == OK:
		search_results = json.result
	else:
		emit_signal("failed_request")
		vr.log_error("failed to parse search result JSON")
		
	return search_results
		
func _get_videos_from_search_result(search_result):
	var videos = []
	for content in search_result['contents']['twoColumnSearchResultsRenderer']['primaryContents']['sectionListRenderer']['contents']:
		if content.has('itemSectionRenderer'):
			var videos_content = content['itemSectionRenderer']['contents']
			for v_content in videos_content:
				if ! v_content.has('videoRenderer'):
					continue
				videos.append(v_content['videoRenderer'])
			break
	return videos

func _on_SearchRequest_request_completed(result, response_code, headers, body):
	var okay = true
	
	if response_code == HTTPClient.RESPONSE_OK:
		var html_text = body.get_string_from_utf8()
		var result_data = _get_search_result_data_from_html(html_text)
		var videos = _get_videos_from_search_result(result_data)
		emit_signal("search_complete",videos)
	else:
		vr.log_error('search result return error code %d' % response_code)
		okay = false
		
	if ! okay:
		emit_signal("failed_request")
