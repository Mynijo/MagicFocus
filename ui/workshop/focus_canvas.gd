class_name FocusCanvas
extends Control
## Zeichenfläche der Werkstatt: zeigt einen Fokus und verarbeitet die Bedienung.
##   In beiden Modi:   Gem gedrückt halten und ziehen = verschieben
##   Modus SETZEN:     Linksklick = gewählte Gem setzen (mit Live-Vorschau),
##                     Klick auf ein Gem = übernimmt Gravur und Form der Auswahl
##                     (Vorschau beim Darüberfahren), Rechtsklick auf Gem = entfernen
##   Modus VERBINDEN:  Klick auf Gems = verbinden (Start bei dem Hauptgem,
##                     Klick auf das Hauptgem schließt den Kreis),
##                     Rechtsklick = letzte Verbindung zurücknehmen
## Mit `auto_connect` wird jede neue Gem mit der zuvor gesetzten verbunden und
## der Kreis ab MIN_GEMS Gems automatisch zur Hauptgem geschlossen.

signal focus_changed
signal message(text: String)
## Neue Vorschau beim Setzen (null = keine Vorschau).
signal preview_changed(preview: SpellResult)
signal drag_started
signal drag_ended

enum Mode { PLACE, CONNECT }

const GEM_PICK_RADIUS := 16.0   # Bildschirm-Pixel
const DRAG_THRESHOLD := 5.0      # Bildschirm-Pixel, ab denen ein Klick zum Ziehen wird
const MIN_GEM_DISTANCE := 25.0  # Fokus-Einheiten
const SLIDE_ATTEMPTS := 4       # Versuche, ein gezogenes Gem aus fremden Reichweiten zu schieben
const MAIN_GEM_SIZE := 13.0     # Bildschirm-Pixel
const MINOR_GEM_SIZE := 9.0
const ELEMENT_DOT_SCALE := 1.6  # Essenz-Punkte größer als neutrale

const COLOR_BACKGROUND := Color(0.07, 0.07, 0.11)
const COLOR_FOCUS := Color(0.11, 0.11, 0.18)
const COLOR_FOCUS_EDGE := Color(0.55, 0.55, 0.9)
const COLOR_EDGE := Color(0.45, 0.75, 1.0)
const COLOR_NEUTRAL := Color(0.92, 0.92, 0.95)
const COLOR_MAIN := Color(1.0, 0.82, 0.35)
const COLOR_BASE_DOT := Color(0.8, 0.8, 0.88)
const COLOR_OK := Color(0.4, 1.0, 0.5)
const COLOR_BAD := Color(1.0, 0.35, 0.35)
const COLOR_PREVIEW := Color(1.0, 0.95, 0.6)

var focus: FocusInstance
var result: SpellResult
var content: CraftingContent
var mode: Mode = Mode.PLACE
## In der Bibliothek gewählte Gem-Form und Gravur (werden im Modus SETZEN platziert).
var placing_gem: GemDef
var placing_engraving: EngravingDef
var auto_connect := true
## Wertet einen (hypothetischen) Fokus aus: func(FocusInstance) -> SpellResult.
## Wird für die Vorschau beim Setzen benutzt.
var evaluate_preview: Callable
var show_sectors := true
var show_radii := false
var show_free_dots := true

var _view_scale := 1.0
var _pressed := -1          # Gem unter dem Mauszeiger beim Drücken
var _press_screen := Vector2.ZERO
var _dragging := false
var _hovered := -1
var _mouse_inside := false
var _mouse_focus := Vector2.ZERO

# Vorschau beim Setzen
var _preview: SpellResult
var _preview_index := -1
var _preview_error := ""
## Index des Gems, das die Vorschau ersetzt (Maus darüber), sonst -1.
var _replace_index := -1


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


