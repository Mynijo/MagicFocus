class_name ScalingRule
extends Resource
## Allgemeine Skalierungsregel:
## "Pro `per_n` Punkte aus `source` -> +`amount` auf den Wert `stat`".
## Beispiele: "+1 Schaden pro Punkt", "1 Burn pro 10 Feuer-Punkte".
## Gezählt werden effektive Essenzen (nach Multiplikator); Element-Essenz ist
## bereits mit dem Element-Faktor gewichtet (1 Feuer-Essenz = 5 Punkte), daher float.

enum Source {
	BASE,         ## nur neutrale Essenz
	ELEMENT,      ## nur Essenz eines bestimmten Elements (`element_id`)
	ANY_ELEMENT,  ## nur Element-Essenz, alle Elemente zusammen
	POINTS,       ## neutrale Essenz + Element-Essenz (die übliche Quelle)
}

@export var source: Source = Source.BASE
@export var element_id: StringName
@export var per_n: int = 1
@export var stat: StringName
@export var amount: float = 1.0
## Unterhalb dieser Anzahl greift die Regel gar nicht.
@export var min_count: int = 0
## Höchstwert des Ergebnisses (0 = keine Grenze), z. B. Mana Efficiency: Luft hebt die
## Cast-Zeit-Erhöhung höchstens ganz auf.
@export var cap := 0.0


func count_from(base_count: float, element_counts: Dictionary) -> float:
	match source:
		Source.BASE:
			return base_count
		Source.ELEMENT:
			return float(element_counts.get(element_id, 0.0))
		Source.ANY_ELEMENT, Source.POINTS:
			var total := base_count if source == Source.POINTS else 0.0
			for count in element_counts.values():
				total += float(count)
			return total
	return 0.0


func evaluate(base_count: float, element_counts: Dictionary) -> float:
	var count := count_from(base_count, element_counts)
	if count < min_count or per_n <= 0:
		return 0.0
	# kleine Toleranz, damit z. B. 4.9999 effektive Essenzen nicht abgerundet werden
	var value := floorf(count / float(per_n) + 0.0001) * amount
	return minf(value, cap) if cap > 0.0 else value
