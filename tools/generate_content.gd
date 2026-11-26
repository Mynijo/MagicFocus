extends SceneTree
## Erzeugt die Gem-Formen, Gravuren und crafting_content.tres aus den Tabellen unten.
## Werte anpassen und neu erzeugen:
##   godot --headless --path . -s res://tools/generate_content.gd
## Alle Zahlen sind Platzhalter fürs Balancing.

const GEM_DIR := "res://content/gems/"
const ENGRAVING_DIR := "res://content/engravings/"

const MAIN := GemDef.Role.MAIN
const MINOR := GemDef.Role.MINOR
const SPITZ := GemDef.Angle.SPITZ
const GROB := GemDef.Angle.GROB
const ENEMY := EngravingDef.Target.ENEMY
const SELF := EngravingDef.Target.SELF
const BOTH := EngravingDef.Target.BOTH

## Je Rolle und Größe (klein, mittel, groß): Radius, max. neutrale Essenz, max. Essenzen.
## Daraus entstehen alle Kombinationen mit Grob und Spitz,
## z. B. id "nebengem_mittel_spitz", Name "Nebengem mittel Spitz".
const GEM_SIZES := {
	MAIN: [[90.0, 45, 20], [120.0, 60, 25], [165.0, 85, 35]],
	MINOR: [[45.0, 15, 10], [60.0, 25, 15], [90.0, 30, 20]],
}
## Größe des Steins je Rolle (Fokus-Einheiten): Essenz darunter ist verdeckt.
const GEM_BODY := { MAIN: 15.0, MINOR: 10.0 }
const SIZE_IDS := ["klein", "mittel", "gross"]

const FOCI := [&"kleiner_fokus", &"mittlerer_fokus", &"grosser_fokus", &"sehr_grosser_fokus",
	&"stern_fokus", &"tropfen_fokus", &"feuer_fokus", &"neutraler_fokus"]

## Faktor je Element: 1 Essenz zählt so viel wie `factor` neutrale Essenz.
const ELEMENT_FACTORS := { &"fire": 5.0, &"water": 5.0, &"earth": 5.0, &"air": 5.0, &"lightning": 5.0 }

## Alle Elemente (für Gravuren, die jede Essenz zählen, z. B. Magischer Bolzen).
const ALL := [&"fire", &"water", &"earth", &"air", &"lightning"]

