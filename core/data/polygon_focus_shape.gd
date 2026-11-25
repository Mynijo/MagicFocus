class_name PolygonFocusShape
extends FocusShape
## Basisklasse für Fokus-Formen, die als Polygon beschrieben werden (Stern, Tropfen, ...).
## Unterklassen implementieren nur `_build_polygon()`. Der Ursprung (0, 0) muss
## innerhalb der Form liegen.

var _polygon := PackedVector2Array()


## Muss von Unterklassen überschrieben werden.
func _build_polygon() -> PackedVector2Array:
	return PackedVector2Array()


## Nach Änderung einer Eigenschaft aufrufen, damit das Polygon neu berechnet wird.
func _invalidate() -> void:
	_polygon = PackedVector2Array()
	emit_changed()


func get_polygon() -> PackedVector2Array:
	if _polygon.is_empty():
		_polygon = _build_polygon()
	return _polygon


func contains(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, get_polygon())


func random_point(rng: RandomNumberGenerator) -> Vector2:
	# Gleichmäßig verteilt durch Verwerfen von Punkten außerhalb der Form
	var bounds := _bounds()
	for attempt in 1000:
		var point := Vector2(
			rng.randf_range(bounds.position.x, bounds.end.x),
			rng.randf_range(bounds.position.y, bounds.end.y))
		if contains(point):
			return point
	return Vector2.ZERO


func get_outline() -> PackedVector2Array:
	return get_polygon()


func _bounds() -> Rect2:
	var polygon := get_polygon()
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for p in polygon:
		bounds = bounds.expand(p)
	return bounds
