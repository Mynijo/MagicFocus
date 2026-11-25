class_name FocusCanvas
extends Control
## Zeichenfläche der Werkstatt: zeigt einen Fokus und verarbeitet die Bedienung.
##   In beiden Modi:   Rune gedrückt halten und ziehen = verschieben
##   Modus SETZEN:     Linksklick = gewählte Rune setzen (mit Live-Vorschau),
##                     Rechtsklick auf Rune = entfernen
##   Modus VERBINDEN:  Klick auf Runen = verbinden (Start bei der Hauptrune,
##                     Klick auf die Hauptrune schließt den Kreis),
##                     Rechtsklick = letzte Verbindung zurücknehmen
## Mit `auto_connect` wird jede neue Rune mit der zuvor gesetzten verbunden und
## der Kreis ab MIN_RUNES Runen automatisch zur Hauptrune geschlossen.

signal focus_changed
signal message(text: String)
## Neue Vorschau beim Setzen (null = keine Vorschau).
signal preview_changed(preview: SpellResult)
signal drag_started
signal drag_ended

enum Mode { PLACE, CONNECT }

const RUNE_PICK_RADIUS := 16.0   # Bildschirm-Pixel
const DRAG_THRESHOLD := 5.0      # Bildschirm-Pixel, ab denen ein Klick zum Ziehen wird
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
const COLOR_PREVIEW := Color(1.0, 0.95, 0.6)

var focus: FocusInstance
var result: SpellResult
var content: CraftingContent
var mode: Mode = Mode.PLACE
## In der Bibliothek gewählte Rune (wird im Modus SETZEN platziert).
var placing_rune: RuneDef
var auto_connect := true
## Wertet einen (hypothetischen) Fokus aus: func(FocusInstance) -> SpellResult.
## Wird für die Vorschau beim Setzen benutzt.
var evaluate_preview: Callable
var show_sectors := true
var show_radii := false
var show_free_dots := true

var _view_scale := 1.0
var _pressed := -1          # Rune unter dem Mauszeiger beim Drücken
var _press_screen := Vector2.ZERO
var _dragging := false
var _hovered := -1
var _mouse_inside := false
var _mouse_focus := Vector2.ZERO

# Vorschau beim Setzen
var _preview: SpellResult
var _preview_index := -1
var _preview_error := ""


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_mouse_inside = true
		NOTIFICATION_MOUSE_EXIT:
			_mouse_inside = false
			_hovered = -1
			update_preview()
			queue_redraw()
		NOTIFICATION_RESIZED:
			queue_redraw()


# --- Koordinaten ------------------------------------------------------------

func _update_view() -> void:
	var extent := 1.0
	if focus != null and focus.focus_def != null and focus.focus_def.shape != null:
		for p in focus.focus_def.shape.get_outline():
			extent = maxf(extent, p.length())
	# Untergrenze verhindert Division durch 0, solange die Fläche noch keine Größe hat
	_view_scale = maxf(minf(size.x, size.y) / (2.0 * extent + 40.0), 0.001)


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
		if _pressed >= 0 and not _dragging and event.position.distance_to(_press_screen) > DRAG_THRESHOLD:
			_dragging = true
			drag_started.emit()
		if _dragging:
			_move_rune(_pressed, _mouse_focus)
		else:
			_hovered = _rune_at(event.position)
		update_preview()
		queue_redraw()
		return

	if not event is InputEventMouseButton:
		return
	var button := event as InputEventMouseButton

	if button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			var idx := _rune_at(button.position)
			if idx >= 0:
				_pressed = idx
				_press_screen = button.position
				_dragging = false
			elif mode == Mode.PLACE and placing_rune != null:
				_try_place(placing_rune, to_focus(button.position))
		else:
			# Loslassen ohne Ziehen = Klick auf die Rune
			if _pressed >= 0 and not _dragging and mode == Mode.CONNECT:
				_try_connect(_pressed)
			var was_dragging := _dragging
			_pressed = -1
			_dragging = false
			if was_dragging:
				drag_ended.emit()
			update_preview()
		accept_event()
	elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		var idx := _rune_at(button.position)
		if mode == Mode.PLACE and idx >= 0:
			remove_rune(idx)
		elif mode == Mode.CONNECT:
			undo_connection()
		accept_event()


# --- Runen setzen / verschieben / entfernen --------------------------------

