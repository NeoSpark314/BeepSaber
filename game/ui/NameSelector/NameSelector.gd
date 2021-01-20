extends Control
class_name NameSelector

onready var _base_button = $NameRow/BaseButton.duplicate()
onready var _name_row = $NameRow

func _ready():
	clear_names()

# adds a name button to the list
# names that are added first show up first in list
func add_name(name):
	var new_button = _base_button.duplicate()
	new_button.text = name
	new_button.connect("pressed",self,"_on_NameButton_pressed",[name])
	_name_row.add_child(new_button)

func clear_names():
	for child in _name_row.get_children():
		child.queue_free()

func _on_NameButton_pressed(name):
	print(name)
