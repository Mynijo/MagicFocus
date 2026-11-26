class_name DotField
extends RefCounted
## Erzeugt die Energiepunkte eines Fokus reproduzierbar aus Seed und Füllung.
## Die Punkte werden zufällig über die Fläche der Fokus-Form verteilt:
##   - mit etwas Abstand zum Rand (EDGE_MARGIN), damit sie nicht auf dem Umriss liegen,
##   - ohne Überlappung: jeder Punkt hat einen Platzradius (Essenz größer als neutrale
##     Essenz, passend zur Darstellung); Essenzen werden zuerst verteilt.
## Findet ein Punkt nach ATTEMPTS Versuchen keinen freien Platz (sehr voller Fokus),
## wird er trotzdem gesetzt.

const EDGE_MARGIN := 12.0
## Platzradius (Fokus-Einheiten, passend zur hervorgehobenen Punktgröße in FocusCanvas):
## zwei Punkte liegen mindestens die Summe auseinander.
const BASE_SPACING := 3.0
const ELEMENT_SPACING := 7.5
const ATTEMPTS := 100
const CELL := ELEMENT_SPACING * 2.0  # Rasterweite für die Nachbarsuche
## Höchstens so viel der Fläche belegen die Platzkreise; sonst werden alle Abstände kleiner.
const MAX_COVERAGE := 0.4


static func generate(focus: FocusInstance) -> Array[EnergyDot]:
	var dots: Array[EnergyDot] = []
	if focus.focus_def == null or focus.focus_def.shape == null:
		return dots

	var rng := RandomNumberGenerator.new()
	rng.seed = focus.dot_seed
	var shape := focus.focus_def.shape
	var grid := {}  # Rasterzelle (Vector2i) -> Array[EnergyDot]
	var factor := spacing_factor(focus)

	# Essenzen zuerst (sie brauchen mehr Platz), feste Reihenfolge der Elemente:
	# gleiche Füllung ergibt gleiche Punkte.
	var element_ids := focus.element_fill.keys()
	element_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for element_id: StringName in element_ids:
		for i in int(focus.element_fill[element_id]):
			_place(EnergyDot.new(Vector2.ZERO, element_id), shape, rng, grid, dots, factor)
	for i in focus.get_base_count():
		_place(EnergyDot.new(), shape, rng, grid, dots, factor)
	return dots


static func spacing(dot: EnergyDot) -> float:
	return BASE_SPACING if dot.is_base() else ELEMENT_SPACING


## Faktor auf alle Abstände (1 = volle Abstände), damit ein voller Fokus nicht überläuft.
static func spacing_factor(focus: FocusInstance) -> float:
	var needed := focus.get_base_count() * PI * BASE_SPACING * BASE_SPACING
	needed += focus.get_element_total() * PI * ELEMENT_SPACING * ELEMENT_SPACING
	var area := absf(FocusGeometry.signed_area(focus.focus_def.shape.get_outline()))
	if needed <= 0.0:
		return 1.0
	return minf(1.0, sqrt(MAX_COVERAGE * area / needed))


## Sucht einen freien Platz für `dot` und trägt ihn ein.
static func _place(dot: EnergyDot, shape: FocusShape, rng: RandomNumberGenerator,
		grid: Dictionary, dots: Array[EnergyDot], factor: float) -> void:
	for attempt in ATTEMPTS:
		dot.position = shape.random_point_inset(rng, EDGE_MARGIN)
		if _is_free(dot, grid, factor):
			break
	var cell := Vector2i((dot.position / CELL).floor())
	if not grid.has(cell):
		grid[cell] = []
	grid[cell].append(dot)
	dots.append(dot)


static func _is_free(dot: EnergyDot, grid: Dictionary, factor: float) -> bool:
	var cell := Vector2i((dot.position / CELL).floor())
	for x in range(cell.x - 1, cell.x + 2):
		for y in range(cell.y - 1, cell.y + 2):
			for other: EnergyDot in grid.get(Vector2i(x, y), []):
				if dot.position.distance_to(other.position) < (spacing(dot) + spacing(other)) * factor:
					return false
	return true