## Punkte einer Gravur = neutrale Essenz + Essenz × Faktor ihres Elements.
## `el` = Element-ID oder Liste (z. B. ALL). Nur Essenz dieser Elemente zählt,
## andere gar nicht. Ohne `el` zählt die Gravur nur neutrale Essenz.
## Die Beschreibung bekommt automatisch einen Zusatz, wie viele Punkte welche Essenz bringt.
##
## Regel-Kurzform: [Quelle, pro N, Wert, Menge, (Mindestanzahl), (Höchstwert)]
##   Quelle: "P" = Punkte (neutrale Essenz + gewichtete Essenz), "N" = nur neutrale Essenz,
##           "E" = nur Essenz (gewichtet), sonst Element-ID (nur dieses Element, gewichtet)
## Status entsteht nur aus Essenz des passenden Elements, nie aus neutraler Essenz.
const ENGRAVINGS := [
	# --- Hauptgravuren ---
	{ id = &"magischer_bolzen", name = "Magischer Bolzen", role = MAIN, el = ALL,
		desc = "+1 Schaden pro Punkt",
		rules = [["P", 1, &"damage", 1.0]] },
	{ id = &"freeze", name = "Freeze", role = MAIN, el = [&"water", &"air"],
		desc = "Wandelt je 100 Nass in 1 Eis. +1 Schaden pro Punkt",
		stats = { &"freeze_conversion": 100.0 },
		rules = [["P", 1, &"damage", 1.0]] },
	{ id = &"slow", name = "Slow", role = MAIN, el = &"air",
		desc = "1 Slowed pro 20 Punkte",
		rules = [["P", 20, &"slow", 1.0]] },
	{ id = &"heal", name = "Heal", role = MAIN, el = &"water", target = SELF,
		desc = "5 Heilung pro Punkt",
		rules = [["P", 1, &"heal", 5.0]] },
	{ id = &"schutz", name = "Schutz", role = MAIN, el = &"earth", target = SELF,
		desc = "5 Armor pro Punkt",
		rules = [["P", 1, &"armor", 5.0]] },
	{ id = &"hasted", name = "Hasted", role = MAIN, el = &"air", target = SELF,
		desc = "1 Hasted pro 20 Punkte",
		rules = [["P", 20, &"hasted", 1.0]] },
	{ id = &"leben_reg", name = "Leben-Reg", role = MAIN, el = &"water", target = SELF,
		desc = "1 Leben-Reg pro 2 Punkte",
		rules = [["P", 2, &"life_regen", 1.0]] },
	{ id = &"mana_reg", name = "Mana-Reg", role = MAIN, el = &"lightning", target = SELF,
		desc = "1 Mana-Reg pro 2 Punkte",
		rules = [["P", 2, &"mana_regen", 1.0]] },
	{ id = &"feuerball", name = "Feuerball", role = MAIN, el = &"fire",
		desc = "+1 Schaden pro Punkt, 1 Burn pro 10 Punkte aus Feuer-Essenz",
		rules = [["P", 1, &"damage", 1.0], [&"fire", 10, &"burn", 1.0]] },
	{ id = &"wasser_detonation", name = "Wasser-Detonation", role = MAIN, el = &"water",
		desc = "+1 Schaden pro Punkt, 1 Nass pro 10 Punkte aus Wasser-Essenz",
		rules = [["P", 1, &"damage", 1.0], [&"water", 10, &"wet", 1.0]] },
	{ id = &"luftklinge", name = "Luftklinge", role = MAIN, el = &"air",
		desc = "+1 Schaden pro Punkt, 1 Bleed pro 10 Punkte aus Luft-Essenz",
		rules = [["P", 1, &"damage", 1.0], [&"air", 10, &"bleed", 1.0]] },
	{ id = &"kanone", name = "Kanone", role = MAIN, el = &"earth",
		desc = "+1 Schaden pro Punkt, 1 Armor Break pro 10 Punkte aus Erd-Essenz",
		rules = [["P", 1, &"damage", 1.0], [&"earth", 10, &"armor_break", 1.0]] },
	{ id = &"blitzschlag", name = "Blitzschlag", role = MAIN, el = &"lightning",
		desc = "+1 Schaden pro Punkt, 1 Schock pro 10 Punkte aus Blitz-Essenz",
		rules = [["P", 1, &"damage", 1.0], [&"lightning", 10, &"shock", 1.0]] },
	# Spell-Paket 2026-11-26, Etappe 3
	{ id = &"meteor", name = "Meteor", role = MAIN, el = &"fire",
		desc = "150 Schaden pro volle 50 Punkte",
		rules = [[&"fire", 50, &"damage", 150.0]] },
	{ id = &"fire_rain", name = "Fire Rain", role = MAIN, el = &"fire", target = BOTH,
		desc = "1 Burn pro 5 Punkte",
		rules = [[&"fire", 5, &"burn", 1.0]] },
	{ id = &"permanent_burn", name = "Permanent Burn", role = MAIN, el = &"fire",
		desc = "1 Perma-Burn pro 25 Punkte",
		rules = [[&"fire", 25, &"perma_burn", 1.0]] },
	{ id = &"water_rain", name = "Water Rain", role = MAIN, el = &"water", target = BOTH,
		desc = "1 Nass pro 5 Punkte",
		rules = [[&"water", 5, &"wet", 1.0]] },
	{ id = &"cleanse", name = "Cleanse", role = MAIN, el = &"water", target = SELF,
		desc = "Cleanse. 1 Heilung pro Punkt",
		stats = { &"cleanse": 1.0 },
		rules = [["P", 1, &"heal", 1.0]] },
	{ id = &"bless", name = "Bless", role = MAIN, el = &"water", target = SELF,
		desc = "1 Bless pro 10 Punkte",
		rules = [["P", 10, &"bless", 1.0]] },
	{ id = &"life_rewind", name = "Life Rewind", role = MAIN, el = &"water", target = SELF,
		desc = "Life Rewind ab 50 Punkten (mehr bringt nichts)",
		rules = [[&"water", 50, &"life_rewind", 1.0, 0, 1.0]] },
	{ id = &"dispel", name = "Dispel", role = MAIN, el = &"lightning",
		desc = "1 Dispel, +1 pro 50 Punkte. +1 Schaden pro 2 Punkte",
		stats = { &"dispel": 1.0 },
		rules = [["P", 50, &"dispel", 1.0], ["P", 2, &"damage", 1.0]] },
	{ id = &"thunderstorm", name = "Thunderstorm", role = MAIN, el = &"lightning",
		desc = "30 Schaden pro Treffer; 1 Treffer pro volle 50 Punkte (mindestens 1)",
		stats = { &"damage": 30.0 },
		rules = [[&"lightning", 50, &"hits", 1.0]] },
	{ id = &"bulwark", name = "Bulwark", role = MAIN, el = &"earth", target = SELF,
		desc = "Ab 50 Punkten: 8 Armor pro Punkt",
		rules = [[&"earth", 1, &"armor", 8.0, 50]] },
	{ id = &"damage_reduction", name = "Damage Reduction", role = MAIN, el = &"earth", target = SELF,
		desc = "1 Damage Reduction, +1 pro 50 Punkte",
		stats = { &"damage_reduction": 1.0 },
		rules = [["P", 50, &"damage_reduction", 1.0]] },
	{ id = &"accelerated_burn", name = "Accelerated Burn", role = MAIN, el = [&"fire", &"air"],
		desc = "1 Accelerated Burn pro 10 Punkte aus Luft-Essenz, 1 Burn pro 10 Punkte aus Feuer-Essenz",
		rules = [[&"air", 10, &"accelerated_burn", 1.0], [&"fire", 10, &"burn", 1.0]] },
	{ id = &"mana_absorption", name = "Mana Absorption", role = MAIN, el = [&"water", &"earth"], target = SELF,
		desc = "2 Armor pro Punkt, 1 Mana Absorption pro 10 Punkte aus Essenz",
		rules = [["P", 1, &"armor", 2.0], ["E", 10, &"mana_absorption", 1.0]] },
	# Paket 2
	{ id = &"critical_chance", name = "Critical Chance", role = MAIN, el = &"fire", target = SELF,
		desc = "1 Critical Chance pro 5 Punkte",
		rules = [["P", 5, &"critical_chance", 1.0]] },
	{ id = &"blood_thinner", name = "Blood Thinner", role = MAIN, el = [&"water", &"earth"],
		desc = "1 Blood Thinner pro 10 Punkte",
		rules = [["P", 10, &"blood_thinner", 1.0]] },
	{ id = &"vampire", name = "Vampire", role = MAIN, el = &"water", target = SELF,
		desc = "1 Leben-Reg pro Bleed-Stack des Gegners; +1 pro Stack je 100 Punkte",
		stats = { &"vampire": 1.0 },
		rules = [["P", 100, &"vampire", 1.0]] },
	{ id = &"max_health", name = "Max Health", role = MAIN, el = &"water", target = SELF,
		desc = "1 Max Health pro 2 Punkte",
		rules = [["P", 2, &"max_health", 1.0]] },
	{ id = &"rot", name = "Rot", role = MAIN, el = &"earth",
		desc = "1 Rotten pro Punkt",
		rules = [["P", 1, &"rotten", 1.0]] },
	# --- Nebengravuren ---
	# ID "standard" bleibt (gespeicherte Foki), Name ist Power Transfer
	{ id = &"standard", name = "Power Transfer", role = MINOR, radius = 0.5,
		desc = "Gibt alles Eingesammelte an das Hauptgem weiter (zählt dort nach dessen Gravur). Halber Radius",
		transfer = true, rules = [] },
	{ id = &"crit", name = "Crit", role = MINOR, el = &"fire",
		desc = "+1 Crit pro 2 Punkte",
		rules = [["P", 2, &"crit", 1.0]] },
	{ id = &"mana_reduktion", name = "Mana-Reduktion", role = MINOR, el = &"water",
		desc = "-1 Mana pro 2 Punkte",
		rules = [["P", 2, &"mana_reduction", 1.0]] },
	{ id = &"cast_speed", name = "Cast-Speed", role = MINOR, el = &"air",
		desc = "-1 s Cast-Zeit pro 10 Punkte",
		rules = [["P", 10, &"cast_time_reduction", 1.0]] },
	{ id = &"armor", name = "Armor", role = MINOR, el = &"earth",
		desc = "1 Armor pro 2 Punkte",
		rules = [["P", 2, &"armor", 1.0]] },
	{ id = &"mana_burn", name = "Mana Burn", role = MINOR, el = &"lightning",
		desc = "1 Mana Burn pro 5 Punkte",
		rules = [[&"lightning", 5, &"mana_burn", 1.0]] },
	# Status-Nebengravuren: je Element eine, Status nur aus Essenz des Elements
	{ id = &"status_burn", name = "Burn", role = MINOR, el = &"fire",
		desc = "1 Burn pro 5 Punkte", rules = [[&"fire", 5, &"burn", 1.0]] },
	{ id = &"status_nass", name = "Nass", role = MINOR, el = &"water",
		desc = "1 Nass pro 5 Punkte", rules = [[&"water", 5, &"wet", 1.0]] },
	{ id = &"status_bleed", name = "Bleed", role = MINOR, el = &"air",
		desc = "1 Bleed pro 5 Punkte", rules = [[&"air", 5, &"bleed", 1.0]] },
	{ id = &"status_armor_break", name = "Armor Break", role = MINOR, el = &"earth",
		desc = "1 Armor Break pro 5 Punkte", rules = [[&"earth", 5, &"armor_break", 1.0]] },
	{ id = &"status_schock", name = "Schock", role = MINOR, el = &"lightning",
		desc = "1 Schock pro 5 Punkte", rules = [[&"lightning", 5, &"shock", 1.0]] },
	# Spell-Paket 2026-11-26, Etappe 4
	{ id = &"echo", name = "Echo", role = MINOR, el = ALL,
		desc = "Wiederholt den Spell sofort, 1-mal pro volle 100 Punkte; jedes Mal Mana, keine Cast-Zeit",
		rules = [["E", 100, &"echo", 1.0]] },
	{ id = &"mana_efficiency", name = "Mana Efficiency", role = MINOR, el = [&"water", &"air"],
		desc = "-1 Mana pro Punkt aus Wasser-Essenz. +1 s Cast-Zeit, minus 0,1 s pro 5 Punkte aus Luft-Essenz (bis 0)",
		stats = { &"cast_time_reduction": -1.0 },
		rules = [[&"water", 1, &"mana_reduction", 1.0], [&"air", 5, &"cast_time_reduction", 0.1, 0, 1.0]] },
	{ id = &"quick_cast", name = "Quick Cast", role = MINOR, el = [&"water", &"air"],
		desc = "-1 s Cast-Zeit pro 5 Punkte aus Luft-Essenz. +10 Mana, minus 1 pro 2 Punkte aus Wasser-Essenz (bis 0)",
		stats = { &"mana_reduction": -10.0 },
		rules = [[&"air", 5, &"cast_time_reduction", 1.0], [&"water", 2, &"mana_reduction", 1.0, 0, 10.0]] },
	{ id = &"radius_expansion", name = "Radius Expansion", role = MINOR, el = &"earth",
		desc = "+1 Radius des Hauptgems pro 2 Punkte",
		rules = [[&"earth", 2, &"radius_bonus", 1.0]] },
	{ id = &"thorns", name = "Thorns", role = MINOR, el = &"earth",
		desc = "1 Thorns pro 5 Punkte", rules = [[&"earth", 5, &"thorns", 1.0]] },
	# Paket 2
	{ id = &"neben_cleanse", name = "Cleanse", role = MINOR, el = &"water",
		desc = "Cleanse",
		stats = { &"cleanse": 1.0 }, rules = [] },
	{ id = &"regeneration", name = "Regeneration", role = MINOR, el = &"water",
		desc = "1 Leben-Reg pro 5 Punkte", rules = [[&"water", 5, &"life_regen", 1.0]] },
	{ id = &"neben_dispel", name = "Dispel", role = MINOR, el = &"lightning",
		desc = "1 Dispel pro 25 Punkte",
		rules = [[&"lightning", 25, &"dispel", 1.0]] },
	{ id = &"critical_damage", name = "Critical Damage", role = MINOR, el = &"lightning",
		desc = "+10 % Crit-Schaden pro 5 Punkte", rules = [[&"lightning", 5, &"crit_damage", 10.0]] },
	{ id = &"status_slow", name = "Slow", role = MINOR, el = &"air",
		desc = "1 Slowed pro 5 Punkte", rules = [[&"air", 5, &"slow", 1.0]] },
	# Etappe 5: Multiplikator
	{ id = &"multiplikator", name = "Multiplikator", role = MINOR, radius = 0.8, inner = 0.3, max_size = GemDef.Size.MITTEL,
		desc = "Wie Power Transfer, aber Radius ×0,8; im inneren Ring (Stein + 0,3 × Radius) zählt alles doppelt. Nur klein und mittel",
		transfer = true, rules = [] },
]


