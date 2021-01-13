extends TextureRect


func set_percent(value,anim=true):
	$Label.text = "%d%%" % value
	material.set_shader_param("percent",float(value)/100)
	if anim:
		$AnimationPlayer.stop()
		$AnimationPlayer.play("change")
