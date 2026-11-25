# MagicFocus

Spell-Crafting-Spiel in **Godot 4.7 / GDScript**. Der Spieler baut **Foki** (Arbeitsflächen),
befüllt sie mit Essenzen, setzt **Gems** (Form + Gravur) und verbindet sie zu einem
geschlossenen Kreis. Daraus entsteht ein Spell. Später kommt ein **1-gegen-1-Magier-Auto-Battler**
dazu. Er ist **noch nicht** implementiert, Architekturentscheidungen sollen ihn aber nicht verbauen.

Kommunikation mit dem Nutzer auf **Deutsch**.

## Struktur

| Ordner | Inhalt |
|---|---|
| `core/data/` | Ressourcen-Klassen: `ElementDef`, `GemDef` (Form), `EngravingDef` (Gravur), `ScalingRule`, `FocusDef`, `FocusShape` (+ `CircleFocusShape`, `PolygonFocusShape` → `StarFocusShape`, `DropFocusShape`), `FocusInstance`, `PlacedGem`, `GemEffect`, `CraftingContent` |
| `core/logic/` | Reine Logik ohne Physik/Szenen: `SpellEvaluator` (Auswertung in 6 Phasen), `FocusGeometry`, `DotField` (Punkte aus Seed), `SpellResult`, `GemResult`, `EnergyDot` |
| `content/` | Inhalte als `.tres`: `elements/`, `gems/`, `engravings/`, `foci/`. `crafting_content.tres` listet alles (Reihenfolge = Reihenfolge in der UI) |
| `tools/` | `generate_content.gd`: erzeugt Gems, Gravuren und `crafting_content.tres` aus Tabellen. **Werte dort ändern und neu erzeugen**, nicht die `.tres` von Hand |
| `ui/workshop/` | Fokus-Werkstatt (Hauptszene): `workshop.gd` (Panels, im Code aufgebaut), `focus_canvas.gd` (Zeichnen und Mausbedienung) |
| `tests/` | `run_tests.gd` (headless Testsuite), `preview_snapshot.tscn` (Render-Check der Werkstatt) |
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
- **Gem = Form + Gravur.** Die Form (`GemDef`) legt Radius, Winkel und Kapazität fest, die Gravur (`EngravingDef`) die Wirkung. Die Rolle (Haupt/Neben) muss übereinstimmen. In der Werkstatt wählt man **Gravur, Größe (klein/mittel/groß) und Spitz ja/nein**; die Gravur legt die Rolle fest, die Form ergibt sich über `CraftingContent.find_gem()`. Es gibt 12 Formen (2 Rollen × 3 Größen × Spitz/Grob), erzeugt aus `GEM_SIZES` im Generator.
- **Winkel:** Spitz sammelt im Innenwinkel der Ecke, Grob im Außenwinkel („innen“ = zum Polygoninneren, auch bei konkaven Formen).
- **Multiplikator:** Spitze Gems zählen eingesammelte Essenzen pauschal **×2** (`GemDef.SPITZ_MULTIPLIER`), grobe ×1. Das gilt auch für Hauptgems. Radius und Kapazität wirken nicht auf den Multiplikator.
- **Einsammeln:** zuerst das Hauptgem, dann die Nebengems in **Platzierungsreihenfolge**. Jedes nimmt die nächstgelegenen freien Punkte bis zu seiner Kapazität (N-E und E getrennt). Jeder Punkt wird nur einmal eingesammelt. Danach: effektiv = eingesammelt × Multiplikator.
- **Übertragen:** Gems mit der Gravur **Standard** geben ihre effektiven N-E und E an das Hauptgem. Der Multiplikator des Hauptgems wirkt nur auf das, was es selbst einsammelt.
- **Gravur-Regeln** zählen „pro N-E“, „pro E“ (alle Elemente) oder „pro Element-E“. Überlappende Regeln **addieren** sich (Heal: Wasser-E = 10 + 20). Die Hauptgravur bestimmt die Art des Spells. Gems verfärben sich nicht; es gibt keine Resistenz und nur einen Schadenstyp.
- **Hauptgravuren:** Magischer Bolzen, Freeze (100 Nass → 1 Eis), Slow, Heal, Schutz, Feuerball (Burn), Wasser-Detonation (Nass), Luftklinge (Bleed), Kanone (Armor Break), Blitzschlag (Schock). Die Status-Attacken zählen nur ihr eigenes Element.
- **Nebengravuren:** Standard (Übertragen), Crit (Feuer), Mana-Reduktion (Wasser), Cast-Speed (Luft, −1 s pro 5), Armor (E, Erde extra), Status (jedes Element erzeugt seinen Status: Feuer → Burn, Wasser → Nass, Luft → Bleed, Erde → Armor Break, Blitz → Schock).
- **Cast-Zeit** = 1 s pro Gem − `cast_time_reduction` (mind. 0,5 s). **Mana** = Kantenlänge × 0,1 − `mana_reduction` (mind. 1).
- **Foki** sind feste Typen: Form (Kreis, Stern, Tropfen), Gem-Kapazität (klein 3, mittel 3–5, groß 5–7, sehr groß bis 10), **Gesamtkapazität** `max_dots` für N-E und E zusammen, ein **Limit für alle E zusammen** `max_element_dots` (nicht pro Element) und `allowed_elements` (z. B. Feuer-Fokus nur Feuer, neutraler Fokus 0 E). **N-E wird nicht eingestellt**, sondern füllt immer bis zur Gesamtkapazität auf (`FocusInstance.get_base_count()`). Upgrades durch den Spieler sind vorerst nicht vorgesehen.
- Der Kampf ist ausschließlich 1-gegen-1, es gibt keinen Flächenschaden und keine Mehrfachziele.

