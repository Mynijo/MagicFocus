extends TestSuite
## Glossar-Seite: alle Inhalte erscheinen, die Suche filtert, die Gravuren-Tabelle sortiert.


func test_glossary_page() -> void:
	var page: Control = load("res://ui/glossary/glossary.tscn").instantiate()
	page._ready()  # außerhalb des Baums (der Runner läuft in _init)
	var texts: Dictionary = page._texts
	check(texts.size() == 5, "5 Text-Reiter und die Gravuren-Tabelle")
	var all := ""
	for label: RichTextLabel in texts.values():
		all += label.get_parsed_text()
	for id: StringName in Status.NAMES:
		check(all.contains(Status.name_of(id)), "Status %s im Glossar" % id)
	for def in content.foci:
		check(all.contains(def.display_name), "Fokus %s im Glossar" % def.id)
	check(all.contains("Mana pro Sekunde"), "Kampfregeln im Glossar")

	var table: EngravingTable = page._engraving_table
	check(table.row_count() == content.engravings.size(), "Alle Gravuren in der Tabelle, waren %d" % table.row_count())
	page._search.text = "Meteor"
	page.refresh()
	check(table.row_count() == 1, "Suche filtert die Gravuren, waren %d" % table.row_count())
	page.free()


func test_engraving_table_sort_and_groups() -> void:
	var table := EngravingTable.new()
	table.setup(content)
	# ohne Gruppen, nach Feuer-Faktor absteigend sortiert: zuerst Gravuren mit Feuer
	table._group = EngravingTable.Group.NONE
	table._on_title_clicked(1, MOUSE_BUTTON_LEFT)
	table._on_title_clicked(1, MOUSE_BUTTON_LEFT)
	var first := table._tree.get_root().get_first_child()
	check(first.get_text(1) != "", "Absteigend nach Feuer: erste Zeile hat Feuer, war %s" % first.get_text(table._col_name))
	check(table.row_count() == content.engravings.size(), "Ohne Gruppen alle Zeilen")
	# nach Rolle gruppiert: zwei Gruppen
	table._group = EngravingTable.Group.ROLE
	table.refresh()
	check(table._tree.get_root().get_child_count() == 2, "Zwei Gruppen nach Rolle")
	table.free()


func test_engraving_table_keeps_collapsed_groups() -> void:
	var table := EngravingTable.new()
	table.setup(content)
	var group := table._tree.get_root().get_first_child()
	var title := group.get_text(table._col_name)
	group.collapsed = true  # löst item_collapsed aus
	table._on_title_clicked(2, MOUSE_BUTTON_LEFT)  # neu sortieren
	var again := table._tree.get_root().get_first_child()
	check(again.get_text(table._col_name) == title and again.collapsed, "Gruppe %s bleibt nach dem Sortieren zu" % title)
	table.free()
