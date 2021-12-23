extends Node

onready var hover_stream := $HoverStream
onready var click_stream := $ClickStream

func attach_children(node: Node, include_buttons = true):
	for child in node.get_children():
		if include_buttons and child is Button:
			attach_button(child)
		
		attach_children(child, include_buttons)

func attach_button(button: Button):
	button.connect("mouse_entered",self,"_on_button_hovered",[button])
	button.connect("pressed",self,"_on_button_pressed")

# prevent spuratic clicking when mouse enters/exits a control quickly
const HOVER_DEBOUNCE_TIME_MS = 200
var _prev_hovered_ctrl = null
var _prev_hover_time = 0
func _on_button_hovered(control):
	# prevent rapid hover sound effects that can occur when the mouse is
	# very close to the edge of the control node (ie. enters/exists quickly)
	var time_now_ms = OS.get_ticks_msec()
	if _prev_hovered_ctrl != control or (time_now_ms - _prev_hover_time) > HOVER_DEBOUNCE_TIME_MS:
		hover_stream.play()
	
	_prev_hovered_ctrl = control
	_prev_hover_time = time_now_ms

func _on_button_pressed():
	click_stream.play()
