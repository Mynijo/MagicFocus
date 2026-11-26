class_name EngravingDef
extends Resource
## Gravur eines Gems. Sie legt fest, was das Gem bewirkt.
## Hauptgravuren bestimmen den Spell, Nebengravuren verbessern ihn.
## Neue Gravuren sind reine Daten (.tres); Sonderfälle laufen über `effects`.

@export var id: StringName
@export var display_name: String
@export var role: GemDef.Role = GemDef.Role.MINOR
## Elemente der Gravur: nur Essenz dieser Elemente zählt (× Faktor des Elements),
## andere Essenz zählt gar nicht. Leer = die Gravur zählt nur neutrale Essenz.
## Magischer Bolzen hat alle Elemente.
@export var element_ids: Array[StringName] = []


func counts_element(element_id: StringName) -> bool:
	return element_ids.has(element_id)
## Symbol auf dem Gem (weiße Linienzeichnung, wird eingefärbt). Nur Darstellung;
## ohne Symbol zeigt die Werkstatt die Form des Elements (bei genau einem Element).
@export var icon: Texture2D
## Kurze Regelbeschreibung für die Oberfläche.
@export_multiline var description: String
## Feste Werte des Spells, z. B. {&"freeze_conversion": 100.0}.
@export var base_stats: Dictionary = {}
## Skalierung mit den effektiven Essenzen des Gems
## (beim Hauptgem: inklusive der übertragenen Essenzen). Essenz ist dabei
## schon mit dem Element-Faktor gewichtet und nach `element_id` gefiltert.
@export var rules: Array[ScalingRule] = []
## Gibt die effektiven Essenzen an das Hauptgem weiter (Power Transfer, ID "standard").
@export var transfer_to_main := false
## Faktor auf den Radius des Gems (Power Transfer: 0,5).
@export var radius_factor := 1.0
## Nur Hauptgravur: Wen der Spell trifft. Alle Werte des Spells, auch die der
## Nebengravuren, gehen auf dieses Ziel.
enum Target { ENEMY, SELF, BOTH }
@export var target: Target = Target.ENEMY
## Spezial-Effekte (Phase 6, nach den Regeln).
@export var effects: Array[GemEffect] = []
