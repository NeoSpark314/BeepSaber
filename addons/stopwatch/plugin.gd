tool
extends EditorPlugin

var StopwatchPanel = preload("res://addons/stopwatch/StopwatchPanel.tscn")
var panel = null

func _enter_tree():
	panel = StopwatchPanel.instance()
	add_control_to_bottom_panel(panel, "Stopwatches")

func _exit_tree():
	remove_control_from_bottom_panel(panel)
	panel.free()
