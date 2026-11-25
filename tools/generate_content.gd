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

## id, Name, Rolle, Radius, Winkel, max. neutrale Essenz, max. Essenzen
const GEMS := [
	[&"hauptgem_grob", "Hauptgem Grob", MAIN, 160.0, GROB, 40, 25],
	[&"hauptgem_spitz", "Hauptgem Spitz", MAIN, 160.0, SPITZ, 40, 25],
	[&"nebengem_klein_spitz", "Nebengem klein Spitz", MINOR, 60.0, SPITZ, 10, 10],
	[&"nebengem_klein_grob", "Nebengem klein Grob", MINOR, 60.0, GROB, 10, 10],
	[&"nebengem_mittel_spitz", "Nebengem mittel Spitz", MINOR, 80.0, SPITZ, 15, 15],
	[&"nebengem_mittel_grob", "Nebengem mittel Grob", MINOR, 80.0, GROB, 15, 15],
	[&"nebengem_gross_spitz", "Nebengem groß Spitz", MINOR, 120.0, SPITZ, 20, 20],
	[&"nebengem_gross_grob", "Nebengem groß Grob", MINOR, 120.0, GROB, 20, 20],
]

const FOCI := [&"kleiner_fokus", &"mittlerer_fokus", &"grosser_fokus", &"sehr_grosser_fokus",
	&"stern_fokus", &"tropfen_fokus", &"feuer_fokus", &"neutraler_fokus"]

