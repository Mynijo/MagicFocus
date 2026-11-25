extends SceneTree
## Tests für die Spell-Auswertung (M1).
## Ausführen:  godot --headless --path <projekt> -s res://tests/run_tests.gd
## Exit-Code 0 = alles grün.

var _checks := 0
var _failures := 0
var _current := ""


func _init() -> void:
	var tests := [
		test_inner_vs_outer,
		test_overlap_main_first,
		test_overlap_minor_placement_order,
		test_capacity_takes_nearest,
		test_crossing_rejected,
		test_not_closed_rejected,
		test_too_few_runes_rejected,
		test_loop_must_start_at_main,
		test_rune_outside_focus_rejected,
		test_element_threshold,
		test_element_tie_uses_list_order,
		test_cast_time_and_mana,
		test_spell_stats,
		test_dot_field_reproducible,
		test_content_loads_and_evaluates,
		test_canvas_editing,
		test_canvas_auto_connect_and_preview,
		test_focus_shapes,
		test_allowed_elements,
		test_edges_must_stay_inside_shape,
		test_status_rune,
		test_explosion_rune,
		test_spell_change_preview,
	]
	for test: Callable in tests:
		_current = test.get_method()
		test.call()
	print("\n%d Prüfungen, %d Fehler" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("FEHLER [%s]: %s" % [_current, message])


# --- Hilfsfunktionen --------------------------------------------------------

func make_rune(role: RuneDef.Role, area: RuneDef.Area, radius: float,
		max_element := 100, max_base := 100) -> RuneDef:
	var rune := RuneDef.new()
	rune.id = &"test"
	rune.display_name = "Testrune"
	rune.role = role
	rune.area = area
	rune.radius = radius
	rune.max_element = max_element
	rune.max_base = max_base
	if role == RuneDef.Role.MAIN:
		rune.spell_form = make_form()
	return rune


func make_form() -> SpellFormDef:
	var form := SpellFormDef.new()
	form.display_name = "Testgeschoss"
	form.base_stats = {&"damage": 5.0}
	var rule := ScalingRule.new()
	rule.source = ScalingRule.Source.ANY_ELEMENT
	rule.per_n = 1
	rule.stat = &"damage"
	rule.amount = 1.0
	form.scaling_rules = [rule]
	return form


func make_focus(placed: Array[PlacedRune], loop: Array[int], closed := true) -> FocusInstance:
	var def := FocusDef.new()
	var shape := CircleFocusShape.new()
	shape.radius = 1000.0
	def.shape = shape
	def.max_runes = 10
	def.max_base_dots = 1000
	def.max_element_dots = 1000
	var focus := FocusInstance.new()
	focus.focus_def = def
	focus.runes = placed
	focus.loop = PackedInt32Array(loop)
	focus.loop_closed = closed
	return focus


func make_element(id: StringName, stat := &"", per_n := 5, amount := 1.0) -> ElementDef:
	var element := ElementDef.new()
	element.id = id
	element.display_name = String(id)
	if stat != &"":
		var rule := ScalingRule.new()
		rule.source = ScalingRule.Source.ELEMENT
		rule.element_id = id
		rule.per_n = per_n
		rule.stat = stat
		rule.amount = amount
		element.minor_rules = [rule]
	return element


func dots_around(center: Vector2, count: int, distance: float, element: StringName) -> Array[EnergyDot]:
	var dots: Array[EnergyDot] = []
	for i in count:
		dots.append(EnergyDot.new(center + Vector2.from_angle(TAU * i / count) * distance, element))
	return dots


## Standard-Dreieck: Hauptrune oben, zwei kleine Runen unten.
func triangle(main_area: RuneDef.Area, main_radius: float) -> FocusInstance:
	var placed: Array[PlacedRune] = [
		PlacedRune.create(make_rune(RuneDef.Role.MAIN, main_area, main_radius), Vector2(0, -100)),
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.OUTER, 50), Vector2(-100, 80)),
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.OUTER, 50), Vector2(100, 80)),
	]
	return make_focus(placed, [0, 1, 2])


func elements_fw() -> Array[ElementDef]:
	return [make_element(&"fire"), make_element(&"water")]


# --- Tests ------------------------------------------------------------------

