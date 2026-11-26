extends Control
## Arena (M6, Schritt 1): zwei Magier aus gespeicherten Foki kämpfen gegeneinander.
## Die Oberfläche wird im Code aufgebaut; die Logik steckt in core/combat/.

const CONTENT := preload("res://content/crafting_content.tres")
const RULES := preload("res://content/combat_rules.tres")
const WORKSHOP_SCENE := "res://ui/workshop/workshop.tscn"
const SPEEDS := [0.0, 1.0, 2.0, 4.0]
const SPEED_NAMES := ["Pause", "1×", "2×", "4×"]
const SIDE_COLORS := ["#8fc8ff", "#ffb08f"]
const EMPTY_SLOT := "– leer –"
const STAT_BAR_LENGTH := 24  # Zeichen für 100 % im Schadensmesser
## Kampf-Status -> Begriff (für Symbol und Tooltip)
const STATUS_TERMS := {
	&"burn": &"burn", &"bleed": &"bleed", &"wet": &"nass", &"shock": &"schock", &"slow": &"slowed",
	&"mana_burn": &"mana_burn", &"armor": &"armor", &"hasted": &"hasted", &"life_regen": &"leben_reg",
	&"mana_regen": &"mana_reg", &"ice": &"eis",
}

## Auswahl bleibt erhalten, wenn man zwischendurch in die Werkstatt wechselt.
static var _saved_slots := [[], []]
static var _saved_names := ["Magier links", "Magier rechts"]

var tooltips: TermTooltips
var combat: Combat
var _speed := 1.0
var _accumulator := 0.0
var _shown_events := 0

var _name_edits: Array[LineEdit] = []
var _slot_selects: Array = [[], []]  # pro Seite: Array[OptionButton]
var _hp_bars: Array[ProgressBar] = []
var _hp_labels: Array[Label] = []
var _mana_bars: Array[ProgressBar] = []
var _mana_labels: Array[Label] = []
var _cast_bars: Array[ProgressBar] = []
var _cast_labels: Array[Label] = []
var _status_texts: Array[RichTextLabel] = []
var _log: RichTextLabel
var _tabs: TabContainer
var _stats_texts: Array[RichTextLabel] = []
var _result: Label
var _seed: SpinBox
var _speed_buttons: Array[Button] = []


func _ready() -> void:
	tooltips = TermTooltips.new()
	tooltips.setup(CONTENT)
	add_child(tooltips)
	_build_ui()
	_set_speed(1)


# --- Aufbau -----------------------------------------------------------------

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.12, 0.12, 0.15)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# Kopfzeile
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	_button(top, "← Werkstatt", func() -> void: get_tree().change_scene_to_file(WORKSHOP_SCENE))
	_button(top, "Kampf starten", _start_combat)
	var speed_group := ButtonGroup.new()
	for i in SPEEDS.size():
		var b := _button(top, SPEED_NAMES[i], _set_speed.bind(i))
		b.toggle_mode = true
		b.button_group = speed_group
		_speed_buttons.append(b)
	var seed_label := Label.new()
	seed_label.text = "  Seed"
	top.add_child(seed_label)
	_seed = SpinBox.new()
	_seed.max_value = 999999
	_seed.value = 1
	top.add_child(_seed)
	_button(top, "Neuer Seed", func() -> void: _seed.value = randi() % 1000000)
	_result = Label.new()
	_result.add_theme_font_size_override("font_size", 18)
	_result.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	top.add_child(_result)

	# Zwei Magier nebeneinander, Log darunter
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 16)
	root.add_child(sides)
	for side in 2:
		sides.add_child(_build_side(side))

	# Unten: Log und Statistik als Reiter
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	_log = RichTextLabel.new()
	_log.name = "Log"
	_log.bbcode_enabled = true
	_log.scroll_following = true
	tooltips.register(_log)
	_tabs.add_child(_log)
	var stats_row := HBoxContainer.new()
	stats_row.name = "Statistik"
	stats_row.add_theme_constant_override("separation", 24)
	_tabs.add_child(stats_row)
	for side in 2:
		var stats := RichTextLabel.new()
		stats.bbcode_enabled = true
		stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tooltips.register(stats)
		stats_row.add_child(stats)
		_stats_texts.append(stats)


