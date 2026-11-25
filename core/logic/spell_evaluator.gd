class_name SpellEvaluator
extends RefCounted
## Wertet einen Fokus zu einem Spell aus. Reine Logik ohne Physik und ohne Szene,
## damit sie auch in der Werkstatt-Vorschau und später im Kampf (headless) läuft.
##
## Phasen:
##   1. Prüfen         Gem-Anzahl, genau ein Hauptgem, Gravuren, geschlossener Kreis
##   2. Bereiche       Einflusssektor jedes Gems (Radius + Innen-/Außenwinkel)
##   3. Einsammeln     Hauptgem zuerst, dann Nebengems in Platzierungsreihenfolge;
##                     jedes nimmt die nächsten freien Punkte bis zu seiner Kapazität
##   4. Multiplizieren Eingesammeltes × Flächen-Multiplikator der Gem-Form
##   5. Übertragen     Standard-Gems geben ihre effektiven Essenzen an das Hauptgem
##   6. Spell          Regeln der Gravuren, Effekte, Cast-Zeit, Mana

const MIN_GEMS := 3
const CAST_TIME_PER_GEM := 1.0
const MIN_CAST_TIME := 0.5
const MANA_PER_LENGTH := 0.1
const MIN_MANA := 1.0

const STAT_CAST_TIME_REDUCTION := &"cast_time_reduction"
const STAT_MANA_REDUCTION := &"mana_reduction"


## `elements` wird für lesbare Fehlermeldungen gebraucht.
## `dots` ist optional (für Tests); sonst werden sie aus dem Fokus erzeugt.
static func evaluate(focus: FocusInstance, elements: Array[ElementDef],
		dots: Variant = null) -> SpellResult:
	var result := SpellResult.new()
	result.dots.assign(dots if dots != null else DotField.generate(focus))

	_validate(focus, result, elements)
	if not result.errors.is_empty():
		return result

	var points := _loop_points(focus)
	var ccw := FocusGeometry.signed_area(points) > 0.0
	_build_gem_results(focus, points, ccw, result)

	var order := _collection_order(result)
	_collect(order, result)
	for gr in result.gem_results:
		gr.apply_multiplier(gr.placed.gem.get_multiplier())
	var main := result.gem_results[focus.get_main_gem_index()]
	_transfer(main, result)
	_compute_spell(main, order, points, result, elements)

	result.valid = true
	return result


# --- Phase 1 ---------------------------------------------------------------

static func _validate(focus: FocusInstance, result: SpellResult, elements: Array[ElementDef]) -> void:
	var def := focus.focus_def
	if def == null:
		result.errors.append("Der Fokus hat keinen Fokus-Typ.")
		return

	for element_id: StringName in focus.element_fill:
		if int(focus.element_fill[element_id]) > 0 and not def.allows_element(element_id):
			var element_name := String(element_id)
			for element in elements:
				if element.id == element_id:
					element_name = element.display_name
			result.errors.append("%s nimmt keine %s-Essenz auf." % [def.display_name, element_name])

	if focus.get_element_total() > def.max_element_dots:
		result.errors.append("Zu viele Essenzen (%d / %d)." % [focus.get_element_total(), def.max_element_dots])

	var gem_count := focus.gems.size()
	if gem_count < MIN_GEMS:
		result.errors.append("Ein Spell braucht mindestens %d Gems." % MIN_GEMS)
	if gem_count > def.max_gems:
		result.errors.append("Dieser Fokus fasst höchstens %d Gems." % def.max_gems)

	var main_count := 0
	for placed in focus.gems:
		if placed == null or placed.gem == null:
			result.errors.append("Ein Gem-Platz ist leer.")
			continue
		if placed.gem.role == GemDef.Role.MAIN:
			main_count += 1
		if placed.engraving == null:
			result.errors.append("%s hat keine Gravur." % placed.gem.display_name)
		elif placed.engraving.role != placed.gem.role:
			result.errors.append("Die Gravur „%s“ passt nicht auf %s." % [
				placed.engraving.display_name, placed.gem.display_name])
		if def.shape != null and not def.shape.contains(placed.position):
			result.errors.append("%s liegt außerhalb des Fokus." % placed.gem.display_name)
	if main_count != 1:
		result.errors.append("Ein Spell braucht genau ein Hauptgem (aktuell %d)." % main_count)
	if not result.errors.is_empty():
		return

	if not focus.loop_closed:
		result.errors.append("Der Gem-Kreis ist nicht geschlossen.")
		return
	if focus.loop.size() != gem_count:
		result.errors.append("Alle Gems müssen Teil des Kreises sein.")
		return
	var seen := {}
	for idx in focus.loop:
		if idx < 0 or idx >= gem_count or seen.has(idx):
			result.errors.append("Ungültige Verbindungsreihenfolge.")
			return
		seen[idx] = true
	if focus.gems[focus.loop[0]].gem.role != GemDef.Role.MAIN:
		result.errors.append("Der Kreis muss beim Hauptgem beginnen.")
		return

	var points := _loop_points(focus)
	if FocusGeometry.has_crossing(points):
		result.errors.append("Verbindungen dürfen sich nicht kreuzen.")
	elif absf(FocusGeometry.signed_area(points)) < 1.0:
		result.errors.append("Die Gems liegen auf einer Linie.")
	if def.shape != null:
		for k in points.size():
			if not def.shape.contains_segment(points[k], points[(k + 1) % points.size()]):
				result.errors.append("Verbindungen müssen innerhalb des Fokus verlaufen.")
				break


