class_name FocusCanvas
extends Control
## Zeichenfläche der Werkstatt: zeigt einen Fokus und verarbeitet die Bedienung.
##   Modus SETZEN:     Linksklick = gewählte Rune setzen, Rune ziehen = verschieben,
##                     Rechtsklick auf Rune = entfernen
##   Modus VERBINDEN:  Linksklick auf Runen = verbinden (Start bei der Hauptrune,
##                     Klick auf die Hauptrune schließt den Kreis),
##                     Rechtsklick = letzte Verbindung zurücknehmen
## Die Darstellung skaliert automatisch, sodass der ganze Fokus sichtbar ist.

signal focus_changed
signal message(text: String)

enum Mode { PLACE, CONNECT }

const RUNE_PICK_RADIUS := 16.0   # Bildschirm-Pixel
const MIN_RUNE_DISTANCE := 25.0  # Fokus-Einheiten
const MAIN_RUNE_SIZE := 13.0     # Bildschirm-Pixel
const MINOR_RUNE_SIZE := 9.0

const COLOR_BACKGROUND := Color(0.07, 0.07, 0.11)
const COLOR_FOCUS := Color(0.11, 0.11, 0.18)
const COLOR_FOCUS_EDGE := Color(0.55, 0.55, 0.9)
const COLOR_EDGE := Color(0.45, 0.75, 1.0)
const COLOR_NEUTRAL := Color(0.92, 0.92, 0.95)
const COLOR_BASE_DOT := Color(0.8, 0.8, 0.88)
const COLOR_OK := Color(0.4, 1.0, 0.5)
const COLOR_BAD := Color(1.0, 0.35, 0.35)

var focus: FocusInstance
var result: SpellResult
var content: CraftingContent
var mode: Mode = Mode.PLACE
## In der Bibliothek gewählte Rune (wird im Modus SETZEN platziert).
var placing_rune: RuneDef
var show_sectors := true
var show_radii := false
var show_free_dots := true

var _view_scale := 1.0
var _dragged := -1
var _hovered := -1
var _mouse_inside := false
var _mouse_focus := Vector2.ZERO


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_mouse_inside = true
		NOTIFICATION_MOUSE_EXIT:
			_mouse_inside = false
			_hovered = -1
			queue_redraw()
		NOTIFICATION_RESIZED:
			queue_redraw()


# --- Koordinaten ------------------------------------------------------------

func _update_view() -> void:
	var extent := 1.0
	if focus != null and focus.focus_def != null and focus.focus_def.shape != null:
		for p in focus.focus_def.shape.get_outline():
			extent = maxf(extent, p.length())
	_view_scale = minf(size.x, size.y) / (2.0 * extent + 40.0)


func to_focus(screen_pos: Vector2) -> Vector2:
	return (screen_pos - size / 2.0) / _view_scale


func to_screen(focus_pos: Vector2) -> Vector2:
	return size / 2.0 + focus_pos * _view_scale


func _rune_at(screen_pos: Vector2) -> int:
	for i in range(focus.runes.size() - 1, -1, -1):
		if to_screen(focus.runes[i].position).distance_to(screen_pos) <= RUNE_PICK_RADIUS:
			return i
	return -1


# --- Eingabe ----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if focus == null:
		return
	_update_view()

	if event is InputEventMouseMotion:
		_mouse_focus = to_focus(event.position)
		if _dragged >= 0:
			_move_rune(_dragged, _mouse_focus)
		else:
			_hovered = _rune_at(event.position)
		queue_redraw()
		return

	if not event is InputEventMouseButton:
		return
	var button := event as InputEventMouseButton

	if not button.pressed:
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragged = -1
		return

	var idx := _rune_at(button.position)
	if button.button_index == MOUSE_BUTTON_LEFT:
		if mode == Mode.PLACE:
			if idx >= 0:
				_dragged = idx
			elif placing_rune != null:
				_try_place(placing_rune, to_focus(button.position))
		elif idx >= 0:
			_try_connect(idx)
		accept_event()
	elif button.button_index == MOUSE_BUTTON_RIGHT:
		if mode == Mode.PLACE and idx >= 0:
			remove_rune(idx)
		elif mode == Mode.CONNECT:
			undo_connection()
		accept_event()


# --- Runen setzen / verschieben / entfernen --------------------------------

func _too_close(pos: Vector2, ignore: int) -> bool:
	for i in focus.runes.size():
		if i != ignore and focus.runes[i].position.distance_to(pos) < MIN_RUNE_DISTANCE:
			return true
	return false


