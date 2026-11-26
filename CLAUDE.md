# MagicFocus

Spell-Crafting-Spiel in **Godot 4.7 / GDScript**. Der Spieler baut **Foki** (Arbeitsflächen),
befüllt sie mit Essenzen, setzt **Gems** (Form + Gravur) und verbindet sie zu einem
geschlossenen Kreis. Daraus entsteht ein Spell. Später kommt ein **1-gegen-1-Magier-Auto-Battler**
dazu. Er ist **noch nicht** implementiert, Architekturentscheidungen sollen ihn aber nicht verbauen.

Kommunikation mit dem Nutzer auf **Deutsch**.

## Struktur

| Ordner | Inhalt |
|---|---|
| `core/data/` | Ressourcen-Klassen: `FocusStore` (gespeicherte Foki als JSON), `GlossaryTerm`, `ElementDef`, `GemDef` (Form), `EngravingDef` (Gravur), `ScalingRule`, `FocusDef`, `FocusShape` (+ `CircleFocusShape`, `PolygonFocusShape` → `StarFocusShape`, `DropFocusShape`), `FocusInstance`, `PlacedGem`, `GemEffect`, `CraftingContent` |
| `core/logic/` | Reine Logik ohne Physik/Szenen: `SpellEvaluator` (Auswertung in 6 Phasen), `FocusGeometry`, `DotField` (Punkte aus Seed), `SpellResult`, `GemResult`, `EnergyDot` |
| `core/combat/` | Kampf (M6), reine Logik: `Combat` (Ablauf, Status, Log), `CombatMage` (Zustand, `from_foci`), `CombatRules` (Zahlen, Inhalt in `content/combat_rules.tres`) |
| `content/` | Inhalte als `.tres`: `elements/`, `gems/`, `engravings/`, `foci/`. `crafting_content.tres` listet alles (Reihenfolge = Reihenfolge in der UI) |
| `tools/` | `generate_content.gd`: erzeugt Gems, Gravuren und `crafting_content.tres` aus Tabellen. **Werte dort ändern und neu erzeugen**, nicht die `.tres` von Hand. `prepare_assets.gd`: schneidet und verkleinert generierte Bilder nach `assets/sprites/` (Gravur-Symbole: alle PNGs aus `assets/engravings/<gravur-id>.png`, danach Generator neu laufen lassen) |
| `assets/` | Bilder (vom Nutzer mit ChatGPT erzeugt): Originale in `gems/`, `essences/`, `textures/`, `engravings/<gravur-id>.png`, `elements/element_<id>.png`; Spiel nutzt `sprites/` (aufbereitet, Mipmaps an). Jedes Element hat eine eigene Punktform (`ElementDef.dot_texture`, im Generator gesetzt), neutrale Essenz ist eine Kugel. Gravuren zeigen auf dem Gem ihr Symbol (`EngravingDef.icon`); ohne Symbol die Form ihres Elements (nur bei genau einem Element). Elemente haben ein Symbol (`ElementDef.icon`) für Befüllen-Liste und Tooltips; Status-Tooltips nutzen das Symbol der erzeugenden Gravur (`STATUS_ICONS` im Generator). Neue Bilder kommen in `input/` und werden von Claude einsortiert |
| `ui/arena/` | Arena: zwei Magier aus gespeicherten Foki (bis zu 5 Spells), Balken, Status-Symbole, Log, Tempo 1×/2×/4× |
| `ui/common/` | `term_tooltips.gd`: verschachtelte Tooltips für Begriffe (Elemente, Status) in RichTextLabels: `linkify()` + `register()` |
| `ui/workshop/` | Fokus-Werkstatt (Hauptszene): `workshop.gd` (Panels, im Code aufgebaut), `focus_canvas.gd` (Zeichnen und Mausbedienung) |
| `tests/` | `run_tests.gd` (headless Testsuite), `preview_snapshot.tscn` (Render-Check der Werkstatt), `arena_snapshot.tscn` (Render-Check der Arena) |
| `FocusCraft/`, `FocusLexicon/` | **Altcode** (Prototyp 2023/24, physikbasiert). Nicht weiterentwickeln, nur Referenz |

## Architekturregeln