func test_inner_vs_outer() -> void:
	var inside: Array[EnergyDot] = [EnergyDot.new(Vector2(0, 20), &"fire")]  # Schwerpunkt-Nähe
	var outside: Array[EnergyDot] = [EnergyDot.new(Vector2(0, -150), &"fire")]  # über der Hauptrune

	var r := SpellEvaluator.evaluate(triangle(RuneDef.Area.INNER, 300), elements_fw(), inside)
	check(r.valid, "Dreieck sollte gültig sein: %s" % [r.errors])
	check(r.rune_results[0].collected.size() == 1, "Innen-Hauptrune sollte den inneren Punkt einsammeln")

	r = SpellEvaluator.evaluate(triangle(RuneDef.Area.INNER, 300), elements_fw(), outside)
	check(r.rune_results[0].collected.size() == 0, "Innen-Hauptrune darf den äußeren Punkt nicht einsammeln")

	r = SpellEvaluator.evaluate(triangle(RuneDef.Area.OUTER, 300), elements_fw(), inside)
	check(r.rune_results[0].collected.size() == 0, "Außen-Hauptrune darf den inneren Punkt nicht einsammeln")

	r = SpellEvaluator.evaluate(triangle(RuneDef.Area.OUTER, 300), elements_fw(), outside)
	check(r.rune_results[0].collected.size() == 1, "Außen-Hauptrune sollte den äußeren Punkt einsammeln")

	r = SpellEvaluator.evaluate(triangle(RuneDef.Area.BOTH, 300), elements_fw(), inside + outside)
	check(r.rune_results[0].collected.size() == 2, "Hauptrune mit beiden Bereichen sollte beide Punkte einsammeln")


func test_overlap_main_first() -> void:
	# Hauptrune wird als ZWEITE platziert, sammelt aber trotzdem zuerst.
	var placed: Array[PlacedRune] = [
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.BOTH, 200), Vector2(100, 80)),
		PlacedRune.create(make_rune(RuneDef.Role.MAIN, RuneDef.Area.BOTH, 200), Vector2(0, -100)),
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.BOTH, 200), Vector2(-100, 80)),
	]
	var dots: Array[EnergyDot] = [EnergyDot.new(Vector2(50, -10), &"fire")]
	var r := SpellEvaluator.evaluate(make_focus(placed, [1, 0, 2]), elements_fw(), dots)
	check(r.valid, "sollte gültig sein: %s" % [r.errors])
	check(r.rune_results[1].collected.size() == 1, "Hauptrune sollte den überlappenden Punkt bekommen")
	check(r.rune_results[0].collected.size() == 0, "Kleine Rune darf den Punkt der Hauptrune nicht bekommen")


func test_overlap_minor_placement_order() -> void:
	var placed: Array[PlacedRune] = [
		PlacedRune.create(make_rune(RuneDef.Role.MAIN, RuneDef.Area.BOTH, 50), Vector2(0, -100)),
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.BOTH, 250), Vector2(-100, 80)),
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.BOTH, 250), Vector2(100, 80)),
	]
	# Punkt liegt näher an Rune 2, aber Rune 1 wurde zuerst platziert.
	var dots: Array[EnergyDot] = [EnergyDot.new(Vector2(40, 180), &"fire")]
	var r := SpellEvaluator.evaluate(make_focus(placed, [0, 2, 1]), elements_fw(), dots)
	check(r.rune_results[1].collected.size() == 1, "Zuerst platzierte kleine Rune sollte den Punkt bekommen")
	check(r.rune_results[2].collected.size() == 0, "Später platzierte kleine Rune darf den Punkt nicht bekommen")


func test_capacity_takes_nearest() -> void:
	var placed: Array[PlacedRune] = [
		PlacedRune.create(make_rune(RuneDef.Role.MAIN, RuneDef.Area.BOTH, 10), Vector2(0, 0)),
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.BOTH, 100, 2, 1), Vector2(300, 0)),
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.BOTH, 10), Vector2(0, 400)),
	]
	var dots: Array[EnergyDot] = []
	for i in [5, 1, 4, 2, 3]:  # absichtlich ungeordnet
		dots.append(EnergyDot.new(Vector2(300 + 10 * i, 0), &"fire"))
	dots.append(EnergyDot.new(Vector2(300, 30)))  # Basispunkte, Kapazität 1
	dots.append(EnergyDot.new(Vector2(300, 15)))
	var r := SpellEvaluator.evaluate(make_focus(placed, [0, 1, 2]), elements_fw(), dots)
	var minor := r.rune_results[1]
	check(minor.element_counts.get(&"fire", 0) == 2, "Kapazität 2 für farbige Punkte sollte gelten")
	check(minor.base_count == 1, "Kapazität 1 für Basispunkte sollte gelten")
	var xs := []
	for dot in minor.collected:
		if not dot.is_base():
			xs.append(dot.position.x)
	xs.sort()
	check(xs == [310.0, 320.0], "Die nächstgelegenen Punkte sollten zuerst genommen werden, war %s" % [xs])
	for dot in minor.collected:
		if dot.is_base():
			check(dot.position == Vector2(300, 15), "Der nähere Basispunkt sollte genommen werden")


