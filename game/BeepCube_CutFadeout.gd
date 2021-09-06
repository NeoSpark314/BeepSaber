extends RigidBody

onready var _meshinstance = get_child(1)
onready var _mat = _meshinstance.material_override

const timer_length = 0.3
const timer_rcp = 1.0/timer_length
var lifetime = 0.0

func _process(delta):
	lifetime += delta;
	if lifetime > timer_length:
		queue_free()
		return
	var f = lifetime*timer_rcp
	_mat.set_shader_param("cut_vanish",ease(f,2)*0.5)
	
#	f = ease(f,0.1)
#	_meshinstance.scale = Vector3(f, f, f)
