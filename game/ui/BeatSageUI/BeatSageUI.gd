extends Panel

export (NodePath) var youtube_ui

onready var beatsage_request_ := $BeatSageRequest
onready var song_url := $SongURL

onready var song_artist := $SongArtist
onready var song_name := $SongName

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

onready var progress_screen := $ProgressScreen
onready var progress_bar := $ProgressScreen/ProgressBar
onready var submit_button := $SubmitButton

const MODELS = {
	"V2" : "v2",
	"V2-Flow (Better flow, less creative)" : "v2-flow"
}

# TODO move these to a shared constants location
const BS_TEMP_DIR = "/sdcard/BeepSaber/temp/"
const BS_SONG_DIR = "/sdcard/BeepSaber/Songs/"

func _ready():
	beatsage_request_.download_dir = BS_TEMP_DIR;
	
	# setup youtube search UI and connect signal handlers
	youtube_ui = get_node(youtube_ui)
	if is_instance_valid(youtube_ui):
		youtube_ui.connect("song_selected",self,"_on_youtube_song_selected")
	
	model_select.clear()
	for key in MODELS.keys():
		model_select.add_item(key)

# override hide() method to handle case where UI is inside a OQ_UI2DCanvas
func hide():
	var parent_canvas = self
	while parent_canvas != null:
		if parent_canvas is OQ_UI2DCanvas:
			break
		parent_canvas = parent_canvas.get_parent()
		
	if parent_canvas == null:
		self.visible = false
	else:
		parent_canvas.hide()
		
# override show() method to handle case where UI is inside a OQ_UI2DCanvas
func show():
	var parent_canvas = self
	while parent_canvas != null:
		if parent_canvas is OQ_UI2DCanvas:
			break
		parent_canvas = parent_canvas.get_parent()
		
	if parent_canvas == null:
		self.visible = true
	else:
		parent_canvas.show()

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
		"audio_metadata_title": song_name.text,
		"audio_metadata_artist": song_artist.text,
		"difficulties": difficulties,
		"modes": modes,
		"events": events,
		"environment": "DefaultEnvironment",
		"system_tag": MODELS[model_select.text],
	}
	
	# initial beatsaber request
	if beatsage_request_.request_custom_level(request_data):
		submit_button.disabled = true
		progress_bar.value = 0
		progress_screen.show()

func _on_BeatSageRequest_download_complete(filepath):
	var okay = true
	submit_button.disabled = false
	progress_screen.hide()
	
	var dir = Directory.new()
	var song_dir_name = filepath.get_basename().get_file()
	var song_out_dir = BS_SONG_DIR + song_dir_name + '/'
	var error = dir.make_dir_recursive(song_out_dir)
	if error != OK: 
		vr.log_error(
			"_on_BeatSageRequest_download_complete - " +
			"Failed to create song output dir '%s'" % song_out_dir)
		okay = false
	
	var Unzip = load('res://addons/gdunzip/unzip.gd').new()
	if okay:
		error = Unzip.unzip(filepath,song_out_dir)
		
	dir.remove(filepath)

func _on_BeatSageRequest_request_failed():
	vr.log_error("BeatSage request failed!")
	submit_button.disabled = false
	progress_screen.hide()

func _on_BeatSageRequest_progress_update(progress, max_progress):
	progress_bar.value = progress
	progress_bar.max_value = max_progress

func _on_BeatSageRequest_youtube_metadata_available(metadata):
	var artist = 'Unknown Artist'
	if metadata.has('artist'):
		artist = metadata['artist']
	song_artist.text = artist
	
	var track = 'Unknown Title'
	if metadata.has('track'):
		track = metadata['track']
	song_name.text = track

func _on_BeatSageRequest_youtube_metadata_request_failed():
	pass # Replace with function body.

func _on_YoutubeButton_pressed():
	if is_instance_valid(youtube_ui):
		youtube_ui.show()

# emitted by the YouTube search dialog when the player selects a video
func _on_youtube_song_selected(video_metadata):
	var video_url = "https://www.youtube.com/watch?v=%s" % video_metadata['id']
	song_url.text = video_url
	
	beatsage_request_.request_youtube_metadata(video_url)

func _on_BackButton_pressed():
	self.hide()

func _on_CancelButton_pressed():
	beatsage_request_.cancel_custom_level_request()
	progress_screen.hide()
	submit_button.disabled = false

func _on_SongURL_text_entered(new_text):
	beatsage_request_.request_youtube_metadata(new_text)
