# The lightsaber logic is mostly contained in the BeepSaber_Game.gd
# here I only track the extended/sheethed state and provide helper functions to
# trigger the necessary animations
extends Area

# store the saber material in a variable so the main game can set the color on initialize
onready var _anim := $AnimationPlayer;

# the type of note this saber can cut (set in the game main)
var type = 0;

func show():
	if (!is_extended()):
		_anim.play("Show");
		get_saber().show()

func get_saber():
	return $saber_holder.get_child(0);

func is_extended():
	return get_saber().is_extended;


func hide():
	# This check makes sure that we are not already in the hidden state
	# (where we translated the light saber to the hilt) to avoid playing it back
	# again from the fully extended light saber position
	if (is_extended() and _anim.current_animation != "QuickHide"):
		_anim.play("Hide");
		get_saber().hide()

func set_thickness(value):
	get_saber().set_thickness(value)
	

func set_color(color):
	get_saber().set_color(color)
	

func _ready():
#	set_saber("res://game/sabers/particles/particles_saber.tscn")
	_anim.play("QuickHide");
	get_saber().quickhide()

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
