extends Spatial

func _ready():
	var c1 = $CPUParticles
	var c2 = $CPUParticles2
	c1.one_shot = true
	c2.one_shot = true
	c1.emitting = true
	c2.emitting = true


func _on_Timer_timeout():
	queue_free()
