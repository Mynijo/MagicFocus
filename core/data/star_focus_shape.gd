class_name StarFocusShape
extends PolygonFocusShape
## Sternförmiger Fokus mit einer Spitze nach oben.

@export var points := 5:
	set(value):
		points = maxi(3, value)
		_invalidate()
@export var outer_radius := 330.0:
	set(value):
		outer_radius = value
		_invalidate()
@export var inner_radius := 160.0:
	set(value):
		inner_radius = value
		_invalidate()


func get_shape_name() -> String:
	return "Stern"


func _build_polygon() -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var count := points * 2
	for i in count:
		var radius := outer_radius if i % 2 == 0 else inner_radius
		var angle := -PI / 2.0 + TAU * i / count
		polygon.append(Vector2.from_angle(angle) * radius)
	return polygon
