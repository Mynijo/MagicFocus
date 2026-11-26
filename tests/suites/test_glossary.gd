extends TestSuite
## Glossar-Seite: alle Inhalte erscheinen, die Suche filtert.


func test_glossary_page() -> void:
	var page: Control = load("res://ui/glossary/glossary.tscn").instantiate()
	page._ready()  # außerhalb des Baums (der Runner läuft in _init)
	var texts: Array[RichTextLabel] = page._texts
	check(texts.size() == 6, "6 Reiter")
	var all := ""
	for label in texts:
		all += label.get_parsed_text()
	for e in content.engravings:
		check(all.contains(e.display_name), "Gravur %s im Glossar" % e.id)
	for id: StringName in Status.NAMES:
		check(all.contains(Status.name_of(id)), "Status %s im Glossar" % id)
	for def in content.foci:
		check(all.contains(def.display_name), "Fokus %s im Glossar" % def.id)
	check(all.contains("Mana pro Sekunde"), "Kampfregeln im Glossar")
	page._search.text = "Meteor"
	page.refresh()
	var engravings := texts[1].get_parsed_text()
	check(engravings.contains("Meteor") and not engravings.contains("Feuerball"), "Suche filtert die Gravuren")
	page.free()