func _try_place(rune: RuneDef, pos: Vector2) -> void:
	var def := focus.focus_def
	var has_main := focus.get_main_rune_index() >= 0
	if not def.shape.contains(pos):
		message.emit("Die Rune muss innerhalb des Fokus liegen.")
	elif focus.runes.size() >= def.max_runes:
		message.emit("Dieser Fokus fasst höchstens %d Runen." % def.max_runes)
	elif rune.role == RuneDef.Role.MAIN and has_main:
		message.emit("Es gibt bereits eine Hauptrune.")
	elif rune.role == RuneDef.Role.MINOR and not has_main:
		message.emit("Setze zuerst eine Hauptrune.")
	elif _too_close(pos, -1):
		message.emit("Zu nah an einer anderen Rune.")
	else:
		focus.runes.append(PlacedRune.create(rune, pos))
		# Neue Rune ist noch nicht verbunden -> Kreis wieder öffnen.
		focus.loop_closed = false
		focus_changed.emit()


func _move_rune(idx: int, pos: Vector2) -> void:
	if not focus.focus_def.shape.contains(pos) or _too_close(pos, idx):
		return
	focus.runes[idx].position = pos
	focus_changed.emit()


func remove_rune(idx: int) -> void:
	# Kreis bis vor die entfernte Rune behalten, Indizes nachrücken.
	var new_loop := PackedInt32Array()
	for loop_idx in focus.loop:
		if loop_idx == idx:
			break
		new_loop.append(loop_idx - 1 if loop_idx > idx else loop_idx)
	focus.loop = new_loop
	focus.loop_closed = false
	focus.runes.remove_at(idx)
	_dragged = -1
	_hovered = -1
	focus_changed.emit()


func clear_runes() -> void:
	focus.runes.clear()
	clear_loop()


# --- Verbinden --------------------------------------------------------------

func _last_in_loop() -> int:
	return focus.loop[focus.loop.size() - 1] if not focus.loop.is_empty() else -1


## Leer = Verbindung zu `idx` ist erlaubt, sonst der Grund.
func connect_error(idx: int) -> String:
	if focus.loop_closed:
		return "Der Kreis ist geschlossen. Rechtsklick nimmt die letzte Verbindung zurück."
	if focus.loop.is_empty():
		if focus.runes[idx].rune.role == RuneDef.Role.MAIN:
			return ""
		return "Der Kreis beginnt bei der Hauptrune."
	var last := _last_in_loop()
	if idx == last:
		return "Das ist die aktuelle Rune."
	if idx == focus.loop[0]:
		if focus.loop.size() < SpellEvaluator.MIN_RUNES:
			return "Zum Schließen braucht der Kreis mindestens %d Runen." % SpellEvaluator.MIN_RUNES
	elif focus.loop.has(idx):
		return "Diese Rune ist bereits verbunden."
	if _edge_crosses(focus.runes[last].position, focus.runes[idx].position, last, idx):
		return "Verbindungen dürfen sich nicht kreuzen."
	return ""


func _edge_crosses(a: Vector2, b: Vector2, a_idx: int, b_idx: int) -> bool:
	for k in focus.loop.size() - 1:
		var e1 := focus.loop[k]
		var e2 := focus.loop[k + 1]
		if e1 == a_idx or e1 == b_idx or e2 == a_idx or e2 == b_idx:
			continue
		if Geometry2D.segment_intersects_segment(a, b, focus.runes[e1].position, focus.runes[e2].position) != null:
			return true
	return false


func _try_connect(idx: int) -> void:
	var error := connect_error(idx)
	if error != "":
		message.emit(error)
		return
	if not focus.loop.is_empty() and idx == focus.loop[0]:
		focus.loop_closed = true
	else:
		focus.loop.append(idx)
	focus_changed.emit()


func undo_connection() -> void:
	if focus.loop_closed:
		focus.loop_closed = false
	elif not focus.loop.is_empty():
		focus.loop.remove_at(focus.loop.size() - 1)
	else:
		return
	focus_changed.emit()


func clear_loop() -> void:
	focus.loop = PackedInt32Array()
	focus.loop_closed = false
	focus_changed.emit()


# --- Zeichnen ---------------------------------------------------------------

