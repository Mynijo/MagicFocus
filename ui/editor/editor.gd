extends Control
## Editor: Werte von Gravuren, Gem-Formen, Foki und Kampfregeln im Spiel ändern.
## Jede Änderung gilt sofort (gleiche Ressourcen wie Werkstatt und Arena) und wird als
## Override in user://balance.json gespeichert (siehe `Balance`). Geänderte Einträge
## sind in der Liste mit • markiert und lassen sich zurücksetzen.

const CONTENT := preload("res://content/crafting_content.tres")
const RULES := preload("res://content/combat_rules.tres")
const WORKSHOP_SCENE := "res://ui/workshop/workshop.tscn"
const GLOSSARY_SCENE := "res://ui/glossary/glossary.tscn"
const ARENA_SCENE := "res://ui/arena/arena.tscn"
const TABS := ["Gravuren", "Gems", "Foki", "Kampfregeln"]
const SOURCE_NAMES := ["neutrale Essenz", "Essenz eines Elements", "jede Essenz der Gravur", "Punkte"]
const GEM_LABELS := { "radius": "Radius", "max_base": "max. neutrale Essenz", "max_element": "max. Essenzen",
	"body_radius": "Stein (verdeckt Essenz)" }
const FOCUS_LABELS := { "max_gems": "max. Gems", "max_dots": "Kapazität", "max_element_dots": "davon max. Essenzen" }

var tooltips: TermTooltips
var _tabs: TabContainer
var _lists: Array[ItemList] = []
var _forms: Array[VBoxContainer] = []
## Schlüssel (siehe Balance) je Reiter, in Listen-Reihenfolge
var _keys: Array = [[], [], [], []]
var _selected: Array[int] = [0, 0, 0, 0]
var _description: RichTextLabel
var _reset_button: Button


func _ready() -> void:
	Balance.ensure_applied()
	tooltips = TermTooltips.new()
	tooltips.setup(CONTENT)
	add_child(tooltips)
	UiKit.background(self)
	var margin := UiKit.margin(self, 12)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	var top := UiKit.row(root, 8)
	UiKit.button(top, "← Werkstatt", func() -> void: get_tree().change_scene_to_file(WORKSHOP_SCENE), false)
	UiKit.button(top, "Glossar", func() -> void: get_tree().change_scene_to_file(GLOSSARY_SCENE), false)
	UiKit.button(top, "Arena", func() -> void: get_tree().change_scene_to_file(ARENA_SCENE), false)
	UiKit.hint(top, "  Änderungen gelten sofort und werden gespeichert. • = geändert.", false)

	for e in CONTENT.engravings:
		_keys[0].append("engraving/" + e.id)
	for g in CONTENT.gems:
		_keys[1].append("gem/" + g.id)
	for f in CONTENT.foci:
		_keys[2].append("focus/" + f.id)
	_keys[3].append("rules")

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	for tab in TABS.size():
		var split := HSplitContainer.new()
		split.name = TABS[tab]
		_tabs.add_child(split)
		var list := ItemList.new()
		list.custom_minimum_size.x = 260
		list.item_selected.connect(_on_item_selected.bind(tab))
		split.add_child(list)
		_lists.append(list)
		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		split.add_child(scroll)
		var form := VBoxContainer.new()
		form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		form.add_theme_constant_override("separation", 6)
		UiKit.margin(scroll).add_child(form)
		_forms.append(form)
		_fill_list(tab)
		_build_form(tab)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tab="):  # für Render-Checks
			_tabs.current_tab = int(arg.trim_prefix("--tab="))


# --- Liste ---------------------------------------------------------------------

func _fill_list(tab: int) -> void:
	var list := _lists[tab]
	list.clear()
	for key: String in _keys[tab]:
		list.add_item(("• " if Balance.is_changed(key) else "   ") + _title(key))
	list.select(_selected[tab])


func _title(key: String) -> String:
	var target := _resource(key)
	if target is EngravingDef:
		return "%s (%s)" % [target.display_name, "Hauptgem" if target.role == GemDef.Role.MAIN else "Nebengem"]
	if target is GemDef or target is FocusDef:
		return target.display_name
	return "Kampfregeln"


func _resource(key: String) -> Resource:
	return Balance.resource_for(key, CONTENT, RULES)


func _on_item_selected(index: int, tab: int) -> void:
	_selected[tab] = index
	_build_form(tab)


func _current_key(tab: int) -> String:
	return _keys[tab][_selected[tab]]


# --- Formulare -------------------------------------------------------------------

func _build_form(tab: int) -> void:
	var form := _forms[tab]
	for child in form.get_children():
		child.queue_free()
	var key := _current_key(tab)
	var target := _resource(key)
	UiKit.header(form, _title(key))
	_reset_button = UiKit.button(form, "Auf Standard zurücksetzen", func() -> void:
		Balance.reset(key)
		_fill_list(tab)
		_build_form(tab), false)
	_reset_button.disabled = not Balance.is_changed(key)
	if target is EngravingDef:
		_engraving_form(form, target, tab)
	elif target is GemDef:
		for field: String in GEM_LABELS:
			_number(form, GEM_LABELS[field], target, field, tab)
	elif target is FocusDef:
		_focus_form(form, target, tab)
	elif target is CombatRules:
		for field: String in CombatRules.LABELS:
			_number(form, CombatRules.LABELS[field], target, field, tab)


