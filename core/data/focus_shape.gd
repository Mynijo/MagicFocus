class_name FocusShape
extends Resource
## Basisklasse für die Form eines Fokus, zentriert um (0, 0).
## Neue Formen (z. B. Stern) überschreiben diese drei Funktionen.

## Anzeigenamen der Größen-Werte aller Formen (Glossar und Editor).
const FIELD_LABELS := {
	"radius": "Radius", "outer_radius": "Radius außen", "inner_radius": "Radius innen", "points": "Spitzen",
	"height": "Höhe", "width": "Breite", "sharpness": "Schärfe der Spitze",
}


func contains(_point: Vector2) -> bool:
	return false


## true, wenn die Strecke a-b vollständig innerhalb der Form verläuft.
## Standard für konvexe Formen: beide Endpunkte innerhalb genügen.
func contains_segment(a: Vector2, b: Vector2) -> bool:
	return contains(a) and contains(b)


## Gleichmäßig verteilter Zufallspunkt innerhalb der Form.
func random_point(_rng: RandomNumberGenerator) -> Vector2:
	return Vector2.ZERO


## Umriss zum Zeichnen.
func get_outline() -> PackedVector2Array:
	return PackedVector2Array()


## Anzeigename der Form, z. B. "Kreis".
func get_shape_name() -> String:
	return "?"
