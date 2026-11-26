extends TestSuite
## Inhalte: Gem-Formen, Gravuren, Elemente, Foki und Skalierungsregeln.


func test_content_loads() -> void:
	check(content != null, "crafting_content.tres sollte laden")
	check(content.elements.size() == 5, "5 Elemente erwartet")
	check(content.gems.size() == 16, "16 Gem-Formen erwartet (2 Rollen x 4 Größen x 2 Winkel), waren %d" % content.gems.size())
	for role in [MAIN, MINOR]:
		for size in GemDef.Size.values():
			for angle in [SPITZ, GROB]:
				var gem := content.find_gem(role, size, angle)
				check(gem != null and gem.role == role and gem.size == size and gem.angle == angle,
					"Gem für Rolle %d, Größe %d, Winkel %d sollte existieren" % [role, size, angle])
	check(content.find_gem(MINOR, GemDef.Size.KLEIN, GROB).radius < content.find_gem(MINOR, GemDef.Size.GROSS, GROB).radius,
		"Größere Gems haben einen größeren Radius")
	check(content.foci.size() == 9, "9 Fokus-Typen erwartet")
	check(content.get_engravings_for(MAIN).size() == 31, "31 Hauptgravuren erwartet")
	check(content.get_engravings_for(MINOR).size() == 22, "22 Nebengravuren erwartet")
	for e in content.engravings:
		var text := ContentText.describe(e, content)
		check(text != "" and not text.contains("N-E"), "%s braucht eine Beschreibung ohne Abkürzung" % e.id)
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
	var fire_focus := content.get_focus(&"feuer_fokus")
	check(fire_focus.allows_element(&"fire") and not fire_focus.allows_element(&"water"), "Feuer-Fokus erlaubt nur Feuer")
	check(content.get_focus(&"kleiner_fokus").allows_element(&"water"), "Normaler Fokus erlaubt alle Elemente")

	var focus := _content_triangle(fire_focus, Vector2(-100, 60), Vector2(100, 60), Vector2(0, -120))
	focus.element_fill = {&"fire": 60, &"water": 5}
	var r := evaluate_real(focus)
	check(not r.valid and _has_error(r, "keine Wasser-Essenz"), "Wasser im Feuer-Fokus sollte abgelehnt werden: %s" % [r.errors])
	focus.element_fill = {&"fire": fire_focus.max_element_dots}
	r = evaluate_real(focus)
	check(r.valid, "Volles Feuer im Feuer-Fokus sollte gültig sein: %s" % [r.errors])

	focus.focus_def = content.get_focus(&"neutraler_fokus")
	r = evaluate_real(focus)
	check(not r.valid and _has_error(r, "Zu viele Essenzen"), "Essenzen im neutralen Fokus sollten abgelehnt werden")
	focus.element_fill = {}
	r = evaluate_real(focus)
	check(r.valid, "Nur neutrale Essenz im neutralen Fokus sollte gültig sein: %s" % [r.errors])


## Der Faktor hängt an der Gravur, pro Element einstellbar.
func test_element_factor_per_element() -> void:
	for e in content.engravings:
		for id: StringName in e.element_factors:
			check(is_equal_approx(e.factor_of(id), 5.0), "%s: Faktor 5 für %s erwartet" % [e.id, id])
	var bolt := engraving(&"magischer_bolzen").duplicate() as EngravingDef
	bolt.element_factors = bolt.element_factors.duplicate()
	bolt.element_factors[&"fire"] = 3.0
	var focus := lab(make_gem(MAIN, GROB, 80), bolt, make_gem(MINOR, GROB, 80), null)
	var dots := dots_line(MAIN_POS, MAIN_OUTER, 2, &"fire") + dots_line(MAIN_POS + Vector2(-2, 0), MAIN_OUTER, 2, &"water")
	var r := evaluate(focus, dots)
	check_stat(r, &"damage", 16.0)  # 2 Feuer x 3 + 2 Wasser x 5
	check(is_equal_approx(r.gem_results[0].points, 16.0), "Punkte des Hauptgems, war %s" % r.gem_results[0].points)


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
