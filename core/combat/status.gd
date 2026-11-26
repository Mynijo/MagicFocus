class_name Status
extends RefCounted
## Alle Status im Kampf an einer Stelle. Die ID ist zugleich der Spell-Wert, der den
## Status erzeugt (z. B. Spell-Wert &"burn" -> Status &"burn"), und die ID des
## Begriffs im Glossar (Tooltip, Symbol).

## ID -> Anzeigename (Reihenfolge = Reihenfolge in Arena und Auswahllisten)
const NAMES := {
	&"burn": "Burn", &"bleed": "Bleed", &"wet": "Nass", &"shock": "Schock", &"slow": "Slowed",
	&"mana_burn": "Mana Burn", &"ice": "Eis", &"perma_burn": "Perma-Burn", &"accelerated_burn": "Accelerated Burn",
	&"blood_thinner": "Blood Thinner", &"cauterized": "Cauterized", &"rotten": "Rotten",
	&"armor": "Armor", &"hasted": "Hasted", &"life_regen": "Leben-Reg", &"mana_regen": "Mana-Reg",
	&"bless": "Bless", &"thorns": "Thorns", &"mana_absorption": "Mana Absorption",
	&"damage_reduction": "Damage Reduction", &"life_rewind": "Life Rewind",
	&"critical_chance": "Critical Chance", &"max_health": "Max Health",
}
## Cleanse entfernt diese ...
const DEBUFFS: Array[StringName] = [&"burn", &"bleed", &"wet", &"shock", &"slow", &"mana_burn", &"ice",
	&"perma_burn", &"accelerated_burn", &"blood_thinner", &"cauterized", &"rotten"]
## ... Dispel diese.
const BUFFS: Array[StringName] = [&"armor", &"hasted", &"life_regen", &"mana_regen", &"bless", &"thorns",
	&"mana_absorption", &"damage_reduction", &"life_rewind", &"critical_chance", &"max_health"]
## Status, die nicht direkt aus einem gleichnamigen Spell-Wert entstehen
## (Eis über Freeze, Cauterized aus Bleed + Burn, Life Rewind mit eigener Logik).
const SPECIAL: Array[StringName] = [&"ice", &"cauterized", &"life_rewind"]
## Status, die sich beim Hinzufügen 1 : 1 aufheben.
const OPPOSITES := { &"wet": &"burn", &"burn": &"wet", &"slow": &"hasted", &"hasted": &"slow" }


static func name_of(id: StringName) -> String:
	return NAMES.get(id, String(id))


## true, wenn der Spell-Wert `stat` beim Ziel als gleichnamiger Status landet.
static func from_spell_value(stat: StringName) -> bool:
	return NAMES.has(stat) and not SPECIAL.has(stat)
