# This file contains the main game logic for the BeepSaber demo implementation
#
extends Spatial

enum GameState {
	Bootup,
	MapSelection,
	Settings,
	Playing,
	Paused,
	# song ended and we're showing the player their final score
	MapComplete,
	# song ended and we're waiting for player to enter name for highscore
	NewHighscore
}


onready var left_controller := $OQ_ARVROrigin/OQ_LeftController;
onready var right_controller := $OQ_ARVROrigin/OQ_RightController;

onready var left_saber := $OQ_ARVROrigin/OQ_LeftController/LeftLightSaber;
onready var right_saber := $OQ_ARVROrigin/OQ_RightController/RightLightSaber;

onready var ui_raycast := $OQ_ARVROrigin/OQ_RightController/Feature_UIRayCast;

onready var highscore_canvas := $Highscores_Canvas
onready var name_selector_canvas := $NameSelector_Canvas
onready var highscore_keyboard := $Keyboard_highscore

onready var map_source_dialogs := $MapSourceDialogs
onready var online_search_keyboard := $Keyboard_online_search

onready var fps_label = $OQ_ARVROrigin/OQ_ARVRCamera/PlayerHead/FPS_Label

onready var cube_template = preload("res://game/BeepCube.tscn").instance();
onready var wall_template = preload("res://game/Wall/Wall.tscn").instance();
onready var LinkedList := preload("res://game/scripts/LinkedList.gd")
export(PackedScene) var bomb_template : PackedScene

onready var _cube_pool := $BeepCubePool

onready var track = $Track;

onready var song_player := $SongPlayer;

onready var menu = $MainMenu_OQ_UI2DCanvas.ui_control

var COLOR_LEFT := Color(1.0, 0.1, 0.1, 1.0);
var COLOR_RIGHT := Color(0.1, 0.1, 1.0, 1.0);

const CUBE_HEIGHT_OFFSET = 0.4
const WALL_HEIGHT = 3.0


var _current_game_state = GameState.Bootup;
var _current_map = null;
var _current_note_speed = 1.0;
var _current_info = null;
var _current_note = 0;
var _current_obstacle = 0;
var _current_event = 0;

var _proc_map_sw := StopwatchFactory.create("process_map",10,true)
var _cut_cube_sw := StopwatchFactory.create("cute_cube",10,true)
var _update_points_sw := StopwatchFactory.create("update_points",10,true)
var _create_cut_pieces_sw := StopwatchFactory.create("create_cut_pieces",10,true)
var _instance_cube_sw := StopwatchFactory.create("instance_cube",10,true)
var _add_cube_to_scene_sw := StopwatchFactory.create("add_cube_to_scene",10,true)

# There's an interesting issue where the AudioStreamPlayer's playback_position
# doesn't immediately return to 0.0 after restarting the song_player. This
# causes issues with restarting a map because the process_physics routine will
# execute for a times and attempt to process the map up to the playback_position
# prior to the AudioStreamPlayer restart. This bug can presents itself as notes
# persisting between map restarts.
# To remidy this issue, this flag is set to true when the map is restarted. The
# process_physics routine won't begin processing the map until after the
# AudioStreamPlayer has reset it's playback_position to zero. This flag is set
# to false once the AudioStreamPlayer reset is detected.
var _audio_synced_after_restart = false

# current difficulty name (Easy, Normal, Hard, etc.)
var _current_diff_name = -1;
# current difficulty rank (1,3,5,etc.)
var _current_diff_rank = -1;


var _current_points = 0;
var _current_multiplier = 1;
var _current_combo = 0;

var _in_wall = false;

var _right_notes = 0;
var _wrong_notes = 0;
var _full_combo = true;

#settings
var cube_cuts_falloff = true
var bombs_enabled = true

# structure of nodes that represent a cut piece of a cube (ie. one half)
class CutPieceNodes:
	extends Reference
	
	var rigid_body := RigidBody.new()
	var mesh := MeshInstance.new()
	var coll := CollisionShape.new()
	
	func _init():
		rigid_body.add_to_group("cutted_cube")
		rigid_body.collision_layer = 0
		rigid_body.collision_mask = CollisionLayerConstants.Floor_mask
		rigid_body.gravity_scale = 1
		# set a phyiscs material for some more bouncy behaviour
		rigid_body.physics_material_override = preload("res://game/BeepCube_Cut.phymat")
		
		coll.shape = BoxShape.new()
		
		rigid_body.add_child(coll)
		rigid_body.add_child(mesh)
		
		rigid_body.set_script(preload("res://game/BeepCube_CutFadeout.gd"))

