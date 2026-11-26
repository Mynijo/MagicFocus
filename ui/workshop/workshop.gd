extends Control
## Fokus-Werkstatt: Fokus wählen und befüllen, Gems setzen, verschieben und zu einem
## Kreis verbinden. Der Spell wird live ausgewertet. Die Oberfläche wird im Code aufgebaut.

const CONTENT := preload("res://content/crafting_content.tres")
const ARENA_SCENE := "res://ui/arena/arena.tscn"
const GLOSSARY_SCENE := "res://ui/glossary/glossary.tscn"

const COLOR_GOOD := "#80ff90"
const COLOR_BAD := "#ff9090"
const KEY_HELP := "Tasten: 1 Setzen · 2 Verbinden · R neu würfeln · Rücktaste Verbindung zurück"

var focus: FocusInstance
var result: SpellResult
## Verschachtelte Tooltips für Begriffe in den Texten.
var tooltips: TermTooltips
## Auswertung mit dem Gem unter dem Mauszeiger (beim Setzen), sonst null.
var _preview_result: SpellResult
## Auswertung vor Beginn des Verschiebens (während des Ziehens), sonst null.
var _drag_baseline: SpellResult
## Gem-Liste im Ergebnis aufgeklappt?
var _show_gem_details := false
var _selected_size: GemDef.Size = GemDef.Size.WINZIG

var _canvas: FocusCanvas
var _focus_select: OptionButton
var _focus_info: Label
var _base_value: Label
var _element_spins := {}  # Element-ID -> SpinBox
var _element_total: Label
var _engraving_select: OptionButton
var _size_buttons: Array[Button] = []
var _spitz_check: CheckBox
var _gem_info: RichTextLabel
var _mode_place: Button
var _mode_connect: Button
var _status: Label
var _result_text: RichTextLabel
var _save_name: LineEdit
var _save_select: OptionButton
var _delete_dialog: ConfirmationDialog


func _ready() -> void:
	Balance.ensure_applied()
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
	# Zum Start die Hälfte der Essenz-Kapazität mit dem ersten erlaubten Element füllen
	for element in CONTENT.elements:
		if def.allows_element(element.id) and def.max_element_dots > 0:
			focus.element_fill[element.id] = int(def.max_element_dots / 2.0)
			break
	focus.dot_seed = randi()


func _load_example() -> void:
	var transfer := CONTENT.get_engraving(&"standard")
	focus.gems = [
		PlacedGem.create(CONTENT.get_gem(&"hauptgem_mittel_grob"), CONTENT.get_engraving(&"magischer_bolzen"), Vector2(-110, 70)),
		PlacedGem.create(CONTENT.get_gem(&"nebengem_mittel_grob"), transfer, Vector2(130, 50)),
		PlacedGem.create(CONTENT.get_gem(&"nebengem_mittel_spitz"), transfer, Vector2(0, -140)),
	]
	focus.loop = PackedInt32Array([0, 1, 2])
	focus.loop_closed = true


func _refresh() -> void:
	result = _evaluate(focus)
	_canvas.focus = focus
	_canvas.result = result
	_canvas.update_preview()
	_canvas.queue_redraw()
	_update_fill_labels()
	_update_result_text()


func _evaluate(target: FocusInstance) -> SpellResult:
	return SpellEvaluator.evaluate(target, CONTENT.elements)


# --- Aufbau der Oberfläche --------------------------------------------------

func _build_ui() -> void:
	tooltips = TermTooltips.new()
	tooltips.setup(CONTENT)
	add_child(tooltips)
	UiKit.background(self)

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
	_canvas.drag_started.connect(func() -> void: _drag_baseline = result)
	_canvas.drag_ended.connect(_on_drag_ended)
	root.add_child(_canvas)

	root.add_child(_build_right_panel())


