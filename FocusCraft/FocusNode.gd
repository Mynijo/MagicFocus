extends Area2D

@export var Radius_node = 10
@export var Radius_impcat = 80
@export var Node_color : Color = Color.WHITE

var Default_node_color = Color.WHITE

var Connections = []
var Impacted_objects = []
var Impact_cone_pos2

var Is_hovered = false
var Is_claimed = false

# Called when the node enters the scene tree for the first time.
func _ready():
	Default_node_color = Node_color
	$CollisionShape2D.shape.radius = Radius_node

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _draw():
	draw_circle(Vector2(0,0),Radius_node, Node_color)
	if Is_hovered or Is_claimed:
		draw_arc(Vector2(0,0),Radius_impcat, 0, PI*2,500, Color(255,255,255))
	if Connections.size() == 2 or (Connections.size() == 1 and Impact_cone_pos2 != null):
		var angle = get_impact_cone_angle()
		if angle > 0:
			draw_arc(Vector2(0,0),Radius_impcat,0,  2*PI-angle,500,Node_color,3)
		else:
			draw_arc(Vector2(0,0),Radius_impcat,0,- 2*PI-angle,500,Node_color,3)

func _on_mouse_entered():
	Is_hovered = true
	queue_redraw()

func _on_mouse_exited():
	Is_hovered = false
	queue_redraw()
	
func set_hovered(flag):
	Is_hovered = flag
	queue_redraw()

func get_Connections():
	return Connections
	
func remove_last_conection():
	Connections.pop_back()
	Is_hovered = false	
	if Connections.size() != 2:
		$ImpactArea/ImpactCone.polygon = [Vector2(0,0),Vector2(0,0),Vector2(0,0)]
		release()
			
func add_connection(conection):
	Connections.append(conection)
	if Connections.size() == 2:
		claim()

func get_angle_from_points(pos1, pos2):
	var direction_to_node1 = position.direction_to(pos1)
	var direction_to_node2 = position.direction_to(pos2)
	return direction_to_node1.angle_to(direction_to_node2)

func get_impact_cone_angle():
	if Impact_cone_pos2 == null and Connections.size() == 2:
		Impact_cone_pos2 = Connections.back().position
	return get_angle_from_points(Connections.front().get_connected_pos(position), Impact_cone_pos2)

func calc_impact_shape():
	var angleFrom = 0
	var angleTo   = 0
	var nbPoints = 36
	var pointsArc = PackedVector2Array()
	pointsArc.push_back(Vector2(0,0))

	var angle = get_impact_cone_angle()
	if angle > 0:
		angleTo = 2*PI-angle
	else:
		angleTo = - 2*PI-angle

	for i in range(nbPoints+1):
		var anglePoint = angleFrom + i*(angleTo-angleFrom)/nbPoints - 90
		pointsArc.push_back(Vector2( cos( anglePoint ), sin( anglePoint ) )* Radius_impcat)
	$ImpactArea/ImpactCone.polygon = pointsArc

func claim():
	Is_claimed = true
	for n in Impacted_objects:
		n.claim(true)

func release():
	Is_claimed = false
	stop_highlight_impact_cone()
	Node_color = Default_node_color
	for n in Impacted_objects:
		n.claim(false)
	Impacted_objects.clear()
	queue_redraw()

func highlight_impact_cone(pos2):
	Impact_cone_pos2 = pos2	
	if get_Connections().size() != 1:
		return
	$ImpactArea.monitoring = true
	look_at(pos2)
	calc_impact_shape()
	
func stop_highlight_impact_cone():
	if !Is_claimed:
		$ImpactArea.monitoring = false
	Impact_cone_pos2 = null
	calc_node_stats()
	queue_redraw()

func calc_node_stats():
	calc_node_color()
		


func _on_impact_area_area_entered(area):
	if !area.is_in_group("collectables"):
		return
	Impacted_objects.append(area)
	if area.has_method("highlight"):
		area.highlight(true)
	calc_node_stats()


func _on_impact_area_area_exited(area):
	if Is_claimed:
		return
	if !area.is_in_group("collectables"):
		return
	if area.has_method("highlight"):
		area.highlight(false)
	
	Impacted_objects.erase(area)
	calc_node_stats()
	
	
func calc_node_color():
	var colors = count_and_sort_colors()
	if colors.size() > 0 and colors[0]["count"] >= 10:
		Node_color = colors[0]["color"] # Speichert die Farbe des ersten Elements

		
func get_color() -> Color:
	calc_node_color()
	return Node_color
	
func get_all_dots_color() -> Array:
	return count_and_sort_colors()

func count_and_sort_colors():
	var impacted_objects = Impacted_objects
	var color_count = {} # Dictionary zur Speicherung der Farbzählung
	for obj in impacted_objects:
		var color = obj.get_Dot_color()
		if color in color_count:
			color_count[color] += 1
		else:
			color_count[color] = 1
	# Umwandlung des Dictionaries in ein Array von Dictionaries für die Sortierung
	var sortable_array = []
	for color in color_count.keys():
		sortable_array.append({"color": color, "count": color_count[color]})
	# Sortieren des Arrays basierend auf der Anzahl der Vorkommen in absteigender Reihenfolge
	sortable_array.sort_custom(func(a, b):
		if a["count"] > b["count"]:
			return true
		return false
	)
	# Rückgabe der sortierten Ergebnisse
	return sortable_array