## Kampfregeln für M6 (Entwurf des Nutzers, noch nicht implementiert)

| Status | Wirkung |
|---|---|
| Bleed | X Schaden pro s, −1 Stack pro s |
| Slowed | X s mehr Cast-Zeit, −1 Stack pro s, max. 10, hebt Hasted 1 : 1 auf |
| Hasted | X s weniger Cast-Zeit, −1 Stack pro s, max. 10, hebt Slowed 1 : 1 auf |
| Mana Burn | −X Mana-Reg pro s, −1 Stack pro Mana-Reg pro s |
| Armor | verhindert X Schaden, −1 pro verhindertem Schaden |
| Schock | 1 Schaden pro verbrauchtem Mana (max. = Stacks), −1 pro verbrauchtem Mana |
| Nass | +X Schaden auf Schock-Schaden, hebt Burn 1 : 1 auf |
| Eis | X s Stun, −1 pro s |
| Burn | X Schaden pro s, −1 Stack pro s |
| Leben-Reg | 1 Leben pro s pro Stack, −1 Stack pro s |
| Mana-Reg | 1 Mana pro s pro Stack, −1 Stack pro s |
| Armor Break | hebt Armor 1 : 5 auf |

## Befehle

Godot-Pfad und Git-Pfad sind maschinenspezifisch (siehe Notizen des Nutzers bzw. Memory).

```powershell
# Klassen registrieren (nach neuen class_name-Skripten nötig)
godot --headless --path . --import
# Inhalte neu erzeugen (nach Änderungen in tools/generate_content.gd)
godot --headless --path . -s res://tools/generate_content.gd
# Tests (Exit-Code 0 = grün)
godot --headless --path . -s res://tests/run_tests.gd
# Render-Check der Werkstatt (PNG-Frames)
godot --path . res://tests/preview_snapshot.tscn --write-movie out.png --quit-after 4 --fixed-fps 30 -- [--focus=<id>] [--place] [--details]
godot --path . --write-movie out.png --quit-after 3 --fixed-fps 30 -- --example
```

## Arbeitsweise

- Der Nutzer ist Hobby-Entwickler und will Claude als technischen Partner und Game-Design-Berater: Ideen konstruktiv hinterfragen, Alternativen nennen, kein Overengineering.
- Design-Fragen als **Multiple Choice** stellen (AskUserQuestion), mit Empfehlung.
- **Commits nur nach ausdrücklicher Freigabe**, nie pushen ohne Nachfrage. Autor wie in den bisherigen Commits.
- Nach Änderungen die Tests ausführen. Bei UI-Änderungen zusätzlich ein Bild rendern und ansehen.

## Offene Punkte

- **Quellen fehlen** für Hasted, Mana Burn, Leben-Reg und Mana-Reg: Keine Gravur erzeugt sie bisher.
- **Crit:** Bedeutung offen (Chance oder Multiplikator?). Bisher nur ein Zählwert.
- **Freeze:** 100 Nass → 1 Eis ist mit 1 Nass pro 2 Wasser-E kaum erreichbar. Verhältnis im Balancing prüfen; Stun-Lock durch Eis vermeiden.
- **N-E auf Nebengems:** Außer bei Standard bewirken eingesammelte N-E auf Nebengems nichts. Ist das gewollt?
- **Gravur nachträglich ändern:** Bisher entfernen und neu setzen. Komfort-Funktion später.
- **Kampfsystem (M6):** Status-Mechaniken siehe oben; headless und deterministisch geplant.
- **Grafik (M4):** Stil, Referenzbilder und Assets vom Nutzer stehen noch aus. Ideen: HDR-2D-Glow, Shader für Linien und Sektoren, Partikel beim Einsammeln.
- **Ressourcen und Dungeons** über den Auto-Battler: erst später.
