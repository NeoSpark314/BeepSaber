tool
extends Spatial
class_name Wall

# copy of 'obstacle' struct from map data
var _obstacle;

# width of wall in meters
export var width = 1 setget _set_width
# height of wall in meters
export var height = 1 setget _set_height
# depth of wall in meters (can be negative)
export var depth = 1 setget _set_depth

onready var _anim = $WallMeshOrientation/AnimationPlayer
onready var _mesh_orientation = $WallMeshOrientation
onready var _mesh = $WallMeshOrientation/WallMesh
onready var _coll = $WallMeshOrientation/WallArea/CollisionShape

var wall_material = preload("res://game/Wall/wall.material");

func _ready():
	# play the spawn animation when wall enters the scene
	_anim.play("Spawn")

func _set_width(value):
	width = value
	
	if not _mesh:
		yield(self,"ready")
		
	_mesh.mesh.size.x = width
	_coll.shape.extents.x = width / 2.0
	_mesh_orientation.translation.x = width / 2.0
	
func _set_height(value):
	height = value
	
	if not _mesh:
		yield(self,"ready")
		
	_mesh.mesh.size.y = height
	_coll.shape.extents.y = height / 2.0
	_mesh_orientation.translation.y = height / 2.0
	
func _set_depth(value):
	depth = value
	
	if not _mesh:
		yield(self,"ready")
		
	_mesh.mesh.size.z = depth
	_coll.shape.extents.z = depth / 2.0
	_mesh_orientation.translation.z = -1 * depth / 2.0

func duplicate_create():
	if not _mesh:
		yield(self,"ready")
	
	_mesh.mesh = _mesh.mesh.duplicate();
#	_mesh.mesh.surface_set_material(0, wall_material.duplicate());
	_coll.shape = _coll.shape.duplicate()