func _gem_at(screen_pos: Vector2) -> int:
	for i in range(focus.gems.size() - 1, -1, -1):
		if to_screen(focus.gems[i].position).distance_to(screen_pos) <= GEM_PICK_RADIUS:
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
			_move_gem(_pressed, _mouse_focus)
		else:
			_hovered = _gem_at(event.position)
		update_preview()
		queue_redraw()
		return

	if not event is InputEventMouseButton:
		return
	var button := event as InputEventMouseButton

	if button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			var idx := _gem_at(button.position)
			if idx >= 0:
				_pressed = idx
				_press_screen = button.position
				_dragging = false
			elif mode == Mode.PLACE and placing_gem != null:
				_try_place(placing_gem, to_focus(button.position))
		else:
			# Loslassen ohne Ziehen = Klick auf das Gem
			if _pressed >= 0 and not _dragging:
				if mode == Mode.CONNECT:
					_try_connect(_pressed)
				elif placing_gem != null:
					_try_replace(_pressed)
			var was_dragging := _dragging
			_pressed = -1
			_dragging = false
			if was_dragging:
				drag_ended.emit()
			update_preview()
		accept_event()
	elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		var idx := _gem_at(button.position)
		if mode == Mode.PLACE and idx >= 0:
			remove_gem(idx)
		elif mode == Mode.CONNECT:
			undo_connection()
		accept_event()


# --- Gems setzen / verschieben / entfernen --------------------------------

func _too_close(target: FocusInstance, pos: Vector2, ignore: int) -> bool:
	for i in target.gems.size():
		if i != ignore and target.gems[i].position.distance_to(pos) < MIN_GEM_DISTANCE:
			return true
	return false


## Gems dürfen nicht in der Reichweite eines anderen Gems liegen, in beide Richtungen:
## Abstand mindestens der größere der beiden Radien. Gibt den Index des ersten
## störenden Gems zurück, sonst -1. Geprüft nur beim Setzen, Verschieben und Ändern.
func radius_conflict(gem: GemDef, pos: Vector2, ignore: int) -> int:
	for i in focus.gems.size():
		var other := focus.gems[i]
		if i != ignore and other.position.distance_to(pos) < maxf(gem.radius, other.gem.radius):
			return i
	return -1


func _radius_error(gem: GemDef, pos: Vector2, ignore: int) -> String:
	var other := radius_conflict(gem, pos, ignore)
	if other < 0:
		return ""
	return "In der Reichweite von %s, Abstand mindestens %d" % [
		_gem_label(focus.gems[other].gem, focus.gems[other].engraving),
		int(maxf(gem.radius, focus.gems[other].gem.radius))]


## Leer = Gem darf hier gesetzt werden, sonst der Grund.
func place_error(gem: GemDef, pos: Vector2) -> String:
	var def := focus.focus_def
	var has_main := focus.get_main_gem_index() >= 0
	if not def.shape.contains(pos):
		return "Das Gem muss innerhalb des Fokus liegen."
	if focus.gems.size() >= def.max_gems:
		return "Dieser Fokus fasst höchstens %d Gems." % def.max_gems
	if gem.role == GemDef.Role.MAIN and has_main:
		return "Es gibt bereits ein Hauptgem."
	if gem.role == GemDef.Role.MINOR and not has_main:
		return "Setze zuerst ein Hauptgem."
	if _too_close(focus, pos, -1):
		return "Zu nah an einem anderen Gem."
	return _radius_error(gem, pos, -1)


func _try_place(gem: GemDef, pos: Vector2) -> void:
	var error := place_error(gem, pos)
	if error != "":
		message.emit(error)
		return
	_insert_gem(focus, gem, pos)
	focus_changed.emit()


