class_name ElementDef
extends Resource
## Ein Element (Feuer, Wasser, ...).
## Die Logik arbeitet ausschließlich mit `id`. `color` dient nur der Darstellung
## und darf daher frei gestaltet werden. Was ein Element bewirkt, steht in den
## Regeln der Gravuren (ScalingRule mit Quelle ELEMENT).

@export var id: StringName
@export var display_name: String
@export var color: Color = Color.WHITE
## Symbol des Elements für Oberfläche und Tooltips (weiß, wird eingefärbt). Nur Darstellung.
@export var icon: Texture2D
## Bild der Essenz-Punkte (weiß, wird mit `color` eingefärbt). Nur Darstellung.
@export var dot_texture: Texture2D
## Eine Essenz dieses Elements zählt für Gravuren so viel wie `factor` neutrale Essenz.
@export var factor: float = 5.0
