# This is a stand-alone version of the demo game Beep Saber. It started (and is still included)
# in the godot oculus quest toolkit (https://github.com/NeoSpark314/godot_oculus_quest_toolkit)
# But this stand-alone version as additional features and will be developed independently

extends Node

func _ready():
	vr.initialize();
	
	var xml_appender = XML_SocketAppender.new()
	xml_appender.host = "10.0.0.10"
	Logging.add_appender(xml_appender)
	
	#vr.set_display_refresh_rate(60);
	#Engine.target_fps = 60;
	
	vr.scene_switch_root = self;
	
	if (vr.inVR): vr.switch_scene("res://game/GodotSplash.tscn", 0.0, 0.0);
	vr.switch_scene("res://game/BeepSaber_Game.tscn", 0.1, 2.0);
