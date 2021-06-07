# This file contains the main game logic for the BeepSaber demo implementation
#
extends Spatial

# TODO add better state management
enum GameState {
	Bootup,
	MapSelection,
	Playing,
	Paused,
	NewHighscore
}

onready var left_controller := $OQ_ARVROrigin/OQ_LeftController;
onready var right_controller := $OQ_ARVROrigin/OQ_RightController;

onready var left_saber := $OQ_ARVROrigin/OQ_LeftController/LeftLightSaber;
onready var right_saber := $OQ_ARVROrigin/OQ_RightController/RightLightSaber;

onready var ui_raycast := $OQ_ARVROrigin/OQ_RightController/Feature_UIRayCast;

onready var right_highscore_canvas := $RightHighscores_Canvas
onready var mid_highscore_canvas := $MidHighscores_Canvas
onready var name_selector_canvas := $NameSelector_Canvas
onready var keyboard := $OQ_UI2DKeyboard

onready var cube_template = preload("res://game/BeepCube.tscn").instance();
onready var wall_template = preload("res://game/Wall/Wall.tscn").instance();
onready var cube_material_template = preload("res://game/BeepCube_new_material.material");

var cube_left = null
var cube_right = null

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


var _high_score = 0;

var _current_points = 0;
var _current_multiplier = 1;
var _current_combo = 0;

var _in_wall = false;

var _right_notes = 0;
var _wrong_notes = 0;

#settings
var cube_cuts_falloff = true
var max_cutted_cubes = 32

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

	_display_points();
	$event_driver.update_colors()
	if _current_map._events.size() > 0:
		$event_driver.set_all_off()
	else:
		$event_driver.set_all_on()

	for c in $Track.get_children():
		c.visible = false;
		$Track.remove_child(c);
		c.queue_free();
	
	$MainMenu_OQ_UI2DCanvas.visible = false;
	$Settings_canvas.visible = false;
	$Online_library.visible = false;
	$OQ_UI2DKeyboard.visible = false;
	$OQ_UI2DKeyboard_main.visible = false;
	right_highscore_canvas.visible = false;
	mid_highscore_canvas.visible = false;
	name_selector_canvas.visible = false;

	track.visible = true
	left_saber.show();
	right_saber.show();
	$Track.visible = true;
	ui_raycast.visible = false;
	$Multiplier_Label.visible=true;
	$Point_Label.visible=true;
	$Percent.visible=true;


func continue_map():
	song_player.play(song_player.get_playback_position());
	$Track.visible = true;
	$MainMenu_OQ_UI2DCanvas.visible = false;
	$Settings_canvas.visible = false;
	$Online_library.visible = false;
	right_highscore_canvas.visible = false;
	mid_highscore_canvas.visible = false;
	name_selector_canvas.visible = false;

	left_saber.show();
	right_saber.show();
	ui_raycast.visible = false;


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


func show_menu():
	if ($MainMenu_OQ_UI2DCanvas.visible): return;

	if (song_player.playing):
		song_player.stop();
		_main_menu.set_mode_continue();
	else:
		_main_menu.set_mode_game_start();
		left_saber.hide();
		right_saber.hide();
		$Multiplier_Label.visible=false;
		$Point_Label.visible=false;
		$Percent.visible=false;

	$Track.visible = false;
	ui_raycast.visible = true;
	$MainMenu_OQ_UI2DCanvas.visible = true;
	$Settings_canvas.visible = true;
	$Online_library.visible = true;
	
func show_pause_menu():
	if ($PauseMenu_canvas.visible or not song_player.playing):
		return;

	if (song_player.playing):
#		print(_current_info)
		song_player.stop();
		$PauseMenu_canvas.ui_control.set_pause_text("%s By %s\nMap author: %s" % [_current_info["_songName"],_current_info["_songAuthorName"],_current_info["_levelAuthorName"]],menu._map_difficulty_name)
	
	# Hide the track (cubes, walls, etc) while showing the pause menu
	track.visible = false;

	ui_raycast.visible = true;
	$PauseMenu_canvas.visible = true;
	$Settings_canvas.visible = true;
	mid_highscore_canvas.visible = false;
	name_selector_canvas.visible = false;
	keyboard.visible = false;
	
# This function will transitioning the game from it's current state into
# the provided 'next_state'. In the future, this function could make
# calls on entered/exited methods to help orchestrate more orderly
# state transitions (most likely part of a future update)
func _transition_game_state(next_state):
	# TODO implement state exit logic
	# TODO implement state entered logic
	_current_game_state = next_state