# structure of nodes that are used to produce effects when cutting a cube
class CutCubeResources:
	extends Reference
	
	var particles : BeepCubeSliceParticles = null
	var piece1 := CutPieceNodes.new()
	var piece2 := CutPieceNodes.new()
	
	func _init():
		particles = preload("res://game/BeepCube_SliceParticles.tscn").instance()

const MAX_CUT_CUBE_RESOURCES = 32
onready var _cut_cube_resources := LinkedList.new()

func restart_map():
	_audio_synced_after_restart = false
	song_player.play(0.0);
	song_player.volume_db = 0.0;
	_in_wall = false;
	_current_note = 0;
	_current_obstacle = 0;
	_current_event = 0;
	_current_points = 0;
	_current_multiplier = 1;
	_current_combo = 0;

	#set_percent_to_null
	_right_notes = 0.0
	_wrong_notes = 0.0
	_full_combo = true;

	_display_points();
	$event_driver.update_colors()
	if _current_map._events.size() > 0:
		$event_driver.set_all_off()
	else:
		$event_driver.set_all_on()

	_clear_track()
	_transition_game_state(GameState.Playing)

func start_map(info, map_data):
	_current_map = map_data;
	_current_info = info;
	var snd_file = File.new()
	snd_file.open(info._path + info._songFilename, File.READ) #works whether it's a resource or a file
	var stream = AudioStreamOGGVorbis.new()
	stream.data = snd_file.get_buffer(snd_file.get_len())
	snd_file.close()
	song_player.stream = stream;
	restart_map();
	
# This function will transitioning the game from it's current state into
# the provided 'next_state'.
func _transition_game_state(next_state):
	_on_game_state_exited(_current_game_state)
	_current_game_state = next_state
	_on_game_state_entered(_current_game_state)

# Callback when the game is transitioning out of the given state.
func _on_game_state_exited(state):
	match state:
		GameState.Bootup:
			pass
		GameState.MapSelection:
			pass
		GameState.Playing:
			pass
		GameState.Paused:
			pass
		GameState.MapComplete:
			pass
		GameState.NewHighscore:
			pass
		_:
			vr.log_warning("Unhandled exit event for state %s" % state)

# Callback when the game is transitioning into the given state.
func _on_game_state_entered(state):
	match state:
		GameState.Bootup:
			pass
		GameState.MapSelection:
			$MainMenu_OQ_UI2DCanvas.visible = true;
			$Settings_canvas.visible = false;
			map_source_dialogs.visible = true;
			$EndScore_canvas.visible = false;
			$PauseMenu_canvas.visible = false;
			highscore_canvas.visible = false;
			name_selector_canvas.visible = false;
			left_saber.hide();
			right_saber.hide();
			$Multiplier_Label.visible = false;
			$Point_Label.visible = false;
			$Percent.visible = false;
			track.visible = false;
			ui_raycast.visible = true;
			highscore_keyboard.visible = false;
			online_search_keyboard.visible = false;
		GameState.Settings:
			$MainMenu_OQ_UI2DCanvas.visible = false;
			$Settings_canvas.visible = true;
			map_source_dialogs.visible = true;
			$EndScore_canvas.visible = false;
			$PauseMenu_canvas.visible = false;
			highscore_canvas.visible = false;
			name_selector_canvas.visible = false;
#			left_saber.hide();
#			right_saber.hide();
			$Multiplier_Label.visible = false;
			$Point_Label.visible = false;
			$Percent.visible = false;
			track.visible = false;
			ui_raycast.visible = true;
			highscore_keyboard.visible = false;
			online_search_keyboard.visible = false;
		GameState.Playing:
			$MainMenu_OQ_UI2DCanvas.visible = false;
			$Settings_canvas.visible = false;
			map_source_dialogs.visible = false;
			$EndScore_canvas.visible = false;
			$PauseMenu_canvas.visible = false;
			highscore_canvas.visible = false;
			name_selector_canvas.visible = false;
			left_saber.show();
			right_saber.show();
			$Multiplier_Label.visible = true;
			$Point_Label.visible = true;
			$Percent.visible = true;
			track.visible = true;
			ui_raycast.visible = false;
			highscore_keyboard.visible = false;
			online_search_keyboard.visible = false;
		GameState.Paused:
			$MainMenu_OQ_UI2DCanvas.visible = false;
			$Settings_canvas.visible = false;
			map_source_dialogs.visible = false;
			$EndScore_canvas.visible = false;
			$PauseMenu_canvas.visible = true;
			highscore_canvas.visible = false;
			name_selector_canvas.visible = false;
