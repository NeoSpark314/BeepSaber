extends Panel

export (NodePath) var beat_saver_canvas_path
export (NodePath) var beat_sage_canvas_path

onready var beat_saver_button := $Margin/VBox/Grid/BeatSaverButton
onready var beat_sage_button := $Margin/VBox/Grid/BeatSageButton

var _beat_saver_canvas = null
var _beat_sage_canvas = null

func _ready():
	UI_AudioEngine.attach_children(self)
	# initialize items related to Beat Saver UI Dialog
	_beat_saver_canvas = get_node(beat_saver_canvas_path)
	if is_instance_valid(_beat_saver_canvas):
		_beat_saver_canvas.connect(
			'visibility_changed',
			self,
			'_on_MapSourceUI_closed',
			[_beat_saver_canvas])
	else:
		vr.log_warning('_beat_saver_canvas is null')
		beat_saver_button.disabled = true
		
	# initialize items related to Beat Sage UI Dialog
	_beat_sage_canvas = get_node(beat_sage_canvas_path)
	if is_instance_valid(_beat_saver_canvas):
		_beat_sage_canvas.connect(
			'visibility_changed',
			self,
			'_on_MapSourceUI_closed',
			[_beat_sage_canvas])
	else:
		vr.log_warning('_beat_sage_canvas is null')
		beat_sage_button.disabled = true

# override hide() method to handle case where UI is inside a OQ_UI2DCanvas
func hide():
	var parent_canvas = self
	while parent_canvas != null:
		if parent_canvas is OQ_UI2DCanvas:
			break
		parent_canvas = parent_canvas.get_parent()
		
	if parent_canvas == null:
		self.visible = false
	else:
		parent_canvas.hide()
		
# override show() method to handle case where UI is inside a OQ_UI2DCanvas
func show():
	var parent_canvas = self
	while parent_canvas != null:
		if parent_canvas is OQ_UI2DCanvas:
			break
		parent_canvas = parent_canvas.get_parent()
		
	if parent_canvas == null:
		self.visible = true
	else:
		parent_canvas.show()

func _on_BeatSaverButton_pressed():
	_beat_saver_canvas.show()
	self.hide()

func _on_BeatSageButton_pressed():
	_beat_sage_canvas.show()
	self.hide()

func _on_MapSourceUI_closed(ui_panel):
	if ! ui_panel.visible:
		self.show()
