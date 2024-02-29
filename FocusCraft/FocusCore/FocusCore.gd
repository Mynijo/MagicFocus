extends Node2D

@export var Dot_color_mod = []
@export var Spells: Array[PackedScene] = []

@export var Dot_base_scaling = [{"Dmg_mod": 	[Color.RED, 1,1]}, 
								{"Mana_mod": 	[Color.BLUE, 1,1]}, 
								{"Shield_mod": [Color.GRAY, 1,1]}, 
								{"Health_mod": [Color.GREEN, 1,1]}]

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func get_spell(Focus):
	var spell = null
	if Focus != null:
		spell = find_spell_by_color_combination(Focus.get_colors())
	if spell != null:
		spell.set_Dot_base_scaling(Dot_base_scaling)
		spell.set_Focus(Focus)
	return spell

func find_spell_by_color_combination(color_combination: Array[Color]):
	for spell in Spells:
		# Instanziere die Szene temporär, um auf ihre Eigenschaften zuzugreifen
		var instance = spell.instantiate()
		# Zugriff auf die Color_combination Variable der Szene
		var spell_color_combination = instance.Color_combination
		
		# Initialisiere is_match als true
		var is_match = true
		if spell_color_combination.size() == color_combination.size():
			for i in range(color_combination.size()):
				if spell_color_combination[i] != color_combination[i]:
					is_match = false
					break
		else:
			is_match = false
		if is_match:
			return instance  # Gibt das gefundene PackedScene zurück
		# Optional: Entferne die Instanz, wenn sie nicht mehr benötigt wird
		instance.queue_free()	
	return null  # Kein entsprechendes PackedScene gefunden
