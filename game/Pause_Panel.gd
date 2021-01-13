extends Panel

signal continue_button()
signal restart_button()
signal mainmenu_button()

func set_pause_text(song_name,dificulty=""):
	$Label.text = "Current song:\n%s\n%s" % [song_name,dificulty]

func _on_continue_button_up():
	emit_signal("continue_button")

func _on_restart_button_up():
	emit_signal("restart_button")

func _on_mainmenu_button_up():
	emit_signal("mainmenu_button")
