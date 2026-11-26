class_name Combat
extends RefCounted
## Kampf zweier Magier (1 gegen 1). Reine Logik, deterministisch über den Seed:
## gleicher Seed und gleiche Magier ergeben immer denselben Verlauf.
##
## Ablauf pro Tick (rules.tick Sekunden):
##   1. Beide Magier: Cast fortsetzen (pausiert bei Eis) oder neuen Cast beginnen.
##      Spells kommen in fester Reihenfolge; fehlt Mana, wartet der Magier.
##      Mana wird beim Cast-Start bezahlt (löst Schock aus).
##   2. Fertige Spells beider Magier wirken gleichzeitig.
##   3. Einmal pro Sekunde: Status-Puls (Bleed, Burn, Leben-Reg, Mana-Reg mit Mana
##      Burn, Abbau von Slowed, Hasted und Eis).
##   4. Ende, wenn ein Magier kein Leben mehr hat (beide: unentschieden)
##      oder rules.max_duration erreicht ist (unentschieden).
##
## Ziele: Schaden und Status gegen den Gegner (OFFENSIVE_STATUS), Heilung und
## Buffs auf den Caster (SELF_STATUS).

## Wert-ID des Spells -> Status beim Gegner (Slow aus der Gravur wird zu Slowed)
const OFFENSIVE_STATUS := {
	&"burn": &"burn", &"bleed": &"bleed", &"wet": &"wet", &"shock": &"shock",
	&"slow": &"slow", &"mana_burn": &"mana_burn",
}
## Wert-ID des Spells -> Status beim Caster
const SELF_STATUS := {
	&"armor": &"armor", &"hasted": &"hasted", &"life_regen": &"life_regen", &"mana_regen": &"mana_regen",
}
## Anzeigenamen der Status (entsprechen den Begriffen der Tooltips)
const STATUS_NAMES := {
	&"burn": "Burn", &"bleed": "Bleed", &"wet": "Nass", &"shock": "Schock", &"slow": "Slowed",
	&"mana_burn": "Mana Burn", &"armor": "Armor", &"hasted": "Hasted", &"life_regen": "Leben-Reg",
	&"mana_regen": "Mana-Reg", &"ice": "Eis",
}

var rules: CombatRules
var mages: Array[CombatMage] = []
var time := 0.0
var over := false
## 0 oder 1 = Sieger, -1 = unentschieden (nur gültig, wenn `over`)
var winner := -1
## Kampf-Log: {time: float, mage: int (-1 = allgemein), text: String}
var events: Array[Dictionary] = []
## Statistik pro Magier (Index = Verursacher):
##   damage:   Quelle -> verursachter Schaden (Spells, Burn, Bleed, Schock; Status
##             zählen für den, der sie verursacht hat, also den Gegner des Getroffenen)
##   heal:     Quelle -> geheilte Leben
##   absorbed: von der eigenen Armor abgefangener Schaden
##   casts:    Spell -> Anzahl Casts
##   crits:    Spell -> Anzahl Crits
var statistics: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _pulse_timer := 0.0


func _init(a: CombatMage, b: CombatMage, p_rules: CombatRules, seed_value: int) -> void:
	rules = p_rules
	mages = [a, b]
	_rng.seed = seed_value
	for k in 2:
		statistics.append({ damage = {}, heal = {}, absorbed = 0.0, casts = {}, crits = {} })
	for mage in mages:
		mage.max_hp = rules.max_hp
		mage.hp = rules.max_hp
		mage.max_mana = rules.max_mana
		mage.mana = minf(rules.start_mana, rules.max_mana)
	for i in 2:
		if mages[i].spells.is_empty():
			_log(i, "%s hat keinen gültigen Spell." % mages[i].mage_name)


## Kompletter Kampf ohne Darstellung (Tests, Balancing).
static func run(a: CombatMage, b: CombatMage, p_rules: CombatRules, seed_value: int) -> Combat:
	var combat := Combat.new(a, b, p_rules, seed_value)
	while not combat.over:
		combat.step()
	return combat


func step() -> void:
	if over:
		return
	var dt := rules.tick
	time += dt
	var finished: Array[int] = [-1, -1]
	for i in 2:
		finished[i] = _advance(i, dt)
	for i in 2:
		if finished[i] >= 0:
			_apply_spell(i, finished[i])
	_pulse_timer += dt
	if _pulse_timer >= 1.0 - 0.0001:
		_pulse_timer -= 1.0
		for i in 2:
			_pulse(i)
	_check_end()


# --- Casten -----------------------------------------------------------------

