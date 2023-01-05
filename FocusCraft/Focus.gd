extends Node2D

var Connected_nodes = []
var Conections = []
var Conection_hover_position
var Conection_hover_Node

var Connection_color = Color.DARK_GRAY


var Focus_node_scene = preload("res://FocusCraft/FocusNode.tscn")
var Connection_scene = preload("res://FocusCraft/Connection.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	$RayCast2D.position = $StartNode.position	
	Connected_nodes.append($StartNode)
	
	for n in range (0, 10):
		var focus_node_instance = Focus_node_scene.instantiate()
		focus_node_instance.position.x = randi_range(20, 580)
		focus_node_instance.position.y = randi_range(20, 580)
		add_child(focus_node_instance)
		
		

func _draw():
	if Input.is_action_pressed("left_mouse"):
		draw_line(get_last_node().position, Conection_hover_position, Connection_color, 3)
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_pressed("left_mouse"):
		reset_conection_hover()
		#cast the RayCast
		$RayCast2D.target_position = $RayCast2D.get_local_mouse_position()
		var result = $RayCast2D.get_collider()
		if result:
			if result.is_in_group("connectable"):
				Conection_hover_position = result.position
				Conection_hover_Node = result
				Connection_color = Color.GREEN
			else:
				Conection_hover_position = $RayCast2D.get_collision_point()
				Connection_color = Color.RED
				
				
		queue_redraw()
	if Input.is_action_just_released("left_mouse"):
		if Conection_hover_Node:
			add_new_connection(Conection_hover_Node)
		queue_redraw()

func reset_conection_hover():
	Conection_hover_Node = null
	Conection_hover_position = get_viewport().get_mouse_position()
	Connection_color = Color.DARK_GRAY

func get_last_node():
	return Connected_nodes.back()

func add_new_connection(new_node):
	if !Connected_nodes.has(new_node):
		var connection_instance = Connection_scene.instantiate()		
		connection_instance.init(new_node.position, get_last_node().position)
		add_child(connection_instance)
		Conections.append(connection_instance)
		
		Connected_nodes.append(new_node)
		$RayCast2D.position = new_node.position
		
		$RayCast2D.clear_exceptions()
		$RayCast2D.add_exception(connection_instance)
		
