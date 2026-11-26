class_name PlacedGem
extends Resource
## Ein im Fokus platziertes Gem: Form, Gravur und Position.

@export var gem: GemDef
@export var engraving: EngravingDef
@export var position: Vector2


## Wirksamer Radius: Radius der Form × Faktor der Gravur (z. B. Power Transfer ×0,5).
func get_radius() -> float:
	return radius_of(gem, engraving)


static func radius_of(p_gem: GemDef, p_engraving: EngravingDef) -> float:
	if p_gem == null:
		return 0.0
	return p_gem.radius * (p_engraving.radius_factor if p_engraving != null else 1.0)


static func create(p_gem: GemDef, p_engraving: EngravingDef, p_position: Vector2) -> PlacedGem:
	var placed := PlacedGem.new()
	placed.gem = p_gem
	placed.engraving = p_engraving
	placed.position = p_position
	return placed