## Fügt ein Gem hinzu und verbindet sie (bei `auto_connect`) mit der zuvor gesetzten.
## Wird auch für die Vorschau auf einer Kopie des Fokus benutzt.
func _insert_gem(target: FocusInstance, gem: GemDef, pos: Vector2) -> void:
	target.gems.append(PlacedGem.create(gem, placing_engraving, pos))
	var idx := target.gems.size() - 1
	if not auto_connect:
		target.loop_closed = false
		return

	if gem.role == GemDef.Role.MAIN:
		# Hauptgem vorne, vorhandene Nebengems in Setz-Reihenfolge dahinter
		var new_loop := PackedInt32Array([idx])
		for i in idx:
			new_loop.append(i)
		target.loop = new_loop
	elif not target.loop.is_empty():
		# Bei geschlossenem Kreis landet das Gem vor der schließenden Kante.
		target.loop.append(idx)
	target.loop_closed = target.loop.size() >= SpellEvaluator.MIN_GEMS \
		and target.loop.size() == target.gems.size()


## Leer = das Gem `idx` darf die gewählte Gravur und Form übernehmen, sonst der Grund.
func replace_error(idx: int) -> String:
	var placed := focus.gems[idx]
	if placing_gem.role != placed.gem.role:
		return "Ein Hauptgem braucht eine Hauptgravur." if placed.gem.role == GemDef.Role.MAIN \
			else "Ein Nebengem braucht eine Nebengravur."
	if placing_gem == placed.gem and placing_engraving == placed.engraving:
		return "Das Gem hat schon diese Gravur und Form."
	return _radius_error(placing_gem, placed.position, idx)


## Ersetzt Gravur und Form des Gems `idx`; Position und Verbindungen bleiben.
func _replace_gem(target: FocusInstance, idx: int) -> void:
	target.gems[idx] = PlacedGem.create(placing_gem, placing_engraving, target.gems[idx].position)


func _try_replace(idx: int) -> void:
	var error := replace_error(idx)
	if error != "":
		message.emit(error)
		return
	_replace_gem(focus, idx)
	focus_changed.emit()


## Zielposition beim Ziehen: Liegt `pos` in der Reichweite eines anderen Gems,
## wird sie auf deren Rand geschoben, sodass das Gem daran entlanggleitet.
## Gibt null zurück, wenn es keine erlaubte Position gibt (dann bleibt das Gem stehen).
func _slide_position(idx: int, pos: Vector2) -> Variant:
	var gem := focus.gems[idx].gem
	var target := pos
	for attempt in SLIDE_ATTEMPTS:
		var blocker := radius_conflict(gem, target, idx)
		if blocker < 0:
			break
		var other := focus.gems[blocker].position
		var direction := target - other
		if direction.length() < 0.001:
			direction = focus.gems[idx].position - other
		target = other + direction.normalized() * (maxf(gem.radius, focus.gems[blocker].gem.radius) + 0.01)
	if radius_conflict(gem, target, idx) >= 0 or _too_close(focus, target, idx) \
			or not focus.focus_def.shape.contains(target):
		return null
	return target


func _move_gem(idx: int, pos: Vector2) -> void:
	var target: Variant = _slide_position(idx, pos)
	if target == null:
		return
	focus.gems[idx].position = target
	focus_changed.emit()


func remove_gem(idx: int) -> void:
	var removed_main := focus.gems[idx].gem.role == GemDef.Role.MAIN
	var new_loop := PackedInt32Array()
	if not removed_main:
		# Nachbarn der entfernten Gem werden direkt verbunden, Indizes rücken nach.
		for loop_idx in focus.loop:
			if loop_idx != idx:
				new_loop.append(loop_idx - 1 if loop_idx > idx else loop_idx)
	focus.loop = new_loop
	focus.loop_closed = focus.loop_closed and new_loop.size() >= SpellEvaluator.MIN_GEMS \
		and new_loop.size() == focus.gems.size() - 1
	focus.gems.remove_at(idx)
	_pressed = -1
	_dragging = false
	_hovered = -1
	focus_changed.emit()


func clear_gems() -> void:
	focus.gems.clear()
	clear_loop()


# --- Verbinden --------------------------------------------------------------

