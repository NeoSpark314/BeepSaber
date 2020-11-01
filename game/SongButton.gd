extends Button

var id
var info

signal pressed_id(id)

func _ready():
	if info:
		text = "%s - %s" % [info._songAuthorName, info._songName]
	else:
		text = "Failed to get song info"


func _on_SongButton_pressed():
	emit_signal("pressed_id", id)
