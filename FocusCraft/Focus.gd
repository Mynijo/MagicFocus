extends Node2D

var last_node

# Called when the node enters the scene tree for the first time.
func _ready():
	add_new_last_node($StartNode)
		
	var FocusNodeScrene = preload("res://FocusCraft/FocusNode.tscn")
	for n in range (0, 10):
		var FocusNodeInstance = FocusNodeScrene.instantiate()
		FocusNodeInstance.position.x = randi_range(20, 580)
		FocusNodeInstance.position.y = randi_range(20, 580)
		add_child(FocusNodeInstance)

func _draw():
	if Input.is_action_pressed("left_mouse"):
		draw_line(last_node.position, get_viewport().get_mouse_position(), Color(255, 0, 0), 1)
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_pressed("left_mouse"):
		$RayCast2D.target_position = $RayCast2D.get_local_mouse_position()
		queue_redraw()
	if Input.is_action_just_released("left_mouse"):
		queue_redraw()

func add_new_last_node(new_node):
	last_node = new_node
	$RayCast2D.position = new_node.position
