extends Area2D

var Conected_node_1
var Conected_node_2
var Length

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func init(node1, node2):
	Conected_node_1 = node1
	Conected_node_2 = node2
	var pos1 = node1.position
	var pos2 = node2.position
	
	$Line2D.add_point(pos1)
	$Line2D.add_point(pos2)
		
	$CollisionShape2D.shape.a = pos1
	$CollisionShape2D.shape.b = pos2
	
	node1.add_conecction(self)
	node2.add_conecction(self)
		
	Length = node1.position.distance_to(node2.position)
	
	
func get_conected_pos(pos):
	if Conected_node_1.position == pos:
		return Conected_node_2.position
	else:
		return Conected_node_1.position
