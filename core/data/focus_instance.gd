class_name FocusInstance
extends Resource
## Ein gebauter und befüllter Fokus des Spielers (speicherbar als .tres).
## Die Energiepunkte selbst werden nicht gespeichert, sondern von DotField
## aus `dot_seed` und der Füllung reproduzierbar erzeugt.

@export var focus_def: FocusDef
## Element-ID -> Anzahl farbiger Punkte, z. B. {&"fire": 25}
@export var element_fill: Dictionary = {}
@export var dot_seed: int = 0
## In Platzierungsreihenfolge. Sie bestimmt, welche kleine Gem bei
## Überlappung zuerst einsammelt.
@export var gems: Array[PlacedGem] = []
## Indizes in `gems` in Verbindungsreihenfolge, beginnend bei dem Hauptgem.
## Die Kante von der letzten zur ersten Gem ist implizit.
@export var loop: PackedInt32Array = PackedInt32Array()
## true, sobald das letzte Gem wieder mit dem Hauptgem verbunden wurde.
@export var loop_closed: bool = false


func get_element_total() -> int:
	var total := 0
	for count: int in element_fill.values():
		total += count
	return total


## Neutrale Essenz füllt den Fokus immer bis zur Gesamtkapazität auf.
func get_base_count() -> int:
	if focus_def == null:
		return 0
	return maxi(0, focus_def.max_dots - get_element_total())


func get_main_gem_index() -> int:
	for i in gems.size():
		if gems[i] != null and gems[i].gem != null and gems[i].gem.role == GemDef.Role.MAIN:
			return i
	return -1
