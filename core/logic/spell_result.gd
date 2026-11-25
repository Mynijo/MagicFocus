class_name SpellResult
extends RefCounted
## Ergebnis der Auswertung eines Fokus. Reine Daten: wird später von UI,
## Spell-Bibliothek und Kampfsimulation gelesen.

var valid := false
var errors := PackedStringArray()

var form: SpellFormDef
## Element des Spells (= Element dem Hauptgem), &"" = neutral
var element_id: StringName = &""
## Wert-Name -> Wert, z. B. {&"damage": 17.0, &"burning": 2.0}
var stats: Dictionary = {}
var cast_time: float = 0.0
var mana_cost: float = 0.0

## In Platzierungsreihenfolge (Index = FocusInstance.gems-Index)
var gem_results: Array[GemResult] = []
## Alle Energiepunkte des Fokus (für die Darstellung)
var dots: Array[EnergyDot] = []


func add_stat(stat: StringName, value: float) -> void:
	if is_zero_approx(value) and not stats.has(stat):
		return
	stats[stat] = stats.get(stat, 0.0) + value


func get_stat(stat: StringName) -> float:
	return stats.get(stat, 0.0)


## Lesbare Zusammenfassung, z. B. für Debug-Ansichten.
func describe() -> String:
	if not valid:
		return "Kein gültiger Spell:\n- " + "\n- ".join(errors)

	var lines := PackedStringArray()
	var element_text := String(element_id) if element_id != &"" else "neutral"
	lines.append("%s  [%s]" % [form.display_name, element_text])
	lines.append("Cast-Zeit: %.2f s   Mana: %.1f" % [cast_time, mana_cost])

	var stat_names := stats.keys()
	stat_names.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for stat: StringName in stat_names:
		lines.append("  %s: %.2f" % [stat, stats[stat]])

	lines.append("")
	for rr in gem_results:
		var role_text := "Hauptgem" if rr.is_main() else "Gem"
		var gem_element := String(rr.element_id) if rr.element_id != &"" else "neutral"
		lines.append("%s %d (%s): %d Energie, %s -> %s" % [
			role_text, rr.index, rr.placed.gem.display_name,
			rr.base_count, str(rr.element_counts), gem_element])
	return "\n".join(lines)
