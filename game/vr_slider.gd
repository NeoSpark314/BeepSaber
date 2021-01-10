extends Control

export(NodePath) var scroll_node
var is_mouse_in = false
var relpos = 0.0
var scrollpos = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	scroll_node = get_node(scroll_node)
	if scroll_node == null: scroll_node = self
	scroll_node.connect("mouse_entered",self,"_mouse_entered")
	scroll_node.connect("mouse_exited",self,"_mouse_exited")
	scroll_node = scroll_node.get_v_scroll()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if is_mouse_in:
		if vr.button_just_pressed(vr.BUTTON.RIGHT_INDEX_TRIGGER):
			relpos = vr.rightController.rotation_degrees.x
			scrollpos = scroll_node.value
		if vr.button_pressed(vr.BUTTON.RIGHT_INDEX_TRIGGER):
			scroll_node.value = scrollpos-((relpos-vr.rightController.rotation_degrees.x)*10)

func _mouse_entered():
	is_mouse_in = true
func _mouse_exited():
	is_mouse_in = false
