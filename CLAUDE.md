# MagicFocus

Spell-Crafting-Spiel in **Godot 4.7 / GDScript**. Der Spieler baut **Foki** (Arbeitsflächen),
befüllt sie mit Essenzen, setzt **Gems** (Form + Gravur) und verbindet sie zu einem
geschlossenen Kreis. Daraus entsteht ein Spell. Später kommt ein **1-gegen-1-Magier-Auto-Battler**
dazu. Er ist **noch nicht** implementiert, Architekturentscheidungen sollen ihn aber nicht verbauen.

Kommunikation mit dem Nutzer auf **Deutsch**.

## Struktur

| Ordner | Inhalt |
|---|---|
| `core/data/` | Ressourcen-Klassen: `FocusStore` (gespeicherte Foki als JSON), `Balance` (Änderungen aus dem Editor als Overrides in `user://balance.json`, `ensure_applied()` in jeder Szene), `ContentText` (Gravur-Beschreibung und Wertnamen aus den Werten), `GlossaryBuilder` (Begriffe zur Laufzeit mit aktuellen Kampfregeln), `GlossaryTerm`, `ElementDef`, `GemDef` (Form), `EngravingDef` (Gravur), `ScalingRule`, `FocusDef`, `FocusShape` (+ `CircleFocusShape`, `PolygonFocusShape` → `StarFocusShape`, `DropFocusShape`), `FocusInstance`, `PlacedGem`, `GemEffect`, `CraftingContent` |
| `core/logic/` | Reine Logik ohne Physik/Szenen: `SpellEvaluator` (Auswertung in 6 Phasen), `FocusGeometry`, `DotField` (Punkte aus Seed), `SpellResult`, `GemResult`, `EnergyDot`, `TextFormat` (Zahlen für Texte) |
| `core/combat/` | Kampf (M6), reine Logik: `Combat` (Ablauf, Log, Statistik), `Status` (**einzige Status-Tabelle**: Namen, Buffs, Debuffs; ID = Spell-Wert = Begriff im Glossar), `CombatMage` (Zustand, `from_foci`), `CombatRules` (Zahlen, Inhalt in `content/combat_rules.tres`), `SpellCondition` |
| `content/` | Inhalte als `.tres`: `elements/`, `gems/`, `engravings/`, `foci/`. `crafting_content.tres` listet alles (Reihenfolge = Reihenfolge in der UI) |
| `tools/` | `generate_content.gd`: erzeugt Gems, Gravuren und `crafting_content.tres` aus Tabellen. **Werte dort ändern und neu erzeugen**, nicht die `.tres` von Hand. `prepare_assets.gd`: schneidet und verkleinert generierte Bilder nach `assets/sprites/` (Gravur-Symbole: alle PNGs aus `assets/engravings/<gravur-id>.png`, danach Generator neu laufen lassen) |
| `assets/` | Bilder (vom Nutzer mit ChatGPT erzeugt): Originale in `gems/`, `essences/`, `textures/`, `engravings/<gravur-id>.png`, `elements/element_<id>.png`; Spiel nutzt `sprites/` (aufbereitet, Mipmaps an). Jedes Element hat eine eigene Punktform (`ElementDef.dot_texture`, im Generator gesetzt), neutrale Essenz ist eine Kugel. Gravuren zeigen auf dem Gem ihr Symbol (`EngravingDef.icon`); ohne Symbol die Form ihres Elements (nur bei genau einem Element). Elemente haben ein Symbol (`ElementDef.icon`) für Befüllen-Liste und Tooltips; Status-Tooltips nutzen das Symbol der erzeugenden Gravur (`STATUS_ICONS` im Generator). Neue Bilder kommen in `input/` und werden von Claude einsortiert |
| `ui/arena/` | Arena: zwei Magier aus gespeicherten Foki (bis zu 5 Spells), Balken, Status-Symbole, Log, Tempo 1×/2×/4× |
| `ui/glossary/` | Glossar-Seite: Reiter Status, Gravuren, Gems, Foki, Elemente, Kampfregeln mit aktuellen Werten, Suche |
| `ui/common/` | `term_tooltips.gd`: verschachtelte Tooltips (`linkify()` + `register()`, `[nolink]…[/nolink]` verhindert Links); `ui_kit.gd`: Bausteine für die im Code gebauten Oberflächen |
| `ui/workshop/` | Fokus-Werkstatt (Hauptszene): `workshop.gd` (Panels, im Code aufgebaut), `focus_canvas.gd` (Zeichnen und Mausbedienung) |
| `tests/` | `run_tests.gd` (Runner: ruft jede Methode `test_*` aller Dateien in `suites/` auf; Skriptfehler zählen als Fehler), `test_suite.gd` (Basis mit `check` und Helfern), `suites/test_*.gd` (nach Thema), `preview_snapshot.tscn` (Render-Check der Werkstatt), `arena_snapshot.tscn` (Render-Check der Arena) |
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
- **Gem = Form + Gravur.** Die Form (`GemDef`) legt Radius, Winkel und Kapazität fest, die Gravur (`EngravingDef`) die Wirkung. Die Rolle (Haupt/Neben) muss übereinstimmen. In der Werkstatt wählt man **Gravur, Größe (winzig/klein/mittel/groß) und Spitz ja/nein**; ein **Klick auf ein gesetztes Gem** übernimmt diese Auswahl (gleiche Rolle nötig, Position und Kreis bleiben, Vorschau beim Darüberfahren); die Gravur legt die Rolle fest, die Form ergibt sich über `CraftingContent.find_gem()`. Es gibt 16 Formen (2 Rollen × 4 Größen × Spitz/Grob), erzeugt aus `GEM_SIZES` im Generator.
- **Abstand:** Kein Gem darf in der Reichweite eines anderen liegen, in beide Richtungen (Abstand ≥ größerer der beiden Radien, gilt auch zum Hauptgem). Nur die Werkstatt prüft das beim Setzen, Verschieben und Ändern (`FocusCanvas.radius_conflict`); die Auswertung nicht, ältere Foki bleiben gültig. Beim Ziehen gleitet ein Gem am Rand fremder Reichweiten entlang (`_slide_position`).
- **Verdeckte Essenz:** Jedes Gem hat einen Stein (`GemDef.body_radius`, Fokus-Einheiten, `GEM_BODY` im Generator: Haupt 15, Neben 10). Essenz darunter zählt für kein Gem (`SpellResult.blocked`); die Werkstatt zeichnet den Stein in dieser Größe und markiert verdeckte Essenz mit rotem Kreuz. Der innere Ring des Multiplikators beginnt am Stein (Stein + 0,3 × Radius).
- **Winkel:** Spitz sammelt im Innenwinkel der Ecke, Grob im Außenwinkel („innen“ = zum Polygoninneren, auch bei konkaven Formen).
- **Multiplikator:** Spitze Gems zählen eingesammelte Essenzen pauschal **×2** (`GemDef.SPITZ_MULTIPLIER`), grobe ×1. Das gilt auch für Hauptgems. Radius und Kapazität wirken nicht auf den Multiplikator.
- **Einsammeln:** zuerst das Hauptgem, dann die Nebengems in **Platzierungsreihenfolge**. Jedes nimmt die nächstgelegenen freien Punkte bis zu seiner Kapazität (N-E und E getrennt). Jeder Punkt wird nur einmal eingesammelt. Danach: effektiv = eingesammelt × Multiplikator.
- **Übertragen:** Gems mit der Gravur **Power Transfer** (ID `standard`) geben ihre effektiven N-E und E an das Hauptgem, sammeln dafür aber nur mit **halbem Radius** (`EngravingDef.radius_factor`, wirksamer Radius über `PlacedGem.get_radius()`). Der Multiplikator des Hauptgems wirkt nur auf das, was es selbst einsammelt.
- **Punkte und Element-Faktor:** Gravuren rechnen mit **Punkten** = N-E + E × Faktor. Der Faktor hängt **an der Gravur, pro Element** (`EngravingDef.element_factors`, Standard 5, im Generator `factors`). Eine Gravur zählt **nur E ihrer Elemente** (`EngravingDef.element_ids`, z. B. Heal = Wasser), **fremde E zählen gar nicht**. **Gravuren ohne Element zählen keine E** (nur N-E). Der **Magische Bolzen hat alle Elemente**. Jede Gravur hat **eine Rate pro Wert** (z. B. Heal 5 pro Punkt); Regeln mit Quelle `POINTS`. Die Beschreibung bekommt im Generator automatisch den Zusatz „Punkte: …“.
- **Status** (Burn, Nass, Bleed, Armor Break, Schock) entsteht **nur aus E des passenden Elements** (gewichtet), nie aus N-E. Pro Status gibt es eine eigene Nebengravur (Burn, Nass, Bleed, Armor Break, Schock) mit dem passenden Element.
- Die Hauptgravur bestimmt die Art des Spells. Gems verfärben sich nicht; es gibt keine Resistenz und nur einen Schadenstyp. Power Transfer überträgt rohe N-E und E; das Hauptgem wendet seine Regeln (und seinen Elementfilter) an.
- **Tooltips:** Element- und Status-Wörter in Texten sind Begriffe (`CraftingContent.glossary`, Texte in `TERMS` im Generator mit `{wert}`-Platzhaltern aus `CombatRules`, Element-, Buff- und Debuff-Texte automatisch). Hovern zeigt den Tooltip, nach ca. 1 s ist er festgepinnt; Begriffe darin öffnen weitere Tooltips. Neue UI-Texte mit Begriffen: `tooltips.linkify()` und Label mit `tooltips.register()` anmelden.
- In der Werkstatt werden E-Punkte größer gezeichnet als N-E (`FocusCanvas.ELEMENT_DOT_SCALE`); doppelt zählende Punkte (Spitz) haben eine versetzte Schattenkopie, die Gem-Liste zeigt „Punkte für die Gravur“. Beim Darüberfahren (und Ziehen) zeigt ein Gem seine eingesammelten Punkte mit Linien und „Sammelt: …“.
- **Crit:** 1 Crit = 1 % Crit-Chance. Ein Crit macht 200 % Schaden (Auswirkung erst im Kampf, M6).
- **Speicherstände** liegen als JSON in `user://foci/` und enthalten nur IDs (`FocusInstance.to_dict()` / `from_dict()`). Unbekannte IDs werden beim Laden entfernt und gemeldet; fehlt ein Gem, wird der Kreis gelöst. **IDs von Gems, Gravuren, Foki und Elementen nicht leichtfertig umbenennen**, sonst gehen gespeicherte Gems verloren.
- **Hauptgravuren** (Element in Klammern): Magischer Bolzen (alle), Freeze (Wasser und Luft, 100 Nass → 1 Eis), Slow (Luft), Heal (Wasser), Schutz (Erde), Hasted (Luft), Leben-Reg (Wasser), Mana-Reg (Blitz), Feuerball (Feuer, Burn), Wasser-Detonation (Wasser, Nass), Luftklinge (Luft, Bleed), Kanone (Erde, Armor Break), Blitzschlag (Blitz, Schock). Dazu die Gravuren aus dem Spell-Paket (Abschnitt unten).
- **Nebengravuren:** Power Transfer (Übertragen, halber Radius, keins), Crit (Feuer), Mana-Reduktion (Wasser), Cast-Speed (Luft), Armor (Erde), Mana Burn (Blitz), Burn (Feuer), Nass (Wasser), Bleed (Luft), Armor Break (Erde), Schock (Blitz). Die sechs Status-Nebengravuren (inkl. Mana Burn) zählen keine N-E, 1 Status pro 5 Punkte.
- **Cast-Zeit** = 1 s pro Gem − `cast_time_reduction` (mind. 0,5 s). **Mana** = Kantenlänge × 0,1 − `mana_reduction` (mind. 1).
- **Foki** sind feste Typen (Start: **Winziger Fokus**, 20 neutrale Essenz + 5 Essenzen): Form (Kreis, Stern, Tropfen), Gem-Kapazität (winzig und klein 3, mittel 3–5, groß 5–7, sehr groß bis 10), **Gesamtkapazität** `max_dots` für N-E und E zusammen, ein **Limit für alle E zusammen** `max_element_dots` (nicht pro Element) und `allowed_elements` (z. B. Feuer-Fokus nur Feuer, neutraler Fokus 0 E). **N-E wird nicht eingestellt**, sondern füllt immer bis zur Gesamtkapazität auf (`FocusInstance.get_base_count()`). Upgrades durch den Spieler sind vorerst nicht vorgesehen.
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
| Perma-Burn | erzeugt pro Stack und Sekunde Burn, baut sich nicht ab, nur Cleanse entfernt ihn |
| Accelerated Burn | Burn tickt zusätzlich zur halben Sekunde, −1 Stack pro s |
| Bless | +X Heilung pro Stack bei jeder erhaltenen Heilung, −1 Stack pro Heilung |
| Thorns | X Gegenschaden pro Stack bei jedem erhaltenen Spell-Treffer, −1 Stack pro Treffer |
| Mana Absorption | +X Mana pro Stack bei jedem erhaltenen Spell-Treffer, −1 Stack pro Treffer |
| Damage Reduction | halbiert den nächsten gegnerischen Spell (alle Treffer), −1 Stack pro Spell |
| Life Rewind | speichert das Leben, nach 10 s wird es darauf gesetzt (auch nach unten); Tod ist Tod |
| Cleanse | Spell-Wert: entfernt alle Debuffs des Ziels (`Combat.DEBUFFS`) |
| Dispel | Spell-Wert (Stacks): pro Stack ein Buff des Ziels (`Combat.BUFFS`) mit allen Stacks, der mit den meisten Stacks zuerst |
| Mehrfach-Treffer | Spell-Wert `hits`: Schaden gilt pro Treffer, jeder Treffer würfelt Crit, löst Thorns/Mana Absorption aus |
| Critical Chance | +1 % Crit pro Stack auf eigene Spells, bleibt bis zum nächsten Crit (dann alle Stacks verbraucht) |
| Critical Damage | Spell-Wert `crit_damage`: + so viele Prozentpunkte auf den Crit-Schaden (kein Status) |
| Blood Thinner | Bleed tickt zusätzlich zur halben Sekunde, −1 Stack pro s |
| Cauterized | entsteht 1 : 1 aus Bleed + Burn, verhindert die nächste Heilung (auch Leben-Reg), −1 pro verhinderter Heilung |
| Max Health / Rotten | +X bzw. −X maximales Leben pro Stack (`CombatRules`); Max Health hebt nur das Maximum, bei Rotten sinkt das Leben mit; beide bauen sich nicht ab |
| Vampire | Spell-Wert `vampire`: Leben-Reg = Bleed-Stacks des Gegners × Wert |
| Echo | Spell-Wert `echo`: Spell wirkt sofort so oft erneut, Mana jedes Mal (löst Schock aus), keine Cast-Zeit; fehlt Mana, endet das Echo |

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
godot --path . res://tests/preview_snapshot.tscn --write-movie out.png --quit-after 4 --fixed-fps 30 -- [--focus=<id>] [--place] [--place-at=x,y] [--all-elements] [--tooltip] [--details] [--scroll] [--hover[=N]] [--replace] [--minor=<gravur-id>]
godot --path . --write-movie out.png --quit-after 3 --fixed-fps 30 -- --example
# Render-Check der Arena (Beispiel-Magier, nicht aus user://)
godot --path . res://tests/arena_snapshot.tscn --write-movie out.png --quit-after 4 --fixed-fps 30 -- [--seconds=N] [--stats]
```

## Konventionen im Code

- Beschreibungen nie von Hand pflegen: `ContentText.describe()` erzeugt sie aus den Werten; `EngravingDef.note` nur für Besonderheiten.
- Nach Werteänderungen zur Laufzeit `Balance.save()` (baut auch die Begriffe neu).
- Zahlen in Texten über `TextFormat.number()` (Dezimalkomma, keine unnötigen Nachkommastellen).
- Neue Status nur in `Status` eintragen (plus Begriff in `TERMS` im Generator); Arena, Bedingungen und Werkstatt lesen von dort.
- Neue Tests: Methode `test_*` in einer Datei unter `tests/suites/` (erbt `TestSuite`), keine Liste pflegen.
- Beschreibungen der Gravuren: kurzer Text im Generator; Ziel (Hauptgravur) und „Punkte: …“ hängt der Generator an.

## Arbeitsweise

- Der Nutzer ist Hobby-Entwickler und will Claude als technischen Partner und Game-Design-Berater: Ideen konstruktiv hinterfragen, Alternativen nennen, kein Overengineering.
- Design-Fragen als **Multiple Choice** stellen (AskUserQuestion), mit Empfehlung.
- **Commits nur nach ausdrücklicher Freigabe**, nie pushen ohne Nachfrage. Autor wie in den bisherigen Commits.
- Nach Änderungen die Tests ausführen. Bei UI-Änderungen zusätzlich ein Bild rendern und ansehen.

## Spell-Paket vom 2026-11-26 (Vorgabe des Nutzers, in Etappen)

Etappen 1 bis 5 und die Spells aus Paket 2 sind umgesetzt (Gravuren im Generator, Werte Platzhalter). Erledigt waren:

- **Etappe 3 – Hauptgravuren:** Meteor, Fire Rain (beide), Permanent Burn; Water Rain (beide), Cleanse, Bless, Life Rewind; Dispel, Thunderstorm (1 Treffer pro 50 Blitz-Punkte); Bulwark (ab 50 Erd-Punkte, viel Armor), Damage Reduction; Accelerated Burn (Luft + Feuer), Mana Absorption (Wasser + Erde).
- **Etappe 4 – Nebengravuren:** Echo (Spell erneut, Mana erneut, keine Cast-Zeit), Mana Efficiency / Quick Cast (Wasser + Luft, flache Werte), Radius Expansion (Erde, Radius des Hauptgems pro Erd-Punkt; braucht 2. Auswertungsdurchlauf), Thorns (Erde).
- **Etappe 5 – Multiplikator-Gravur:** neue Gem-Form (klein/mittel), Sektor wie andere Gems, äußerer Radius 0,8 × Größenradius mit ×1, innerer 0,3 × mit ×2.
- **Paket 2 (Nutzer, 2026-11-26) – Status:** Critical Chance (Buff, +1 % Crit pro Stack auf eigene Spells, **bleibt bis zum nächsten Crit**, dann verbraucht), Blood Thinner (Debuff, Bleed tickt doppelt so oft), Cauterized (Debuff, **entsteht 1 : 1 aus Bleed + Burn**: je 1 Bleed und 1 Burn werden zu 1 Cauterized; verhindert die nächste Heilung, 1 Stack pro Heilung), Max Health (Buff, +X maximales Leben pro Stack), Rotten (Debuff, −1 maximales Leben pro Stack).
- **Paket 2 – Hauptgravuren:** Critical Chance (Feuer), Blood Thinner (Wasser + Erde), Vampire (Wasser, Leben-Reg in Höhe der **Bleed-Stacks des Gegners**), Max Health (Wasser), Rot (Erde).
- **Paket 2 – Nebengravuren:** Cleanse (Wasser), Regeneration (Wasser, Leben-Reg), Dispel (Blitz), Critical Damage (Blitz, erhöht den Crit-Schaden des Spells direkt, kein Status), Slow (Luft, Slowed auf das Spellziel).
- **Paket 2 – Bedingungen:** Spieler/Gegner hat mehr oder weniger als X Stacks eines Status.
- **Paket 2 – danach (Reihenfolge: erst alle Spells):** Glossar-Seite (alle Foki, Gems, Gravuren, Status mit Werten), Gravur-Editor und Fokus-Editor (Werte im Spiel bearbeiten), fehlende Assets (Symbole) auflisten und einbauen.
- **Grundsatz:** Status- und Kampfwerte **flach**, nicht in Prozent (außer wo der Nutzer Prozent vorgibt, z. B. Damage Reduction 50 %).
- **Entschieden:** Dodge (Status und Hauptgravur) entfällt. Perma-Burn baut sich nicht ab (pro Stack und Sekunde 1 Burn), nur Cleanse entfernt ihn. Accelerated Burn = doppelte Tick-Frequenz (gleicher Gesamtschaden, halbe Zeit). Life Rewind: Tod ist Tod; nach 10 s wird das Leben auf den gespeicherten Wert gesetzt (auch nach unten).
- **Umsetzung:** Regel-Kurzform im Generator hat optional Mindestanzahl und Höchstwert (`ScalingRule.min_count`, `cap`). Nebengravuren dürfen feste Werte haben (`base_stats`, z. B. Cleanse). Radius Expansion: Stat `radius_bonus`, `SpellEvaluator` wertet dann ein zweites Mal mit größerem Hauptgem-Radius aus (`GemResult.radius_bonus`). Multiplikator (ID `multiplikator`): Gravur mit `inner_radius_factor` 0,3, Radius 0,8, überträgt wie Power Transfer, `max_size` mittel (Werkstatt sperrt Groß); `GemResult.dot_multiplier()` je Punkt. Bedingungen: „Selbst/Gegner hat mehr/weniger als X“ Stacks eines Status. Gleichnamige Haupt- und Nebengravuren haben getrennte IDs (`neben_cleanse`, `neben_dispel`, `status_slow`).
- **Noch zu entscheiden:** Echo-Schwelle (Platzhalter: 1 Wiederholung pro 100 Essenz-Punkte). Life Rewind wirkt erst ab 50 Wasser-Punkten und skaliert nicht. Neue Gravuren brauchen Symbole (Assets). Danach: Glossar-Seite, Editoren, Assets.

## Offene Punkte

- **Freeze:** 100 Nass → 1 Eis ist mit 1 Nass pro 10 Wasser-Punkte (= 2 Wasser-E) kaum erreichbar. Verhältnis im Balancing prüfen; Stun-Lock durch Eis vermeiden.
- **Kampf (M6) weiter:** Werte in `CombatRules` und der Spells balancen (Kämpfe werden über Mana-Engpässe entschieden, Status-Stacks aus Spells sind klein). Später: Gegner-Vorlagen, Spell-Bedingungen, Balancing-Werkzeug (viele Kämpfe simulieren).
- **Grafik (M4):** Stil, Referenzbilder und Assets vom Nutzer stehen noch aus. Ideen: HDR-2D-Glow, Shader für Linien und Sektoren, Partikel beim Einsammeln.
- **Ressourcen und Dungeons** über den Auto-Battler: erst später.