#			left_saber.show();
#			right_saber.show();
			$Multiplier_Label.visible = true;
			$Point_Label.visible = true;
			$Percent.visible = true;
			track.visible = false;
			ui_raycast.visible = true;
			highscore_keyboard.visible = false;
			online_search_keyboard.visible = false;
			
			song_player.stop();
			$PauseMenu_canvas.ui_control.set_pause_text("%s By %s\nMap author: %s" % [_current_info["_songName"],_current_info["_songAuthorName"],_current_info["_levelAuthorName"]],menu._map_difficulty_name)
		GameState.MapComplete:
			_endscore_panel().set_buttons_disabled(false)
			
			$MainMenu_OQ_UI2DCanvas.visible = false;
			$Settings_canvas.visible = false;
			map_source_dialogs.visible = false;
			$EndScore_canvas.visible = true;
			$PauseMenu_canvas.visible = false;
			highscore_canvas.visible = false;
			name_selector_canvas.visible = false;
			left_saber.hide();
			right_saber.hide();
			$Multiplier_Label.visible = false;
			$Point_Label.visible = false;
			$Percent.visible = false;
			track.visible = false;
			ui_raycast.visible = true;
			highscore_keyboard.visible = false;
			online_search_keyboard.visible = false;
		GameState.NewHighscore:
			# populate highscore panel with records
			_highscore_panel().load_highscores(
				_current_info,_current_diff_rank)
			
			_endscore_panel().set_buttons_disabled(true)
			
			# fill name selector with most recent player names
			_name_selector().clear_names()
			# WARNING: The get_all_player_names() method could become
			# costly for a very large highscore database (ie. many
			# songs and many difficulties). If that ever becomes a
			# concern, we may want to consider caching a list of the
			# N most recent players instead.
			for player_name in Highscores.get_all_player_names():
				_name_selector().add_name(player_name)
			
			$MainMenu_OQ_UI2DCanvas.visible = false;
			$Settings_canvas.visible = false;
			map_source_dialogs.visible = false;
			$EndScore_canvas.visible = true;
			$PauseMenu_canvas.visible = false;
			highscore_canvas.visible = true;
			name_selector_canvas.visible = true;
			left_saber.hide();
			right_saber.hide();
			$Multiplier_Label.visible = false;
			$Point_Label.visible = false;
			$Percent.visible = false;
			track.visible = false;
			ui_raycast.visible = true;
			highscore_keyboard.visible = true;
			online_search_keyboard.visible = false;
		_:
			vr.log_warning("Unhandled enter event for state %s" % state)

# when the song ended we want to display the current score and
# the high score
func _on_song_ended():
	song_player.stop();
	PlayCount.increment_play_count(_current_info,_current_diff_rank)
	
	var new_record = false
	var highscore = Highscores.get_highscore(_current_info,_current_diff_rank)
	if highscore == null:
		# no highscores exist yet
		highscore = _current_points
	elif _current_points > highscore:
		# player's score is the new highscore!
		highscore = _current_points;
		new_record = true

	var current_percent = int((_right_notes/(_right_notes+_wrong_notes))*100)
	$EndScore_canvas.ui_control.show_score(
		_current_points,
		highscore,
		current_percent,
		"%s By %s\n%s     Map author: %s" % [
			_current_info["_songName"],
			_current_info["_songAuthorName"],
			menu._map_difficulty_name,
			_current_info["_levelAuthorName"]],
		_full_combo,
		new_record
		)
	
	if Highscores.is_new_highscore(_current_info,_current_diff_rank,_current_points):
		_transition_game_state(GameState.NewHighscore)
	else:
		_transition_game_state(GameState.MapComplete)

# call this method to submit a new highscore to the database
func _submit_highscore(player_name):
	if _current_game_state == GameState.NewHighscore:
		Highscores.add_highscore(
			_current_info,
			_current_diff_rank,
			player_name,
			_current_points)
			
		_transition_game_state(GameState.MapComplete)

const beat_distance = 4.0;
const beats_ahead = 4.0;
const CUBE_DISTANCE = 0.5;
const CUBE_ROTATIONS = [180, 0, 270, 90, -135, 135, -45, 45, 0];

