extends Control
## Glossar: alle Status, Gravuren, Gem-Formen, Foki, Elemente und Kampfregeln mit ihren
## aktuellen Werten (inklusive Änderungen aus dem Editor). Nur zum Nachschlagen.

const CONTENT := preload("res://content/crafting_content.tres")
const RULES := preload("res://content/combat_rules.tres")
const WORKSHOP_SCENE := "res://ui/workshop/workshop.tscn"
const ARENA_SCENE := "res://ui/arena/arena.tscn"
const ICON_SIZE := 22
## Reiter: Titel -> Funktion, die den Text baut
const TABS := ["Status", "Gravuren", "Gems", "Foki", "Elemente", "Kampfregeln"]

var tooltips: TermTooltips
var _tabs: TabContainer
## Reiter-Titel -> RichTextLabel (alle außer Gravuren)
var _texts := {}
## Reiter Gravuren: sortierbare Tabelle
var _engraving_table: EngravingTable
var _search: LineEdit


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
	UiKit.button(top, "Arena", func() -> void: get_tree().change_scene_to_file(ARENA_SCENE), false)
	UiKit.button(top, "Editor", func() -> void: get_tree().change_scene_to_file("res://ui/editor/editor.tscn"), false)
	_search = LineEdit.new()
	_search.placeholder_text = "Suchen …"
	_search.custom_minimum_size.x = 260
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String) -> void: refresh())
	top.add_child(_search)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	for title: String in TABS:
		if title == "Gravuren":
			_engraving_table = EngravingTable.new()
			_engraving_table.name = title
			_tabs.add_child(_engraving_table)
			_engraving_table.setup(CONTENT)
			continue
		var label := RichTextLabel.new()
		label.name = title
		label.bbcode_enabled = true
		label.selection_enabled = true
		tooltips.register(label)
		_tabs.add_child(label)
		_texts[title] = label
	refresh()
	# Für Render-Checks: --tab=N zeigt Reiter N
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tab="):
			_tabs.current_tab = int(arg.trim_prefix("--tab="))


func refresh() -> void:
	var texts := { "Status": _status_text(), "Gems": _gems_text(), "Foki": _foci_text(),
		"Elemente": _elements_text(), "Kampfregeln": _rules_text() }
	for title: String in texts:
		(_texts[title] as RichTextLabel).text = tooltips.linkify(texts[title])
	if _engraving_table != null:
		_engraving_table.filter = _search.text.strip_edges()
		_engraving_table.refresh()


## Passt ein Eintrag zur Suche? (Groß-/Kleinschreibung egal)
func _matches(text: String) -> bool:
	return _search.text.strip_edges() == "" or text.to_lower().contains(_search.text.strip_edges().to_lower())


# --- Reiter --------------------------------------------------------------------

func _status_text() -> String:
	var t := ""
	t += _term_section("Debuffs", Status.DEBUFFS)
	t += _term_section("Buffs", Status.BUFFS)
	var others: Array[StringName] = []
	for id: StringName in GlossaryBuilder.TERMS:
		if not Status.NAMES.has(id):
			others.append(id)
	t += _term_section("Weitere Begriffe", others)
	return t


func _term_section(title: String, ids: Array[StringName]) -> String:
	var t := ""
	for id in ids:
		var term := CONTENT.get_term(id)
		if term != null and _matches(term.title + " " + term.text):
			t += "%s[b]%s[/b]\n[indent]%s[/indent]\n" % [_icon(term.icon, term.icon_color), term.title, term.text]
	return _section(title, t)



func _gems_text() -> String:
	var rows := ""
	for gem in CONTENT.gems:
		if _matches(gem.display_name):
			rows += _row([gem.display_name, TextFormat.number(gem.radius), str(gem.max_base), str(gem.max_element),
				TextFormat.number(gem.body_radius), "Innenwinkel ×%s" % TextFormat.number(gem.get_multiplier())
				if gem.is_inner() else "Außenwinkel ×1"])
	return _table(["Gem", "Radius", "neutrale Essenz", "Essenzen", "Stein", "Bereich"], rows) + \
		"\n[color=#999999]Radius: Reichweite beim Einsammeln. Stein: Essenz darunter ist verdeckt und zählt nicht. Spitz zählt alles Eingesammelte doppelt.[/color]\n"


func _foci_text() -> String:
	var rows := ""
	for def in CONTENT.foci:
		if not _matches(def.display_name):
			continue
		var size := PackedStringArray()
		for field in Balance.number_fields(def.shape):
			size.append("%s %s" % [FocusShape.FIELD_LABELS.get(field, field), TextFormat.number(def.shape.get(field))])
		rows += _row(["[nolink]%s[/nolink]" % def.display_name, def.shape.get_shape_name(), str(def.max_gems), str(def.max_dots),
			str(def.max_element_dots), _allowed_text(def), ", ".join(size)])
	return _table(["Fokus", "Form", "Gems", "Kapazität", "davon Essenzen", "Elemente", "Größe"], rows) + \
		"\n[color=#999999]Kapazität: neutrale Essenz und Essenzen zusammen; neutrale Essenz füllt den Rest auf.[/color]\n"


func _elements_text() -> String:
	var t := ""
	for element in CONTENT.elements:
		var term := CONTENT.get_term(element.id)
		if term != null and _matches(term.title + " " + term.text):
			t += "%s[b]%s[/b]\n[indent]%s[/indent]\n" % [_icon(term.icon, term.icon_color), term.title, term.text]
	return t


func _rules_text() -> String:
	var rows := ""
	for field: String in CombatRules.LABELS:
		var label: String = CombatRules.LABELS[field]
		if _matches(label):
			rows += _row([label, TextFormat.number(RULES.get(field))])
	return _table(["Kampfregel", "Wert"], rows)


# --- Helfer --------------------------------------------------------------------

func _section(title: String, body: String) -> String:
	if body == "":
		return ""
	return "[font_size=19][b][color=#b3ccff]%s[/color][/b][/font_size]\n%s\n" % [title, body]


func _icon(texture: Texture2D, color: Color) -> String:
	if texture == null or texture.resource_path == "":
		return ""
	return _icon_path(texture.resource_path, color) + " "


func _icon_path(path: String, color: Color) -> String:
	return "[img width=%d height=%d color=#%s]%s[/img]" % [ICON_SIZE, ICON_SIZE, color.to_html(false), path]


## Elemente einer Gravur in Elementfarbe mit Faktor, z. B. "Feuer ×5".

func _allowed_text(def: FocusDef) -> String:
	if def.max_element_dots <= 0:
		return "keine"
	if def.allowed_elements.is_empty():
		return "alle"
	var names := PackedStringArray()
	for id in def.allowed_elements:
		var element := CONTENT.get_element(id)
		names.append(element.display_name if element != null else String(id))
	return ", ".join(names)


func _table(headers: Array, rows: String) -> String:
	if rows == "":
		return "[color=#777777]Nichts gefunden.[/color]\n"
	var t := "[table=%d]" % headers.size()
	for header: String in headers:
		t += "[cell][color=#999999]%s[/color]    [/cell]" % header
	return t + rows + "[/table]\n"


func _row(cells: Array) -> String:
	var t := ""
	for cell in cells:
		t += "[cell]%s    [/cell]" % str(cell)
	return t
