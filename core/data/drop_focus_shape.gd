class_name DropFocusShape
extends PolygonFocusShape
## Tropfenförmiger Fokus: Spitze oben, runder Bauch unten.
## Umriss: x = width * sin(t) * sin(t/2)^sharpness, y = -height * cos(t)

@export var height := 330.0:
	set(value):
		height = value
		_invalidate()
@export var width := 340.0:
	set(value):
		width = value
		_invalidate()
## Größer = schlankere Spitze
@export var sharpness := 1.0:
	set(value):
		sharpness = maxf(0.1, value)
		_invalidate()


func get_shape_name() -> String:
	return "Tropfen"


func _build_polygon() -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var steps := 96
	for i in steps:
		var t := TAU * i / steps
		var x := width * sin(t) * pow(absf(sin(t / 2.0)), sharpness)
		var y := -height * cos(t)
		polygon.append(Vector2(x, y))
	return polygon
