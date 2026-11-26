extends SceneTree
## Tests für die Spell-Auswertung und die Werkstatt.
## Ausführen:  godot --headless --path <projekt> -s res://tests/run_tests.gd
## Exit-Code 0 = alles grün.

const MAIN := GemDef.Role.MAIN
const MINOR := GemDef.Role.MINOR
const SPITZ := GemDef.Angle.SPITZ
const GROB := GemDef.Angle.GROB

var content: CraftingContent
var _checks := 0
var _failures := 0
var _current := ""


func _init() -> void:
	content = load("res://content/crafting_content.tres") as CraftingContent
	var tests := [
		test_content_loads,
		test_multiplier_values,
		test_scaling_rule_float,
		test_inner_vs_outer,
		test_overlap_main_first,
		test_overlap_minor_placement_order,
		test_capacity_takes_nearest,
		test_crossing_rejected,
		test_not_closed_rejected,
		test_too_few_gems_rejected,
		test_loop_must_start_at_main,
		test_gem_outside_focus_rejected,
		test_engraving_validation,
		test_effective_counts,
		test_transfer_to_main,
		test_main_multiplier,
		test_magic_bolt,
		test_heal_and_protection_count_own_element,
		test_status_attack_counts_own_element,
		test_status_minor_per_element,
		test_engraving_without_element,
		test_minor_engravings,
		test_neutral_essence_rules,
		test_save_roundtrip,
		test_cast_time_and_mana,
		test_dot_field_reproducible,
		test_example_focus_evaluates,
		test_canvas_editing,
		test_canvas_auto_connect_and_preview,
		test_canvas_replace_engraving,
		test_gems_outside_other_radius,
		test_new_main_engravings,
		test_mana_burn_minor,
		test_element_factor_per_element,
		test_glossary_and_linkify,
		test_tooltip_pinning,
		test_combat_damage_armor_crit,
		test_combat_status_rules,
		test_combat_mana_shock_ice,
		test_combat_run_and_determinism,
		test_combat_mage_from_foci,
		test_combat_statistics,
		test_combat_targets_and_next_cast,
		test_combat_conditions,
		test_power_transfer_half_radius,
		test_combat_new_statuses,
		test_rule_min_and_cap,
		test_minor_base_stats_and_mana_efficiency,
		test_radius_expansion,
		test_multiplier_engraving,
		test_combat_package_two,
		test_stack_conditions,
		test_blocked_under_gem,
		test_life_rewind_threshold,
		test_dispel_per_stack,
		test_freeze_counts_water_and_air,
		test_focus_shapes,
		test_allowed_elements,
		test_edges_must_stay_inside_shape,
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


func check_stat(r: SpellResult, stat: StringName, expected: float) -> void:
	check(is_equal_approx(r.get_stat(stat), expected), "%s: erwartet %s, war %s" % [stat, expected, r.get_stat(stat)])


# --- Hilfsfunktionen --------------------------------------------------------

func make_gem(role: GemDef.Role, angle: GemDef.Angle, radius: float,
		max_element := 100, max_base := 100) -> GemDef:
	var gem := GemDef.new()
	gem.id = &"test"
	gem.display_name = "Testgem"
	gem.role = role
	gem.angle = angle
	gem.radius = radius
	gem.max_element = max_element
	gem.max_base = max_base
	return gem


## Gravur ohne Wirkung (für Tests, in denen es nur ums Einsammeln geht).
func plain_engraving(role: GemDef.Role) -> EngravingDef:
	var engraving := EngravingDef.new()
	engraving.display_name = "Testgravur"
	engraving.role = role
	return engraving


func engraving(id: StringName) -> EngravingDef:
	return content.get_engraving(id)


## Platziert ein Gem; ohne Gravur bekommt es eine wirkungslose der passenden Rolle.
func place(gem: GemDef, pos: Vector2, p_engraving: EngravingDef = null) -> PlacedGem:
	return PlacedGem.create(gem, p_engraving if p_engraving != null else plain_engraving(gem.role), pos)


func make_focus(placed: Array[PlacedGem], loop: Array[int], closed := true) -> FocusInstance:
	var def := FocusDef.new()
	var shape := CircleFocusShape.new()
	shape.radius = 1000.0
	def.shape = shape
	def.max_gems = 10
	def.max_dots = 2000
	def.max_element_dots = 1000
	var focus := FocusInstance.new()
	focus.focus_def = def
	focus.gems = placed
	focus.loop = PackedInt32Array(loop)
	focus.loop_closed = closed
	return focus


## Punkte auf einer Linie ab `center` in Richtung `angle_deg` (Abstand 10, 14, 18, ...).
func dots_line(center: Vector2, angle_deg: float, count: int, element: StringName = &"") -> Array[EnergyDot]:
	var dots: Array[EnergyDot] = []
	for i in count:
		dots.append(EnergyDot.new(center + Vector2.from_angle(deg_to_rad(angle_deg)) * (10.0 + 4.0 * i), element))
	return dots


## Standard-Dreieck: Hauptgem oben, zwei Nebengems unten.
func triangle(main_angle: GemDef.Angle, main_radius: float) -> FocusInstance:
	var placed: Array[PlacedGem] = [
		place(make_gem(MAIN, main_angle, main_radius), Vector2(0, -100)),
		place(make_gem(MINOR, GROB, 50), Vector2(-100, 80)),
		place(make_gem(MINOR, GROB, 50), Vector2(100, 80)),
	]
	return make_focus(placed, [0, 1, 2])


## Hauptgem bei (0,0), Test-Gem bei (300,0), wirkungsloses Füllgem bei (0,400).
## Richtungen für Punkte:
##   Hauptgem:  innen = 45°, außen = 225°
##   Test-Gem:  innen = 153°, außen = 270°
const MAIN_POS := Vector2(0, 0)
const MAIN_INNER := 45.0
const MAIN_OUTER := 225.0
const MINOR_POS := Vector2(300, 0)
const MINOR_INNER := 153.0
const MINOR_OUTER := 270.0


func lab(main_gem: GemDef, main_engraving: EngravingDef,
		minor_gem: GemDef, minor_engraving: EngravingDef) -> FocusInstance:
	var placed: Array[PlacedGem] = [
		place(main_gem, MAIN_POS, main_engraving),
		place(minor_gem, MINOR_POS, minor_engraving),
		place(make_gem(MINOR, GROB, 10), Vector2(0, 400)),
	]
	return make_focus(placed, [0, 1, 2])


func evaluate(focus: FocusInstance, dots: Array[EnergyDot] = []) -> SpellResult:
	return SpellEvaluator.evaluate(focus, content.elements, dots)


# --- Inhalte und Grundlagen -------------------------------------------------

func test_content_loads() -> void:
	check(content != null, "crafting_content.tres sollte laden")
	check(content.elements.size() == 5, "5 Elemente erwartet")
	check(content.gems.size() == 12, "12 Gem-Formen erwartet (2 Rollen x 3 Größen x 2 Winkel), waren %d" % content.gems.size())
	for role in [MAIN, MINOR]:
		for size in GemDef.Size.values():
			for angle in [SPITZ, GROB]:
				var gem := content.find_gem(role, size, angle)
				check(gem != null and gem.role == role and gem.size == size and gem.angle == angle,
					"Gem für Rolle %d, Größe %d, Winkel %d sollte existieren" % [role, size, angle])
	check(content.find_gem(MINOR, GemDef.Size.KLEIN, GROB).radius < content.find_gem(MINOR, GemDef.Size.GROSS, GROB).radius,
		"Größere Gems haben einen größeren Radius")
	check(content.foci.size() == 8, "8 Fokus-Typen erwartet")
	check(content.get_engravings_for(MAIN).size() == 31, "31 Hauptgravuren erwartet")
	check(content.get_engravings_for(MINOR).size() == 22, "22 Nebengravuren erwartet")
	for e in content.engravings:
		check(e.description != "" and not e.description.contains("N-E"), "%s braucht eine Beschreibung ohne Abkürzung" % e.id)
		for rule in e.rules:
			check(rule.stat != &"", "Regel ohne Wert in %s" % e.id)
	check(engraving(&"standard").transfer_to_main, "Standard-Gravur überträgt an das Hauptgem")


func test_multiplier_values() -> void:
	for radius in [60.0, 80.0, 160.0]:
		check(is_equal_approx(make_gem(MINOR, GROB, radius).get_multiplier(), 1.0), "Grob r%d = x1" % radius)
		check(is_equal_approx(make_gem(MINOR, SPITZ, radius).get_multiplier(), 2.0), "Spitz r%d = x2" % radius)
	check(is_equal_approx(make_gem(MAIN, GROB, 160).get_multiplier(), 1.0), "Hauptgem Grob = x1")
	check(is_equal_approx(make_gem(MAIN, SPITZ, 160).get_multiplier(), 2.0), "Hauptgem Spitz = x2")
	check(is_equal_approx(content.get_gem(&"nebengem_mittel_spitz").get_multiplier(), 2.0), "Inhalt: Nebengem mittel Spitz = x2")


func test_scaling_rule_float() -> void:
	var rule := ScalingRule.new()
	rule.source = ScalingRule.Source.ELEMENT
	rule.element_id = &"fire"
	rule.per_n = 5
	rule.stat = &"x"
	check(is_equal_approx(rule.evaluate(0.0, {&"fire": 4.99999}), 1.0), "Rundungsfehler sollen nicht abrunden")
	check(is_equal_approx(rule.evaluate(0.0, {&"fire": 4.5}), 0.0), "4.5 von 5 reicht nicht")
	rule.source = ScalingRule.Source.ANY_ELEMENT
	rule.per_n = 2
	check(is_equal_approx(rule.evaluate(0.0, {&"fire": 3.0, &"water": 4.5}), 3.0), "7.5 E / 2 = 3")
	rule.source = ScalingRule.Source.BASE
	rule.per_n = 1
	rule.min_count = 5
	check(is_equal_approx(rule.evaluate(4.0, {}), 0.0), "min_count gilt")


# --- Einsammeln -------------------------------------------------------------

func test_inner_vs_outer() -> void:
	var inside: Array[EnergyDot] = [EnergyDot.new(Vector2(0, 20), &"fire")]
	var outside: Array[EnergyDot] = [EnergyDot.new(Vector2(0, -150), &"fire")]

	var r := evaluate(triangle(SPITZ, 300), inside)
	check(r.valid, "Dreieck sollte gültig sein: %s" % [r.errors])
	check(r.gem_results[0].collected.size() == 1, "Spitzes Hauptgem sollte den inneren Punkt einsammeln")
	r = evaluate(triangle(SPITZ, 300), outside)
	check(r.gem_results[0].collected.size() == 0, "Spitzes Hauptgem darf den äußeren Punkt nicht einsammeln")
	r = evaluate(triangle(GROB, 300), inside)
	check(r.gem_results[0].collected.size() == 0, "Grobes Hauptgem darf den inneren Punkt nicht einsammeln")
	r = evaluate(triangle(GROB, 300), outside)
	check(r.gem_results[0].collected.size() == 1, "Grobes Hauptgem sollte den äußeren Punkt einsammeln")


func test_overlap_main_first() -> void:
	# Hauptgem wird als ZWEITES platziert, sammelt aber trotzdem zuerst.
	var placed: Array[PlacedGem] = [
		place(make_gem(MINOR, SPITZ, 300), Vector2(100, 80)),
		place(make_gem(MAIN, SPITZ, 300), Vector2(0, -100)),
		place(make_gem(MINOR, SPITZ, 300), Vector2(-100, 80)),
	]
	var dots: Array[EnergyDot] = [EnergyDot.new(Vector2(0, 20), &"fire")]
	var r := evaluate(make_focus(placed, [1, 0, 2]), dots)
	check(r.valid, "sollte gültig sein: %s" % [r.errors])
	check(r.gem_results[1].collected.size() == 1, "Hauptgem sollte den überlappenden Punkt bekommen")
	check(r.gem_results[0].collected.size() == 0, "Nebengem darf den Punkt nicht bekommen")


func test_overlap_minor_placement_order() -> void:
	var placed: Array[PlacedGem] = [
		place(make_gem(MAIN, SPITZ, 50), Vector2(0, -100)),
		place(make_gem(MINOR, SPITZ, 250), Vector2(-100, 80)),
		place(make_gem(MINOR, SPITZ, 250), Vector2(100, 80)),
	]
	# Punkt liegt näher an Gem 2, aber Gem 1 wurde zuerst platziert.
	var dots: Array[EnergyDot] = [EnergyDot.new(Vector2(40, 60), &"fire")]
	var r := evaluate(make_focus(placed, [0, 2, 1]), dots)
	check(r.gem_results[1].collected.size() == 1, "Zuerst platziertes Nebengem sollte den Punkt bekommen")
	check(r.gem_results[2].collected.size() == 0, "Später platziertes Nebengem darf den Punkt nicht bekommen")


func test_capacity_takes_nearest() -> void:
	var focus := lab(make_gem(MAIN, GROB, 10), null, make_gem(MINOR, GROB, 100, 2, 1), null)
	var dots: Array[EnergyDot] = []
	for i in [5, 1, 4, 2, 3]:  # absichtlich ungeordnet, Richtung 0° = außen
		dots.append(EnergyDot.new(Vector2(300 + 10 * i, 0), &"fire"))
	dots.append(EnergyDot.new(Vector2(300, -30)))  # neutrale Essenzen, Kapazität 1
	dots.append(EnergyDot.new(Vector2(300, -15)))
	var r := evaluate(focus, dots)
	var minor := r.gem_results[1]
	check(minor.element_counts.get(&"fire", 0) == 2, "Kapazität 2 für Essenzen sollte gelten")
	check(minor.base_count == 1, "Kapazität 1 für N-E sollte gelten")
	var xs := []
	for dot in minor.collected:
		if not dot.is_base():
			xs.append(dot.position.x)
	xs.sort()
	check(xs == [310.0, 320.0], "Die nächstgelegenen Punkte sollten zuerst genommen werden, war %s" % [xs])
	for dot in minor.collected:
		if dot.is_base():
			check(dot.position == Vector2(300, -15), "Die nähere N-E sollte genommen werden")


# --- Prüfungen --------------------------------------------------------------

func test_crossing_rejected() -> void:
	var placed: Array[PlacedGem] = [
		place(make_gem(MAIN, GROB, 50), Vector2(0, 0)),
		place(make_gem(MINOR, GROB, 50), Vector2(100, 0)),
		place(make_gem(MINOR, GROB, 50), Vector2(100, 100)),
		place(make_gem(MINOR, GROB, 50), Vector2(0, 100)),
	]
	var r := evaluate(make_focus(placed, [0, 2, 1, 3]))
	check(not r.valid and _has_error(r, "kreuzen"), "Kreuzung sollte abgelehnt werden: %s" % [r.errors])
	r = evaluate(make_focus(placed, [0, 1, 2, 3]))
	check(r.valid, "Viereck ohne Kreuzung sollte gültig sein: %s" % [r.errors])


func test_not_closed_rejected() -> void:
	var focus := triangle(SPITZ, 100)
	focus.loop_closed = false
	var r := evaluate(focus)
	check(not r.valid and _has_error(r, "nicht geschlossen"), "Offener Kreis sollte ungültig sein: %s" % [r.errors])


func test_too_few_gems_rejected() -> void:
	var placed: Array[PlacedGem] = [
		place(make_gem(MAIN, GROB, 50), Vector2(0, 0)),
		place(make_gem(MINOR, GROB, 50), Vector2(100, 0)),
	]
	var r := evaluate(make_focus(placed, [0, 1]))
	check(not r.valid and _has_error(r, "mindestens"), "Zwei Gems sollten nicht reichen: %s" % [r.errors])


func test_loop_must_start_at_main() -> void:
	var focus := triangle(SPITZ, 100)
	focus.loop = PackedInt32Array([1, 2, 0])
	var r := evaluate(focus)
	check(not r.valid and _has_error(r, "Hauptgem beginnen"), "Kreis muss beim Hauptgem starten: %s" % [r.errors])


func test_gem_outside_focus_rejected() -> void:
	var focus := triangle(SPITZ, 100)
	focus.gems[2].position = Vector2(5000, 0)
	var r := evaluate(focus)
	check(not r.valid and _has_error(r, "außerhalb"), "Gem außerhalb sollte ungültig sein: %s" % [r.errors])


func test_engraving_validation() -> void:
	var focus := triangle(SPITZ, 100)
	focus.gems[1].engraving = null
	var r := evaluate(focus)
	check(not r.valid and _has_error(r, "keine Gravur"), "Gem ohne Gravur sollte abgelehnt werden: %s" % [r.errors])

	focus = triangle(SPITZ, 100)
	focus.gems[1].engraving = engraving(&"magischer_bolzen")
	r = evaluate(focus)
	check(not r.valid and _has_error(r, "passt nicht"), "Hauptgravur auf Nebengem sollte abgelehnt werden: %s" % [r.errors])

	focus = triangle(SPITZ, 100)
	focus.gems[0].engraving = engraving(&"standard")
	r = evaluate(focus)
	check(not r.valid and _has_error(r, "passt nicht"), "Nebengravur auf Hauptgem sollte abgelehnt werden")


# --- Neues Regelwerk ---------------------------------------------------------

func test_effective_counts() -> void:
	# Spitzes Nebengem: x2
	var focus := lab(make_gem(MAIN, GROB, 10), engraving(&"magischer_bolzen"),
		make_gem(MINOR, SPITZ, 80), engraving(&"status_burn"))
	var dots := dots_line(MINOR_POS, MINOR_INNER, 4, &"fire") + dots_line(MINOR_POS + Vector2(0, 2), MINOR_INNER, 2)
	var r := evaluate(focus, dots)
	check(r.valid, "sollte gültig sein: %s" % [r.errors])
	var gr := r.gem_results[1]
	check(gr.base_count == 2 and gr.element_counts.get(&"fire", 0) == 4, "4 Feuer + 2 N-E eingesammelt")
	check(is_equal_approx(gr.multiplier, 2.0), "Multiplikator x2")
	check(is_equal_approx(gr.effective_elements.get(&"fire", 0.0), 8.0), "effektiv 8 Feuer")
	check(is_equal_approx(gr.effective_base, 4.0), "effektiv 4 N-E")
	check_stat(r, &"burn", 8.0)


func test_transfer_to_main() -> void:
	var focus := lab(make_gem(MAIN, GROB, 80), engraving(&"magischer_bolzen"),
		make_gem(MINOR, SPITZ, 80), engraving(&"standard"))
	var dots := dots_line(MINOR_POS, MINOR_INNER, 4, &"fire") + dots_line(MAIN_POS, MAIN_OUTER, 3)
	var r := evaluate(focus, dots)
	check(r.valid, "sollte gültig sein: %s" % [r.errors])
	var main := r.gem_results[0]
	check(is_equal_approx(main.received_elements.get(&"fire", 0.0), 8.0), "Hauptgem erhält 4 Feuer x2 = 8")
	check(is_equal_approx(main.total_base(), 3.0), "Hauptgem hat 3 eigene N-E")
	check_stat(r, &"damage", 43.0)  # 3 neutral + 8 Feuer x Faktor 5


func test_main_multiplier() -> void:
	# Spitzes Hauptgem = x2 auf das eigene Einsammeln, nicht auf Übertragenes
	var focus := lab(make_gem(MAIN, SPITZ, 160), engraving(&"magischer_bolzen"),
		make_gem(MINOR, GROB, 80), engraving(&"standard"))
	var dots := dots_line(MAIN_POS, MAIN_INNER, 4) + dots_line(MINOR_POS, MINOR_OUTER, 2, &"water")
	var r := evaluate(focus, dots)
	check(is_equal_approx(r.gem_results[0].effective_base, 8.0), "4 N-E x2 = 8")
	check(is_equal_approx(r.gem_results[0].received_elements.get(&"water", 0.0), 2.0), "Übertragenes bleibt x1")
	check_stat(r, &"damage", 18.0)  # 8 neutral + 2 Wasser x Faktor 5


func test_magic_bolt() -> void:
	var focus := lab(make_gem(MAIN, GROB, 80), engraving(&"magischer_bolzen"), make_gem(MINOR, GROB, 80), null)
	var dots := dots_line(MAIN_POS, MAIN_OUTER, 5) + dots_line(MAIN_POS + Vector2(-2, 0), MAIN_OUTER, 3, &"air")
	var r := evaluate(focus, dots)
	check(r.engraving.id == &"magischer_bolzen", "Spell = Gravur des Hauptgems")
	check_stat(r, &"damage", 20.0)  # ohne Element: 5 neutral + 3 Luft x 5


func test_heal_and_protection_count_own_element() -> void:
	var dots := dots_line(MAIN_POS, MAIN_OUTER, 2, &"water") + dots_line(MAIN_POS + Vector2(-2, 0), MAIN_OUTER, 1, &"fire")
	var r := evaluate(lab(make_gem(MAIN, GROB, 80), engraving(&"heal"), make_gem(MINOR, GROB, 80), null), dots)
	check_stat(r, &"heal", 50.0)  # 2 Wasser x 5 Punkte x 5 Heilung, Feuer zählt nicht

	dots = dots_line(MAIN_POS, MAIN_OUTER, 2, &"earth") + dots_line(MAIN_POS + Vector2(-2, 0), MAIN_OUTER, 1, &"fire")
	r = evaluate(lab(make_gem(MAIN, GROB, 80), engraving(&"schutz"), make_gem(MINOR, GROB, 80), null), dots)
	check_stat(r, &"armor", 50.0)  # 2 Erde x 5 x 5, Feuer zählt nicht


func test_status_attack_counts_own_element() -> void:
	var dots := dots_line(MAIN_POS, MAIN_OUTER, 5, &"fire") \
		+ dots_line(MAIN_POS + Vector2(-2, 0), MAIN_OUTER, 4, &"water") \
		+ dots_line(MAIN_POS + Vector2(0, -2), MAIN_OUTER, 3)
	var r := evaluate(lab(make_gem(MAIN, GROB, 80), engraving(&"feuerball"), make_gem(MINOR, GROB, 80), null), dots)
	check_stat(r, &"damage", 28.0)  # 3 neutral + 5 Feuer x 5, Wasser zählt nicht
	check_stat(r, &"burn", 2.0)  # 25 Feuer-Punkte / 10
	check(not r.stats.has(&"wet"), "Feuerball macht kein Nass")

	r = evaluate(lab(make_gem(MAIN, GROB, 80), engraving(&"wasser_detonation"), make_gem(MINOR, GROB, 80), null), dots)
	check_stat(r, &"wet", 2.0)
	check(not r.stats.has(&"burn"), "Wasser-Detonation macht kein Burn")


func test_status_minor_per_element() -> void:
	var dots := dots_line(MINOR_POS, MINOR_OUTER, 2, &"fire") \
		+ dots_line(MINOR_POS + Vector2(2, 0), MINOR_OUTER, 3, &"water") \
		+ dots_line(MINOR_POS + Vector2(4, 0), MINOR_OUTER, 1, &"air") \
		+ dots_line(MINOR_POS + Vector2(6, 0), MINOR_OUTER, 1, &"earth") \
		+ dots_line(MINOR_POS + Vector2(8, 0), MINOR_OUTER, 2, &"lightning") \
		+ dots_line(MINOR_POS + Vector2(10, 0), MINOR_OUTER, 6)
	# je Status eine Gravur; sie zählt nur Essenz ihres Elements (1 pro Essenz), nie neutrale
	var expected := { &"status_burn": [&"burn", 2.0], &"status_nass": [&"wet", 3.0], &"status_bleed": [&"bleed", 1.0],
		&"status_armor_break": [&"armor_break", 1.0], &"status_schock": [&"shock", 2.0] }
	for id: StringName in expected:
		var r := evaluate(lab(make_gem(MAIN, GROB, 10), engraving(&"magischer_bolzen"),
			make_gem(MINOR, GROB, 80), engraving(id)), dots)
		check_stat(r, expected[id][0], expected[id][1])
		var others := 0.0
		for stat: StringName in r.stats:
			if stat != expected[id][0]:
				others += r.stats[stat]
		check(is_zero_approx(others), "%s erzeugt nur seinen Status, war %s" % [id, r.stats])


## Gravuren ohne Element zählen keine Essenz; der Bolzen zählt alle Elemente.
func test_engraving_without_element() -> void:
	var no_element := EngravingDef.new()
	no_element.role = MAIN
	var rule := ScalingRule.new()
	rule.source = ScalingRule.Source.POINTS
	rule.stat = &"damage"
	no_element.rules.append(rule)
	var dots := dots_line(MAIN_POS, MAIN_OUTER, 3) + dots_line(MAIN_POS + Vector2(-2, 0), MAIN_OUTER, 2, &"fire")
	var r := evaluate(lab(make_gem(MAIN, GROB, 80), no_element, make_gem(MINOR, GROB, 80), null), dots)
	check_stat(r, &"damage", 3.0)  # nur neutrale Essenz
	check(engraving(&"magischer_bolzen").element_ids.size() == 5, "Magischer Bolzen hat alle Elemente")


func test_minor_engravings() -> void:
	var main := make_gem(MAIN, GROB, 10)
	var bolt := engraving(&"magischer_bolzen")
	var minor := make_gem(MINOR, GROB, 80)
	var mixed := dots_line(MINOR_POS, MINOR_OUTER, 3, &"fire") + dots_line(MINOR_POS + Vector2(2, 0), MINOR_OUTER, 2, &"earth")

	var r := evaluate(lab(main, bolt, minor, engraving(&"crit")), mixed)
	check_stat(r, &"crit", 7.0)  # 3 Feuer x 5 / 2, Erde zählt nicht
	r = evaluate(lab(main, bolt, minor, engraving(&"armor")), mixed)
	check_stat(r, &"armor", 5.0)  # 2 Erde x 5 / 2, Feuer zählt nicht


## Neutrale Essenz wirkt nur über "N"-Regeln, etwa halb so stark wie Essenz.
func test_neutral_essence_rules() -> void:
	var main := make_gem(MAIN, GROB, 10)
	var bolt := engraving(&"magischer_bolzen")
	var minor := make_gem(MINOR, GROB, 80)
	var neutral := dots_line(MINOR_POS, MINOR_OUTER, 4)

	var r := evaluate(lab(main, bolt, minor, engraving(&"crit")), neutral)
	check_stat(r, &"crit", 2.0)  # 4 / 2
	r = evaluate(lab(main, bolt, minor, engraving(&"armor")), neutral)
	check_stat(r, &"armor", 2.0)
	r = evaluate(lab(main, bolt, minor, engraving(&"mana_reduktion")), neutral)
	check(is_equal_approx(r.mana_cost, 118.0), "4 neutrale Essenz = -2 Mana, war %s" % r.mana_cost)
	r = evaluate(lab(main, bolt, minor, engraving(&"status_burn")), neutral)
	check(not r.stats.has(&"burn") or is_zero_approx(r.get_stat(&"burn")), "Burn: neutrale Essenz bewirkt nichts")

	var main_dots := dots_line(MAIN_POS, MAIN_OUTER, 2)
	r = evaluate(lab(make_gem(MAIN, GROB, 80), engraving(&"heal"), minor, null), main_dots)
	check_stat(r, &"heal", 10.0)  # 2 x5
	r = evaluate(lab(make_gem(MAIN, GROB, 80), engraving(&"schutz"), minor, null), main_dots)
	check_stat(r, &"armor", 10.0)


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


func test_cast_time_and_mana() -> void:
	var main := make_gem(MAIN, GROB, 10)
	var bolt := engraving(&"magischer_bolzen")
	var minor := make_gem(MINOR, GROB, 80)

	var r := evaluate(lab(main, bolt, minor, null))
	check(is_equal_approx(r.cast_time, 3.0), "3 Gems = 3 s, war %s" % r.cast_time)
	check(is_equal_approx(r.mana_cost, 120.0), "Umfang 1200 x 0.1 = 120 Mana, war %s" % r.mana_cost)

	r = evaluate(lab(main, bolt, minor, engraving(&"cast_speed")), dots_line(MINOR_POS, MINOR_OUTER, 4, &"air"))
	check(is_equal_approx(r.cast_time, 1.0), "4 Luft = 20 Punkte = -2 s, war %s" % r.cast_time)
	r = evaluate(lab(main, bolt, minor, engraving(&"cast_speed")), dots_line(MINOR_POS, MINOR_OUTER, 17, &"air"))
	check(is_equal_approx(r.cast_time, SpellEvaluator.MIN_CAST_TIME), "Cast-Zeit hat eine Untergrenze, war %s" % r.cast_time)

	r = evaluate(lab(main, bolt, minor, engraving(&"mana_reduktion")), dots_line(MINOR_POS, MINOR_OUTER, 5, &"water"))
	check(is_equal_approx(r.mana_cost, 108.0), "5 Wasser = 25 Punkte = -12 Mana, war %s" % r.mana_cost)


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


## Auswertung mit den Punkten aus dem Seed des Fokus.
func evaluate_real(focus: FocusInstance) -> SpellResult:
	return SpellEvaluator.evaluate(focus, content.elements)


# --- Werkstatt --------------------------------------------------------------

func place_on(canvas: FocusCanvas, gem: GemDef, pos: Vector2, p_engraving: EngravingDef = null) -> void:
	if p_engraving != null:
		canvas.placing_engraving = p_engraving
	else:
		canvas.placing_engraving = engraving(&"magischer_bolzen") if gem.role == MAIN else engraving(&"standard")
	canvas._try_place(gem, pos)


func test_canvas_editing() -> void:
	var main := content.get_gem(&"hauptgem_mittel_grob")
	var minor := content.get_gem(&"nebengem_mittel_grob")
	var focus := FocusInstance.new()
	focus.focus_def = content.get_focus(&"kleiner_fokus")
	var canvas := FocusCanvas.new()
	canvas.focus = focus
	canvas.auto_connect = false  # manuelles Verbinden testen
	var messages: Array[String] = []
	canvas.message.connect(func(text: String) -> void: messages.append(text))

	place_on(canvas, minor, Vector2(0, 0))
	check(focus.gems.is_empty() and messages.back().contains("zuerst ein Hauptgem"), "Nebengem vor Hauptgem sollte abgelehnt werden")
	place_on(canvas, main, Vector2(-100, 50))
	check(focus.gems[0].engraving.id == &"magischer_bolzen", "Gesetztes Gem trägt die gewählte Gravur")
	place_on(canvas, main, Vector2(100, 50))
	check(focus.gems.size() == 1 and messages.back().contains("bereits ein Hauptgem"), "Zweites Hauptgem sollte abgelehnt werden")
	place_on(canvas, minor, Vector2(-95, 50))
	check(messages.back().contains("Zu nah"), "Zu nahes Gem sollte abgelehnt werden")
	place_on(canvas, minor, Vector2(400, 0))
	check(messages.back().contains("innerhalb"), "Gem außerhalb sollte abgelehnt werden")
	place_on(canvas, minor, Vector2(100, 50))
	place_on(canvas, minor, Vector2(0, -120))
	place_on(canvas, minor, Vector2(0, 150))
	check(focus.gems.size() == 3 and messages.back().contains("höchstens 3"), "Gem-Kapazität sollte gelten")

	canvas._try_connect(1)
	check(focus.loop.is_empty(), "Kreis darf nicht bei einem Nebengem beginnen")
	canvas._try_connect(0)
	canvas._try_connect(1)
	canvas._try_connect(0)
	check(not focus.loop_closed and messages.back().contains("mindestens"), "Schließen mit 2 Gems sollte abgelehnt werden")
	canvas._try_connect(2)
	canvas._try_connect(0)
	check(focus.loop_closed and focus.loop == PackedInt32Array([0, 1, 2]), "Kreis sollte geschlossen sein")
	var r := evaluate_real(focus)
	check(r.valid, "Im Editor gebauter Kreis sollte gültig sein: %s" % [r.errors])

	canvas.undo_connection()
	check(not focus.loop_closed and focus.loop.size() == 3, "Zurück sollte zuerst den Kreis öffnen")
	canvas.remove_gem(1)
	check(focus.gems.size() == 2 and focus.loop == PackedInt32Array([0, 1]),
		"Entfernen sollte die Nachbarn verbinden, war %s" % [focus.loop])
	check(not focus.loop_closed, "Mit 2 Gems darf der Kreis nicht geschlossen sein")
	canvas.free()


func test_canvas_auto_connect_and_preview() -> void:
	var main := content.get_gem(&"hauptgem_mittel_grob")
	var minor := content.get_gem(&"nebengem_mittel_grob")
	var focus := FocusInstance.new()
	focus.focus_def = content.get_focus(&"mittlerer_fokus")
	focus.element_fill = {&"fire": 60}
	focus.dot_seed = 7
	var canvas := FocusCanvas.new()
	canvas.focus = focus
	canvas.evaluate_preview = evaluate_real

	place_on(canvas, main, Vector2(-120, 60))
	place_on(canvas, minor, Vector2(120, 60))
	check(focus.loop == PackedInt32Array([0, 1]) and not focus.loop_closed, "Zweites Gem sollte automatisch verbunden sein")
	place_on(canvas, minor, Vector2(0, -150))
	check(focus.loop == PackedInt32Array([0, 1, 2]) and focus.loop_closed, "Ab 3 Gems sollte sich der Kreis schließen")
	place_on(canvas, minor, Vector2(0, 200))
	check(focus.loop == PackedInt32Array([0, 1, 2, 3]) and focus.loop_closed,
		"Neues Gem sollte vor der schließenden Kante eingefügt werden")

	canvas.remove_gem(2)
	check(focus.loop == PackedInt32Array([0, 1, 2]) and focus.loop_closed,
		"Nach Entfernen sollte der Kreis mit 3 Gems geschlossen bleiben, war %s" % [focus.loop])

	# Vorschau: verändert den Fokus nicht, liefert eine gültige Auswertung mit dem neuen Gem
	canvas.mode = FocusCanvas.Mode.PLACE
	canvas.placing_gem = minor
	canvas.placing_engraving = engraving(&"standard")
	canvas._mouse_inside = true
	canvas._mouse_focus = Vector2(-250, 180)  # zwischen letztem Nebengem und Hauptgem, ohne Kreuzung
	canvas.update_preview()
	check(focus.gems.size() == 3, "Vorschau darf den Fokus nicht verändern")
	check(canvas._preview != null and canvas._preview.valid, "Vorschau sollte einen gültigen Spell ergeben")
	check(canvas._preview_index == 3, "Vorschau-Gem sollte das vierte sein")

	canvas._mouse_focus = Vector2(1000, 0)
	canvas.update_preview()
	check(canvas._preview == null and canvas._preview_error.contains("innerhalb"), "Vorschau außerhalb sollte den Grund nennen")

	# Hauptgem entfernen löst den Kreis; ein neues Hauptgem verbindet die vorhandenen Nebengems
	canvas.remove_gem(0)
	check(focus.loop.is_empty() and not focus.loop_closed, "Ohne Hauptgem gibt es keinen Kreis")
	place_on(canvas, main, Vector2(-150, 100))
	check(focus.loop == PackedInt32Array([2, 0, 1]) and focus.loop_closed,
		"Neues Hauptgem sollte die Nebengems verbinden, war %s" % [focus.loop])
	canvas.free()


func test_canvas_replace_engraving() -> void:
	var main := content.get_gem(&"hauptgem_mittel_grob")
	var minor := content.get_gem(&"nebengem_mittel_grob")
	var focus := FocusInstance.new()
	focus.focus_def = content.get_focus(&"mittlerer_fokus")
	focus.element_fill = {&"fire": 60}
	focus.dot_seed = 7
	var canvas := FocusCanvas.new()
	canvas.focus = focus
	canvas.evaluate_preview = evaluate_real
	var messages: Array[String] = []
	canvas.message.connect(func(text: String) -> void: messages.append(text))
	place_on(canvas, main, Vector2(-120, 60))
	place_on(canvas, minor, Vector2(120, 60))
	place_on(canvas, minor, Vector2(0, -150))
	var loop_before := focus.loop.duplicate()

	# Vorschau beim Darüberfahren: ändert den Fokus nicht
	var spitz_klein := content.get_gem(&"nebengem_klein_spitz")
	canvas.placing_gem = spitz_klein
	canvas.placing_engraving = engraving(&"crit")
	canvas._mouse_inside = true
	canvas._hovered = 1
	canvas.update_preview()
	check(canvas.is_replace_preview() and canvas._preview != null and canvas._preview.valid, "Vorschau beim Ersetzen")
	check(canvas._preview.gem_results[1].placed.engraving.id == &"crit", "Vorschau zeigt die neue Gravur")
	check(focus.gems[1].engraving.id == &"standard", "Vorschau darf den Fokus nicht verändern")

	# Klick übernimmt Gravur und Form, Position und Kreis bleiben
	canvas._try_replace(1)
	check(focus.gems[1].engraving.id == &"crit" and focus.gems[1].gem == spitz_klein, "Gravur und Form übernommen")
	check(focus.gems[1].position == Vector2(120, 60), "Position bleibt")
	check(focus.loop == loop_before and focus.loop_closed, "Kreis bleibt")
	canvas._hovered = 1
	canvas.update_preview()
	check(not canvas.is_replace_preview(), "Keine Vorschau, wenn sich nichts ändern würde")

	# Rolle muss passen
	canvas._try_replace(0)
	check(focus.gems[0].engraving.id == &"magischer_bolzen" and messages.back().contains("Hauptgravur"),
		"Hauptgem darf keine Nebengravur bekommen")
	canvas.placing_gem = content.get_gem(&"hauptgem_gross_spitz")
	canvas.placing_engraving = engraving(&"heal")
	canvas._try_replace(0)
	check(focus.gems[0].engraving.id == &"heal" and focus.gems[0].gem.size == GemDef.Size.GROSS, "Hauptgem geändert")
	canvas._try_replace(2)
	check(focus.gems[2].engraving.id == &"standard" and messages.back().contains("Nebengravur"),
		"Nebengem darf keine Hauptgravur bekommen")
	canvas.free()


func test_new_main_engravings() -> void:
	var minor := make_gem(MINOR, GROB, 80)
	var main_gem := make_gem(MAIN, GROB, 120)
	var r := evaluate(lab(main_gem, engraving(&"hasted"), minor, null),
		dots_line(MAIN_POS, MAIN_OUTER, 10, &"air") + dots_line(MAIN_POS + Vector2(-2, 0), MAIN_OUTER, 20))
	check_stat(r, &"hasted", 3.0)  # (10 Luft x 5 + 20 neutral) / 20
	r = evaluate(lab(main_gem, engraving(&"leben_reg"), minor, null),
		dots_line(MAIN_POS, MAIN_OUTER, 3, &"water") + dots_line(MAIN_POS + Vector2(-2, 0), MAIN_OUTER, 4))
	check_stat(r, &"life_regen", 9.0)  # (3 Wasser x 5 + 4 neutral) / 2
	r = evaluate(lab(main_gem, engraving(&"mana_reg"), minor, null),
		dots_line(MAIN_POS, MAIN_OUTER, 3, &"lightning") + dots_line(MAIN_POS + Vector2(-2, 0), MAIN_OUTER, 2, &"water"))
	check_stat(r, &"mana_regen", 7.0)  # 3 Blitz x 5 / 2, Wasser zählt nicht


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


func _content_triangle(def: FocusDef, a: Vector2, b: Vector2, c: Vector2) -> FocusInstance:
	var focus := FocusInstance.new()
	focus.focus_def = def
	var standard := engraving(&"standard")
	focus.gems = [
		PlacedGem.create(content.get_gem(&"hauptgem_mittel_grob"), engraving(&"magischer_bolzen"), a),
		PlacedGem.create(content.get_gem(&"nebengem_mittel_grob"), standard, b),
		PlacedGem.create(content.get_gem(&"nebengem_mittel_grob"), standard, c),
	]
	focus.loop = PackedInt32Array([0, 1, 2])
	focus.loop_closed = true
	return focus


func test_allowed_elements() -> void:
	var fire_focus := content.get_focus(&"feuer_fokus")
	check(fire_focus.allows_element(&"fire") and not fire_focus.allows_element(&"water"), "Feuer-Fokus erlaubt nur Feuer")
	check(content.get_focus(&"kleiner_fokus").allows_element(&"water"), "Normaler Fokus erlaubt alle Elemente")

	var focus := _content_triangle(fire_focus, Vector2(-100, 60), Vector2(100, 60), Vector2(0, -120))
	focus.element_fill = {&"fire": 60, &"water": 5}
	var r := evaluate_real(focus)
	check(not r.valid and _has_error(r, "keine Wasser-Essenz"), "Wasser im Feuer-Fokus sollte abgelehnt werden: %s" % [r.errors])
	focus.element_fill = {&"fire": 80}
	r = evaluate_real(focus)
	check(r.valid, "80 Feuer im Feuer-Fokus sollte gültig sein: %s" % [r.errors])

	focus.focus_def = content.get_focus(&"neutraler_fokus")
	r = evaluate_real(focus)
	check(not r.valid and _has_error(r, "Zu viele Essenzen"), "Essenzen im neutralen Fokus sollten abgelehnt werden")
	focus.element_fill = {}
	r = evaluate_real(focus)
	check(r.valid, "300 N-E im neutralen Fokus sollten gültig sein: %s" % [r.errors])


func test_edges_must_stay_inside_shape() -> void:
	var star_def := content.get_focus(&"stern_fokus")
	var star := star_def.shape
	var top := Vector2(0, -300)
	var right := Vector2.from_angle(deg_to_rad(-18)) * 300  # benachbarte Zacke
	check(star.contains(top) and star.contains(right), "Beide Zackenspitzen liegen im Stern")
	check(not star.contains_segment(top, right), "Strecke zwischen zwei Zacken verlässt den Stern")
	check(star.contains_segment(Vector2.ZERO, top), "Strecke von der Mitte in eine Zacke bleibt im Stern")
	check(content.get_focus(&"kleiner_fokus").shape.contains_segment(Vector2(-200, 0), Vector2(200, 0)),
		"Im Kreis bleibt jede Strecke zwischen inneren Punkten innerhalb")

	var focus := _content_triangle(star_def, top, right, Vector2(0, 50))
	var r := evaluate_real(focus)
	check(not r.valid and _has_error(r, "innerhalb des Fokus verlaufen"),
		"Kante durch den leeren Bereich sollte abgelehnt werden: %s" % [r.errors])

	focus.gems[1].position = Vector2(100, -40)
	r = evaluate_real(focus)
	check(r.valid, "Kreis innerhalb des Sterns sollte gültig sein: %s" % [r.errors])

	var canvas := FocusCanvas.new()
	canvas.focus = focus
	canvas.auto_connect = false
	focus.loop = PackedInt32Array([0])
	focus.loop_closed = false
	focus.gems[1].position = right
	check(canvas.connect_error(1).contains("innerhalb des Fokus"), "Werkstatt sollte die Verbindung ablehnen")
	canvas.free()


func test_spell_change_preview() -> void:
	var workshop: Node = load("res://ui/workshop/workshop.tscn").instantiate()

	var before := SpellResult.new()
	before.valid = true
	before.engraving = engraving(&"magischer_bolzen")
	before.stats = {&"damage": 10.0}
	before.cast_time = 3.0
	before.mana_cost = 50.0
	var after := SpellResult.new()
	after.valid = true
	after.engraving = before.engraving
	after.stats = {&"damage": 14.0, &"burn": 5.0}
	after.cast_time = 4.0
	after.mana_cost = 50.0

	var text: String = workshop._diff_text(before, after)
	check(text.contains("10 → [b]14[/b]") and text.contains("(+4)"), "Schaden-Änderung sollte angezeigt werden: %s" % text)
	check(text.contains("Burn (Stacks): 0 → [b]5[/b]"), "Neuer Statuswert sollte als Zuwachs erscheinen")
	check(text.contains("Cast-Zeit (s): 3 → [b]4[/b] [color=#ff9090]"), "Längere Cast-Zeit sollte rot sein")

	after.engraving = engraving(&"heal")
	text = workshop._diff_text(before, after)
	check(text.contains("Magischer Bolzen → Heal"), "Wechsel der Spell-Art sollte angezeigt werden")

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
	canvas.evaluate_preview = evaluate_real
	var received: Array = []
	canvas.preview_changed.connect(func(p: SpellResult) -> void: received.append(p))
	canvas.placing_gem = content.get_gem(&"hauptgem_mittel_grob")
	canvas.placing_engraving = engraving(&"magischer_bolzen")
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


func test_mana_burn_minor() -> void:
	var r := evaluate(lab(make_gem(MAIN, GROB, 10), engraving(&"magischer_bolzen"), make_gem(MINOR, GROB, 80), engraving(&"mana_burn")),
		dots_line(MINOR_POS, MINOR_OUTER, 3, &"lightning") + dots_line(MINOR_POS + Vector2(2, 0), MINOR_OUTER, 4))
	check_stat(r, &"mana_burn", 3.0)  # 3 Blitz x 5 / 5, neutrale Essenz zählt nicht


## Der Faktor ist pro Element einstellbar.
func test_element_factor_per_element() -> void:
	for element in content.elements:
		check(is_equal_approx(element.factor, 5.0), "%s: Faktor 5 erwartet" % element.id)
	var elements: Array[ElementDef] = []
	for element in content.elements:
		var copy := element.duplicate() as ElementDef
		if copy.id == &"fire":
			copy.factor = 3.0
		elements.append(copy)
	var focus := lab(make_gem(MAIN, GROB, 80), engraving(&"magischer_bolzen"), make_gem(MINOR, GROB, 80), null)
	var dots := dots_line(MAIN_POS, MAIN_OUTER, 2, &"fire") + dots_line(MAIN_POS + Vector2(-2, 0), MAIN_OUTER, 2, &"water")
	var r := SpellEvaluator.evaluate(focus, elements, dots)
	check_stat(r, &"damage", 16.0)  # 2 Feuer x 3 + 2 Wasser x 5
	check(is_equal_approx(r.gem_results[0].points, 16.0), "Punkte des Hauptgems, war %s" % r.gem_results[0].points)


func test_freeze_counts_water_and_air() -> void:
	var dots := dots_line(MAIN_POS, MAIN_OUTER, 2, &"water") + dots_line(MAIN_POS + Vector2(-2, 0), MAIN_OUTER, 1, &"air") \
		+ dots_line(MAIN_POS + Vector2(0, -2), MAIN_OUTER, 3, &"fire") + dots_line(MAIN_POS + Vector2(2, 2), MAIN_OUTER, 4)
	var r := evaluate(lab(make_gem(MAIN, GROB, 80), engraving(&"freeze"), make_gem(MINOR, GROB, 80), null), dots)
	check_stat(r, &"damage", 19.0)  # 4 neutral + (2 Wasser + 1 Luft) x 5, Feuer zählt nicht
	check_stat(r, &"freeze_conversion", 100.0)


## Gems dürfen nicht in der Reichweite eines anderen Gems liegen (beide Richtungen).
func test_gems_outside_other_radius() -> void:
	var main := content.get_gem(&"hauptgem_mittel_grob")   # Radius 120
	var minor := content.get_gem(&"nebengem_mittel_grob")  # Radius 60
	var big := content.get_gem(&"nebengem_gross_grob")     # Radius 90
	check(main.radius == 120.0 and minor.radius == 60.0 and big.radius == 90.0, "Radien wie im Test angenommen")
	var focus := FocusInstance.new()
	focus.focus_def = content.get_focus(&"grosser_fokus")
	var canvas := FocusCanvas.new()
	canvas.focus = focus
	var messages: Array[String] = []
	canvas.message.connect(func(text: String) -> void: messages.append(text))

	place_on(canvas, main, Vector2(0, 0))
	place_on(canvas, minor, Vector2(110, 0), engraving(&"crit"))
	check(focus.gems.size() == 1 and messages.back().contains("Reichweite"), "Nebengem im Radius des Hauptgems abgelehnt")
	place_on(canvas, minor, Vector2(130, 0), engraving(&"crit"))
	check(focus.gems.size() == 2, "Außerhalb des Hauptgem-Radius erlaubt")
	place_on(canvas, minor, Vector2(130, 40), engraving(&"crit"))  # 40 vom Nebengem (Radius 60)
	check(focus.gems.size() == 2, "Im Radius eines Nebengems abgelehnt")
	place_on(canvas, big, Vector2(0, -130), engraving(&"crit"))
	check(focus.gems.size() == 3, "Großes Nebengem mit genug Abstand erlaubt")
	# beide Richtungen: kleiner Abstand zum großen Gem reicht nicht, auch wenn das neue Gem kleiner ist
	place_on(canvas, minor, Vector2(-70, -130), engraving(&"crit"))
	check(focus.gems.size() == 3 and messages.back().contains("90"), "Abstand mindestens der größere Radius")

	# Ziehen in einen Radius: das Gem gleitet am Rand entlang statt hängen zu bleiben
	canvas._move_gem(1, Vector2(100, 0))
	check(is_equal_approx(snappedf(focus.gems[1].position.x, 0.1), 120.0) and is_zero_approx(focus.gems[1].position.y),
		"Auf den Rand geschoben, war %s" % focus.gems[1].position)
	canvas._move_gem(1, Vector2(100, 30))
	var p := focus.gems[1].position
	check(absf(p.length() - 120.0) < 0.1 and p.y > 20.0, "Gleitet am Rand entlang, war %s" % p)

	# Vergrößern, sodass ein anderes Gem im Radius läge, wird verhindert
	canvas.placing_gem = content.get_gem(&"hauptgem_gross_grob")  # Radius 165
	canvas.placing_engraving = engraving(&"magischer_bolzen")
	canvas._try_replace(0)
	check(focus.gems[0].gem == main and messages.back().contains("Reichweite"), "Vergrößern über ein anderes Gem verhindert")
	canvas.free()


func test_glossary_and_linkify() -> void:
	check(content.glossary.size() == 5 + 27, "5 Elemente + 27 Status/Effekte als Begriffe, waren %d" % content.glossary.size())
	for term in content.glossary:
		check(term.text != "" and not term.words.is_empty(), "Begriff %s braucht Text und Wörter" % term.id)
	var tips := TermTooltips.new()
	tips.setup(content)
	var text := tips.linkify("Mana Burn und Burn, Feuerball, Feuer-Essenz, [url=toggle_gems]Burn[/url] [color=#fff]Nass[/color]")
	check(text.contains("[url=term:mana_burn]") and text.contains("[url=term:burn]"), "Mana Burn und Burn verlinkt: %s" % text)
	check(text.count("term:burn") == 1, "Burn in Mana Burn und im vorhandenen Link nicht doppelt verlinkt: %s" % text)
	check(not text.contains("Feuerball[/color][/url]") and text.contains("Feuerball"), "Feuerball bleibt Text")
	check(text.contains("[url=term:fire]") and text.contains("Feuer-Essenz[/color][/url]"), "Feuer-Essenz verlinkt")
	check(text.contains("[url=toggle_gems]Burn[/url]"), "Vorhandene Links bleiben unberührt")
	check(text.contains("[color=#fff][url=term:nass]"), "Begriffe in Formatierung werden verlinkt")
	check(not tips.linkify("Burn", "burn").contains("[url"), "Ausgeschlossener Begriff (eigener Tooltip) bleibt Text")
	tips.free()


## Ablauf: erscheint nach Verzögerung, verschwindet ohne Pinnen, bleibt nach langem Hovern.
func test_tooltip_pinning() -> void:
	var tips := TermTooltips.new()
	tips.setup(content)
	root.add_child(tips)
	tips._on_hover_started("term:burn", 0)
	tips._process(TermTooltips.SHOW_DELAY * 0.5)
	check(tips.open_count() == 0, "Vor der Verzögerung kein Tooltip")
	tips._process(TermTooltips.SHOW_DELAY)
	check(tips.open_count() == 1 and not tips._stack[0].pinned, "Tooltip erscheint, noch nicht gepinnt")
	tips._on_hover_ended("term:burn", 0)
	check(tips.open_count() == 0, "Ohne Pinnen verschwindet er beim Verlassen des Begriffs")

	tips._on_hover_started("term:burn", 0)
	tips._process(TermTooltips.SHOW_DELAY + 0.01)
	tips._process(TermTooltips.PIN_DELAY)
	check(tips.open_count() == 1 and tips._stack[0].pinned, "Nach langem Hovern festgepinnt")
	tips._on_hover_ended("term:burn", 0)
	check(tips.open_count() == 1, "Festgepinnt bleibt er beim Verlassen des Begriffs")
	# verschachtelt: Begriff im Tooltip (Ebene 1)
	tips._on_hover_started("term:nass", 1)
	tips._process(TermTooltips.SHOW_DELAY + 0.01)
	check(tips.open_count() == 2 and tips._stack[1].term == "nass", "Begriff im Tooltip öffnet einen weiteren")
	tips._close_from(0)
	check(tips.open_count() == 0, "Schließen einer Ebene schließt alle darüber")
	tips.queue_free()


# --- Kampf (M6) ---------------------------------------------------------------

func make_spell(stats: Dictionary, cast_time := 1.0, mana_cost := 10.0,
		target: EngravingDef.Target = EngravingDef.Target.ENEMY) -> SpellResult:
	var spell := SpellResult.new()
	spell.valid = true
	spell.cast_time = cast_time
	spell.mana_cost = mana_cost
	spell.engraving = EngravingDef.new()
	spell.engraving.role = MAIN
	spell.engraving.target = target
	for stat: StringName in stats:
		spell.stats[stat] = float(stats[stat])
	return spell


func make_mage(p_name: String, spells: Array[SpellResult]) -> CombatMage:
	var mage := CombatMage.new()
	mage.mage_name = p_name
	for i in spells.size():
		mage.add_spell(spells[i], "Spell %d" % (i + 1))
	return mage


func duel(a_spells: Array[SpellResult], b_spells: Array[SpellResult], seed_value := 1) -> Combat:
	return Combat.new(make_mage("A", a_spells), make_mage("B", b_spells), CombatRules.new(), seed_value)


func test_combat_damage_armor_crit() -> void:
	var c := duel([make_spell({ &"damage": 50 })], [])
	c.mages[1].add_stacks(&"armor", 20)
	c._apply_spell(0, 0)
	check(is_equal_approx(c.mages[1].hp, c.rules.max_hp - 30.0) and c.mages[1].stacks(&"armor") == 0, "Armor fängt 20 von 50 ab, HP %s" % c.mages[1].hp)
	c = duel([make_spell({ &"damage": 50, &"crit": 100 })], [])
	c._apply_spell(0, 0)
	check(is_equal_approx(c.mages[1].hp, c.rules.max_hp - 100.0), "100 %% Crit = doppelter Schaden, HP %s" % c.mages[1].hp)
	c = duel([make_spell({ &"heal": 30, &"armor": 5, &"hasted": 2 }, 1.0, 10.0, EngravingDef.Target.SELF)], [])
	c.mages[0].hp = c.rules.max_hp - 100.0
	c._apply_spell(0, 0)
	check(is_equal_approx(c.mages[0].hp, c.rules.max_hp - 70.0) and c.mages[0].stacks(&"armor") == 5 and c.mages[0].stacks(&"hasted") == 2,
		"Selbst-Spell: Heilung, Armor und Hasted auf den Caster")


func test_combat_status_rules() -> void:
	var rules := CombatRules.new()
	# Burn: Schaden pro Stack und Sekunde, dann -1 Stack
	# (Stacks direkt gesetzt: über _add_status würden Bleed + Burn zu Cauterized)
	var c := duel([make_spell({ &"burn": 3 })], [])
	c.mages[1].add_stacks(&"burn", 3)
	c.mages[1].add_stacks(&"bleed", 2)
	c._pulse(1)
	check(is_equal_approx(c.mages[1].hp, rules.max_hp - 3 * rules.burn_damage - 2 * rules.bleed_damage), "Burn und Bleed Puls, HP %s" % c.mages[1].hp)
	check(c.mages[1].stacks(&"burn") == 2 and c.mages[1].stacks(&"bleed") == 1, "Je -1 Stack pro Sekunde")
	# Nass hebt Burn 1 : 1 auf
	c.mages[1].remove_stacks(&"bleed", 99)
	c._apply_spell(0, 0)  # Burn jetzt 5
	c._add_status(1, &"wet", 3)
	check(c.mages[1].stacks(&"burn") == 2 and c.mages[1].stacks(&"wet") == 0, "3 Nass heben 3 Burn auf")
	# Slowed und Hasted heben sich auf, höchstens 10
	c._add_status(1, &"hasted", 4)
	c._add_status(1, &"slow", 6)
	check(c.mages[1].stacks(&"hasted") == 0 and c.mages[1].stacks(&"slow") == 2, "Slowed hebt Hasted auf")
	c._add_status(1, &"slow", 50)
	check(c.mages[1].stacks(&"slow") == rules.max_slowed_hasted, "Slowed höchstens 10")
	var spell := make_spell({}, 2.0)
	check(is_equal_approx(c.cast_time_for(c.mages[1], spell), 2.0 + 10 * rules.slowed_seconds), "Slowed verlängert die Cast-Zeit")
	# Armor Break 1 : 5
	c.mages[1].add_stacks(&"armor", 12)
	c._armor_break(1, 2)
	check(c.mages[1].stacks(&"armor") == 2, "2 Armor Break entfernen 10 Armor")


func test_combat_mana_shock_ice() -> void:
	var rules := CombatRules.new()
	# Mana wird beim Cast-Start bezahlt; fehlt es, wartet der Magier
	var c := duel([make_spell({ &"damage": 1 }, 1.0, 150.0)], [])
	c.step()
	check(c.mages[0].casting == 0 and is_equal_approx(c.mages[0].mana, rules.start_mana - 150.0), "Cast beginnt, Mana bezahlt")
	for k in 10:
		c.step()
	check(c.mages[0].casting == -1 and c.mages[0].waiting_for_mana, "Zu wenig Mana: wartet")
	# Schock: Schaden beim Bezahlen, höchstens so viel wie Stacks, plus Nass
	c = duel([make_spell({}, 1.0, 30.0)], [])
	c.mages[0].add_stacks(&"shock", 20)
	c.mages[0].add_stacks(&"wet", 4)
	c.step()
	check(is_equal_approx(c.mages[0].hp, rules.max_hp - 20 - 4 * rules.wet_shock_bonus) and c.mages[0].stacks(&"shock") == 0,
		"Schock 20 + Nass 4, HP %s" % c.mages[0].hp)
	# Freeze wandelt 100 Nass in 1 Eis; Eis pausiert den Cast
	c = duel([make_spell({ &"wet": 250, &"freeze_conversion": 100 })], [make_spell({}, 3.0)])
	c.step()  # B beginnt zu casten
	c._apply_spell(0, 0)
	check(c.mages[1].stacks(&"ice") == 2 and c.mages[1].stacks(&"wet") == 50, "250 Nass -> 2 Eis + 50 Nass")
	var elapsed := c.mages[1].cast_elapsed
	c._advance(1, 0.1)
	check(is_equal_approx(c.mages[1].cast_elapsed, elapsed), "Eis pausiert den Cast")
	c._pulse(1)
	c._pulse(1)
	check(not c.mages[1].is_stunned(), "Eis: -1 Stack pro Sekunde")
	# Mana Burn senkt die Mana-Reg und verbraucht sich
	c = duel([], [])
	c.mages[0].mana = 0.0
	c.mages[0].add_stacks(&"mana_burn", 4)
	c._pulse(0)
	check(is_equal_approx(c.mages[0].mana, rules.mana_regen - 4 * rules.mana_burn_per_stack) and c.mages[0].stacks(&"mana_burn") == 0,
		"Mana Burn senkt die Mana-Reg, Mana %s" % c.mages[0].mana)


func test_combat_run_and_determinism() -> void:
	var a_spells: Array[SpellResult] = [make_spell({ &"damage": 60, &"crit": 30 }, 1.5, 40.0), make_spell({ &"burn": 5 }, 1.0, 20.0)]
	var b_spells: Array[SpellResult] = [make_spell({ &"damage": 30, &"crit": 30 }, 1.5, 40.0)]
	var rules := CombatRules.new()
	var first := Combat.run(make_mage("A", a_spells), make_mage("B", b_spells), rules, 7)
	var second := Combat.run(make_mage("A", a_spells), make_mage("B", b_spells), rules, 7)
	check(first.over and first.winner == 0, "Stärkerer Magier gewinnt, Sieger %d" % first.winner)
	check(first.events.size() == second.events.size() and is_equal_approx(first.time, second.time)
		and first.events.back().text == second.events.back().text, "Gleicher Seed, gleicher Kampf")
	var no_spells := Combat.run(make_mage("A", []), make_mage("B", []), rules, 1)
	check(no_spells.winner == -1 and no_spells.time >= rules.max_duration - 0.01, "Ohne Spells: unentschieden nach Zeitlimit")


func test_combat_mage_from_foci() -> void:
	var good := FocusInstance.new()
	good.focus_def = content.get_focus(&"kleiner_fokus")
	good.dot_seed = 5
	good.gems = [
		PlacedGem.create(content.get_gem(&"hauptgem_mittel_grob"), engraving(&"magischer_bolzen"), Vector2(-120, 80)),
		PlacedGem.create(content.get_gem(&"nebengem_mittel_grob"), engraving(&"standard"), Vector2(130, 60)),
		PlacedGem.create(content.get_gem(&"nebengem_mittel_spitz"), engraving(&"standard"), Vector2(0, -150)),
	]
	good.loop = PackedInt32Array([0, 1, 2])
	good.loop_closed = true
	var bad := FocusInstance.new()
	bad.focus_def = good.focus_def
	var foci: Array[FocusInstance] = [good, bad, good, good, good, good, good]
	var warnings: Array[String] = []
	var mage := CombatMage.from_foci("Test", foci, PackedStringArray(["a", "b", "c", "d", "e", "f", "g"]), content.elements, warnings)
	check(mage.spells.size() == 4 and mage.spell_names[1] == "c", "Höchstens 5 Foki, ungültige übersprungen: %d" % mage.spells.size())
	check(warnings.size() == 1 and warnings[0].contains("„b“"), "Warnung für ungültigen Fokus")


func test_combat_statistics() -> void:
	var c := duel([make_spell({ &"damage": 50, &"crit": 100, &"burn": 3 })], [make_spell({ &"heal": 40 }, 1.0, 10.0, EngravingDef.Target.SELF)])
	c.mages[1].add_stacks(&"armor", 20)
	c._apply_spell(0, 0)  # 100 Schaden (Crit), 20 von Armor abgefangen, 3 Burn
	c._pulse(1)           # Burn: 3 Stacks Schaden, zählt für den Verursacher
	c.mages[1].hp -= 100.0
	c._apply_spell(1, 0)  # Heilung 40
	var s: Dictionary = c.statistics[0]
	check(is_equal_approx(s.damage.get("Spell 1", 0.0), 80.0), "Spell-Schaden nach Armor: %s" % [s.damage])
	check(is_equal_approx(s.damage.get("Burn", 0.0), 3 * c.rules.burn_damage), "Burn zählt für den Verursacher")
	check(int(s.crits.get("Spell 1", 0)) == 1, "Crit gezählt")
	check(is_equal_approx(c.statistics[1].absorbed, 20.0), "Abgefangen zählt beim Getroffenen")
	check(is_equal_approx(c.statistics[1].heal.get("Spell 1", 0.0), 40.0), "Heilung nach Quelle")
	check(is_equal_approx(Combat.total(s.damage), 80.0 + 3 * c.rules.burn_damage), "Gesamtschaden")
	c.step()
	check(int(c.statistics[0].casts.get("Spell 1", 0)) == 1, "Cast gezählt")


## Neue Regeln: Ziel aus der Hauptgravur, Slowed/Hasted nur für den nächsten Cast, Bedingungen.
func test_combat_targets_and_next_cast() -> void:
	# Angriff mit Armor-Nebengem: Armor landet beim Gegner (alles aufs Ziel)
	var c := duel([make_spell({ &"damage": 10, &"armor": 5 })], [])
	c._apply_spell(0, 0)
	check(c.mages[1].stacks(&"armor") == 5 and c.mages[0].stacks(&"armor") == 0, "Armor geht aufs Ziel des Angriffs")
	# beide Spieler (Rain)
	c = duel([make_spell({ &"burn": 2 }, 1.0, 10.0, EngravingDef.Target.BOTH)], [])
	c._apply_spell(0, 0)
	check(c.mages[0].stacks(&"burn") == 2 and c.mages[1].stacks(&"burn") == 2, "Rain trifft beide")
	# Slowed: nur nächster Cast, wird verbraucht, kein Abbau pro Sekunde
	var rules := CombatRules.new()
	c = duel([], [make_spell({}, 2.0, 10.0)])
	c.mages[1].add_stacks(&"slow", 3)
	c._pulse(1)
	check(c.mages[1].stacks(&"slow") == 3, "Slowed baut sich nicht über Zeit ab")
	c.step()
	check(is_equal_approx(c.mages[1].cast_total, 2.0 + 3 * rules.slowed_seconds) and c.mages[1].stacks(&"slow") == 0,
		"Slowed verlängert den nächsten Cast und wird verbraucht")


func test_combat_conditions() -> void:
	var a := make_mage("A", [])
	a.add_spell(make_spell({ &"heal": 50 }, 1.0, 10.0, EngravingDef.Target.SELF), "Heal",
		SpellCondition.create(SpellCondition.Type.OWN_HP_BELOW, 50.0))
	a.add_spell(make_spell({ &"damage": 10 }), "Bolzen")
	a.add_spell(make_spell({ &"burn": 1 }), "Opener", SpellCondition.create(SpellCondition.Type.ONCE))
	var c := Combat.new(a, make_mage("B", []), CombatRules.new(), 1)
	c.step()
	check(a.casting == 1, "Heal übersprungen (Leben über 50 %%), Bolzen gecastet")
	a.casting = -1
	c.step()
	check(a.casting == 2, "Einmal-Spell beim ersten Mal")
	a.casting = -1
	a.hp = 100.0
	c.step()
	check(a.casting == 0, "Unter 50 %% Leben: Heal")
	a.casting = -1
	a.next_spell = 2
	a.hp = a.max_hp
	c.step()
	check(a.casting == 1, "Einmal-Spell nicht ein zweites Mal")
	check(SpellCondition.create(SpellCondition.Type.ENEMY_HAS_STATUS, 0.0, &"burn").describe() == "Gegner hat Status Burn", "Beschreibung")
	var enemy_burn := SpellCondition.create(SpellCondition.Type.ENEMY_HAS_STATUS, 0.0, &"burn")
	check(not enemy_burn.is_met(a, c.mages[1], 0), "Gegner ohne Burn")
	c.mages[1].add_stacks(&"burn", 1)
	check(enemy_burn.is_met(a, c.mages[1], 0), "Gegner mit Burn")


func test_power_transfer_half_radius() -> void:
	var minor := content.get_gem(&"nebengem_mittel_grob")
	check(engraving(&"standard").display_name == "Power Transfer", "Standard heißt jetzt Power Transfer")
	check(is_equal_approx(PlacedGem.radius_of(minor, engraving(&"standard")), minor.radius * 0.5), "Power Transfer: halber Radius")
	check(is_equal_approx(PlacedGem.radius_of(minor, engraving(&"crit")), minor.radius), "Andere Gravuren: voller Radius")
	# Einsammeln nutzt den halben Radius
	var main := make_gem(MAIN, GROB, 10)
	var gem := make_gem(MINOR, GROB, 80)
	var dots := dots_line(MINOR_POS, MINOR_OUTER, 10)  # Abstände 10 .. 46
	var transfer := EngravingDef.new()
	transfer.role = MINOR
	transfer.transfer_to_main = true
	transfer.radius_factor = 0.5
	var r := evaluate(lab(main, engraving(&"magischer_bolzen"), gem, transfer), dots)
	check(r.gem_results[1].base_count == 8, "Radius 40 statt 80: 8 von 10 Punkten, waren %d" % r.gem_results[1].base_count)


# --- Etappe 2: neue Status ----------------------------------------------------

func test_combat_new_statuses() -> void:
	var rules := CombatRules.new()
	# Perma-Burn: erzeugt pro Sekunde Burn, baut sich nicht ab
	var c := duel([], [])
	c.mages[1].add_stacks(&"perma_burn", 2)
	c._pulse(1)
	c._pulse(1)
	check(c.mages[1].stacks(&"perma_burn") == 2 and c.mages[1].stacks(&"burn") > 0, "Perma-Burn bleibt und erzeugt Burn")
	# Cleanse entfernt eigene Debuffs, Dispel gegnerische Buffs
	c = duel([make_spell({ &"cleanse": 1 }, 1.0, 10.0, EngravingDef.Target.SELF), make_spell({ &"dispel": 1 })], [])
	c.mages[0].add_stacks(&"perma_burn", 2)
	c.mages[0].add_stacks(&"armor", 5)
	c.mages[1].add_stacks(&"thorns", 3)
	c.mages[1].add_stacks(&"burn", 4)
	c._apply_spell(0, 0)
	check(c.mages[0].stacks(&"perma_burn") == 0 and c.mages[0].stacks(&"armor") == 5, "Cleanse: Debuffs weg, Buffs bleiben")
	c._apply_spell(0, 1)
	check(c.mages[1].stacks(&"thorns") == 0 and c.mages[1].stacks(&"burn") == 4, "Dispel: Buffs weg, Debuffs bleiben")
	# Bless: +X Heilung pro Stack, 1 Stack pro Heilung
	c = duel([make_spell({ &"heal": 10 }, 1.0, 10.0, EngravingDef.Target.SELF)], [])
	c.mages[0].hp = 100.0
	c.mages[0].add_stacks(&"bless", 2)
	c._apply_spell(0, 0)
	check(is_equal_approx(c.mages[0].hp, 110.0 + 2 * rules.bless_heal) and c.mages[0].stacks(&"bless") == 1, "Bless erhöht Heilung")
	# Thorns und Mana Absorption reagieren auf Spell-Treffer
	c = duel([make_spell({ &"damage": 10 })], [])
	c.mages[1].add_stacks(&"thorns", 2)
	c.mages[1].add_stacks(&"mana_absorption", 3)
	c.mages[1].mana = 0.0
	c._apply_spell(0, 0)
	check(is_equal_approx(c.mages[0].hp, rules.max_hp - 2 * rules.thorns_damage), "Thorns: Gegenschaden")
	check(is_equal_approx(c.mages[1].mana, 3 * rules.mana_absorption_mana), "Mana Absorption: Mana pro Treffer")
	check(c.mages[1].stacks(&"thorns") == 1 and c.mages[1].stacks(&"mana_absorption") == 2, "Je 1 Stack verbraucht")
	check(is_equal_approx(c.statistics[1].damage.get("Thorns", 0.0), 2 * rules.thorns_damage), "Thorns in der Statistik des Trägers")
	# Damage Reduction halbiert den nächsten Spell (alle Treffer), Mehrfach-Treffer
	c = duel([make_spell({ &"damage": 10, &"hits": 3 })], [])
	c.mages[1].add_stacks(&"damage_reduction", 1)
	c._apply_spell(0, 0)
	check(is_equal_approx(c.mages[1].hp, rules.max_hp - 3 * 10 * rules.damage_reduction_factor), "3 Treffer, halbiert, HP %s" % c.mages[1].hp)
	c._apply_spell(0, 0)
	check(is_equal_approx(c.mages[1].hp, rules.max_hp - 15 - 30), "Danach wieder voller Schaden")
	# Accelerated Burn: Burn tickt doppelt so oft
	c = duel([], [])
	c.mages[1].add_stacks(&"burn", 4)
	c.mages[1].add_stacks(&"accelerated_burn", 5)
	for k in 10:
		c.step()  # 1 Sekunde
	check(c.mages[1].stacks(&"burn") == 2, "Zwei Burn-Ticks pro Sekunde, Burn %d" % c.mages[1].stacks(&"burn"))
	# Life Rewind: nach 10 s Leben auf gespeicherten Wert (auch nach unten)
	c = duel([make_spell({ &"life_rewind": 1 }, 1.0, 10.0, EngravingDef.Target.SELF)], [])
	c.mages[0].hp = 300.0
	c._apply_spell(0, 0)
	c.mages[0].hp = 500.0
	for k in int(rules.life_rewind_seconds):
		c._pulse(0)
	check(is_equal_approx(c.mages[0].hp, 300.0) and c.mages[0].stacks(&"life_rewind") == 0, "Life Rewind setzt auf 300 zurück, HP %s" % c.mages[0].hp)


# --- Etappen 3 bis 5 und Paket 2 -----------------------------------------------

func test_rule_min_and_cap() -> void:
	var rule := ScalingRule.new()
	rule.source = ScalingRule.Source.BASE
	rule.per_n = 1
	rule.amount = 1.0
	rule.min_count = 50
	check(is_zero_approx(rule.evaluate(49.0, {})), "Unter der Mindestanzahl: nichts")
	check(is_equal_approx(rule.evaluate(60.0, {}), 60.0), "Ab der Mindestanzahl: voller Wert")
	rule.cap = 10.0
	check(is_equal_approx(rule.evaluate(60.0, {}), 10.0), "Höchstwert begrenzt")


func test_minor_base_stats_and_mana_efficiency() -> void:
	var r := evaluate(lab(make_gem(MAIN, GROB, 80), engraving(&"magischer_bolzen"),
		make_gem(MINOR, GROB, 80), engraving(&"neben_cleanse")), [])
	check_stat(r, &"cleanse", 1.0)
	# Mana Efficiency: +1 s Cast-Zeit, 3 Luft = 15 Punkte senken um 0,3 s; 2 Wasser = 10 Punkte = -10 Mana
	var dots := dots_line(MINOR_POS, MINOR_OUTER, 3, &"air") + dots_line(MINOR_POS + Vector2(0, 2), MINOR_OUTER, 2, &"water")
	r = evaluate(lab(make_gem(MAIN, GROB, 80), engraving(&"magischer_bolzen"),
		make_gem(MINOR, GROB, 80), engraving(&"mana_efficiency")), dots)
	check_stat(r, &"cast_time_reduction", -0.7)
	check_stat(r, &"mana_reduction", 10.0)


func test_radius_expansion() -> void:
	# Hauptgem Radius 30 sammelt 6 Punkte (10..30); 4 Erde = 20 Punkte = +10 Radius -> 8 Punkte (10..38)
	var dots := dots_line(MAIN_POS, MAIN_OUTER, 20) + dots_line(MINOR_POS, MINOR_OUTER, 4, &"earth")
	var r := evaluate(lab(make_gem(MAIN, GROB, 30), engraving(&"magischer_bolzen"),
		make_gem(MINOR, GROB, 80), engraving(&"radius_expansion")), dots)
	check(r.valid, "gültig: %s" % [r.errors])
	check_stat(r, &"radius_bonus", 10.0)
	check(r.gem_results[0].base_count == 8, "Zweiter Durchlauf mit Radius 40: 8 Punkte, waren %d" % r.gem_results[0].base_count)
	check_stat(r, &"damage", 8.0)


func test_multiplier_engraving() -> void:
	var multi := engraving(&"multiplikator")
	var gem := make_gem(MINOR, GROB, 100)
	# Radius 80, innerer Ring 30: Punkte bei 10..78 = 18, davon 6 innen (10..30) zählen doppelt
	var r := evaluate(lab(make_gem(MAIN, GROB, 5), engraving(&"magischer_bolzen"), gem, multi),
		dots_line(MINOR_POS, MINOR_OUTER, 20))
	check(r.valid, "gültig: %s" % [r.errors])
	check(r.gem_results[1].base_count == 18, "0,8-facher Radius: 18 Punkte, waren %d" % r.gem_results[1].base_count)
	check(is_equal_approx(r.gem_results[1].effective_base, 24.0), "6 innen ×2 + 12 außen = 24, war %s" % r.gem_results[1].effective_base)
	check_stat(r, &"damage", 24.0)  # an das Hauptgem übertragen
	gem.size = GemDef.Size.GROSS
	r = evaluate(lab(make_gem(MAIN, GROB, 5), engraving(&"magischer_bolzen"), gem, multi), [])
	check(not r.valid, "Multiplikator passt nicht auf große Gems")


func test_combat_package_two() -> void:
	var rules := CombatRules.new()
	# Critical Chance: zählt zur Crit-Chance und wird beim Crit verbraucht
	var c := duel([make_spell({ &"damage": 50 })], [])
	c.mages[0].add_stacks(&"critical_chance", 100)
	c._apply_spell(0, 0)
	check(is_equal_approx(c.mages[1].hp, rules.max_hp - 100.0) and c.mages[0].stacks(&"critical_chance") == 0,
		"Critical Chance: Crit, danach verbraucht")
	# Critical Damage: +50 % Crit-Schaden
	c = duel([make_spell({ &"damage": 50, &"crit": 100, &"crit_damage": 50 })], [])
	c._apply_spell(0, 0)
	check(is_equal_approx(c.mages[1].hp, rules.max_hp - 125.0), "Crit mit +50 %% = 250 %%, HP %s" % c.mages[1].hp)
	# Cauterized: Bleed + Burn 1 : 1, verhindert die nächste Heilung
	c = duel([], [])
	c._add_status(1, &"bleed", 3)
	c._add_status(1, &"burn", 2)
	var m := c.mages[1]
	check(m.stacks(&"bleed") == 1 and m.stacks(&"burn") == 0 and m.stacks(&"cauterized") == 2, "2 Bleed + 2 Burn -> 2 Cauterized")
	m.hp = 100.0
	c._heal(1, 30.0, "Test")
	check(is_equal_approx(m.hp, 100.0) and m.stacks(&"cauterized") == 1, "Cauterized verhindert eine Heilung")
	# Blood Thinner: Bleed tickt zusätzlich zur halben Sekunde
	c = duel([], [])
	c.mages[1].add_stacks(&"bleed", 4)
	c.mages[1].add_stacks(&"blood_thinner", 1)
	c._half_tick(1)
	check(is_equal_approx(c.mages[1].hp, rules.max_hp - 4 * rules.bleed_damage) and c.mages[1].stacks(&"bleed") == 3, "Blood Thinner: halber Tick")
	# Max Health hebt nur das Maximum, Rotten senkt es (Leben sinkt mit)
	c = duel([make_spell({ &"max_health": 10 }, 1.0, 10.0, EngravingDef.Target.SELF), make_spell({ &"rotten": 30 })], [])
	c._apply_spell(0, 0)
	check(is_equal_approx(c.mages[0].max_hp, rules.max_hp + 10 * rules.max_health_per_stack) and is_equal_approx(c.mages[0].hp, rules.max_hp),
		"Max Health: Maximum %s, Leben bleibt" % c.mages[0].max_hp)
	c._apply_spell(0, 1)
	check(is_equal_approx(c.mages[1].max_hp, rules.max_hp - 30 * rules.rotten_per_stack) and is_equal_approx(c.mages[1].hp, c.mages[1].max_hp),
		"Rotten: Maximum und Leben sinken")
	c._remove_all(1, Combat.DEBUFFS, "Cleanse")
	check(is_equal_approx(c.mages[1].max_hp, rules.max_hp), "Cleanse entfernt Rotten")
	# Vampire: Leben-Reg in Höhe der Bleed-Stacks des Gegners
	c = duel([make_spell({ &"vampire": 2 }, 1.0, 10.0, EngravingDef.Target.SELF)], [])
	c.mages[1].add_stacks(&"bleed", 5)
	c._apply_spell(0, 0)
	check(c.mages[0].stacks(&"life_regen") == 10, "Vampire: 5 Bleed × 2 = 10 Leben-Reg")
	# Echo: wiederholt sofort, kostet Mana erneut
	c = duel([make_spell({ &"damage": 10, &"echo": 2 }, 1.0, 10.0)], [])
	c.mages[0].mana = 15.0
	c._finish_spell(0, 0)
	check(is_equal_approx(c.mages[1].hp, rules.max_hp - 20.0) and is_equal_approx(c.mages[0].mana, 5.0),
		"Echo: 1 Wiederholung, dann fehlt Mana (HP %s)" % c.mages[1].hp)


func test_stack_conditions() -> void:
	var a := CombatMage.new()
	var b := CombatMage.new()
	a.add_stacks(&"burn", 3)
	var above := SpellCondition.create(SpellCondition.Type.OWN_STACKS_ABOVE, 50.0, &"burn", 2)
	check(above.is_met(a, b, 0), "3 Burn > 2")
	above.amount = 3
	check(not above.is_met(a, b, 0), "3 Burn ist nicht mehr als 3")
	var below := SpellCondition.create(SpellCondition.Type.ENEMY_STACKS_BELOW, 50.0, &"burn", 1)
	check(below.is_met(a, b, 0), "Gegner hat weniger als 1 Burn")
	check(below.describe() == "Gegner hat weniger als 1 Burn", "Beschreibung: %s" % below.describe())


func test_blocked_under_gem() -> void:
	# Stein mit halber Größe 15: Punkte bei 10 und 14 sind verdeckt, ab 18 zählen sie
	var gem := make_gem(MINOR, GROB, 80)
	gem.body_radius = 15.0
	var r := evaluate(lab(make_gem(MAIN, GROB, 5), engraving(&"magischer_bolzen"), gem, engraving(&"standard")),
		dots_line(MINOR_POS, MINOR_OUTER, 5))
	check(r.blocked.size() == 2, "2 Punkte verdeckt, waren %d" % r.blocked.size())
	check(r.gem_results[1].base_count == 3, "3 Punkte eingesammelt, waren %d" % r.gem_results[1].base_count)
	# Multiplikator: innerer Ring beginnt am Stein (15 + 0,3 × 100 = 45)
	gem.radius = 100.0
	var placed := PlacedGem.create(gem, engraving(&"multiplikator"), Vector2.ZERO)
	check(is_equal_approx(placed.get_inner_radius(), 45.0), "Innerer Ring bis 45, war %s" % placed.get_inner_radius())


func test_life_rewind_threshold() -> void:
	var rewind := engraving(&"life_rewind")
	var r := evaluate(lab(make_gem(MAIN, GROB, 80), rewind, make_gem(MINOR, GROB, 80), null),
		dots_line(MAIN_POS, MAIN_OUTER, 9, &"water"))
	check_stat(r, &"life_rewind", 0.0)  # 9 Wasser = 45 Punkte
	r = evaluate(lab(make_gem(MAIN, GROB, 80), rewind, make_gem(MINOR, GROB, 80), null),
		dots_line(MAIN_POS, MAIN_OUTER, 16, &"water"))
	check_stat(r, &"life_rewind", 1.0)  # 80 Punkte: trotzdem nur 1


func test_dispel_per_stack() -> void:
	# 2 Dispel: entfernt die zwei Buffs mit den meisten Stacks komplett, der dritte bleibt
	var c := duel([make_spell({ &"dispel": 2 })], [])
	var m := c.mages[1]
	m.add_stacks(&"armor", 30)
	m.add_stacks(&"thorns", 5)
	m.add_stacks(&"bless", 2)
	m.add_stacks(&"burn", 4)
	c._apply_spell(0, 0)
	check(m.stacks(&"armor") == 0 and m.stacks(&"thorns") == 0, "Armor und Thorns ganz entfernt")
	check(m.stacks(&"bless") == 2 and m.stacks(&"burn") == 4, "Bless bleibt, Debuffs unberührt")
