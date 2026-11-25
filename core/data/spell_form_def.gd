class_name SpellFormDef
extends Resource
## Die Form eines Spells (Geschoss, Schild, ...). Sie wird von der Hauptrune vorgegeben,
## das Element ergibt sich aus den eingesammelten Punkten der Hauptrune.

@export var id: StringName
@export var display_name: String
## Grundwerte, z. B. {&"damage": 5.0}
@export var base_stats: Dictionary = {}
## Skalierung des Haupt-Spells. Gezählt werden die farbigen Punkte der Hauptrune
## und die Basispunkte ALLER Runen (Basis-Energie stärkt den Haupt-Spell).
@export var scaling_rules: Array[ScalingRule] = []