static func _loop_points(focus: FocusInstance) -> PackedVector2Array:
	var points := PackedVector2Array()
	for idx in focus.loop:
		points.append(focus.gems[idx].position)
	return points


# --- Phase 2 ---------------------------------------------------------------

static func _build_gem_results(focus: FocusInstance, points: PackedVector2Array,
		ccw: bool, result: SpellResult) -> void:
	for i in focus.gems.size():
		var gr := GemResult.new()
		gr.index = i
		gr.placed = focus.gems[i]
		result.gem_results.append(gr)

	var n := points.size()
	for k in n:
		var gr := result.gem_results[focus.loop[k]]
		var sector := FocusGeometry.sector_for(
			points[(k - 1 + n) % n], points[k], points[(k + 1) % n], gr.placed.gem.is_inner(), ccw)
		gr.sector_start = sector.x
		gr.sector_sweep = sector.y


# --- Phase 3 ---------------------------------------------------------------

## Hauptgem zuerst, danach Nebengems in Platzierungsreihenfolge.
static func _collection_order(result: SpellResult) -> Array[GemResult]:
	var order := result.gem_results.duplicate()
	order.sort_custom(func(a: GemResult, b: GemResult) -> bool:
		if a.is_main() != b.is_main():
			return a.is_main()
		return a.index < b.index)
	return order


static func _collect(order: Array[GemResult], result: SpellResult) -> void:
	var claimed := {}
	for gr in order:
		var gem := gr.placed.gem
		var center := gr.placed.position

		var candidates: Array[EnergyDot] = []
		for dot in result.dots:
			if claimed.has(dot):
				continue
			if FocusGeometry.in_sector(dot.position, center, gem.radius, gr.sector_start, gr.sector_sweep):
				candidates.append(dot)
		candidates.sort_custom(func(a: EnergyDot, b: EnergyDot) -> bool:
			return a.position.distance_squared_to(center) < b.position.distance_squared_to(center))

		var base_taken := 0
		var element_taken := 0
		for dot in candidates:
			if dot.is_base():
				if base_taken >= gem.max_base:
					continue
				base_taken += 1
			else:
				if element_taken >= gem.max_element:
					continue
				element_taken += 1
			gr.add_dot(dot)
			claimed[dot] = true


# --- Phase 5 ---------------------------------------------------------------

static func _transfer(main: GemResult, result: SpellResult) -> void:
	for gr in result.gem_results:
		if gr != main and gr.placed.engraving.transfer_to_main:
			main.receive(gr)


# --- Phase 6 ---------------------------------------------------------------

## Element-Essenz für eine Gravur: mit dem Faktor des Elements gewichtet.
## Nur Essenz der Elemente der Gravur zählt, andere fällt weg.
static func _weighted_counts(counts: Dictionary, engraving: EngravingDef, factors: Dictionary) -> Dictionary:
	var weighted := {}
	for id: StringName in counts:
		if not engraving.counts_element(id):
			continue
		weighted[id] = float(counts[id]) * float(factors.get(id, 1.0))
	return weighted


static func _compute_spell(main: GemResult, order: Array[GemResult],
		points: PackedVector2Array, result: SpellResult, elements: Array[ElementDef]) -> void:
	var main_engraving := main.placed.engraving
	result.engraving = main_engraving
	for stat: StringName in main_engraving.base_stats:
		result.add_stat(stat, float(main_engraving.base_stats[stat]))

	var factors := {}
	for element in elements:
		factors[element.id] = element.factor

	# Hauptgem: eigene und übertragene Essenzen; Nebengems: nur eigene
	for gr in order:
		var engraving := gr.placed.engraving
		var base := gr.total_base() if gr.is_main() else gr.effective_base
		var counts := _weighted_counts(
			gr.total_elements() if gr.is_main() else gr.effective_elements, engraving, factors)
		gr.points = base
		for count: float in counts.values():
			gr.points += count
		for rule in engraving.rules:
			result.add_stat(rule.stat, rule.evaluate(base, counts))

	for gr in order:
		for effect in gr.placed.engraving.effects:
			if effect != null:
				effect.apply(gr, result)

	var cast_time := result.gem_results.size() * CAST_TIME_PER_GEM - result.get_stat(STAT_CAST_TIME_REDUCTION)
	result.cast_time = maxf(MIN_CAST_TIME, cast_time)
	var mana := FocusGeometry.perimeter(points) * MANA_PER_LENGTH - result.get_stat(STAT_MANA_REDUCTION)
	result.mana_cost = maxf(MIN_MANA, mana)
