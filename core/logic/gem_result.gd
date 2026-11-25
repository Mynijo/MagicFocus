class_name GemResult
extends RefCounted
## Auswertungsergebnis einer einzelnen Gem.

## Index in FocusInstance.gems (Platzierungsreihenfolge)
var index: int
var placed: PlacedGem
## Einflussbereich als Kreissektor: Startwinkel und Öffnungswinkel (Radiant).
var sector_start: float = 0.0
var sector_sweep: float = 0.0
var collected: Array[EnergyDot] = []
var base_count: int = 0
## Element-ID -> Anzahl
var element_counts: Dictionary = {}
## Angenommenes Element, &"" = neutral
var element_id: StringName = &""


func is_main() -> bool:
	return placed.gem.role == GemDef.Role.MAIN


func add_dot(dot: EnergyDot) -> void:
	collected.append(dot)
	if dot.is_base():
		base_count += 1
	else:
		element_counts[dot.element_id] = element_counts.get(dot.element_id, 0) + 1


func get_element_total() -> int:
	var total := 0
	for count: int in element_counts.values():
		total += count
	return total
