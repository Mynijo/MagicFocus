class_name TermTooltips
extends CanvasLayer
## Verschachtelte Tooltips für Begriffe (Elemente, Status) in RichTextLabels.
##
##   - `linkify()` macht bekannte Wörter im BBCode-Text zu Begriffs-Links.
##   - `register()` verbindet ein RichTextLabel mit den Tooltips.
##   - Hovern über einen Begriff: nach SHOW_DELAY erscheint der Tooltip, ein Balken
##     füllt sich; nach PIN_DELAY ist er festgepinnt und bleibt stehen.
##   - In einen festgepinnten Tooltip kann man hineinfahren; Begriffe darin öffnen
##     weitere Tooltips. Verlässt die Maus einen Tooltip (und alle daraus geöffneten),
##     schließt er sich.

const SHOW_DELAY := 0.35
const PIN_DELAY := 1.2
const MAX_WIDTH := 340.0
const GRACE := 28.0  # Pixel Spielraum um einen Tooltip
const ICON_SIZE := 28  # Symbol im Tooltip-Titel
const META_PREFIX := "term:"
const LINK_COLOR := "#9fd4ff"
const COLOR_PANEL := Color(0.08, 0.08, 0.12, 0.97)
const COLOR_BORDER := Color(0.45, 0.5, 0.7)
const COLOR_PINNED := Color(1.0, 0.82, 0.35)

var content: CraftingContent

## word -> term id; Wörter nach Länge sortiert (längste zuerst, z. B. "Mana Burn" vor "Burn")
var _word_to_id := {}
var _regex: RegEx

## Offene Tooltips, Ebene 0 zuerst. Einträge: {panel, label, bar, term, pinned}
var _stack: Array[Dictionary] = []
## Aktuell gehoverter Begriff und die Ebene des Labels (0 = normale Oberfläche,
## n = Tooltip n-1), sonst ""
var _hover_term := ""
var _hover_level := 0
var _hover_time := 0.0


func _init() -> void:
	layer = 100


func setup(p_content: CraftingContent) -> void:
	content = p_content
	var words: Array[String] = []
	for term in content.glossary:
		for word in term.words:
			_word_to_id[word] = String(term.id)
			words.append(word)
	words.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var escaped := PackedStringArray()
	for word in words:
		escaped.append(_escape(word))
	# ganzes Wort: davor und danach kein Buchstabe
	_regex = RegEx.create_from_string("(?<!\\p{L})(" + "|".join(escaped) + ")(?!\\p{L})")


## Verbindet ein RichTextLabel; `level` = Ebene des Labels (0 für die normale Oberfläche).
func register(label: RichTextLabel, level := 0) -> void:
	label.meta_underlined = false
	label.meta_hover_started.connect(_on_hover_started.bind(level))
	label.meta_hover_ended.connect(_on_hover_ended.bind(level))


## Macht bekannte Begriffe zu Links; BBCode-Tags und vorhandene Links bleiben unberührt.
## Text in [nolink]...[/nolink] wird nicht verlinkt (die Markierung selbst fällt weg).
func linkify(bbcode: String, exclude_id := "") -> String:
	if _regex == null:
		return bbcode
	var result := ""
	var in_url := 0
	var pos := 0
	while pos < bbcode.length():
		var tag_start := bbcode.find("[", pos)
		var plain := bbcode.substr(pos) if tag_start < 0 else bbcode.substr(pos, tag_start - pos)
		result += plain if in_url > 0 else _link_words(plain, exclude_id)
		if tag_start < 0:
			break
		var tag_end := bbcode.find("]", tag_start)
		if tag_end < 0:
			result += bbcode.substr(tag_start)
			break
		var tag := bbcode.substr(tag_start, tag_end - tag_start + 1)
		if tag.begins_with("[url") or tag == "[nolink]":
			in_url += 1
		elif tag == "[/url]" or tag == "[/nolink]":
			in_url = maxi(0, in_url - 1)
		if not tag.ends_with("nolink]"):
			result += tag
		pos = tag_end + 1
	return result


func _link_words(text: String, exclude_id: String) -> String:
	var out := ""
	var last := 0
	for m in _regex.search_all(text):
		var word := m.get_string(1)
		var id: String = _word_to_id.get(word, "")
		out += text.substr(last, m.get_start(1) - last)
		if id == "" or id == exclude_id:
			out += word
		else:
			out += "[url=%s%s][color=%s]%s[/color][/url]" % [META_PREFIX, id, LINK_COLOR, word]
		last = m.get_end(1)
	return out + text.substr(last)


