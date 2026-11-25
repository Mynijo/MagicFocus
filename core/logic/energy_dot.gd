class_name EnergyDot
extends RefCounted
## Ein einzelner Energiepunkt im Fokus.

var position: Vector2
## &"" = Basis-Energiepunkt, sonst die ID des Elements.
var element_id: StringName


func _init(p_position: Vector2 = Vector2.ZERO, p_element_id: StringName = &"") -> void:
	position = p_position
	element_id = p_element_id


func is_base() -> bool:
	return element_id == &""