func _spawn_note(note, current_beat):
	var note_node = null;
	var is_cube = true
	var color := COLOR_LEFT
	if (note._type == 0):
		_instance_cube_sw.start()
		note_node = _cube_pool.acquire()
		color = COLOR_LEFT
		_instance_cube_sw.stop()
	elif (note._type == 1):
		_instance_cube_sw.start()
		note_node = _cube_pool.acquire()
		color = COLOR_RIGHT
		_instance_cube_sw.stop()
	elif (note._type == 3) and bombs_enabled:
		is_cube = false
		note_node = bomb_template.instance()
	else:
		return;
	
	if note_node == null:
		print("Failed to acquire a new note from scene pool")
		return
	
	# disable collision until it gets nearer to player (helps with performance)
	note_node.collision_disabled = true

	if menu._map_difficulty_noteJumpMovementSpeed > 0:
		note_node.speed = float(menu._map_difficulty_noteJumpMovementSpeed)/9

	var line = -(CUBE_DISTANCE * 3.0 / 2.0) + note._lineIndex * CUBE_DISTANCE;
	var layer = CUBE_DISTANCE + note._lineLayer * CUBE_DISTANCE;

	var rotation_z = deg2rad(CUBE_ROTATIONS[note._cutDirection]);

	var distance = note._time - current_beat;

	note_node.transform.origin = Vector3(
		line,
		CUBE_HEIGHT_OFFSET + layer,
		-distance * beat_distance);

	if is_cube:
		var is_dot = note._cutDirection == 8
		note_node._cube_mesh_orientation.rotation.z = rotation_z;
		note_node._cube_mesh_orientation.rotation.y = (PI if is_dot else 0)

	note_node._note = note;
	
	if note_node is BeepCube:
		_add_cube_to_scene_sw.start()
		note_node.spawn(note._type, color)
		_add_cube_to_scene_sw.stop()
	else:
		# spawn bombs by adding to track
		track.add_child(note_node);

# constants used to interpret the '_type' field in map obstacles
const WALL_TYPE_FULL_HEIGHT = 0;
const WALL_TYPE_CROUCH = 1;

func _spawn_wall(obstacle, current_beat):
	# instantiate new wall from template
	var wall = wall_template.duplicate();
	wall.duplicate_create();# gives it its own unique mesh and collision shape
	
	var height = 0;
	
	if (obstacle._type == WALL_TYPE_FULL_HEIGHT):
		wall.height = WALL_HEIGHT;
		height = 0;
	elif (obstacle._type == WALL_TYPE_CROUCH):
		wall.height = WALL_HEIGHT / 2.0;
		height = WALL_HEIGHT / 2.0;
	else:
		return;

	track.add_child(wall);

	var line = -(CUBE_DISTANCE * 3.0 / 2.0) + obstacle._lineIndex * CUBE_DISTANCE;
	
	var distance = obstacle._time - current_beat;

	wall.transform.origin = Vector3(line,height,-distance * beat_distance);
	wall.depth = beat_distance * obstacle._duration;
	wall.width = CUBE_DISTANCE * obstacle._width;
	
	# walls have slightly difference origins offsets than cubes do, so we must
	# translate them by half a cube distance to correct for the misalignment.
	wall.translate(Vector3(-CUBE_DISTANCE/2.0,-CUBE_DISTANCE/2.0,0.0));

	wall._obstacle = obstacle;


func _process_map(dt):
	if (_current_map == null):
		return;
	
	_proc_map_sw.start()
	
	var current_time = song_player.get_playback_position();
	
	var current_beat = current_time * _current_info._beatsPerMinute / 60.0;

	# spawn notes
	var n =_current_map._notes;
	while (_current_note < n.size() && n[_current_note]._time <= current_beat+beats_ahead):
		_spawn_note(n[_current_note], current_beat);
		_current_note += 1;

	# spawn obstacles (walls)
	var o = _current_map._obstacles;
	while (_current_obstacle < o.size() && o[_current_obstacle]._time <= current_beat+beats_ahead):
		_spawn_wall(o[_current_obstacle], current_beat);
		_current_obstacle += 1;

	var speed = Vector3(0.0, 0.0, beat_distance * _current_info._beatsPerMinute / 60.0) * dt;

	for c_idx in track.get_child_count():
		var c = track.get_child(c_idx)
		if ! c.visible:
			continue
		
		c.translate(speed);

		var depth = CUBE_DISTANCE
		if c is Wall:
			# compute wall's depth based on duration
			depth = beat_distance * c._obstacle._duration
		else:
			# enable bomb/cube collision when it gets closer enough to player
			if c.global_transform.origin.z > -3.0:
				c.collision_disabled = false

		# remove children that go to far
		if ((c.global_transform.origin.z - depth) > 2.0):
			if c is BeepCube:
				_reset_combo();
				# cubes must be released() instead of queue_free() because they
				# are part of a pool.
				c.release()
			else:
				c.queue_free();

	var e = _current_map._events;
	while (_current_event < e.size() && e[_current_event]._time <= current_beat):#+beats_ahead):
		_spawn_event(e[_current_event], current_beat);
		_current_event += 1;

	if (song_player.get_playback_position() >= song_player.stream.get_length()-1):
		_on_song_ended();
		
	_proc_map_sw.stop()

