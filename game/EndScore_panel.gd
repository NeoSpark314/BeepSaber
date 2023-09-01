extends Panel
class_name EndScorePanel

var animated_percent = 0
signal repeat()
signal goto_mainmenu()

func show_score(score,record,percent,song_string="",is_full_combo=false,is_new_record=false):
	$details.modulate = Color(1,1,1,0)
	$char.modulate = Color(1,1,1,0)
	$full_combo_label.modulate = Color(1,1,1,0)
	$new_record_label.modulate = Color(1,1,1,0)
	
	$full_combo_label.visible = is_full_combo
	$new_record_label.visible = is_new_record
	
	$name.text = song_string
	
	$details.text = "Your Score:\n%d\n\nRecord:\n%d" % [score,record]
	
	var letter_score = "N"
	if percent >= 98:
		letter_score = "[rainbow freq=0.5 sat=0.7 val=2]S"
	elif percent >= 90:
		letter_score = "A"
	elif percent >= 80:
		letter_score = "B"
	elif percent >= 70:
		letter_score = "C"
	elif percent >= 60:
		letter_score = "D"
	elif percent >= 50:
		letter_score = "E"
	else:
		letter_score = "F"
	
	$char.bbcode_text = "[center]"+letter_score
	
	$Tween.interpolate_property(self,"animated_percent",0,percent,3,Tween.TRANS_QUAD,Tween.EASE_OUT)
	$Tween.start()

func set_buttons_disabled(disabled):
	$Repeat.disabled = disabled
	$MainMenu.disabled = disabled

func _on_Tween_tween_step(object, key, elapsed, value):
	if key==":animated_percent":
		$pi/percent_indicator.set_percent(value,false)
		
func _on_Tween_tween_completed(object, key):
	if key==":animated_percent":
		$pi/percent_indicator.set_percent(animated_percent,true)
		$Tween.interpolate_property($details,"modulate",Color(1,1,1,0),Color(1,1,1,1),2,Tween.TRANS_QUAD,Tween.TRANS_LINEAR)
		$Tween.interpolate_property($char,"modulate",Color(1,1,1,0),Color(1,1,1,1),2,Tween.TRANS_QUAD,Tween.TRANS_LINEAR)
		$Tween.interpolate_property($full_combo_label,"modulate",Color(1,1,1,0),Color(1,1,1,1),2,Tween.TRANS_QUAD,Tween.TRANS_LINEAR)
		$Tween.interpolate_property($new_record_label,"modulate",Color(1,1,1,0),Color(1,1,1,1),2,Tween.TRANS_QUAD,Tween.TRANS_LINEAR)
		$Tween.start()


func _on_Repeat_button_up():
	emit_signal("repeat")

func _on_MainMenu_button_up():
	emit_signal("goto_mainmenu")
