# The lightsaber logic is mostly contained in the BeepSaber_Game.gd
# here I only track the extended/sheethed state and provide helper functions to
# trigger the necessary animations
extends Area

# store the saber material in a variable so the main game can set the color on initialize
onready var _mat : ShaderMaterial = $LightSaber_Mesh.mesh.surface_get_material(0);
onready var _anim := $AnimationPlayer;

# the type of note this saber can cut (set in the game main)
var type = 0;

onready var imm_geo = $ImmediateGeometry

func show():
	if (!is_extended()):
		_anim.play("Show");


func is_extended():
	return $LightSaber_Mesh.translation.y > 0.1;


func hide():
	# This check makes sure that we are not already in the hidden state
	# (where we translated the light saber to the hilt) to avoid playing it back
	# again from the fully extended light saber position
	if (is_extended() and _anim.current_animation != "QuickHide"):
		_anim.play("Hide");

func set_thickness(value):
	$LightSaber_Mesh.scale.x = value
	$LightSaber_Mesh.scale.y = value
	
func set_tail_size(size=3):
	max_pos = size

func set_color(color):
	_mat.set_shader_param("color", color);
	imm_geo.material_override.set_shader_param("color", color);
	

func _ready():
	imm_geo.material_override = imm_geo.material_override.duplicate()
	_anim.play("QuickHide");
	remove_child(imm_geo)
	get_tree().get_root().add_child(imm_geo)

var last_pos = []
var max_pos = 3
func _process(delta):
	if is_extended():
		var pos = [$base.global_transform.origin,$tip.global_transform.origin]
		imm_geo.clear()
		imm_geo.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		for i in range(last_pos.size()):
			var posA = pos
			if i > 0:
				posA = last_pos[i-1]
			var posB = last_pos[i]
			
			imm_geo.add_vertex(pos[0])
			imm_geo.add_vertex(posA[1])
			imm_geo.add_vertex(posB[1])
			
		imm_geo.end()
		
		last_pos.insert(0,pos)
		while last_pos.size() > max_pos:
			last_pos.remove(last_pos.size()-1)
	else:
		imm_geo.clear()
	
func get_tip():
	return $tip.global_transform.origin
