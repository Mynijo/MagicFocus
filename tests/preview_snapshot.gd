extends Node
## Visueller Test: öffnet die Werkstatt mit Beispiel-Fokus und simuliert eine
## Nebengem unter dem Mauszeiger, um die Setz-Vorschau zu rendern.
## Rendern:  godot --path <projekt> res://tests/preview_snapshot.tscn --write-movie out.png --quit-after 5

const WORKSHOP := preload("res://ui/workshop/workshop.tscn")


func _ready() -> void:
	var workshop := WORKSHOP.instantiate()
	add_child(workshop)
	await get_tree().process_frame

	# Optional: --focus=<id> zeigt einen bestimmten Fokus-Typ mit einem Dreieck
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--focus="):
			var def: FocusDef = workshop.CONTENT.get_focus(StringName(arg.trim_prefix("--focus=")))
			workshop._on_focus_type_selected(workshop.CONTENT.foci.find(def))
			var gems: Array[PlacedGem] = [
				PlacedGem.create(workshop.CONTENT.get_gem(&"hauptgem_geschoss"), Vector2(0, 120)),
				PlacedGem.create(workshop.CONTENT.get_gem(&"nebengem_standard"), Vector2(-110, -40)),
				PlacedGem.create(workshop.CONTENT.get_gem(&"nebengem_innen"), Vector2(110, -40)),
			]
			workshop.focus.gems = gems
			workshop.focus.loop = PackedInt32Array([0, 1, 2])
			workshop.focus.loop_closed = true
			workshop._refresh()
			# Optional: --place zeigt die Vorschau einer vierten Gem
			if OS.get_cmdline_user_args().has("--place"):
				var canvas: FocusCanvas = workshop._canvas
				canvas.placing_gem = workshop.CONTENT.get_gem(&"nebengem_status")
				canvas._mouse_inside = true
				canvas._mouse_focus = Vector2(180, 60)
				canvas.update_preview()
				canvas.queue_redraw()
			return

	workshop._on_example_pressed()
	# Beispiel ohne dritte Gem, damit die Vorschau den Kreis schließt
	workshop.focus.gems.remove_at(2)
	workshop.focus.loop = PackedInt32Array([0, 1])
	workshop.focus.loop_closed = false
	workshop._refresh()

	var canvas: FocusCanvas = workshop._canvas
	canvas.placing_gem = workshop.CONTENT.get_gem(&"nebengem_standard")
	canvas._mouse_inside = true
	canvas._mouse_focus = Vector2(0, -140)
	canvas.update_preview()
	canvas.queue_redraw()
