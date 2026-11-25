extends Control
## Fokus-Werkstatt (M2): Fokus wählen und befüllen, Runen aus der Bibliothek setzen,
## verschieben und zu einem Kreis verbinden. Der Spell wird live ausgewertet.
## Die Oberfläche wird im Code aufgebaut; die Grafik folgt in M4.

const CONTENT := preload("res://content/crafting_content.tres")
const SAVE_DIR := "user://foci/"

const STAT_NAMES := {
	&"damage": "Schaden",
	&"shield": "Schild",
	&"resistance": "Resistenz",
	&"heal": "Heilung",
	&"burning": "Burning-Stacks",
	&"wet": "Wet-Stacks",
	&"lightning": "Blitz-Stacks",
	&"cast_time_reduction": "Cast-Zeit-Verkürzung (s)",
}
const AREA_NAMES := ["innen", "außen", "innen + außen"]

var focus: FocusInstance
var result: SpellResult
var threshold := SpellEvaluator.ELEMENT_THRESHOLD

var _canvas: FocusCanvas
var _focus_select: OptionButton
var _focus_info: Label
var _base_spin: SpinBox
var _element_spins := {}  # Element-ID -> SpinBox
var _element_total: Label
var _library_group := ButtonGroup.new()
var _mode_place: Button
var _mode_connect: Button
var _status: Label
var _result_text: RichTextLabel
var _save_name: LineEdit
var _save_select: OptionButton


func _ready() -> void:
	_new_focus(CONTENT.foci[0])
	_build_ui()
	_sync_fill_ui()
	_refresh_save_list()
	if OS.get_cmdline_user_args().has("--example"):
		_load_example()
	_refresh()


# --- Fokus-Zustand ----------------------------------------------------------

func _new_focus(def: FocusDef) -> void:
	focus = FocusInstance.new()
	focus.focus_def = def
	focus.base_count = def.max_base_dots
	focus.element_fill = {&"fire": int(def.max_element_dots / 2.0)}
	focus.dot_seed = randi()


func _load_example() -> void:
	focus.runes = [
		PlacedRune.create(CONTENT.get_rune(&"hauptrune_geschoss"), Vector2(-110, 70)),
		PlacedRune.create(CONTENT.get_rune(&"zusatzrune_standard"), Vector2(130, 50)),
		PlacedRune.create(CONTENT.get_rune(&"zusatzrune_innen"), Vector2(0, -140)),
	]
	focus.loop = PackedInt32Array([0, 1, 2])
	focus.loop_closed = true


func _refresh() -> void:
	result = SpellEvaluator.evaluate(focus, CONTENT.elements, null, threshold)
	_canvas.focus = focus
	_canvas.result = result
	_canvas.queue_redraw()
	_update_fill_labels()
	_update_result_text()


# --- Aufbau der Oberfläche --------------------------------------------------

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.12, 0.12, 0.15)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	root.add_child(_build_left_panel())

	_canvas = FocusCanvas.new()
	_canvas.content = CONTENT
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = true
	_canvas.focus_changed.connect(_on_canvas_changed)
	_canvas.message.connect(_show_status)
	root.add_child(_canvas)

	root.add_child(_build_right_panel())


