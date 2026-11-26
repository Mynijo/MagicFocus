class_name CombatMage
extends RefCounted
## Zustand eines Magiers im Kampf: Leben, Mana, Spells in fester Reihenfolge,
## laufender Cast und Status-Stacks.

const MAX_SPELLS := 5

var mage_name: String
## Spells in Cast-Reihenfolge (nur gültige)
var spells: Array[SpellResult] = []
## Anzeigename pro Spell (Name des gespeicherten Fokus)
var spell_names := PackedStringArray()

var hp := 0.0
var max_hp := 0.0
var mana := 0.0
var max_mana := 0.0
## Status-Name (Wert-ID wie &"burn") -> Stacks
var status := {}

## Index des nächsten Spells in der Reihenfolge
var next_spell := 0
## Index des Spells, der gerade gecastet wird, sonst -1
var casting := -1
var cast_elapsed := 0.0
var cast_total := 0.0
## true, solange er auf Mana für den nächsten Spell wartet (für das Log)
var waiting_for_mana := false


## Magier aus gespeicherten Foki; ungültige Foki werden übersprungen und in `warnings` gemeldet.
static func from_foci(p_name: String, foci: Array[FocusInstance], names: PackedStringArray,
		elements: Array[ElementDef], warnings: Array[String]) -> CombatMage:
	var mage := CombatMage.new()
	mage.mage_name = p_name
	for i in mini(foci.size(), MAX_SPELLS):
		var result := SpellEvaluator.evaluate(foci[i], elements)
		var spell_name := names[i] if i < names.size() else "Spell %d" % (i + 1)
		if not result.valid:
			warnings.append("%s: „%s“ ist kein gültiger Spell und wird übersprungen." % [p_name, spell_name])
			continue
		mage.spells.append(result)
		mage.spell_names.append(spell_name)
	return mage


func stacks(stat: StringName) -> int:
	return int(status.get(stat, 0))


func add_stacks(stat: StringName, amount: int) -> void:
	if amount > 0:
		status[stat] = stacks(stat) + amount


## Entfernt bis zu `amount` Stacks; gibt zurück, wie viele es waren.
func remove_stacks(stat: StringName, amount: int) -> int:
	var removed := mini(stacks(stat), maxi(amount, 0))
	if removed > 0:
		status[stat] = stacks(stat) - removed
		if stacks(stat) == 0:
			status.erase(stat)
	return removed


func is_alive() -> bool:
	return hp > 0.0


func is_stunned() -> bool:
	return stacks(&"ice") > 0


## Name des Spells, der gerade gecastet wird ("" ohne Cast).
func casting_name() -> String:
	return spell_names[casting] if casting >= 0 else ""
