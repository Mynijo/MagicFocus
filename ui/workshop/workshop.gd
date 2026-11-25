extends Control
## Fokus-Werkstatt (M2): Fokus wählen und befüllen, Gems aus der Bibliothek setzen,
## verschieben und zu einem Kreis verbinden. Der Spell wird live ausgewertet.
## Die Oberfläche wird im Code aufgebaut; die Grafik folgt in M4.

const CONTENT := preload("res://content/crafting_content.tres")
const SAVE_DIR := "user://foci/"

const STAT_NAMES := {
	&"damage": "Schaden",
	&"heal": "Heilung",
	&"armor": "Armor",
	&"crit": "Crit",
	&"slow": "Slow (Stacks)",
	&"burn": "Burn (Stacks)",
	&"wet": "Nass (Stacks)",
	&"bleed": "Bleed (Stacks)",
	&"armor_break": "Armor Break (Stacks)",
	&"shock": "Schock (Stacks)",
	&"freeze_conversion": "Freeze (Nass pro Eis)",
	&"mana_reduction": "Mana-Reduktion",
	&"cast_time_reduction": "Cast-Zeit-Verkürzung (s)",
}

var focus: FocusInstance
var result: SpellResult
## Auswertung mit dem Gem unter dem Mauszeiger (beim Setzen), sonst null.
var _preview_result: SpellResult
## Auswertung vor Beginn des Verschiebens (während des Ziehens), sonst null.
var _drag_baseline: SpellResult

var _canvas: FocusCanvas
var _focus_select: OptionButton
var _focus_info: Label
var _base_value: Label
var _element_spins := {}  # Element-ID -> SpinBox
var _element_total: Label
var _engraving_select: OptionButton
var _spitz_check: CheckBox
var _gem_info: Label
var _selected_size: GemDef.Size = GemDef.Size.MITTEL
var _mode_place: Button
var _mode_connect: Button
var _status: Label
var _result_text: RichTextLabel
var _save_name: LineEdit
var _save_select: OptionButton
## Gem-Liste im Ergebnis aufgeklappt?
var _show_gem_details := false


func _ready() -> void:
	_new_focus(CONTENT.foci[0])
	_build_ui()
	_sync_fill_ui()
	_refresh_save_list()
	if OS.get_cmdline_user_args().has("--example"):
		_load_example()
	_refresh()
	_update_placing()


# --- Fokus-Zustand ----------------------------------------------------------

func _new_focus(def: FocusDef) -> void:
	focus = FocusInstance.new()
	focus.focus_def = def
	focus.element_fill = {}
	# Zum Start die Hälfte der Essenz-Kapazität mit dem ersten erlaubten Element füllen
	for element in CONTENT.elements:
		if def.allows_element(element.id) and def.max_element_dots > 0:
			focus.element_fill[element.id] = int(def.max_element_dots / 2.0)
			break
	focus.dot_seed = randi()


func _load_example() -> void:
	var standard := CONTENT.get_engraving(&"standard")
	focus.gems = [
		PlacedGem.create(CONTENT.get_gem(&"hauptgem_mittel_grob"), CONTENT.get_engraving(&"magischer_bolzen"), Vector2(-110, 70)),
		PlacedGem.create(CONTENT.get_gem(&"nebengem_mittel_grob"), standard, Vector2(130, 50)),
		PlacedGem.create(CONTENT.get_gem(&"nebengem_mittel_spitz"), standard, Vector2(0, -140)),
	]
	focus.loop = PackedInt32Array([0, 1, 2])
	focus.loop_closed = true


