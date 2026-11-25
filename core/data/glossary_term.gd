class_name GlossaryTerm
extends Resource
## Ein erklärbarer Begriff (Element, Status) für die Tooltips der Oberfläche.

@export var id: StringName
@export var title: String
## Wörter, die im Text auf diesen Begriff verweisen (z. B. "Slow" und "Slowed").
@export var words: PackedStringArray = []
## Symbol im Tooltip-Titel (weiß, wird mit `icon_color` eingefärbt), optional.
@export var icon: Texture2D
@export var icon_color: Color = Color.WHITE
## Erklärung; darf selbst wieder Begriffe enthalten (verschachtelte Tooltips).
@export_multiline var text: String