func test_crossing_rejected() -> void:
	var placed: Array[PlacedRune] = [
		PlacedRune.create(make_rune(RuneDef.Role.MAIN, RuneDef.Area.BOTH, 50), Vector2(0, 0)),
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.BOTH, 50), Vector2(100, 0)),
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.BOTH, 50), Vector2(100, 100)),
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.BOTH, 50), Vector2(0, 100)),
	]
	var r := SpellEvaluator.evaluate(make_focus(placed, [0, 2, 1, 3]), elements_fw(), [] as Array[EnergyDot])
	check(not r.valid, "Sich kreuzende Verbindungen sollten ungültig sein")
	check(_has_error(r, "kreuzen"), "Fehlermeldung zur Kreuzung erwartet, war %s" % [r.errors])

	r = SpellEvaluator.evaluate(make_focus(placed, [0, 1, 2, 3]), elements_fw(), [] as Array[EnergyDot])
	check(r.valid, "Viereck ohne Kreuzung sollte gültig sein: %s" % [r.errors])


func test_not_closed_rejected() -> void:
	var focus := triangle(RuneDef.Area.INNER, 100)
	focus.loop_closed = false
	var r := SpellEvaluator.evaluate(focus, elements_fw(), [] as Array[EnergyDot])
	check(not r.valid and _has_error(r, "nicht geschlossen"), "Offener Kreis sollte ungültig sein: %s" % [r.errors])


func test_too_few_runes_rejected() -> void:
	var placed: Array[PlacedRune] = [
		PlacedRune.create(make_rune(RuneDef.Role.MAIN, RuneDef.Area.BOTH, 50), Vector2(0, 0)),
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.BOTH, 50), Vector2(100, 0)),
	]
	var r := SpellEvaluator.evaluate(make_focus(placed, [0, 1]), elements_fw(), [] as Array[EnergyDot])
	check(not r.valid and _has_error(r, "mindestens"), "Zwei Runen sollten nicht reichen: %s" % [r.errors])


func test_loop_must_start_at_main() -> void:
	var focus := triangle(RuneDef.Area.INNER, 100)
	focus.loop = PackedInt32Array([1, 2, 0])
	var r := SpellEvaluator.evaluate(focus, elements_fw(), [] as Array[EnergyDot])
	check(not r.valid and _has_error(r, "Hauptrune beginnen"), "Kreis muss bei Hauptrune starten: %s" % [r.errors])


func test_rune_outside_focus_rejected() -> void:
	var focus := triangle(RuneDef.Area.INNER, 100)
	focus.runes[2].position = Vector2(5000, 0)
	var r := SpellEvaluator.evaluate(focus, elements_fw(), [] as Array[EnergyDot])
	check(not r.valid and _has_error(r, "außerhalb"), "Rune außerhalb sollte ungültig sein: %s" % [r.errors])


func test_element_threshold() -> void:
	var main_pos := Vector2(0, -100)
	var dots := dots_around(main_pos, 10, 20, &"fire") + dots_around(main_pos, 9, 30, &"water")
	var r := SpellEvaluator.evaluate(triangle(RuneDef.Area.BOTH, 40), elements_fw(), dots, 10)
	check(r.rune_results[0].element_id == &"fire", "10 Feuerpunkte sollten Feuer ergeben")
	check(r.element_id == &"fire", "Spell-Element sollte Feuer sein")

	dots = dots_around(main_pos, 9, 20, &"fire")
	r = SpellEvaluator.evaluate(triangle(RuneDef.Area.BOTH, 40), elements_fw(), dots, 10)
	check(r.rune_results[0].element_id == &"", "9 Feuerpunkte sollten bei Schwelle 10 neutral bleiben")

	dots = dots_around(main_pos, 4, 20, &"fire")
	r = SpellEvaluator.evaluate(triangle(RuneDef.Area.BOTH, 40), elements_fw(), dots)
	check(r.rune_results[0].element_id == &"fire", "4 Feuerpunkte sollten bei Standardschwelle 4 reichen")


func test_element_tie_uses_list_order() -> void:
	var main_pos := Vector2(0, -100)
	var dots := dots_around(main_pos, 10, 20, &"fire") + dots_around(main_pos, 10, 30, &"water")
	var r := SpellEvaluator.evaluate(triangle(RuneDef.Area.BOTH, 40), elements_fw(), dots)
	check(r.element_id == &"fire", "Bei Gleichstand sollte das zuerst gelistete Element gewinnen")
	var reversed: Array[ElementDef] = [make_element(&"water"), make_element(&"fire")]
	r = SpellEvaluator.evaluate(triangle(RuneDef.Area.BOTH, 40), reversed, dots)
	check(r.element_id == &"water", "Mit umgekehrter Liste sollte Wasser gewinnen")