func _refresh() -> void:
	result = SpellEvaluator.evaluate(focus, CONTENT.elements)
	_canvas.focus = focus
	_canvas.result = result
	_canvas.update_preview()
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
	_canvas.evaluate_preview = _evaluate
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = true
	_canvas.focus_changed.connect(_on_canvas_changed)
	_canvas.message.connect(_show_status)
	_canvas.preview_changed.connect(_on_preview_changed)
	_canvas.drag_started.connect(_on_drag_started)
	_canvas.drag_ended.connect(_on_drag_ended)
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
		_focus_select.add_item("%s  (%s)" % [def.display_name, def.shape.get_shape_name()])
	_focus_select.item_selected.connect(_on_focus_type_selected)
	box.add_child(_focus_select)
	_focus_info = _small_label(box, "")

	# Befüllung
	_header(box, "2. Befüllen")
	var base_row := HBoxContainer.new()
	box.add_child(base_row)
	var base_label := Label.new()
	base_label.text = "Neutrale Essenz"
	base_label.tooltip_text = "Füllt den Fokus automatisch bis zur Gesamtkapazität auf."
	base_label.mouse_filter = Control.MOUSE_FILTER_PASS
	base_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_row.add_child(base_label)
	_base_value = Label.new()
	base_row.add_child(_base_value)
	_small_label(box, "Wird automatisch bis zum Maximum aufgefüllt.")

	_small_label(box, "Essenzen")
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

	# Gem-Bibliothek
	_header(box, "3. Gems setzen")
	_small_label(box, "Gravur, Größe und Spitz wählen, dann in den Fokus klicken – die Vorschau zeigt, welche Punkte das Gem einsammeln würde. Die Gravur bestimmt, ob es ein Hauptgem oder Nebengem ist. Gems ziehen = verschieben, Rechtsklick = entfernen.")
	_check(box, "Automatisch verbinden", true, _set_auto_connect)

	var engraving_row := HBoxContainer.new()
	box.add_child(engraving_row)
	var engraving_label := Label.new()
	engraving_label.text = "Gravur"
	engraving_row.add_child(engraving_label)
	_engraving_select = OptionButton.new()
	_engraving_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for role in [GemDef.Role.MAIN, GemDef.Role.MINOR]:
		_engraving_select.add_separator("Hauptgem" if role == GemDef.Role.MAIN else "Nebengem")
		for engraving in CONTENT.get_engravings_for(role):
			_engraving_select.add_item(engraving.display_name)
			_engraving_select.set_item_metadata(_engraving_select.item_count - 1, engraving)
	_engraving_select.item_selected.connect(_on_gem_selection_changed.unbind(1))
	engraving_row.add_child(_engraving_select)
	_engraving_select.select(1)  # erste Hauptgravur (Index 0 = Überschrift)

	var size_row := HBoxContainer.new()
	box.add_child(size_row)
	var size_group := ButtonGroup.new()
	for size in GemDef.Size.values():
		var button := _toggle_button(size_row, GemDef.SIZE_NAMES[size].capitalize(), size_group)
		button.button_pressed = size == GemDef.Size.MITTEL
		button.pressed.connect(_on_size_selected.bind(size))
	_spitz_check = CheckBox.new()
	_spitz_check.text = "Spitz (Innenwinkel, Essenzen zählen ×2)"
	_spitz_check.toggled.connect(_on_gem_selection_changed.unbind(1))
	box.add_child(_spitz_check)
	_gem_info = _small_label(box, "")

	# Verbinden
	_header(box, "4. Verbinden")
	_small_label(box, "Für eine eigene Reihenfolge: „Kreis lösen“, dann beim Hauptgem beginnen, Gems nacheinander anklicken und mit Klick auf das Hauptgem schließen. Rechtsklick = zurück.")
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
	_button(box, "Alle Gems entfernen", func() -> void: _canvas.clear_gems())

	# Anzeige / Balancing
	_header(box, "Anzeige & Balancing")
	_check(box, "Einflussbereiche", true, _set_display.bind(&"show_sectors"))
	_check(box, "Reichweite immer zeigen", false, _set_display.bind(&"show_radii"))
	_check(box, "Freie Punkte zeigen", true, _set_display.bind(&"show_free_dots"))

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
	_result_text.meta_underlined = false
	_result_text.meta_clicked.connect(_on_result_meta_clicked)
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


## Überträgt die Auswahl (Gravur, Größe, Spitz) auf das zu setzende Gem.
func _update_placing() -> void:
	var engraving: EngravingDef = _engraving_select.get_item_metadata(_engraving_select.selected)
	var angle := GemDef.Angle.SPITZ if _spitz_check.button_pressed else GemDef.Angle.GROB
	var gem := CONTENT.find_gem(engraving.role, _selected_size, angle)
	_canvas.placing_engraving = engraving
	_canvas.placing_gem = gem
	var lines := PackedStringArray([engraving.description])
	if gem != null:
		lines.append("%s: Radius %d, %s, Essenzen zählen ×%s, max. %d neutrale Essenz und %d Essenzen" % [
			gem.display_name, int(gem.radius), "Innenwinkel" if gem.is_inner() else "Außenwinkel",
			_format_number(gem.get_multiplier()), gem.max_base, gem.max_element])
	_gem_info.text = "\n".join(lines)
	_canvas.update_preview()
	_canvas.queue_redraw()


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


func _set_mode(mode: FocusCanvas.Mode) -> void:
	_canvas.mode = mode
	_canvas.update_preview()
	_canvas.queue_redraw()


func _on_size_selected(size: GemDef.Size) -> void:
	_selected_size = size
	_on_gem_selection_changed()


