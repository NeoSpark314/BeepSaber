extends Spatial

var is_extended = false
var trail = true

onready var _mat : ShaderMaterial = $LightSaber_Mesh.material_override;

onready var _anim = $AnimationPlayer
onready var imm_geo = $ImmediateGeometry
var saber_holder

func _ready():
	saber_holder = get_parent().get_parent()
	saber_holder.connect("saber_show",self,"show")
	saber_holder.connect("saber_hide",self,"hide")
	saber_holder.connect("saber_quickhide",self,"quickhide")
	saber_holder.connect("saber_set_thickness",self,"set_thickness")
	saber_holder.connect("saber_set_color",self,"set_color")
	saber_holder.connect("saber_set_trail",self,"set_trail")
	saber_holder.connect("saber_hit",self,"hit")
	imm_geo.material_override = imm_geo.material_override.duplicate()
	remove_child(imm_geo)
	get_tree().get_root().add_child(imm_geo)
	quickhide()
	
func _exit_tree():
	imm_geo.queue_free()
	
func set_color(color):
	_mat.set_shader_param("color", color);
	imm_geo.material_override.set_shader_param("color", color);
func set_thickness(value):
	$LightSaber_Mesh.scale.x = value
	$LightSaber_Mesh.scale.y = value
func set_trail(enabled=true):
	trail = enabled

func show():
	_anim.play("Show");
	is_extended = true;
	
func hide():
	_anim.play("Hide");
	is_extended = false;
	
func quickhide():
	_anim.play("QuickHide");
	is_extended = false;

func hit(cube,time_offset):
	if time_offset>0.2 or time_offset<-0.05:
		$hitsound.play()
	else:
		if time_offset <= 0:
			$hitsound.play(-time_offset)
		else:
			yield(get_tree().create_timer(time_offset),"timeout")
			$hitsound.play()

func set_tail_size(size=3):
	max_pos = size
	
var last_pos = []
var max_pos = 3
func _process(delta):
	if is_extended and trail:
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
