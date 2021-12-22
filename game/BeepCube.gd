# BeepCube is the standard cube that will get cut by the sabers
extends Note
class_name BeepCube

# the animation player contains the span animation that is applied to the CubeMeshAnimation node
onready var _anim = $CubeMeshOrientation/CubeMeshAnimation/AnimationPlayer;
# this is a separate Spatial for the orientation used in the game to display the cut direction
onready var _cube_mesh_orientation : Spatial = $CubeMeshOrientation;
onready var _mesh_instance : MeshInstance = $CubeMeshOrientation/CubeMeshAnimation/BeepCube_Mesh;
onready var _big_coll_area := $CubeMeshOrientation/BeepCube_Big
onready var _small_coll_area := $CubeMeshOrientation/BeepCube_Small

# we store the mesh here as part of the BeepCube for easier access because we will
# reuse it when we create the cut cube pieces
var _mesh : Mesh = null;
var _mat = null;
var collision_disabled = false setget _set_colision_disabled
export var min_speed = 0.5;

func _ready():
	_mesh = _mesh_instance.mesh;
	_mat = _mesh_instance.material_override;
	# play the spawn animation when this cube enters the scene
	_anim.playback_speed = max(min_speed,speed)
	_anim.play("Spawn");
	
	# separate cube collision layers to allow a diferent collider on right/wrong cuts.
	# opposing collision layers (ie. right note & left saber) will be placed on the
	# smalling collision shape, while similar collision layers (ie right note &
	# right saber) are placed on the larger collision shape.
	yield(get_tree(),"physics_frame")
	var is_left_note = _note._type == 0
	_big_coll_area.set_collision_layer_bit(CollisionLayerConstants.LeftNote_bit, is_left_note)
	_big_coll_area.set_collision_layer_bit(CollisionLayerConstants.RightNote_bit, ! is_left_note)
	_small_coll_area.set_collision_layer_bit(CollisionLayerConstants.LeftNote_bit, ! is_left_note)
	_small_coll_area.set_collision_layer_bit(CollisionLayerConstants.RightNote_bit, is_left_note)

func duplicate_create(color : Color):
	var mi = $CubeMeshOrientation/CubeMeshAnimation/BeepCube_Mesh;
	_mat = mi.material_override.duplicate(true);
	_mat.set_shader_param("color",color);
	mi.mesh = mi.mesh.duplicate();
	mi.material_override = _mat;
	_mesh = mi.mesh;

func update_color_only(color : Color):
	_mat.set_shader_param("color",color);
	
func _set_colision_disabled(value):
	collision_disabled = value
	$CubeMeshOrientation/BeepCube_Big/CollisionBig.disabled = value
	$CubeMeshOrientation/BeepCube_Small/CollisionSmall.disabled = value