## Jede Änderung der Auswahl wechselt in den Modus Setzen.
func _on_gem_selection_changed() -> void:
	_mode_place.button_pressed = true
	_set_mode(FocusCanvas.Mode.PLACE)
	_update_placing()


func _evaluate(target: FocusInstance) -> SpellResult:
	return SpellEvaluator.evaluate(target, CONTENT.elements)


func _set_auto_connect(on: bool) -> void:
	_canvas.auto_connect = on
	_canvas.update_preview()
	_canvas.queue_redraw()


func _set_display(on: bool, property: StringName) -> void:
	_canvas.set(property, on)
	_canvas.queue_redraw()


func _on_example_pressed() -> void:
	_new_focus(CONTENT.get_focus(&"kleiner_fokus"))
	_load_example()
	_sync_fill_ui()
	_refresh()


func _on_preview_changed(preview: SpellResult) -> void:
	_preview_result = preview
	_update_result_text()


func _on_drag_started() -> void:
	_drag_baseline = result


func _on_drag_ended() -> void:
	_drag_baseline = null
	_update_result_text()


func _on_canvas_changed() -> void:
	_status.text = ""
	_refresh()


func _show_status(text: String) -> void:
	_status.text = text


func _on_focus_type_selected(index: int) -> void:
	var def := CONTENT.foci[index]
	focus.focus_def = def
	# Essenzen auf erlaubte Elemente und die neue Kapazität kürzen
	var remaining := def.max_element_dots
	for element in CONTENT.elements:
		var count := mini(int(focus.element_fill.get(element.id, 0)), remaining)
		if not def.allows_element(element.id):
			count = 0
		remaining -= count
		if count > 0:
			focus.element_fill[element.id] = count
		else:
			focus.element_fill.erase(element.id)
	_sync_fill_ui()
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
	for element_id: StringName in _element_spins:
		var spin: SpinBox = _element_spins[element_id]
		var allowed := def.allows_element(element_id) and def.max_element_dots > 0
		spin.max_value = def.max_element_dots
		spin.editable = allowed
		spin.modulate.a = 1.0 if allowed else 0.35
		spin.tooltip_text = "" if allowed else "In diesem Fokus nicht erlaubt"
		spin.set_value_no_signal(int(focus.element_fill.get(element_id, 0)))
	var index := CONTENT.foci.find(def)
	if index >= 0:
		_focus_select.select(index)


func _allowed_text(def: FocusDef) -> String:
	if def.max_element_dots <= 0:
		return "keine (nur neutrale Essenz)"
	if def.allowed_elements.is_empty():
		return "alle"
	var names := PackedStringArray()
	for element in CONTENT.elements:
		if def.allows_element(element.id):
			names.append(element.display_name)
	return "nur " + ", ".join(names)


func _update_fill_labels() -> void:
	var def := focus.focus_def
	_focus_info.text = "Form: %s   ·   Gems: %d / %d\nKapazität: %d (davon max. %d Essenzen)\nErlaubte Essenzen: %s" % [
		def.shape.get_shape_name(), focus.gems.size(), def.max_gems,
		def.max_dots, def.max_element_dots, _allowed_text(def)]
	_element_total.text = "Essenzen: %d / %d" % [focus.get_element_total(), def.max_element_dots]
	_base_value.text = str(focus.get_base_count())


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
			parts.append("%s %s" % [_element_bbcode(element.id), _format_number(float(counts[element.id]))])
	return ", ".join(parts)


## Vergleich zweier Auswertungen als BBCode ("vorher -> nachher").
func _diff_text(before: SpellResult, after: SpellResult) -> String:
	if not after.valid:
		var invalid_text := "[color=#ff9090]Der Spell wäre ungültig:[/color]\n"
		for error in after.errors:
			invalid_text += "[color=#ff9090]  • %s[/color]\n" % error
		return invalid_text

	var t := ""
	if not before.valid:
		t += "[color=#80ff90]Der Spell wird gültig: %s[/color]\n" % after.engraving.display_name
	elif before.engraving != after.engraving:
		t += "Spell: %s → %s\n" % [before.engraving.display_name, after.engraving.display_name]

	var old_cast := before.cast_time if before.valid else 0.0
	var old_mana := before.mana_cost if before.valid else 0.0
	t += _diff_line("Cast-Zeit (s)", old_cast, after.cast_time, false)
	t += _diff_line("Mana", old_mana, after.mana_cost, false)

	var stat_names := after.stats.keys()
	if before.valid:
		for stat: StringName in before.stats:
			if not stat_names.has(stat):
				stat_names.append(stat)
	for stat: StringName in stat_names:
		var old_value: float = before.stats.get(stat, 0.0) if before.valid else 0.0
		t += _diff_line(STAT_NAMES.get(stat, String(stat)), old_value, after.stats.get(stat, 0.0), true)
	return t