func _build_left_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	UiKit.margin(scroll).add_child(box)

	UiKit.header(box, "1. Fokus")
	_focus_select = OptionButton.new()
	for def in CONTENT.foci:
		_focus_select.add_item("%s (%s)" % [def.display_name, def.shape.get_shape_name()])
	_focus_select.item_selected.connect(_on_focus_type_selected)
	box.add_child(_focus_select)
	_focus_info = UiKit.hint(box, "")

	UiKit.header(box, "2. Befüllen")
	_build_fill(box)

	UiKit.header(box, "3. Gems setzen")
	UiKit.hint(box, "Gravur, Größe und Form wählen, dann in den Fokus klicken. Klick auf ein Gem: übernimmt die Auswahl. Ziehen: verschieben. Rechtsklick: entfernen.")
	UiKit.check(box, "Automatisch verbinden", true, _set_auto_connect)
	_build_gem_choice(box)

	UiKit.header(box, "4. Verbinden")
	UiKit.hint(box, "Eigene Reihenfolge: „Kreis lösen“, beim Hauptgem beginnen, Gems anklicken, mit dem Hauptgem schließen. Rechtsklick: zurück.")
	var mode_group := ButtonGroup.new()
	var mode_row := UiKit.row(box)
	_mode_place = UiKit.toggle_button(mode_row, "Setzen [1]", mode_group)
	_mode_place.button_pressed = true
	_mode_place.pressed.connect(_set_mode.bind(FocusCanvas.Mode.PLACE))
	_mode_connect = UiKit.toggle_button(mode_row, "Verbinden [2]", mode_group)
	_mode_connect.pressed.connect(_set_mode.bind(FocusCanvas.Mode.CONNECT))
	var edit_row := UiKit.row(box)
	UiKit.button(edit_row, "Zurück", func() -> void: _canvas.undo_connection())
	UiKit.button(edit_row, "Kreis lösen", func() -> void: _canvas.clear_loop())
	UiKit.button(box, "Alle Gems entfernen", func() -> void: _canvas.clear_gems())

	UiKit.header(box, "Anzeige")
	UiKit.check(box, "Einflussbereiche", true, _set_display.bind(&"show_sectors"))
	UiKit.check(box, "Reichweite immer zeigen", false, _set_display.bind(&"show_radii"))
	UiKit.check(box, "Freie Punkte zeigen", true, _set_display.bind(&"show_free_dots"))

	UiKit.header(box, "Speichern und Laden")
	_build_save(box)

	UiKit.header(box, "Weiter")
	var nav_row := UiKit.row(box)
	UiKit.button(nav_row, "Arena", func() -> void: get_tree().change_scene_to_file(ARENA_SCENE))
	UiKit.button(nav_row, "Glossar", func() -> void: get_tree().change_scene_to_file(GLOSSARY_SCENE))
	return scroll


func _build_fill(box: VBoxContainer) -> void:
	var base_row := UiKit.row(box)
	var base_label := Label.new()
	base_label.text = "Neutrale Essenz"
	base_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_row.add_child(base_label)
	_base_value = Label.new()
	base_row.add_child(_base_value)
	UiKit.hint(box, "Füllt den Rest bis zur Kapazität auf.")
	for element in CONTENT.elements:
		var row := UiKit.row(box)
		var swatch: Control
		if element.icon != null:
			var icon := TextureRect.new()
			icon.texture = element.icon
			icon.modulate = element.color
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			swatch = icon
		else:
			var rect := ColorRect.new()
			rect.color = element.color
			swatch = rect
		swatch.custom_minimum_size = Vector2(22, 22)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var name_label := UiKit.rich_label(row, tooltips.linkify(element.display_name), 16, tooltips)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var spin := SpinBox.new()
		spin.value_changed.connect(_on_element_changed.bind(element.id))
		row.add_child(spin)
		_element_spins[element.id] = spin
	_element_total = UiKit.hint(box, "")
	UiKit.button(box, "Punkte neu würfeln [R]", _reroll)


func _build_gem_choice(box: VBoxContainer) -> void:
	var engraving_row := UiKit.row(box)
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

	var size_row := UiKit.row(box)
	var size_group := ButtonGroup.new()
	for size in GemDef.Size.values():
		var button := UiKit.toggle_button(size_row, GemDef.SIZE_NAMES[size].capitalize(), size_group)
		button.button_pressed = size == _selected_size
		button.pressed.connect(_on_size_selected.bind(size))
		_size_buttons.append(button)
	_spitz_check = UiKit.check(box, "Spitz (Innenwinkel, zählt ×2)", false, _on_gem_selection_changed.unbind(1))
	_gem_info = UiKit.rich_label(box, "", 12, tooltips)


