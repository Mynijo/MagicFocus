extends Node2D

@export var Color_combination: Array[Color] = []
@export var Dot_color_special_mod = []

@export var SpellName = "Default"

@export var Dmg_mod = [Color.WHITE, 0 ,0 ]
@export var Mana_mod =[Color.WHITE, 0 ,0 ]
@export var Shield_mod = [Color.WHITE, 0 ,0 ]
@export var Health_mod = [Color.WHITE, 0 ,0 ]
@export var Max_targes_mod = [Color.WHITE, 0 ,0 ]

@export var Dmg_base = 0
@export var Mana_base = 0
@export var Max_targes_base = 1
@export var Shield_base = 0
@export var Health_base = 0
@export var Buffs = []
@export var Debuffs = []


var Focus
var Focus_Dots

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

	
func get_Dmg():
	var return_value = Dmg_base
	if Focus_Dots != null:
		var key = Dmg_mod[0]
		if Focus_Dots.has(key):
			return_value = Dmg_base + Focus_Dots[key] / Dmg_mod[1] * Dmg_mod[2]
	return return_value
		
func get_Mana():
	var return_value = Mana_base
	if Focus != null:
		return_value += Focus.get_connection_length()
	return_value /= 10
	if Focus_Dots != null:
		var key = Mana_mod[0]
		if Focus_Dots.has(key):
			return_value += Focus_Dots[key] / Mana_mod[1] * Mana_mod[2]
	return return_value
		
func get_Shield():
	var return_value = Shield_base
	if Focus_Dots != null:
		var key = Shield_mod[0]
		if Focus_Dots.has(key):
			return_value = Shield_base + Focus_Dots[key] / Shield_mod[1] * Shield_mod[2]
	return return_value
		
func get_Health():
	var return_value = Health_base
	if Focus_Dots != null:
		var key = Health_mod[0]
		if Focus_Dots.has(key):
			return_value = Health_base + Focus_Dots[key] / Health_mod[1] * Health_mod[2]
	return return_value
	
func get_Max_targes():
	var return_value = Max_targes_base
	if Focus_Dots != null:
		var key = Max_targes_mod[0]
		if Focus_Dots.has(key):
			return_value = Max_targes_base + Focus_Dots[key] / Max_targes_mod[1] * Max_targes_mod[2]
	return return_value
	
func get_Buffs ():
	return Buffs
	
func get_Debuffs ():
	return Debuffs

func get_icon():
	return $Icon
	
func set_Focus(focus):
	if focus != null:
		Focus = focus
		set_Focus_Dots(Focus.get_dots_sum())
	
func set_Focus_Dots(focus_Dots):
	Focus_Dots = focus_Dots
	
func set_Dot_base_scaling(dot_base_scaling):
	for mod_dict in dot_base_scaling:
		for key in mod_dict:
			var value = mod_dict[key]
			# Überprüfe, ob die aktuelle Einstellung auf die Standardwerte gesetzt ist
			var current_value = get(key)
			if current_value == [Color.WHITE, 0, 0]:
				# Setze den neuen Wert, wenn die Standardwerte vorliegen
				set(key, value)
