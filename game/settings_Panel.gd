extends Panel

export(NodePath) var game;


func _ready():
	game = get_node(game);


func _on_HSlider_value_changed(value):
	game.left_saber.set_thickness(float(value)/100);
	game.right_saber.set_thickness(float(value)/100);


func _on_cuttedBlocks_toggled(button_pressed):
	game.cube_cuts_falloff = button_pressed;