func _too_close(target: FocusInstance, pos: Vector2, ignore: int) -> bool:
	for i in target.runes.size():
		if i != ignore and target.runes[i].position.distance_to(pos) < MIN_RUNE_DISTANCE:
			return true
	return false


## Leer = Rune darf hier gesetzt werden, sonst der Grund.
func place_error(rune: RuneDef, pos: Vector2) -> String:
	var def := focus.focus_def
	var has_main := focus.get_main_rune_index() >= 0
	if not def.shape.contains(pos):
		return "Die Rune muss innerhalb des Fokus liegen."
	if focus.runes.size() >= def.max_runes:
		return "Dieser Fokus fasst höchstens %d Runen." % def.max_runes
	if rune.role == RuneDef.Role.MAIN and has_main:
		return "Es gibt bereits eine Hauptrune."
	if rune.role == RuneDef.Role.MINOR and not has_main:
		return "Setze zuerst eine Hauptrune."
	if _too_close(focus, pos, -1):
		return "Zu nah an einer anderen Rune."
	return ""


func _try_place(rune: RuneDef, pos: Vector2) -> void:
	var error := place_error(rune, pos)
	if error != "":
		message.emit(error)
		return
	_insert_rune(focus, rune, pos)
	focus_changed.emit()


## Fügt eine Rune hinzu und verbindet sie (bei `auto_connect`) mit der zuvor gesetzten.
## Wird auch für die Vorschau auf einer Kopie des Fokus benutzt.
func _insert_rune(target: FocusInstance, rune: RuneDef, pos: Vector2) -> void:
	target.runes.append(PlacedRune.create(rune, pos))
	var idx := target.runes.size() - 1
	if not auto_connect:
		target.loop_closed = false
		return

	if rune.role == RuneDef.Role.MAIN:
		# Hauptrune vorne, vorhandene Zusatzrunen in Setz-Reihenfolge dahinter
		var new_loop := PackedInt32Array([idx])
		for i in idx:
			new_loop.append(i)
		target.loop = new_loop
	elif not target.loop.is_empty():
		# Bei geschlossenem Kreis landet die Rune vor der schließenden Kante.
		target.loop.append(idx)
	target.loop_closed = target.loop.size() >= SpellEvaluator.MIN_RUNES \
		and target.loop.size() == target.runes.size()


func _move_rune(idx: int, pos: Vector2) -> void:
	if not focus.focus_def.shape.contains(pos) or _too_close(focus, pos, idx):
		return
	focus.runes[idx].position = pos
	focus_changed.emit()


func remove_rune(idx: int) -> void:
	var removed_main := focus.runes[idx].rune.role == RuneDef.Role.MAIN
	var new_loop := PackedInt32Array()
	if not removed_main:
		# Nachbarn der entfernten Rune werden direkt verbunden, Indizes rücken nach.
		for loop_idx in focus.loop:
			if loop_idx != idx:
				new_loop.append(loop_idx - 1 if loop_idx > idx else loop_idx)
	focus.loop = new_loop
	focus.loop_closed = focus.loop_closed and new_loop.size() >= SpellEvaluator.MIN_RUNES \
		and new_loop.size() == focus.runes.size() - 1
	focus.runes.remove_at(idx)
	_pressed = -1
	_dragging = false
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
	var from := focus.runes[last].position
	var to := focus.runes[idx].position
	if _edge_crosses(from, to, last, idx):
		return "Verbindungen dürfen sich nicht kreuzen."
	if not focus.focus_def.shape.contains_segment(from, to):
		return "Die Verbindung muss innerhalb des Fokus verlaufen."
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


## Kanten des Kreises als Paare von Rune-Indizes.
func _loop_edges() -> Array[Vector2i]:
	var edges: Array[Vector2i] = []
	var n := focus.loop.size()
	for k in n:
		if k == n - 1 and not focus.loop_closed:
			break
		edges.append(Vector2i(focus.loop[k], focus.loop[(k + 1) % n]))
	return edges


## Indizes der Kanten, die eine andere (nicht benachbarte) Kante schneiden.
func _crossing_edges(edges: Array[Vector2i]) -> Dictionary:
	var crossing := {}
	for i in edges.size():
		for j in range(i + 1, edges.size()):
			var a := edges[i]
			var b := edges[j]
			if a.x == b.x or a.x == b.y or a.y == b.x or a.y == b.y:
				continue
			if Geometry2D.segment_intersects_segment(
					focus.runes[a.x].position, focus.runes[a.y].position,
					focus.runes[b.x].position, focus.runes[b.y].position) != null:
				crossing[i] = true
				crossing[j] = true
	return crossing