func test_cast_time_and_mana() -> void:
	var placed: Array[PlacedRune] = [
		PlacedRune.create(make_rune(RuneDef.Role.MAIN, RuneDef.Area.BOTH, 10), Vector2(0, 0)),
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.BOTH, 50), Vector2(300, 0)),
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.BOTH, 10), Vector2(0, 400)),
	]
	var focus := make_focus(placed, [0, 1, 2])
	var elements: Array[ElementDef] = [make_element(&"air", &"cast_time_reduction", 5, 0.25)]

	var r := SpellEvaluator.evaluate(focus, elements, [] as Array[EnergyDot])
	check(is_equal_approx(r.cast_time, 3.0), "3 Runen = 3 s, war %s" % r.cast_time)
	check(is_equal_approx(r.mana_cost, 120.0), "Umfang 1200 * 0.1 = 120 Mana, war %s" % r.mana_cost)

	r = SpellEvaluator.evaluate(focus, elements, dots_around(Vector2(300, 0), 10, 20, &"air"))
	check(r.rune_results[1].element_id == &"air", "Kleine Rune sollte Luft annehmen")
	check(is_equal_approx(r.cast_time, 2.5), "10 Luft = -0.5 s, war %s" % r.cast_time)


func test_spell_stats() -> void:
	var placed: Array[PlacedRune] = [
		PlacedRune.create(make_rune(RuneDef.Role.MAIN, RuneDef.Area.BOTH, 50), Vector2(0, 0)),
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.BOTH, 50), Vector2(300, 0)),
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.BOTH, 10), Vector2(0, 400)),
	]
	var elements: Array[ElementDef] = [make_element(&"fire", &"burning", 5, 1.0)]
	var dots := dots_around(Vector2(0, 0), 12, 20, &"fire") + dots_around(Vector2(300, 0), 10, 20, &"fire")
	var r := SpellEvaluator.evaluate(make_focus(placed, [0, 1, 2]), elements, dots)
	check(r.valid, "sollte gültig sein: %s" % [r.errors])
	check(r.element_id == &"fire", "Spell sollte Feuer sein")
	check(is_equal_approx(r.get_stat(&"damage"), 17.0), "Schaden 5 + 12 = 17, war %s" % r.get_stat(&"damage"))
	check(is_equal_approx(r.get_stat(&"burning"), 2.0), "10 Feuer in kleiner Rune = 2 Burning, war %s" % r.get_stat(&"burning"))


func test_dot_field_reproducible() -> void:
	var def := FocusDef.new()
	var shape := CircleFocusShape.new()
	shape.radius = 250.0
	def.shape = shape
	var focus := FocusInstance.new()
	focus.focus_def = def
	focus.base_count = 100
	focus.element_fill = {&"fire": 25, &"air": 15}
	focus.dot_seed = 42

	var a := DotField.generate(focus)
	var b := DotField.generate(focus)
	check(a.size() == 140, "100 Basis + 40 farbige Punkte erwartet, war %d" % a.size())
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


func test_content_loads_and_evaluates() -> void:
	var content := load("res://content/crafting_content.tres") as CraftingContent
	check(content != null, "crafting_content.tres sollte laden")
	if content == null:
		return
	check(content.elements.size() == 5, "5 Elemente erwartet")
	check(content.runes.size() == 8, "8 Runen erwartet")
	check(content.foci.size() == 8, "8 Fokus-Typen erwartet")
	check(content.get_element(&"fire").minor_rules.size() == 1, "Feuer sollte eine Regel haben")
	check(content.get_rune(&"hauptrune_geschoss").spell_form != null, "Hauptrune braucht eine Spell-Form")

	var focus := FocusInstance.new()
	focus.focus_def = content.get_focus(&"kleiner_fokus")
	focus.base_count = 100
	focus.element_fill = {&"fire": 25, &"air": 15}
	focus.dot_seed = 1234
	focus.runes = [
		PlacedRune.create(content.get_rune(&"hauptrune_geschoss"), Vector2(-120, 80)),
		PlacedRune.create(content.get_rune(&"zusatzrune_standard"), Vector2(130, 60)),
		PlacedRune.create(content.get_rune(&"zusatzrune_standard"), Vector2(0, -150)),
	]
	focus.loop = PackedInt32Array([0, 1, 2])
	focus.loop_closed = true
	var r := SpellEvaluator.evaluate(focus, content.elements)
	check(r.valid, "Beispiel-Fokus sollte gültig sein: %s" % [r.errors])
	print("\nBeispiel-Fokus:\n" + r.describe())


