class_name FocusDef
extends Resource
## Ein Fokus-Typ: Form, Größe, Kapazitäten und erlaubte Energiearten.
## Beispiele: Feuer-Fokus (nur Feuer, dafür viel davon), neutraler Fokus
## (keine farbigen Punkte, dafür sehr viele Basispunkte).

enum SizeClass { SMALL, MEDIUM, LARGE, HUGE }

@export var id: StringName
@export var display_name: String
@export var shape: FocusShape
@export var size_class: SizeClass = SizeClass.SMALL
## Feste Obergrenze dieses Fokus (klein 3, mittel 3-5, groß 5-7, sehr groß bis 10).
@export var max_runes: int = 3
@export var max_base_dots: int = 100
@export var max_element_dots: int = 40
## Erlaubte Elemente für farbige Punkte. Leer = alle Elemente erlaubt.
@export var allowed_elements: Array[StringName] = []


func allows_element(element_id: StringName) -> bool:
	return allowed_elements.is_empty() or allowed_elements.has(element_id)