## Begriffe für die Tooltips: ID -> [Titel, weitere Wörter, Text]. Leerer Titel = Name aus
## `Status.NAMES`. Bei Status ist die ID die Status-ID. `{name}` im Text wird durch den
## Wert aus content/combat_rules.tres ersetzt (siehe `_rule_values`).
const TERMS := {
	&"burn": ["", [], "Debuff. {burn_damage} Schaden pro Stack und Sekunde, danach -1 Stack. Hebt sich 1 : 1 mit Nass auf; mit Bleed entsteht Cauterized."],
	&"bleed": ["", [], "Debuff. {bleed_damage} Schaden pro Stack und Sekunde, danach -1 Stack. Mit Burn entsteht Cauterized."],
	&"wet": ["", [], "Debuff. +{wet_shock_bonus} Schock-Schaden pro Stack. Hebt sich 1 : 1 mit Burn auf. Freeze wandelt Nass in Eis."],
	&"shock": ["", [], "Debuff. Gibt der Träger Mana aus: 1 Schaden und -1 Stack pro Mana (höchstens alle Stacks). Nass verstärkt den Schaden."],
	&"slow": ["", ["Slow"], "Debuff. Nächster Cast +{slowed_seconds} s pro Stack; dabei werden alle Stacks verbraucht. Höchstens {max_slowed_hasted} Stacks, hebt sich 1 : 1 mit Hasted auf."],
	&"mana_burn": ["", [], "Debuff. Senkt die Mana-Reg um {mana_burn_per_stack} pro Stack und Sekunde; die genutzten Stacks werden verbraucht."],
	&"ice": ["", [], "Debuff. Betäubt: kein neuer Cast, ein laufender pausiert. -1 Stack pro Sekunde."],
	&"perma_burn": ["", [], "Debuff. Erzeugt pro Stack {perma_burn_rate} Burn pro Sekunde. Baut sich nicht ab, nur Cleanse entfernt ihn."],
	&"accelerated_burn": ["", [], "Debuff. Burn tickt zweimal pro Sekunde: gleicher Schaden in halber Zeit. -1 Stack pro Sekunde."],
	&"blood_thinner": ["", [], "Debuff. Bleed tickt zweimal pro Sekunde: gleicher Schaden in halber Zeit. -1 Stack pro Sekunde."],
	&"cauterized": ["", [], "Debuff. Entsteht aus je 1 Bleed und 1 Burn. Verhindert die nächste Heilung und verliert dabei 1 Stack."],
	&"rotten": ["", [], "Debuff. -{rotten_per_stack} maximales Leben pro Stack; das Leben sinkt mit. Baut sich nicht ab."],
	&"armor": ["", [], "Buff. Fängt 1 Schaden pro Stack ab und verliert dabei den Stack. Armor Break entfernt ihn."],
	&"hasted": ["", [], "Buff. Nächster Cast -{hasted_seconds} s pro Stack; dabei werden alle Stacks verbraucht. Höchstens {max_slowed_hasted} Stacks, hebt sich 1 : 1 mit Slowed auf."],
	&"life_regen": ["", [], "Buff. 1 Heilung pro Stack und Sekunde, danach -1 Stack."],
	&"mana_regen": ["", [], "Buff. +1 Mana pro Stack und Sekunde (zu den {mana_regen} Grund-Mana), danach -1 Stack."],
	&"bless": ["", [], "Buff. Jede erhaltene Heilung +{bless_heal} pro Stack; verbraucht 1 Stack."],
	&"thorns": ["", [], "Buff. Trifft ein gegnerischer Spell: {thorns_damage} Schaden pro Stack an den Angreifer; verbraucht 1 Stack."],
	&"mana_absorption": ["", [], "Buff. Trifft ein gegnerischer Spell: +{mana_absorption_mana} Mana pro Stack; verbraucht 1 Stack."],
	&"damage_reduction": ["", [], "Buff. Der nächste gegnerische Spell macht nur {damage_reduction_percent} % Schaden (alle Treffer); verbraucht 1 Stack."],
	&"life_rewind": ["", [], "Buff. Merkt sich das Leben; nach {life_rewind_seconds} s wird es darauf gesetzt, auch nach unten. Tod ist endgültig."],
	&"critical_chance": ["", [], "Buff. +1 % Crit-Chance pro Stack. Beim nächsten Crit werden alle Stacks verbraucht."],
	&"max_health": ["", [], "Buff. +{max_health_per_stack} maximales Leben pro Stack (nicht das aktuelle Leben). Baut sich nicht ab."],
	&"crit": ["Crit", [], "Spell-Wert. 1 Crit = 1 % Chance pro Treffer auf {crit_percent} % Schaden."],
	&"armor_break": ["Armor Break", [], "Spell-Wert. Entfernt beim Treffer {armor_break_ratio} Armor pro Stack."],
	&"cleanse": ["Cleanse", [], "Spell-Wert. Entfernt alle Debuffs des Ziels."],
	&"dispel": ["Dispel", [], "Spell-Wert. Pro Stack wird ein Buff des Ziels ganz entfernt, der mit den meisten Stacks zuerst."],
	&"points": ["Punkte", [], "Grundlage jeder Gravur: neutrale Essenz zählt 1, eine Essenz ihren Faktor, aber nur für Gravuren mit ihrem Element. Sonst zählt sie nichts."],
	&"spitz": ["Spitz", [], "Gem-Form: sammelt im Innenwinkel, alles Eingesammelte zählt doppelt. Grob sammelt im Außenwinkel einfach."],
}
## Symbol eines Begriffs: Gravur-Symbol (Dateiname ohne "engraving_").
const TERM_ICONS := {
	&"burn": "status_burn", &"bleed": "status_bleed", &"wet": "status_nass", &"shock": "status_schock",
	&"slow": "slow", &"mana_burn": "mana_burn", &"ice": "freeze", &"perma_burn": "permanent_burn",
	&"accelerated_burn": "accelerated_burn", &"blood_thinner": "blood_thinner", &"cauterized": "cauterized",
	&"rotten": "rot", &"armor": "armor", &"hasted": "hasted", &"life_regen": "leben_reg", &"mana_regen": "mana_reg",
	&"bless": "bless", &"thorns": "thorns", &"mana_absorption": "mana_absorption", &"damage_reduction": "damage_reduction",
	&"life_rewind": "life_rewind", &"critical_chance": "critical_chance", &"max_health": "max_health",
	&"crit": "crit", &"armor_break": "status_armor_break", &"cleanse": "cleanse", &"dispel": "dispel",
}



