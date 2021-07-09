extends Node

# Set in ring_multimesh.gd
var multimesh : MultiMesh
var instance_id : int
var norm_id : float

var rot_speed : float = 0.0

var target_zoom_dist : float
var zoom_speed = 0.0


func _ready():
	target_zoom_dist = instance_id*0.1

const damp = pow(0.95, 120.0);

func _process(delta):
	if is_zero_approx(rot_speed) and is_zero_approx(zoom_speed):
		return
	var delta_damp = pow(0.2,delta)
	rot_speed *= delta_damp
	zoom_speed *= delta_damp
	var t = multimesh.get_instance_transform(instance_id)
	t = t.rotated(Vector3.FORWARD,rot_speed)
	t = t.translated(-Vector3.FORWARD*zoom_speed)
	
	multimesh.set_instance_transform(instance_id,t)

func respin(new_rand_target_rot):
	yield(get_tree().create_timer(norm_id*0.5),"timeout")
	var norm = (norm_id*0.5)+0.49
	rot_speed += new_rand_target_rot*norm

var zoomed = false
func zoom():
	yield(get_tree().create_timer(norm_id*0.3),"timeout")
	if zoomed: zoom_speed = target_zoom_dist
	else: zoom_speed = -target_zoom_dist
	
	zoomed = !zoomed
