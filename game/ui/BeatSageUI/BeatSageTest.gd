extends Control

onready var beatsage_request_ := $BeatSageRequest

func _on_SubmitButton_pressed():
	# TODO fill this out
	var request_data = {}
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
