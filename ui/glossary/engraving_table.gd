class_name EngravingTable
extends VBoxContainer
## Gravuren als sortierbare Tabelle (Glossar): zuerst die Faktoren der fünf Elemente,
## dann neutrale Essenz, Gravur, Rolle, Ziel und Wirkung. Klick auf eine Spaltenüberschrift
## sortiert (zweiter Klick: umgekehrt); Gruppierung nach Element, Rolle oder ohne.

enum Group { ELEMENT, ROLE, NONE }

const GROUP_NAMES := ["Gruppieren nach Element", "Gruppieren nach Rolle", "Keine Gruppen"]
const NEUTRAL_ICON := preload("res://assets/sprites/element_neutral.png")
const NEUTRAL_COLOR := Color(0.8, 0.8, 0.88)
const ICON_WIDTH := 18
const DIM := Color(0.6, 0.6, 0.65)

var content: CraftingContent
## Suchtext (leer = alle)
var filter := ""
var _tree: Tree
var _group := Group.ELEMENT
var _sort_column := -1  # -1 = Reihenfolge der Inhalte
var _sort_descending := false
## Spalten: 0 = Aufklapp-Pfeil der Gruppen, 1..n Elemente, dann diese
var _col_neutral: int
var _col_name: int
var _col_role: int
var _col_target: int
var _col_effect: int


func setup(p_content: CraftingContent) -> void:
	content = p_content
	var bar := HBoxContainer.new()
	add_child(bar)
	var group_select := OptionButton.new()
	for group_name: String in GROUP_NAMES:
		group_select.add_item(group_name)
	group_select.item_selected.connect(func(i: int) -> void:
		_group = i as Group
		refresh())
	bar.add_child(group_select)
	UiKit.hint(bar, "  Sortieren: Spaltenüberschrift anklicken · Vollständige Wirkung im Tooltip", false)

	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.select_mode = Tree.SELECT_ROW
	var n := content.elements.size()
	_col_neutral = n + 1
	_col_name = n + 2
	_col_role = n + 3
	_col_target = n + 4
	_col_effect = n + 5
	_tree.columns = n + 6
	_setup_column(0, "", 28)
	for i in n:
		_setup_column(i + 1, content.elements[i].display_name, 70)
	_setup_column(_col_neutral, "Neutral", 70)
	_setup_column(_col_name, "Gravur", 190)
	_setup_column(_col_role, "Rolle", 110)
	_setup_column(_col_target, "Ziel", 80)
	_setup_column(_col_effect, "Wirkung", 300, true)
	_tree.column_title_clicked.connect(_on_title_clicked)
	add_child(_tree)
	refresh()


func _setup_column(column: int, title: String, width: int, expand := false) -> void:
	_tree.set_column_title(column, title)
	_tree.set_column_title_alignment(column, HORIZONTAL_ALIGNMENT_LEFT)
	_tree.set_column_expand(column, expand)
	_tree.set_column_custom_minimum_width(column, width)
	_tree.set_column_clip_content(column, true)


func _on_title_clicked(column: int, _mouse_button: int) -> void:
	if column == 0:
		return
	if column == _sort_column:
		_sort_descending = not _sort_descending
	else:
		_sort_column = column
		_sort_descending = false
	refresh()


## Baut die Tabelle neu (nach Suche, Sortierung, Gruppierung oder Wertänderung).
func refresh() -> void:
	if _tree == null:
		return
	_tree.clear()
	var root := _tree.create_item()
	var list: Array[EngravingDef] = []
	for e in content.engravings:
		if filter == "" or (e.display_name + " " + ContentText.describe(e, content)).to_lower().contains(filter.to_lower()):
			list.append(e)
	if _sort_column >= 0:
		list.sort_custom(func(a: EngravingDef, b: EngravingDef) -> bool:
			var ka: Variant = _sort_key(a)
			var kb: Variant = _sort_key(b)
			if ka == kb:
				return a.display_name < b.display_name
			return (ka > kb) if _sort_descending else (ka < kb))
	for group: Array in _groups(list):
		var parent := root
		if _group != Group.NONE:
			parent = _tree.create_item(root)
			parent.set_text(_col_name, group[0])
			parent.set_custom_color(_col_name, group[1])
			for c in _tree.columns:
				parent.set_selectable(c, false)
		for e: EngravingDef in group[2]:
			_add_row(parent, e)


