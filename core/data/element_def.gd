class_name ElementDef
extends Resource
## Ein Element (Feuer, Wasser, ...).
## Die Logik arbeitet ausschließlich mit `id`. `color` dient nur der Darstellung
## und darf daher frei gestaltet werden. Was ein Element bewirkt, steht in den
## Regeln der Gravuren (ScalingRule mit Quelle ELEMENT).

@export var id: StringName
@export var display_name: String
@export var color: Color = Color.WHITE