func _last_in_loop() -> int:
	return focus.loop[focus.loop.size() - 1] if not focus.loop.is_empty() else -1


## Leer = Verbindung zu `idx` ist erlaubt, sonst der Grund.
func connect_error(idx: int) -> String:
	if focus.loop_closed:
		return "Der Kreis ist geschlossen. Rechtsklick nimmt die letzte Verbindung zurück."
	if focus.loop.is_empty():
		if focus.gems[idx].gem.role == GemDef.Role.MAIN:
			return ""
		return "Der Kreis beginnt beim Hauptgem."
	var last := _last_in_loop()
	if idx == last:
		return "Das ist das aktuelle Gem."
	if idx == focus.loop[0]:
		if focus.loop.size() < SpellEvaluator.MIN_GEMS:
			return "Zum Schließen braucht der Kreis mindestens %d Gems." % SpellEvaluator.MIN_GEMS
	elif focus.loop.has(idx):
		return "Dieses Gem ist bereits verbunden."
	var from := focus.gems[last].position
	var to := focus.gems[idx].position
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
		if Geometry2D.segment_intersects_segment(a, b, focus.gems[e1].position, focus.gems[e2].position) != null:
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


## Kanten des Kreises als Paare von Gem-Indizes.
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
					focus.gems[a.x].position, focus.gems[a.y].position,
					focus.gems[b.x].position, focus.gems[b.y].position) != null:
				crossing[i] = true
				crossing[j] = true
	return crossing


# --- Vorschau beim Setzen ---------------------------------------------------

func _clear_preview() -> void:
	_preview = null
	_preview_index = -1
	_preview_error = ""
	_replace_index = -1


## true, wenn die Vorschau ein vorhandenes Gem ersetzt (Maus über einem Gem).
func is_replace_preview() -> bool:
	return _replace_index >= 0


## Berechnet, was die gewählte Gem an der Mausposition einsammeln würde
## (bzw. was sich ändert, wenn das Gem unter der Maus sie übernimmt),
## und meldet das Ergebnis über `preview_changed`.
func update_preview() -> void:
	_compute_preview()
	preview_changed.emit(_preview)


func _compute_preview() -> void:
	_clear_preview()
	if focus == null or mode != Mode.PLACE or placing_gem == null:
		return
	if not _mouse_inside or _pressed >= 0 or not evaluate_preview.is_valid():
		return
	if _hovered >= 0:
		# Nur zeigen, wenn ein Klick wirklich etwas ändern würde (kein Hinweis beim
		# bloßen Darüberfahren, etwa vor dem Verschieben).
		if replace_error(_hovered) != "":
			return
		_replace_index = _hovered
	else:
		_preview_error = place_error(placing_gem, _mouse_focus)
		if _preview_error != "":
			return

	var copy := FocusInstance.new()
	copy.focus_def = focus.focus_def
	copy.element_fill = focus.element_fill
	copy.dot_seed = focus.dot_seed
	copy.gems = focus.gems.duplicate()
	copy.loop = focus.loop.duplicate()
	copy.loop_closed = focus.loop_closed
	if _replace_index >= 0:
		_replace_gem(copy, _replace_index)
		_preview_index = _replace_index
	else:
		_insert_gem(copy, placing_gem, _mouse_focus)
		_preview_index = copy.gems.size() - 1
	_preview = evaluate_preview.call(copy)


## Position der Vorschau: das ersetzte Gem oder die Maus.
func _preview_position() -> Vector2:
	return focus.gems[_replace_index].position if _replace_index >= 0 else _mouse_focus


## Punkte, die die Vorschau-Gem einsammeln würde. Ist der Spell mit ihr noch
## nicht gültig, werden die aktuell freien Punkte in ihrer Reichweite gezeigt.
func _preview_dots(claimed: Dictionary) -> Array[EnergyDot]:
	var dots: Array[EnergyDot] = []
	if _preview != null and _preview.valid:
		dots.assign(_preview.gem_results[_preview_index].collected)
		return dots
	var center := _preview_position()
	for dot in result.dots:
		if not claimed.has(dot) and dot.position.distance_to(center) <= placing_gem.radius:
			dots.append(dot)
	return dots


