extends Node2D
## Debug-Ansicht für M1: zeigt Fokus, Energiepunkte, Einflussbereiche und das
## Auswertungsergebnis. Nur zum Prüfen der Logik, nicht die spätere Grafik.
##
## Bedienung:  Runen mit der Maus ziehen | R = Punkte neu würfeln |
##             M = Hauptrune wechseln (Geschoss/Schild)

const CONTENT := preload("res://content/crafting_content.tres")
const RUNE_PICK_RADIUS := 18.0

var focus: FocusInstance
var result: SpellResult
var _dragged := -1

@onready var _info: Label = $UI/Info


func _ready() -> void:
	position = Vector2(300, 324)
	focus = FocusInstance.new()
	focus.focus_def = CONTENT.get_focus(&"kleiner_fokus")
	focus.base_count = 100
	focus.element_fill = {&"fire": 25, &"air": 15}
	focus.dot_seed = 1234
	focus.runes = [
		PlacedRune.create(CONTENT.get_rune(&"hauptrune_geschoss"), Vector2(-120, 80)),
		PlacedRune.create(CONTENT.get_rune(&"zusatzrune_standard"), Vector2(130, 60)),
		PlacedRune.create(CONTENT.get_rune(&"zusatzrune_standard"), Vector2(0, -150)),
	]
	focus.loop = PackedInt32Array([0, 1, 2])
	focus.loop_closed = true
	_refresh()


func _refresh() -> void:
	result = SpellEvaluator.evaluate(focus, CONTENT.elements)
	_info.text = "Runen ziehen | R = neu würfeln | M = Hauptrune wechseln\n\n" + result.describe()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragged = _rune_at(to_local(event.position))
		else:
			_dragged = -1
	elif event is InputEventMouseMotion and _dragged >= 0:
		focus.runes[_dragged].position = to_local(event.position)
		_refresh()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				focus.dot_seed = randi()
				_refresh()
			KEY_M:
				_toggle_main_rune()


func _rune_at(local_pos: Vector2) -> int:
	for i in focus.runes.size():
		if focus.runes[i].position.distance_to(local_pos) <= RUNE_PICK_RADIUS:
			return i
	return -1


func _toggle_main_rune() -> void:
	var idx := focus.get_main_rune_index()
	if idx < 0:
		return
	var current := focus.runes[idx].rune.id
	var next_id := &"hauptrune_schild" if current == &"hauptrune_geschoss" else &"hauptrune_geschoss"
	focus.runes[idx].rune = CONTENT.get_rune(next_id)
	_refresh()


func _element_color(element_id: StringName, fallback: Color) -> Color:
	var element := CONTENT.get_element(element_id)
	return element.color if element != null else fallback


func _draw() -> void:
	var shape := focus.focus_def.shape
	var outline := shape.get_outline()
	outline.append(outline[0])
	draw_polyline(outline, Color(0.6, 0.6, 0.8), 2.0)

	# Einflussbereiche
	var claimed := {}
	if result.valid:
		for rr in result.rune_results:
			var color := _element_color(rr.element_id, Color(0.9, 0.9, 0.9))
			var polygon := FocusGeometry.sector_polygon(
				rr.placed.position, rr.placed.rune.radius, rr.sector_start, rr.sector_sweep)
			draw_colored_polygon(polygon, Color(color, 0.12))
			for dot in rr.collected:
				claimed[dot] = true

	# Verbindungen
	var n := focus.loop.size()
	for k in n:
		if k == n - 1 and not focus.loop_closed:
			break
		var a := focus.runes[focus.loop[k]].position
		var b := focus.runes[focus.loop[(k + 1) % n]].position
		draw_line(a, b, Color(0.4, 0.7, 1.0), 3.0)

	# Energiepunkte: eingesammelte hell und größer, freie gedimmt
	for dot in result.dots:
		var color := _element_color(dot.element_id, Color(0.85, 0.85, 0.9))
		if claimed.has(dot):
			draw_circle(dot.position, 3.0, color)
		else:
			draw_circle(dot.position, 2.0, Color(color, 0.35))

	# Runen
	for i in focus.runes.size():
		var placed := focus.runes[i]
		var is_main := placed.rune.role == RuneDef.Role.MAIN
		var fill := Color(0.95, 0.95, 0.95)
		if result.valid:
			fill = _element_color(result.rune_results[i].element_id, fill)
		var radius := 14.0 if is_main else 9.0
		draw_circle(placed.position, radius, fill)
		draw_arc(placed.position, radius, 0.0, TAU, 32, Color.BLACK, 2.0)
