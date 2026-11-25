extends Node2D
## Debug-Ansicht für M1: zeigt Fokus, Energiepunkte, Einflussbereiche und das
## Auswertungsergebnis. Nur zum Prüfen der Logik, nicht die spätere Grafik.
##
## Bedienung:  Gems mit der Maus ziehen | R = Punkte neu würfeln |
##             M = Hauptgem wechseln (Geschoss/Schild)

const CONTENT := preload("res://content/crafting_content.tres")
const GEM_PICK_RADIUS := 18.0

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
	focus.gems = [
		PlacedGem.create(CONTENT.get_gem(&"hauptgem_geschoss"), Vector2(-120, 80)),
		PlacedGem.create(CONTENT.get_gem(&"nebengem_standard"), Vector2(130, 60)),
		PlacedGem.create(CONTENT.get_gem(&"nebengem_standard"), Vector2(0, -150)),
	]
	focus.loop = PackedInt32Array([0, 1, 2])
	focus.loop_closed = true
	_refresh()


func _refresh() -> void:
	result = SpellEvaluator.evaluate(focus, CONTENT.elements)
	_info.text = "Gems ziehen | R = neu würfeln | M = Hauptgem wechseln\n\n" + result.describe()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragged = _gem_at(to_local(event.position))
		else:
			_dragged = -1
	elif event is InputEventMouseMotion and _dragged >= 0:
		focus.gems[_dragged].position = to_local(event.position)
		_refresh()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				focus.dot_seed = randi()
				_refresh()
			KEY_M:
				_toggle_main_gem()


func _gem_at(local_pos: Vector2) -> int:
	for i in focus.gems.size():
		if focus.gems[i].position.distance_to(local_pos) <= GEM_PICK_RADIUS:
			return i
	return -1


func _toggle_main_gem() -> void:
	var idx := focus.get_main_gem_index()
	if idx < 0:
		return
	var current := focus.gems[idx].gem.id
	var next_id := &"hauptgem_schild" if current == &"hauptgem_geschoss" else &"hauptgem_geschoss"
	focus.gems[idx].gem = CONTENT.get_gem(next_id)
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
		for rr in result.gem_results:
			var color := _element_color(rr.element_id, Color(0.9, 0.9, 0.9))
			var polygon := FocusGeometry.sector_polygon(
				rr.placed.position, rr.placed.gem.radius, rr.sector_start, rr.sector_sweep)
			draw_colored_polygon(polygon, Color(color, 0.12))
			for dot in rr.collected:
				claimed[dot] = true

	# Verbindungen
	var n := focus.loop.size()
	for k in n:
		if k == n - 1 and not focus.loop_closed:
			break
		var a := focus.gems[focus.loop[k]].position
		var b := focus.gems[focus.loop[(k + 1) % n]].position
		draw_line(a, b, Color(0.4, 0.7, 1.0), 3.0)

	# Energiepunkte: eingesammelte hell und größer, freie gedimmt
	for dot in result.dots:
		var color := _element_color(dot.element_id, Color(0.85, 0.85, 0.9))
		if claimed.has(dot):
			draw_circle(dot.position, 3.0, color)
		else:
			draw_circle(dot.position, 2.0, Color(color, 0.35))

	# Gems
	for i in focus.gems.size():
		var placed := focus.gems[i]
		var is_main := placed.gem.role == GemDef.Role.MAIN
		var fill := Color(0.95, 0.95, 0.95)
		if result.valid:
			fill = _element_color(result.gem_results[i].element_id, fill)
		var radius := 14.0 if is_main else 9.0
		draw_circle(placed.position, radius, fill)
		draw_arc(placed.position, radius, 0.0, TAU, 32, Color.BLACK, 2.0)