func test_canvas_editing() -> void:
	var content := load("res://content/crafting_content.tres") as CraftingContent
	var main := content.get_rune(&"hauptrune_geschoss")
	var minor := content.get_rune(&"zusatzrune_standard")
	var focus := FocusInstance.new()
	focus.focus_def = content.get_focus(&"kleiner_fokus")
	var canvas := FocusCanvas.new()
	canvas.focus = focus
	canvas.auto_connect = false  # manuelles Verbinden testen
	var messages: Array[String] = []
	canvas.message.connect(func(text: String) -> void: messages.append(text))

	canvas._try_place(minor, Vector2(0, 0))
	check(focus.runes.is_empty() and messages.back().contains("zuerst eine Hauptrune"), "Zusatzrune vor Hauptrune sollte abgelehnt werden")
	canvas._try_place(main, Vector2(-100, 50))
	canvas._try_place(main, Vector2(100, 50))
	check(focus.runes.size() == 1 and messages.back().contains("bereits eine Hauptrune"), "Zweite Hauptrune sollte abgelehnt werden")
	canvas._try_place(minor, Vector2(-95, 50))
	check(messages.back().contains("Zu nah"), "Zu nahe Rune sollte abgelehnt werden")
	canvas._try_place(minor, Vector2(400, 0))
	check(messages.back().contains("innerhalb"), "Rune außerhalb sollte abgelehnt werden")
	canvas._try_place(minor, Vector2(100, 50))
	canvas._try_place(minor, Vector2(0, -120))
	canvas._try_place(minor, Vector2(0, 150))
	check(focus.runes.size() == 3 and messages.back().contains("höchstens 3"), "Runen-Kapazität sollte gelten")

	canvas._try_connect(1)
	check(focus.loop.is_empty(), "Kreis darf nicht bei einer Zusatzrune beginnen")
	canvas._try_connect(0)
	canvas._try_connect(1)
	canvas._try_connect(0)
	check(not focus.loop_closed and messages.back().contains("mindestens"), "Schließen mit 2 Runen sollte abgelehnt werden")
	canvas._try_connect(2)
	canvas._try_connect(0)
	check(focus.loop_closed and focus.loop == PackedInt32Array([0, 1, 2]), "Kreis sollte geschlossen sein")
	var r := SpellEvaluator.evaluate(focus, content.elements)
	check(r.valid, "Im Editor gebauter Kreis sollte gültig sein: %s" % [r.errors])

	canvas.undo_connection()
	check(not focus.loop_closed and focus.loop.size() == 3, "Zurück sollte zuerst den Kreis öffnen")
	canvas.remove_rune(1)
	check(focus.runes.size() == 2 and focus.loop == PackedInt32Array([0, 1]),
		"Entfernen sollte die Nachbarn verbinden, war %s" % [focus.loop])
	check(not focus.loop_closed, "Mit 2 Runen darf der Kreis nicht geschlossen sein")
	canvas.free()


func test_canvas_auto_connect_and_preview() -> void:
	var content := load("res://content/crafting_content.tres") as CraftingContent
	var main := content.get_rune(&"hauptrune_geschoss")
	var minor := content.get_rune(&"zusatzrune_standard")
	var focus := FocusInstance.new()
	focus.focus_def = content.get_focus(&"mittlerer_fokus")
	focus.base_count = 150
	focus.element_fill = {&"fire": 60}
	focus.dot_seed = 7
	var canvas := FocusCanvas.new()
	canvas.focus = focus
	canvas.evaluate_preview = func(f: FocusInstance) -> SpellResult:
		return SpellEvaluator.evaluate(f, content.elements)

	canvas._try_place(main, Vector2(-120, 60))
	canvas._try_place(minor, Vector2(120, 60))
	check(focus.loop == PackedInt32Array([0, 1]) and not focus.loop_closed, "Zweite Rune sollte automatisch verbunden sein")
	canvas._try_place(minor, Vector2(0, -150))
	check(focus.loop == PackedInt32Array([0, 1, 2]) and focus.loop_closed, "Ab 3 Runen sollte sich der Kreis schließen")
	canvas._try_place(minor, Vector2(0, 200))
	check(focus.loop == PackedInt32Array([0, 1, 2, 3]) and focus.loop_closed,
		"Neue Rune sollte vor der schließenden Kante eingefügt werden")

	canvas.remove_rune(2)
	check(focus.loop == PackedInt32Array([0, 1, 2]) and focus.loop_closed,
		"Nach Entfernen sollte der Kreis mit 3 Runen geschlossen bleiben, war %s" % [focus.loop])

	# Vorschau: verändert den Fokus nicht, liefert eine gültige Auswertung mit der neuen Rune
	canvas.mode = FocusCanvas.Mode.PLACE
	canvas.placing_rune = minor
	canvas._mouse_inside = true
	canvas._mouse_focus = Vector2(-250, 180)  # zwischen letzter Zusatzrune und Hauptrune, ohne Kreuzung
	canvas.update_preview()
	check(focus.runes.size() == 3, "Vorschau darf den Fokus nicht verändern")
	check(canvas._preview != null and canvas._preview.valid, "Vorschau sollte einen gültigen Spell ergeben")
	check(canvas._preview_index == 3, "Vorschau-Rune sollte die vierte sein")

	canvas._mouse_focus = Vector2(1000, 0)
	canvas.update_preview()
	check(canvas._preview == null and canvas._preview_error.contains("innerhalb"), "Vorschau außerhalb sollte den Grund nennen")

	# Main entfernen löst den Kreis; neue Hauptrune verbindet die vorhandenen Zusatzrunen
	canvas.remove_rune(0)
	check(focus.loop.is_empty() and not focus.loop_closed, "Ohne Hauptrune gibt es keinen Kreis")
	canvas._try_place(main, Vector2(-150, 100))
	check(focus.loop == PackedInt32Array([2, 0, 1]) and focus.loop_closed,
		"Neue Hauptrune sollte die Zusatzrunen verbinden, war %s" % [focus.loop])
	canvas.free()