# --- Vorschau beim Setzen ---------------------------------------------------

func _clear_preview() -> void:
	_preview = null
	_preview_index = -1
	_preview_error = ""


## Berechnet, was die gewählte Rune an der Mausposition einsammeln würde,
## und meldet das Ergebnis über `preview_changed`.
func update_preview() -> void:
	_compute_preview()
	preview_changed.emit(_preview)


func _compute_preview() -> void:
	_clear_preview()
	if focus == null or mode != Mode.PLACE or placing_rune == null:
		return
	if not _mouse_inside or _hovered >= 0 or _pressed >= 0:
		return
	_preview_error = place_error(placing_rune, _mouse_focus)
	if _preview_error != "" or not evaluate_preview.is_valid():
		return

	var copy := FocusInstance.new()
	copy.focus_def = focus.focus_def
	copy.base_count = focus.base_count
	copy.element_fill = focus.element_fill
	copy.dot_seed = focus.dot_seed
	copy.runes = focus.runes.duplicate()
	copy.loop = focus.loop.duplicate()
	copy.loop_closed = focus.loop_closed
	_insert_rune(copy, placing_rune, _mouse_focus)
	_preview_index = copy.runes.size() - 1
	_preview = evaluate_preview.call(copy)


## Punkte, die die Vorschau-Rune einsammeln würde. Ist der Spell mit ihr noch
## nicht gültig, werden die aktuell freien Punkte in ihrer Reichweite gezeigt.
func _preview_dots(claimed: Dictionary) -> Array[EnergyDot]:
	var dots: Array[EnergyDot] = []
	if _preview != null and _preview.valid:
		dots.assign(_preview.rune_results[_preview_index].collected)
		return dots
	for dot in result.dots:
		if not claimed.has(dot) and dot.position.distance_to(_mouse_focus) <= placing_rune.radius:
			dots.append(dot)
	return dots


func _preview_summary(dots: Array[EnergyDot]) -> String:
	if dots.is_empty():
		return "keine Punkte"
	var base := 0
	var counts := {}
	for dot in dots:
		if dot.is_base():
			base += 1
		else:
			counts[dot.element_id] = counts.get(dot.element_id, 0) + 1
	var parts := PackedStringArray(["Energie %d" % base])
	if content != null:
		for element in content.elements:
			if counts.has(element.id):
				parts.append("%s %d" % [element.display_name, counts[element.id]])
	var text := " · ".join(parts)
	if _preview == null or not _preview.valid:
		text += "  (in Reichweite)"
	return text


# --- Zeichnen ---------------------------------------------------------------

func _element_color(element_id: StringName, fallback: Color) -> Color:
	if content != null and element_id != &"":
		var element := content.get_element(element_id)
		if element != null:
			return element.color
	return fallback


func _draw_sector(rr: RuneResult, fill_alpha: float, border: Color, px: float) -> void:
	if rr.sector_sweep < 0.01:
		return
	var color := _element_color(rr.element_id, COLOR_NEUTRAL)
	var polygon := FocusGeometry.sector_polygon(
		rr.placed.position, rr.placed.rune.radius, rr.sector_start, rr.sector_sweep, 48)
	draw_colored_polygon(polygon, Color(color, fill_alpha))
	var outline := polygon.duplicate()
	outline.append(polygon[0])
	draw_polyline(outline, border, 1.0 * px, true)


