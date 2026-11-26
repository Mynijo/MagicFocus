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
## Regel-Kurzform: [Quelle, pro N, Wert, Menge]
##   Quelle: "P" = Punkte (neutrale Essenz + gewichtete Essenz), "N" = nur neutrale Essenz,
##           "E" = nur Essenz (gewichtet), sonst Element-ID (nur dieses Element, gewichtet)
## Status entsteht nur aus Essenz des passenden Elements, nie aus neutraler Essenz.
const ENGRAVINGS := [
	# --- Hauptgravuren ---
	{ id = &"magischer_bolzen", name = "Magischer Bolzen", role = MAIN, el = ALL,
		desc = "+1 Schaden pro Punkt",
		rules = [["P", 1, &"damage", 1.0]] },
	{ id = &"freeze", name = "Freeze", role = MAIN, el = [&"water", &"air"],
		desc = "Wandelt 100 Nass in 1 Eis. +1 Schaden pro Punkt",
		stats = { &"freeze_conversion": 100.0 },
		rules = [["P", 1, &"damage", 1.0]] },
	{ id = &"slow", name = "Slow", role = MAIN, el = &"air",
		desc = "1 Slow pro 20 Punkte",
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
	# --- Nebengravuren ---
	# ID "standard" bleibt (gespeicherte Foki), Name ist Power Transfer
	{ id = &"standard", name = "Power Transfer", role = MINOR, radius = 0.5,
		desc = "Gibt seine neutrale Essenz und Essenzen an das Hauptgem weiter. Dort zählen sie nach den Regeln des Hauptgems. Das Gem sammelt nur mit halbem Radius",
		transfer = true, rules = [] },
	{ id = &"crit", name = "Crit", role = MINOR, el = &"fire",
		desc = "+1 % Crit-Chance pro 2 Punkte. Ein Crit macht 200 % Schaden",
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
]


## Status-Begriffe für die Tooltips (Kampfregeln aus der Tabelle des Nutzers, M6).
## [id, Titel, Wörter im Text, Erklärung]. Begriffe in der Erklärung werden selbst
## wieder zu Tooltips. X = Wert kommt mit dem Kampfsystem.
const STATUS_TERMS := [
	[&"bleed", "Bleed", ["Bleed"],
		"Verursacht pro Stack X Schaden pro Sekunde. Verliert 1 Stack pro Sekunde. Entsteht aus Luft-Essenz."],
	[&"slowed", "Slowed", ["Slowed", "Slow"],
		"Verlängert die Cast-Zeit des Gegners um X Sekunden. Verliert 1 Stack pro Sekunde, höchstens 10 Stacks. Slowed und Hasted heben sich 1 : 1 auf."],
	[&"hasted", "Hasted", ["Hasted"],
		"Verkürzt die eigene Cast-Zeit um X Sekunden. Verliert 1 Stack pro Sekunde, höchstens 10 Stacks. Hasted und Slowed heben sich 1 : 1 auf."],
	[&"mana_burn", "Mana Burn", ["Mana Burn"],
		"Senkt die Mana-Reg des Gegners um X pro Sekunde. Verliert 1 Stack pro gesenkter Mana-Reg. Entsteht aus Blitz-Essenz."],
	[&"armor", "Armor", ["Armor"],
		"Verhindert X Schaden. Verliert 1 Stack pro verhindertem Schaden. Armor Break hebt Armor im Verhältnis 1 : 5 auf."],
	[&"schock", "Schock", ["Schock"],
		"Verursacht 1 Schaden pro Mana, das der Gegner verbraucht (höchstens so viel wie Stacks). Verliert 1 Stack pro verbrauchtem Mana. Nass verstärkt den Schaden. Entsteht aus Blitz-Essenz."],
	[&"nass", "Nass", ["Nass"],
		"Erhöht den Schaden von Schock um X. Nass und Burn heben sich 1 : 1 auf. Freeze wandelt 100 Nass in 1 Eis. Entsteht aus Wasser-Essenz."],
	[&"eis", "Eis", ["Eis"],
		"Betäubt X Sekunden: Der Gegner kann nicht zaubern. Verliert 1 Stack pro Sekunde. Entsteht, wenn Freeze Nass umwandelt."],
	[&"burn", "Burn", ["Burn"],
		"Verursacht X Schaden pro Sekunde. Verliert 1 Stack pro Sekunde. Nass und Burn heben sich 1 : 1 auf. Entsteht aus Feuer-Essenz."],
	[&"leben_reg", "Leben-Reg", ["Leben-Reg"],
		"Heilt 1 Leben pro Sekunde und Stack. Verliert 1 Stack pro Sekunde. Entsteht aus Wasser-Essenz."],
	[&"mana_reg", "Mana-Reg", ["Mana-Reg"],
		"Gibt 1 Mana pro Sekunde und Stack. Verliert 1 Stack pro Sekunde. Mana Burn senkt sie. Entsteht aus Blitz-Essenz."],
	[&"armor_break", "Armor Break", ["Armor Break"],
		"Hebt Armor im Verhältnis 1 : 5 auf. Entsteht aus Erd-Essenz."],
	[&"crit", "Crit", ["Crit"],
		"1 Crit = 1 % Chance auf einen kritischen Treffer. Ein kritischer Treffer macht 200 % Schaden. Entsteht aus Feuer-Essenz."],
	[&"perma_burn", "Perma-Burn", ["Perma-Burn"],
		"Debuff. Erzeugt pro Stack jede Sekunde Burn. Baut sich nicht ab; nur Cleanse entfernt ihn."],
	[&"accelerated_burn", "Accelerated Burn", ["Accelerated Burn"],
		"Debuff. Solange er wirkt, tickt Burn zweimal pro Sekunde: gleicher Gesamtschaden in der halben Zeit. Verliert 1 Stack pro Sekunde."],
	[&"bless", "Bless", ["Bless"],
		"Buff. Jede erhaltene Heilung (auch Leben-Reg) heilt pro Stack X mehr und verbraucht 1 Stack."],
	[&"thorns", "Thorns", ["Thorns"],
		"Buff. Wird der Träger von einem Spell getroffen, erhält der Angreifer pro Stack X Schaden; verbraucht 1 Stack pro Treffer."],
	[&"mana_absorption", "Mana Absorption", ["Mana Absorption"],
		"Buff. Wird der Träger von einem Spell getroffen, erhält er pro Stack X Mana; verbraucht 1 Stack pro Treffer."],
	[&"damage_reduction", "Damage Reduction", ["Damage Reduction"],
		"Buff. Halbiert den Schaden des nächsten gegnerischen Spells (alle Treffer); 1 Stack pro Spell."],
	[&"life_rewind", "Life Rewind", ["Life Rewind"],
		"Buff. Speichert das aktuelle Leben; nach 10 Sekunden wird das Leben auf diesen Wert gesetzt, auch nach unten. Tödlicher Schaden tötet trotzdem."],
	[&"cleanse", "Cleanse", ["Cleanse"],
		"Entfernt alle Debuffs vom Ziel: Burn, Bleed, Nass, Schock, Slowed, Mana Burn, Eis, Perma-Burn, Accelerated Burn."],
	[&"dispel", "Dispel", ["Dispel"],
		"Entfernt alle Buffs vom Ziel: Armor, Hasted, Leben-Reg, Mana-Reg, Bless, Thorns, Mana Absorption, Damage Reduction, Life Rewind."],
]
## Symbol je Status: Gravur-Symbol, das ihn erzeugt (Dateiname ohne "engraving_").
const STATUS_ICONS := {
	&"bleed": "status_bleed", &"slowed": "slow", &"hasted": "hasted", &"mana_burn": "mana_burn",
	&"armor": "armor", &"schock": "status_schock", &"nass": "status_nass", &"eis": "freeze",
	&"burn": "status_burn", &"leben_reg": "leben_reg", &"mana_reg": "mana_reg",
	&"armor_break": "status_armor_break", &"crit": "crit",
}
## Welche Status ein Element erzeugt (für die Element-Erklärung).
const ELEMENT_STATUS := {
	&"fire": ["Burn", "Crit"], &"water": ["Nass", "Leben-Reg"], &"earth": ["Armor", "Armor Break"],
	&"air": ["Bleed", "Slowed", "Hasted"], &"lightning": ["Schock", "Mana Burn", "Mana-Reg"],
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
		engraving.description = data.desc + _points_text(data, content.elements)
		engraving.base_stats = data.get("stats", {})
		engraving.transfer_to_main = data.get("transfer", false)
		engraving.radius_factor = data.get("radius", 1.0)
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
	return rule


func _save(resource: Resource, path: String) -> void:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		push_error("Speichern fehlgeschlagen: %s (%d)" % [path, error])


## Zusatz zur Beschreibung: wie viele Punkte welche Essenz bringt.
## Neutrale Essenz wird nur genannt, wenn eine Regel sie zählt.
func _points_text(data: Dictionary, elements: Array[ElementDef]) -> String:
	if data.rules.is_empty():
		return ""
	var counts_base := false
	for r: Array in data.rules:
		counts_base = counts_base or r[0] == "P" or r[0] == "N"
	var parts := PackedStringArray()
	if counts_base:
		parts.append("neutrale Essenz 1")
	var ids := _element_ids(data)
	for element in elements:
		if ids.has(element.id):
			parts.append("%s-Essenz %s" % [element.display_name, _number(element.factor)])
	if ids.is_empty():
		parts.append("Essenz 0")
	elif ids.size() < elements.size():
		parts.append("andere Essenz 0")
	if not counts_base:
		parts.append("neutrale Essenz 0")
	return ". Punkte: " + ", ".join(parts)


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


func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else str(value)


## Begriffe: Status aus STATUS_TERMS, Elemente aus Faktor und Gravuren erzeugt.
func _build_glossary(content: CraftingContent) -> void:
	for element in content.elements:
		var term := GlossaryTerm.new()
		term.id = element.id
		term.title = element.display_name
		term.icon = element.icon
		term.icon_color = element.color
		var words := PackedStringArray([element.display_name, element.display_name + "-Essenz"])
		if not words.has(element.display_name.trim_suffix("e") + "-Essenz"):
			words.append(element.display_name.trim_suffix("e") + "-Essenz")  # "Erd-Essenz"
		term.words = words
		var engravings := PackedStringArray()
		for engraving in content.engravings:
			if engraving.element_ids.has(element.id) and engraving.element_ids.size() < content.elements.size():
				engravings.append(engraving.display_name)
		term.text = "Ein Element. Eine %s-Essenz zählt %s Punkte für Gravuren mit diesem Element, für andere Gravuren nichts (außer Magischer Bolzen). Erzeugt: %s.\nGravuren: %s." % [
			element.display_name, _number(element.factor), ", ".join(ELEMENT_STATUS.get(element.id, [])), ", ".join(engravings)]
		content.glossary.append(term)
	for row: Array in STATUS_TERMS:
		var term := GlossaryTerm.new()
		term.id = row[0]
		term.title = row[1]
		term.words = PackedStringArray(row[2])
		var icon_path := "res://assets/sprites/engraving_%s.png" % STATUS_ICONS.get(row[0], "")
		if ResourceLoader.exists(icon_path):
			term.icon = load(icon_path)
		term.text = row[3] + "\n(Kampfregel, wirkt ab dem Auto-Battler.)"
		content.glossary.append(term)