func _build_save(box: VBoxContainer) -> void:
	_save_name = LineEdit.new()
	_save_name.placeholder_text = "Name des Fokus"
	box.add_child(_save_name)
	var save_row := UiKit.row(box)
	UiKit.button(save_row, "Speichern", _save_focus)
	UiKit.button(save_row, "Neu", _reset_focus)
	_save_select = OptionButton.new()
	box.add_child(_save_select)
	var load_row := UiKit.row(box)
	UiKit.button(load_row, "Laden", _load_focus)
	UiKit.button(load_row, "Löschen", _delete_focus)
	UiKit.button(box, "Beispiel laden", _on_example_pressed)
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Fokus löschen"
	_delete_dialog.ok_button_text = "Löschen"
	_delete_dialog.cancel_button_text = "Abbrechen"
	_delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(_delete_dialog)


func _build_right_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 360
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	UiKit.margin(panel).add_child(box)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", UiKit.COLOR_STATUS)
	box.add_child(_status)

	_result_text = RichTextLabel.new()
	_result_text.bbcode_enabled = true
	_result_text.meta_clicked.connect(_on_result_meta_clicked)
	tooltips.register(_result_text)
	_result_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_result_text)
	UiKit.hint(box, KEY_HELP)
	return panel


## Überträgt die Auswahl (Gravur, Größe, Spitz) auf das zu setzende Gem.
func _update_placing() -> void:
	var engraving: EngravingDef = _engraving_select.get_item_metadata(_engraving_select.selected)
	# manche Gravuren passen nur auf kleinere Gems (Multiplikator)
	for size in _size_buttons.size():
		_size_buttons[size].disabled = size > engraving.max_size
	if _selected_size > engraving.max_size:
		_selected_size = engraving.max_size
		_size_buttons[_selected_size].button_pressed = true
	var angle := GemDef.Angle.SPITZ if _spitz_check.button_pressed else GemDef.Angle.GROB
	var gem := CONTENT.find_gem(engraving.role, _selected_size, angle)
	_canvas.placing_engraving = engraving
	_canvas.placing_gem = gem
	var text := ContentText.describe(engraving, CONTENT)
	if gem != null:
		text += "\n%s · Radius %d · %s ×%s · bis %d neutrale Essenz, %d Essenzen" % [
			gem.display_name, int(PlacedGem.radius_of(gem, engraving)),
			"Innenwinkel" if gem.is_inner() else "Außenwinkel", TextFormat.number(gem.get_multiplier()),
			gem.max_base, gem.max_element]
	_gem_info.text = "[color=#b3b3bf]%s[/color]" % tooltips.linkify(text)
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
		var count := mini(int(focus.element_fill.get(element.id, 0)), remaining) if def.allows_element(element.id) else 0
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


func _update_fill_labels() -> void:
	var def := focus.focus_def
	_focus_info.text = "Bis %d Gems · Kapazität %d, davon bis %d Essenzen\nEssenzen: %s" % [
		def.max_gems, def.max_dots, def.max_element_dots, _allowed_text(def)]
	_element_total.text = "Essenzen: %d / %d" % [focus.get_element_total(), def.max_element_dots]
	_base_value.text = str(focus.get_base_count())


func _allowed_text(def: FocusDef) -> String:
	if def.max_element_dots <= 0:
		return "keine"
	if def.allowed_elements.is_empty():
		return "alle"
	var names := PackedStringArray()
	for element in CONTENT.elements:
		if def.allows_element(element.id):
			names.append(element.display_name)
	return "nur " + ", ".join(names)


# --- Ergebnis ---------------------------------------------------------------

