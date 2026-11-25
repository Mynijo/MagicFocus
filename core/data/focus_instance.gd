class_name FocusInstance
extends Resource
## Ein gebauter und befüllter Fokus des Spielers (speicherbar als .tres).
## Die Energiepunkte selbst werden nicht gespeichert, sondern von DotField
## aus `dot_seed` und der Füllung reproduzierbar erzeugt.

@export var focus_def: FocusDef
@export var base_count: int = 0
## Element-ID -> Anzahl farbiger Punkte, z. B. {&"fire": 25}
@export var element_fill: Dictionary = {}
@export var dot_seed: int = 0
## In Platzierungsreihenfolge. Sie bestimmt, welche kleine Rune bei
## Überlappung zuerst einsammelt.
@export var runes: Array[PlacedRune] = []
## Indizes in `runes` in Verbindungsreihenfolge, beginnend bei der Hauptrune.
## Die Kante von der letzten zur ersten Rune ist implizit.
@export var loop: PackedInt32Array = PackedInt32Array()
## true, sobald die letzte Rune wieder mit der Hauptrune verbunden wurde.
@export var loop_closed: bool = false


func get_element_total() -> int:
	var total := 0
	for count: int in element_fill.values():
		total += count
	return total


func get_main_rune_index() -> int:
	for i in runes.size():
		if runes[i] != null and runes[i].rune != null and runes[i].rune.role == RuneDef.Role.MAIN:
			return i
	return -1
