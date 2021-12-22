# The lightsaber logic is mostly contained in the BeepSaber_Game.gd
# here I only track the extended/sheethed state and provide helper functions to
# trigger the necessary animations
extends Area

# the type of note this saber can cut (0 -> left, 1 -> right)
export(int, 0, 1) var type = 0

# store the saber material in a variable so the main game can set the color on initialize
onready var _anim := $AnimationPlayer;
onready var _swing_cast := $SwingableRayCast
onready var _main_game = null;

signal saber_show()
signal saber_hide()
signal saber_quickhide()
signal saber_set_thickness(value)
signal saber_set_color(value)
signal saber_set_trail(value)
signal saber_hit(cube,time_offset)
signal cube_collide(cube)
signal bomb_collide(bomb)

func show():
	if (!is_extended()):
		_anim.play("Show");
		emit_signal("saber_show")

func get_saber():
	return $saber_holder.get_child(0);

func is_extended():
	var val = get_saber().get("is_extended")
	if val != null:
		return val
	return false


func hide():
	# This check makes sure that we are not already in the hidden state
	# (where we translated the light saber to the hilt) to avoid playing it back
	# again from the fully extended light saber position
	if (is_extended() and _anim.current_animation != "QuickHide"):
		_anim.play("Hide");
		emit_signal("saber_hide")

func set_thickness(value):
	emit_signal("saber_set_thickness",value)
	

func set_color(color):
	emit_signal("saber_set_color",color)
	
func set_trail(enabled=true):
	emit_signal("saber_set_trail",enabled)

func _ready():
#	set_saber("res://game/sabers/particles/particles_saber.tscn")
	if get_tree().get_nodes_in_group("main_game"):
		_main_game = get_tree().get_nodes_in_group("main_game")[0];
	_anim.play("QuickHide");
	emit_signal("saber_quickhide")
	
	#separates cube collision layers to allow a diferent collider on right/wrong cuts
	yield(get_tree(),"physics_frame")
	if type == 0:
		_swing_cast.set_collision_mask_bit(CollisionLayerConstants.LeftNote_bit, true)
	else:
		_swing_cast.set_collision_mask_bit(CollisionLayerConstants.RightNote_bit, true)
	
func _process(delta):
	if is_extended():
		#check floor collision for burn mark
		$RayCast.force_raycast_update()
		var raycoli = $RayCast.get_collider()
		if raycoli != null and (raycoli.collision_layer & CollisionLayerConstants.Floor_mask):
			var colipoint = $RayCast.get_collision_point()
			raycoli.burn_mark(colipoint,type)
				
func set_saber(saber_path):
	var prenewsaber = load(saber_path)
	var newsaber = prenewsaber.instance()
	for i in $saber_holder.get_children():
		i.queue_free()
	$saber_holder.add_child(newsaber)

func hit(cube):
	var time_offset = (
		(cube._note._time/_main_game._current_info._beatsPerMinute * 60.0)-
		_main_game.song_player.get_playback_position()
		)
	emit_signal("saber_hit",cube,time_offset)

func _on_SwingableRayCast_area_collided(area):
	if area.collision_layer & CollisionLayerConstants.AllNotes_mask:
		emit_signal("cube_collide",area.get_parent().get_parent())
	elif area.collision_layer & CollisionLayerConstants.Bombs_mask:
		emit_signal("bomb_collide",area.get_parent().get_parent())
