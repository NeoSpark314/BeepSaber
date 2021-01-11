extends Panel

export(NodePath) var game;
onready var file = File.new()
var savedata = {
	thickness=100,
	cube_cuts_falloff=true,
	COLOR_LEFT = Color("ff1a1a"),
	COLOR_RIGHT = Color("1a1aff"),
	saber_tail = true,
	glare = false,
	events = true
}
var defaults
const config_path = "user://config.dat"

func _ready():
	if game is NodePath:
		game = get_node(game);
	defaults = savedata.duplicate()
	if file.file_exists(config_path):
		file.open(config_path,File.READ)
		savedata = file.get_var(true)
		file.close()
	
	#correct controls
	yield(get_tree(),"idle_frame")
	_on_HSlider_value_changed(savedata.thickness,false)
	_on_cuttedBlocks_toggled(savedata.cube_cuts_falloff,false)
	_on_left_sable_col_color_changed(savedata.COLOR_LEFT,false)
	_on_right_sable_col_color_changed(savedata.COLOR_RIGHT,false)
	_on_saber_tail_toggled(savedata.saber_tail,false)
	if savedata.has("glare"):
		_on_glare_toggled(savedata.glare,false)
	if savedata.has("events"):
		_on_d_background_toggled(savedata.events,false)

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
	game.left_saber.set_thickness(float(value)/100);
	game.right_saber.set_thickness(float(value)/100);
	
	if overwrite:
		savedata.thickness = value
		save_current_settings()
	else:
		$saber_thicknes.value = value



func _on_cuttedBlocks_toggled(button_pressed,overwrite=true):
	game.cube_cuts_falloff = button_pressed;
	
	if overwrite:
		savedata.cube_cuts_falloff = button_pressed
		save_current_settings()
	else:
		$cuttedBlocks.pressed = button_pressed


func _on_left_sable_col_color_changed(color,overwrite=true):
	game.COLOR_LEFT = color
	game.update_saber_colors()
	game.update_cube_colors()
	
	if overwrite:
		savedata.COLOR_LEFT = color
		save_current_settings()
	else:
		$left_sable_col.color = color


func _on_right_sable_col_color_changed(color,overwrite=true):
	game.COLOR_RIGHT = color
	game.update_saber_colors()
	game.update_cube_colors()
	
	if overwrite:
		savedata.COLOR_RIGHT = color
		save_current_settings()
	else:
		$right_sable_col.color = color


func _on_saber_tail_toggled(button_pressed,overwrite=true):
	if button_pressed:
		game.left_saber.set_tail_size(3)
		game.right_saber.set_tail_size(3)
	else:
		game.left_saber.set_tail_size(0)
		game.right_saber.set_tail_size(0)
		
	if overwrite:
		savedata.saber_tail = button_pressed
		save_current_settings()
	else:
		$saber_tail.pressed = button_pressed


func _on_glare_toggled(button_pressed,overwrite=true):
	var env = get_tree().get_nodes_in_group("enviroment")[0]
	env.environment.glow_enabled = button_pressed
	
	if overwrite:
		savedata.glare = button_pressed
		save_current_settings()
	else:
		$glare.pressed = button_pressed


func _on_d_background_toggled(button_pressed,overwrite=true):
	game.disable_events(!button_pressed)
	
	if overwrite:
		savedata.events = button_pressed
		save_current_settings()
	else:
		$d_background.pressed = button_pressed

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
