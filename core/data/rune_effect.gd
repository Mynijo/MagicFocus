class_name RuneEffect
extends Resource
## Basisklasse für Spezial-Effekte von Runen (z. B. Übertragungsrune, Eis-Rune).
## Wird in Phase 4 der Auswertung aufgerufen, nach dem Einsammeln und vor der
## Bestimmung der Runen-Elemente. In M1 gibt es noch keine Implementierungen.


func apply(_rune: RuneResult, _result: SpellResult) -> void:
	pass
