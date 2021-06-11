extends Node
class_name SongUtils

const SONG_KEY_ORDER = [
	'_songAuthorName',
	'_songName',
	'_songSubName',
	'_levelAuthorName']

# creates a unique key given a map_info
#
# KeyFormat = [SA,SN,SSN,LA]
#   SA  -> Song Author
#   SN  -> Song Name
#   SSN -> Song Sub-Name
#   LA  -> Level Author
static func get_key(map_info):
	var song_key = '['
	for i in range(SONG_KEY_ORDER.size()):
		var mi_key = SONG_KEY_ORDER[i]
		if i != 0:
			song_key += ','
		
		var mi_val = ""
		if map_info.has(mi_key):
			mi_val = map_info[mi_key]
			mi_val.replace("\"",'')
			mi_val.replace("'",'')
		else:
			vr.log_warning("map_info does not contain key '%s'" % mi_key)
		
		song_key += "'%s'" % mi_val
	song_key += ']'
		
	return song_key