func _element_color(element_id: StringName, fallback: Color) -> Color:
	if content != null and element_id != &"":
		var element := content.get_element(element_id)
		if element != null:
			return element.color
	return fallback


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BACKGROUND)
	if focus == null or focus.focus_def == null or focus.focus_def.shape == null:
		return
	_update_view()
	var px := 1.0 / _view_scale  # ein Bildschirm-Pixel in Fokus-Einheiten
	draw_set_transform(size / 2.0, 0.0, Vector2(_view_scale, _view_scale))

	# Fokus
	var outline := focus.focus_def.shape.get_outline()
	draw_colored_polygon(outline, COLOR_FOCUS)
	var closed_outline := outline.duplicate()
	closed_outline.append(outline[0])
	draw_polyline(closed_outline, COLOR_FOCUS_EDGE, 2.0 * px, true)

	var valid := result != null and result.valid
	var claimed := {}

	# Einflussbereiche
	if valid:
		for rr in result.rune_results:
			for dot in rr.collected:
				claimed[dot] = true
			if not show_sectors or rr.sector_sweep < 0.01:
				continue
			var color := _element_color(rr.element_id, COLOR_NEUTRAL)
			var polygon := FocusGeometry.sector_polygon(
				rr.placed.position, rr.placed.rune.radius, rr.sector_start, rr.sector_sweep, 48)
			draw_colored_polygon(polygon, Color(color, 0.13))
			var border := polygon.duplicate()
			border.append(polygon[0])
			draw_polyline(border, Color(color, 0.45), 1.0 * px, true)

	# Reichweite (immer, solange noch kein gültiger Spell besteht)
	if show_radii or not valid:
		for placed in focus.runes:
			draw_arc(placed.position, placed.rune.radius, 0.0, TAU, 64, Color(1, 1, 1, 0.18), 1.0 * px, true)

	# Verbindungen
	var n := focus.loop.size()
	for k in n:
		if k == n - 1 and not focus.loop_closed:
			break
		var a := focus.runes[focus.loop[k]].position
		var b := focus.runes[focus.loop[(k + 1) % n]].position
		draw_line(a, b, COLOR_EDGE, 3.0 * px, true)

	# Gummiband beim Verbinden
	if mode == Mode.CONNECT and _mouse_inside and n > 0 and not focus.loop_closed:
		var from := focus.runes[_last_in_loop()].position
		var to := _mouse_focus
		var band_color := Color(1, 1, 1, 0.4)
		if _hovered >= 0:
			to = focus.runes[_hovered].position
			band_color = COLOR_OK if connect_error(_hovered) == "" else COLOR_BAD
		elif _edge_crosses(from, to, _last_in_loop(), -1):
			band_color = COLOR_BAD
		draw_line(from, to, band_color, 2.0 * px, true)

	# Energiepunkte
	if result != null:
		for dot in result.dots:
			var color := _element_color(dot.element_id, COLOR_BASE_DOT)
			if claimed.has(dot):
				draw_circle(dot.position, 3.2 * px, color, true, -1.0, true)
			elif show_free_dots:
				draw_circle(dot.position, 2.2 * px, Color(color, 0.4), true, -1.0, true)

	# Vorschau der gewählten Rune
	if mode == Mode.PLACE and placing_rune != null and _mouse_inside and _dragged < 0 and _hovered < 0:
		var ghost_ok := focus.focus_def.shape.contains(_mouse_focus) and not _too_close(_mouse_focus, -1)
		var ghost_color := Color(COLOR_OK if ghost_ok else COLOR_BAD, 0.5)
		draw_arc(_mouse_focus, placing_rune.radius, 0.0, TAU, 64, ghost_color, 1.0 * px, true)
		var ghost_size := MAIN_RUNE_SIZE if placing_rune.role == RuneDef.Role.MAIN else MINOR_RUNE_SIZE
		draw_circle(_mouse_focus, ghost_size * px, ghost_color, true, -1.0, true)

	# Runen
	for i in focus.runes.size():
		var placed := focus.runes[i]
		var is_main := placed.rune.role == RuneDef.Role.MAIN
		var fill := COLOR_NEUTRAL
		if valid:
			fill = _element_color(result.rune_results[i].element_id, COLOR_NEUTRAL)
		var radius := (MAIN_RUNE_SIZE if is_main else MINOR_RUNE_SIZE) * px
		draw_circle(placed.position, radius, fill, true, -1.0, true)
		var ring := Color.BLACK
		if i == _dragged or i == _hovered:
			ring = Color(1, 0.9, 0.3)
		elif focus.loop.has(i):
			ring = COLOR_EDGE
		draw_arc(placed.position, radius, 0.0, TAU, 32, ring, 2.5 * px, true)

	# Beschriftung in Bildschirm-Koordinaten (Platzierungsreihenfolge)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var font := get_theme_default_font()
	var minor_number := 0
	for i in focus.runes.size():
		var is_main := focus.runes[i].rune.role == RuneDef.Role.MAIN
		if not is_main:
			minor_number += 1
		var label := "H" if is_main else str(minor_number)
		draw_string(font, to_screen(focus.runes[i].position) + Vector2(12, -10), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.85))
