# extend the RayCast node and add additional RayCasts that help detect
# collisions with objects while swinging at high velocities.
extends RayCast

signal area_collided(area)

export (int,2,10) var num_collision_raycasts = 8

const DEBUG = false
const DEBUG_TRAIL_SEGMENTS = 5
const LinkedList = preload("res://game/scripts/LinkedList.gd")

# this constant is used to prevent unnecessary raycast collision computations
# when the ray's 'cast_to' vector length is below this threshold. it seems like
# Godot's physics engine never picks up on collisions when the vector's length
# is below this threshold. this vlaue was imperically found by logging the
# minimum length when using the node in-game.
const MIN_SWEPT_LENGTH_THRESHOLD = 0.035

# the type of note this saber can cut (set in the game main)
var _prev_ray_positions = [];
var _rays = [];
var _debug_curr_balls = [];
var _debug_raycast_trail := LinkedList.new();
onready var _sw := StopwatchFactory.create(name, 10, true);

func _ready():
	yield(get_tree(),"physics_frame")
	
	# use discrete RayCasts for continuous collision detection between _physics_process()
	for _i in range(num_collision_raycasts):
		var new_ray := RayCast.new()
		# inherit properties of parent
		new_ray.collision_mask = collision_mask
		new_ray.collide_with_areas = collide_with_areas
		new_ray.collide_with_bodies = collide_with_bodies
		new_ray.enabled = enabled
		add_child(new_ray)
		_prev_ray_positions.append(Vector3())
		_rays.append(new_ray)
		
		if DEBUG:
			var new_ball := $debug_ball.duplicate()
			new_ball.visible = true
			add_child(new_ball)
			_debug_curr_balls.append(new_ball)
	
	# no longer need original instance
	remove_child($debug_ball)

# override so that we can update child segments too
func set_collision_mask_bit(bit: int, value: bool):
	collision_mask = collision_mask | (int(value) << bit)
	for ray in _rays:
		ray.set_collision_mask_bit(bit,value)

func _physics_process(_delta):
	_sw.start()
	# see if 'core' ray is colliding with anything
	var coll = get_collider()
	if coll is Area:
		emit_signal("area_collided",coll)
	
	# ---------------------
	
	# update positions of segmented ray casts and check for collisions on them
	
	# generate new locations for ray casters
	var saber_base = transform.origin
	var saber_tip = saber_base + cast_to
	var step_dist = (saber_tip - saber_base) / (num_collision_raycasts - 1)
	
	var next_local_pos = transform.origin
	for i in range(num_collision_raycasts):
		var next_global_pos = global_transform.xform(next_local_pos)
			
		# update ray's newest location for next physics frame processing
		var ray : RayCast = _rays[i]
		ray.global_transform.origin = next_global_pos
		if DEBUG:
			_debug_curr_balls[i].global_transform.origin = next_global_pos
			
		# cast a ray to the newest location and check for collisions
		ray.cast_to = ray.to_local(_prev_ray_positions[i])
		if ray.cast_to.length() > MIN_SWEPT_LENGTH_THRESHOLD:
			ray.force_raycast_update()
			coll = ray.get_collider()
			if coll is Area:
				emit_signal("area_collided",coll)
		
		_prev_ray_positions[i] = next_global_pos
		next_local_pos += step_dist
		
	if DEBUG:
		var old_slice = _debug_raycast_trail.pop_back()

		# update oldest slide with newest ray casts
		for i in range(num_collision_raycasts):
			old_slice[i].global_transform = _rays[i].global_transform
			old_slice[i].cast_to = _rays[i].cast_to

		_debug_raycast_trail.push_front(old_slice)
	_sw.stop()

func _on_SwingableRayCast_tree_entered():
	if DEBUG:
		var root = get_tree().get_root()
		var scene_root = root.get_child(root.get_child_count() - 1)
		for _t in range(DEBUG_TRAIL_SEGMENTS):
			var trail_slice = []
			for _i in range(num_collision_raycasts):
				var new_ray := RayCast.new()
				new_ray.enabled = true
				new_ray.collision_mask = collision_mask
				scene_root.add_child(new_ray)
				trail_slice.append(new_ray)
			_debug_raycast_trail.push_front(trail_slice)