func _update_result_text() -> void:
	var t := ""
	if _preview_result != null:
		var title := "Vorschau: Gem ändern" if _canvas.is_replace_preview() else "Vorschau: neues Gem"
		t += _section(title, _diff_text(result, _preview_result))
	elif _drag_baseline != null:
		t += _section("Änderung durch Verschieben", _diff_text(_drag_baseline, result))
	if result.valid:
		t += "[font_size=22][b]%s[/b][/font_size]\n" % result.engraving.display_name
		t += "[color=#aaaaaa]%s[/color]\n\n" % ContentText.describe(result.engraving, CONTENT)
		t += "Cast-Zeit: [b]%s s[/b] · Mana: [b]%s[/b]\n\n" % [
			TextFormat.number(result.cast_time), TextFormat.number(result.mana_cost, 1)]
		for stat: StringName in result.stats:
			t += "%s: %s\n" % [ContentText.value_name(stat), TextFormat.number(result.stats[stat])]
		var arrow := "▾" if _show_gem_details else "▸"
		t += "\n[url=toggle_gems][b]%s Gems (%d)[/b][/url]\n" % [arrow, result.gem_results.size()]
		if _show_gem_details:
			t += _gem_details_text()
	else:
		t += "[font_size=18][b]Noch kein gültiger Spell[/b][/font_size]\n\n"
		for error in result.errors:
			t += "[color=%s]• %s[/color]\n" % [COLOR_BAD, error]
		t += "\nKreis: %d von %d Gems verbunden%s\n" % [
			focus.loop.size(), focus.gems.size(), " (geschlossen)" if focus.loop_closed else ""]
	_result_text.text = tooltips.linkify(t)


func _section(title: String, body: String) -> String:
	return "[font_size=18][b][color=#fff2a0]%s[/color][/b][/font_size]\n%s\n[color=#555555]────────────[/color]\n\n" % [title, body]


## Vergleich zweier Auswertungen als BBCode ("vorher → nachher").
func _diff_text(before: SpellResult, after: SpellResult) -> String:
	if not after.valid:
		var invalid := "[color=%s]Der Spell wäre ungültig:[/color]\n" % COLOR_BAD
		for error in after.errors:
			invalid += "[color=%s]  • %s[/color]\n" % [COLOR_BAD, error]
		return invalid

	var t := ""
	if not before.valid:
		t += "[color=%s]Der Spell wird gültig: %s[/color]\n" % [COLOR_GOOD, after.engraving.display_name]
	elif before.engraving != after.engraving:
		t += "Spell: %s → %s\n" % [before.engraving.display_name, after.engraving.display_name]
	t += _diff_line("Cast-Zeit (s)", before.cast_time if before.valid else 0.0, after.cast_time, false)
	t += _diff_line("Mana", before.mana_cost if before.valid else 0.0, after.mana_cost, false)
	var stat_names := after.stats.keys()
	if before.valid:
		for stat: StringName in before.stats:
			if not stat_names.has(stat):
				stat_names.append(stat)
	for stat: StringName in stat_names:
		var old_value: float = before.stats.get(stat, 0.0) if before.valid else 0.0
		t += _diff_line(ContentText.value_name(stat), old_value, after.stats.get(stat, 0.0), true)
	return t


## Eine Zeile "Name: alt → neu (+x)"; grün = besser, rot = schlechter.
func _diff_line(label: String, old_value: float, new_value: float, higher_is_better: bool) -> String:
	var delta := snappedf(new_value - old_value, 0.01)
	if is_zero_approx(delta):
		return "[color=#999999]%s: %s[/color]\n" % [label, TextFormat.number(new_value, 1)]
	var color := COLOR_GOOD if (delta > 0.0) == higher_is_better else COLOR_BAD
	return "%s: %s → [b]%s[/b] [color=%s](%s%s)[/color]\n" % [
		label, TextFormat.number(old_value, 1), TextFormat.number(new_value, 1), color,
		"+" if delta > 0.0 else "", TextFormat.number(delta, 1)]


