class_name TestSuite
extends RefCounted
## Basis der Test-Sammlungen in tests/suites/: Prüfungen und gemeinsame Helfer.
## Jede Methode `test_*` einer Sammlung wird vom Runner (tests/run_tests.gd) aufgerufen.

const MAIN := GemDef.Role.MAIN
const MINOR := GemDef.Role.MINOR
const SPITZ := GemDef.Angle.SPITZ
const GROB := GemDef.Angle.GROB

## Labor-Aufbau (siehe `lab`): Hauptgem bei (0,0), Test-Gem bei (300,0), Füllgem bei (0,400).
## Richtungen für Punkte: Hauptgem innen 45°, außen 225°; Test-Gem innen 153°, außen 270°.
const MAIN_POS := Vector2(0, 0)
const MAIN_INNER := 45.0
const MAIN_OUTER := 225.0
const MINOR_POS := Vector2(300, 0)
const MINOR_INNER := 153.0
const MINOR_OUTER := 270.0

var content: CraftingContent
## Für Tests, die Nodes in den Baum hängen.
var tree: SceneTree
var checks := 0
var failures := 0
## Name des laufenden Tests (für Fehlermeldungen)
var current := ""


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FEHLER [%s]: %s" % [current, message])


func check_stat(r: SpellResult, stat: StringName, expected: float) -> void:
	check(is_equal_approx(r.get_stat(stat), expected), "%s: erwartet %s, war %s" % [stat, expected, r.get_stat(stat)])



func make_gem(role: GemDef.Role, angle: GemDef.Angle, radius: float,
		max_element := 100, max_base := 100) -> GemDef:
	var gem := GemDef.new()
	gem.id = &"test"
	gem.display_name = "Testgem"
	gem.role = role
	gem.angle = angle
	gem.radius = radius
	gem.max_element = max_element
	gem.max_base = max_base
	return gem


## Gravur ohne Wirkung (für Tests, in denen es nur ums Einsammeln geht).
func plain_engraving(role: GemDef.Role) -> EngravingDef:
	var engraving := EngravingDef.new()
	engraving.display_name = "Testgravur"
	engraving.role = role
	return engraving


func engraving(id: StringName) -> EngravingDef:
	return content.get_engraving(id)


## Platziert ein Gem; ohne Gravur bekommt es eine wirkungslose der passenden Rolle.
func place(gem: GemDef, pos: Vector2, p_engraving: EngravingDef = null) -> PlacedGem:
	return PlacedGem.create(gem, p_engraving if p_engraving != null else plain_engraving(gem.role), pos)


func make_focus(placed: Array[PlacedGem], loop: Array[int], closed := true) -> FocusInstance:
	var def := FocusDef.new()
	var shape := CircleFocusShape.new()
	shape.radius = 1000.0
	def.shape = shape
	def.max_gems = 10
	def.max_dots = 2000
	def.max_element_dots = 1000
	var focus := FocusInstance.new()
	focus.focus_def = def
	focus.gems = placed
	focus.loop = PackedInt32Array(loop)
	focus.loop_closed = closed
	return focus


## Punkte auf einer Linie ab `center` in Richtung `angle_deg` (Abstand 10, 14, 18, ...).
func dots_line(center: Vector2, angle_deg: float, count: int, element: StringName = &"") -> Array[EnergyDot]:
	var dots: Array[EnergyDot] = []
	for i in count:
		dots.append(EnergyDot.new(center + Vector2.from_angle(deg_to_rad(angle_deg)) * (10.0 + 4.0 * i), element))
	return dots


## Standard-Dreieck: Hauptgem oben, zwei Nebengems unten.
func triangle(main_angle: GemDef.Angle, main_radius: float) -> FocusInstance:
	var placed: Array[PlacedGem] = [
		place(make_gem(MAIN, main_angle, main_radius), Vector2(0, -100)),
		place(make_gem(MINOR, GROB, 50), Vector2(-100, 80)),
		place(make_gem(MINOR, GROB, 50), Vector2(100, 80)),
	]
	return make_focus(placed, [0, 1, 2])


func lab(main_gem: GemDef, main_engraving: EngravingDef,
		minor_gem: GemDef, minor_engraving: EngravingDef) -> FocusInstance:
	var placed: Array[PlacedGem] = [
		place(main_gem, MAIN_POS, main_engraving),
		place(minor_gem, MINOR_POS, minor_engraving),
		place(make_gem(MINOR, GROB, 10), Vector2(0, 400)),
	]
	return make_focus(placed, [0, 1, 2])


func evaluate(focus: FocusInstance, dots: Array[EnergyDot] = []) -> SpellResult:
	return SpellEvaluator.evaluate(focus, content.elements, dots)


## Auswertung mit den Punkten aus dem Seed des Fokus.
func evaluate_real(focus: FocusInstance) -> SpellResult:
	return SpellEvaluator.evaluate(focus, content.elements)


func _content_triangle(def: FocusDef, a: Vector2, b: Vector2, c: Vector2) -> FocusInstance:
	var focus := FocusInstance.new()
	focus.focus_def = def
	var standard := engraving(&"standard")
	focus.gems = [
		PlacedGem.create(content.get_gem(&"hauptgem_mittel_grob"), engraving(&"magischer_bolzen"), a),
		PlacedGem.create(content.get_gem(&"nebengem_mittel_grob"), standard, b),
		PlacedGem.create(content.get_gem(&"nebengem_mittel_grob"), standard, c),
	]
	focus.loop = PackedInt32Array([0, 1, 2])
	focus.loop_closed = true
	return focus


func _has_error(result: SpellResult, fragment: String) -> bool:
	for error in result.errors:
		if error.contains(fragment):
			return true
	return false


# --- Werkstatt ----------------------------------------------------------------

func place_on(canvas: FocusCanvas, gem: GemDef, pos: Vector2, p_engraving: EngravingDef = null) -> void:
	if p_engraving != null:
		canvas.placing_engraving = p_engraving
	else:
		canvas.placing_engraving = engraving(&"magischer_bolzen") if gem.role == MAIN else engraving(&"standard")
	canvas._try_place(gem, pos)


# --- Kampf --------------------------------------------------------------------

func make_spell(stats: Dictionary, cast_time := 1.0, mana_cost := 10.0,
		target: EngravingDef.Target = EngravingDef.Target.ENEMY) -> SpellResult:
	var spell := SpellResult.new()
	spell.valid = true
	spell.cast_time = cast_time
	spell.mana_cost = mana_cost
	spell.engraving = EngravingDef.new()
	spell.engraving.role = MAIN
	spell.engraving.target = target
	for stat: StringName in stats:
		spell.stats[stat] = float(stats[stat])
	return spell


func make_mage(p_name: String, spells: Array[SpellResult]) -> CombatMage:
	var mage := CombatMage.new()
	mage.mage_name = p_name
	for i in spells.size():
		mage.add_spell(spells[i], "Spell %d" % (i + 1))
	return mage


func duel(a_spells: Array[SpellResult], b_spells: Array[SpellResult], seed_value := 1) -> Combat:
	return Combat.new(make_mage("A", a_spells), make_mage("B", b_spells), CombatRules.new(), seed_value)
