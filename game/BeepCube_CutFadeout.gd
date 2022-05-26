extends RigidBody

onready var _meshinstance : MeshInstance = null

const timer_length = 0.3
const timer_rcp = 1.0/timer_length
var lifetime = 0.0

func _ready():
	for child in get_children():
		if child is MeshInstance:
			_meshinstance = child
			break
	if _meshinstance == null:
		print("WARN: could not find child MeshInstance")
	reset()

func reset():
	lifetime = 0.0
	visible = false
	# set both velocities to zero
	linear_velocity *= 0
	angular_velocity *= 0
	set_process(false)
	set_physics_process(false)

func fire():
	if _meshinstance != null:
		visible = true
		set_process(true)
		set_physics_process(true)

func _process(delta):
	lifetime += delta;
	if lifetime > timer_length:
		reset()
		return
	var f = lifetime*timer_rcp
	_meshinstance.material_override.set_shader_param("cut_vanish",ease(f,2)*0.5)
	
#	f = ease(f,0.1)
#	_meshinstance.scale = Vector3(f, f, f)
