extends TestSuite
## Speichern, Laden und reproduzierbare Punkte.


func test_save_roundtrip() -> void:
	var focus := FocusInstance.new()
	focus.focus_def = content.get_focus(&"mittlerer_fokus")
	focus.element_fill = {&"fire": 10, &"water": 5}
	focus.dot_seed = 3_000_000_123  # größer als int32
	focus.gems = [
		PlacedGem.create(content.get_gem(&"hauptgem_mittel_grob"), engraving(&"heal"), Vector2(-110.5, 70)),
		PlacedGem.create(content.get_gem(&"nebengem_klein_spitz"), engraving(&"crit"), Vector2(130, 50)),
		PlacedGem.create(content.get_gem(&"nebengem_gross_grob"), engraving(&"standard"), Vector2(0, -140)),
	]
	focus.loop = PackedInt32Array([0, 1, 2])
	focus.loop_closed = true

	# über JSON wie in der Werkstatt
	var data: Dictionary = JSON.parse_string(JSON.stringify(focus.to_dict()))
	var warnings: Array[String] = []
	var loaded := FocusInstance.from_dict(data, content, warnings)
	check(loaded != null and warnings.is_empty(), "Laden ohne Warnungen: %s" % [warnings])
	check(loaded.focus_def == focus.focus_def, "Fokus-Typ")
	check(loaded.dot_seed == focus.dot_seed, "Seed %d, war %d" % [focus.dot_seed, loaded.dot_seed])
	check(loaded.element_fill == {&"fire": 10, &"water": 5}, "Essenzen: %s" % [loaded.element_fill])
	check(loaded.gems.size() == 3, "3 Gems")
	check(loaded.gems[1].gem.id == &"nebengem_klein_spitz" and loaded.gems[1].engraving.id == &"crit", "Gem und Gravur über IDs")
	check(loaded.gems[0].position == Vector2(-110.5, 70), "Position")
	check(loaded.loop == focus.loop and loaded.loop_closed, "Kreis")
	var before := evaluate_real(focus)
	var after := evaluate_real(loaded)
	check(before.valid == after.valid and before.stats == after.stats, "Gleicher Spell nach dem Laden")

	# unbekanntes Gem: wird entfernt, der Kreis gelöst
	data.gems[1].gem = "gibt_es_nicht"
	warnings.clear()
	loaded = FocusInstance.from_dict(data, content, warnings)
	check(loaded.gems.size() == 2, "Unbekanntes Gem entfernt")
	check(loaded.loop.is_empty() and not loaded.loop_closed, "Kreis gelöst")
	check(warnings.size() == 2, "Warnungen für Gem und Kreis: %s" % [warnings])

	# nicht erlaubte Essenz und unbekannter Fokus
	data.focus = "feuer_fokus"
	warnings.clear()
	loaded = FocusInstance.from_dict(data, content, warnings)
	check(not loaded.element_fill.has(&"water"), "Wasser im Feuer-Fokus entfernt")
	data.focus = "gibt_es_nicht"
	check(FocusInstance.from_dict(data, content, warnings) == null, "Unbekannter Fokus-Typ = null")


func test_dot_field_reproducible() -> void:
	var def := FocusDef.new()
	var shape := CircleFocusShape.new()
	shape.radius = 250.0
	def.shape = shape
	def.max_dots = 140
	def.max_element_dots = 60
	var focus := FocusInstance.new()
	focus.focus_def = def
	focus.element_fill = {&"fire": 25, &"air": 15}
	check(focus.get_base_count() == 100, "Neutrale Essenz füllt bis zur Kapazität auf, war %d" % focus.get_base_count())
	focus.dot_seed = 42

	var a := DotField.generate(focus)
	var b := DotField.generate(focus)
	check(a.size() == 140, "100 N-E + 40 E erwartet, war %d" % a.size())
	var same := a.size() == b.size()
	var inside := true
	for i in a.size():
		same = same and a[i].position == b[i].position and a[i].element_id == b[i].element_id
		inside = inside and shape.contains(a[i].position)
	check(same, "Gleicher Seed sollte gleiche Punkte ergeben")
	check(inside, "Alle Punkte sollten im Fokus liegen")

	focus.dot_seed = 43
	var c := DotField.generate(focus)
	check(c[0].position != a[0].position, "Anderer Seed sollte andere Punkte ergeben")


func test_example_focus_evaluates() -> void:
	var focus := FocusInstance.new()
	focus.focus_def = content.get_focus(&"kleiner_fokus")
	focus.element_fill = {&"fire": 25, &"air": 15}
	focus.dot_seed = 1234
	var standard := engraving(&"standard")
	focus.gems = [
		PlacedGem.create(content.get_gem(&"hauptgem_mittel_grob"), engraving(&"magischer_bolzen"), Vector2(-120, 80)),
		PlacedGem.create(content.get_gem(&"nebengem_mittel_grob"), standard, Vector2(130, 60)),
		PlacedGem.create(content.get_gem(&"nebengem_mittel_spitz"), standard, Vector2(0, -150)),
	]
	focus.loop = PackedInt32Array([0, 1, 2])
	focus.loop_closed = true
	var r := evaluate_real(focus)
	check(r.valid, "Beispiel-Fokus sollte gültig sein: %s" % [r.errors])
	check(r.get_stat(&"damage") > 0.0, "Beispiel sollte Schaden machen")
	print("\nBeispiel-Fokus:\n" + r.describe())