func _preview_summary(dots: Array[EnergyDot]) -> String:
	var text := _dots_summary(dots)
	if not dots.is_empty() and (_preview == null or not _preview.valid):
		text += "  (in Reichweite)"
	return text


## "neutrale Essenz 12 · Feuer 3"
func _dots_summary(dots: Array[EnergyDot]) -> String:
	if dots.is_empty():
		return "keine Punkte"
	var base := 0
	var counts := {}
	for dot in dots:
		if dot.is_base():
			base += 1
		else:
			counts[dot.element_id] = counts.get(dot.element_id, 0) + 1
	var parts := PackedStringArray(["neutrale Essenz %d" % base])
	if content != null:
		for element in content.elements:
			if counts.has(element.id):
				parts.append("%s %d" % [element.display_name, counts[element.id]])
	return " · ".join(parts)


## Gem, dessen eingesammelte Punkte gerade hervorgehoben werden
## (unter der Maus oder beim Ziehen), sonst null.
func _owner_result() -> GemResult:
	if result == null or not result.valid:
		return null
	var idx := _pressed if _dragging else _hovered
	if idx < 0 or idx >= result.gem_results.size():
		return null
	return result.gem_results[idx]


# --- Zeichnen ---------------------------------------------------------------

func _element_color(element_id: StringName, fallback: Color) -> Color:
	if content != null and element_id != &"":
		var element := content.get_element(element_id)
		if element != null:
			return element.color
	return fallback


func _gem_color(gem: GemDef) -> Color:
	return COLOR_MAIN if gem.role == GemDef.Role.MAIN else COLOR_NEUTRAL


## Beschriftung am Gem: Gravur und Multiplikator, z. B. "Feuerball ×2".
static func _gem_label(gem: GemDef, engraving: EngravingDef) -> String:
	var engraving_name := engraving.display_name if engraving != null else "ohne Gravur"
	var multiplier := gem.get_multiplier()
	if is_equal_approx(multiplier, 1.0):
		return engraving_name  # ×1 wird nicht angezeigt
	var number := str(int(multiplier)) if is_equal_approx(multiplier, roundf(multiplier)) else String.num(multiplier, 2)
	return "%s ×%s" % [engraving_name, number]


