extends Note

export var min_speed = 0.5;
onready var _anim = $BombAnimation/AnimationPlayer

var collision_disabled = false setget _set_colision_disabled

func _ready():
	# play the spawn animation when this bomb enters the scene
	_anim.playback_speed = max(min_speed,speed)
	_anim.play("Spawn");

func _set_colision_disabled(value):
	collision_disabled = value
	$BombAnimation/Area/CollisionShape.disabled = value
