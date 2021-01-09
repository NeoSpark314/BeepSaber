extends Panel
class_name HighscorePanel

signal close()

export var show_close_button = true

# keep a copy of the base row for regeneration later
onready var _base_row = $Margin/VBox/LeftRight/ScrollContainer/Margin/HighscoresList/BaseRecordRow.duplicate()
onready var _highscore_list = $Margin/VBox/LeftRight/ScrollContainer/Margin/HighscoresList
onready var _title = $Margin/VBox/Title
onready var _song_info = $Margin/VBox/LeftRight/VBox/SongInfo_Label
onready var _exit_button = $Margin/VBox/Exit_Button

func _ready():
	_clear_list()
	_exit_button.visible = show_close_button

func load_highscores(map_info,diff_rank):
	# clear the high score list
	_clear_list()
	
	# populate title text
	set_title("Highscores (%s)" % _get_difficulty_name(map_info,diff_rank))
	
	# populate song info
	_song_info.text = """Artist: %s
		Song: %s
		Map Author: %s""" % [map_info._songAuthorName, map_info._songName, map_info._levelAuthorName]
		
	# TODO populate song artwork
		
	var records = Highscores.get_records(map_info,diff_rank)
	var idx = 1
	for record in records:
		# build a new row and populate fields from record
		var new_row = _base_row.duplicate()
		new_row.get_child(0).text = "%d." % idx
		new_row.get_child(1).text = record.player_name
		new_row.get_child(2).text = str(record.score)
		
		_highscore_list.add_child(new_row)
		idx += 1
		
func set_title(title_text):
	_title.text = title_text
	
# clears all rows from the highscore table
func _clear_list():
	for c in _highscore_list.get_children():
		c.queue_free()
	
func _get_difficulty_name(map_info,diff_rank):
	if map_info.has('_difficultyBeatmapSets'):
		for beat_sets in map_info._difficultyBeatmapSets:
			for beat_map in beat_sets._difficultyBeatmaps:
				if beat_map._difficultyRank == diff_rank:
					return beat_map._difficulty
	return 'Rank %s' % diff_rank
	
func _on_Exit_Button_pressed():
	emit_signal("close")