# when the song ended we want to display the current score and
# the high score
func _end_song_display():
	if (_current_points > _high_score):
		_high_score = _current_points;

	var current_percent = int((_right_notes/(_right_notes+_wrong_notes))*100)
	
	$EndScore_canvas.visible = true
	$EndScore_canvas.ui_control.show_score(_current_points,_high_score,current_percent,"%s By %s\n%s     Map author: %s" % [_current_info["_songName"],_current_info["_songAuthorName"],menu._map_difficulty_name,_current_info["_levelAuthorName"]])
	ui_raycast.visible = true;
	song_player.stop();
	
	if Highscores.is_new_highscore(_current_info,_current_diff_rank,_current_points):
		_on_new_highscore()
	else:
		show_menu();

func _on_new_highscore():
	_transition_game_state(GameState.NewHighscore)
	
	# populate middle highscore panel with records
#	_mid_highscore_panel().load_highscores(
#		_current_info,_current_diff_rank)
	
	# allows player to click on UI elements
	ui_raycast.visible = true;
	
	# show/hide applicable UI elements
	$Track.visible = false
	$MainMenu_OQ_UI2DCanvas.visible = false
	mid_highscore_canvas.visible = true
	right_highscore_canvas.visible = false
	name_selector_canvas.visible = true;
	keyboard.visible = true
	
	# fill name selector with most recent player names
	_name_selector().clear_names()
	# WARNING: The get_all_player_names() method could become
	# costly for a very large highscore database (ie. many
	# songs and many difficulties). If that ever becomes a
	# concern, we may want to consider caching a list of the
	# N most recent players instead.
	for player_name in Highscores.get_all_player_names():
		_name_selector().add_name(player_name)
	
# call this method to submit a new highscore to the database
func _submit_highscore(player_name):
	if _current_game_state == GameState.NewHighscore:
		Highscores.add_highscore(
			_current_info,
			_current_diff_rank,
			player_name,
			_current_points)
			
		Highscores.save_hs_table()
			
		show_menu()

const beat_distance = 4.0;
const beats_ahead = 4.0;
const CUBE_DISTANCE = 0.5;
const CUBE_ROTATIONS = [180, 0, 270, 90, -135, 135, -45, 45, 0];

func _spawn_cube(note, current_beat):
	var cube = null;
	if (note._type == 0):
		cube = cube_left.duplicate();
	elif (note._type == 1):
		cube = cube_right.duplicate();
	else:
		return;

	if menu._map_difficulty_noteJumpMovementSpeed > 0:
		cube.speed = float(menu._map_difficulty_noteJumpMovementSpeed)/9
	track.add_child(cube);

	var line = -(CUBE_DISTANCE * 3.0 / 2.0) + note._lineIndex * CUBE_DISTANCE;
	var layer = CUBE_DISTANCE + note._lineLayer * CUBE_DISTANCE;

	var rotation_z = deg2rad(CUBE_ROTATIONS[note._cutDirection]);

	var distance = note._time - current_beat;

	cube.transform.origin = Vector3(
		line,
		CUBE_HEIGHT_OFFSET + layer,
		-distance * beat_distance);

	cube._cube_mesh_orientation.rotation.z = rotation_z;
	if note._cutDirection==8:
		cube._cube_mesh_orientation.rotation.y = deg2rad(180);

	cube._note = note;

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

	var current_time = song_player.get_playback_position();
	
	var current_beat = current_time * _current_info._beatsPerMinute / 60.0;

	# spawn notes
	var n =_current_map._notes;
	while (_current_note < n.size() && n[_current_note]._time <= current_beat+beats_ahead):
		_spawn_cube(n[_current_note], current_beat);
		_current_note += 1;

	# spawn obstacles (walls)
	var o = _current_map._obstacles;
	while (_current_obstacle < o.size() && o[_current_obstacle]._time <= current_beat+beats_ahead):
		_spawn_wall(o[_current_obstacle], current_beat);
		_current_obstacle += 1;

	var speed = Vector3(0.0, 0.0, beat_distance * _current_info._beatsPerMinute / 60.0) * dt;

	for c in track.get_children():
		c.translate(speed);

		var depth = CUBE_DISTANCE
		if c is Wall:
			# compute wall's depth based on duration
			depth = beat_distance * c._obstacle._duration

		# remove children that go to far
		if ((c.global_transform.origin.z - depth) > 2.0):
			if not c is Wall:
				_reset_combo();
			c.queue_free();

	var e = _current_map._events;
	while (_current_event < e.size() && e[_current_event]._time <= current_beat):#+beats_ahead):
		_spawn_event(e[_current_event], current_beat);
		_current_event += 1;

	if (song_player.get_playback_position() >= song_player.stream.get_length()-1):
		_end_song_display();

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
	if (vr.button_just_released(vr.BUTTON.ENTER)):
		show_pause_menu();

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

	cube_left = cube_template.duplicate();
	cube_right = cube_template.duplicate();
	cube_left.duplicate_create(COLOR_LEFT);
	cube_right.duplicate_create(COLOR_RIGHT);
	update_cube_colors()

	update_saber_colors()
	
	# This is a workaround for now to orient correctly for the Vive controllers
	if (vr.active_arvr_interface_name == "OpenVR"):
		left_saber.rotation_degrees.x = -90;
		right_saber.rotation_degrees.x = -90;
		ui_raycast.rotation_degrees.x = 0;

	$MainMenu_OQ_UI2DCanvas.visible = false;
	$Settings_canvas.visible = false;
	$Online_library.visible = false;
	$OQ_UI2DKeyboard.visible = false;
	$OQ_UI2DKeyboard_main.visible = false;
	mid_highscore_canvas.visible = false;
	right_highscore_canvas.visible = false;
	name_selector_canvas.visible = false;
	show_menu();

