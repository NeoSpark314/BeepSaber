# The main menu is shown at game start or pause on an OQ_UI2DCanvas
# some logic is in the BeepSaber_Game.gd to set the correct state
#
# This file also contains the logic to load a beatmap in the format that
# normal Beat Saber uses. So you can load here custom beat saber songs too
extends Panel

# we need the main game class here to trigger game start/restart/continue
var _beepsaber = null;

func initialize(beepsaber_game):
	_beepsaber = beepsaber_game;


func set_mode_game_start():
	$Play_Button.visible = true;
	$Continue_Button.visible = false;
	$Restart_Button.visible = false;


func set_mode_continue():
	$Play_Button.visible = false;
	$Continue_Button.visible = true;
	$Restart_Button.visible = true;


var path = "res://game/data/maps/";
var _playlists

var PlaylistButton = preload("res://game/PlaylistButton.tscn")

func _load_playlists():
	var Playlists = $PlaylistMenu/Playlists
	
	_playlists = vr.load_json_file(path + "Playlists.json");
	if (!_playlists):
		vr.log_error("No Playlists.json found in " + path);
		return false;
	
	for pl in _playlists:
		var newPlaylistButton = PlaylistButton.instance()
		newPlaylistButton.pl = pl
		newPlaylistButton.connect("pressed_pl", self, "_set_cur_playlist")
		Playlists.add_child(newPlaylistButton)
	
	if (_playlists.size() == 0):
		_set_cur_playlist([])
	else:
		_set_cur_playlist(_playlists[0])

var SongButton = preload("res://game/SongButton.tscn")

func _set_cur_playlist(pl):
	var Playlists = $PlaylistMenu/Playlists
	
	for playlist in Playlists.get_children():
		if playlist.pl == pl:
			playlist.modulate = Color(1, 0.5, 0.5)
		else:
			playlist.modulate = Color(1, 1, 1)
	
	var Songs = $Playlist/Songs
	
	for song in Songs.get_children():
		song.queue_free()
	
	var info
	var to_select = true
	for id in pl["Songs"]:
		var newSongButton = SongButton.instance();
		newSongButton.id = id;
		newSongButton.info = _load_info_id(id);
		newSongButton.connect("pressed_id", self, "_select_song");
		Songs.add_child(newSongButton)
		if newSongButton.info and to_select:
			_select_song(id)
			to_select = false

func _load_info_id(id):
	var info = vr.load_json_file(path + "Songs/" + id + "/info.dat");
	if (!info):
		vr.log_error("No info.dat found in " + path + "Songs/" + id);
		#info = _download_song_id(id)
		return info;
	
	if (info._difficultyBeatmapSets.size() == 0):
		vr.log_error("No _difficultyBeatmapSets in info.dat");
		return null;
	
	return info;


# a loaded beat map will have an info dictionary; this is a global variable here
# to later extend it to load different maps
var _map_id = null;
var _map_info = null;

var DifficultyButton = preload("res://game/DifficultyButton.tscn")


func _select_song(id):
	_map_id = id
	_map_info = _load_info_id(id)
	$SongInfo_Label.text = """Song Author: %s
	Song Title: %s
	Beatmap Author: %s""" %[_map_info._songAuthorName, _map_info._songName, _map_info._levelAuthorName]

	$cover.texture = load(path + "Songs/" + id + "/" + _map_info._coverImageFilename);
	
	var Songs = $Playlist/Songs
	for song in Songs.get_children():
		if song.id == id:
			song.modulate = Color(1, 0.5, 0.5)
		else:
			song.modulate = Color(1, 1, 1)
	
	var Difficulties = $DifficultyMenu/Playlists
	for difficulty in Difficulties.get_children():
		difficulty.queue_free()
	for ii_dif in range(_map_info._difficultyBeatmapSets[0]._difficultyBeatmaps.size()):
		var newDifficultyButton = DifficultyButton.instance()
		newDifficultyButton.id = ii_dif
		var BMPS = _map_info._difficultyBeatmapSets[0]._difficultyBeatmaps
		newDifficultyButton.Name = _map_info._difficultyBeatmapSets[0]._difficultyBeatmaps[ii_dif]._difficulty
		newDifficultyButton.connect("pressed_id", self, "_select_difficulty")
		Difficulties.add_child(newDifficultyButton)
	
	_select_difficulty(0)


var _map_difficulty = 0


func _select_difficulty(id):
	_map_difficulty = id
	var Difficulties = $DifficultyMenu/Playlists
	for difficulty in Difficulties.get_children():
		difficulty.modulate = Color(1, 1, 1)
	Difficulties.get_child(id).modulate = Color(1, 0.5, 0.5)


func _load_map_and_start():
	if (_map_info == null): return;
		
	var set0 = _map_info._difficultyBeatmapSets[0];
	if (set0._difficultyBeatmaps.size() == 0):
		vr.log_error("No _difficultyBeatmaps in set");
		return false;
		
	var map_info = set0._difficultyBeatmaps[_map_difficulty];
	var map_filename = path + "Songs/" + _map_id + "/" + map_info._beatmapFilename;
	var map_data = vr.load_json_file(map_filename);
	
	if (map_data == null):
		vr.log_error("Could not read map data from " + map_filename);
	
	#print(info);

	_beepsaber.start_map(path + "Songs/" + _map_id + "/", _map_info, map_data);
	
	return true;


func _ready():
	_load_playlists()
	pass


func _on_Play_Button_pressed():
	_load_map_and_start();
	pass


func _on_Exit_Button_pressed():
	get_tree().quit()
	pass;


func _on_Restart_Button_pressed():
	_beepsaber.restart_map();


func _on_Continue_Button_pressed():
	_beepsaber.continue_map();



# Note (19.10.2020): downloading of unknown songs is currently disabled
#                    as this will need special handling also on the quest
#
#var download_id = ""
#func _download_song_id(id):
#	download_id = id
#	$HTTPRequest.request("https://beatsaver.com/api/download/key/"+id)
#	return null

#func extract_file(zip_file, fileName, destination):
#	var gdunzip = load('res://addons/gdunzip/gdunzip.gd').new()
#	var loaded = gdunzip.load(zip_file)
#	var file = File.new()
#	var uncompressed = gdunzip.uncompress(fileName)
#	file.open(destination+"/"+fileName, File.WRITE)
#	file.store_buffer(uncompressed)
#	file.close()
#	print("DECOMPRESSED: "+fileName)
#
#
#func unzip(zip_file, destination):
#	var gdunzip = load('res://addons/gdunzip/gdunzip.gd').new()
#	var loaded = gdunzip.load(zip_file)
#	if !loaded:
#		return false
#	for f in gdunzip.files:
#		# extract_file(zip_file, f, destination) # NOT WORKING PROPERLY
#		print(f)
#
#
#func _on_HTTPRequest_request_completed(result, response_code, headers, body):
#	var directory = Directory.new()
#	if response_code == 200:
#		print("Downloaded song: "+download_id)
#		directory.make_dir("res://game/data/maps/Songs/"+download_id)
#		var file = File.new()
#		file.open("res://game/data/maps/Songs/"+download_id+"/temp.zip", File.WRITE)
#		file.store_buffer(body)
#		file.close()
#		unzip("res://game/data/maps/Songs/"+download_id+"/temp.zip", "res://game/data/maps/Songs/"+download_id)
#	else:
#		print("Failed to download song: "+download_id)
