class_name ScalingRule
extends Resource
## Allgemeine Skalierungsregel:
## "Pro `per_n` Essenzen aus `source` -> +`amount` auf den Wert `stat`".
## Beispiele: "+2 Schaden pro E", "1 Slow pro 10 Luft-E".
## Gezählt werden effektive Essenzen (nach Multiplikator), daher float.

enum Source {
	BASE,         ## neutrale Essenzen (N-E)
	ELEMENT,      ## Essenzen eines bestimmten Elements (`element_id`)
	ANY_ELEMENT,  ## alle Element-Essenzen zusammen (E)
}

@export var source: Source = Source.BASE
@export var element_id: StringName
@export var per_n: int = 1
@export var stat: StringName
@export var amount: float = 1.0
## Unterhalb dieser Anzahl greift die Regel gar nicht.
@export var min_count: int = 0


func count_from(base_count: float, element_counts: Dictionary) -> float:
	match source:
		Source.BASE:
			return base_count
		Source.ELEMENT:
			return float(element_counts.get(element_id, 0.0))
		Source.ANY_ELEMENT:
			var total := 0.0
			for count in element_counts.values():
				total += float(count)
			return total
	return 0.0


func evaluate(base_count: float, element_counts: Dictionary) -> float:
	var count := count_from(base_count, element_counts)
	if count < min_count or per_n <= 0:
		return 0.0
	# kleine Toleranz, damit z. B. 4.9999 effektive Essenzen nicht abgerundet werden
	return floorf(count / float(per_n) + 0.0001) * amount
