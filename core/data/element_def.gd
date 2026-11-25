class_name ElementDef
extends Resource
## Ein Element (Feuer, Wasser, ...).
## Die Logik arbeitet ausschließlich mit `id`. `color` dient nur der Darstellung
## und darf daher frei gestaltet werden.

@export var id: StringName
@export var display_name: String
@export var color: Color = Color.WHITE
## Regeln, die greifen, wenn eine kleine Rune dieses Element annimmt
## (z. B. Feuer: pro 5 Feuerpunkte +1 Burning).
@export var minor_rules: Array[ScalingRule] = []