func _init() -> void:
	DirAccess.make_dir_recursive_absolute(GEM_DIR)
	DirAccess.make_dir_recursive_absolute(ENGRAVING_DIR)

	var content := CraftingContent.new()
	for id in [&"fire", &"water", &"earth", &"air", &"lightning"]:
		var element: ElementDef = load("res://content/elements/%s.tres" % id)
		element.factor = ELEMENT_FACTORS[id]
		element.dot_texture = load("res://assets/sprites/essenz_%s.png" % id)
		element.icon = load("res://assets/sprites/element_%s.png" % id)
		# neu speichern, damit entfernte Felder aus der Datei verschwinden
		_save(element, "res://content/elements/%s.tres" % id)
		content.elements.append(load("res://content/elements/%s.tres" % id))

	for role in [MAIN, MINOR]:
		var role_name := "Hauptgem" if role == MAIN else "Nebengem"
		for size in 3:
			for angle in [GROB, SPITZ]:
				var row: Array = GEM_SIZES[role][size]
				var gem := GemDef.new()
				var angle_name := "Spitz" if angle == SPITZ else "Grob"
				gem.id = StringName("%s_%s_%s" % [role_name.to_lower(), SIZE_IDS[size], angle_name.to_lower()])
				gem.display_name = "%s %s %s" % [role_name, GemDef.SIZE_NAMES[size], angle_name]
				gem.role = role
				gem.size = size
				gem.angle = angle
				gem.radius = row[0]
				gem.max_base = row[1]
				gem.max_element = row[2]
				gem.body_radius = GEM_BODY[role]
				var path := GEM_DIR + String(gem.id) + ".tres"
				_save(gem, path)
				content.gems.append(load(path))

	for data: Dictionary in ENGRAVINGS:
		var engraving := EngravingDef.new()
		engraving.id = data.id
		engraving.display_name = data.name
		engraving.role = data.role
		engraving.element_ids = _element_ids(data)
		# Symbol, falls vorhanden (aufbereitet mit tools/prepare_assets.gd)
		var icon_path := "res://assets/sprites/engraving_%s.png" % data.id
		if ResourceLoader.exists(icon_path):
			engraving.icon = load(icon_path)
		engraving.description = data.desc + _target_text(data) + _points_text(data, content.elements)
		engraving.base_stats = data.get("stats", {})
		engraving.transfer_to_main = data.get("transfer", false)
		engraving.radius_factor = data.get("radius", 1.0)
		engraving.inner_radius_factor = data.get("inner", 0.0)
		engraving.max_size = data.get("max_size", GemDef.Size.GROSS)
		engraving.target = data.get("target", ENEMY)
		for r: Array in data.rules:
			engraving.rules.append(_rule(r))
		var path := ENGRAVING_DIR + String(engraving.id) + ".tres"
		_save(engraving, path)
		content.engravings.append(load(path))

	for id in FOCI:
		content.foci.append(load("res://content/foci/%s.tres" % id))
	_build_glossary(content)
	# Kampfregeln nur anlegen, nie überschreiben (Werte werden von Hand im Editor angepasst)
	if not ResourceLoader.exists("res://content/combat_rules.tres"):
		_save(CombatRules.new(), "res://content/combat_rules.tres")
	_save(content, "res://content/crafting_content.tres")
	print("Inhalte erzeugt: %d Gems, %d Gravuren" % [content.gems.size(), content.engravings.size()])
	quit()