## Setzt den Cast fort oder beginnt einen neuen; gibt den Index eines fertigen Spells zurück.
func _advance(i: int, dt: float) -> int:
	var mage := mages[i]
	if mage.is_stunned():
		return -1
	if mage.casting < 0:
		_try_start_cast(i)
	if mage.casting < 0:
		return -1
	mage.cast_elapsed += dt
	if mage.cast_elapsed >= mage.cast_total - 0.0001:
		var done := mage.casting
		mage.casting = -1
		return done
	return -1


func _try_start_cast(i: int) -> void:
	var mage := mages[i]
	if mage.spells.is_empty():
		return
	var index := mage.next_spell
	var spell := mage.spells[index]
	if mage.mana < spell.mana_cost:
		if not mage.waiting_for_mana:
			mage.waiting_for_mana = true
			_log(i, "%s wartet auf Mana für %s." % [mage.mage_name, mage.spell_names[index]])
		return
	mage.waiting_for_mana = false
	mage.mana -= spell.mana_cost
	mage.casting = index
	mage.next_spell = (index + 1) % mage.spells.size()
	mage.cast_elapsed = 0.0
	mage.cast_total = cast_time_for(mage, spell)
	_count(statistics[i].casts, mage.spell_names[index], 1.0)
	_log(i, "%s castet %s (%s s)." % [mage.mage_name, mage.spell_names[index], _num(mage.cast_total)])
	_trigger_shock(i, spell.mana_cost)


## Cast-Zeit mit Slowed und Hasted, beim Cast-Start festgelegt.
func cast_time_for(mage: CombatMage, spell: SpellResult) -> float:
	var t := spell.cast_time + mage.stacks(&"slow") * rules.slowed_seconds - mage.stacks(&"hasted") * rules.hasted_seconds
	return maxf(SpellEvaluator.MIN_CAST_TIME, t)


# --- Spells wirken ----------------------------------------------------------

func _apply_spell(i: int, index: int) -> void:
	var caster := mages[i]
	var j := 1 - i
	var spell := caster.spells[index]
	var spell_name := caster.spell_names[index]

	var damage := spell.get_stat(&"damage")
	if damage > 0.0:
		var crit := _rng.randf() * 100.0 < spell.get_stat(&"crit")
		if crit:
			damage *= rules.crit_multiplier
			_count(statistics[i].crits, spell_name, 1.0)
		_damage(j, damage, spell_name + (" (Crit)" if crit else ""), spell_name)

	var heal := spell.get_stat(&"heal")
	if heal > 0.0:
		_heal(i, heal, spell_name)

	for stat: StringName in OFFENSIVE_STATUS:
		_add_status(j, OFFENSIVE_STATUS[stat], int(spell.get_stat(stat)))
	for stat: StringName in SELF_STATUS:
		_add_status(i, SELF_STATUS[stat], int(spell.get_stat(stat)))
	_armor_break(j, int(spell.get_stat(&"armor_break")))

	# Freeze: wandelt Nass des Gegners in Eis (nach dem Nass dieses Spells)
	var conversion := spell.get_stat(&"freeze_conversion")
	if conversion > 0.0:
		var target := mages[j]
		var ice := int(floor(target.stacks(&"wet") / conversion))
		if ice > 0:
			target.remove_stacks(&"wet", int(ice * conversion))
			_add_status(j, &"ice", ice)


## Schaden über Armor: Armor fängt Schaden 1 : 1 ab und verliert dabei Stacks.
## `stat_source` = Quelle für die Statistik (ohne Zusatz wie "(Crit)"), sonst `source`.
func _damage(target_index: int, amount: float, source: String, stat_source := "") -> void:
	var target := mages[target_index]
	var absorbed := target.remove_stacks(&"armor", int(floor(amount)))
	var taken := maxf(0.0, amount - absorbed)
	target.hp -= taken
	# aller Schaden stammt vom Gegner (auch Status und Schock)
	_count(statistics[1 - target_index].damage, stat_source if stat_source != "" else source, taken)
	statistics[target_index].absorbed += absorbed
	var text := "%s nimmt %s Schaden (%s)" % [target.mage_name, _num(taken), source]
	if absorbed > 0:
		text += ", Armor fängt %d ab" % absorbed
	_log(target_index, text + ".")


func _heal(target_index: int, amount: float, source: String) -> void:
	var target := mages[target_index]
	var healed := minf(amount, target.max_hp - target.hp)
	target.hp += healed
	_count(statistics[target_index].heal, source, healed)
	if healed > 0.0:
		_log(target_index, "%s heilt %s (%s)." % [target.mage_name, _num(healed), source])


