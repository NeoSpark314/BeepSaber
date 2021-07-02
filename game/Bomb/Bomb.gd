extends Note

export var min_speed = 0.5;
onready var _anim = $BombAnimation/AnimationPlayer

func _ready():
	# play the spawn animation when this bomb enters the scene
	_anim.playback_speed = max(min_speed,speed)
	_anim.play("Spawn");
