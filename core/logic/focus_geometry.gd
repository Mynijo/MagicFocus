class_name FocusGeometry
extends RefCounted
## Reine Geometrie-Funktionen für Gem-Kreise. Ersetzt die bisherige
## Berechnung über RayCast2D, Area2D und CollisionPolygon2D.


## Vorzeichenbehaftete Fläche (Shoelace). Das Vorzeichen gibt die Umlaufrichtung an.
static func signed_area(points: PackedVector2Array) -> float:
	var area := 0.0
	var n := points.size()
	for i in n:
		var a := points[i]
		var b := points[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	return area * 0.5


static func perimeter(points: PackedVector2Array) -> float:
	var length := 0.0
	var n := points.size()
	for i in n:
		length += points[i].distance_to(points[(i + 1) % n])
	return length


## true, wenn sich zwei nicht benachbarte Kanten des geschlossenen Kreises schneiden.
static func has_crossing(points: PackedVector2Array) -> bool:
	var n := points.size()
	for i in n:
		var a1 := points[i]
		var a2 := points[(i + 1) % n]
		for j in range(i + 1, n):
			# Benachbarte Kanten teilen sich einen Endpunkt -> nicht prüfen.
			if j == i + 1 or (i == 0 and j == n - 1):
				continue
			var b1 := points[j]
			var b2 := points[(j + 1) % n]
			if Geometry2D.segment_intersects_segment(a1, a2, b1, b2) != null:
				return true
	return false


## Einflussbereich eines Gems als Vector2(startwinkel, öffnungswinkel).
## `inner` = Innenwinkel (Spitz), sonst Außenwinkel (Grob).
## `ccw` = Umlaufrichtung des Kreises (signed_area > 0). "Innen" ist immer die
## Seite zum Inneren des Polygons, auch bei konkaven Formen.
static func sector_for(prev: Vector2, current: Vector2, next: Vector2,
		inner: bool, ccw: bool) -> Vector2:
	var to_prev := (prev - current).angle()
	var to_next := (next - current).angle()
	var inner_start: float
	var inner_sweep: float
	if ccw:
		inner_start = to_next
		inner_sweep = wrapf(to_prev - to_next, 0.0, TAU)
	else:
		inner_start = to_prev
		inner_sweep = wrapf(to_next - to_prev, 0.0, TAU)

	if inner:
		return Vector2(inner_start, inner_sweep)
	return Vector2(inner_start + inner_sweep, TAU - inner_sweep)


static func in_sector(point: Vector2, center: Vector2, radius: float,
		start: float, sweep: float) -> bool:
	var offset := point - center
	if offset.length() > radius:
		return false
	if sweep >= TAU - 0.0001 or offset.is_zero_approx():
		return true
	return wrapf(offset.angle() - start, 0.0, TAU) <= sweep


## Punkte eines Kreissektors als Polygon (zum Zeichnen).
static func sector_polygon(center: Vector2, radius: float, start: float,
		sweep: float, steps: int = 32) -> PackedVector2Array:
	var points := PackedVector2Array()
	var full := sweep >= TAU - 0.0001
	if not full:
		points.append(center)
	for i in steps + 1:
		if full and i == steps:
			break
		points.append(center + Vector2.from_angle(start + sweep * i / steps) * radius)
	return points