func update_cube_colors():
	cube_left.update_color_only(COLOR_LEFT);
	cube_right.update_color_only(COLOR_RIGHT);

func update_saber_colors():
	left_saber.set_color(COLOR_LEFT)
	left_saber.type = 0;
	right_saber.set_color(COLOR_RIGHT)
	right_saber.type = 1;
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
func _create_cut_rigid_body(_sign, cube : Spatial, cutplane : Plane, cut_distance, controller_speed, saber_ends):
	if not cube_cuts_falloff: 
		return
	#remove cutted cubes when there are more than max_cutted_cubes
	var cutted_cubes_group = get_tree().get_nodes_in_group("cutted_cube")
	if cutted_cubes_group.size() >= max_cutted_cubes:
		cutted_cubes_group[0].remove_from_group("cutted_cube")
		cutted_cubes_group[0].queue_free()
		
	var rigid_body_half = RigidBody.new();
	rigid_body_half.add_to_group("cutted_cube")
	rigid_body_half.collision_layer = 8
	rigid_body_half.collision_mask = 0
	rigid_body_half.gravity_scale = 2
	
	# the original cube mesh
	var cutted_cube = MeshInstance.new();
	cutted_cube.mesh = cube._mesh;
	cutted_cube.transform = cube._cube_mesh_orientation.transform;
	cutted_cube.material_override = cube._mat.duplicate()
	
	#calculate angle and position of the cut
	cutted_cube.material_override.set_shader_param("cutted",true)
	cutted_cube.material_override.set_shader_param("inverted_cut",!bool((_sign+1)/2))
	var saber_end_mov = saber_ends[0]-saber_ends[1]
	var saber_end_angle = rad2deg(Vector2(saber_end_mov.x,saber_end_mov.y).angle())
	var saber_end_angle_rel = (int(((saber_end_angle+90)+(360-cutted_cube.rotation_degrees.z))+180)%360)-180
	cutted_cube.material_override.set_shader_param("cut_angle",saber_end_angle_rel)
	if saber_end_angle_rel > 90 or saber_end_angle_rel < -90:
		cutted_cube.material_override.set_shader_param("cut_pos",-cut_distance*3)
	else:
		cutted_cube.material_override.set_shader_param("cut_pos",cut_distance*3)

	# transform the normal into the orientation of the actual cube mesh
	var normal = cutted_cube.transform.basis.inverse() * cutplane.normal;

	# Next we are adding a simple collision cube to the rigid body. Note that
	# his is really just a very crude approximation of the actual cut geometry
	# but for now it's enough to give them some physics behaviour
	var coll = CollisionShape.new();
	coll.shape = BoxShape.new();
	coll.shape.extents = Vector3(0.25, 0.25, 0.125);
	coll.look_at_from_position(-cutplane.normal*_sign*0.125, cutplane.normal, Vector3(0,1,0));
	rigid_body_half.add_child(coll);

	# set a phyiscs material for some more bouncy behaviour
	rigid_body_half.physics_material_override = load("res://game/BeepCube_Cut.phymat");

	rigid_body_half.add_child(cutted_cube);
	add_child(rigid_body_half);
	rigid_body_half.global_transform = cube.global_transform;

	# some impulse so the cube halfs get some movement
#	if saber_end_angle_rel > 90 or saber_end_angle_rel < -90:
	rigid_body_half.apply_central_impulse((_sign) * cutplane.normal +  controller_speed);
