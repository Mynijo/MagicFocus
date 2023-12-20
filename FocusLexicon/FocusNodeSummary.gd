extends HBoxContainer

var Object_counter_scene = preload("res://FocusLexicon/ObjectCounter.tscn")

var Object_counter = []

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func set_FocusNode(node):	
	var dup_node = node.duplicate()
	dup_node.position.x = dup_node.Radius_node
	dup_node.position.y = dup_node.Radius_node
	
	$FocusIcon.add_child(dup_node)
	
	var found = false
	for d in node.Impacted_objects:
		found = false
		for obj_cnt in Object_counter:
			if obj_cnt.is_from_type(d):
				obj_cnt.increase_counter()
				found = true
		if !found:
			var object_counter_instance = Object_counter_scene.instantiate()
			object_counter_instance.set_type(d)
			object_counter_instance.increase_counter()
			add_child(object_counter_instance)
			Object_counter.append(object_counter_instance)