func _rule(r: Array) -> ScalingRule:
	var rule := ScalingRule.new()
	match r[0]:
		"P":
			rule.source = ScalingRule.Source.POINTS
		"N":
			rule.source = ScalingRule.Source.BASE
		"E":
			rule.source = ScalingRule.Source.ANY_ELEMENT
		_:
			rule.source = ScalingRule.Source.ELEMENT
			rule.element_id = r[0]
	rule.per_n = r[1]
	rule.stat = r[2]
	rule.amount = r[3]
	if r.size() > 4:
		rule.min_count = r[4]
	if r.size() > 5:
		rule.cap = r[5]
	return rule


func _save(resource: Resource, path: String) -> void:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		push_error("Speichern fehlgeschlagen: %s (%d)" % [path, error])


## `el` aus der Tabelle als Liste: einzelne ID, Liste oder nichts.
func _element_ids(data: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	var value: Variant = data.get("el", [])
	if value is StringName:
		ids.append(value)
	else:
		for id: StringName in value:
			ids.append(id)
	return ids



## Zusatz für Hauptgravuren: wen der Spell trifft.
func _target_text(data: Dictionary) -> String:
	if data.role != MAIN:
		return ""
	return ". Ziel: " + ["Gegner", "selbst", "beide"][data.get("target", ENEMY)]


## Zusatz zur Beschreibung: welche Essenz wie viele Punkte bringt (fehlende zählen 0),
## z. B. ". Punkte: neutrale Essenz ×1, Feuer-Essenz ×5".
func _points_text(data: Dictionary, elements: Array[ElementDef]) -> String:
	if data.rules.is_empty():
		return ""
	var parts := PackedStringArray()
	for r: Array in data.rules:
		if (r[0] == "P" or r[0] == "N") and parts.is_empty():
			parts.append("neutrale Essenz ×1")
	var ids := _element_ids(data)
	if ids.size() == elements.size():
		parts.append("jede Essenz ×%s" % TextFormat.number(elements[0].factor))
	else:
		for element in elements:
			if ids.has(element.id):
				parts.append("%s-Essenz ×%s" % [_essence_word(element), TextFormat.number(element.factor)])
	return ". Punkte: " + ", ".join(parts)


## "Feuer", "Erd" (für "Erd-Essenz"), "Luft", ...
static func _essence_word(element: ElementDef) -> String:
	return element.display_name.trim_suffix("e")


## Werte aus den Kampfregeln für die Platzhalter in TERMS.
func _rule_values() -> Dictionary:
	var rules: CombatRules = load("res://content/combat_rules.tres")
	var values := {}
	for property in rules.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = rules.get(property.name)
			if value is float or value is int:
				values[property.name] = TextFormat.number(value)
	values["damage_reduction_percent"] = TextFormat.number(rules.damage_reduction_factor * 100.0)
	values["crit_percent"] = TextFormat.number(rules.crit_multiplier * 100.0)
	return values


## Begriffe: Elemente (aus Faktor und Gravuren), Buff und Debuff (aus `Status`), TERMS.
func _build_glossary(content: CraftingContent) -> void:
	for element in content.elements:
		content.glossary.append(_element_term(element, content))
	content.glossary.append(_group_term(&"debuff", "Debuff", Status.DEBUFFS, "Schadet dem Träger; Cleanse entfernt alle"))
	content.glossary.append(_group_term(&"buff", "Buff", Status.BUFFS, "Hilft dem Träger; Dispel entfernt sie"))
	var values := _rule_values()
	for id: StringName in TERMS:
		var row: Array = TERMS[id]
		var term := GlossaryTerm.new()
		term.id = id
		term.title = row[0] if row[0] != "" else Status.name_of(id)
		term.words = PackedStringArray([term.title] + row[1])
		var icon_path := "res://assets/sprites/engraving_%s.png" % TERM_ICONS.get(id, "")
		if ResourceLoader.exists(icon_path):
			term.icon = load(icon_path)
		term.text = String(row[2]).format(values)
		content.glossary.append(term)


## Element: Punkte, erzeugte Effekte und Gravuren (aus den Gravuren berechnet).
func _element_term(element: ElementDef, content: CraftingContent) -> GlossaryTerm:
	var term := GlossaryTerm.new()
	term.id = element.id
	term.title = element.display_name
	term.icon = element.icon
	term.icon_color = element.color
	term.words = PackedStringArray([element.display_name, element.display_name + "-Essenz"])
	if element.display_name != _essence_word(element):
		term.words.append(_essence_word(element) + "-Essenz")  # "Erd-Essenz"
	var engravings := PackedStringArray()
	var effects := PackedStringArray()
	for engraving in content.engravings:
		if not engraving.element_ids.has(element.id) or engraving.element_ids.size() == content.elements.size():
			continue
		if not engravings.has(engraving.display_name):
			engravings.append(engraving.display_name)
		for stat: StringName in _stats_of(engraving):
			var title := _term_title(stat)
			if title != "" and not effects.has(title):
				effects.append(title)
	term.text = "Element. 1 %s-Essenz = %s Punkte, nur für Gravuren mit %s.\nErzeugt: %s.\nGravuren: [nolink]%s[/nolink]." % [
		_essence_word(element), TextFormat.number(element.factor), element.display_name,
		", ".join(effects), ", ".join(engravings)]
	return term


func _group_term(id: StringName, title: String, statuses: Array[StringName], text: String) -> GlossaryTerm:
	var term := GlossaryTerm.new()
	term.id = id
	term.title = title
	term.words = PackedStringArray([title, title + "s"])
	var names := PackedStringArray()
	for status in statuses:
		names.append(Status.name_of(status))
	term.text = "%s: %s." % [text, ", ".join(names)]
	return term


## Alle Werte, die eine Gravur erzeugt (Regeln und feste Werte).
static func _stats_of(engraving: EngravingDef) -> Array[StringName]:
	var stats: Array[StringName] = []
	for rule in engraving.rules:
		stats.append(rule.stat)
	for stat: StringName in engraving.base_stats:
		stats.append(stat)
	return stats


## Titel des Begriffs zu einem Spell-Wert ("" ohne Begriff).
static func _term_title(stat: StringName) -> String:
	if Status.NAMES.has(stat):
		return Status.name_of(stat)
	if TERMS.has(stat):
		return TERMS[stat][0]
	return ""
