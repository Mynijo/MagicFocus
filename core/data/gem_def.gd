class_name GemDef
extends Resource
## Eine Gem aus der Gem-Bibliothek.

enum Role { MAIN, MINOR }
## Welcher Teil des Einflusskreises zählt: Innenwinkel, Außenwinkel oder beides.
enum Area { INNER, OUTER, BOTH }

@export var id: StringName
@export var display_name: String
@export var role: Role = Role.MINOR
@export var radius: float = 80.0
@export var area: Area = Area.OUTER
## Maximal einsammelbare Basis-Energiepunkte.
@export var max_base: int = 15
## Maximal einsammelbare farbige Energiepunkte.
@export var max_element: int = 15
## Multipliziert alle Beiträge diesem Gem.
@export var strength: float = 1.0
## Nur für Hauptgems: welche Spell-Form sie erzeugt.
@export var spell_form: SpellFormDef
## Zusätzliche Regeln diesem Gem, unabhängig von ihrem Element.
@export var extra_rules: Array[ScalingRule] = []
## Nur Nebengems: Wendet die Regeln des angenommenen Elements an (ElementDef.minor_rules).
## Aus bei Gems, die Elemente über `extra_rules` selbst auswerten (z. B. Statuseffekt-Gem).
@export var use_element_rules := true
## Spezial-Effekte (noch ungenutzt).
@export var effects: Array[GemEffect] = []
