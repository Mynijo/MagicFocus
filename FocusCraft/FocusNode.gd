extends Area2D

@export var Radius_node = 10
@export var Radius_impcat = 80
@export var Node_color = Color(255,0,0)


var is_hovered = false

# Called when the node enters the scene tree for the first time.
func _ready():
	$CollisionShape2D.shape.radius = Radius_node


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _draw():
	draw_circle(Vector2(0,0),Radius_node, Node_color)
	if is_hovered:
		draw_arc(Vector2(0,0),Radius_impcat, 0, PI*2,500, Color(255,255,255))


func _on_mouse_entered():
	is_hovered = true
	queue_redraw()


func _on_mouse_exited():
	is_hovered = false
	queue_redraw()
