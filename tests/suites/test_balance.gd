extends TestSuite
## Änderungen aus dem Editor: speichern, anwenden, zurücksetzen.


func test_balance_save_and_reset() -> void:
	Balance.ensure_applied()
	var heal := engraving(&"heal")
	var key := "engraving/heal"
	var old_amount := heal.rules[0].amount
	check(not Balance.is_changed(key), "Ohne Änderung kein Eintrag")
	heal.rules[0].amount = 7.0
	heal.element_factors[&"water"] = 3.0
	check(Balance.is_changed(key), "Geänderte Gravur wird erkannt")
	check(Balance.save() == OK, "Speichern klappt")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Balance.path))
	check(data.keys() == [key], "Nur der geänderte Eintrag steht in der Datei: %s" % [data.keys()])
	check(is_equal_approx(data[key].rules[0].amount, 7.0), "Neuer Wert gespeichert")
	Balance.reset(key)
	check(is_equal_approx(heal.rules[0].amount, old_amount) and is_equal_approx(heal.factor_of(&"water"), 5.0),
		"Zurücksetzen stellt den Standard her")
	data = JSON.parse_string(FileAccess.get_file_as_string(Balance.path))
	check(data.is_empty(), "Nach dem Zurücksetzen ist die Datei leer")


func test_balance_roundtrip() -> void:
	# Jede Ressource übersteht Umwandeln und Zurückschreiben unverändert
	var c := Balance.content()
	var r := Balance.rules()
	for key: String in Balance.keys(c):
		var target := Balance.resource_for(key, c, r)
		var before := JSON.stringify(Balance.serialize(target))
		Balance.deserialize(target, JSON.parse_string(before))
		check(JSON.stringify(Balance.serialize(target)) == before, "Roundtrip von %s" % key)
	var spell := evaluate_real(_content_triangle(content.get_focus(&"kleiner_fokus"),
		Vector2(0, -100), Vector2(-100, 80), Vector2(100, 80)))
	check(spell.valid, "Inhalte nach dem Roundtrip weiter nutzbar: %s" % [spell.errors])


func test_balance_rules_update_tooltips() -> void:
	Balance.ensure_applied()
	var rules := Balance.rules()
	var old := rules.burn_damage
	rules.burn_damage = 9.0
	Balance.save()
	check(content.get_term(&"burn").text.contains("9 Schaden"), "Tooltip zeigt den neuen Wert: %s" % content.get_term(&"burn").text)
	Balance.reset("rules")
	check(is_equal_approx(rules.burn_damage, old) and content.get_term(&"burn").text.contains("%s Schaden" % TextFormat.number(old)),
		"Zurückgesetzt")
