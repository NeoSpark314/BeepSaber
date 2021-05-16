extends "res://game/sabers/default/default_saber.gd"

func _ready():
	saber_holder.connect("saber_hit",self,"hit_particles")
	set_tail_size(5)

var last_tip_pos = Vector3()
func _process(delta):
	var current_tip_pos = $tip.global_transform.origin
	$CPUParticles.speed_scale = 0.5+(20*(current_tip_pos-last_tip_pos).length())
	$CPUParticles.lifetime = 4+(8*(current_tip_pos-last_tip_pos).length())
	last_tip_pos = current_tip_pos

func hit_particles(cube,time_offset):
	$CPUParticlescut.restart()
	$hitsound.pitch_scale = rand_range(0.9,1.1)

func set_thickness(value): #ignore set thinkness on this saber
	pass
