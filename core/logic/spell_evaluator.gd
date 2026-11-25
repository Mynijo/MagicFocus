class_name SpellEvaluator
extends RefCounted
## Wertet einen Fokus zu einem Spell aus. Reine Logik ohne Physik und ohne Szene,
## damit sie auch in der Werkstatt-Vorschau und später im Kampf (headless) läuft.
##
## Phasen:
##   1. Prüfen        Gem-Anzahl, genau ein Hauptgem, geschlossener Kreis, keine Kreuzung
##   2. Bereiche      Einflusssektor jedem Gem (Radius + Innen/Außen/beides)
##   3. Einsammeln    Hauptgem zuerst, dann kleine Gems in Platzierungsreihenfolge;
##                    jede nimmt die nächsten freien Punkte bis zu ihrer Kapazität
##   4. Effekte       Spezial-Gems (Schnittstelle, in M1 leer)
##   5. Elemente      häufigstes Element je Gem (ab `threshold` Punkten)
##   6. Spell         Form, Element, Werte, Cast-Zeit, Mana

const MIN_GEMS := 3
## Vorläufiger Standard; in der Werkstatt einstellbar (Balancing noch offen).
const ELEMENT_THRESHOLD := 4
const CAST_TIME_PER_GEM := 1.0
const MIN_CAST_TIME := 0.5
const MANA_PER_LENGTH := 0.1

const STAT_CAST_TIME_REDUCTION := &"cast_time_reduction"


## `elements` legt auch die Reihenfolge bei Gleichstand fest.
## `dots` ist optional (für Tests); sonst werden sie aus dem Fokus erzeugt.
## `threshold` = Mindestanzahl Punkte, ab der ein Gem ein Element annimmt.
static func evaluate(focus: FocusInstance, elements: Array[ElementDef],
		dots: Variant = null, threshold: int = ELEMENT_THRESHOLD) -> SpellResult:
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
	_apply_effects(order, result)
	_assign_elements(result, elements, threshold)
	if not _compute_spell(focus, elements, points, result):
		return result

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

	if focus.base_count > def.max_base_dots:
		result.errors.append("Zu viele Energiepunkte (%d / %d)." % [focus.base_count, def.max_base_dots])
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
		var rr := GemResult.new()
		rr.index = i
		rr.placed = focus.gems[i]
		result.gem_results.append(rr)

	var n := points.size()
	for k in n:
		var rr := result.gem_results[focus.loop[k]]
		var sector := FocusGeometry.sector_for(
			points[(k - 1 + n) % n], points[k], points[(k + 1) % n], rr.placed.gem.area, ccw)
		rr.sector_start = sector.x
		rr.sector_sweep = sector.y


# --- Phase 3 ---------------------------------------------------------------

## Hauptgem zuerst, danach kleine Gems in Platzierungsreihenfolge.
static func _collection_order(result: SpellResult) -> Array[GemResult]:
	var order := result.gem_results.duplicate()
	order.sort_custom(func(a: GemResult, b: GemResult) -> bool:
		if a.is_main() != b.is_main():
			return a.is_main()
		return a.index < b.index)
	return order


static func _collect(order: Array[GemResult], result: SpellResult) -> void:
	var claimed := {}
	for rr in order:
		var gem := rr.placed.gem
		var center := rr.placed.position

		var candidates: Array[EnergyDot] = []
		for dot in result.dots:
			if claimed.has(dot):
				continue
			if FocusGeometry.in_sector(dot.position, center, gem.radius, rr.sector_start, rr.sector_sweep):
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
			rr.add_dot(dot)
			claimed[dot] = true


# --- Phase 4 ---------------------------------------------------------------

static func _apply_effects(order: Array[GemResult], result: SpellResult) -> void:
	for rr in order:
		for effect in rr.placed.gem.effects:
			if effect != null:
				effect.apply(rr, result)


# --- Phase 5 ---------------------------------------------------------------

static func _assign_elements(result: SpellResult, elements: Array[ElementDef],
		threshold: int) -> void:
	for rr in result.gem_results:
		var best_id: StringName = &""
		var best_count := 0
		for element in elements:
			var count: int = rr.element_counts.get(element.id, 0)
			# strikt größer: bei Gleichstand gewinnt das zuerst gelistete Element
			if count > best_count:
				best_count = count
				best_id = element.id
		rr.element_id = best_id if best_count >= maxi(1, threshold) else &""


# --- Phase 6 ---------------------------------------------------------------

static func _compute_spell(focus: FocusInstance, elements: Array[ElementDef],
		points: PackedVector2Array, result: SpellResult) -> bool:
	var main := result.gem_results[focus.get_main_gem_index()]
	var form := main.placed.gem.spell_form
	if form == null:
		result.errors.append("Das Hauptgem hat keine Spell-Form.")
		return false

	result.form = form
	result.element_id = main.element_id

	for stat: StringName in form.base_stats:
		result.add_stat(stat, float(form.base_stats[stat]))

	# Haupt-Spell: farbige Punkte dem Hauptgem, Basispunkte aller Gems
	var total_base := 0
	for rr in result.gem_results:
		total_base += rr.base_count
	var main_strength := main.placed.gem.strength
	for rule in form.scaling_rules:
		result.add_stat(rule.stat, rule.evaluate(total_base, main.element_counts, main.element_id) * main_strength)

	var elements_by_id := {}
	for element in elements:
		elements_by_id[element.id] = element

	for rr in result.gem_results:
		var gem := rr.placed.gem
		for rule in gem.extra_rules:
			result.add_stat(rule.stat, rule.evaluate(rr.base_count, rr.element_counts, rr.element_id) * gem.strength)
		# Kleine Gems verbessern den Spell über ihr Element
		if rr.is_main() or rr.element_id == &"" or not gem.use_element_rules:
			continue
		var element: ElementDef = elements_by_id.get(rr.element_id)
		if element == null:
			continue
		for rule in element.minor_rules:
			result.add_stat(rule.stat, rule.evaluate(rr.base_count, rr.element_counts, rr.element_id) * gem.strength)

	var reduction := result.get_stat(STAT_CAST_TIME_REDUCTION)
	result.cast_time = maxf(MIN_CAST_TIME, focus.gems.size() * CAST_TIME_PER_GEM - reduction)
	result.mana_cost = FocusGeometry.perimeter(points) * MANA_PER_LENGTH
	return true
