extends TestSuite
## Kampf: Schaden, Status, Ablauf, Bedingungen.


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
	var c := duel([make_spell({ &"damage": 1 }, 1.0, 40.0)], [])
	c.step()
	check(c.mages[0].casting == 0 and is_equal_approx(c.mages[0].mana, rules.start_mana - 40.0), "Cast beginnt, Mana bezahlt")
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
	a.hp = c.rules.max_hp * 0.3
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
	c.mages[0].hp = 60.0
	c._apply_spell(0, 0)
	c.mages[0].hp = 120.0
	for k in int(rules.life_rewind_seconds):
		c._pulse(0)
	check(is_equal_approx(c.mages[0].hp, 60.0) and c.mages[0].stacks(&"life_rewind") == 0, "Life Rewind setzt auf 60 zurück, HP %s" % c.mages[0].hp)


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
	c._remove_all(1, Status.DEBUFFS, "Cleanse")
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
