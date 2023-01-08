extends Area2D

@export var Radius_node = 10
@export var Radius_impcat = 80
@export var Node_color = Color(255,0,0)


var Default_node_color



var Conecctions = []
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
	if Conecctions.size() == 2 or (Conecctions.size() == 1 and Impact_cone_pos2 != null):
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

func get_conecctions():
	return Conecctions
	
func remove_last_conection():
	Conecctions.pop_back()
	Is_hovered = false	
	if Conecctions.size() != 2:
		$ImpactArea/ImpactCone.polygon = [Vector2(0,0),Vector2(0,0),Vector2(0,0)]
		release()
			
func add_conecction(conection):
	Conecctions.append(conection)
	if Conecctions.size() == 2:
		claim()

func get_angle_from_points(pos1, pos2):
	var direction_to_node1 = position.direction_to(pos1)
	var direction_to_node2 = position.direction_to(pos2)
	return direction_to_node1.angle_to(direction_to_node2)

func get_impact_cone_angle():
	if Impact_cone_pos2 == null and Conecctions.size() == 2:
		Impact_cone_pos2 = Conecctions.back().position
	return get_angle_from_points(Conecctions.front().get_conected_pos(position), Impact_cone_pos2)

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
	if get_conecctions().size() != 1:
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
		
func calc_node_color():
	var my_color = Color(0,0,0)
	if Impacted_objects.size() > 0:
		for n in Impacted_objects:
			my_color += n.get_Dot_color()
		my_color = my_color / Impacted_objects.size()
		Node_color = my_color
	else:
		Node_color = Default_node_color

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