func test_focus_shapes() -> void:
	var star := StarFocusShape.new()
	star.points = 5
	star.outer_radius = 300.0
	star.inner_radius = 150.0
	check(star.get_outline().size() == 10, "Stern mit 5 Zacken hat 10 Eckpunkte")
	check(star.contains(Vector2.ZERO), "Sternmitte liegt im Stern")
	check(star.contains(Vector2(0, -280)), "Obere Zacke liegt im Stern")
	check(not star.contains(Vector2(0, 280)), "Zwischen den unteren Zacken liegt außerhalb")
	star.inner_radius = 290.0
	check(star.contains(Vector2(0, 280)), "Nach Änderung des Innenradius neu berechnen")

	var drop := DropFocusShape.new()
	check(drop.contains(Vector2.ZERO), "Tropfenmitte liegt im Tropfen")
	check(drop.contains(Vector2(0, -300)), "Nahe der Spitze liegt im Tropfen")
	check(not drop.contains(Vector2(200, -250)), "Neben der Spitze liegt außerhalb")
	check(drop.contains(Vector2(0, 300)), "Unten im Bauch liegt im Tropfen")

	for shape: FocusShape in [star, drop]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var inside := true
		for i in 300:
			inside = inside and shape.contains(shape.random_point(rng))
		check(inside, "Zufallspunkte sollten in der Form %s liegen" % shape.get_shape_name())


func test_allowed_elements() -> void:
	var content := load("res://content/crafting_content.tres") as CraftingContent
	var fire_focus := content.get_focus(&"feuer_fokus")
	check(fire_focus.allows_element(&"fire") and not fire_focus.allows_element(&"water"), "Feuer-Fokus erlaubt nur Feuer")
	check(content.get_focus(&"kleiner_fokus").allows_element(&"water"), "Normaler Fokus erlaubt alle Elemente")

	var focus := FocusInstance.new()
	focus.focus_def = fire_focus
	focus.element_fill = {&"fire": 60, &"water": 5}
	focus.runes = [
		PlacedRune.create(content.get_rune(&"hauptrune_geschoss"), Vector2(-100, 60)),
		PlacedRune.create(content.get_rune(&"zusatzrune_standard"), Vector2(100, 60)),
		PlacedRune.create(content.get_rune(&"zusatzrune_standard"), Vector2(0, -120)),
	]
	focus.loop = PackedInt32Array([0, 1, 2])
	focus.loop_closed = true
	var r := SpellEvaluator.evaluate(focus, content.elements)
	check(not r.valid and _has_error(r, "keine Wasser-Essenz"), "Wasser im Feuer-Fokus sollte abgelehnt werden: %s" % [r.errors])
	focus.element_fill = {&"fire": 80}
	r = SpellEvaluator.evaluate(focus, content.elements)
	check(r.valid, "80 Feuer im Feuer-Fokus sollte gültig sein: %s" % [r.errors])

	focus.focus_def = content.get_focus(&"neutraler_fokus")
	focus.base_count = 300
	r = SpellEvaluator.evaluate(focus, content.elements)
	check(not r.valid and _has_error(r, "Zu viele Essenzen"), "Essenzen im neutralen Fokus sollten abgelehnt werden")
	focus.element_fill = {}
	r = SpellEvaluator.evaluate(focus, content.elements)
	check(r.valid, "300 Basispunkte im neutralen Fokus sollten gültig sein: %s" % [r.errors])


