class_name PlacedRune
extends Resource
## Eine im Fokus platzierte Rune.

@export var rune: RuneDef
@export var position: Vector2


static func create(p_rune: RuneDef, p_position: Vector2) -> PlacedRune:
	var placed := PlacedRune.new()
	placed.rune = p_rune
	placed.position = p_position
	return placed
