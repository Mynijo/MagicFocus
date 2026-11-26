extends TestSuite
## Werkstatt: Setzen, Verbinden, Vorschau, Tooltips.


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
	check(messages.back().contains("In der Reichweite"), "Zu nahes Gem sollte abgelehnt werden")
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
	check(text.contains("Burn: 0 → [b]5[/b]"), "Neuer Statuswert sollte als Zuwachs erscheinen")
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
	check(content.glossary.size() == 5 + 2 + 29, "5 Elemente, Buff, Debuff und 29 Begriffe, waren %d" % content.glossary.size())
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
	check(text.contains("[color=#fff][url=term:wet]"), "Begriffe in Formatierung werden verlinkt")
	check(not tips.linkify("Burn", "burn").contains("[url"), "Ausgeschlossener Begriff (eigener Tooltip) bleibt Text")
	tips.free()


## Ablauf: erscheint nach Verzögerung, verschwindet ohne Pinnen, bleibt nach langem Hovern.
func test_tooltip_pinning() -> void:
	var tips := TermTooltips.new()
	tips.setup(content)
	tree.root.add_child(tips)
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
	tips._on_hover_started("term:wet", 1)
	tips._process(TermTooltips.SHOW_DELAY + 0.01)
	check(tips.open_count() == 2 and tips._stack[1].term == "wet", "Begriff im Tooltip öffnet einen weiteren")
	tips._close_from(0)
	check(tips.open_count() == 0, "Schließen einer Ebene schließt alle darüber")
	tips.queue_free()
