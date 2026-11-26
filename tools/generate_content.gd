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

## Je Rolle und Größe (winzig, klein, mittel, groß): Radius, max. neutrale Essenz, max. Essenzen,
## Größe des Steins (Fokus-Einheiten; Essenz darunter ist verdeckt).
## Daraus entstehen alle Kombinationen mit Grob und Spitz,
## z. B. id "nebengem_mittel_spitz", Name "Nebengem mittel Spitz".
const GEM_SIZES := {
	MAIN: [[40.0, 20, 5, 8.0], [90.0, 45, 20, 15.0], [120.0, 60, 25, 15.0], [165.0, 85, 35, 15.0]],
	MINOR: [[25.0, 8, 3, 6.0], [45.0, 15, 10, 10.0], [60.0, 25, 15, 10.0], [90.0, 30, 20, 10.0]],
}
const SIZE_IDS := ["winzig", "klein", "mittel", "gross"]

const FOCI := [&"winziger_fokus", &"kleiner_fokus", &"mittlerer_fokus", &"grosser_fokus", &"sehr_grosser_fokus",
	&"stern_fokus", &"tropfen_fokus", &"feuer_fokus", &"neutraler_fokus"]

## Standard-Faktor: 1 Essenz zählt für Gravuren mit ihrem Element so viele Punkte
## (pro Gravur und Element abweichend möglich, siehe `factors` in ENGRAVINGS).
const ELEMENT_FACTOR := 5.0

## Alle Elemente (für Gravuren, die jede Essenz zählen, z. B. Magischer Bolzen).
const ALL := [&"fire", &"water", &"earth", &"air", &"lightning"]

