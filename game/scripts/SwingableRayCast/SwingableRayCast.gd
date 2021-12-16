# extend the RayCast node and add additional RayCasts that help detect
# collisions with objects while swinging at high velocities.
extends RayCast

signal area_collided(area)

export (int,2,10) var num_collision_raycasts = 6

const DEBUG = false
const DEBUG_TRAIL_SEGMENTS = 5
const LinkedList = preload("res://game/scripts/LinkedList.gd")

# the type of note this saber can cut (set in the game main)
var _prev_ray_positions = [];
var _rays = [];
var _debug_curr_balls = [];
var _debug_raycast_trail := LinkedList.new();

func _ready():
	#separates cube collision layers to allow a diferent collider on right/wrong cuts
	yield(get_tree(),"physics_frame")
	
	# instantiate ray caster for doing continuous collision detection for cubes
	for i in range(num_collision_raycasts):
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

func _physics_process(delta):
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
	
	for i in range(num_collision_raycasts):
		var next_pos = transform.origin + step_dist * i
		next_pos = global_transform.xform(next_pos)
			
		# update ray's newest location for next physics frame processing
		var ray : RayCast = _rays[i]
		ray.global_transform.origin = next_pos
		if DEBUG:
			_debug_curr_balls[i].global_transform.origin = next_pos
			
		# cast a ray to the newest location and check for collisions
		ray.cast_to = ray.to_local(_prev_ray_positions[i])
		ray.force_raycast_update()
		coll = ray.get_collider()
		if coll is Area:
			emit_signal("area_collided",coll)
		
		_prev_ray_positions[i] = next_pos
		
	if DEBUG:
		var old_slice = _debug_raycast_trail.pop_back()

		# update oldest slide with newest ray casts
		for i in range(num_collision_raycasts):
			old_slice[i].global_transform = _rays[i].global_transform
			old_slice[i].cast_to = _rays[i].cast_to

		_debug_raycast_trail.push_front(old_slice)

func _on_SwingableRayCast_tree_entered():
	if DEBUG:
		var root = get_tree().get_root()
		var scene_root = root.get_child(root.get_child_count() - 1)
		for t in range(DEBUG_TRAIL_SEGMENTS):
			var trail_slice = []
			for i in range(num_collision_raycasts):
				var new_ray := RayCast.new()
				new_ray.enabled = true
				new_ray.collision_mask = collision_mask
				scene_root.add_child(new_ray)
				trail_slice.append(new_ray)
			_debug_raycast_trail.push_front(trail_slice)
