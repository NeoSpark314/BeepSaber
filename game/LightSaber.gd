# The lightsaber logic is mostly contained in the BeepSaber_Game.gd
# here I only track the extended/sheethed state and provide helper functions to
# trigger the necessary animations
extends Area

# store the saber material in a variable so the main game can set the color on initialize
onready var _anim := $AnimationPlayer;
onready var _main_game = get_tree().get_nodes_in_group("main_game")[0];

# the type of note this saber can cut (set in the game main)
var type = 0;


signal saber_show()
signal saber_hide()
signal saber_quickhide()
signal saber_set_thickness(value)
signal saber_set_color(value)
signal saber_set_trail(value)
signal saber_hit(cube,time_offset)

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
	_anim.play("QuickHide");
	emit_signal("saber_quickhide")

func _process(delta):
	if is_extended():
		#check floor collision for burn mark
		$RayCast.force_raycast_update()
		if $RayCast.is_colliding():
			var raycoli = $RayCast.get_collider()
			if raycoli in get_tree().get_nodes_in_group("floor"):
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