- Die Logik in `core/logic/` bleibt frei von Physik, Nodes und Rendering, damit sie headless läuft (Werkstatt-Vorschau, später die Kampfsimulation).
- Elemente werden über ihre **ID** identifiziert, nie über ihre Farbe. Die Farbe dient nur der Darstellung.
- Werte, Kapazitäten und Regeln gehören in Inhalte bzw. `ScalingRule`s, nicht in Code. Neue Gravuren brauchen möglichst keinen neuen Code; Sonderfälle sind eine Unterklasse von `GemEffect`.
- Neue Fokusformen sind eine Unterklasse von `PolygonFocusShape` (nur `_build_polygon()`).
- Begriffe in der Oberfläche: **neutrale Essenz** (Code: `base`) und **Essenz** (Code: `element`). **Keine Abkürzungen in der UI** (kein „N-E“, keine Gravur-Kürzel). „Gem“ ist in UI-Texten Neutrum („das Gem“). In der UI deutsch, im Code englische Bezeichner. In diesem Dokument stehen N-E / E nur als Kurzform.
- Alle Zahlenwerte in `content/` sind Platzhalter fürs Balancing.

## Implementierte Spielregeln

- Ein Spell braucht genau **1 Hauptgem** und mindestens **3 Gems** in einem **geschlossenen Kreis**, der beim Hauptgem beginnt. Kanten dürfen sich nicht kreuzen und müssen **innerhalb der Fokusform** verlaufen.
- **Gem = Form + Gravur.** Die Form (`GemDef`) legt Radius, Winkel und Kapazität fest, die Gravur (`EngravingDef`) die Wirkung. Die Rolle (Haupt/Neben) muss übereinstimmen. In der Werkstatt wählt man **Gravur, Größe (klein/mittel/groß) und Spitz ja/nein**; ein **Klick auf ein gesetztes Gem** übernimmt diese Auswahl (gleiche Rolle nötig, Position und Kreis bleiben, Vorschau beim Darüberfahren); die Gravur legt die Rolle fest, die Form ergibt sich über `CraftingContent.find_gem()`. Es gibt 12 Formen (2 Rollen × 3 Größen × Spitz/Grob), erzeugt aus `GEM_SIZES` im Generator.
- **Abstand:** Kein Gem darf in der Reichweite eines anderen liegen, in beide Richtungen (Abstand ≥ größerer der beiden Radien, gilt auch zum Hauptgem). Nur die Werkstatt prüft das beim Setzen, Verschieben und Ändern (`FocusCanvas.radius_conflict`); die Auswertung nicht, ältere Foki bleiben gültig. Beim Ziehen gleitet ein Gem am Rand fremder Reichweiten entlang (`_slide_position`).
- **Winkel:** Spitz sammelt im Innenwinkel der Ecke, Grob im Außenwinkel („innen“ = zum Polygoninneren, auch bei konkaven Formen).
- **Multiplikator:** Spitze Gems zählen eingesammelte Essenzen pauschal **×2** (`GemDef.SPITZ_MULTIPLIER`), grobe ×1. Das gilt auch für Hauptgems. Radius und Kapazität wirken nicht auf den Multiplikator.
- **Einsammeln:** zuerst das Hauptgem, dann die Nebengems in **Platzierungsreihenfolge**. Jedes nimmt die nächstgelegenen freien Punkte bis zu seiner Kapazität (N-E und E getrennt). Jeder Punkt wird nur einmal eingesammelt. Danach: effektiv = eingesammelt × Multiplikator.
- **Übertragen:** Gems mit der Gravur **Power Transfer** (ID `standard`) geben ihre effektiven N-E und E an das Hauptgem, sammeln dafür aber nur mit **halbem Radius** (`EngravingDef.radius_factor`, wirksamer Radius über `PlacedGem.get_radius()`). Der Multiplikator des Hauptgems wirkt nur auf das, was es selbst einsammelt.
- **Punkte und Element-Faktor:** Gravuren rechnen mit **Punkten** = N-E + E × Faktor des Elements (`ElementDef.factor`, zurzeit überall 5). Eine Gravur zählt **nur E ihrer Elemente** (`EngravingDef.element_ids`, z. B. Heal = Wasser), **fremde E zählen gar nicht**. **Gravuren ohne Element zählen keine E** (nur N-E). Der **Magische Bolzen hat alle Elemente**. Jede Gravur hat **eine Rate pro Wert** (z. B. Heal 5 pro Punkt); Regeln mit Quelle `POINTS`. Die Beschreibung bekommt im Generator automatisch den Zusatz „Punkte: …“.
- **Status** (Burn, Nass, Bleed, Armor Break, Schock) entsteht **nur aus E des passenden Elements** (gewichtet), nie aus N-E. Pro Status gibt es eine eigene Nebengravur (Burn, Nass, Bleed, Armor Break, Schock) mit dem passenden Element.
- Die Hauptgravur bestimmt die Art des Spells. Gems verfärben sich nicht; es gibt keine Resistenz und nur einen Schadenstyp. Power Transfer überträgt rohe N-E und E; das Hauptgem wendet seine Regeln (und seinen Elementfilter) an.
- **Tooltips:** Element- und Status-Wörter in Texten sind Begriffe (`CraftingContent.glossary`, Texte in `STATUS_TERMS` im Generator, Element-Texte automatisch). Hovern zeigt den Tooltip, nach ca. 1 s ist er festgepinnt; Begriffe darin öffnen weitere Tooltips. Neue UI-Texte mit Begriffen: `tooltips.linkify()` und Label mit `tooltips.register()` anmelden.
- In der Werkstatt werden E-Punkte größer gezeichnet als N-E (`FocusCanvas.ELEMENT_DOT_SCALE`); doppelt zählende Punkte (Spitz) haben eine versetzte Schattenkopie, die Gem-Liste zeigt „Punkte für die Gravur“. Beim Darüberfahren (und Ziehen) zeigt ein Gem seine eingesammelten Punkte mit Linien und „Sammelt: …“.
- **Crit:** 1 Crit = 1 % Crit-Chance. Ein Crit macht 200 % Schaden (Auswirkung erst im Kampf, M6).
- **Speicherstände** liegen als JSON in `user://foci/` und enthalten nur IDs (`FocusInstance.to_dict()` / `from_dict()`). Unbekannte IDs werden beim Laden entfernt und gemeldet; fehlt ein Gem, wird der Kreis gelöst. **IDs von Gems, Gravuren, Foki und Elementen nicht leichtfertig umbenennen**, sonst gehen gespeicherte Gems verloren.
- **Hauptgravuren** (Element in Klammern): Magischer Bolzen (alle), Freeze (Wasser und Luft, 100 Nass → 1 Eis), Slow (Luft), Heal (Wasser), Schutz (Erde), Hasted (Luft), Leben-Reg (Wasser), Mana-Reg (Blitz), Feuerball (Feuer, Burn), Wasser-Detonation (Wasser, Nass), Luftklinge (Luft, Bleed), Kanone (Erde, Armor Break), Blitzschlag (Blitz, Schock).
- **Nebengravuren:** Power Transfer (Übertragen, halber Radius, keins), Crit (Feuer), Mana-Reduktion (Wasser), Cast-Speed (Luft), Armor (Erde), Mana Burn (Blitz), Burn (Feuer), Nass (Wasser), Bleed (Luft), Armor Break (Erde), Schock (Blitz). Die sechs Status-Nebengravuren (inkl. Mana Burn) zählen keine N-E, 1 Status pro 5 Punkte.
- **Cast-Zeit** = 1 s pro Gem − `cast_time_reduction` (mind. 0,5 s). **Mana** = Kantenlänge × 0,1 − `mana_reduction` (mind. 1).
- **Foki** sind feste Typen: Form (Kreis, Stern, Tropfen), Gem-Kapazität (klein 3, mittel 3–5, groß 5–7, sehr groß bis 10), **Gesamtkapazität** `max_dots` für N-E und E zusammen, ein **Limit für alle E zusammen** `max_element_dots` (nicht pro Element) und `allowed_elements` (z. B. Feuer-Fokus nur Feuer, neutraler Fokus 0 E). **N-E wird nicht eingestellt**, sondern füllt immer bis zur Gesamtkapazität auf (`FocusInstance.get_base_count()`). Upgrades durch den Spieler sind vorerst nicht vorgesehen.
- Der Kampf ist ausschließlich 1-gegen-1, es gibt keinen Flächenschaden und keine Mehrfachziele.