## Status hinzufügen, mit Gegenseitigkeiten: Nass und Burn, Slowed und Hasted heben sich 1 : 1 auf.
func _add_status(target_index: int, stat: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var target := mages[target_index]
	var opposite := { &"wet": &"burn", &"burn": &"wet", &"slow": &"hasted", &"hasted": &"slow" }
	if opposite.has(stat):
		var cancelled := target.remove_stacks(opposite[stat], amount)
		if cancelled > 0:
			_log(target_index, "%s: %s hebt %d %s auf." % [
				target.mage_name, STATUS_NAMES[stat], cancelled, STATUS_NAMES[opposite[stat]]])
		amount -= cancelled
	if amount <= 0:
		return
	if stat == &"slow" or stat == &"hasted":
		amount = mini(amount, rules.max_slowed_hasted - target.stacks(stat))
		if amount <= 0:
			return
	target.add_stacks(stat, amount)
	_log(target_index, "%s erhält %d %s." % [target.mage_name, amount, STATUS_NAMES.get(stat, String(stat))])


## Armor Break hebt Armor im Verhältnis 1 : ratio auf (sofort, Rest verfällt).
func _armor_break(target_index: int, amount: int) -> void:
	if amount <= 0:
		return
	var removed := mages[target_index].remove_stacks(&"armor", int(amount * rules.armor_break_ratio))
	if removed > 0:
		_log(target_index, "%s: Armor Break entfernt %d Armor." % [mages[target_index].mage_name, removed])


## Schock: 1 Schaden pro bezahltem Mana (höchstens so viel wie Stacks), plus Nass-Bonus.
func _trigger_shock(i: int, mana_spent: float) -> void:
	var mage := mages[i]
	var consumed := mage.remove_stacks(&"shock", int(floor(mana_spent)))
	if consumed <= 0:
		return
	var damage := consumed + mage.stacks(&"wet") * rules.wet_shock_bonus
	_damage(i, damage, "Schock")


# --- Status-Puls (einmal pro Sekunde) ----------------------------------------

func _pulse(i: int) -> void:
	var mage := mages[i]
	var bleed := mage.stacks(&"bleed")
	if bleed > 0:
		_damage(i, bleed * rules.bleed_damage, "Bleed")
		mage.remove_stacks(&"bleed", 1)
	var burn := mage.stacks(&"burn")
	if burn > 0:
		_damage(i, burn * rules.burn_damage, "Burn")
		mage.remove_stacks(&"burn", 1)
	var life := mage.stacks(&"life_regen")
	if life > 0:
		_heal(i, life, "Leben-Reg")
		mage.remove_stacks(&"life_regen", 1)

	# Mana: Grundwert + Mana-Reg, Mana Burn zieht davon ab und verbraucht sich dabei
	var regen := rules.mana_regen + mage.stacks(&"mana_regen")
	var burn_stacks := mage.stacks(&"mana_burn")
	if burn_stacks > 0 and rules.mana_burn_per_stack > 0.0:
		var burned := minf(burn_stacks * rules.mana_burn_per_stack, regen)
		regen -= burned
		mage.remove_stacks(&"mana_burn", int(ceil(burned / rules.mana_burn_per_stack)))
	mage.mana = minf(mage.max_mana, mage.mana + regen)
	mage.remove_stacks(&"mana_regen", 1)

	mage.remove_stacks(&"slow", 1)
	mage.remove_stacks(&"hasted", 1)
	mage.remove_stacks(&"ice", 1)


# --- Ende -------------------------------------------------------------------

func _check_end() -> void:
	var dead := [not mages[0].is_alive(), not mages[1].is_alive()]
	if dead[0] or dead[1]:
		over = true
		if dead[0] and dead[1]:
			winner = -1
			_log(-1, "Beide Magier fallen gleichzeitig: unentschieden.")
		else:
			winner = 1 if dead[0] else 0
			_log(-1, "%s gewinnt." % mages[winner].mage_name)
	elif time >= rules.max_duration - 0.0001:
		over = true
		winner = -1
		_log(-1, "Zeit abgelaufen: unentschieden.")


## Summe aller Werte eines Statistik-Eintrags (z. B. gesamter Schaden).
static func total(values: Dictionary) -> float:
	var sum := 0.0
	for v: float in values.values():
		sum += v
	return sum


func _count(values: Dictionary, key: String, amount: float) -> void:
	if amount > 0.0:
		values[key] = float(values.get(key, 0.0)) + amount


func _log(mage_index: int, text: String) -> void:
	events.append({ time = time, mage = mage_index, text = text })


static func _num(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
