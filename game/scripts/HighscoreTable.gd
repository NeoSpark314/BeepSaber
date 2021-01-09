extends Node
class_name HighscoreTable

# location to store the highscores on filesystem
const HIGHSCORES_FILEPATH = "user://highscores.json"

# maximum records to store in each song's record table. once list
# grows past this length, the lowest ranking score will get bumped.
const MAX_RECORDS_PER_KEY = 10

# internal copy of the highscore table
# restored from user file in _ready()
# {
#   "<hs_key>" : {# records for a given song
#       "1" : [ # records at diffucultyRank 1
#           {"player_name":"Bob","score":10000,"epoch_time":0}
#           {"player_name":"Alice","score":5000,"epoch_time":0}
#       ],
#       "3" : [ # records at diffucultyRank 3
#           {"player_name":"Bob","score":10000,"epoch_time":0}
#           {"player_name":"Alice","score":5000,"epoch_time":0}
#       ]
#   }
# }
var _hs_table = {}

func _ready():
	load_hs_table()
	
# clears the whole highscore table
func clear_table():
	_hs_table = {}
	
# returns true if score is a new highscore in the table, false otherwise
func is_new_highscore(map_info,diff_rank,score):
	var hs_key = _get_hs_key(map_info)
	return _is_new_highscore(hs_key,diff_rank,score)
	
# adds a new score record to the table. if the score is not a highscore
# then the record will not be stored.
#
# map_info : data structure as read for map's info.dat file
# diff_rank : difficulty rank (1,3,etc.) that the score was set on
# player_name : string name for the player
# score : integer score to store
#
# return : None
func add_highscore(map_info,diff_rank,player_name,score):
	# get existing records for song + difficulty
	var hs_key = _get_hs_key(map_info)
	var records = _get_records(hs_key,diff_rank)
	
	# construct a new record and resort the list
	var record = _make_record(score,player_name)
	records.append(record)
	records.sort_custom(self,"_highest_and_oldest")
	
	# remove the lowest ranking score
	if records.size() > MAX_RECORDS_PER_KEY:
		records.pop_back()
		
	# store updated records in table
	if not _hs_table.has(hs_key):
		_hs_table[hs_key] = {}
	_hs_table[hs_key][diff_rank] = records
		
# return : the list of records for the given map + difficulty
func get_records(map_info,diff_rank):
	var hs_key = _get_hs_key(map_info)
	return _get_records(hs_key,diff_rank)
	
# restores highscore table from filesystem
func load_hs_table():
	var file = File.new()
	if file.open(HIGHSCORES_FILEPATH,File.READ) == OK:
		var text = file.get_as_text()
		file.close()
		var json_res = JSON.parse(text)
		if json_res.error == OK:
			_hs_table = json_res.result
	else:
		print("WARN: Failed to open %s (might not exist yet)" % HIGHSCORES_FILEPATH)

# saves highscore table to filesystem
func save_hs_table():
	var file = File.new()
	if file.open(HIGHSCORES_FILEPATH,File.WRITE) == OK:
		file.store_string(JSON.print(_hs_table,"   ",true))
		file.close()
	else:
		print("ERROR: Failed to open %s" % HIGHSCORES_FILEPATH)

# internal function used to lookup records for a given song + diffculty
func _get_records(hs_key,diff_rank):
	var records = []
	
	if _hs_table.has(hs_key):
		var hs_row = _hs_table[hs_key]
		if hs_row.has(diff_rank):
			records = hs_row[diff_rank]
	
	return records

# internal function used too check if a score is a new highscore
func _is_new_highscore(hs_key,diff_rank,score):
	var records = get_records(hs_key,diff_rank)
	# make a temporary record just for lookup purposes
	var temp_record = _make_record(score,"**TEMP_PLAYER**")
	return _get_insert_index(records,temp_record) < MAX_RECORDS_PER_KEY

# creates a "record" structure for storage in the highscore table
func _make_record(score,player_name):
	return {
		"score" : score,
		"player_name" : player_name,
		"epoch_time" : OS.get_unix_time()
	}

# records: the list of records for a given (song + diff_rank)
# record: the score record to request the insertion index for
func _get_insert_index(records,record):
	return records.bsearch_custom(record,self,"_highest_and_oldest",false)

static func _highest_and_oldest(lhs, rhs):
	if lhs.score > rhs.score:
		return true
	elif lhs.score < rhs.score:
		return false
	else:
		#  Older score's should be sorted with higher precedance
		# than newer scores.
		if lhs.epoch_time < rhs.epoch_time:
			return true
	return false

const HIGHSCORE_KEY_ORDER = [
	'_songAuthorName',
	'_songName',
	'_songSubName',
	'_levelAuthorName']

# creates a unique key for looking up highscores given a map_info
#
# KeyFormat = [SA,SN,SSN,LA]
#   SA  -> Song Author
#   SN  -> Song Name
#   SSN -> Song Sub-Name
#   LA  -> Level Author
func _get_hs_key(map_info):
	var hs_key = '['
	for i in range(HIGHSCORE_KEY_ORDER.size()):
		var mi_key = HIGHSCORE_KEY_ORDER[i]
		if i != 0:
			hs_key += ','
		
		var mi_val = ""
		if map_info.has(mi_key):
			mi_val = map_info[mi_key]
			mi_val.replace('"','\"')
		
		hs_key += '"%s"' % mi_val
	hs_key += ']'
		
	return hs_key
