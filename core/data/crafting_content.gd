class_name CraftingContent
extends Resource
## Sammlung aller verfügbaren Inhalte (später: Runen-Bibliothek, Werkstatt).
## Die Reihenfolge von `elements` entscheidet bei Gleichstand der Elemente in einer Rune.

@export var elements: Array[ElementDef] = []
@export var spell_forms: Array[SpellFormDef] = []
@export var runes: Array[RuneDef] = []
@export var foci: Array[FocusDef] = []


func get_element(id: StringName) -> ElementDef:
	for element in elements:
		if element.id == id:
			return element
	return null


func get_rune(id: StringName) -> RuneDef:
	for rune in runes:
		if rune.id == id:
			return rune
	return null


func get_focus(id: StringName) -> FocusDef:
	for focus in foci:
		if focus.id == id:
			return focus
	return null
