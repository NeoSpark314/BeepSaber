# BeepCube is the standard cube that will get cut by the sabers
extends Note

# the animation player contains the span animation that is applied to the CubeMeshAnimation node
onready var _anim = $CubeMeshOrientation/CubeMeshAnimation/AnimationPlayer;
# this is a separate Spatial for the orientation used in the game to display the cut direction
onready var _cube_mesh_orientation : Spatial = $CubeMeshOrientation;
onready var _mesh_instance : MeshInstance = $CubeMeshOrientation/CubeMeshAnimation/BeepCube_Mesh;

# we store the mesh here as part of the BeepCube for easier access because we will
# reuse it when we create the cut cube pieces
var _mesh : Mesh = null;
var _mat = null;
export var min_speed = 0.5;

func _ready():
	_mesh = _mesh_instance.mesh;
	_mat = _mesh_instance.material_override;
	# play the spawn animation when this cube enters the scene
	_anim.playback_speed = max(min_speed,speed)
	_anim.play("Spawn");
	
	#separates cube collision layers to allow a diferent collider on right/wrong cuts
	yield(get_tree(),"physics_frame")
	$CubeMeshOrientation/BeepCube_Big.set_collision_mask_bit(4,!bool(_note._type))
	$CubeMeshOrientation/BeepCube_Big.set_collision_mask_bit(14,bool(_note._type))
	$CubeMeshOrientation/BeepCube_Small.set_collision_mask_bit(4,bool(_note._type))
	$CubeMeshOrientation/BeepCube_Small.set_collision_mask_bit(14,!bool(_note._type))

func duplicate_create(color : Color):
	var mi = $CubeMeshOrientation/CubeMeshAnimation/BeepCube_Mesh;
	_mat = mi.material_override.duplicate(true);
	_mat.set_shader_param("color",color);
	mi.mesh = mi.mesh.duplicate();
	mi.material_override = _mat;
	_mesh = mi.mesh;

func update_color_only(color : Color):
	_mat.set_shader_param("color",color);

