extends Panel

export (NodePath) var youtube_ui

onready var beatsage_request_ := $BeatSageRequest
onready var song_url := $SongURL

onready var difficulty_normal := $DifficultyNormal
onready var difficulty_hard := $DifficultyHard
onready var difficulty_expert := $DifficultyExpert
onready var difficulty_expert_plus := $DifficultyExpertPlus

onready var mode_standard := $ModeStandard
onready var mode_no_arrows := $ModeNoArrows
onready var mode_one_saber := $ModeOneSaber

onready var events_bombs := $EventsBombs
onready var events_dot_block := $EventsDotBlocks
onready var events_obstacles := $EventsObstacles

onready var model_select := $ModelButton

const MODELS = {
	"V2" : "v2",
	"V2-Flow (Better flow, less creative)" : "v2-flow"
}

func _ready():
	youtube_ui = get_node(youtube_ui)
	
	model_select.clear()
	for key in MODELS.keys():
		model_select.add_item(key)

func _on_SubmitButton_pressed():
	var difficulties = ""
	if difficulty_normal.pressed:
		difficulties += ",Normal"
	if difficulty_hard.pressed:
		difficulties += ",Hard"
	if difficulty_expert.pressed:
		difficulties += ",Expert"
	if difficulty_expert_plus.pressed:
		difficulties += ",ExpertPlus"
	if difficulties.length() > 0:
		difficulties = difficulties.substr(1)
		
	var modes = ""
	if mode_standard.pressed:
		modes += ",Standard"
	if mode_no_arrows.pressed:
		modes += ",NoArrows"
	if mode_one_saber.pressed:
		modes += ",OneSaber"
	if modes.length() > 0:
		modes = modes.substr(1)
		
	var events = ""
	if events_bombs.pressed:
		events += ",Bombs"
	if events_dot_block.pressed:
		events += ",DotBlocks"
	if events_obstacles.pressed:
		events += ",Obstacles"
	if events.length() > 0:
		events = events.substr(1)
	
	# build request dictionary
	var request_data = {
		"youtube_url": song_url.text,
		"audio_metadata_title": "Test Song %d" % randi(),
		"audio_metadata_artist": "Test Artist",
		"difficulties": difficulties,
		"modes": modes,
		"events": events,
		"environment": "DefaultEnvironment",
		"system_tag": MODELS[model_select.text],
	}
	
	# initial beatsaber request
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

func _on_YoutubeButton_pressed():
	if is_instance_valid(youtube_ui):
		youtube_ui.visible = true
