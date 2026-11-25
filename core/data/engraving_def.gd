class_name EngravingDef
extends Resource
## Gravur eines Gems. Sie legt fest, was das Gem bewirkt.
## Hauptgravuren bestimmen den Spell, Nebengravuren verbessern ihn.
## Neue Gravuren sind reine Daten (.tres); Sonderfälle laufen über `effects`.

@export var id: StringName
@export var display_name: String
@export var role: GemDef.Role = GemDef.Role.MINOR
## Kurze Regelbeschreibung für die Oberfläche.
@export_multiline var description: String
## Feste Werte des Spells, z. B. {&"freeze_conversion": 100.0}.
@export var base_stats: Dictionary = {}
## Skalierung mit den effektiven Essenzen des Gems
## (beim Hauptgem: inklusive der übertragenen Essenzen).
@export var rules: Array[ScalingRule] = []
## Gibt die effektiven Essenzen an das Hauptgem weiter (Standard-Gravur).
@export var transfer_to_main := false
## Spezial-Effekte (Phase 6, nach den Regeln).
@export var effects: Array[GemEffect] = []
