class_name TextFormat
extends RefCounted
## Zahlen für deutsche Texte: ganze Zahlen ohne Komma, sonst höchstens `decimals`
## Nachkommastellen mit Dezimalkomma (0,5).


static func number(value: float, decimals := 2) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return String.num(value, decimals).replace(".", ",")
