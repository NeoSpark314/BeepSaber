extends Spatial

var _spectrum = null;
var _spectrum_nodes = [];
export(NodePath) var game;

var ring_rot_speed = 0.0;
var ring_rot_inv_dir = false;

export var disabled = false

func _ready():
	if game is NodePath:
		game = get_node(game);
	_setup_level();

func _process(delta):
	_update_level(delta);
	
# update the level animations
func _update_level(dt):
	var VU_COUNT = _spectrum_nodes.size();
	var FREQ_MAX = 11050.0
	var MIN_DB = 60.0

	var prev_hz = 100
	for i in range(1,VU_COUNT+1):
		var hz = i * FREQ_MAX / VU_COUNT;
		var f = _spectrum.get_magnitude_for_frequency_range(prev_hz,hz)
		var energy = clamp((MIN_DB + linear2db(f.length()))/MIN_DB,0,1)
		
		if _spectrum_nodes[i-1].translation.y < energy * 10.0:
			_spectrum_nodes[i-1].translation.y = min(_spectrum_nodes[i-1].translation.y+0.2,energy * 10.0);
		else:
			_spectrum_nodes[i-1].translation.y -= 0.08;

		prev_hz = hz
		
	#procces ring rotations
	if ring_rot_speed > 0:
		for ring in $Level/rings.get_children():
			if ring is Spatial:
				var rot = ring_rot_speed
				if ring_rot_inv_dir: rot *= -1
				ring.rotate_z((rot * dt) * (float(ring.get_index()+1)/5))
			

# create the level data that is displayed
func _setup_level():
	# create a specrum analyzer
	AudioServer.add_bus_effect(0, AudioEffectSpectrumAnalyzer.new());
	_spectrum = AudioServer.get_bus_effect_instance(0,0);
	# and create some cubes to display it in the level (updated in _update_level(dt))
	var s = $Level/SpectrumBar;
	_spectrum_nodes.push_back(s);
	for  i in range(0, 7):
		s = s.duplicate()
		$Level.add_child(s);
		s.translation.x += 2.0;
		_spectrum_nodes.push_back(s);
		
	update_colors()

func update_colors():
	for i in [0,2,3]:
		change_light_color(i,game.COLOR_LEFT)
	for i in [1,4]:
		change_light_color(i,game.COLOR_RIGHT)
		
func set_all_off():
	if not disabled:
		for i in [0,1,2,3,4]:
			change_light_color(i,-1)
	else:
		update_colors()
		for i in [1,2,3]:
			change_light_color(i,-1)
		$Level/rings.visible = false
func set_all_on():
		update_colors()
		$Level/rings.visible = true

func procces_event(data,beat):
	if disabled: return
#	print(data)
	if int(data._type) in [0,1,2,3,4]:
		match int(data._value):
			0:
				change_light_color(data._type,-1)
			1:
				change_light_color(data._type,game.COLOR_RIGHT)
			2:
				change_light_color(data._type,game.COLOR_RIGHT,1)
			3:
				change_light_color(data._type,game.COLOR_RIGHT,2)
			5:
				change_light_color(data._type,game.COLOR_LEFT)
			6:
				change_light_color(data._type,game.COLOR_LEFT,1)
			7:
				change_light_color(data._type,game.COLOR_LEFT,2)
	else:
		match int(data._type):
			8:
				if not $Level/rings/Tween.is_active():
					ring_rot_inv_dir = bool(randi()%2)
				$Level/rings/Tween.stop(self,"ring_rot_speed")
				$Level/rings/Tween.interpolate_property(self,"ring_rot_speed",3.0,0.0,2,Tween.TRANS_QUAD,Tween.EASE_OUT)
				$Level/rings/Tween.start()
			9:
				$Level/rings/AnimationPlayer.stop(false)
				if $Level/rings/ring.translation.z > -6.5:
					$Level/rings/AnimationPlayer.play("in")
				else:
					$Level/rings/AnimationPlayer.play("out")
					
			12:
				var val = float(data._value)/8
				$Level/t2/AnimationPlayer.playback_speed = val
			13:
				var val = float(data._value)/8
				$Level/t3/AnimationPlayer.playback_speed = val
	
func change_light_color(type,color=-1,transition_mode=0):
	var group : Spatial
	var material = []
	var tween : Tween
	match int(type):
		0:
			group = $Level/t0
			material = [$Level/t0/laser1/Bar7.material_override]
			tween = $Level/t0/Tween
		1:
			group = $Level/t1
			material = [$Level/t1/Bar7.material_override]
			tween = $Level/t1/Tween
		2:
			group = $Level/t2
			material = [$Level/t2/laser1/Bar7.material_override]
			tween = $Level/t2/Tween
		3:
			group = $Level/t3
			material = [$Level/t3/laser1/Bar7.material_override]
			tween = $Level/t3/Tween
		4:
			group = $Level/t4
			material = [$Level/t4/Bar1.material_override,$Level/floor.material_override]
			tween = $Level/t4/Tween
	
	if not color is Color:
		for m in material:
			m.albedo_color = Color.black
		group.visible = false
		return
	
	match transition_mode:
		0:
			for m in material:
				m.albedo_color = color
			group.visible = true
		1:
			tween.stop_all()
			for m in material:
				tween.interpolate_property(m,"albedo_color",Color(0,0,0),color,1,Tween.TRANS_BOUNCE,Tween.EASE_IN)
			tween.start()
			group.visible = true
		2:
			tween.stop_all()
			for m in material:
				tween.interpolate_property(m,"albedo_color",color,Color(0,0,0),2,Tween.TRANS_BOUNCE,Tween.EASE_OUT)
			tween.start()
			group.visible = true
			yield(tween,"tween_completed")
			if material[0].albedo_color == Color(0,0,0):
				group.visible = false
			