func _spawn_event(data,beat):
	$event_driver.procces_event(data,beat)


# with this variable we track the movement volume of the controller
# since the last cut (used to give a higher score when moved a lot)
var _controller_movement_aabb = [
	AABB(), AABB(), AABB()
]

func _update_controller_movement_aabb(controller : ARVRController):
	var id = controller.controller_id
	var aabb = _controller_movement_aabb[id].expand(controller.global_transform.origin);
	_controller_movement_aabb[id] = aabb;


func _check_and_update_saber(controller : ARVRController, saber: Area):
	# to allow extending/sheething the saber while not playing a song
	if (!song_player.playing):
		if (controller._button_just_pressed(vr.CONTROLLER_BUTTON.XA) ||
			controller._button_just_pressed(vr.CONTROLLER_BUTTON.YB)):
				if (!saber._anim.is_playing()):
					if (saber.is_extended()): saber.hide();
					else: saber.show();
					
	
	# check for saber rumble (only when extended and not already rumbling)
	# this check is necessary to not overwrite a rumble set from somewhere else
	# (in this case it can come from cutting cubes)
	if (!controller.is_simple_rumbling()): 
		if (_in_wall):
			# weak rumble on both controllers when player is inside wall
			controller.set_rumble(0.1);
		elif (saber.get_overlapping_areas().size() > 0 || saber.get_overlapping_bodies().size() > 0):
			# strong rumble when saber is cutting into wall or other saber
			controller.set_rumble(0.5);
		else:
			controller.set_rumble(0.0);


var left_saber_end = Vector3()
var right_saber_end = Vector3()
var left_saber_end_past = Vector3()
var right_saber_end_past = Vector3()
var last_dt = 0.0


func _update_saber_end_variabless(dt):
	left_saber_end_past = left_saber_end
	right_saber_end_past = right_saber_end
	left_saber_end = left_controller.global_transform.origin + left_saber.global_transform.basis.y
	right_saber_end = right_controller.global_transform.origin + right_saber.global_transform.basis.y
	last_dt = dt


func _physics_process(dt):
	if fps_label.visible:
		fps_label.set_label_text("FPS: %d" % Engine.get_frames_per_second())
	
	# pause game when player presses menu button
	if (vr.button_just_released(vr.BUTTON.ENTER)):
		if _current_game_state == GameState.Playing:
			_transition_game_state(GameState.Paused)

	if _current_game_state == GameState.Playing:
		if song_player.playing and not _audio_synced_after_restart:
			# 0.5 seconds is a pretty concervative number to use for the audio
			# resync check. Having this duration be this long might only be an
			# issue for maps that spawn notes extremely early into the song.
			if song_player.get_playback_position() < 0.5:
				_audio_synced_after_restart = true;
		elif song_player.playing:
			_process_map(dt);
			_update_controller_movement_aabb(left_controller);
			_update_controller_movement_aabb(right_controller);
	
	_check_and_update_saber(left_controller, left_saber);
	_check_and_update_saber(right_controller, right_saber);
	
	_update_saber_end_variabless(dt)
	

var _main_menu = null;
var _lpf = null;

func _ready():
	_main_menu = $MainMenu_OQ_UI2DCanvas.find_node("BeepSaberMainMenu", true, false);
	_main_menu.initialize(self);
	$MapSourceDialogs/BeatSaver_Canvas.ui_control.main_menu_node = _main_menu

	update_saber_colors()
	
	# This is a workaround for now to orient correctly for the Vive controllers
	if (vr.active_arvr_interface_name == "OpenVR"):
		left_saber.rotation_degrees.x = -90;
		right_saber.rotation_degrees.x = -90;
		ui_raycast.rotation_degrees.x = 0;

	# initialize list of cut cube resources
	for _i in range(MAX_CUT_CUBE_RESOURCES):
		var new_res := CutCubeResources.new()
		add_child(new_res.particles)
		add_child(new_res.piece1.rigid_body)
		add_child(new_res.piece2.rigid_body)
		_cut_cube_resources.push_back(new_res)

	UI_AudioEngine.attach_children(highscore_keyboard)
	UI_AudioEngine.attach_children(online_search_keyboard)

	_transition_game_state(GameState.MapSelection)