func _engraving_form(form: VBoxContainer, e: EngravingDef, tab: int) -> void:
	_description = UiKit.rich_label(form, "", 14, tooltips)
	_update_description(e)
	if e.role == GemDef.Role.MAIN:
		_option(form, "Ziel", ContentText.TARGET_NAMES, e.target, func(i: int) -> void:
			e.target = i
			_changed(tab))
	var note := _labeled(form, "Notiz")
	var note_edit := LineEdit.new()
	note_edit.text = e.note
	note_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_edit.text_changed.connect(func(text: String) -> void:
		e.note = text
		_changed(tab))
	note.add_child(note_edit)

	UiKit.header(form, "Elemente und Faktor")
	for element in CONTENT.elements:
		var row := UiKit.row(form)
		var spin := _spin(e.factor_of(element.id) if e.counts_element(element.id) else 5.0, false)
		spin.editable = e.counts_element(element.id)
		var check := UiKit.check(row, element.display_name, e.counts_element(element.id), func(on: bool) -> void:
			if on:
				e.element_factors[element.id] = spin.value
			else:
				e.element_factors.erase(element.id)
			spin.editable = on
			_changed(tab))
		check.custom_minimum_size.x = 140
		spin.value_changed.connect(func(value: float) -> void:
			if e.counts_element(element.id):
				e.element_factors[element.id] = value
				_changed(tab))
		row.add_child(spin)
		UiKit.hint(row, "Punkte pro Essenz", false)

	UiKit.header(form, "Feste Werte")
	for stat: StringName in e.base_stats.keys():
		var row := UiKit.row(form)
		var spin := _spin(float(e.base_stats[stat]), false)
		spin.value_changed.connect(func(value: float) -> void:
			e.base_stats[stat] = value
			_changed(tab))
		row.add_child(spin)
		_stat_option(row, stat, func(new_stat: StringName) -> void:
			var value: float = e.base_stats[stat]
			e.base_stats.erase(stat)
			e.base_stats[new_stat] = value
			_changed(tab, true))
		UiKit.button(row, "Entfernen", func() -> void:
			e.base_stats.erase(stat)
			_changed(tab, true), false)
	UiKit.button(form, "+ Fester Wert", func() -> void:
		e.base_stats[_free_stat(e)] = 1.0
		_changed(tab, true), false)

	UiKit.header(form, "Regeln")
	for i in e.rules.size():
		_rule_row(form, e, i, tab)
	UiKit.button(form, "+ Regel", func() -> void:
		var rule := ScalingRule.new()
		rule.source = ScalingRule.Source.POINTS
		rule.stat = &"damage"
		e.rules.append(rule)
		_changed(tab, true), false)

	UiKit.header(form, "Einsammeln")
	var transfer := UiKit.check(form, "Gibt alles an das Hauptgem weiter", e.transfer_to_main, func(on: bool) -> void:
		e.transfer_to_main = on
		_changed(tab))
	transfer.disabled = e.role == GemDef.Role.MAIN
	_number(form, "Radius-Faktor", e, "radius_factor", tab)
	_number(form, "Innerer Ring (× Radius ab Stein, 0 = keiner)", e, "inner_radius_factor", tab)
	_number(form, "Innerer Ring: Multiplikator", e, "inner_multiplier", tab)
	var sizes: Array = []
	for size_name: String in GemDef.SIZE_NAMES:
		sizes.append(size_name)
	_option(form, "Größte Gem-Größe", sizes, e.max_size, func(i: int) -> void:
		e.max_size = i
		_changed(tab))


