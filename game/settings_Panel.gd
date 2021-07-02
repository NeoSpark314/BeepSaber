extends Panel

signal apply()

export(NodePath) var game;
onready var file = File.new()
var savedata = {
	thickness=100,
	cube_cuts_falloff=true,
	COLOR_LEFT = Color("ff1a1a"),
	COLOR_RIGHT = Color("1a1aff"),
	saber_tail = true,
	glare = false,
	show_fps = false,
	bombs_enabled = true,
	events = true,
	saber = 0
}
var defaults
const config_path = "user://config.dat"

onready var saber = $ScrollContainer/VBox/SaberTypeRow/saber
onready var glare = $ScrollContainer/VBox/glare
onready var sabe_tail = $ScrollContainer/VBox/saber_tail
onready var saber_thickness = $ScrollContainer/VBox/SaberThicknessRow/saber_thickness
onready var cut_blocks = $ScrollContainer/VBox/cut_blocks
onready var d_background = $ScrollContainer/VBox/d_background
onready var left_saber_col = $ScrollContainer/VBox/SaberColorsRow/left_saber_col
onready var right_saber_col = $ScrollContainer/VBox/SaberColorsRow/right_saber_col
onready var show_fps = $ScrollContainer/VBox/show_fps
onready var bombs_enabled = $ScrollContainer/VBox/bombs_enabled

var sabers = [
	["Default saber","res://game/sabers/default/default_saber.tscn"],
	["Particle sword","res://game/sabers/particles/particles_saber.tscn"]
]

func _ready():
	if game is NodePath:
		game = get_node(game);
	defaults = savedata.duplicate()
	if file.file_exists(config_path):
		file.open(config_path,File.READ)
		savedata = file.get_var(true)
		file.close()
	
	saber.clear()
	for s in sabers:
		saber.add_item(s[0])
	
	#correct controls
	yield(get_tree(),"idle_frame")
	_on_HSlider_value_changed(savedata.thickness,false)
	_on_cut_blocks_toggled(savedata.cube_cuts_falloff,false)
	_on_left_saber_col_color_changed(savedata.COLOR_LEFT,false)
	_on_right_saber_col_color_changed(savedata.COLOR_RIGHT,false)
	_on_saber_tail_toggled(savedata.saber_tail,false)
	if savedata.has("glare"):
		_on_glare_toggled(savedata.glare,false)
	if savedata.has("events"):
		_on_d_background_toggled(savedata.events,false)
	if savedata.has("saber"):
		_on_saber_item_selected(savedata.saber,false)
	if savedata.has("show_fps"):
		_on_show_fps_toggled(savedata.show_fps,false)
	if savedata.has("bombs_enabled"):
		_on_bombs_enabled_toggled(savedata.bombs_enabled,false)

func save_current_settings():
	file.open(config_path,File.WRITE)
	file.store_var(savedata,true)
	file.close()
	
func _on_Button_button_up():
	savedata = defaults
	save_current_settings()
	_ready()


#settings down here
func _on_HSlider_value_changed(value,overwrite=true):
	if game:
		game.left_saber.set_thickness(float(value)/100);
		game.right_saber.set_thickness(float(value)/100);
	
	if overwrite:
		savedata.thickness = value
		save_current_settings()
	else:
		saber_thickness.value = value



func _on_cut_blocks_toggled(button_pressed,overwrite=true):
	if game:
		game.cube_cuts_falloff = button_pressed;
	
	if overwrite:
		savedata.cube_cuts_falloff = button_pressed
		save_current_settings()
	else:
		cut_blocks.pressed = button_pressed


func _on_left_saber_col_color_changed(color,overwrite=true):
	if game:
		game.COLOR_LEFT = color
		game.update_saber_colors()
		game.update_cube_colors()
	
	if overwrite:
		savedata.COLOR_LEFT = color
		save_current_settings()
	else:
		left_saber_col.color = color


func _on_right_saber_col_color_changed(color,overwrite=true):
	if game:
		game.COLOR_RIGHT = color
		game.update_saber_colors()
		game.update_cube_colors()
	
	if overwrite:
		savedata.COLOR_RIGHT = color
		save_current_settings()
	else:
		right_saber_col.color = color


func _on_saber_tail_toggled(button_pressed,overwrite=true):
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		ls.set_trail(button_pressed)
	
	if overwrite:
		savedata.saber_tail = button_pressed
		save_current_settings()
	else:
		sabe_tail.pressed = button_pressed


func _on_glare_toggled(button_pressed,overwrite=true):
	var env_nodes = get_tree().get_nodes_in_group("enviroment")
	for node in env_nodes:
		node.environment.glow_enabled = button_pressed
	
	if overwrite:
		savedata.glare = button_pressed
		save_current_settings()
	else:
		glare.pressed = button_pressed


func _on_d_background_toggled(button_pressed,overwrite=true):
	if game:
		game.disable_events(!button_pressed)
	
	if overwrite:
		savedata.events = button_pressed
		save_current_settings()
	else:
		d_background.pressed = button_pressed

func _on_saber_item_selected(index,overwrite=true):
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		ls.set_saber(sabers[index][1])
	yield(get_tree(),"idle_frame")
	game.update_saber_colors()
	_on_saber_tail_toggled(savedata.saber_tail,false)
		
	if overwrite:
		savedata.saber = index
		save_current_settings()
	else:
		saber.select(index)

func _on_show_fps_toggled(button_pressed,overwrite=true):
	if game:
		game.fps_label.visible = button_pressed
	
	if overwrite:
		savedata.show_fps = button_pressed
		save_current_settings()
	else:
		show_fps.pressed = button_pressed


func _on_bombs_enabled_toggled(button_pressed,overwrite=true):
	if game:
		game.bombs_enabled = button_pressed
	
	if overwrite:
		savedata.bombs_enabled = button_pressed
		save_current_settings()
	else:
		bombs_enabled.pressed = button_pressed
	
#check if A, B and right thumbstick buttons are pressed at the same time to delete settings
func _on_wipe_check_timeout():
	if (game.menu.visible
		and ((vr.button_pressed(vr.BUTTON.A) 
		and vr.button_pressed(vr.BUTTON.B)
		and vr.button_pressed(vr.BUTTON.RIGHT_THUMBSTICK) 
		or Input.is_action_pressed("ui_page_up") and Input.is_action_pressed("ui_page_down")))
		):
			var dir = Directory.new()
			dir.remove(config_path)
			get_tree().change_scene("res://GameMain.tscn")

func _on_apply_pressed():
	emit_signal("apply")
