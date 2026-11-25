class_name FocusShape
extends Resource
## Basisklasse für die Form eines Fokus, zentriert um (0, 0).
## Neue Formen (z. B. Stern) überschreiben diese drei Funktionen.


func contains(_point: Vector2) -> bool:
	return false


## Gleichmäßig verteilter Zufallspunkt innerhalb der Form.
func random_point(_rng: RandomNumberGenerator) -> Vector2:
	return Vector2.ZERO


## Umriss zum Zeichnen.
func get_outline() -> PackedVector2Array:
	return PackedVector2Array()