func _gem_details_text() -> String:
	var t := ""
	for gr in result.gem_results:
		var gem := gr.placed.gem
		var multiplier := "" if is_equal_approx(gr.multiplier, 1.0) else " ×" + TextFormat.number(gr.multiplier)
		t += "%s%s · %s%s\n" % ["★ " if gr.is_main() else "", gem.display_name, gr.placed.engraving.display_name, multiplier]
		var details := "Gesammelt: neutrale Essenz %d/%d, Essenzen %d/%d%s" % [
			gr.base_count, gem.max_base, gr.get_element_total(), gem.max_element,
			"" if gr.element_counts.is_empty() else " (%s)" % _counts_text(gr.element_counts)]
		if not is_equal_approx(gr.effective_base + _sum(gr.effective_elements), gr.base_count + gr.get_element_total()):
			details += "\nZählt: %s" % _essence_text(gr.effective_base, gr.effective_elements)
		if gr.is_main() and (gr.received_base > 0.0 or not gr.received_elements.is_empty()):
			details += "\nErhalten: %s" % _essence_text(gr.received_base, gr.received_elements)
		if not gr.placed.engraving.transfer_to_main:
			details += "\nPunkte: %s" % TextFormat.number(gr.points)
		t += "[indent][color=#bbbbbb]%s[/color][/indent]\n" % details
	return t


static func _sum(counts: Dictionary) -> float:
	var total := 0.0
	for value: float in counts.values():
		total += value
	return total


## "neutrale Essenz 12, Feuer 3, Luft 1"
func _essence_text(base: float, counts: Dictionary) -> String:
	var text := "neutrale Essenz %s" % TextFormat.number(base)
	if not counts.is_empty():
		text += ", " + _counts_text(counts)
	return text


func _counts_text(counts: Dictionary) -> String:
	var parts := PackedStringArray()
	for element in CONTENT.elements:
		if counts.has(element.id):
			parts.append("[color=#%s]%s[/color] %s" % [
				element.color.to_html(false), element.display_name, TextFormat.number(float(counts[element.id]))])
	return ", ".join(parts)


func _on_result_meta_clicked(meta: Variant) -> void:
	if str(meta) == "toggle_gems":
		_show_gem_details = not _show_gem_details
		_update_result_text()


# --- Speichern und Laden (FocusStore: JSON mit IDs in user://foci/) ---------

func _refresh_save_list() -> void:
	_save_select.clear()
	for focus_name in FocusStore.list_names():
		_save_select.add_item(focus_name)


func _selected_save_name() -> String:
	return _save_select.get_item_text(_save_select.selected) if _save_select.selected >= 0 else ""


func _save_focus() -> void:
	var file_name := _save_name.text.strip_edges().validate_filename()
	if file_name == "":
		_show_status("Bitte einen Namen eingeben.")
		return
	var error := FocusStore.save(focus, file_name)
	if error != OK:
		_show_status("Speichern fehlgeschlagen (Fehler %d)." % error)
		return
	_show_status("Gespeichert: %s" % file_name)
	_refresh_save_list()
	for i in _save_select.item_count:
		if _save_select.get_item_text(i) == file_name:
			_save_select.select(i)


func _load_focus() -> void:
	var file_name := _selected_save_name()
	if file_name == "":
		_show_status("Kein gespeicherter Fokus ausgewählt.")
		return
	var warnings: Array[String] = []
	var loaded := FocusStore.load_focus(file_name, CONTENT, warnings)
	if loaded == null:
		_show_status("Laden fehlgeschlagen: %s" % " ".join(warnings))
		return
	focus = loaded
	_save_name.text = file_name
	_sync_fill_ui()
	_refresh()
	var lines := PackedStringArray(["Geladen: %s" % file_name])
	lines.append_array(warnings)
	_show_status("\n".join(lines))


func _delete_focus() -> void:
	var file_name := _selected_save_name()
	if file_name == "":
		_show_status("Kein gespeicherter Fokus ausgewählt.")
		return
	_delete_dialog.dialog_text = "„%s“ wirklich löschen?" % file_name
	_delete_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	var file_name := _selected_save_name()
	if file_name == "":
		return
	var error := FocusStore.delete(file_name)
	if error != OK:
		_show_status("Löschen fehlgeschlagen (Fehler %d)." % error)
		return
	_show_status("Gelöscht: %s" % file_name)
	_refresh_save_list()


func _reset_focus() -> void:
	_new_focus(focus.focus_def)
	_sync_fill_ui()
	_refresh()