## Kampf (M6, umgesetzt in `core/combat/`)

- 1 gegen 1, Tick 0,1 s, deterministisch über einen Seed (Crit wird gewürfelt). Gekämpft wird mit gespeicherten Foki (`FocusStore`), je Magier bis zu 5 Spells.
- **Feste Reihenfolge mit Bedingungen:** Spells werden der Reihe nach im Kreis gecastet. Jeder Spell hat eine Aktivierungsbedingung (`SpellCondition`: Immer, Einmal, eigenes/gegnerisches Leben unter/über X %, selbst/Gegner hat Status); ist sie nicht erfüllt, wird er übersprungen. Fehlt Mana, wartet der Magier. **Mana wird beim Cast-Start bezahlt** (löst Schock aus). Cast-Zeit = Spell-Cast-Zeit + Slowed − Hasted (mind. 0,5 s); **Slowed und Hasted gelten nur für diesen Cast und werden verbraucht** (kein Abbau über Zeit).
- **Ziel:** Die Hauptgravur bestimmt das Ziel (`EngravingDef.target`: Gegner, selbst, beide). **Alle Werte des Spells, auch die der Nebengravuren, gehen auf dieses Ziel** (Feuerball + Armor-Nebengem gibt dem Gegner Armor). Selbst-Ziel: Heal, Schutz, Hasted, Leben-Reg, Mana-Reg.
- **Eis pausiert den Cast** (kein Abbruch). Freeze wandelt nach dem Treffer je `freeze_conversion` Nass in 1 Eis.
- Status wirken einmal pro Sekunde (Puls), Stacks sind ganze Zahlen; auch die Mana-Reg kommt im Puls. Armor Break wirkt sofort (Rest verfällt).
- Ende: ein Magier ohne Leben (beide gleichzeitig = unentschieden) oder Zeitlimit (unentschieden).
- Alle „X“ der Tabelle stehen in `CombatRules` (Platzhalter). `content/combat_rules.tres` legt der Generator nur einmal an und überschreibt es nicht.