## Eine Zeile "Name: alt → neu (+x)"; grün = besser, rot = schlechter.
func _diff_line(label: String, old_value: float, new_value: float, higher_is_better: bool) -> String:
	var delta := new_value - old_value
	if is_zero_approx(delta):
		return "[color=#999999]%s: %s[/color]\n" % [label, _format_number(new_value)]
	var better := (delta > 0.0) == higher_is_better
	var color := "#80ff90" if better else "#ff9090"
	var prefix := "+" if delta > 0.0 else ""
	return "%s: %s → [b]%s[/b] [color=%s](%s%s)[/color]\n" % [
		label, _format_number(old_value), _format_number(new_value), color, prefix, _format_number(delta)]


func _update_result_text() -> void:
	var t := ""
	if _preview_result != null:
		t += "[font_size=18][b][color=#fff2a0]Vorschau: mit neuem Gem[/color][/b][/font_size]\n"
		t += _diff_text(result, _preview_result) + "\n[color=#555555]────────────[/color]\n\n"
	elif _drag_baseline != null:
		t += "[font_size=18][b][color=#fff2a0]Änderung durch Verschieben[/color][/b][/font_size]\n"
		t += _diff_text(_drag_baseline, result) + "\n[color=#555555]────────────[/color]\n\n"
	if result.valid:
		t += "[font_size=22][b]%s[/b][/font_size]\n" % result.engraving.display_name
		t += "[color=#aaaaaa]%s[/color]\n\n" % result.engraving.description
		t += "Cast-Zeit: [b]%.2f s[/b]\nMana: [b]%.1f[/b]\n\n" % [result.cast_time, result.mana_cost]
		t += "[b]Werte[/b]\n"
		for stat: StringName in result.stats:
			t += "  %s: %s\n" % [STAT_NAMES.get(stat, String(stat)), _format_number(result.stats[stat])]
		var arrow := "▾" if _show_gem_details else "▸"
		t += "\n[url=toggle_gems][b]%s Gems (%d)[/b][/url]\n" % [arrow, result.gem_results.size()]
		if _show_gem_details:
			t += _gem_details_text()
	else:
		t += "[font_size=18][b]Noch kein gültiger Spell[/b][/font_size]\n\n"
		for error in result.errors:
			t += "[color=#ff9090]• %s[/color]\n" % error
		var connected := focus.loop.size()
		t += "\nKreis: %d von %d Gems verbunden%s\n" % [
			connected, focus.gems.size(), " (geschlossen)" if focus.loop_closed else ""]

	t += "\n[color=#888888][font_size=12]Gems ziehen = verschieben (in beiden Modi). "
	t += "Tasten: 1 = Setzen, 2 = Verbinden, R = neu würfeln, "
	t += "Rücktaste = Verbindung zurück[/font_size][/color]"
	_result_text.text = t


func _gem_details_text() -> String:
	var t := ""
	for gr in result.gem_results:
		var gem := gr.placed.gem
		var title := "★ " if gr.is_main() else ""
		t += "%s%s · %s  ×%s\n" % [title, gem.display_name, gr.placed.engraving.display_name,
			_format_number(gr.multiplier)]
		var details := "eingesammelt: neutrale Essenz %d/%d, Essenzen %d/%d%s" % [
			gr.base_count, gem.max_base, gr.get_element_total(), gem.max_element,
			"" if gr.element_counts.is_empty() else " (%s)" % _counts_text(gr.element_counts)]
		if not is_equal_approx(gr.multiplier, 1.0):
			details += "\nzählt: %s" % _essence_text(gr.effective_base, gr.effective_elements)
		if gr.is_main() and (gr.received_base > 0.0 or not gr.received_elements.is_empty()):
			details += "\nübertragen: %s" % _essence_text(gr.received_base, gr.received_elements)
		t += "[indent][color=#bbbbbb]%s[/color][/indent]\n" % details
	return t


## "neutrale Essenz 12, Feuer 3, Luft 1"
func _essence_text(base: float, counts: Dictionary) -> String:
	var text := "neutrale Essenz %s" % _format_number(base)
	if not counts.is_empty():
		text += ", " + _counts_text(counts)
	return text


func _on_result_meta_clicked(meta: Variant) -> void:
	if str(meta) == "toggle_gems":
		_show_gem_details = not _show_gem_details
		_update_result_text()


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
