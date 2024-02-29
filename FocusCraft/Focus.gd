extends Node2D

var Connected_nodes = []
var Conections = []
var Conection_hover_position
var Conection_hover_Node

var Focus_size = 500
var Focus_max_node = 3
var Focus_max_dots = 50

var All_nodes = []
var All_dos = []

var Connection_color = Color.DARK_GRAY



var Focus_node_scene = preload("res://FocusCraft/FocusNode.tscn")
var Connection_scene = preload("res://FocusCraft/Connection.tscn")
var Energie_dots_scene = preload("res://FocusCraft/EnergieDots.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	$StartNode.position = Vector2(int(Focus_size/2), int(Focus_size/2))
	$RayCast2D.position = $StartNode.position
	creat_new_focus()
	

#Inly fast and dirty, dont look
func creat_new_focus(shake_flag = false):
	for n in range (0, Focus_max_node):
		var pos
		var flag_ok = false
		while !flag_ok:
			flag_ok = true
			pos =  Vector2( randi_range(20, Focus_size -20), randi_range(20, Focus_size -20))
			for i in All_nodes:				
				if i.position.distance_to(pos) < 60 or $StartNode.position.distance_to(pos) < 100:
					flag_ok = false
		if !shake_flag:	
			var focus_node_instance = Focus_node_scene.instantiate()
			focus_node_instance.position = pos
			add_child(focus_node_instance)
			All_nodes.append(focus_node_instance)
		else:
			All_nodes[n].position = pos
					
	for n in range (0, Focus_max_dots):
		var pos
		var flag_ok  = false
		var flag_ok_2 = true
		while !flag_ok:
			pos =  Vector2( randi_range(0, Focus_size), randi_range(0, Focus_size) )
			for i in All_nodes:
				if i.position.distance_to(pos) < 80:
					flag_ok_2 = true
					for m in All_nodes:
						if m.position.distance_to(pos) < 15 or $StartNode.position.distance_to(pos) < 15:
							flag_ok_2 = false
							break
					if flag_ok_2:
						flag_ok = true
				
		if !shake_flag:
			var energie_dots_instance = Energie_dots_scene.instantiate()
			energie_dots_instance.position = pos
			add_child(energie_dots_instance)
			All_dos.append(energie_dots_instance)
		else:
			All_dos[n].position = pos
		All_dos[n].Dot_color = Color.YELLOW
		if (n % 2) == 0:
			All_dos[n].Dot_color = Color.RED
		if (n % 3) == 0:
			All_dos[n].Dot_color = Color.RED
	


func _draw():
	if Input.is_action_pressed("left_mouse"):
		draw_line(get_last_node().position, Conection_hover_position, Connection_color, 3)
		draw_circle(get_viewport().get_mouse_position(), $StartNode.Radius_node, Connection_color)
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var counter_dos = 0
	for n in All_nodes:
		counter_dos += n.Impacted_objects.size()
	$Label.text = str(counter_dos) + " / " + str(All_dos.size())
	var connection_length = get_connection_length()
	$Mana.text = "Mana: " + str(int(connection_length))
		

func get_connection_length():
	var connection_length = 0
	for n in Conections:
		connection_length += n.Length
		connection_length += (Conection_hover_position.distance_to(get_last_node().position))
	return connection_length
	
	
func _physics_process(delta):
	var mouse_pos = get_viewport().get_mouse_position()
	if mouse_pos.x >=0 and mouse_pos.x <= Focus_size and mouse_pos.y >=0 and mouse_pos.y <= Focus_size:
		if Input.is_action_pressed("left_mouse"):
			get_last_node().set_hovered(true)
			reset_conection_hover()
			get_last_node().highlight_impact_cone(get_viewport().get_mouse_position())
			#cast the RayCast
			$RayCast2D.target_position = $RayCast2D.get_local_mouse_position()
			var result = $RayCast2D.get_collider()
			if result:
				if result.is_in_group("connectable") and !Connected_nodes.has(result):
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
			get_last_node().stop_highlight_impact_cone()
			get_last_node().set_hovered(false)
			queue_redraw()

func reset_conection_hover():
	Conection_hover_Node = null
	Conection_hover_position = get_viewport().get_mouse_position()
	Connection_color = Color.DARK_GRAY

func get_last_node():
	if Connected_nodes.size() > 0:
		return Connected_nodes.back()
	else:
		return $StartNode

func add_new_connection(new_node):
	if !Connected_nodes.has(new_node):
		var connection_instance = Connection_scene.instantiate()
		connection_instance.init(new_node, get_last_node())
		add_child(connection_instance)
		move_child(connection_instance, 0) 
		Conections.append(connection_instance)
		
		Connected_nodes.append(new_node)
		$RayCast2D.position = new_node.position
		
		$RayCast2D.clear_exceptions()
		$RayCast2D.add_exception(connection_instance)
		
		$FocusSummary.set_Focus(self)
	$SpellSummary.add_focus(self)
		
func back():
	if Conections.size() == 0:
		return
		
	get_last_node().remove_last_conection()
	Connected_nodes.pop_back()
	get_last_node().remove_last_conection()
	
	var connection = Conections.back()
	Conections.pop_back()
	connection.queue_free()
	
	$FocusSummary.set_Focus(self)
	
	$RayCast2D.clear_exceptions()
	$RayCast2D.position = get_last_node().position
	if Conections.size() > 0:
		$RayCast2D.add_exception(Conections.back())
	
	$SpellSummary.add_focus(self)
	
func reset():
	for i in range(0,Conections.size()):
		back()
	$SpellSummary.add_focus(self)

func shake():
	reset()
	creat_new_focus(true)
	

func _on_button_pressed():
	back()

func _on_button_2_pressed():
	reset()

func _on_button_3_pressed():
	shake()

	
# Funktion, die Farben von Fokus-Knoten basierend auf Tiefensuche zurückgibt
func get_colors() -> Array[Color]:
	var colors : Array[Color] = []
	var visited_nodes = {}
	var start_node = $StartNode
	
	visited_nodes[start_node] = true
	
	if start_node.Connections.size() > 0:
		dfs_visit(start_node, start_node.Connections[0], colors, visited_nodes, false)
	
	return colors

# Funktion, die alle Punktfarben von Fokus-Knoten basierend auf Tiefensuche zurückgibt
func get_dots():
	var dots_colors = []
	var visited_nodes = {}
	var start_node = $StartNode
	
	visited_nodes[start_node] = true
	
	if start_node.Connections.size() > 0:
		dfs_visit(start_node, start_node.Connections[0], dots_colors, visited_nodes, true)
	
	return dots_colors
	
func get_dots_sum():
	var dots_pro_node = get_dots()
	var dots_pro_focus = {}
	# Durchlaufe jedes Array in dots_pro_node
	for node_array in dots_pro_node:
		for color_dict in node_array:
				var color = color_dict["color"]
				var count = color_dict["count"]
				# Füge Werte für gleiche Farben zusammen
				if color in dots_pro_focus:
					dots_pro_focus[Color(color)] += count
				else:
					dots_pro_focus[Color(color)] = count
	return dots_pro_focus
# Angepasste Hilfsfunktion für die Tiefensuche ab einem bestimmten Knoten
func dfs_visit(prev_node, connection, colors, visited_nodes: Dictionary, get_dots: bool) -> void:
	var next_node = connection.Connected_node_1 if prev_node != connection.Connected_node_1 else connection.Connected_node_2
	
	if next_node == null or next_node in visited_nodes:
		return
	
	if get_dots:
		var dots_colors = next_node.get_all_dots_color()
		colors.append(dots_colors)
	else:
		var next_color = next_node.get_color()
		if next_color != Color.WHITE:
			colors.append(next_color)
	
	visited_nodes[next_node] = true
	
	for next_connection in next_node.Connections:
		dfs_visit(next_node, next_connection, colors, visited_nodes, get_dots)