### Kampfregeln (Tabelle des Nutzers)

| Status | Wirkung |
|---|---|
| Bleed | X Schaden pro s, −1 Stack pro s |
| Slowed | X s mehr Cast-Zeit beim nächsten Cast, wird dabei verbraucht, max. 10, hebt Hasted 1 : 1 auf |
| Hasted | X s weniger Cast-Zeit beim nächsten Cast, wird dabei verbraucht, max. 10, hebt Slowed 1 : 1 auf |
| Mana Burn | −X Mana-Reg pro s, −1 Stack pro Mana-Reg pro s |
| Armor | verhindert X Schaden, −1 pro verhindertem Schaden |
| Schock | 1 Schaden pro verbrauchtem Mana (max. = Stacks), −1 pro verbrauchtem Mana |
| Nass | +X Schaden auf Schock-Schaden, hebt Burn 1 : 1 auf |
| Eis | X s Stun, −1 pro s |
| Burn | X Schaden pro s, −1 Stack pro s |
| Leben-Reg | 1 Leben pro s pro Stack, −1 Stack pro s |
| Mana-Reg | 1 Mana pro s pro Stack, −1 Stack pro s |
| Armor Break | hebt Armor 1 : 5 auf |
| Crit | 1 Crit = 1 % Chance, ein Crit macht 200 % Schaden |

## Befehle

Godot-Pfad und Git-Pfad sind maschinenspezifisch (siehe Notizen des Nutzers bzw. Memory).

```powershell
# Klassen registrieren (nach neuen class_name-Skripten nötig)
godot --headless --path . --import
# Inhalte neu erzeugen (nach Änderungen in tools/generate_content.gd)
godot --headless --path . -s res://tools/generate_content.gd
# Bilder aufbereiten (nach neuen Assets), danach --import
godot --headless --path . -s res://tools/prepare_assets.gd
# Tests (Exit-Code 0 = grün)
godot --headless --path . -s res://tests/run_tests.gd
# Render-Check der Werkstatt (PNG-Frames)
godot --path . res://tests/preview_snapshot.tscn --write-movie out.png --quit-after 4 --fixed-fps 30 -- [--focus=<id>] [--place] [--place-at=x,y] [--all-elements] [--tooltip] [--details] [--scroll] [--hover[=N]] [--replace]
godot --path . --write-movie out.png --quit-after 3 --fixed-fps 30 -- --example
# Render-Check der Arena (Beispiel-Magier, nicht aus user://)
godot --path . res://tests/arena_snapshot.tscn --write-movie out.png --quit-after 4 --fixed-fps 30 -- [--seconds=N] [--stats]
```

