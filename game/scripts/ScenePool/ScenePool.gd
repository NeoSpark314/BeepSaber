extends Node

# emitted when the pool intances a scene for the first time
signal scene_instanced(scene)

export (PackedScene) var Scene = null
export (int) var pool_size = 10

onready var LinkedList := preload("res://game/scripts/LinkedList.gd")
onready var _free_list := LinkedList.new()

func _ready():
	if Scene == null:
		push_error("Scene is null ('%s' ScenePool)" % name)
		return
	
	for _i in range(pool_size):
		var new_scene = Scene.instance()
		if new_scene.connect("scene_released",self,"_on_scene_released",[new_scene]) != OK:
			push_error("failed to connect 'scene_released' signal. Scene's must emit this signal for the ScenePool to function properly.")
			return
		emit_signal("scene_instanced",new_scene)
		_free_list.push_back(new_scene)

func acquire():
	return _free_list.pop_front()

func _on_scene_released(scene):
	_free_list.push_back(scene)
