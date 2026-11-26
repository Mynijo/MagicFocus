class_name UiKit
extends RefCounted
## Bausteine für die im Code aufgebauten Oberflächen (Werkstatt, Arena).

const COLOR_BACKGROUND := Color(0.12, 0.12, 0.15)
const COLOR_HEADER := Color(0.7, 0.8, 1.0)
const COLOR_HINT := Color(0.7, 0.7, 0.75)
const COLOR_STATUS := Color(1, 0.85, 0.4)


## Vollflächiger Hintergrund.
static func background(parent: Control) -> void:
	var rect := ColorRect.new()
	rect.color = COLOR_BACKGROUND
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(rect)


static func margin(parent: Control, size := 10) -> MarginContainer:
	var box := MarginContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		box.add_theme_constant_override("margin_" + side, size)
	parent.add_child(box)
	return box


static func row(parent: Control, separation := 4) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box


static func header(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", COLOR_HEADER)
	parent.add_child(label)
	return label


## Kleiner grauer Hinweistext mit Zeilenumbruch.
static func hint(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", COLOR_HINT)
	parent.add_child(label)
	return label


## Text mit Begriffs-Tooltips (BBCode); die Höhe passt sich dem Inhalt an.
static func rich_label(parent: Control, bbcode: String, font_size: int, tooltips: TermTooltips) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	label.text = bbcode
	tooltips.register(label)
	parent.add_child(label)
	return label


static func button(parent: Control, text: String, callback: Callable, expand := true) -> Button:
	var b := Button.new()
	b.text = text
	if expand:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


## Umschaltknopf in einer Gruppe (nur einer ist gedrückt).
static func toggle_button(parent: Control, text: String, group: ButtonGroup, expand := true) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	if expand:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(b)
	return b


static func check(parent: Control, text: String, value: bool, callback: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = value
	box.toggled.connect(callback)
	parent.add_child(box)
	return box
