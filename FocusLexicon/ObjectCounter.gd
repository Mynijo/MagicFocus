extends HBoxContainer

@export var Object_type = "none"

var Object_sub_type

var Obj_counter = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func set_type(type):
	var my_type = type.duplicate()
	my_type.position = Vector2(0,0)
	$Icon.add_child(my_type)
	if type.is_in_group("dots"):
		Object_sub_type = type.get_Dot_color()
		$Count.set_modulate(type.get_Dot_color())
	else:
		Object_sub_type = type.name

func is_from_type(d):
	if d.is_in_group("dots"):
		if Object_sub_type == d.get_Dot_color():
			return true
	else:
		if Object_sub_type == d.name():
			return true
	return false

func increase_counter(counter = 1):
	Obj_counter += counter
	$Count.text = str(int(Obj_counter))