func test_edges_must_stay_inside_shape() -> void:
	var content := load("res://content/crafting_content.tres") as CraftingContent
	var star_def := content.get_focus(&"stern_fokus")
	var star := star_def.shape
	var top := Vector2(0, -300)
	var right := Vector2.from_angle(deg_to_rad(-18)) * 300  # benachbarte Zacke
	check(star.contains(top) and star.contains(right), "Beide Zackenspitzen liegen im Stern")
	check(not star.contains_segment(top, right), "Strecke zwischen zwei Zacken verlässt den Stern")
	check(star.contains_segment(Vector2.ZERO, top), "Strecke von der Mitte in eine Zacke bleibt im Stern")
	check(content.get_focus(&"kleiner_fokus").shape.contains_segment(Vector2(-200, 0), Vector2(200, 0)),
		"Im Kreis bleibt jede Strecke zwischen inneren Punkten innerhalb")

	var focus := FocusInstance.new()
	focus.focus_def = star_def
	focus.runes = [
		PlacedRune.create(content.get_rune(&"hauptrune_geschoss"), top),
		PlacedRune.create(content.get_rune(&"zusatzrune_standard"), right),
		PlacedRune.create(content.get_rune(&"zusatzrune_standard"), Vector2(0, 50)),
	]
	focus.loop = PackedInt32Array([0, 1, 2])
	focus.loop_closed = true
	var r := SpellEvaluator.evaluate(focus, content.elements)
	check(not r.valid and _has_error(r, "innerhalb des Fokus verlaufen"),
		"Kante durch den leeren Bereich sollte abgelehnt werden: %s" % [r.errors])

	focus.runes[1].position = Vector2(100, -40)
	r = SpellEvaluator.evaluate(focus, content.elements)
	check(r.valid, "Kreis innerhalb des Sterns sollte gültig sein: %s" % [r.errors])

	var canvas := FocusCanvas.new()
	canvas.focus = focus
	canvas.auto_connect = false
	focus.loop = PackedInt32Array([0])
	focus.loop_closed = false
	focus.runes[1].position = right
	check(canvas.connect_error(1).contains("innerhalb des Fokus"), "Werkstatt sollte die Verbindung ablehnen")
	canvas.free()


## Fokus mit kleiner Hauptrune bei (0,0), Test-Rune bei (300,0) und Füllrune bei (0,400).
func _single_rune_focus(content: CraftingContent, main: RuneDef, minor: RuneDef) -> FocusInstance:
	var placed: Array[PlacedRune] = [
		PlacedRune.create(main, Vector2(0, 0)),
		PlacedRune.create(minor, Vector2(300, 0)),
		PlacedRune.create(make_rune(RuneDef.Role.MINOR, RuneDef.Area.BOTH, 10), Vector2(0, 400)),
	]
	return make_focus(placed, [0, 1, 2])


func test_status_rune() -> void:
	var content := load("res://content/crafting_content.tres") as CraftingContent
	var status := content.get_rune(&"zusatzrune_status")
	check(status != null and not status.use_element_rules, "Statuseffekt-Rune sollte existieren und keine Element-Boni nutzen")
	var rune := status.duplicate() as RuneDef
	rune.area = RuneDef.Area.BOTH  # Für den Test alle Punkte im Radius zählen
	var focus := _single_rune_focus(content, make_rune(RuneDef.Role.MAIN, RuneDef.Area.BOTH, 10), rune)

	var center := Vector2(300, 0)
	var dots := dots_around(center, 5, 20, &"fire") + dots_around(center, 4, 30, &"water") \
		+ dots_around(center, 10, 40, &"air") + dots_around(center, 1, 50, &"lightning")
	var r := SpellEvaluator.evaluate(focus, content.elements, dots)
	check(r.valid, "sollte gültig sein: %s" % [r.errors])
	check(is_equal_approx(r.get_stat(&"burn"), 5.0), "5 Feuer = 5 Burn, war %s" % r.get_stat(&"burn"))
	check(is_equal_approx(r.get_stat(&"wet"), 0.0), "4 Wasser = kein Wet (unter 5), war %s" % r.get_stat(&"wet"))
	check(is_equal_approx(r.get_stat(&"slow"), 10.0), "10 Luft = 10 Slow, war %s" % r.get_stat(&"slow"))
	check(is_equal_approx(r.get_stat(&"shock"), 0.0), "1 Blitz = kein Shock")
	check(r.rune_results[1].element_id == &"air", "Rune nimmt trotzdem Luft als Element an")
	check(is_equal_approx(r.get_stat(&"cast_time_reduction"), 0.0),
		"Element-Bonus der Luft (Cast-Zeit) darf bei der Statuseffekt-Rune nicht greifen")

	# Gegenprobe: Standard-Zusatzrune mit gleichen Punkten bekommt den Luft-Bonus
	var standard := content.get_rune(&"zusatzrune_standard").duplicate() as RuneDef
	standard.area = RuneDef.Area.BOTH
	r = SpellEvaluator.evaluate(_single_rune_focus(content, make_rune(RuneDef.Role.MAIN, RuneDef.Area.BOTH, 10), standard),
		content.elements, dots)
	check(r.get_stat(&"cast_time_reduction") > 0.0, "Standard-Zusatzrune sollte den Luft-Bonus bekommen")