static func _escape(word: String) -> String:
	var out := ""
	for c in word:
		out += ("\\" + c) if "\\^$.|?*+()[]{}-".contains(c) else c
	return out


# --- Hover ------------------------------------------------------------------

func _on_hover_started(meta: Variant, level: int) -> void:
	var text := str(meta)
	if not text.begins_with(META_PREFIX):
		return
	_hover_term = text.trim_prefix(META_PREFIX)
	_hover_level = level
	_hover_time = 0.0


func _on_hover_ended(meta: Variant, level: int) -> void:
	if level != _hover_level or str(meta).trim_prefix(META_PREFIX) != _hover_term:
		return
	_hover_term = ""
	# nicht festgepinnter Tooltip dieses Begriffs verschwindet mit dem Hover
	if _stack.size() > level and not _stack[level].pinned:
		_close_from(level)


func _process(delta: float) -> void:
	if _hover_term != "":
		_hover_time += delta
		var open: bool = _stack.size() > _hover_level and _stack[_hover_level].term == _hover_term
		if not open and _hover_time >= SHOW_DELAY:
			_open(_hover_term, _hover_level)
			open = true
		if open:
			var entry: Dictionary = _stack[_hover_level]
			if not entry.pinned:
				var progress := clampf((_hover_time - SHOW_DELAY) / (PIN_DELAY - SHOW_DELAY), 0.0, 1.0)
				(entry.bar as ProgressBar).value = progress
				if progress >= 1.0:
					_pin(entry)
	_close_left_tooltips()


## Festgepinnte Tooltips schließen, sobald die Maus weder in ihnen noch in einem
## daraus geöffneten Tooltip ist (und nicht gerade ihren Begriff hovert).
func _close_left_tooltips() -> void:
	if _stack.is_empty():
		return
	var mouse := _mouse()
	var deepest_inside := -1
	for i in _stack.size():
		# etwas Spielraum, damit man vom Begriff in den Tooltip fahren kann
		if (_stack[i].panel as Control).get_global_rect().grow(GRACE).has_point(mouse):
			deepest_inside = i
	# Ebene, deren Begriff gerade gehovert wird, bleibt offen
	var keep := deepest_inside
	if _hover_term != "":
		keep = maxi(keep, _hover_level)
	if keep + 1 < _stack.size():
		_close_from(keep + 1)


func _open(term_id: String, level: int) -> void:
	_close_from(level)
	var term := content.get_term(StringName(term_id)) if content != null else null
	if term == null:
		return
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = MAX_WIDTH
	var title := "[b]%s[/b]" % term.title
	if term.icon != null and term.icon.resource_path != "":
		title = "[img width=%d height=%d color=#%s]%s[/img]  %s" % [
			ICON_SIZE, ICON_SIZE, term.icon_color.to_html(false), term.icon.resource_path, title]
	label.text = "%s\n%s" % [title, linkify(term.text, term_id)]
	register(label, level + 1)
	box.add_child(label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.custom_minimum_size.y = 3
	box.add_child(bar)

	var entry := { panel = panel, label = label, bar = bar, term = term_id, pinned = false }
	_stack.append(entry)
	# Position: neben der Maus, im Fenster gehalten
	panel.reset_size()
	var view := _view_size()
	var pos := _mouse() + Vector2(14, 18)
	pos.x = clampf(pos.x, 4.0, view.x - panel.size.x - 4.0)
	if pos.y + panel.size.y > view.y - 4.0:
		pos.y = _mouse().y - panel.size.y - 10.0
	panel.position = pos.max(Vector2(4, 4))


func _pin(entry: Dictionary) -> void:
	entry.pinned = true
	(entry.bar as ProgressBar).visible = false
	var style := (entry.panel as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = COLOR_PINNED
	style.set_border_width_all(2)


func _close_from(level: int) -> void:
	while _stack.size() > level:
		var entry: Dictionary = _stack.pop_back()
		(entry.panel as Control).queue_free()
	if _hover_level > level and _hover_term != "":
		_hover_term = ""


## Für Tests: Anzahl offener Tooltips.
func open_count() -> int:
	return _stack.size()


func _mouse() -> Vector2:
	return get_viewport().get_mouse_position() if is_inside_tree() else Vector2.ZERO


func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1600, 900)
