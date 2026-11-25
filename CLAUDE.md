# MagicFocus

Spell-Crafting-Spiel in **Godot 4.7 / GDScript**. Der Spieler baut **Foki** (Arbeitsflächen),
befüllt sie mit Energie, setzt **Runen** und verbindet sie zu einem geschlossenen Kreis.
Daraus entsteht ein Spell. Später kommt ein **1-gegen-1-Magier-Auto-Battler** dazu. Er ist
**noch nicht** implementiert, Architekturentscheidungen sollen ihn aber nicht verbauen.

Kommunikation mit dem Nutzer auf **Deutsch**.

## Struktur

| Ordner | Inhalt |
|---|---|
| `core/data/` | Ressourcen-Klassen: `ElementDef`, `RuneDef`, `SpellFormDef`, `ScalingRule`, `FocusDef`, `FocusShape` (+ `CircleFocusShape`, `PolygonFocusShape` → `StarFocusShape`, `DropFocusShape`), `FocusInstance`, `PlacedRune`, `RuneEffect`, `CraftingContent` |
| `core/logic/` | Reine Logik ohne Physik/Szenen: `SpellEvaluator` (Auswertung in 6 Phasen), `FocusGeometry`, `DotField` (Punkte aus Seed), `SpellResult`, `RuneResult`, `EnergyDot` |
| `content/` | Inhalte als `.tres` (Elemente, Runen, Spell-Formen, Foki). `crafting_content.tres` listet alles; die Reihenfolge der Elemente entscheidet bei Gleichstand |
| `ui/workshop/` | Fokus-Werkstatt (Hauptszene): `workshop.gd` (Panels, im Code aufgebaut), `focus_canvas.gd` (Zeichnen und Mausbedienung) |
| `tests/` | `run_tests.gd` (headless Testsuite), `preview_snapshot.tscn` (Render-Check der Werkstatt) |
| `debug/` | Frühe Debug-Ansicht aus M1 |
| `FocusCraft/`, `FocusLexicon/` | **Altcode** (Prototyp 2023/24, physikbasiert). Nicht weiterentwickeln, nur Referenz |

## Architekturregeln

- Die Logik in `core/logic/` bleibt frei von Physik, Nodes und Rendering, damit sie headless läuft (Werkstatt-Vorschau, später die Kampfsimulation).
- Elemente werden über ihre **ID** identifiziert, nie über ihre Farbe. Die Farbe dient nur der Darstellung.
- Werte, Kapazitäten und Regeln gehören in `.tres`-Inhalte bzw. `ScalingRule`s, nicht in Code. Neue Spells und Runen brauchen möglichst keinen neuen Code.
- Neue Fokusformen sind eine Unterklasse von `PolygonFocusShape` (nur `_build_polygon()`). Spezial-Effekte von Runen sind eine Unterklasse von `RuneEffect` (Phase 4 der Auswertung).
- Begriffe in der Oberfläche: **Energiepunkte** (Code: `base`) und **Essenzen** (Code: `element`). In der UI deutsch, im Code englische Bezeichner.
- Alle Zahlenwerte in `content/` sind Platzhalter fürs Balancing.

## Implementierte Spielregeln

