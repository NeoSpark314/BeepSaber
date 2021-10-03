extends Control

onready var api := $YouTubeAPI
onready var search_line_edit := $SearchLineEdit
onready var search_button := $SearchButton

func _on_SearchButton_pressed():
	var search_text = search_line_edit.text
	api.search(search_text)
	search_button.disabled = true

func _on_YouTubeAPI_failed_request():
	search_button.disabled = false
	vr.log_error('Search failed!')

func _on_YouTubeAPI_search_complete(videos):
	search_button.disabled = false
	print('found %d search result(s)' % videos.size())
