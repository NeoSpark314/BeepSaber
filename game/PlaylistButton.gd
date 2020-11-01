extends Button

var pl

signal pressed_pl(pl)

func _ready():
	text = pl.Name


func _on_PlaylistButton_pressed():
	emit_signal("pressed_pl", pl)
