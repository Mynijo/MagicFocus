class_name CircleFocusShape
extends FocusShape

@export var radius: float = 250.0


func contains(point: Vector2) -> bool:
	return point.length() <= radius


func random_point(rng: RandomNumberGenerator) -> Vector2:
	# sqrt sorgt für eine gleichmäßige Verteilung über die Fläche
	var distance := radius * sqrt(rng.randf())
	var angle := rng.randf() * TAU
	return Vector2.from_angle(angle) * distance


func get_outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 64:
		points.append(Vector2.from_angle(TAU * i / 64.0) * radius)
	return points
