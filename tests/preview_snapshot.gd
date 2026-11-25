extends Node
## Visueller Test: öffnet die Werkstatt mit Beispiel-Fokus und simuliert ein
## Nebengem unter dem Mauszeiger, um die Setz-Vorschau zu rendern.
## Rendern:  godot --path <projekt> res://tests/preview_snapshot.tscn --write-movie out.png --quit-after 5

const WORKSHOP := preload("res://ui/workshop/workshop.tscn")


func _ready() -> void:
	var workshop := WORKSHOP.instantiate()
	add_child(workshop)
	await get_tree().process_frame
	var content: CraftingContent = workshop.CONTENT
	var canvas: FocusCanvas = workshop._canvas
	# Optional: --details klappt die Gem-Liste im Ergebnis auf
	if OS.get_cmdline_user_args().has("--details"):
		workshop._on_result_meta_clicked("toggle_gems")
	# Optional: --scroll zeigt das Ende der linken Spalte (Speichern & Laden)
	if OS.get_cmdline_user_args().has("--scroll"):
		var scroll := workshop.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
		await get_tree().process_frame
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

	# Optional: --focus=<id> zeigt einen bestimmten Fokus-Typ mit einem Dreieck
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--focus="):
			var def: FocusDef = content.get_focus(StringName(arg.trim_prefix("--focus=")))
			workshop._on_focus_type_selected(content.foci.find(def))
			var standard := content.get_engraving(&"standard")
			var gems: Array[PlacedGem] = [
				PlacedGem.create(content.get_gem(&"hauptgem_mittel_grob"), content.get_engraving(&"feuerball"), Vector2(0, 120)),
				PlacedGem.create(content.get_gem(&"nebengem_mittel_grob"), standard, Vector2(-110, -40)),
				PlacedGem.create(content.get_gem(&"nebengem_mittel_spitz"), content.get_engraving(&"crit"), Vector2(110, -40)),
			]
			workshop.focus.gems = gems
			workshop.focus.loop = PackedInt32Array([0, 1, 2])
			workshop.focus.loop_closed = true
			# Optional: --all-elements füllt alle fünf Elemente (zum Ansehen der Essenz-Formen)
			if OS.get_cmdline_user_args().has("--all-elements"):
				workshop.focus.element_fill = {&"fire": 8, &"water": 8, &"earth": 8, &"air": 8, &"lightning": 8}
				workshop._sync_fill_ui()
			workshop._refresh()
			# Optional: --place zeigt die Vorschau eines vierten Gems
			if OS.get_cmdline_user_args().has("--place"):
				canvas.placing_gem = content.get_gem(&"nebengem_klein_spitz")
				canvas.placing_engraving = content.get_engraving(&"status_burn")
				canvas._mouse_inside = true
				canvas._mouse_focus = Vector2(150, 40)
				# --place-at=x,y setzt die Mausposition der Vorschau
				for place_arg in OS.get_cmdline_user_args():
					if place_arg.begins_with("--place-at="):
						var xy := place_arg.trim_prefix("--place-at=").split_floats(",")
						canvas._mouse_focus = Vector2(xy[0], xy[1])
				canvas.update_preview()
				canvas.queue_redraw()
			return

	workshop._on_example_pressed()
	# Optional: --tooltip zeigt einen festgepinnten Tooltip (Burn) und darin einen weiteren (Nass)
	if OS.get_cmdline_user_args().has("--tooltip"):
		var tips: TermTooltips = workshop.tooltips
		tips._open("fire", 0)
		tips._pin(tips._stack[0])
		tips._stack[0].panel.position = Vector2(1200, 300)
		tips._open("burn", 1)
		tips._stack[1].panel.position = Vector2(1150, 500)
		(tips._stack[1].bar as ProgressBar).value = 0.6
		# Hover auf Ebene 1 halten, damit beide offen bleiben
		tips._hover_term = "burn"
		tips._hover_level = 1
		tips._hover_time = 0.0
		tips.set_process(false)
		return
	# Optional: --hover zeigt, welche Punkte das Hauptgem einsammelt (Maus darüber)
	if OS.get_cmdline_user_args().has("--hover"):
		canvas.placing_gem = workshop.focus.gems[0].gem
		canvas.placing_engraving = workshop.focus.gems[0].engraving
		canvas._mouse_inside = true
		canvas._hovered = 0
		canvas._mouse_focus = workshop.focus.gems[0].position
		canvas.update_preview()
		canvas.queue_redraw()
		return
	# Optional: --replace zeigt die Vorschau beim Ändern eines gesetzten Gems
	if OS.get_cmdline_user_args().has("--replace"):
		canvas.placing_gem = content.get_gem(&"nebengem_klein_spitz")
		canvas.placing_engraving = content.get_engraving(&"crit")
		canvas._mouse_inside = true
		canvas._hovered = 1
		canvas._mouse_focus = workshop.focus.gems[1].position
		canvas.update_preview()
		canvas.queue_redraw()
		return
	# Beispiel ohne drittes Gem, damit die Vorschau den Kreis schließt
	workshop.focus.gems.remove_at(2)
	workshop.focus.loop = PackedInt32Array([0, 1])
	workshop.focus.loop_closed = false
	workshop._refresh()

	canvas.placing_gem = content.get_gem(&"nebengem_mittel_spitz")
	canvas.placing_engraving = content.get_engraving(&"standard")
	canvas._mouse_inside = true
	canvas._mouse_focus = Vector2(0, -140)
	canvas.update_preview()
	canvas.queue_redraw()
