extends Area2D

var Connected_node_1
var Connected_node_2
var Length

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func init(node1, node2):
	Connected_node_1 = node1
	Connected_node_2 = node2
	var pos1 = node1.position
	var pos2 = node2.position
	
	$Line2D.add_point(pos1)
	$Line2D.add_point(pos2)
		
	$CollisionShape2D.shape.a = pos1
	$CollisionShape2D.shape.b = pos2
	
	node1.add_connection(self)
	node2.add_connection(self)
		
	Length = node1.position.distance_to(node2.position)
	
	
func get_connected_pos(pos):
	if Connected_node_1.position == pos:
		return Connected_node_2.position
	else:
		return Connected_node_1.position