func _draw_sector(rr: GemResult, fill_alpha: float, border: Color, px: float) -> void:
	if rr.sector_sweep < 0.01:
		return
	var color := _gem_color(rr.placed.gem)
	var polygon := FocusGeometry.sector_polygon(
		rr.placed.position, rr.placed.gem.radius, rr.sector_start, rr.sector_sweep, 48)
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
		for rr in result.gem_results:
			for dot in rr.collected:
				claimed[dot] = true
			if show_sectors:
				var color := _gem_color(rr.placed.gem)
				_draw_sector(rr, 0.13, Color(color, 0.45), px)

	# Reichweite (immer, solange noch kein gültiger Spell besteht)
	if show_radii or not valid:
		for placed in focus.gems:
			draw_arc(placed.position, placed.gem.radius, 0.0, TAU, 64, Color(1, 1, 1, 0.18), 1.0 * px, true)

	# Verbindungen (kreuzende oder aus dem Fokus führende rot)
	var edges := _loop_edges()
	var crossing := _crossing_edges(edges)
	var shape := focus.focus_def.shape
	for i in edges.size():
		var a := focus.gems[edges[i].x].position
		var b := focus.gems[edges[i].y].position
		var bad := crossing.has(i) or not shape.contains_segment(a, b)
		draw_line(a, b, COLOR_BAD if bad else COLOR_EDGE, 3.0 * px, true)

	# Gummiband beim Verbinden
	var n := focus.loop.size()
	if mode == Mode.CONNECT and _mouse_inside and n > 0 and not focus.loop_closed and not _dragging:
		var from := focus.gems[_last_in_loop()].position
		var to := _mouse_focus
		var band_color := Color(1, 1, 1, 0.4)
		if _hovered >= 0:
			to = focus.gems[_hovered].position
			band_color = COLOR_OK if connect_error(_hovered) == "" else COLOR_BAD
		elif _edge_crosses(from, to, _last_in_loop(), -1) or not shape.contains_segment(from, to):
			band_color = COLOR_BAD
		draw_line(from, to, band_color, 2.0 * px, true)

	# Vorschau beim Setzen: Bereich und neue Verbindungen
	var show_ghost := mode == Mode.PLACE and placing_gem != null and _mouse_inside \
		and _hovered < 0 and _pressed < 0
	var show_replace := is_replace_preview()
	var preview_dots: Array[EnergyDot] = []
	if show_ghost and _preview_error == "":
		if _preview != null and _preview.valid:
			var preview_gem := _preview.gem_results[_preview_index]
			_draw_sector(preview_gem, 0.22, COLOR_PREVIEW, px)
		else:
			draw_arc(_preview_position(), placing_gem.radius, 0.0, TAU, 64, Color(COLOR_PREVIEW, 0.7), 1.0 * px, true)
		_draw_preview_edges(px)
		preview_dots = _preview_dots(claimed)

	# Zugehörigkeit: Punkte des Gems unter der Maus (bzw. des gezogenen) mit Linien zum Gem
	var owner := _owner_result()
	var owned := {}
	if owner != null:
		_draw_sector(owner, 0.18, Color(_gem_color(owner.placed.gem), 0.9), px)
		for dot in owner.collected:
			owned[dot] = true
			var line_color := Color(_element_color(dot.element_id, COLOR_BASE_DOT), 0.5)
			draw_line(owner.placed.position, dot.position, line_color, 1.0 * px, true)

	# Energiepunkte
	# Essenz-Punkte sind größer als neutrale (sie zählen mehr). Beim Hervorheben
	# werden die Punkte anderer Gems blasser.
	if result != null:
		for dot in result.dots:
			var color := _element_color(dot.element_id, COLOR_BASE_DOT)
			var scale := 1.0 if dot.is_base() else ELEMENT_DOT_SCALE
			if owned.has(dot):
				draw_circle(dot.position, 3.6 * scale * px, color, true, -1.0, true)
				draw_arc(dot.position, 5.5 * scale * px, 0.0, TAU, 16, Color(1, 1, 1, 0.85), 1.2 * px, true)
			elif claimed.has(dot):
				draw_circle(dot.position, 3.2 * scale * px, Color(color, 0.35 if owner != null else 1.0), true, -1.0, true)
			elif show_free_dots:
				draw_circle(dot.position, 2.2 * scale * px, Color(color, 0.4), true, -1.0, true)
	for dot in preview_dots:
		var color := _element_color(dot.element_id, COLOR_BASE_DOT)
		var scale := 1.0 if dot.is_base() else ELEMENT_DOT_SCALE
		draw_circle(dot.position, 3.2 * scale * px, color, true, -1.0, true)
		draw_arc(dot.position, 6.0 * scale * px, 0.0, TAU, 16, COLOR_PREVIEW, 1.5 * px, true)

	# Geist der zu setzenden Gem
	if show_ghost:
		var ghost_color := Color(COLOR_OK if _preview_error == "" else COLOR_BAD, 0.6)
		if _preview_error != "":
			draw_arc(_mouse_focus, placing_gem.radius, 0.0, TAU, 64, Color(COLOR_BAD, 0.4), 1.0 * px, true)
			# Reichweite des Gems, das im Weg ist
			var blocker := radius_conflict(placing_gem, _mouse_focus, -1)
			if blocker >= 0:
				var other := focus.gems[blocker]
				draw_arc(other.position, maxf(other.gem.radius, placing_gem.radius), 0.0, TAU, 64,
					Color(COLOR_BAD, 0.8), 2.0 * px, true)
		var ghost_size := MAIN_GEM_SIZE if placing_gem.role == GemDef.Role.MAIN else MINOR_GEM_SIZE
		draw_circle(_mouse_focus, ghost_size * px, ghost_color, true, -1.0, true)

	# Gems
	for i in focus.gems.size():
		var placed := focus.gems[i]
		var is_main := placed.gem.role == GemDef.Role.MAIN
		var fill := _gem_color(placed.gem)
		var radius := (MAIN_GEM_SIZE if is_main else MINOR_GEM_SIZE) * px
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
	for placed in focus.gems:
		var label := _gem_label(placed.gem, placed.engraving)
		var label_pos := to_screen(placed.position) + Vector2(14, -10)
		draw_string_outline(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
		draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.9))

	if show_ghost:
		var text := _preview_error if _preview_error != "" else _preview_summary(preview_dots)
		if _preview_error == "":
			text = _gem_label(placing_gem, placing_engraving) + "  ·  " + text
		_draw_hint(font, to_screen(_mouse_focus), text, COLOR_BAD if _preview_error != "" else COLOR_PREVIEW)
	elif owner != null:
		var anchor := to_screen(owner.placed.position)
		_draw_hint(font, anchor, "Sammelt: " + _dots_summary(owner.collected), Color(1, 1, 1, 0.95))
		if show_replace:
			var text := "Klick: wird zu %s  ·  %s" % [
				_gem_label(placing_gem, placing_engraving), _preview_summary(_preview_dots(claimed))]
			_draw_hint(font, anchor, text, COLOR_PREVIEW, 1)
	elif show_replace:
		var text := "Klick: wird zu %s  ·  %s" % [
			_gem_label(placing_gem, placing_engraving), _preview_summary(_preview_dots(claimed))]
		_draw_hint(font, to_screen(_preview_position()), text, COLOR_PREVIEW)


