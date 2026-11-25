class_name FocusDef
extends Resource
## Ein Fokus-Typ: Form, Größe und Kapazitäten.

enum SizeClass { SMALL, MEDIUM, LARGE, HUGE }

@export var id: StringName
@export var display_name: String
@export var shape: FocusShape
@export var size_class: SizeClass = SizeClass.SMALL
## Feste Obergrenze dieses Fokus (klein 3, mittel 3-5, groß 5-7, sehr groß bis 10).
@export var max_runes: int = 3
@export var max_base_dots: int = 100
@export var max_element_dots: int = 40
