class_name SpellResult
extends RefCounted
## Ergebnis der Auswertung eines Fokus. Reine Daten: wird später von UI,
## Spell-Bibliothek und Kampfsimulation gelesen.

var valid := false
var errors := PackedStringArray()

## Gravur des Hauptgems = Art des Spells
var engraving: EngravingDef
## Wert-Name -> Wert, z. B. {&"damage": 17.0, &"burn": 2.0}
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


## Lesbare Zusammenfassung, z. B. für Tests und Debug-Ausgaben.
func describe() -> String:
	if not valid:
		return "Kein gültiger Spell:\n- " + "\n- ".join(errors)

	var lines := PackedStringArray()
	lines.append(engraving.display_name)
	lines.append("Cast-Zeit: %.2f s   Mana: %.1f" % [cast_time, mana_cost])

	var stat_names := stats.keys()
	stat_names.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for stat: StringName in stat_names:
		lines.append("  %s: %.2f" % [stat, stats[stat]])

	lines.append("")
	for gr in gem_results:
		lines.append("%s %d (%s, %s, x%.2f): %d N-E, %s" % [
			"Hauptgem" if gr.is_main() else "Gem", gr.index, gr.placed.gem.display_name,
			gr.placed.engraving.display_name, gr.multiplier, gr.base_count, str(gr.element_counts)])
	return "\n".join(lines)