## Hinweistext unter einem Punkt (`line` = weitere Zeile darunter);
## passt er rechts nicht mehr hin, steht er links davon.
func _draw_hint(font: Font, anchor: Vector2, text: String, color: Color, line := 0) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var pos := anchor + Vector2(16, 22 + 18 * line)
	if pos.x + width > size.x - 8.0:
		pos.x = maxf(8.0, anchor.x - 16.0 - width)
	# dunkler Hintergrund, damit der Hinweis über Beschriftungen lesbar bleibt
	draw_rect(Rect2(pos + Vector2(-4, -15), Vector2(width + 8, 19)), Color(0.05, 0.05, 0.08, 0.85))
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.8))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


## Gestrichelte Linien zu den Gems, mit denen die neue Gem verbunden würde.
func _draw_preview_edges(px: float) -> void:
	if not auto_connect or placing_gem.role == GemDef.Role.MAIN or focus.loop.is_empty():
		return
	var shape := focus.focus_def.shape
	var from := focus.gems[_last_in_loop()].position
	var color := Color(COLOR_PREVIEW if shape.contains_segment(from, _mouse_focus) else COLOR_BAD, 0.7)
	draw_dashed_line(from, _mouse_focus, color, 2.0 * px, 8.0 * px, true, true)
	var will_close := focus.loop_closed or \
		(focus.loop.size() + 1 >= SpellEvaluator.MIN_GEMS and focus.loop.size() + 1 == focus.gems.size() + 1)
	if will_close:
		var main_pos := focus.gems[focus.loop[0]].position
		color = Color(COLOR_PREVIEW if shape.contains_segment(_mouse_focus, main_pos) else COLOR_BAD, 0.7)
		draw_dashed_line(_mouse_focus, main_pos, color, 2.0 * px, 8.0 * px, true, true)