func _draw() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
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
			if show_sectors:
				var color := _element_color(rr.element_id, COLOR_NEUTRAL)
				_draw_sector(rr, 0.13, Color(color, 0.45), px)

	# Reichweite (immer, solange noch kein gültiger Spell besteht)
	if show_radii or not valid:
		for placed in focus.runes:
			draw_arc(placed.position, placed.rune.radius, 0.0, TAU, 64, Color(1, 1, 1, 0.18), 1.0 * px, true)

	# Verbindungen (kreuzende oder aus dem Fokus führende rot)
	var edges := _loop_edges()
	var crossing := _crossing_edges(edges)
	var shape := focus.focus_def.shape
	for i in edges.size():
		var a := focus.runes[edges[i].x].position
		var b := focus.runes[edges[i].y].position
		var bad := crossing.has(i) or not shape.contains_segment(a, b)
		draw_line(a, b, COLOR_BAD if bad else COLOR_EDGE, 3.0 * px, true)

	# Gummiband beim Verbinden
	var n := focus.loop.size()
	if mode == Mode.CONNECT and _mouse_inside and n > 0 and not focus.loop_closed and not _dragging:
		var from := focus.runes[_last_in_loop()].position
		var to := _mouse_focus
		var band_color := Color(1, 1, 1, 0.4)
		if _hovered >= 0:
			to = focus.runes[_hovered].position
			band_color = COLOR_OK if connect_error(_hovered) == "" else COLOR_BAD
		elif _edge_crosses(from, to, _last_in_loop(), -1) or not shape.contains_segment(from, to):
			band_color = COLOR_BAD
		draw_line(from, to, band_color, 2.0 * px, true)

	# Vorschau beim Setzen: Bereich und neue Verbindungen
	var show_ghost := mode == Mode.PLACE and placing_rune != null and _mouse_inside \
		and _hovered < 0 and _pressed < 0
	var preview_dots: Array[EnergyDot] = []
	if show_ghost and _preview_error == "":
		if _preview != null and _preview.valid:
			var preview_rune := _preview.rune_results[_preview_index]
			_draw_sector(preview_rune, 0.22, COLOR_PREVIEW, px)
		else:
			draw_arc(_mouse_focus, placing_rune.radius, 0.0, TAU, 64, Color(COLOR_PREVIEW, 0.7), 1.0 * px, true)
		_draw_preview_edges(px)
		preview_dots = _preview_dots(claimed)

	# Energiepunkte
	if result != null:
		for dot in result.dots:
			var color := _element_color(dot.element_id, COLOR_BASE_DOT)
			if claimed.has(dot):
				draw_circle(dot.position, 3.2 * px, color, true, -1.0, true)
			elif show_free_dots:
				draw_circle(dot.position, 2.2 * px, Color(color, 0.4), true, -1.0, true)
	for dot in preview_dots:
		var color := _element_color(dot.element_id, COLOR_BASE_DOT)
		draw_circle(dot.position, 3.2 * px, color, true, -1.0, true)
		draw_arc(dot.position, 6.0 * px, 0.0, TAU, 16, COLOR_PREVIEW, 1.5 * px, true)

	# Geist der zu setzenden Rune
	if show_ghost:
		var ghost_color := Color(COLOR_OK if _preview_error == "" else COLOR_BAD, 0.6)
		if _preview_error != "":
			draw_arc(_mouse_focus, placing_rune.radius, 0.0, TAU, 64, Color(COLOR_BAD, 0.4), 1.0 * px, true)
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
		if i == _pressed or i == _hovered:
			ring = Color(1, 0.9, 0.3)
		elif focus.loop.has(i):
			ring = COLOR_EDGE
		draw_arc(placed.position, radius, 0.0, TAU, 32, ring, 2.5 * px, true)

	# Beschriftungen in Bildschirm-Koordinaten
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

	if show_ghost:
		var text := _preview_error if _preview_error != "" else _preview_summary(preview_dots)
		var text_color := COLOR_BAD if _preview_error != "" else COLOR_PREVIEW
		var text_pos := to_screen(_mouse_focus) + Vector2(16, 22)
		draw_string_outline(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.8))
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_color)


## Gestrichelte Linien zu den Runen, mit denen die neue Rune verbunden würde.
func _draw_preview_edges(px: float) -> void:
	if not auto_connect or placing_rune.role == RuneDef.Role.MAIN or focus.loop.is_empty():
		return
	var shape := focus.focus_def.shape
	var from := focus.runes[_last_in_loop()].position
	var color := Color(COLOR_PREVIEW if shape.contains_segment(from, _mouse_focus) else COLOR_BAD, 0.7)
	draw_dashed_line(from, _mouse_focus, color, 2.0 * px, 8.0 * px, true, true)
	var will_close := focus.loop_closed or \
		(focus.loop.size() + 1 >= SpellEvaluator.MIN_RUNES and focus.loop.size() + 1 == focus.runes.size() + 1)
	if will_close:
		var main_pos := focus.runes[focus.loop[0]].position
		color = Color(COLOR_PREVIEW if shape.contains_segment(_mouse_focus, main_pos) else COLOR_BAD, 0.7)
		draw_dashed_line(_mouse_focus, main_pos, color, 2.0 * px, 8.0 * px, true, true)
