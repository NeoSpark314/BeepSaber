extends Spatial


var points_label=[]
export var points_label_amount = 4
onready var points_label_ref = preload("res://game/points_label.tscn")
var current_point_label = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	for i in range(0,points_label_amount):
		points_label.insert(0,points_label_ref.instance())
		add_child(points_label[0])


func show_points(position=Vector3(),value=0):
	var color = Color(1,1,1)
	if value == 0:
		value = "x"
		color = Color(1,0,0)
#	else:
#		color = Color(1-clamp(value/150,0.4,1),clamp(value/150,0.4,1),0)
	else:  #keeping points color white makes it more neutral
		color.v = clamp(value/150,0.7,1)
	points_label[current_point_label].show_points(position,value,color)
	current_point_label += 1
	current_point_label %= points_label.size()
