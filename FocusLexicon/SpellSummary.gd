extends Node2D

@export var FocusCore : PackedScene = null 
@export var Focus : PackedScene = null

var FocusCore_obj = null 
var Focus_obj  = null

var Spell = null 
var is_refreshed = false

var Default_icon

# Called when the node enters the scene tree for the first time.
func _ready():
	if FocusCore != null:
		FocusCore_obj = FocusCore.instantiate()
	if Focus != null:
		Focus_obj = Focus.instantiate()
		
	Default_icon = $MainContainer/CenterContainer/SpellIcon.texture
	refresh() # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func add_focus(focus):
	Focus_obj = focus
	is_refreshed = false
	refresh()
	
func reset():
	$MainContainer/CenterContainer/SpellIcon.texture = Default_icon
	$MainContainer/ModContainer/AttackModContainer/Dmg/Value.text = "0"
	$MainContainer/ModContainer/AttackModContainer/Max_targes/Value.text = "0"
	#$MainContainer/ModContainer/AttackModContainer/Debuffs/Value.text = "0"
	$MainContainer/ModContainer/DefModContainer/Mana/Value.text = "0"
	$MainContainer/ModContainer/DefModContainer/Shield/Value.text = "0"
	$MainContainer/ModContainer/DefModContainer/Health/Value.text = "0"
	#$MainContainer/ModContainer/DefModContainer/Buffs/Value.text = "0"

func refresh():
	if is_refreshed:
		return
	if Focus_obj == null or FocusCore_obj == null:
		reset()
		return
	if Spell != null:
		Spell.free()
	Spell = FocusCore_obj.get_spell(Focus_obj)
	if Spell == null:
		reset()
		return
	$MainContainer/CenterContainer/SpellIcon.texture = Spell.get_icon().texture
	
	$MainContainer/ModContainer/AttackModContainer/Dmg/Value.text = "%d" % Spell.get_Dmg()
	$MainContainer/ModContainer/AttackModContainer/Max_targes/Value.text = "%d" % Spell.get_Max_targes()
	#$MainContainer/ModContainer/AttackModContainer/Debuffs/Value.text = Spell.get_Debuffs()
	$MainContainer/ModContainer/DefModContainer/Mana/Value.text ="%d" % Spell.get_Mana()
	$MainContainer/ModContainer/DefModContainer/Shield/Value.text = "%d" % Spell.get_Shield()
	$MainContainer/ModContainer/DefModContainer/Health/Value.text = "%d" % Spell.get_Health()
	#$MainContainer/ModContainer/DefModContainer/Buffs/Value.text = Spell.get_Buffs()
	
		
	is_refreshed = true
	
