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

	# Optional: --focus=<id> zeigt einen bestimmten Fokus-Typ mit einem Dreieck
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--focus="):
			var def: FocusDef = content.get_focus(StringName(arg.trim_prefix("--focus=")))
			workshop._on_focus_type_selected(content.foci.find(def))
			var standard := content.get_engraving(&"standard")
			var gems: Array[PlacedGem] = [
				PlacedGem.create(content.get_gem(&"hauptgem_grob"), content.get_engraving(&"feuerball"), Vector2(0, 120)),
				PlacedGem.create(content.get_gem(&"nebengem_mittel_grob"), standard, Vector2(-110, -40)),
				PlacedGem.create(content.get_gem(&"nebengem_mittel_spitz"), content.get_engraving(&"crit"), Vector2(110, -40)),
			]
			workshop.focus.gems = gems
			workshop.focus.loop = PackedInt32Array([0, 1, 2])
			workshop.focus.loop_closed = true
			workshop._refresh()
			# Optional: --place zeigt die Vorschau eines vierten Gems
			if OS.get_cmdline_user_args().has("--place"):
				canvas.placing_gem = content.get_gem(&"nebengem_klein_spitz")
				canvas.placing_engraving = content.get_engraving(&"status")
				canvas._mouse_inside = true
				canvas._mouse_focus = Vector2(150, 40)
				canvas.update_preview()
				canvas.queue_redraw()
			return

	workshop._on_example_pressed()
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
