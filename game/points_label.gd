extends Spatial


func show_points(position=Vector3(),value="x",color = Color(1,1,1)):
	transform.origin = position
	$Viewport/Label.text = str(value)
	$Viewport/Label.modulate = color
	$AnimationPlayer.stop()
	$AnimationPlayer.play("hit")
#	$AudioStreamPlayer3D.play()
