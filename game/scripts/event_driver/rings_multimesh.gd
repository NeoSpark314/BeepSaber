tool
extends MultiMeshInstance

var animator = preload("res://game/scripts/event_driver/rings_animator.tscn")

func reset():
	for i in range(multimesh.instance_count):
		if not get_children().empty():
			var a = get_child(i)
			a.zoomed = false
			a.rot_speed = 0
			a.zoom_speed = 0
		var t : Transform = Transform()
		t = t.scaled(Vector3(0.5,0.5,0.5))
		t.origin.z = -i*5
		multimesh.set_instance_transform(i,t)

func _ready():
	reset()
	for i in range(multimesh.instance_count):
		var a = animator.instance()
		a.instance_id = i
		var n = float(multimesh.instance_count-i)/multimesh.instance_count
		a.norm_id = 1.0-n
		a.multimesh = multimesh
		add_child(a)

func rings_out_in():
	for animator in get_children():
		animator.zoom()

func rings_rotate():
	var rand = (randf()*2.0)-1.0
	rand = sqrt(abs(rand))*sign(rand) # Bias values towards 1
	rand *= get_process_delta_time()*20.0
	for animator in get_children():
		animator.respin(rand)
