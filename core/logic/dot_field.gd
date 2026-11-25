class_name DotField
extends RefCounted
## Erzeugt die Energiepunkte eines Fokus reproduzierbar aus Seed und Füllung.
## Die Punkte werden zufällig über die gesamte Fläche der Fokus-Form verteilt.


static func generate(focus: FocusInstance) -> Array[EnergyDot]:
	var dots: Array[EnergyDot] = []
	if focus.focus_def == null or focus.focus_def.shape == null:
		return dots

	var rng := RandomNumberGenerator.new()
	rng.seed = focus.dot_seed
	var shape := focus.focus_def.shape

	# Basispunkte zuerst: Ihre Lage hängt dann nicht von der Element-Füllung ab.
	for i in focus.base_count:
		dots.append(EnergyDot.new(shape.random_point(rng)))

	# Feste Reihenfolge der Elemente -> gleiche Füllung ergibt gleiche Punkte.
	var element_ids := focus.element_fill.keys()
	element_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for element_id: StringName in element_ids:
		for i in int(focus.element_fill[element_id]):
			dots.append(EnergyDot.new(shape.random_point(rng), element_id))

	return dots
