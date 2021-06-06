extends ItemList

export(NodePath) var scroll_node
export var enable_joystick_scrolling = true
var v_scroll : VScrollBar = null
var is_mouse_in = false
var relpos = 0.0
var scrollpos = 0.0

# JOYSTICK_SCROLL_THRESHOLD
# Range: 0.0 to 1.0
# Description: Scrolling via the joystick is engadged when the absolute value
# of the joystick's position exceeds this threshold. This prevents accidental
# scroll events occuring from small amounts of noise/movements in the joystick.
const JOYSTICK_SCROLL_THRESHOLD = 0.1

# JOYSTICK_SLOW_SCROLL_SPEED
# Range: 0 to max
# Description: The minimum scroll speed to use when scrolling via the joystick.
# This value is interpolated against the joystick's position and represents the
# scrolling speed nearest to the joystick's resting position.
const JOYSTICK_SLOW_SCROLL_SPEED = 10

# JOYSTICK_FAST_SCROLL_SPEED
# Range: 0 to max
# Description: The maximum scroll speed to use when scrolling via the joystick.
# This value is interpolated against the joystick's position and represents the
# scrolling speed at full throw of the joystick.
const JOYSTICK_FAST_SCROLL_SPEED = 2000

# Called when the node enters the scene tree for the first time.
func _ready():
	scroll_node = get_node(scroll_node)
	if scroll_node == null:
		scroll_node = self
	scroll_node.connect("mouse_entered",self,"_mouse_entered")
	scroll_node.connect("mouse_exited",self,"_mouse_exited")
	v_scroll = scroll_node.get_v_scroll()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if is_mouse_in:
		if vr.button_pressed(vr.BUTTON.RIGHT_INDEX_TRIGGER):
			# Scroll via "click & drag"
			var newpos = -vr.rightController.rotation_degrees.x-(vr.rightController.transform.origin.y*20)
			v_scroll.value += ((relpos-newpos)*20)
			relpos = newpos
		elif enable_joystick_scrolling && ! vr.rightController.is_hand:
			# Scroll via joystick
			var y_joy = vr.rightController.get_joystick_axis(1)
			if abs(y_joy) > JOYSTICK_SCROLL_THRESHOLD:
				# negate sign so positive scroll_amounts will scroll down
				var scroll_amount = lerp(
					JOYSTICK_SLOW_SCROLL_SPEED,
					JOYSTICK_FAST_SCROLL_SPEED,
					abs(y_joy)) * -sign(y_joy) * delta
				v_scroll.value += scroll_amount
	
func _mouse_entered():
	is_mouse_in = true

func _mouse_exited():
	is_mouse_in = false
