class_name PlacedGem
extends Resource
## Eine im Fokus platzierte Gem.

@export var gem: GemDef
@export var position: Vector2


static func create(p_gem: GemDef, p_position: Vector2) -> PlacedGem:
	var placed := PlacedGem.new()
	placed.gem = p_gem
	placed.position = p_position
	return placed
