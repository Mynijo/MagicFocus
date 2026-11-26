extends TestSuite
## Editor-Seite: Formulare für alle Einträge, Änderungen werden gespeichert und zurückgesetzt.


func test_editor_page() -> void:
	var page: Control = load("res://ui/editor/editor.tscn").instantiate()
	page._ready()  # außerhalb des Baums (der Runner läuft in _init)
	check(page._lists.size() == 4, "4 Reiter")
	check(page._lists[0].item_count == content.engravings.size(), "Alle Gravuren in der Liste")
	# Jedes Formular lässt sich bauen
	for tab in 4:
		for i in page._keys[tab].size():
			page._on_item_selected(i, tab)
	# Wert ändern wie über ein Feld, dann zurücksetzen
	page._on_item_selected(0, 3)
	var rules := Balance.rules()
	var old := rules.max_hp
	rules.max_hp = 99.0
	page._changed(3)
	check(Balance.is_changed("rules") and page._lists[3].get_item_text(0).begins_with("•"), "Änderung markiert")
	Balance.reset("rules")
	check(is_equal_approx(rules.max_hp, old) and not Balance.is_changed("rules"), "Zurückgesetzt")
	page.free()
