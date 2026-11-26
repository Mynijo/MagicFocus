class_name CombatRules
extends Resource
## Zahlen für den Kampf. Alle Werte sind Platzhalter fürs Balancing (M5);
## die "X" aus den Kampfregeln stehen hier. Inhalt: content/combat_rules.tres.

@export_group("Magier")
@export var max_hp := 600.0
@export var max_mana := 200.0
## Mana zu Kampfbeginn
@export var start_mana := 200.0
## Mana pro Sekunde ohne Status
@export var mana_regen := 25.0

@export_group("Ablauf")
## Zeitschritt der Simulation in Sekunden
@export var tick := 0.1
## Danach endet der Kampf unentschieden
@export var max_duration := 300.0

@export_group("Status")
## Schaden-Faktor eines Crits (200 %)
@export var crit_multiplier := 2.0
## Bleed: Schaden pro Stack und Sekunde
@export var bleed_damage := 2.0
## Burn: Schaden pro Stack und Sekunde
@export var burn_damage := 2.0
## Slowed: zusätzliche Cast-Zeit pro Stack (Sekunden)
@export var slowed_seconds := 0.1
## Hasted: kürzere Cast-Zeit pro Stack (Sekunden)
@export var hasted_seconds := 0.1
## Höchstzahl Stacks für Slowed und Hasted
@export var max_slowed_hasted := 10
## Mana Burn: weniger Mana-Reg pro Stack und Sekunde
@export var mana_burn_per_stack := 1.0
## Nass: zusätzlicher Schock-Schaden pro Nass-Stack
@export var wet_shock_bonus := 1.0
## Armor Break: so viel Armor hebt ein Stack auf
@export var armor_break_ratio := 5.0
## Perma-Burn: Burn pro Stack und Sekunde (baut sich nicht ab, nur Cleanse)
@export var perma_burn_rate := 1.0
## Bless: zusätzliche Heilung pro Stack bei jeder erhaltenen Heilung (1 Stack verbraucht)
@export var bless_heal := 5.0
## Thorns: Gegenschaden pro Stack bei jedem erhaltenen Spell-Treffer (1 Stack verbraucht)
@export var thorns_damage := 3.0
## Mana Absorption: Mana pro Stack bei jedem erhaltenen Spell-Treffer (1 Stack verbraucht)
@export var mana_absorption_mana := 5.0
## Damage Reduction: Faktor auf den Schaden des nächsten Spells (vom Nutzer vorgegeben: 50 %)
@export var damage_reduction_factor := 0.5
## Life Rewind: nach so vielen Sekunden wird das Leben zurückgesetzt
@export var life_rewind_seconds := 10.0
