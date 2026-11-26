class_name GlossaryBuilder
extends RefCounted
## Baut die Begriffe für die Tooltips (`CraftingContent.glossary`) aus den aktuellen Inhalten
## und Kampfregeln. Läuft im Generator und erneut, wenn der Editor Werte ändert.

## Begriffe für die Tooltips: ID -> [Titel, weitere Wörter, Text]. Leerer Titel = Name aus
## `Status.NAMES`. Bei Status ist die ID die Status-ID. `{name}` im Text wird durch den
## Wert aus content/combat_rules.tres ersetzt (siehe `rule_values`).
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


## Ersetzt die Begriffe von `content`: Elemente, Buff, Debuff und TERMS.
static func build(content: CraftingContent, rules: CombatRules) -> void:
	content.glossary.clear()
	for element in content.elements:
		content.glossary.append(_element_term(element, content))
	content.glossary.append(_group_term(&"debuff", "Debuff", Status.DEBUFFS, "Schadet dem Träger; Cleanse entfernt alle"))
	content.glossary.append(_group_term(&"buff", "Buff", Status.BUFFS, "Hilft dem Träger; Dispel entfernt sie"))
	var values := rule_values(rules)
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


## Werte aus den Kampfregeln für die Platzhalter in TERMS.
static func rule_values(rules: CombatRules) -> Dictionary:
	var values := {}
	for property in rules.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = rules.get(property.name)
			if value is float or value is int:
				values[property.name] = TextFormat.number(value)
	values["damage_reduction_percent"] = TextFormat.number(rules.damage_reduction_factor * 100.0)
	values["crit_percent"] = TextFormat.number(rules.crit_multiplier * 100.0)
	return values


## Element: Faktor, erzeugte Effekte und Gravuren (aus den Gravuren berechnet).
static func _element_term(element: ElementDef, content: CraftingContent) -> GlossaryTerm:
	var term := GlossaryTerm.new()
	term.id = element.id
	term.title = element.display_name
	term.icon = element.icon
	term.icon_color = element.color
	var essence := ContentText.essence_name(element.id, content)
	term.words = PackedStringArray([element.display_name, essence])
	var engravings := PackedStringArray()
	var effects := PackedStringArray()
	var factors := PackedStringArray()
	for engraving in content.engravings:
		if not engraving.counts_element(element.id):
			continue
		var factor := TextFormat.number(engraving.factor_of(element.id))
		if not factors.has(factor):
			factors.append(factor)
		if engraving.element_factors.size() == content.elements.size():
			continue  # Magischer Bolzen: zählt alles, erzeugt nichts Eigenes
		if not engravings.has(engraving.display_name):
			engravings.append(engraving.display_name)
		for stat: StringName in _stats_of(engraving):
			var title := _term_title(stat)
			if title != "" and not effects.has(title):
				effects.append(title)
	term.text = "Element. 1 %s = %s Punkte, nur für Gravuren mit %s.\nErzeugt: %s.\nGravuren: [nolink]%s[/nolink]." % [
		essence, " oder ".join(factors), element.display_name, ", ".join(effects), ", ".join(engravings)]
	return term


static func _group_term(id: StringName, title: String, statuses: Array[StringName], text: String) -> GlossaryTerm:
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
