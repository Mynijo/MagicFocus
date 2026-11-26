class_name GemDef
extends Resource
## Eine Gem-Form aus der Bibliothek: Radius und Winkel.
## Was das Gem bewirkt, legt die Gravur fest (EngravingDef).
##
## Multiplikator: Spitze Gems zählen jede eingesammelte Essenz doppelt
## (Ausgleich für den kleineren Innenwinkel), grobe Gems einfach.

enum Role { MAIN, MINOR }
## Spitz sammelt im Innenwinkel der Ecke, Grob im Außenwinkel.
enum Angle { SPITZ, GROB }
enum Size { KLEIN, MITTEL, GROSS }

const SIZE_NAMES := ["klein", "mittel", "groß"]

const SPITZ_MULTIPLIER := 2.0

@export var id: StringName
@export var display_name: String
@export var role: Role = Role.MINOR
@export var size: Size = Size.MITTEL
@export var radius: float = 80.0
@export var angle: Angle = Angle.GROB
## Maximal einsammelbare neutrale Essenzen (N-E).
@export var max_base: int = 15
## Maximal einsammelbare Element-Essenzen (E).
@export var max_element: int = 15
## Größe des Steins (halber Durchmesser, Fokus-Einheiten). Essenz darunter ist verdeckt
## und zählt für kein Gem. 0 = kein Stein (Tests).
@export var body_radius := 0.0


func is_inner() -> bool:
	return angle == Angle.SPITZ


func get_multiplier() -> float:
	return SPITZ_MULTIPLIER if angle == Angle.SPITZ else 1.0


func get_angle_name() -> String:
	return "Spitz" if angle == Angle.SPITZ else "Grob"