## [[Titel, Farbe, Gravuren], ...] in fester Reihenfolge, leere Gruppen fallen weg.
func _groups(list: Array[EngravingDef]) -> Array:
	var result := []
	match _group:
		Group.NONE:
			result.append(["", Color.WHITE, list])
		Group.ROLE:
			for role in [GemDef.Role.MAIN, GemDef.Role.MINOR]:
				result.append(["Hauptgravuren" if role == GemDef.Role.MAIN else "Nebengravuren", Color.WHITE,
					list.filter(func(e: EngravingDef) -> bool: return e.role == role)])
		Group.ELEMENT:
			for element in content.elements:
				result.append([element.display_name, element.color, list.filter(func(e: EngravingDef) -> bool:
					return e.element_factors.size() == 1 and e.counts_element(element.id))])
			var total := content.elements.size()
			result.append(["Mehrere Elemente", Color.WHITE, list.filter(func(e: EngravingDef) -> bool:
				return e.element_factors.size() > 1 and e.element_factors.size() < total)])
			result.append(["Alle Elemente", Color.WHITE, list.filter(func(e: EngravingDef) -> bool:
				return e.element_factors.size() == total)])
			result.append(["Ohne Element", Color.WHITE, list.filter(func(e: EngravingDef) -> bool:
				return e.element_factors.is_empty())])
	return result.filter(func(g: Array) -> bool: return not g[2].is_empty())


func _add_row(parent: TreeItem, e: EngravingDef) -> void:
	var item := _tree.create_item(parent)
	for i in content.elements.size():
		var element := content.elements[i]
		if e.counts_element(element.id):
			_factor_cell(item, i + 1, element.icon, element.color, e.factor_of(element.id))
	if ContentText.counts_base(e):
		_factor_cell(item, _col_neutral, NEUTRAL_ICON, NEUTRAL_COLOR, 1.0)
	item.set_text(_col_name, e.display_name)
	if e.icon != null:
		item.set_icon(_col_name, e.icon)
		item.set_icon_max_width(_col_name, ICON_WIDTH)
	item.set_text(_col_role, "Hauptgravur" if e.role == GemDef.Role.MAIN else "Nebengravur")
	item.set_custom_color(_col_role, DIM)
	if e.role == GemDef.Role.MAIN:
		item.set_text(_col_target, ContentText.TARGET_NAMES[e.target].capitalize())
	var effect := ContentText.describe(e, content, false, false)
	item.set_text(_col_effect, effect)
	for c in _tree.columns:
		item.set_tooltip_text(c, "%s: %s" % [e.display_name, effect])


func _factor_cell(item: TreeItem, column: int, icon: Texture2D, color: Color, factor: float) -> void:
	item.set_icon(column, icon)
	item.set_icon_modulate(column, color)
	item.set_icon_max_width(column, ICON_WIDTH)
	item.set_text(column, "×" + TextFormat.number(factor))
	item.set_custom_color(column, color)


## Sortierwert einer Gravur für die aktuelle Spalte.
func _sort_key(e: EngravingDef) -> Variant:
	if _sort_column >= 1 and _sort_column <= content.elements.size():
		return e.factor_of(content.elements[_sort_column - 1].id)
	if _sort_column == _col_neutral:
		return 1.0 if ContentText.counts_base(e) else 0.0
	if _sort_column == _col_role:
		return int(e.role)
	if _sort_column == _col_target:
		return int(e.target) if e.role == GemDef.Role.MAIN else -1
	if _sort_column == _col_effect:
		return ContentText.describe(e, content, false, false)
	return e.display_name


## Anzahl der Gravur-Zeilen (für Tests).
func row_count() -> int:
	var count := 0
	var item := _tree.get_root().get_first_child() if _tree.get_root() != null else null
	while item != null:
		if item.get_child_count() > 0:
			count += item.get_child_count()
		elif item.get_text(_col_effect) != "":
			count += 1
		item = item.get_next()
	return count