func _build_side(side: int) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var name_edit := LineEdit.new()
	name_edit.text = _saved_names[side]
	name_edit.add_theme_color_override("font_color", Color(SIDE_COLORS[side]))
	name_edit.text_changed.connect(func(text: String) -> void: _saved_names[side] = text)
	box.add_child(name_edit)
	_name_edits.append(name_edit)

	var names := FocusStore.list_names()
	if names.is_empty():
		_small(box, "Noch keine gespeicherten Foki. Speichere zuerst welche in der Werkstatt.")
	_small(box, "Spells in Cast-Reihenfolge (bis zu %d):" % CombatMage.MAX_SPELLS)
	for slot in CombatMage.MAX_SPELLS:
		var select := OptionButton.new()
		select.add_item(EMPTY_SLOT)
		for n in names:
			select.add_item(n)
		var saved: Array = _saved_slots[side]
		if slot < saved.size():
			for i in select.item_count:
				if select.get_item_text(i) == saved[slot]:
					select.select(i)
		select.item_selected.connect(func(_i: int) -> void: _remember_slots(side))
		box.add_child(select)
		_slot_selects[side].append(select)

	_hp_bars.append(_bar(box, Color(0.75, 0.25, 0.25)))
	_hp_labels.append(_bar_label(_hp_bars.back()))
	_mana_bars.append(_bar(box, Color(0.3, 0.45, 0.95)))
	_mana_labels.append(_bar_label(_mana_bars.back()))
	_cast_bars.append(_bar(box, Color(0.95, 0.8, 0.35)))
	_cast_labels.append(_bar_label(_cast_bars.back()))

	var status := RichTextLabel.new()
	status.bbcode_enabled = true
	status.fit_content = true
	status.scroll_active = false
	status.custom_minimum_size.y = 34
	tooltips.register(status)
	box.add_child(status)
	_status_texts.append(status)
	return panel


