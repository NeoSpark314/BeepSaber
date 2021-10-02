extends Control

onready var beatsage_request_ := $BeatSageRequest

func _on_SubmitButton_pressed():
	var request_data = {
		"youtube_url": "https://www.youtube.com/watch?v=iqJKohK2f8g",
		"audio_metadata_title": "Heartbreak Anthem",
		"audio_metadata_artist": "Galantis, David Guetta, Little Mix",
		"difficulties": "Hard,Expert,Normal,ExpertPlus",
		"modes": "Standard",
		"events": "DotBlocks",
		"environment": "DefaultEnvironment",
		"system_tag": "v2",
	}
	if beatsage_request_.request(request_data):
		$SubmitButton.disabled = true

func _on_BeatSageRequest_download_complete(filepath):
	print('download complete!')
	$SubmitButton.disabled = false

func _on_BeatSageRequest_heartbeat():
	print('BeatSage heartbeat...')

func _on_BeatSageRequest_request_failed():
	vr.log_error("BeatSage request failed!")
	$SubmitButton.disabled = false