## Eine Regel: "[Menge] [Wert] pro [N] Punkte aus [Quelle] ab [Mindestens] höchstens [Höchstwert]"
func _rule_row(form: VBoxContainer, e: EngravingDef, index: int, tab: int) -> void:
	var rule := e.rules[index]
	var box := VBoxContainer.new()
	form.add_child(box)
	var row := UiKit.row(box)
	var amount := _spin(rule.amount, false)
	amount.value_changed.connect(func(v: float) -> void:
		rule.amount = v
		_changed(tab))
	row.add_child(amount)
	_stat_option(row, rule.stat, func(stat: StringName) -> void:
		rule.stat = stat
		_changed(tab))
	UiKit.hint(row, "pro", false)
	var per_n := _spin(rule.per_n, true)
	per_n.min_value = 1
	per_n.value_changed.connect(func(v: float) -> void:
		rule.per_n = int(v)
		_changed(tab))
	row.add_child(per_n)
	UiKit.hint(row, "Punkte aus", false)
	var sources := SOURCE_NAMES.duplicate()
	var source_index := rule.source
	for element in CONTENT.elements:
		sources.append(element.display_name + "-Essenz")
		if rule.source == ScalingRule.Source.ELEMENT and rule.element_id == element.id:
			source_index = sources.size() - 1
	_option(row, "", sources, source_index, func(i: int) -> void:
		if i >= SOURCE_NAMES.size():
			rule.source = ScalingRule.Source.ELEMENT
			rule.element_id = CONTENT.elements[i - SOURCE_NAMES.size()].id
		else:
			rule.source = i
			rule.element_id = &""
		_changed(tab))
	var row2 := UiKit.row(box)
	UiKit.hint(row2, "      ab", false)
	var min_count := _spin(rule.min_count, true)
	min_count.value_changed.connect(func(v: float) -> void:
		rule.min_count = int(v)
		_changed(tab))
	row2.add_child(min_count)
	UiKit.hint(row2, "Punkten, höchstens (0 = ohne)", false)
	var cap := _spin(rule.cap, false)
	cap.value_changed.connect(func(v: float) -> void:
		rule.cap = v
		_changed(tab))
	row2.add_child(cap)
	UiKit.button(row2, "Regel entfernen", func() -> void:
		e.rules.remove_at(index)
		_changed(tab, true), false)


func _focus_form(form: VBoxContainer, def: FocusDef, tab: int) -> void:
	for field: String in FOCUS_LABELS:
		_number(form, FOCUS_LABELS[field], def, field, tab)
	UiKit.header(form, "Erlaubte Elemente (keins gewählt = alle)")
	for element in CONTENT.elements:
		UiKit.check(form, element.display_name, def.allowed_elements.has(element.id), func(on: bool) -> void:
			var allowed := def.allowed_elements.duplicate()
			if on and not allowed.has(element.id):
				allowed.append(element.id)
			elif not on:
				allowed.erase(element.id)
			def.allowed_elements = allowed
			_changed(tab))
	UiKit.header(form, "Größe (%s)" % def.shape.get_shape_name())
	for field in Balance.number_fields(def.shape):
		_number(form, FocusShape.FIELD_LABELS.get(field, field), def.shape, field, tab)


# --- Bausteine -------------------------------------------------------------------

## Zeile "Beschriftung  [Zahl]" für ein Zahlenfeld von `target`.
func _number(form: Control, label: String, target: Object, field: String, tab: int) -> void:
	var row := _labeled(form, label)
	var spin := _spin(target.get(field), target.get(field) is int)
	spin.value_changed.connect(func(v: float) -> void:
		target.set(field, int(v) if target.get(field) is int else v)
		_changed(tab))
	row.add_child(spin)


func _labeled(form: Control, label: String) -> HBoxContainer:
	var row := UiKit.row(form)
	var text := Label.new()
	text.text = label
	text.custom_minimum_size.x = 300
	row.add_child(text)
	return row


func _spin(value: float, integer: bool) -> SpinBox:
	var spin := SpinBox.new()
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.min_value = -1000
	spin.max_value = 10000
	spin.step = 1.0 if integer else 0.01
	spin.custom_minimum_size.x = 110
	spin.set_value_no_signal(value)
	return spin


func _option(parent: Control, label: String, items: Array, selected: int, callback: Callable) -> void:
	var row: Control = _labeled(parent, label) if label != "" else parent
	var option := OptionButton.new()
	for item: String in items:
		option.add_item(item)
	option.select(selected)
	option.item_selected.connect(callback)
	row.add_child(option)


## Auswahl eines Spell-Werts (Schaden, Burn, ...).
func _stat_option(parent: Control, stat: StringName, callback: Callable) -> void:
	var values := ContentText.all_values()
	var names: Array = []
	for value in values:
		names.append(ContentText.value_name(value))
	var option := OptionButton.new()
	for i in names.size():
		option.add_item(names[i])
	option.select(maxi(0, values.find(stat)))
	option.item_selected.connect(func(i: int) -> void: callback.call(values[i]))
	parent.add_child(option)


## Ein Spell-Wert, den die Gravur noch nicht als festen Wert hat.
func _free_stat(e: EngravingDef) -> StringName:
	for value in ContentText.all_values():
		if not e.base_stats.has(value):
			return value
	return &"damage"


## Nach jeder Änderung: speichern, Markierung und Beschreibung aktualisieren;
## `rebuild` baut das Formular neu (Zeilen hinzugefügt oder entfernt).
func _changed(tab: int, rebuild := false) -> void:
	Balance.save()
	var key := _current_key(tab)
	_lists[tab].set_item_text(_selected[tab], ("• " if Balance.is_changed(key) else "   ") + _title(key))
	if is_instance_valid(_reset_button):
		_reset_button.disabled = not Balance.is_changed(key)
	if rebuild:
		_build_form(tab)
	elif _resource(key) is EngravingDef:
		_update_description(_resource(key))


func _update_description(e: EngravingDef) -> void:
	if _description != null and is_instance_valid(_description):
		_description.text = "[color=#bbbbbb]%s[/color]" % tooltips.linkify(ContentText.describe(e, CONTENT))