func _bar(parent: Control, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 22
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _bar_label(bar: ProgressBar) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	bar.add_child(label)
	return label


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _small(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	parent.add_child(label)


# --- Kampf ------------------------------------------------------------------

func _remember_slots(side: int) -> void:
	var names: Array = []
	for select: OptionButton in _slot_selects[side]:
		names.append(select.get_item_text(select.selected))
	_saved_slots[side] = names


func _start_combat() -> void:
	var warnings: Array[String] = []
	var mages: Array[CombatMage] = []
	for side in 2:
		var foci: Array[FocusInstance] = []
		var names := PackedStringArray()
		for select: OptionButton in _slot_selects[side]:
			var focus_name := select.get_item_text(select.selected)
			if focus_name == EMPTY_SLOT:
				continue
			var focus := FocusStore.load_focus(focus_name, CONTENT, warnings)
			if focus != null:
				foci.append(focus)
				names.append(focus_name)
		mages.append(CombatMage.from_foci(_name_edits[side].text, foci, names, CONTENT.elements, warnings))
	combat = Combat.new(mages[0], mages[1], RULES, int(_seed.value))
	_accumulator = 0.0
	_shown_events = 0
	_log.clear()
	for w in warnings:
		_log.append_text("[color=#ff9090]%s[/color]\n" % w)
	_result.text = ""
	if _speed == 0.0:
		_set_speed(1)
	_update_view()


func _set_speed(index: int) -> void:
	_speed = SPEEDS[index]
	_speed_buttons[index].button_pressed = true


func _process(delta: float) -> void:
	if combat == null or combat.over or _speed == 0.0:
		return
	_accumulator += delta * _speed
	while _accumulator >= RULES.tick and not combat.over:
		combat.step()
		_accumulator -= RULES.tick
	_update_view()


func _update_view() -> void:
	if combat == null:
		return
	for side in 2:
		var mage := combat.mages[side]
		_hp_bars[side].max_value = mage.max_hp
		_hp_bars[side].value = maxf(mage.hp, 0.0)
		_hp_labels[side].text = "Leben %d / %d" % [maxi(int(ceil(mage.hp)), 0), int(mage.max_hp)]
		_mana_bars[side].max_value = mage.max_mana
		_mana_bars[side].value = mage.mana
		_mana_labels[side].text = "Mana %d / %d" % [int(mage.mana), int(mage.max_mana)]
		if mage.casting >= 0:
			_cast_bars[side].max_value = mage.cast_total
			_cast_bars[side].value = mage.cast_elapsed
			_cast_labels[side].text = "%s%s" % [mage.casting_name(), "  (betäubt)" if mage.is_stunned() else ""]
		else:
			_cast_bars[side].value = 0.0
			_cast_labels[side].text = "betäubt" if mage.is_stunned() else ("wartet auf Mana" if mage.waiting_for_mana else "")
		_status_texts[side].text = _status_text(mage)
	# Statistik nur neu aufbauen, wenn etwas passiert ist (sonst flackern die Tooltips)
	if _shown_events < combat.events.size() or _shown_events == 0:
		for side in 2:
			_stats_texts[side].text = _statistics_text(side)
	while _shown_events < combat.events.size():
		var event: Dictionary = combat.events[_shown_events]
		var color: String = SIDE_COLORS[event.mage] if event.mage >= 0 else "#ffd966"
		_log.append_text(tooltips.linkify("[color=#888888]%5.1f s[/color]  [color=%s]%s[/color]\n" % [event.time, color, event.text]))
		_shown_events += 1
	if combat.over:
		_result.text = "  " + ("Unentschieden" if combat.winner < 0 else "%s gewinnt!" % combat.mages[combat.winner].mage_name)


## Schadensmesser eines Magiers: Quellen mit Balken, Anteil, Casts und Crits,
## darunter Heilung und von Armor abgefangener Schaden.
func _statistics_text(side: int) -> String:
	var mage := combat.mages[side]
	var stats: Dictionary = combat.statistics[side]
	var damage: Dictionary = stats.damage
	var total := Combat.total(damage)
	var color: String = SIDE_COLORS[side]
	var t := "[font_size=17][b][color=%s]%s[/color][/b][/font_size]\n" % [color, mage.mage_name]
	t += "Schaden gesamt: [b]%d[/b]   ·   Kampfzeit %d s   ·   %s pro Sekunde\n\n" % [
		int(total), int(combat.time), _num(total / maxf(combat.time, 0.1))]
	if damage.is_empty():
		t += "[color=#777777]noch kein Schaden[/color]\n"
	else:
		t += "[table=5]"
		for header in ["Quelle", "", "Schaden", "Anteil", "Casts / Crits"]:
			t += "[cell][color=#999999]%s[/color]   [/cell]" % header
		var sources := damage.keys()
		sources.sort_custom(func(a: String, b: String) -> bool: return damage[a] > damage[b])
		for source: String in sources:
			var value: float = damage[source]
			var share := value / total if total > 0.0 else 0.0
			var bar := "█".repeat(maxi(1, int(round(share * STAT_BAR_LENGTH))))
			var casts := int(stats.casts.get(source, 0))
			var counts := "%d / %d" % [casts, int(stats.crits.get(source, 0))] if casts > 0 else "–"
			t += "[cell]%s   [/cell][cell][color=%s]%s[/color]   [/cell][cell]%d   [/cell][cell]%d %%   [/cell][cell]%s[/cell]" % [
				source, color, bar, int(value), int(round(share * 100.0)), counts]
		t += "[/table]\n"
	var heal := Combat.total(stats.heal)
	t += "\nHeilung: [b]%d[/b]" % int(heal)
	if heal > 0.0:
		var parts := PackedStringArray()
		for source: String in stats.heal:
			parts.append("%s %d" % [source, int(stats.heal[source])])
		t += "  (%s)" % ", ".join(parts)
	t += "\nVon Armor abgefangen: [b]%d[/b]" % int(stats.absorbed)
	return tooltips.linkify(t)


static func _num(value: float) -> String:
	return "%.1f" % value


## Status als Symbole mit Stacks, z. B. "[Burn-Symbol] Burn 3".
func _status_text(mage: CombatMage) -> String:
	var parts := PackedStringArray()
	for stat: StringName in STATUS_TERMS:
		var n := mage.stacks(stat)
		if n <= 0:
			continue
		var term := CONTENT.get_term(STATUS_TERMS[stat])
		var icon := ""
		if term != null and term.icon != null:
			icon = "[img width=22 height=22]%s[/img] " % term.icon.resource_path
		parts.append("%s%s %d" % [icon, Combat.STATUS_NAMES[stat], n])
	if parts.is_empty():
		return "[color=#777777]keine Status[/color]"
	return tooltips.linkify("   ".join(parts))
