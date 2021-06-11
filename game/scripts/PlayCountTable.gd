extends Node
class_name PlayCountTable

# location to store the play counts on filesystem
const PLAY_COUNT_FILEPATH = "user://play_count.json"

# internal copy of the play count table
# restored from user file in _ready()
# {
#   "<song_key>" : {# play counts for a given song
#       "1" : 0, # play count at diffucultyRank 1
#       "3" : 10 # play count at diffucultyRank 3
#   }
# }
var _pc_table = {}

func _ready():
	load_table()
	
# clears the whole play count table
func clear_table():
	_pc_table = {}
	
# removes a given map from the table, effectively resetting that map's counters
func remove_map(map_info):
	var song_key = SongUtils.get_key(map_info)
	_pc_table.erase(song_key)
	save_table()
	
# increments the maps play count by 1.
#
# map_info : data structure as read for map's info.dat file
# diff_rank : difficulty rank (1,3,etc.) that the score was set on
#
# return : None
func increment_play_count(map_info,diff_rank):
	var song_key = SongUtils.get_key(map_info)
	if not _pc_table.has(song_key):
		_pc_table[song_key] = {}
		
	var diff_str = str(diff_rank)
	if not _pc_table[song_key].has(diff_str):
		_pc_table[song_key][diff_str] = 0
		
	_pc_table[song_key][diff_str] += 1
	
	save_table()
		
# return : the map's play count for the given difficulty
func get_play_count(map_info,diff_rank):
	var song_key = SongUtils.get_key(map_info)
	if not _pc_table.has(song_key):
		return 0
		
	var diff_str = str(diff_rank)
	if not _pc_table[song_key].has(diff_str):
		return 0
		
	return _pc_table[song_key][diff_str]

# return : the map's total play count accros all difficulties
func get_total_play_count(map_info):
	var song_key = SongUtils.get_key(map_info)
	if not _pc_table.has(song_key):
		return 0
		
	var total = 0
	for count in _pc_table[song_key].values():
		total += count
	return total

# restores play count table from filesystem
func load_table():
	var file = File.new()
	if file.open(PLAY_COUNT_FILEPATH,File.READ) == OK:
		var text = file.get_as_text()
		file.close()
		var json_res = JSON.parse(text)
		if json_res.error == OK:
			_pc_table = json_res.result
	else:
		print("WARN: Failed to open %s (might not exist yet)" % PLAY_COUNT_FILEPATH)

# saves play count table to filesystem
func save_table():
	var file = File.new()
	if file.open(PLAY_COUNT_FILEPATH,File.WRITE) == OK:
		file.store_string(JSON.print(_pc_table,"   ",true))
		file.close()
	else:
		print("ERROR: Failed to open %s" % PLAY_COUNT_FILEPATH)