func test_explosion_rune() -> void:
	var content := load("res://content/crafting_content.tres") as CraftingContent
	var explosion := content.get_rune(&"hauptrune_explosion")
	check(explosion.role == RuneDef.Role.MAIN and explosion.area == RuneDef.Area.OUTER, "Explosion ist eine Hauptrune mit Außenbereich")
	check(explosion.radius > content.get_rune(&"hauptrune_geschoss").radius, "Explosion hat einen größeren Einflussbereich")
	check(explosion.strength < 1.0, "Explosion hat einen niedrigeren Multiplikator")

	var rune := explosion.duplicate() as RuneDef
	rune.area = RuneDef.Area.BOTH
	var focus := _single_rune_focus(content, rune, make_rune(RuneDef.Role.MINOR, RuneDef.Area.BOTH, 10))
	var r := SpellEvaluator.evaluate(focus, content.elements, dots_around(Vector2.ZERO, 20, 50, &"fire"))
	check(r.valid and r.form.id == &"explosion", "Spell sollte eine Explosion sein")
	# Grundschaden 8 + 20 Feuer * 1 * Stärke 0.6 = 20
	check(is_equal_approx(r.get_stat(&"damage"), 20.0), "Schaden 8 + 20 * 0.6 = 20, war %s" % r.get_stat(&"damage"))


func test_spell_change_preview() -> void:
	var content := load("res://content/crafting_content.tres") as CraftingContent
	var workshop: Node = load("res://ui/workshop/workshop.tscn").instantiate()

	var before := SpellResult.new()
	before.valid = true
	before.form = content.get_rune(&"hauptrune_geschoss").spell_form
	before.stats = {&"damage": 10.0}
	before.cast_time = 3.0
	before.mana_cost = 50.0
	var after := SpellResult.new()
	after.valid = true
	after.form = before.form
	after.stats = {&"damage": 14.0, &"burn": 5.0}
	after.cast_time = 4.0
	after.mana_cost = 50.0

	var text: String = workshop._diff_text(before, after)
	check(text.contains("10 → [b]14[/b]") and text.contains("(+4)"), "Schaden-Änderung sollte angezeigt werden: %s" % text)
	check(text.contains("Burn (Stacks): 0 → [b]5[/b]"), "Neuer Statuswert sollte als Zuwachs erscheinen")
	check(text.contains("Cast-Zeit (s): 3 → [b]4[/b] [color=#ff9090]"), "Längere Cast-Zeit sollte rot sein")

	var invalid := SpellResult.new()
	text = workshop._diff_text(invalid, after)
	check(text.contains("wird gültig"), "Übergang ungültig -> gültig sollte genannt werden")
	invalid.errors.append("Testfehler")
	text = workshop._diff_text(before, invalid)
	check(text.contains("wäre ungültig") and text.contains("Testfehler"), "Ungültige Vorschau sollte die Gründe nennen")
	workshop.free()

	# Canvas meldet die Vorschau
	var focus := FocusInstance.new()
	focus.focus_def = content.get_focus(&"kleiner_fokus")
	var canvas := FocusCanvas.new()
	canvas.focus = focus
	canvas.evaluate_preview = func(f: FocusInstance) -> SpellResult: return SpellEvaluator.evaluate(f, content.elements)
	var received: Array = []
	canvas.preview_changed.connect(func(p: SpellResult) -> void: received.append(p))
	canvas.placing_rune = content.get_rune(&"hauptrune_geschoss")
	canvas._mouse_inside = true
	canvas._mouse_focus = Vector2(0, 0)
	canvas.update_preview()
	check(received.size() == 1 and received[0] != null, "Vorschau sollte gemeldet werden")
	canvas._mouse_inside = false
	canvas.update_preview()
	check(received.size() == 2 and received[1] == null, "Ohne Maus sollte die Vorschau verschwinden")
	canvas.free()


func _has_error(result: SpellResult, fragment: String) -> bool:
	for error in result.errors:
		if error.contains(fragment):
			return true
	return false
