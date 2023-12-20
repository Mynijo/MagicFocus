extends Node2D

var Focus_node_summary_scene = preload("res://FocusLexicon/FocusNodeSummary.tscn")

var Focus

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func set_Focus(focus):
	Focus = focus;
	reset_summary()
	for n in focus.Connected_nodes:
		add_FocusNode(n)
	calc_mana()
	
func calc_mana():
	var connection_length = 0
	for n in Focus.Conections:
		connection_length += n.Length
	$Mana.text = "Mana: " + str(int(connection_length))

func add_FocusNode(node):
	var focus_node_summary_instance = Focus_node_summary_scene.instantiate()
	$NodeContainer.add_child(focus_node_summary_instance)
	focus_node_summary_instance.set_FocusNode(node)

func remove_FocusNode(node):
	$NodeContainer.remove_child(node)

func reset_summary():
	for n in $NodeContainer.get_children():
		$NodeContainer.remove_child(n)
