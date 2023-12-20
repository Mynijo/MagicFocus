extends Node2D

@export var object_type = "dot"
@export var Radius_dot = 2
@export var Radius_impcat = 80
@export var Dot_color = Color.YELLOW
@export var Highlight_color = Color.GRAY

@export var Highlighted = false

# Called when the node enters the scene tree for the first time.
func _ready():
	$CollisionShape2D.shape.radius = Radius_dot

func claim(flag):
	self.visible = !flag
	$CollisionShape2D.disabled = flag
	Highlighted = false
	queue_redraw()
	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _draw():
	draw_circle(Vector2(0,0),Radius_dot, Dot_color)
	if Highlighted:
		draw_circle(Vector2(0,0),Radius_dot *3, Highlight_color)

func highlight(flag):
	if Highlighted != flag:
		Highlighted = flag
		queue_redraw()

func get_Dot_color():
	return Dot_color
	
func reset():
	position = Vector2(0,0)
	visible = true
	Highlighted = false
	
