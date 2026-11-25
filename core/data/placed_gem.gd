class_name PlacedGem
extends Resource
## Ein im Fokus platziertes Gem: Form, Gravur und Position.

@export var gem: GemDef
@export var engraving: EngravingDef
@export var position: Vector2


static func create(p_gem: GemDef, p_engraving: EngravingDef, p_position: Vector2) -> PlacedGem:
	var placed := PlacedGem.new()
	placed.gem = p_gem
	placed.engraving = p_engraving
	placed.position = p_position
	return placed