func _build_left_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := _margin(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	# Fokus
	_header(box, "1. Fokus")
	_focus_select = OptionButton.new()
	for def in CONTENT.foci:
		_focus_select.add_item(def.display_name)
	_focus_select.item_selected.connect(_on_focus_type_selected)
	box.add_child(_focus_select)
	_focus_info = _small_label(box, "")

	# Befüllung
	_header(box, "2. Befüllen")
	var base_row := HBoxContainer.new()
	box.add_child(base_row)
	var base_label := Label.new()
	base_label.text = "Basispunkte"
	base_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_row.add_child(base_label)
	_base_spin = SpinBox.new()
	_base_spin.value_changed.connect(_on_base_changed)
	base_row.add_child(_base_spin)

	for element in CONTENT.elements:
		var row := HBoxContainer.new()
		box.add_child(row)
		var swatch := ColorRect.new()
		swatch.color = element.color
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var name_label := Label.new()
		name_label.text = element.display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var spin := SpinBox.new()
		spin.value_changed.connect(_on_element_changed.bind(element.id))
		row.add_child(spin)
		_element_spins[element.id] = spin
	_element_total = _small_label(box, "")

	var reroll := Button.new()
	reroll.text = "Punkte neu würfeln  [R]"
	reroll.pressed.connect(_reroll)
	box.add_child(reroll)

	# Runen-Bibliothek
	_header(box, "3. Runen setzen")
	_small_label(box, "Rune wählen, dann in den Fokus klicken. Ziehen = verschieben, Rechtsklick = entfernen.")
	_library_group.allow_unpress = true
	for rune in CONTENT.runes:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = _library_group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var prefix := "★ " if rune.role == RuneDef.Role.MAIN else "• "
		button.text = "%s%s  (r%d, %s)" % [prefix, rune.display_name, int(rune.radius), AREA_NAMES[rune.area]]
		button.tooltip_text = _rune_tooltip(rune)
		button.toggled.connect(_on_library_toggled.bind(rune))
		box.add_child(button)

	# Verbinden
	_header(box, "4. Verbinden")
	_small_label(box, "Bei der Hauptrune beginnen, Runen nacheinander anklicken, mit Klick auf die Hauptrune schließen. Rechtsklick = zurück.")
	var mode_group := ButtonGroup.new()
	var mode_row := HBoxContainer.new()
	box.add_child(mode_row)
	_mode_place = _toggle_button(mode_row, "Setzen  [1]", mode_group)
	_mode_place.button_pressed = true
	_mode_place.pressed.connect(_set_mode.bind(FocusCanvas.Mode.PLACE))
	_mode_connect = _toggle_button(mode_row, "Verbinden  [2]", mode_group)
	_mode_connect.pressed.connect(_set_mode.bind(FocusCanvas.Mode.CONNECT))
	var edit_row := HBoxContainer.new()
	box.add_child(edit_row)
	_button(edit_row, "Zurück", func() -> void: _canvas.undo_connection())
	_button(edit_row, "Kreis lösen", func() -> void: _canvas.clear_loop())
	_button(box, "Alle Runen entfernen", func() -> void: _canvas.clear_runes())

	# Anzeige / Balancing
	_header(box, "Anzeige & Balancing")
	_check(box, "Einflussbereiche", true, _set_display.bind(&"show_sectors"))
	_check(box, "Reichweite immer zeigen", false, _set_display.bind(&"show_radii"))
	_check(box, "Freie Punkte zeigen", true, _set_display.bind(&"show_free_dots"))
	var threshold_row := HBoxContainer.new()
	box.add_child(threshold_row)
	var threshold_label := Label.new()
	threshold_label.text = "Element-Schwelle"
	threshold_label.tooltip_text = "Ab so vielen Punkten eines Elements nimmt eine Rune dieses Element an."
	threshold_label.mouse_filter = Control.MOUSE_FILTER_PASS
	threshold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	threshold_row.add_child(threshold_label)
	var threshold_spin := SpinBox.new()
	threshold_spin.min_value = 1
	threshold_spin.max_value = 50
	threshold_spin.value = threshold
	threshold_spin.value_changed.connect(_on_threshold_changed)
	threshold_row.add_child(threshold_spin)

	# Speichern / Laden
	_header(box, "Speichern & Laden")
	_save_name = LineEdit.new()
	_save_name.placeholder_text = "Name des Fokus"
	box.add_child(_save_name)
	var save_row := HBoxContainer.new()
	box.add_child(save_row)
	_button(save_row, "Speichern", _save_focus)
	_button(save_row, "Neu", _reset_focus)
	_save_select = OptionButton.new()
	box.add_child(_save_select)
	_button(box, "Laden", _load_focus)
	_button(box, "Beispiel laden", _on_example_pressed)

	return scroll


func _build_right_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 360
	var margin := _margin(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	box.add_child(_status)

	_result_text = RichTextLabel.new()
	_result_text.bbcode_enabled = true
	_result_text.fit_content = false
	_result_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_result_text)
	return panel


# --- kleine UI-Helfer -------------------------------------------------------

func _margin(parent: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	parent.add_child(margin)
	return margin


func _header(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	parent.add_child(label)


func _small_label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _toggle_button(parent: Control, text: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button


func _check(parent: Control, text: String, value: bool, callback: Callable) -> void:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = value
	check.toggled.connect(callback)
	parent.add_child(check)


func _rune_tooltip(rune: RuneDef) -> String:
	var lines := PackedStringArray()
	lines.append(rune.display_name + (" (Hauptrune)" if rune.role == RuneDef.Role.MAIN else " (Zusatzrune)"))
	lines.append("Radius: %d" % int(rune.radius))
	lines.append("Bereich: %s" % AREA_NAMES[rune.area])
	lines.append("Max. Basispunkte: %d" % rune.max_base)
	lines.append("Max. farbige Punkte: %d" % rune.max_element)
	lines.append("Stärke: x%.2f" % rune.strength)
	if rune.spell_form != null:
		lines.append("Spell-Form: %s" % rune.spell_form.display_name)
	return "\n".join(lines)


# --- Ereignisse -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1:
			_mode_place.button_pressed = true
			_set_mode(FocusCanvas.Mode.PLACE)
		KEY_2:
			_mode_connect.button_pressed = true
			_set_mode(FocusCanvas.Mode.CONNECT)
		KEY_R:
			_reroll()
		KEY_BACKSPACE:
			_canvas.undo_connection()
		KEY_ESCAPE:
			var pressed := _library_group.get_pressed_button()
			if pressed != null:
				pressed.button_pressed = false


func _set_mode(mode: FocusCanvas.Mode) -> void:
	_canvas.mode = mode
	if mode == FocusCanvas.Mode.CONNECT:
		var pressed := _library_group.get_pressed_button()
		if pressed != null:
			pressed.button_pressed = false
	_canvas.queue_redraw()


func _on_library_toggled(on: bool, rune: RuneDef) -> void:
	if on:
		_canvas.placing_rune = rune
		_mode_place.button_pressed = true
		_set_mode(FocusCanvas.Mode.PLACE)
	elif _canvas.placing_rune == rune:
		_canvas.placing_rune = null
	_canvas.queue_redraw()


func _set_display(on: bool, property: StringName) -> void:
	_canvas.set(property, on)
	_canvas.queue_redraw()


func _on_threshold_changed(value: float) -> void:
	threshold = int(value)
	_refresh()


func _on_example_pressed() -> void:
	_new_focus(CONTENT.get_focus(&"kleiner_fokus"))
	_load_example()
	_sync_fill_ui()
	_refresh()


func _on_canvas_changed() -> void:
	_status.text = ""
	_refresh()


func _show_status(text: String) -> void:
	_status.text = text


func _on_focus_type_selected(index: int) -> void:
	var def := CONTENT.foci[index]
	focus.focus_def = def
	focus.base_count = mini(focus.base_count, def.max_base_dots)
	# Farbige Punkte auf die neue Kapazität kürzen
	var remaining := def.max_element_dots
	for element in CONTENT.elements:
		var count := mini(int(focus.element_fill.get(element.id, 0)), remaining)
		remaining -= count
		if count > 0:
			focus.element_fill[element.id] = count
		else:
			focus.element_fill.erase(element.id)
	_sync_fill_ui()
	_refresh()


func _on_base_changed(value: float) -> void:
	focus.base_count = int(value)
	_refresh()


func _on_element_changed(value: float, element_id: StringName) -> void:
	var others := focus.get_element_total() - int(focus.element_fill.get(element_id, 0))
	var allowed := clampi(int(value), 0, focus.focus_def.max_element_dots - others)
	if allowed != int(value):
		(_element_spins[element_id] as SpinBox).set_value_no_signal(allowed)
	if allowed > 0:
		focus.element_fill[element_id] = allowed
	else:
		focus.element_fill.erase(element_id)
	_refresh()


func _reroll() -> void:
	focus.dot_seed = randi()
	_refresh()


func _sync_fill_ui() -> void:
	var def := focus.focus_def
	_base_spin.max_value = def.max_base_dots
	_base_spin.set_value_no_signal(focus.base_count)
	for element_id: StringName in _element_spins:
		var spin: SpinBox = _element_spins[element_id]
		spin.max_value = def.max_element_dots
		spin.set_value_no_signal(int(focus.element_fill.get(element_id, 0)))
	var index := CONTENT.foci.find(def)
	if index >= 0:
		_focus_select.select(index)


func _update_fill_labels() -> void:
	var def := focus.focus_def
	_focus_info.text = "Runen: %d / %d   ·   Basispunkte max. %d   ·   farbige Punkte max. %d" % [
		focus.runes.size(), def.max_runes, def.max_base_dots, def.max_element_dots]
	_element_total.text = "Farbige Punkte: %d / %d" % [focus.get_element_total(), def.max_element_dots]


# --- Ergebnis ---------------------------------------------------------------

func _element_bbcode(element_id: StringName) -> String:
	if element_id == &"":
		return "[color=#bbbbbb]neutral[/color]"
	var element := CONTENT.get_element(element_id)
	if element == null:
		return String(element_id)
	return "[color=#%s]%s[/color]" % [element.color.to_html(false), element.display_name]


func _counts_text(counts: Dictionary) -> String:
	if counts.is_empty():
		return "–"
	var parts := PackedStringArray()
	for element in CONTENT.elements:
		if counts.has(element.id):
			parts.append("%s %d" % [_element_bbcode(element.id), counts[element.id]])
	return ", ".join(parts)


func _update_result_text() -> void:
	var t := ""
	if result.valid:
		t += "[font_size=22][b]%s[/b][/font_size]\n" % result.form.display_name
		t += "Element: %s\n\n" % _element_bbcode(result.element_id)
		t += "Cast-Zeit: [b]%.2f s[/b]\nMana: [b]%.1f[/b]\n\n" % [result.cast_time, result.mana_cost]
		t += "[b]Werte[/b]\n"
		for stat: StringName in result.stats:
			t += "  %s: %s\n" % [STAT_NAMES.get(stat, String(stat)), _format_number(result.stats[stat])]
		t += "\n[b]Runen[/b]\n"
		for rr in result.rune_results:
			var rune := rr.placed.rune
			var title := "★ Hauptrune" if rr.is_main() else "Zusatzrune"
			t += "%s – %s → %s\n" % [title, rune.display_name, _element_bbcode(rr.element_id)]
			t += "    Basis %d/%d · farbig %d/%d: %s\n" % [
				rr.base_count, rune.max_base, rr.get_element_total(), rune.max_element, _counts_text(rr.element_counts)]
	else:
		t += "[font_size=18][b]Noch kein gültiger Spell[/b][/font_size]\n\n"
		for error in result.errors:
			t += "[color=#ff9090]• %s[/color]\n" % error
		var connected := focus.loop.size()
		t += "\nKreis: %d von %d Runen verbunden%s\n" % [
			connected, focus.runes.size(), " (geschlossen)" if focus.loop_closed else ""]

	t += "\n[color=#888888][font_size=12]Tasten: 1 = Setzen, 2 = Verbinden, R = neu würfeln, "
	t += "Rücktaste = Verbindung zurück, Esc = Rune abwählen[/font_size][/color]"
	_result_text.text = t


func _format_number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.2f" % value


# --- Speichern / Laden ------------------------------------------------------

func _refresh_save_list() -> void:
	_save_select.clear()
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return
	for file in DirAccess.get_files_at(SAVE_DIR):
		if file.ends_with(".tres"):
			_save_select.add_item(file.get_basename())


func _save_focus() -> void:
	var file_name := _save_name.text.strip_edges().validate_filename()
	if file_name == "":
		_show_status("Bitte einen Namen eingeben.")
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var error := ResourceSaver.save(focus, SAVE_DIR + file_name + ".tres")
	if error != OK:
		_show_status("Speichern fehlgeschlagen (Fehler %d)." % error)
		return
	_show_status("Gespeichert: %s" % file_name)
	_refresh_save_list()


func _load_focus() -> void:
	if _save_select.selected < 0:
		_show_status("Kein gespeicherter Fokus ausgewählt.")
		return
	var file_name := _save_select.get_item_text(_save_select.selected)
	var loaded := ResourceLoader.load(SAVE_DIR + file_name + ".tres", "", ResourceLoader.CACHE_MODE_IGNORE) as FocusInstance
	if loaded == null or loaded.focus_def == null:
		_show_status("Laden fehlgeschlagen.")
		return
	focus = loaded
	_save_name.text = file_name
	_sync_fill_ui()
	_refresh()
	_show_status("Geladen: %s" % file_name)


func _reset_focus() -> void:
	_new_focus(focus.focus_def)
	_sync_fill_ui()
	_refresh()
