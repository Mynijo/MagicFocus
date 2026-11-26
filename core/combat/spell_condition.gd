class_name SpellCondition
extends Resource
## Aktivierungsbedingung eines Spells im Kampf. Ist sie nicht erfüllt, überspringt
## der Magier den Spell und nimmt den nächsten in der Reihenfolge.

enum Type { ALWAYS, ONCE, OWN_HP_BELOW, OWN_HP_ABOVE, ENEMY_HP_BELOW, ENEMY_HP_ABOVE, OWN_HAS_STATUS, ENEMY_HAS_STATUS,
	OWN_STACKS_ABOVE, OWN_STACKS_BELOW, ENEMY_STACKS_ABOVE, ENEMY_STACKS_BELOW }

## Anzeigenamen in Reihenfolge von Type
const TYPE_NAMES := [
	"Immer", "Einmal", "Eigenes Leben unter", "Eigenes Leben über",
	"Gegner-Leben unter", "Gegner-Leben über", "Selbst hat Status", "Gegner hat Status",
	"Selbst hat mehr als", "Selbst hat weniger als", "Gegner hat mehr als", "Gegner hat weniger als",
]

@export var type: Type = Type.ALWAYS
## Schwelle in Prozent des maximalen Lebens (für die Leben-Bedingungen)
@export var percent := 50.0
## Status-ID wie &"burn" (für die Status-Bedingungen)
@export var status: StringName = &"burn"
## Anzahl Stacks (für "mehr als" / "weniger als")
@export var amount := 1


static func create(p_type: Type, p_percent := 50.0, p_status: StringName = &"burn", p_amount := 1) -> SpellCondition:
	var condition := SpellCondition.new()
	condition.type = p_type
	condition.percent = p_percent
	condition.status = p_status
	condition.amount = p_amount
	return condition


static func uses_percent(p_type: Type) -> bool:
	return p_type in [Type.OWN_HP_BELOW, Type.OWN_HP_ABOVE, Type.ENEMY_HP_BELOW, Type.ENEMY_HP_ABOVE]


static func uses_status(p_type: Type) -> bool:
	return p_type in [Type.OWN_HAS_STATUS, Type.ENEMY_HAS_STATUS] or uses_amount(p_type)


static func uses_amount(p_type: Type) -> bool:
	return p_type in [Type.OWN_STACKS_ABOVE, Type.OWN_STACKS_BELOW, Type.ENEMY_STACKS_ABOVE, Type.ENEMY_STACKS_BELOW]


## `casts` = wie oft dieser Spell schon gecastet wurde.
func is_met(caster: CombatMage, enemy: CombatMage, casts: int) -> bool:
	match type:
		Type.ONCE:
			return casts == 0
		Type.OWN_HP_BELOW:
			return caster.hp < caster.max_hp * percent / 100.0
		Type.OWN_HP_ABOVE:
			return caster.hp > caster.max_hp * percent / 100.0
		Type.ENEMY_HP_BELOW:
			return enemy.hp < enemy.max_hp * percent / 100.0
		Type.ENEMY_HP_ABOVE:
			return enemy.hp > enemy.max_hp * percent / 100.0
		Type.OWN_HAS_STATUS:
			return caster.stacks(status) > 0
		Type.ENEMY_HAS_STATUS:
			return enemy.stacks(status) > 0
		Type.OWN_STACKS_ABOVE:
			return caster.stacks(status) > amount
		Type.OWN_STACKS_BELOW:
			return caster.stacks(status) < amount
		Type.ENEMY_STACKS_ABOVE:
			return enemy.stacks(status) > amount
		Type.ENEMY_STACKS_BELOW:
			return enemy.stacks(status) < amount
	return true


## z. B. "Eigenes Leben unter 50 %" oder "Gegner hat Status Burn"
func describe() -> String:
	var text: String = TYPE_NAMES[type]
	if uses_percent(type):
		text += " %d %%" % int(percent)
	elif uses_amount(type):
		text += " %d %s" % [amount, Combat.STATUS_NAMES.get(status, status)]
	elif uses_status(type):
		text += " " + str(Combat.STATUS_NAMES.get(status, status))
	return text
