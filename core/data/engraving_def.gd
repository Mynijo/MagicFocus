class_name EngravingDef
extends Resource
## Gravur eines Gems: legt fest, was das Gem bewirkt. Hauptgravuren bestimmen den Spell,
## Nebengravuren verbessern ihn. Gravuren sind reine Daten (erzeugt von
## tools/generate_content.gd); Sonderfälle laufen über `effects`.

## Wen der Spell trifft (nur Hauptgravur). Alle Werte des Spells gehen auf dieses Ziel.
enum Target { ENEMY, SELF, BOTH }

@export var id: StringName
@export var display_name: String
@export var role: GemDef.Role = GemDef.Role.MINOR
## Kurze Notiz zu Besonderheiten, die nicht aus den Werten hervorgehen. Die vollständige
## Beschreibung erzeugt `ContentText.describe()` aus den Werten.
@export_multiline var note: String
## Symbol auf dem Gem (weiß, wird eingefärbt). Ohne Symbol zeigt die Werkstatt die
## Punktform des Elements (bei genau einem Element).
@export var icon: Texture2D
## Elemente der Gravur mit ihrem Faktor: 1 Essenz zählt so viele Punkte (Element-ID -> Faktor).
## Andere Essenz zählt gar nicht; leer = nur neutrale Essenz zählt.
@export var element_factors: Dictionary = {}
@export var target: Target = Target.ENEMY

@export_group("Werte")
## Feste Werte des Spells, z. B. {&"freeze_conversion": 100.0}.
@export var base_stats: Dictionary = {}
## Skalierung mit den Punkten des Gems (beim Hauptgem inklusive Übertragenem).
@export var rules: Array[ScalingRule] = []
## Spezial-Effekte (Phase 6, nach den Regeln).
@export var effects: Array[GemEffect] = []

@export_group("Einsammeln")
## Gibt das Eingesammelte an das Hauptgem weiter (Power Transfer, Multiplikator).
@export var transfer_to_main := false
## Faktor auf den Radius des Gems (Power Transfer 0,5, Multiplikator 0,8).
@export var radius_factor := 1.0
## Innerer Ring (Multiplikator): vom Stein bis `inner_radius_factor` × Radius darüber
## hinaus zählt Essenz zusätzlich × `inner_multiplier` (0 = kein Ring).
@export var inner_radius_factor := 0.0
@export var inner_multiplier := 2.0
## Größte erlaubte Gem-Größe (Multiplikator: nur klein und mittel).
@export var max_size: GemDef.Size = GemDef.Size.GROSS


func counts_element(element_id: StringName) -> bool:
	return element_factors.has(element_id)


## Faktor für Essenz dieses Elements (0 = zählt nicht).
func factor_of(element_id: StringName) -> float:
	return float(element_factors.get(element_id, 0.0))


func get_element_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(element_factors.keys())
	return ids
