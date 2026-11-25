class_name FocusInstance
extends Resource
## Ein gebauter und befüllter Fokus des Spielers.
## Die Energiepunkte selbst werden nicht gespeichert, sondern von DotField
## aus `dot_seed` und der Füllung reproduzierbar erzeugt.
##
## Gespeichert wird über `to_dict()` / `from_dict()` mit IDs statt Dateipfaden,
## damit Speicherstände Änderungen an den Inhalten überstehen.

const SAVE_VERSION := 1

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


# --- Speichern / Laden ------------------------------------------------------

## Speicherformat (JSON-tauglich): nur IDs, Zahlen und Listen.
func to_dict() -> Dictionary:
	var essences := {}
	for id: StringName in element_fill:
		essences[String(id)] = int(element_fill[id])
	var gem_list := []
	for placed in gems:
		gem_list.append({
			"gem": String(placed.gem.id),
			"engraving": String(placed.engraving.id) if placed.engraving != null else "",
			"x": placed.position.x,
			"y": placed.position.y,
		})
	return {
		"version": SAVE_VERSION,
		"focus": String(focus_def.id),
		"seed": dot_seed,
		"essences": essences,
		"gems": gem_list,
		"loop": Array(loop),
		"loop_closed": loop_closed,
	}


## Baut einen Fokus aus `to_dict()`-Daten. Unbekannte IDs werden übersprungen
## und in `warnings` gemeldet. Fehlt ein Gem, wird der Kreis gelöst, weil die
## Indizes nicht mehr stimmen. Gibt null zurück, wenn der Fokus-Typ fehlt.
static func from_dict(data: Dictionary, content: CraftingContent, warnings: Array[String]) -> FocusInstance:
	var def := content.get_focus(StringName(str(data.get("focus", ""))))
	if def == null:
		warnings.append("Unbekannter Fokus-Typ „%s“." % data.get("focus", ""))
		return null

	var instance := FocusInstance.new()
	instance.focus_def = def
	instance.dot_seed = int(data.get("seed", 0))

	var essences: Dictionary = data.get("essences", {})
	var remaining := def.max_element_dots
	for key: String in essences:
		var id := StringName(key)
		var count := mini(int(essences[key]), remaining)
		if content.get_element(id) == null or not def.allows_element(id):
			warnings.append("Essenz „%s“ wurde entfernt." % key)
			continue
		if count < int(essences[key]):
			warnings.append("Essenz „%s“ wurde auf die Kapazität gekürzt." % key)
		if count > 0:
			instance.element_fill[id] = count
			remaining -= count

	var gems_complete := true
	for entry: Dictionary in data.get("gems", []):
		var gem := content.get_gem(StringName(str(entry.get("gem", ""))))
		var engraving := content.get_engraving(StringName(str(entry.get("engraving", ""))))
		if gem == null or engraving == null:
			warnings.append("Gem „%s“ mit Gravur „%s“ ist unbekannt und wurde entfernt." % [
				entry.get("gem", ""), entry.get("engraving", "")])
			gems_complete = false
			continue
		var pos := Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
		instance.gems.append(PlacedGem.create(gem, engraving, pos))

	if gems_complete:
		for index in data.get("loop", []):
			if int(index) >= 0 and int(index) < instance.gems.size():
				instance.loop.append(int(index))
		instance.loop_closed = bool(data.get("loop_closed", false)) and not instance.loop.is_empty()
	elif not data.get("loop", []).is_empty():
		warnings.append("Der Kreis wurde gelöst, bitte neu verbinden.")
	return instance
