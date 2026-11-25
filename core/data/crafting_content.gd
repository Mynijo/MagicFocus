class_name CraftingContent
extends Resource
## Sammlung aller verfügbaren Inhalte: Elemente, Gem-Formen, Gravuren, Foki.
## Die Reihenfolge der Listen bestimmt die Reihenfolge in der Oberfläche.

@export var elements: Array[ElementDef] = []
@export var gems: Array[GemDef] = []
@export var engravings: Array[EngravingDef] = []
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


## Gem-Form zu Rolle, Größe und Winkel (Auswahl in der Werkstatt).
func find_gem(role: GemDef.Role, size: GemDef.Size, angle: GemDef.Angle) -> GemDef:
	for gem in gems:
		if gem.role == role and gem.size == size and gem.angle == angle:
			return gem
	return null


func get_engraving(id: StringName) -> EngravingDef:
	for engraving in engravings:
		if engraving.id == id:
			return engraving
	return null


func get_engravings_for(role: GemDef.Role) -> Array[EngravingDef]:
	var list: Array[EngravingDef] = []
	for engraving in engravings:
		if engraving.role == role:
			list.append(engraving)
	return list


func get_focus(id: StringName) -> FocusDef:
	for focus in foci:
		if focus.id == id:
			return focus
	return null