func update_saber_colors():
	left_saber.set_color(COLOR_LEFT)
	right_saber.set_color(COLOR_RIGHT)
	#also updates map colors
	$event_driver.update_colors()
	$StandingGround.update_colors(COLOR_LEFT,COLOR_RIGHT)

func disable_events(disabled):
	$event_driver.disabled = disabled
	if disabled:
		$event_driver.set_all_off()
	else:
		$event_driver.set_all_on()


# cut the cube by creating two rigid bodies and using a CSGBox to create
# the cut plane
func _create_cut_rigid_body(_sign, cube : Spatial, cutplane : Plane, cut_distance, controller_speed, saber_ends, cut_res: CutCubeResources):
	if not cube_cuts_falloff: 
		return
	
	# this function gets run twice, one for each piece of the cube
	var piece : CutPieceNodes = cut_res.piece1
	if is_equal_approx(_sign,1):
		piece = cut_res.piece2
	
	# make piece invisible and stop it's processing while we're updating it
	piece.rigid_body.reset()
	
	# the original cube mesh
	piece.mesh.mesh = cube._mesh;
	piece.mesh.transform = cube._cube_mesh_orientation.transform;
	piece.mesh.material_override = cube._mat.duplicate()
	
	# calculate angle and position of the cut
	piece.mesh.material_override.set_shader_param("cutted",true)
	piece.mesh.material_override.set_shader_param("inverted_cut",!bool((_sign+1)/2))
	# TODO: cutplane is unused and replaced by this? what
	var saber_end_mov = saber_ends[0]-saber_ends[1]
	var saber_end_angle = rad2deg(Vector2(saber_end_mov.x,saber_end_mov.y).angle())
	var saber_end_angle_rel = (int(((saber_end_angle+90)+(360-piece.mesh.rotation_degrees.z))+180)%360)-180
	
	var rot_dir = saber_end_angle_rel > 90 or saber_end_angle_rel < -90
	var rot_dir_flt = (float(rot_dir)*2)-1
	piece.mesh.material_override.set_shader_param("cut_pos",cut_distance*rot_dir_flt)
	piece.mesh.material_override.set_shader_param("cut_angle",deg2rad(saber_end_angle_rel))

	# transform the normal into the orientation of the actual cube mesh
	var normal = piece.mesh.transform.basis.inverse() * cutplane.normal;
	
	# Next we are adding a simple collision cube to the rigid body. Note that
	# his is really just a very crude approximation of the actual cut geometry
	# but for now it's enough to give them some physics behaviour
	piece.coll.shape.extents = Vector3(0.25, 0.25, 0.125)
	piece.coll.look_at_from_position(-cutplane.normal*_sign*0.125, cutplane.normal, Vector3(0,1,0))

	piece.rigid_body.global_transform = cube.global_transform
	# make piece visible and start its simulation
	piece.rigid_body.fire()
	
	# some impulse so the cube half moves
	var cutplane_2d = Vector3(saber_end_mov.x,saber_end_mov.y,0.0)
	var splitplane_2d = cutplane_2d.cross(piece.mesh.transform.basis.z)
#	_sign *= rot_dir_flt
	piece.rigid_body.apply_central_impulse((_sign * splitplane_2d * 15) + (cutplane_2d*10))
	piece.rigid_body.apply_torque_impulse((_sign) * Vector3.FORWARD * 0.15)
	
	# This function gets run twice so we don't want two particle effects
	if is_equal_approx(_sign,1):
		cut_res.particles.transform.origin = cube.global_transform.origin
		cut_res.particles.rotation_degrees.z = saber_end_angle+90
		cut_res.particles.fire()

func _reset_combo():
	_current_multiplier = 1;
	_current_combo = 0;
	_wrong_notes += 1.0;
	_full_combo = false;
	_display_points();
	
func _clear_track():
	for c in track.get_children():
		if c is BeepCube:
			if c.visible:
				c.release()
		else:
			c.visible = false;
			track.remove_child(c);
			c.queue_free();

