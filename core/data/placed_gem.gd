class_name PlacedGem
extends Resource
## Ein im Fokus platziertes Gem: Form, Gravur und Position.

@export var gem: GemDef
@export var engraving: EngravingDef
@export var position: Vector2


## Wirksamer Radius: Radius der Form × Faktor der Gravur (z. B. Power Transfer ×0,5).
func get_radius() -> float:
	return radius_of(gem, engraving)


## Innerer Ring der Multiplikator-Gravur (0 = keiner): vom Stein bis 0,3 × Radius darüber hinaus.
func get_inner_radius() -> float:
	if gem == null or engraving == null:
		return 0.0
	if engraving.inner_radius_factor <= 0.0:
		return 0.0
	# beginnt am Rand des Steins
	return gem.body_radius + gem.radius * engraving.inner_radius_factor


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
