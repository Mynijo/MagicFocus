extends TestSuite
## Gravuren: Punkte, Element-Filter, Übertragen und die Werte einzelner Gravuren.


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
	check(engraving(&"magischer_bolzen").element_factors.size() == 5, "Magischer Bolzen hat alle Elemente")


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
	check(is_equal_approx(r.mana_cost, 1200 * SpellEvaluator.MANA_PER_LENGTH - 2.0), "4 neutrale Essenz = -2 Mana, war %s" % r.mana_cost)
	r = evaluate(lab(main, bolt, minor, engraving(&"status_burn")), neutral)
	check(not r.stats.has(&"burn") or is_zero_approx(r.get_stat(&"burn")), "Burn: neutrale Essenz bewirkt nichts")

	var main_dots := dots_line(MAIN_POS, MAIN_OUTER, 2)
	r = evaluate(lab(make_gem(MAIN, GROB, 80), engraving(&"heal"), minor, null), main_dots)
	check_stat(r, &"heal", 10.0)  # 2 x5
	r = evaluate(lab(make_gem(MAIN, GROB, 80), engraving(&"schutz"), minor, null), main_dots)
	check_stat(r, &"armor", 10.0)


func test_cast_time_and_mana() -> void:
	var main := make_gem(MAIN, GROB, 10)
	var bolt := engraving(&"magischer_bolzen")
	var minor := make_gem(MINOR, GROB, 80)

	var r := evaluate(lab(main, bolt, minor, null))
	check(is_equal_approx(r.cast_time, 3.0), "3 Gems = 3 s, war %s" % r.cast_time)
	check(is_equal_approx(r.mana_cost, 1200 * SpellEvaluator.MANA_PER_LENGTH), "Umfang 1200 × Mana pro Länge, war %s" % r.mana_cost)

	r = evaluate(lab(main, bolt, minor, engraving(&"cast_speed")), dots_line(MINOR_POS, MINOR_OUTER, 4, &"air"))
	check(is_equal_approx(r.cast_time, 1.0), "4 Luft = 20 Punkte = -2 s, war %s" % r.cast_time)
	r = evaluate(lab(main, bolt, minor, engraving(&"cast_speed")), dots_line(MINOR_POS, MINOR_OUTER, 17, &"air"))
	check(is_equal_approx(r.cast_time, SpellEvaluator.MIN_CAST_TIME), "Cast-Zeit hat eine Untergrenze, war %s" % r.cast_time)

	r = evaluate(lab(main, bolt, minor, engraving(&"mana_reduktion")), dots_line(MINOR_POS, MINOR_OUTER, 5, &"water"))
	check(is_equal_approx(r.mana_cost, 1200 * SpellEvaluator.MANA_PER_LENGTH - 12.0), "5 Wasser = 25 Punkte = -12 Mana, war %s" % r.mana_cost)


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


func test_mana_burn_minor() -> void:
	var r := evaluate(lab(make_gem(MAIN, GROB, 10), engraving(&"magischer_bolzen"), make_gem(MINOR, GROB, 80), engraving(&"mana_burn")),
		dots_line(MINOR_POS, MINOR_OUTER, 3, &"lightning") + dots_line(MINOR_POS + Vector2(2, 0), MINOR_OUTER, 4))
	check_stat(r, &"mana_burn", 3.0)  # 3 Blitz x 5 / 5, neutrale Essenz zählt nicht


func test_freeze_counts_water_and_air() -> void:
	var dots := dots_line(MAIN_POS, MAIN_OUTER, 2, &"water") + dots_line(MAIN_POS + Vector2(-2, 0), MAIN_OUTER, 1, &"air") \
		+ dots_line(MAIN_POS + Vector2(0, -2), MAIN_OUTER, 3, &"fire") + dots_line(MAIN_POS + Vector2(2, 2), MAIN_OUTER, 4)
	var r := evaluate(lab(make_gem(MAIN, GROB, 80), engraving(&"freeze"), make_gem(MINOR, GROB, 80), null), dots)
	check_stat(r, &"damage", 19.0)  # 4 neutral + (2 Wasser + 1 Luft) x 5, Feuer zählt nicht
	check_stat(r, &"freeze_conversion", 100.0)


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


func test_life_rewind_threshold() -> void:
	var rewind := engraving(&"life_rewind")
	var r := evaluate(lab(make_gem(MAIN, GROB, 80), rewind, make_gem(MINOR, GROB, 80), null),
		dots_line(MAIN_POS, MAIN_OUTER, 9, &"water"))
	check_stat(r, &"life_rewind", 0.0)  # 9 Wasser = 45 Punkte
	r = evaluate(lab(make_gem(MAIN, GROB, 80), rewind, make_gem(MINOR, GROB, 80), null),
		dots_line(MAIN_POS, MAIN_OUTER, 16, &"water"))
	check_stat(r, &"life_rewind", 1.0)  # 80 Punkte: trotzdem nur 1
