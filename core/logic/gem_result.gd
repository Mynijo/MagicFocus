class_name GemResult
extends RefCounted
## Auswertungsergebnis eines einzelnen Gems.

## Index in FocusInstance.gems (Platzierungsreihenfolge)
var index: int
var placed: PlacedGem
## Einflussbereich als Kreissektor: Startwinkel und Öffnungswinkel (Radiant).
var sector_start: float = 0.0
var sector_sweep: float = 0.0

## Eingesammelte Punkte (ganze Zahlen)
var collected: Array[EnergyDot] = []
var base_count: int = 0
## Element-ID -> Anzahl
var element_counts: Dictionary = {}

## Flächen-Multiplikator der Gem-Form
var multiplier: float = 1.0
## Nur Hauptgem: zusätzlicher Radius durch Radius Expansion
var radius_bonus := 0.0
## Eingesammeltes × Multiplikator
var effective_base: float = 0.0
## Element-ID -> effektive Anzahl
var effective_elements: Dictionary = {}

## Punkte für die Gravur: neutrale Essenz + Essenz × Element-Faktor
## (nur die Essenz, die die Gravur zählt). Wird in Phase 6 gesetzt.
var points: float = 0.0

## Nur Hauptgem: von Standard-Gems übertragene effektive Essenzen
var received_base: float = 0.0
var received_elements: Dictionary = {}


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


## Wirksamer Sammelradius (mit Radius Expansion).
func get_radius() -> float:
	return placed.get_radius() + radius_bonus


## Multiplikator eines eingesammelten Punkts: Form × innerer Bereich (Multiplikator-Gravur).
func dot_multiplier(dot: EnergyDot) -> float:
	var inner := placed.get_inner_radius()
	if inner > 0.0 and dot.position.distance_to(placed.position) <= inner:
		return multiplier * placed.engraving.inner_multiplier
	return multiplier


func apply_multiplier(value: float) -> void:
	multiplier = value
	effective_base = 0.0
	effective_elements.clear()
	for dot in collected:
		var m := dot_multiplier(dot)
		if dot.is_base():
			effective_base += m
		else:
			effective_elements[dot.element_id] = effective_elements.get(dot.element_id, 0.0) + m


func receive(other: GemResult) -> void:
	received_base += other.effective_base
	for element_id: StringName in other.effective_elements:
		received_elements[element_id] = received_elements.get(element_id, 0.0) + other.effective_elements[element_id]


## Effektive N-E inklusive Übertragungen (Grundlage der Regeln)
func total_base() -> float:
	return effective_base + received_base


## Effektive E je Element inklusive Übertragungen
func total_elements() -> Dictionary:
	var totals := effective_elements.duplicate()
	for element_id: StringName in received_elements:
		totals[element_id] = totals.get(element_id, 0.0) + received_elements[element_id]
	return totals