## Regel-Kurzform: [Quelle, Element, pro N, Wert, Menge]
##   Quelle: "N" = neutrale Essenz, "E" = alle Essenzen, sonst Element-ID
const ENGRAVINGS := [
	# --- Hauptgravuren ---
	{ id = &"magischer_bolzen", name = "Magischer Bolzen", role = MAIN,
		desc = "+1 Schaden pro neutraler Essenz, +2 Schaden pro Essenz",
		rules = [["N", 1, &"damage", 1.0], ["E", 1, &"damage", 2.0]] },
	{ id = &"freeze", name = "Freeze", role = MAIN,
		desc = "Wandelt 100 Nass in 1 Eis. +1 Schaden pro neutraler Essenz",
		stats = { &"freeze_conversion": 100.0 },
		rules = [["N", 1, &"damage", 1.0]] },
	{ id = &"slow", name = "Slow", role = MAIN,
		desc = "1 Slow pro 10 Luft-Essenzen",
		rules = [[&"air", 10, &"slow", 1.0]] },
	{ id = &"heal", name = "Heal", role = MAIN,
		desc = "10 Heilung pro Essenz, zusätzlich 20 pro Wasser-Essenz",
		rules = [["E", 1, &"heal", 10.0], [&"water", 1, &"heal", 20.0]] },
	{ id = &"schutz", name = "Schutz", role = MAIN,
		desc = "10 Armor pro Essenz, zusätzlich 20 pro Erd-Essenz",
		rules = [["E", 1, &"armor", 10.0], [&"earth", 1, &"armor", 20.0]] },
	{ id = &"feuerball", name = "Feuerball", role = MAIN,
		desc = "+1 Schaden pro neutraler Essenz, 1 Burn pro 2 Feuer-Essenzen",
		rules = [["N", 1, &"damage", 1.0], [&"fire", 2, &"burn", 1.0]] },
	{ id = &"wasser_detonation", name = "Wasser-Detonation", role = MAIN,
		desc = "+1 Schaden pro neutraler Essenz, 1 Nass pro 2 Wasser-Essenzen",
		rules = [["N", 1, &"damage", 1.0], [&"water", 2, &"wet", 1.0]] },
	{ id = &"luftklinge", name = "Luftklinge", role = MAIN,
		desc = "+1 Schaden pro neutraler Essenz, 1 Bleed pro 2 Luft-Essenzen",
		rules = [["N", 1, &"damage", 1.0], [&"air", 2, &"bleed", 1.0]] },
	{ id = &"kanone", name = "Kanone", role = MAIN,
		desc = "+1 Schaden pro neutraler Essenz, 1 Armor Break pro 2 Erd-Essenzen",
		rules = [["N", 1, &"damage", 1.0], [&"earth", 2, &"armor_break", 1.0]] },
	{ id = &"blitzschlag", name = "Blitzschlag", role = MAIN,
		desc = "+1 Schaden pro neutraler Essenz, 1 Schock pro 2 Blitz-Essenzen",
		rules = [["N", 1, &"damage", 1.0], [&"lightning", 2, &"shock", 1.0]] },
	# --- Nebengravuren ---
	{ id = &"standard", name = "Standard", role = MINOR,
		desc = "Gibt seine neutrale Essenz und Essenzen an das Hauptgem weiter",
		transfer = true, rules = [] },
	{ id = &"crit", name = "Crit", role = MINOR,
		desc = "+1 Crit pro Feuer-Essenz",
		rules = [[&"fire", 1, &"crit", 1.0]] },
	{ id = &"mana_reduktion", name = "Mana-Reduktion", role = MINOR,
		desc = "-1 Mana pro Wasser-Essenz",
		rules = [[&"water", 1, &"mana_reduction", 1.0]] },
	{ id = &"cast_speed", name = "Cast-Speed", role = MINOR,
		desc = "-1 s Cast-Zeit pro 5 Luft-Essenzen",
		rules = [[&"air", 5, &"cast_time_reduction", 1.0]] },
	{ id = &"armor", name = "Armor", role = MINOR,
		desc = "1 Armor pro Essenz, zusätzlich 5 pro Erd-Essenz",
		rules = [["E", 1, &"armor", 1.0], [&"earth", 1, &"armor", 5.0]] },
	{ id = &"status", name = "Status", role = MINOR,
		desc = "1 Status pro Essenz: Feuer → Burn, Wasser → Nass, Luft → Bleed, Erde → Armor Break, Blitz → Schock",
		rules = [[&"fire", 1, &"burn", 1.0], [&"water", 1, &"wet", 1.0], [&"air", 1, &"bleed", 1.0],
			[&"earth", 1, &"armor_break", 1.0], [&"lightning", 1, &"shock", 1.0]] },
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(GEM_DIR)
	DirAccess.make_dir_recursive_absolute(ENGRAVING_DIR)

	var content := CraftingContent.new()
	for id in [&"fire", &"water", &"earth", &"air", &"lightning"]:
		var element: ElementDef = load("res://content/elements/%s.tres" % id)
		# neu speichern, damit entfernte Felder aus der Datei verschwinden
		_save(element, "res://content/elements/%s.tres" % id)
		content.elements.append(load("res://content/elements/%s.tres" % id))

	for row in GEMS:
		var gem := GemDef.new()
		gem.id = row[0]
		gem.display_name = row[1]
		gem.role = row[2]
		gem.radius = row[3]
		gem.angle = row[4]
		gem.max_base = row[5]
		gem.max_element = row[6]
		var path := GEM_DIR + String(gem.id) + ".tres"
		_save(gem, path)
		content.gems.append(load(path))

	for data: Dictionary in ENGRAVINGS:
		var engraving := EngravingDef.new()
		engraving.id = data.id
		engraving.display_name = data.name
		engraving.role = data.role
		engraving.description = data.desc
		engraving.base_stats = data.get("stats", {})
		engraving.transfer_to_main = data.get("transfer", false)
		for r: Array in data.rules:
			engraving.rules.append(_rule(r))
		var path := ENGRAVING_DIR + String(engraving.id) + ".tres"
		_save(engraving, path)
		content.engravings.append(load(path))

	for id in FOCI:
		content.foci.append(load("res://content/foci/%s.tres" % id))
	_save(content, "res://content/crafting_content.tres")
	print("Inhalte erzeugt: %d Gems, %d Gravuren" % [content.gems.size(), content.engravings.size()])
	quit()


func _rule(r: Array) -> ScalingRule:
	var rule := ScalingRule.new()
	match r[0]:
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
