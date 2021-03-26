extends StaticBody


#func _process(delta):
#	burn_mark()

var last_position = [Vector2(0,-50),Vector2(0,-50)]

var C_LEFT = Color()
var C_RIGHT = Color()

func update_colors(COLOR_LEFT,COLOR_RIGHT):
	C_LEFT = COLOR_LEFT
	C_RIGHT = COLOR_RIGHT
	$Viewport/ColorRect/burn_l.modulate = C_LEFT
	$Viewport/ColorRect/burn_r.modulate = C_RIGHT
	

func burn_mark(position=Vector3(0,0,-50),type=0):
	var burn_mark_sprite
	var burn_mark_sprite_long
	if type == 0:
		burn_mark_sprite = $Viewport/ColorRect/burn_l
		burn_mark_sprite_long = $Viewport/ColorRect/burn_l/burn2
	elif type == 1:
		burn_mark_sprite = $Viewport/ColorRect/burn_r
		burn_mark_sprite_long = $Viewport/ColorRect/burn_r/burn2
	else:
		return
	
	
	var newpos = Vector2(
		(position.x+1)*256,
		position.z*256
	)
	
	burn_mark_sprite.position = newpos
	
	burn_mark_sprite.rotation = newpos.angle_to_point(last_position[type])
	var dist = last_position[type].distance_to(newpos)
	if dist > 8:
		burn_mark_sprite.self_modulate.a = 0
		burn_mark_sprite_long.visible = true
		burn_mark_sprite_long.rect_size.x = dist*6
	else:
		burn_mark_sprite.self_modulate.a = 1
		burn_mark_sprite_long.visible = false
	
	
	last_position[type] = newpos
