extends TestSuite
## Einsammeln: Sektoren, Reihenfolge, Kapazität, Radius, Multiplikator, verdeckte Essenz.


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