## Punkte einer Gravur = neutrale Essenz + Essenz × Faktor ihres Elements.
## `el` = Element-ID oder Liste (z. B. ALL). Nur Essenz dieser Elemente zählt,
## andere gar nicht. Ohne `el` zählt die Gravur nur neutrale Essenz.
## Die Beschreibung erzeugt `ContentText.describe()` aus den Werten; `note` nur für Besonderheiten.
##
## Regel-Kurzform: [Quelle, pro N, Wert, Menge, (Mindestanzahl), (Höchstwert)]
##   Quelle: "P" = Punkte (neutrale Essenz + gewichtete Essenz), "N" = nur neutrale Essenz,
##           "E" = nur Essenz (gewichtet), sonst Element-ID (nur dieses Element, gewichtet)
## Status entsteht nur aus Essenz des passenden Elements, nie aus neutraler Essenz.
const ENGRAVINGS := [
	# --- Hauptgravuren ---
	{ id = &"magischer_bolzen", name = "Magischer Bolzen", role = MAIN, el = ALL,
		rules = [["P", 1, &"damage", 1.0]] },
	{ id = &"freeze", name = "Freeze", role = MAIN, el = [&"water", &"air"],
		stats = { &"freeze_conversion": 100.0 },
		rules = [["P", 1, &"damage", 1.0]] },
	{ id = &"slow", name = "Slow", role = MAIN, el = &"air",
		rules = [["P", 20, &"slow", 1.0]] },
	{ id = &"heal", name = "Heal", role = MAIN, el = &"water", target = SELF,
		rules = [["P", 1, &"heal", 5.0]] },
	{ id = &"schutz", name = "Schutz", role = MAIN, el = &"earth", target = SELF,
		rules = [["P", 1, &"armor", 5.0]] },
	{ id = &"hasted", name = "Hasted", role = MAIN, el = &"air", target = SELF,
		rules = [["P", 20, &"hasted", 1.0]] },
	{ id = &"leben_reg", name = "Leben-Reg", role = MAIN, el = &"water", target = SELF,
		rules = [["P", 2, &"life_regen", 1.0]] },
	{ id = &"mana_reg", name = "Mana-Reg", role = MAIN, el = &"lightning", target = SELF,
		rules = [["P", 2, &"mana_regen", 1.0]] },
	{ id = &"feuerball", name = "Feuerball", role = MAIN, el = &"fire",
		rules = [["P", 1, &"damage", 1.0], [&"fire", 10, &"burn", 1.0]] },
	{ id = &"wasser_detonation", name = "Wasser-Detonation", role = MAIN, el = &"water",
		rules = [["P", 1, &"damage", 1.0], [&"water", 10, &"wet", 1.0]] },
	{ id = &"luftklinge", name = "Luftklinge", role = MAIN, el = &"air",
		rules = [["P", 1, &"damage", 1.0], [&"air", 10, &"bleed", 1.0]] },
	{ id = &"kanone", name = "Kanone", role = MAIN, el = &"earth",
		rules = [["P", 1, &"damage", 1.0], [&"earth", 10, &"armor_break", 1.0]] },
	{ id = &"blitzschlag", name = "Blitzschlag", role = MAIN, el = &"lightning",
		rules = [["P", 1, &"damage", 1.0], [&"lightning", 10, &"shock", 1.0]] },
	# Spell-Paket 2026-11-26, Etappe 3
	{ id = &"meteor", name = "Meteor", role = MAIN, el = &"fire",
		rules = [[&"fire", 50, &"damage", 150.0]] },
	{ id = &"fire_rain", name = "Fire Rain", role = MAIN, el = &"fire", target = BOTH,
		rules = [[&"fire", 5, &"burn", 1.0]] },
	{ id = &"permanent_burn", name = "Permanent Burn", role = MAIN, el = &"fire",
		rules = [[&"fire", 25, &"perma_burn", 1.0]] },
	{ id = &"water_rain", name = "Water Rain", role = MAIN, el = &"water", target = BOTH,
		rules = [[&"water", 5, &"wet", 1.0]] },
	{ id = &"cleanse", name = "Cleanse", role = MAIN, el = &"water", target = SELF,
		stats = { &"cleanse": 1.0 },
		rules = [["P", 1, &"heal", 1.0]] },
	{ id = &"bless", name = "Bless", role = MAIN, el = &"water", target = SELF,
		rules = [["P", 10, &"bless", 1.0]] },
	{ id = &"life_rewind", name = "Life Rewind", role = MAIN, el = &"water", target = SELF,
		rules = [[&"water", 50, &"life_rewind", 1.0, 0, 1.0]] },
	{ id = &"dispel", name = "Dispel", role = MAIN, el = &"lightning",
		stats = { &"dispel": 1.0 },
		rules = [["P", 50, &"dispel", 1.0], ["P", 2, &"damage", 1.0]] },
	{ id = &"thunderstorm", name = "Thunderstorm", role = MAIN, el = &"lightning",
		note = "Schaden gilt pro Treffer, mindestens 1 Treffer",
		stats = { &"damage": 30.0 },
		rules = [[&"lightning", 50, &"hits", 1.0]] },
	{ id = &"bulwark", name = "Bulwark", role = MAIN, el = &"earth", target = SELF,
		rules = [[&"earth", 1, &"armor", 8.0, 50]] },
	{ id = &"damage_reduction", name = "Damage Reduction", role = MAIN, el = &"earth", target = SELF,
		stats = { &"damage_reduction": 1.0 },
		rules = [["P", 50, &"damage_reduction", 1.0]] },
	{ id = &"accelerated_burn", name = "Accelerated Burn", role = MAIN, el = [&"fire", &"air"],
		rules = [[&"air", 10, &"accelerated_burn", 1.0], [&"fire", 10, &"burn", 1.0]] },
	{ id = &"mana_absorption", name = "Mana Absorption", role = MAIN, el = [&"water", &"earth"], target = SELF,
		rules = [["P", 1, &"armor", 2.0], ["E", 10, &"mana_absorption", 1.0]] },
	# Paket 2
	{ id = &"critical_chance", name = "Critical Chance", role = MAIN, el = &"fire", target = SELF,
		rules = [["P", 5, &"critical_chance", 1.0]] },
	{ id = &"blood_thinner", name = "Blood Thinner", role = MAIN, el = [&"water", &"earth"],
		rules = [["P", 10, &"blood_thinner", 1.0]] },
	{ id = &"vampire", name = "Vampire", role = MAIN, el = &"water", target = SELF,
		stats = { &"vampire": 1.0 },
		rules = [["P", 100, &"vampire", 1.0]] },
	{ id = &"max_health", name = "Max Health", role = MAIN, el = &"water", target = SELF,
		rules = [["P", 2, &"max_health", 1.0]] },
	{ id = &"rot", name = "Rot", role = MAIN, el = &"earth",
		rules = [["P", 1, &"rotten", 1.0]] },
	# --- Nebengravuren ---
	# ID "standard" bleibt (gespeicherte Foki), Name ist Power Transfer
	{ id = &"standard", name = "Power Transfer", role = MINOR, radius = 0.5,
		transfer = true, rules = [] },
	{ id = &"crit", name = "Crit", role = MINOR, el = &"fire",
		rules = [["P", 2, &"crit", 1.0]] },
	{ id = &"mana_reduktion", name = "Mana-Reduktion", role = MINOR, el = &"water",
		rules = [["P", 2, &"mana_reduction", 1.0]] },
	{ id = &"cast_speed", name = "Cast-Speed", role = MINOR, el = &"air",
		rules = [["P", 10, &"cast_time_reduction", 1.0]] },
	{ id = &"armor", name = "Armor", role = MINOR, el = &"earth",
		rules = [["P", 2, &"armor", 1.0]] },
	{ id = &"mana_burn", name = "Mana Burn", role = MINOR, el = &"lightning",
		rules = [[&"lightning", 5, &"mana_burn", 1.0]] },
	# Status-Nebengravuren: je Element eine, Status nur aus Essenz des Elements
	{ id = &"status_burn", name = "Burn", role = MINOR, el = &"fire", rules = [[&"fire", 5, &"burn", 1.0]] },
	{ id = &"status_nass", name = "Nass", role = MINOR, el = &"water", rules = [[&"water", 5, &"wet", 1.0]] },
	{ id = &"status_bleed", name = "Bleed", role = MINOR, el = &"air", rules = [[&"air", 5, &"bleed", 1.0]] },
	{ id = &"status_armor_break", name = "Armor Break", role = MINOR, el = &"earth", rules = [[&"earth", 5, &"armor_break", 1.0]] },
	{ id = &"status_schock", name = "Schock", role = MINOR, el = &"lightning", rules = [[&"lightning", 5, &"shock", 1.0]] },
	# Spell-Paket 2026-11-26, Etappe 4
	{ id = &"echo", name = "Echo", role = MINOR, el = ALL,
		note = "Wiederholt den Spell sofort; jedes Mal Mana, keine Cast-Zeit",
		rules = [["E", 100, &"echo", 1.0]] },
	{ id = &"mana_efficiency", name = "Mana Efficiency", role = MINOR, el = [&"water", &"air"],
		stats = { &"cast_time_reduction": -1.0 },
		rules = [[&"water", 1, &"mana_reduction", 1.0], [&"air", 5, &"cast_time_reduction", 0.1, 0, 1.0]] },
	{ id = &"quick_cast", name = "Quick Cast", role = MINOR, el = [&"water", &"air"],
		stats = { &"mana_reduction": -10.0 },
		rules = [[&"air", 5, &"cast_time_reduction", 1.0], [&"water", 2, &"mana_reduction", 1.0, 0, 10.0]] },
	{ id = &"radius_expansion", name = "Radius Expansion", role = MINOR, el = &"earth",
		rules = [[&"earth", 2, &"radius_bonus", 1.0]] },
	{ id = &"thorns", name = "Thorns", role = MINOR, el = &"earth", rules = [[&"earth", 5, &"thorns", 1.0]] },
	# Paket 2
	{ id = &"neben_cleanse", name = "Cleanse", role = MINOR, el = &"water",
		stats = { &"cleanse": 1.0 }, rules = [] },
	{ id = &"regeneration", name = "Regeneration", role = MINOR, el = &"water", rules = [[&"water", 5, &"life_regen", 1.0]] },
	{ id = &"neben_dispel", name = "Dispel", role = MINOR, el = &"lightning",
		rules = [[&"lightning", 25, &"dispel", 1.0]] },
	{ id = &"critical_damage", name = "Critical Damage", role = MINOR, el = &"lightning", rules = [[&"lightning", 5, &"crit_damage", 10.0]] },
	{ id = &"status_slow", name = "Slow", role = MINOR, el = &"air", rules = [[&"air", 5, &"slow", 1.0]] },
	# Etappe 5: Multiplikator
	{ id = &"multiplikator", name = "Multiplikator", role = MINOR, radius = 0.8, inner = 0.3, max_size = GemDef.Size.MITTEL,
		transfer = true, rules = [] },
]

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(GEM_DIR)
	DirAccess.make_dir_recursive_absolute(ENGRAVING_DIR)

	var content := CraftingContent.new()
	for id in ALL:
		var element: ElementDef = load("res://content/elements/%s.tres" % id)
		element.dot_texture = load("res://assets/sprites/essenz_%s.png" % id)
		element.icon = load("res://assets/sprites/element_%s.png" % id)
		# neu speichern, damit entfernte Felder aus der Datei verschwinden
		_save(element, "res://content/elements/%s.tres" % id)
		content.elements.append(load("res://content/elements/%s.tres" % id))

	for role in [MAIN, MINOR]:
		var role_name := "Hauptgem" if role == MAIN else "Nebengem"
		for size in SIZE_IDS.size():
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
				gem.body_radius = row[3]
				var path := GEM_DIR + String(gem.id) + ".tres"
				_save(gem, path)
				content.gems.append(load(path))

	for data: Dictionary in ENGRAVINGS:
		var engraving := EngravingDef.new()
		engraving.id = data.id
		engraving.display_name = data.name
		engraving.role = data.role
		engraving.element_factors = _element_factors(data)
		# Symbol, falls vorhanden (aufbereitet mit tools/prepare_assets.gd)
		var icon_path := "res://assets/sprites/engraving_%s.png" % data.id
		if ResourceLoader.exists(icon_path):
			engraving.icon = load(icon_path)
		engraving.note = data.get("note", "")
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
	# Kampfregeln nur anlegen, nie überschreiben (Werte werden von Hand im Editor angepasst)
	if not ResourceLoader.exists("res://content/combat_rules.tres"):
		_save(CombatRules.new(), "res://content/combat_rules.tres")
	GlossaryBuilder.build(content, load("res://content/combat_rules.tres"))
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


## Element-ID -> Faktor: `el` (einzelne ID oder Liste) mit ELEMENT_FACTOR,
## einzelne Faktoren lassen sich mit `factors = { &"fire": 3.0 }` abweichend setzen.
func _element_factors(data: Dictionary) -> Dictionary:
	var ids: Variant = data.get("el", [])
	if ids is StringName:
		ids = [ids]
	var factors := {}
	for id: StringName in ids:
		factors[id] = ELEMENT_FACTOR
	factors.merge(data.get("factors", {}), true)
	return factors
