class_name ContentText
extends RefCounted
## Texte aus den aktuellen Werten der Inhalte (nach Änderungen im Editor immer passend):
## Namen der Spell-Werte und die Beschreibung einer Gravur aus ihren Regeln.

## Anzeigenamen der Spell-Werte, die kein Status sind (Status: Name aus `Status`).
const VALUE_NAMES := {
	&"damage": "Schaden", &"heal": "Heilung", &"crit": "Crit", &"crit_damage": "Crit-Schaden (%)",
	&"hits": "Treffer", &"echo": "Echo", &"vampire": "Vampire", &"cleanse": "Cleanse", &"dispel": "Dispel",
	&"armor_break": "Armor Break", &"freeze_conversion": "Freeze (Nass pro Eis)", &"mana_reduction": "Mana-Reduktion",
	&"cast_time_reduction": "Cast-Zeit-Verkürzung (s)", &"radius_bonus": "Radius des Hauptgems",
}
## Werte, die nur an oder aus sind (1 = an): im Text nur der Name.
const FLAGS := [&"cleanse", &"life_rewind"]
const TARGET_NAMES := ["Gegner", "selbst", "beide"]


static func value_name(stat: StringName) -> String:
	return VALUE_NAMES[stat] if VALUE_NAMES.has(stat) else Status.name_of(stat)


## Alle bekannten Spell-Werte (für Auswahllisten im Editor).
static func all_values() -> Array[StringName]:
	var values: Array[StringName] = []
	for stat: StringName in VALUE_NAMES:
		values.append(stat)
	for stat: StringName in Status.NAMES:
		if Status.from_spell_value(stat) or stat == &"life_rewind":
			values.append(stat)
	return values


## Ein Wert als Text, z. B. "5 Heilung", "-1 s Cast-Zeit", "+10 % Crit-Schaden".
static func value_text(stat: StringName, amount: float) -> String:
	var n := TextFormat.number(absf(amount))
	var sign := "-" if amount < 0.0 else "+"
	var inverse := "+" if amount < 0.0 else "-"  # Reduktionen: positiver Wert = weniger
	match stat:
		&"cast_time_reduction":
			return "%s%s s Cast-Zeit" % [inverse, n]
		&"mana_reduction":
			return "%s%s Mana" % [inverse, n]
		&"crit":
			return "%s%s Crit" % [sign, n]
		&"crit_damage":
			return "%s%s %% Crit-Schaden" % [sign, n]
		&"radius_bonus":
			return "%s%s Radius des Hauptgems" % [sign, n]
		&"freeze_conversion":
			return "je %s Nass werden 1 Eis" % n
		&"vampire":
			return "%s Leben-Reg pro Bleed-Stack des Gegners" % TextFormat.number(amount)
		&"echo":
			return "%s× Echo" % TextFormat.number(amount)
	if FLAGS.has(stat) and is_equal_approx(amount, 1.0):
		return value_name(stat)
	return "%s %s" % [TextFormat.number(amount), value_name(stat)]


## Eine Regel als Text, z. B. "1 Burn pro 10 Punkte aus Feuer-Essenz (ab 50 Punkten)".
static func rule_text(rule: ScalingRule, content: CraftingContent) -> String:
	# Greift höchstens einmal (Höchstwert = Menge): "Life Rewind ab 50 Punkten aus ..."
	var once := rule.cap > 0.0 and is_equal_approx(rule.cap, rule.amount)
	var text := "%s %s %s" % [value_text(rule.stat, rule.amount), "ab" if once else "pro",
		"%d Punkten" % rule.per_n if once else ("Punkt" if rule.per_n == 1 else "%d Punkte" % rule.per_n)]
	match rule.source:
		ScalingRule.Source.BASE:
			text += " aus neutraler Essenz"
		ScalingRule.Source.ANY_ELEMENT:
			text += " aus Essenz"
		ScalingRule.Source.ELEMENT:
			text += " aus %s" % essence_name(rule.element_id, content)
	if rule.min_count > 0:
		text += " (ab %d Punkten)" % rule.min_count
	if rule.cap > 0.0 and not once:
		text += " (höchstens %s)" % TextFormat.number(rule.cap)
	return text


## "Feuer-Essenz", "Erd-Essenz", ...
static func essence_name(element_id: StringName, content: CraftingContent) -> String:
	var element := content.get_element(element_id) if content != null else null
	var element_name := element.display_name if element != null else String(element_id)
	return element_name.trim_suffix("e") + "-Essenz"


## Beschreibung einer Gravur: Notiz, feste Werte, Regeln, Einsammeln, Ziel, Punkte.
static func describe(engraving: EngravingDef, content: CraftingContent) -> String:
	var parts := PackedStringArray()
	if engraving.note != "":
		parts.append(engraving.note)
	for stat: StringName in engraving.base_stats:
		parts.append(value_text(stat, float(engraving.base_stats[stat])))
	for rule in engraving.rules:
		parts.append(rule_text(rule, content))
	if engraving.transfer_to_main:
		parts.append("Gibt alles Eingesammelte an das Hauptgem weiter")
	if not is_equal_approx(engraving.radius_factor, 1.0):
		parts.append("Radius ×%s" % TextFormat.number(engraving.radius_factor))
	if engraving.inner_radius_factor > 0.0:
		parts.append("Im inneren Ring (Stein + %s × Radius) zählt alles ×%s" % [
			TextFormat.number(engraving.inner_radius_factor), TextFormat.number(engraving.inner_multiplier)])
	if engraving.max_size < GemDef.Size.GROSS:
		parts.append("Nur bis Größe %s" % GemDef.SIZE_NAMES[engraving.max_size])
	if engraving.role == GemDef.Role.MAIN:
		parts.append("Ziel: " + TARGET_NAMES[engraving.target])
	var points := points_text(engraving, content)
	if points != "":
		parts.append(points)
	return ". ".join(parts)


## "Punkte: neutrale Essenz ×1, Feuer-Essenz ×5" (nur wenn Regeln Punkte zählen).
static func points_text(engraving: EngravingDef, content: CraftingContent) -> String:
	if engraving.rules.is_empty():
		return ""
	var parts := PackedStringArray()
	for rule in engraving.rules:
		if rule.source in [ScalingRule.Source.POINTS, ScalingRule.Source.BASE]:
			parts.append("neutrale Essenz ×1")
			break
	var factors := engraving.element_factors.values()
	var all_elements := content != null and engraving.element_factors.size() == content.elements.size()
	if all_elements and factors.all(func(f: float) -> bool: return is_equal_approx(f, factors[0])):
		parts.append("jede Essenz ×%s" % TextFormat.number(factors[0]))
	elif content != null:
		for element in content.elements:
			if engraving.counts_element(element.id):
				parts.append("%s ×%s" % [essence_name(element.id, content), TextFormat.number(engraving.factor_of(element.id))])
	return "Punkte: " + ", ".join(parts)
