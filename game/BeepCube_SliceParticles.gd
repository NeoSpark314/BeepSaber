extends Spatial
class_name BeepCubeSliceParticles

onready var c1 := $CPUParticles
onready var c2 := $CPUParticles2

func _ready():
	c1.one_shot = true
	c2.one_shot = true
	reset()

func reset():
	visible = false
	c1.emitting = false
	c2.emitting = false
	c1.restart()
	c2.restart()

func fire():
	visible = true
	c1.emitting = true
	c2.emitting = true