#	else:
#		rigid_body_half.apply_central_impulse((_sign) * cutplane.normal +  controller_speed);

	# delete the rigid body after 2 seconds; this only works here because we are
	# at the end of this function and do not need the rigid body for anything else
	yield(get_tree().create_timer(2.0), "timeout")
	if rigid_body_half:
		rigid_body_half.queue_free()



func _reset_combo():
	_current_multiplier = 1;
	_current_combo = 0;
	_wrong_notes += 1.0
	_display_points();


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
	var normalized_points = clamp(points/100, 0.0, 1.0);
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

	_create_cut_rigid_body(-1, cube, cutplane, cut_distance, controller_speed, [saber_end,saber_end_past]);
	_create_cut_rigid_body( 1, cube, cutplane, cut_distance, controller_speed, [saber_end,saber_end_past]);
	
	# allows a bit of save margin where the beat is considered 100% correct
	var beat_accuracy = clamp((1.0 - abs(cube.global_transform.origin.z)) / 0.5, 0.0, 1.0);

	_update_points_from_cut(saber, cube, beat_accuracy, cut_angle_accuracy, cut_distance_accuracy, travel_distance_factor);

	# reset the movement tracking volume for the next cut
	_controller_movement_aabb[controller.controller_id] = AABB(controller.global_transform.origin, Vector3(0,0,0));

	#vr.show_dbg_info("cut_accuracy", str(beat_accuracy) + ", " + str(cut_angle_accuracy) + ", " + str(cut_distance_accuracy) + ", " + str(travel_distance_factor));
	# delete the original cube; we have two new halfs created above
	cube.queue_free();

# quiets song when player enters into a wall
func _quiet_song():
	song_player.volume_db = -15.0;

# restores song volume when player leaves wall
func _louden_song():
	song_player.volume_db = 0.0;
	
# accessor method for the side highscore panel (on right side of menu)
func _right_highscore_panel() -> HighscorePanel:
	return right_highscore_canvas.ui_control
	
# accessor method for the main highscore panel (in middle of screen)
func _mid_highscore_panel() -> HighscorePanel:
	return mid_highscore_canvas.ui_control
	
# accessor method for the player name selector UI element
func _name_selector() -> NameSelector:
	return name_selector_canvas.ui_control
	
func _on_LeftLightSaber_area_entered(area : Area):
	if song_player.playing and (area.is_in_group("beepcube")):
		_cut_cube(left_controller, left_saber, area.get_parent().get_parent());


func _on_RightLightSaber_area_entered(area : Area):
	if song_player.playing and (area.is_in_group("beepcube")):
		_cut_cube(right_controller, right_saber, area.get_parent().get_parent());

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
	$MainMenu_OQ_UI2DCanvas.ui_control.set_mode_game_start()
	restart_map()
	$EndScore_canvas.visible = false
	$PauseMenu_canvas.visible = false


func _on_EndScore_panel_goto_mainmenu():
	$MainMenu_OQ_UI2DCanvas.ui_control.set_mode_game_start()
	for c in $Track.get_children():
		c.visible = false;
		$Track.remove_child(c);
		c.queue_free();
	show_menu()
	$EndScore_canvas.visible = false
	$PauseMenu_canvas.visible = false


func _on_Pause_Panel_continue_button():
	$PauseMenu_canvas.visible = false
	$Settings_canvas.visible = false;
	$Pause_countdown.visible = true
	track.visible = true
	$Pause_countdown.set_label_text("3")
	yield(get_tree().create_timer(0.5),"timeout")
	$Pause_countdown.set_label_text("2")
	yield(get_tree().create_timer(0.5),"timeout")
	$Pause_countdown.set_label_text("1")
	yield(get_tree().create_timer(0.5),"timeout")
	$Pause_countdown.visible = false
	continue_map()


# FIXME this doesn't always seem to get called :(
func _on_BeepSaber_tree_exiting():
	# save highscores before quiting game
	Highscores.save_hs_table()

func _on_BeepSaberMainMenu_difficulty_changed(map_info, diff_name, diff_rank):
	_current_diff_name = diff_name
	_current_diff_rank = diff_rank
	
	# menu loads playlist in _ready(), must yield until scene is loaded
	if not right_highscore_canvas:
		yield(self,"ready")
	
	right_highscore_canvas.show()
	_right_highscore_panel().load_highscores(map_info,diff_rank)

func _on_OQ_UI2DKeyboard_text_input_enter(text):
	if _current_game_state == GameState.NewHighscore:
		_submit_highscore(text)

func _on_NameSelector_name_selected(name):
	if _current_game_state == GameState.NewHighscore:
		_submit_highscore(name)
