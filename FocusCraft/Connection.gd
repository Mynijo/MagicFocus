extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func init(pos1, pos2):
	$Line2D.add_point(pos1)
	$Line2D.add_point(pos2)
	$CollisionShape2D.shape.a = pos1
	$CollisionShape2D.shape.b = pos2
