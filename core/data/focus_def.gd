class_name FocusDef
extends Resource
## Ein Fokus-Typ: Form, Größe, Kapazitäten und erlaubte Elemente.
## Beispiele: Feuer-Fokus (nur Feuer, dafür viel davon), neutraler Fokus
## (keine Essenzen, nur neutrale Essenz).

enum SizeClass { SMALL, MEDIUM, LARGE, HUGE }

@export var id: StringName
@export var display_name: String
@export var shape: FocusShape
@export var size_class: SizeClass = SizeClass.SMALL
## Feste Obergrenze dieses Fokus (klein 3, mittel 3-5, groß 5-7, sehr groß bis 10).
@export var max_gems: int = 3
## Gesamtkapazität für neutrale Essenz und Essenzen zusammen. Der Rest neben
## den Essenzen wird immer mit neutraler Essenz aufgefüllt.
@export var max_dots: int = 140
## Zusätzliches Limit für alle Essenzen zusammen (nicht pro Element).
@export var max_element_dots: int = 40
## Erlaubte Elemente für Essenzen. Leer = alle Elemente erlaubt.
@export var allowed_elements: Array[StringName] = []


func allows_element(element_id: StringName) -> bool:
	return allowed_elements.is_empty() or allowed_elements.has(element_id)
