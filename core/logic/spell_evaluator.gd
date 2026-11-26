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
##   5. Übertragen     Power Transfer und Multiplikator geben ihr Eingesammeltes an das Hauptgem
##   6. Spell          Regeln der Gravuren, Effekte, Cast-Zeit, Mana
## Essenz unter einem Gem-Stein zählt für niemanden. Radius Expansion löst einen
## zweiten Durchlauf der Phasen 2 bis 6 mit größerem Hauptgem-Radius aus.

const MIN_GEMS := 3
const CAST_TIME_PER_GEM := 1.0
const MIN_CAST_TIME := 0.5
const MANA_PER_LENGTH := 0.05
const MIN_MANA := 1.0

const STAT_CAST_TIME_REDUCTION := &"cast_time_reduction"
const STAT_MANA_REDUCTION := &"mana_reduction"
## Radius Expansion: zusätzlicher Radius des Hauptgems (wirkt im zweiten Durchlauf)
const STAT_RADIUS_BONUS := &"radius_bonus"


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
	_run(focus, points, ccw, result, 0.0)
	# Radius Expansion: zweiter Durchlauf mit größerem Radius des Hauptgems
	var bonus := result.get_stat(STAT_RADIUS_BONUS)
	if bonus > 0.0:
		_run(focus, points, ccw, result, bonus)
		result.stats[STAT_RADIUS_BONUS] = bonus

	result.valid = true
	return result


## Phasen 2 bis 6. `main_bonus` = zusätzlicher Radius des Hauptgems.
static func _run(focus: FocusInstance, points: PackedVector2Array, ccw: bool, result: SpellResult,
		main_bonus: float) -> void:
	result.gem_results.clear()
	result.stats.clear()
	_build_gem_results(focus, points, ccw, result)
	var main := result.gem_results[focus.get_main_gem_index()]
	main.radius_bonus = main_bonus
	var order := _collection_order(result)
	_collect(order, result)
	for gr in result.gem_results:
		gr.apply_multiplier(gr.placed.gem.get_multiplier())
	_transfer(main, result)
	_compute_spell(main, order, points, result)


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
		elif placed.gem.size > placed.engraving.max_size:
			result.errors.append("Die Gravur „%s“ passt nur auf Gems bis Größe %s." % [
				placed.engraving.display_name, GemDef.SIZE_NAMES[placed.engraving.max_size]])
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
	# Essenz unter einem Stein ist verdeckt und zählt für niemanden
	result.blocked.clear()
	for dot in result.dots:
		for gr in order:
			if dot.position.distance_to(gr.placed.position) < gr.placed.gem.body_radius:
				result.blocked.append(dot)
				claimed[dot] = true
				break
	for gr in order:
		var gem := gr.placed.gem
		var center := gr.placed.position

		var candidates: Array[EnergyDot] = []
		for dot in result.dots:
			if claimed.has(dot):
				continue
			if FocusGeometry.in_sector(dot.position, center, gr.get_radius(), gr.sector_start, gr.sector_sweep):
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

## Element-Essenz für eine Gravur: mit dem Faktor der Gravur für dieses Element gewichtet.
## Nur Essenz der Elemente der Gravur zählt, andere fällt weg.
static func _weighted_counts(counts: Dictionary, engraving: EngravingDef) -> Dictionary:
	var weighted := {}
	for id: StringName in counts:
		if engraving.counts_element(id):
			weighted[id] = float(counts[id]) * engraving.factor_of(id)
	return weighted


static func _compute_spell(main: GemResult, order: Array[GemResult],
		points: PackedVector2Array, result: SpellResult) -> void:
	var main_engraving := main.placed.engraving
	result.engraving = main_engraving

	# Hauptgem: eigene und übertragene Essenzen; Nebengems: nur eigene
	for gr in order:
		var engraving := gr.placed.engraving
		# feste Werte der Gravur (Haupt- und Nebengravuren)
		for stat: StringName in engraving.base_stats:
			result.add_stat(stat, float(engraving.base_stats[stat]))
		var base := gr.total_base() if gr.is_main() else gr.effective_base
		var counts := _weighted_counts(
			gr.total_elements() if gr.is_main() else gr.effective_elements, engraving)
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


## Richtwert ohne geschlossenen Kreis (Vorschau beim Setzen): was `engraving` auf `gem` aus
## den Punkten `dots` machen würde. Nächste Punkte zuerst bis zur Kapazität, × Multiplikator
## der Form; der Sektor ist noch unbekannt, daher zählt die ganze Reichweite.
## Gibt {points: float, stats: Dictionary} zurück.
static func estimate(gem: GemDef, engraving: EngravingDef, center: Vector2, dots: Array[EnergyDot]) -> Dictionary:
	var sorted := dots.duplicate()
	sorted.sort_custom(func(a: EnergyDot, b: EnergyDot) -> bool:
		return a.position.distance_squared_to(center) < b.position.distance_squared_to(center))
	var base := 0.0
	var counts := {}
	var element_taken := 0
	for dot: EnergyDot in sorted:
		if dot.is_base():
			if base < gem.max_base:
				base += 1.0
		elif element_taken < gem.max_element:
			element_taken += 1
			counts[dot.element_id] = counts.get(dot.element_id, 0.0) + 1.0
	base *= gem.get_multiplier()
	for id: StringName in counts:
		counts[id] *= gem.get_multiplier()
	var weighted := _weighted_counts(counts, engraving)
	var points := base
	for value: float in weighted.values():
		points += value
	var stats := {}
	for stat: StringName in engraving.base_stats:
		stats[stat] = float(engraving.base_stats[stat])
	for rule in engraving.rules:
		var value := rule.evaluate(base, weighted)
		if not is_zero_approx(value):
			stats[rule.stat] = stats.get(rule.stat, 0.0) + value
	return { points = points, stats = stats }


## Beitrag eines Gems zu den Spell-Werten aus seinen Regeln (Hauptgem inklusive
## Übertragenem), z. B. {&"damage": 33.0, &"burn": 1.0}. Für die Anzeige der Herkunft.
static func gem_contribution(gr: GemResult) -> Dictionary:
	var engraving := gr.placed.engraving
	var base := gr.total_base() if gr.is_main() else gr.effective_base
	var counts := _weighted_counts(gr.total_elements() if gr.is_main() else gr.effective_elements, engraving)
	var out := {}
	for rule in engraving.rules:
		var value := rule.evaluate(base, counts)
		if not is_zero_approx(value):
			out[rule.stat] = out.get(rule.stat, 0.0) + value
	return out