func _update_points_from_cut(saber, cube, beat_accuracy, cut_angle_accuracy, cut_distance_accuracy, travel_distance_factor):
	#if (beat_accuracy == 0.0 || cut_angle_accuracy == 0.0 || cut_distance_accuracy == 0.0):
	#	_reset_combo();
	#	return;
	
	#send data to saber for esthetics effects
	saber.hit(cube) 
	
	# check if we hit the cube with the correctly colored saber
	if (saber.type != cube._note._type):
		_reset_combo();
		_wrong_notes += 1.0
		$Points_label_driver.show_points(cube.transform.origin,0)
		return;

	_current_combo += 1;
	_current_multiplier = 1 + round(min((_current_combo / 10), 7.0));

	# point computation based on the accuracy of the swing
	var points = 0;
	points += beat_accuracy * 50;
	points += cut_angle_accuracy * 50;
	points += cut_distance_accuracy * 50;
	points += points * travel_distance_factor;

	points = round(points);
	_current_points += points * _current_multiplier;
#	print(points)
	$Points_label_driver.show_points(cube.transform.origin,points)
	# track acurracy percent
	var normalized_points = clamp(points/80, 0.0, 1.0);
#	var normalized_points = clamp(points/100, 0.0, 1.0);
#	print(normalized_points)
	_right_notes += normalized_points;
	_wrong_notes += 1.0-normalized_points;

	_display_points();
	


func _display_points():
	var current_percent = 100
	if _right_notes+_wrong_notes > 0:
		current_percent = int((_right_notes/(_right_notes+_wrong_notes))*100)
	
	$Point_Label.set_label_text("Score: %6d" % _current_points);
	$Percent.ui_control.set_percent(current_percent)
	$Multiplier_Label.set_label_text("x %d\nCombo %d" %[_current_multiplier, _current_combo])

# perform the necessay computations to cut a cube with the saber
func _cut_cube(controller : ARVRController, saber : Area, cube : Spatial):
	_cut_cube_sw.start()
	
	# perform haptic feedback for the cut
	controller.simple_rumble(0.75, 0.1);
	var o = controller.global_transform.origin;
	var saber_end : Vector3
	var saber_end_past : Vector3
	if(controller.controller_id == 1): # Check if it's the left controller
		saber_end = left_saber_end
		saber_end_past = left_saber_end_past
	else:
		saber_end = right_saber_end
		saber_end_past = right_saber_end_past
	
	var cutplane := Plane(o, saber_end, saber_end_past + (beat_distance *_current_info._beatsPerMinute * last_dt / 30) * Vector3(0, 0, 1)); # Account for relative position to track speed
	var cut_distance = cutplane.distance_to(cube.global_transform.origin);
	
	var controller_speed : Vector3 = (saber_end - saber_end_past) / (5*last_dt) + 0.2*(beat_distance *_current_info._beatsPerMinute / 60) * Vector3(0, 0, 1) # Account for inertial track speed

	# compute the angle between the cube orientation and the cut direction
	var cut_direction_xy = -Vector3(controller_speed.x, controller_speed.y, 0.0).normalized();
	var base_cut_angle_accuracy = cube._cube_mesh_orientation.global_transform.basis.y.dot(cut_direction_xy);
	var cut_angle_accuracy = clamp((base_cut_angle_accuracy-0.7)/0.3, 0.0, 1.0);
	if cube._note._cutDirection==8: #ignore angle if is a dot
		cut_angle_accuracy = 1.0;
	var cut_distance_accuracy = clamp((0.1 - abs(cut_distance))/0.1, 0.0, 1.0);
	var travel_distance_factor = _controller_movement_aabb[controller.controller_id].get_longest_axis_size();
	travel_distance_factor = clamp((travel_distance_factor-0.5)/0.5, 0.0, 1.0);

	_create_cut_pieces_sw.start()
	# acquire oldest CutCubeResources to use for this event. we reused these
	# resource for performance reasons. it gets placed onto the back of the
	# list so that it won't get used again for a couple more cycles.
	var cut_res : CutCubeResources = _cut_cube_resources.pop_front()
	_cut_cube_resources.push_back(cut_res)
	_create_cut_rigid_body(-1, cube, cutplane, cut_distance, controller_speed, [saber_end,saber_end_past], cut_res);
	_create_cut_rigid_body( 1, cube, cutplane, cut_distance, controller_speed, [saber_end,saber_end_past], cut_res);
	_create_cut_pieces_sw.stop()
	
	# allows a bit of save margin where the beat is considered 100% correct
	var beat_accuracy = clamp((1.0 - abs(cube.global_transform.origin.z)) / 0.5, 0.0, 1.0);

	_update_points_sw.start()
	_update_points_from_cut(saber, cube, beat_accuracy, cut_angle_accuracy, cut_distance_accuracy, travel_distance_factor);
	_update_points_sw.stop()

	# reset the movement tracking volume for the next cut
	_controller_movement_aabb[controller.controller_id] = AABB(controller.global_transform.origin, Vector3(0,0,0));

	#vr.show_dbg_info("cut_accuracy", str(beat_accuracy) + ", " + str(cut_angle_accuracy) + ", " + str(cut_distance_accuracy) + ", " + str(travel_distance_factor));
	cube.release();
	
	_cut_cube_sw.stop()

