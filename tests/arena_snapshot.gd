extends Node
## Visueller Test der Arena: zwei Magier mit Spells aus Beispiel-Foki (nicht aus
## user://), Kampf wird ein Stück vorgespult.
## Rendern:  godot --path <projekt> res://tests/arena_snapshot.tscn --write-movie out.png --quit-after 4 --fixed-fps 30 -- [--seconds=N] [--stats]

const ARENA := preload("res://ui/arena/arena.tscn")


func _ready() -> void:
	var arena := ARENA.instantiate()
	add_child(arena)
	await get_tree().process_frame
	var content: CraftingContent = arena.CONTENT
	var left := _mage("Feuermagier", content, [[&"feuerball", &"crit"], [&"magischer_bolzen", &"status_burn"]], content.elements)
	var right := _mage("Wassermagier", content, [[&"freeze", &"status_nass"], [&"heal", &"armor"]], content.elements)
	arena.combat = Combat.new(left, right, arena.RULES, 3)
	var seconds := 8.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			seconds = float(arg.trim_prefix("--seconds="))
	while arena.combat.time < seconds and not arena.combat.over:
		arena.combat.step()
	print("Kampf: %.1f s, Sieger %d, Leben %d / %d" % [arena.combat.time, arena.combat.winner, arena.combat.mages[0].hp, arena.combat.mages[1].hp])
	arena._set_speed(0)
	if OS.get_cmdline_user_args().has("--stats"):
		arena._tabs.current_tab = 1
	arena._update_view()


## Magier mit je einem Spell pro Gravur-Paar (Hauptgravur, Nebengravur).
func _mage(p_name: String, content: CraftingContent, pairs: Array, elements: Array[ElementDef]) -> CombatMage:
	var foci: Array[FocusInstance] = []
	var names := PackedStringArray()
	for pair: Array in pairs:
		var focus := FocusInstance.new()
		focus.focus_def = content.get_focus(&"mittlerer_fokus")
		focus.element_fill = { &"fire": 20, &"water": 20 }
		focus.dot_seed = 11
		focus.gems = [
			PlacedGem.create(content.get_gem(&"hauptgem_mittel_grob"), content.get_engraving(pair[0]), Vector2(-150, 100)),
			PlacedGem.create(content.get_gem(&"nebengem_mittel_spitz"), content.get_engraving(pair[1]), Vector2(150, 100)),
			PlacedGem.create(content.get_gem(&"nebengem_mittel_grob"), content.get_engraving(&"standard"), Vector2(0, -180)),
		]
		focus.loop = PackedInt32Array([0, 1, 2])
		focus.loop_closed = true
		foci.append(focus)
		names.append("%s + %s" % [content.get_engraving(pair[0]).display_name, content.get_engraving(pair[1]).display_name])
	var warnings: Array[String] = []
	var mage := CombatMage.from_foci(p_name, foci, names, elements, warnings)
	for w in warnings:
		push_warning(w)
	return mage