- Ein Spell braucht genau **1 Hauptrune** und mindestens **3 Runen** in einem **geschlossenen Kreis**, der bei der Hauptrune beginnt. Kanten dürfen sich nicht kreuzen und müssen **innerhalb der Fokusform** verlaufen.
- Einflussbereich einer Rune: Radius plus **Innen-, Außen- oder beide Winkel** an ihrer Ecke („innen“ = zum Polygoninneren, auch bei konkaven Formen).
- **Einsammeln:** zuerst die Hauptrune, dann die Zusatzrunen in **Platzierungsreihenfolge**. Jede nimmt die nächstgelegenen freien Punkte bis zu ihrer Kapazität (Energie und Essenzen getrennt). Jeder Punkt kann nur einmal eingesammelt werden.
- **Runen-Element:** das häufigste Element ab der Schwelle (`SpellEvaluator.ELEMENT_THRESHOLD`, Standard 4, in der Werkstatt einstellbar). Bei Gleichstand gewinnt die Reihenfolge in `crafting_content`.
- **Hauptrune:** Ihr Typ bestimmt die **Spell-Form** (Geschoss, Schild, Explosion), ihr Element das **Spell-Element**. Die Form skaliert mit den Essenzen der Hauptrune und den Energiepunkten aller Runen, multipliziert mit `strength`.
- **Zusatzrunen:** Sie bekommen die `minor_rules` ihres Elements (Feuer → Burn, Wasser → Wet und Heilung, Erde → Schild, Luft → kürzere Cast-Zeit, Blitz → Shock), außer bei `use_element_rules = false`.
- **Statuseffekt-Rune:** ab 5 Essenzen eines Elements 1 Stack pro Essenz (Blitz → Shock, Feuer → Burn, Wasser → Wet, Luft → Slow). Erde hat keinen Effekt.
- **Cast-Zeit** = 1 s pro Rune minus Luft-Verkürzung. **Mana** = Kantenlänge × 0,1.
- **Foki** sind feste Typen: Form (Kreis, Stern, Tropfen), Runen-Kapazität (klein 3, mittel 3–5, groß 5–7, sehr groß bis 10), Kapazität für Energiepunkte und Essenzen sowie `allowed_elements` (z. B. Feuer-Fokus nur Feuer, neutraler Fokus 0 Essenzen). Upgrades durch den Spieler sind vorerst nicht vorgesehen.
- Der Kampf ist ausschließlich 1-gegen-1, es gibt keinen Flächenschaden und keine Mehrfachziele.

## Befehle

Godot-Pfad und Git-Pfad sind maschinenspezifisch (siehe Notizen des Nutzers bzw. Memory).

```powershell
# Klassen registrieren (nach neuen class_name-Skripten nötig)
godot --headless --path . --import
# Tests (Exit-Code 0 = grün)
godot --headless --path . -s res://tests/run_tests.gd
# Render-Check der Werkstatt (PNG-Frames)
godot --path . res://tests/preview_snapshot.tscn --write-movie out.png --quit-after 4 --fixed-fps 30 -- [--focus=<id>] [--place]
godot --path . --write-movie out.png --quit-after 3 --fixed-fps 30 -- --example
```

## Arbeitsweise

- Der Nutzer ist Hobby-Entwickler und will Claude als technischen Partner und Game-Design-Berater: Ideen konstruktiv hinterfragen, Alternativen nennen, kein Overengineering.
- Design-Fragen als **Multiple Choice** stellen (AskUserQuestion), mit Empfehlung.
- **Commits nur nach ausdrücklicher Freigabe**, nie pushen ohne Nachfrage. Autor wie in den bisherigen Commits.
- Nach Änderungen die Tests ausführen. Bei UI-Änderungen zusätzlich ein Bild rendern und ansehen.

## Offene Punkte

- **Übertragungsrune** (gibt ihre Punkte an die Hauptrune; deren Kapazität gilt): Was passiert mit dem Überschuss?
- **Eis-Rune** (Zusatzrune, wandelt Wet-Stacks in Ice-Stacks, Freeze/Stun): Verhältnis noch offen, Stun-Lock vermeiden.
- Möglichkeit, die **Manakosten zu beeinflussen**: noch nicht festgelegt.
- **Explosion:** eigene Rolle im 1-gegen-1 kommt mit dem Kampfsystem.
- **Kampfsystem (M6):** Bedeutung von Burn, Wet, Shock (Schaden pro verbrauchtem Gegner-Mana), Slow (verlangsamt Gegner-Casts), Schild und Resistenz. Eine headless und deterministische Simulation ist geplant.
- **Grafik (M4):** Stil, Referenzbilder und Assets vom Nutzer stehen noch aus. Ideen: HDR-2D-Glow, Shader für Linien und Sektoren, Partikel beim Einsammeln.
- **Ressourcen und Dungeons** über den Auto-Battler: erst später.
