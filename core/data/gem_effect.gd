class_name GemEffect
extends Resource
## Basisklasse für Spezial-Effekte von Gems (z. B. Übertragungsgem, Eis-Gem).
## Wird in Phase 4 der Auswertung aufgerufen, nach dem Einsammeln und vor der
## Bestimmung der Gem-Elemente. In M1 gibt es noch keine Implementierungen.


func apply(_gem: GemResult, _result: SpellResult) -> void:
	pass
