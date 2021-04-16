extends "res://game/sabers/default/default_saber.gd"

func _ready():
	set_tail_size(5)

var last_tip_pos = Vector3()
func _process(delta):
	var current_tip_pos = $tip.global_transform.origin
	$CPUParticles.speed_scale = 0.5+(20*(current_tip_pos-last_tip_pos).length())
	$CPUParticles.lifetime = 4+(8*(current_tip_pos-last_tip_pos).length())
	last_tip_pos = current_tip_pos

func hit():
	$hitsound.pitch_scale = rand_range(0.9,1.1)
	$hitsound.play()
	$CPUParticlescut.restart()

func set_thickness(value):
	pass
