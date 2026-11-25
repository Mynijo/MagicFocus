class_name ScalingRule
extends Resource
## Allgemeine Skalierungsregel:
## "Pro `per_n` Punkte aus `source` -> +`amount` auf den Wert `stat`".
## Deckt z. B. "pro 5 Feuerpunkte +1 Burning" oder "pro farbigem Punkt +1 Resistenz" ab.

enum Source {
	BASE,         ## Basis-Energiepunkte
	ELEMENT,      ## Punkte eines bestimmten Elements (`element_id`)
	ANY_ELEMENT,  ## alle farbigen Punkte zusammen
	RUNE_ELEMENT, ## Punkte des Elements, das die Rune angenommen hat
}

@export var source: Source = Source.BASE
@export var element_id: StringName
@export var per_n: int = 1
@export var stat: StringName
@export var amount: float = 1.0
## Unterhalb dieser Anzahl greift die Regel gar nicht.
@export var min_count: int = 0


func count_from(base_count: int, element_counts: Dictionary, rune_element: StringName) -> int:
	match source:
		Source.BASE:
			return base_count
		Source.ELEMENT:
			return element_counts.get(element_id, 0)
		Source.ANY_ELEMENT:
			var total := 0
			for count: int in element_counts.values():
				total += count
			return total
		Source.RUNE_ELEMENT:
			if rune_element == &"":
				return 0
			return element_counts.get(rune_element, 0)
	return 0


func evaluate(base_count: int, element_counts: Dictionary, rune_element: StringName) -> float:
	var count := count_from(base_count, element_counts, rune_element)
	if count < min_count or per_n <= 0:
		return 0.0
	return floori(count / float(per_n)) * amount
