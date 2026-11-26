extends TestSuite
## Prüfungen der Auswertung: Kreis, Hauptgem, Gravuren, Fokusform.


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