# quiets song when player enters into a wall
func _quiet_song():
	song_player.volume_db = -15.0;

# restores song volume when player leaves wall
func _louden_song():
	song_player.volume_db = 0.0;
	
# accessor method for the side highscore panel (on right side of menu)
func _highscore_panel() -> HighscorePanel:
	return highscore_canvas.ui_control
	
func _endscore_panel() -> EndScorePanel:
	return $EndScore_canvas.ui_control
	
# accessor method for the player name selector UI element
func _name_selector() -> NameSelector:
	return name_selector_canvas.ui_control

func _on_PlayerHead_area_entered(area):
	if area.is_in_group("wall"):
		if not _in_wall:
			_quiet_song();
		
		_in_wall = true;

func _on_PlayerHead_area_exited(area):
	if area.is_in_group("wall"):
		if _in_wall:
			_louden_song();
		
		_in_wall = false;


func _on_EndScore_panel_repeat():
	restart_map()
	$EndScore_canvas.visible = false
	$PauseMenu_canvas.visible = false


func _on_EndScore_panel_goto_mainmenu():
	_clear_track()
	_transition_game_state(GameState.MapSelection)


func _on_Pause_Panel_continue_button():
	$PauseMenu_canvas.visible = false
	$Pause_countdown.visible = true
	track.visible = true
	$Pause_countdown.set_label_text("3")
	yield(get_tree().create_timer(0.5),"timeout")
	$Pause_countdown.set_label_text("2")
	yield(get_tree().create_timer(0.5),"timeout")
	$Pause_countdown.set_label_text("1")
	yield(get_tree().create_timer(0.5),"timeout")
	$Pause_countdown.visible = false
	
	# continue game play
	song_player.play(song_player.get_playback_position());
	_transition_game_state(GameState.Playing)

func _on_BeepSaberMainMenu_difficulty_changed(map_info, diff_name, diff_rank):
	_current_diff_name = diff_name
	_current_diff_rank = diff_rank
	
	# menu loads playlist in _ready(), must yield until scene is loaded
	if not highscore_canvas:
		yield(self,"ready")
	
	highscore_canvas.show()
	_highscore_panel().load_highscores(map_info,diff_rank)

func _on_BeepSaberMainMenu_settings_requested():
	_transition_game_state(GameState.Settings)

func _on_settings_Panel_apply():
	_transition_game_state(GameState.MapSelection)

func _on_Keyboard_highscore_text_input_enter(text):
	if _current_game_state == GameState.NewHighscore:
		_submit_highscore(text)

func _on_NameSelector_name_selected(name):
	if _current_game_state == GameState.NewHighscore:
		_submit_highscore(name)

func _on_LeftLightSaber_cube_collide(cube):
	# check 'playing' to prevent cutting items while resuming from pause menu
	# where items are visible at this point, but there a count down before the
	# song starts to play again
	if song_player.playing:
		_cut_cube(left_controller, left_saber, cube);

func _on_RightLightSaber_cube_collide(cube):
	# check 'playing' to prevent cutting items while resuming from pause menu
	# where items are visible at this point, but there a count down before the
	# song starts to play again
	if song_player.playing:
		_cut_cube(right_controller, right_saber, cube);

func _on_LeftLightSaber_bomb_collide(bomb):
	# check 'playing' to prevent cutting items while resuming from pause menu
	# where items are visible at this point, but there a count down before the
	# song starts to play again
	if song_player.playing:
		_reset_combo()
		bomb.queue_free()
		left_controller.simple_rumble(1.0, 0.15);

func _on_RightLightSaber_bomb_collide(bomb):
	# check 'playing' to prevent cutting items while resuming from pause menu
	# where items are visible at this point, but there a count down before the
	# song starts to play again
	if song_player.playing:
		_reset_combo()
		bomb.queue_free()
		right_controller.simple_rumble(1.0, 0.15);

func _on_BeepCubePool_scene_instanced(cube):
	cube.visible = false
	$Track.add_child(cube)
