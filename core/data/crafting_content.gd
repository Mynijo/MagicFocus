class_name CraftingContent
extends Resource
## Sammlung aller verfügbaren Inhalte (später: Gem-Bibliothek, Werkstatt).
## Die Reihenfolge von `elements` entscheidet bei Gleichstand der Elemente in einem Gem.

@export var elements: Array[ElementDef] = []
@export var spell_forms: Array[SpellFormDef] = []
@export var gems: Array[GemDef] = []
@export var foci: Array[FocusDef] = []


func get_element(id: StringName) -> ElementDef:
	for element in elements:
		if element.id == id:
			return element
	return null


func get_gem(id: StringName) -> GemDef:
	for gem in gems:
		if gem.id == id:
			return gem
	return null


func get_focus(id: StringName) -> FocusDef:
	for focus in foci:
		if focus.id == id:
			return focus
	return null