## Arbeitsweise

- Der Nutzer ist Hobby-Entwickler und will Claude als technischen Partner und Game-Design-Berater: Ideen konstruktiv hinterfragen, Alternativen nennen, kein Overengineering.
- Design-Fragen als **Multiple Choice** stellen (AskUserQuestion), mit Empfehlung.
- **Commits nur nach ausdrücklicher Freigabe**, nie pushen ohne Nachfrage. Autor wie in den bisherigen Commits.
- Nach Änderungen die Tests ausführen. Bei UI-Änderungen zusätzlich ein Bild rendern und ansehen.

## Spell-Paket vom 2026-11-26 (Vorgabe des Nutzers, in Etappen)

Etappe 1 (Systemänderungen) ist umgesetzt: Power Transfer, Ziel durch Hauptgravur, Slowed/Hasted nur nächster Cast, Aktivierungsbedingungen, Schattenkopie. Offen:

- **Etappe 2 – neue Status:** Perma-Burn (Debuff, erzeugt jede Sekunde X Burn), Bless (+X Heilung pro Heilung), Thorns (X Gegenschaden pro Spell-Treffer), Mana Absorption (X Mana pro erhaltenem Treffer), Life Rewind (speichert HP, setzt nach 10 s zurück), Damage Reduction (halbiert den nächsten Spell-Schaden). Dazu Mehrfach-Treffer, Cleanse (eigene Debuffs weg), Dispel (gegnerische Buffs weg), Accelerated Burn.
- **Etappe 3 – Hauptgravuren:** Meteor, Fire Rain (beide), Permanent Burn; Water Rain (beide), Cleanse, Bless, Life Rewind; Dispel, Thunderstorm (1 Treffer pro 50 Blitz-Punkte); Bulwark (ab 50 Erd-Punkte, viel Armor), Damage Reduction; Accelerated Burn (Luft + Feuer), Mana Absorption (Wasser + Erde).
- **Etappe 4 – Nebengravuren:** Echo (Spell erneut, Mana erneut, keine Cast-Zeit), Mana Efficiency / Quick Cast (Wasser + Luft, flache Werte), Radius Expansion (Erde, Radius des Hauptgems pro Erd-Punkt; braucht 2. Auswertungsdurchlauf), Thorns (Erde).
- **Etappe 5 – Multiplikator-Gravur:** neue Gem-Form (klein/mittel), Sektor wie andere Gems, äußerer Radius 0,8 × Größenradius mit ×1, innerer 0,3 × mit ×2.
- **Grundsatz:** Status- und Kampfwerte **flach**, nicht in Prozent (außer wo der Nutzer Prozent vorgibt, z. B. Damage Reduction 50 %).
- **Entschieden:** Dodge (Status und Hauptgravur) entfällt. Perma-Burn baut sich nicht ab (pro Stack und Sekunde 1 Burn), nur Cleanse entfernt ihn. Accelerated Burn = doppelte Tick-Frequenz (gleicher Gesamtschaden, halbe Zeit). Life Rewind: Tod ist Tod; nach 10 s wird das Leben auf den gespeicherten Wert gesetzt (auch nach unten).
- **Noch zu entscheiden:** Echo-Schwellen. Neue Gravuren brauchen Symbole (Assets).

## Offene Punkte

- **Freeze:** 100 Nass → 1 Eis ist mit 1 Nass pro 10 Wasser-Punkte (= 2 Wasser-E) kaum erreichbar. Verhältnis im Balancing prüfen; Stun-Lock durch Eis vermeiden.
- **Kampf (M6) weiter:** Werte in `CombatRules` und der Spells balancen (Kämpfe werden über Mana-Engpässe entschieden, Status-Stacks aus Spells sind klein). Später: Gegner-Vorlagen, Spell-Bedingungen, Balancing-Werkzeug (viele Kämpfe simulieren).
- **Grafik (M4):** Stil, Referenzbilder und Assets vom Nutzer stehen noch aus. Ideen: HDR-2D-Glow, Shader für Linien und Sektoren, Partikel beim Einsammeln.
- **Ressourcen und Dungeons** über den Auto-Battler: erst später.
