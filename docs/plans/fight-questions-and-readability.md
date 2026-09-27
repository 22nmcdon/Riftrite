# Plan: fight questions and readability (redesign step 6)

Step 6 of `docs/plans/fun-redesign.md`: sections 7 and 8. The user's answers are under **Decisions** at the end.

**Why:** today the player sees only the current day's fights, the elites and the boss don't say what they do, the start gives no direction, and the fight screen is a wall of log text where the big moments (boss phases, Awakening) are only log lines.

## 1. The whole act on the day bar (the user's answer)

- **Every fight in the act is shown from day 1:** each day's two fights (easier and harder), the two elites on days 3 and 6, and the boss on day 8.
- **Their own icons:** normal fights, elites, and the boss each get a different icon, so the threats stand out on the bar.
- **Hover for details:** hovering an elite or the boss shows its enemies, the essence it yields, and its **mechanic** (section 2). Hovering a normal fight shows its enemies and essence.
- **The code already allows it:** a day's fights come from the run seed, the act, and the day (`RunFlow._pick_fights`), never from earlier picks. That becomes a public `RunFlow.fights_for_day(state, run, day)` the day bar can call for any day. A replayed day keeps its fights, as now.

## 2. Each elite and the boss asks a question

Each elite and boss encounter gets a `"mechanic"` in `data/encounters.json`: a name, one line on what it does, and one line on what answers it. It's presentation text only. What the enemies actually do stays in their items, relics, and phases, which already exist. The validator requires a mechanic on every elite and boss encounter.

| Encounter | Mechanic | What it does | What answers it |
| --- | --- | --- | --- |
| The Hound Alpha | **The Hunt** (new) | A new Hound Alpha leads the pack. Its bite always goes for your weakest hero (lowest HP %), and below half HP it frenzies and bites 40% faster. | Shield or heal your weakest hero; burst the Alpha before it frenzies. |
| Cairn Watch | **Stone Ward** | The Cairn Guardian shields its whole side every 5 seconds, and the archers shoot your back row. | Poison goes around Shield; Burn is halved against it. Protect your back row. |
| Witch Coven | **Gloam Totem** | The witches in the back row cast 20% stronger, and the Sentinel in front heals as it bites. | Reach the back row, or wash away their damage over time. |
| Old Mother Ash | **Molt, then Last Ember** | Below 60% HP she bites faster and her bites Bleed. Below 25% she hardens with Shield and breathes Burn on everyone every 3 seconds. | Burst through her last quarter; heal and cleanse against the Burn. |

- **The Hound Alpha is new content** made from existing building blocks: an enemy with an ability aimed at `enemy_lowest_hp` and an HP-threshold phase (`PhaseDef`) that speeds it up. It replaces one of the two Rift Hounds. No new effect type.
- **The other three** already do what the table says; they only get the text.
- **Where the mechanic shows:** the day bar hover (section 1), the fight-choice card, and the enemy preview before the fight.

## 3. Start kits replace the item package (the user's answer)

- **The start offers:** gold (as now), a common relic (as now), and **two kits** in place of the random item.
- **A kit** is a common item at tier C that comes **already infused** with an essence that suits it, so the first shop has a purpose. For example, a Burn kit could be a Burn item infused with Ember.
- **Kits follow the team:** there's a kit per keyword (8, in `data/economy.json`), and the two offered match affinities of the drafted heroes, picked by the run seed (`RunRandom`).
- **Kit contents** are content, built directly and reviewed in the PR:

  | Keyword | Kit | Item | Essence |
  | --- | --- | --- | --- |
  | Blade | Woodcutter's Kit | Hatchet | Wrath |
  | Bow | Flint Quiver | Flint Arrows | Wrath |
  | Spell | Storm Slate | Slate Tablet | Storm |
  | Mend | Herbalist's Satchel | Peat Poultice | Verdant |
  | Ward | Stonewarden's Kit | Oak Buckler | Stone |
  | Burn | Tinder Box | Tallow Torch | Ember |
  | Bleed | Barbed Bundle | Barbed Net (Uncommon: no Common has Bleed) | Umbral |
  | Hex | Frostsoot Pouch | Soot Bomb | Frost |

  Each essence is one its merchant pairs with that keyword. If the team has fewer than two affinities with a kit, other kits fill in (no hero has that problem now).

## 4. Readability

- **The combat log is hidden by default,** one click away (a "Log" button opens the side panel). The log rule in `CLAUDE.md` is unchanged: every effect still writes to it.
- **Banners at the moment they happen,** in the middle of the arena, one at a time (about 1.5s each, queued):
  - a boss or elite enters a phase ("Old Mother Ash: Last Ember")
  - an infusion reaches Resonant or awakens ("Ember + Storm awakens: Plasma")
  - a deed level ("✦ Wren: Opening Wounds")
  - a synergy triggers for the first time in a run ("✦ Synergy discovered: Ash and Ink")

  Today the synergy banner shows from the start of the fight, and phases and Awakening are log lines only. The banners read the log entries the fight player is already playing back, so the sim doesn't change.
- **Fight speed starts at 1x, and a speed you change is remembered** (the user's answer). It's saved in the player's settings (`user://settings.json`), not in the run, so it never touches the sim.

## 5. The fight chart (the user's addition)

Opening the log panel during a fight shows a chart of what each hero is doing, above the log text. It updates live as the fight plays back.

- **Three tabs:** **Damage**, **Healing and Shield**, and **Damage taken**.
- **One bar per hero,** sorted from most to least, each split into colored segments by type:

  | Tab | Segments |
  | --- | --- |
  | Damage | Basic attack, Abilities, then each status that dealt damage (Burn, Poison, Bleed, ...) |
  | Healing and Shield | Healing, Shield |
  | Damage taken | To HP, absorbed by Shield; hits and each status shown in the breakdown |

- **Hovering a hero's bar shows a breakdown by source:** each item (with its infusion), each status, and each innate, deed, duo bond, or synergy, with its amount and share. On the Damage taken tab, the sources are the enemies and their items.
- **Relics:** a relic's damage, healing, or Shield belongs to the team, not a hero, so it gets its own "Relics" bar.
- **Where the numbers come from:** the combat log entries played so far (damage, status damage, healing, Shield, and Rift Collapse). Status damage counts for whoever applied it, the same rule as deeds and kills. It's UI only; the sim doesn't change.

## 6. Code

- **Run layer:**
  - `RunFlow.fights_for_day` (any day's fights, from the seed, the act, and the day)
  - start kits in `RunFlow` (`_pick_kits`, the kit package) and `EconomyDef.kits`; `RunContent` checks them
  - `RunFlow.pick_start_hero` now takes the run content (the draft's end offers the kits)
  - the run bot takes a kit
- **Sim data:** `EncounterDef` reads the `"mechanic"` (required on elites and the boss).
- **Data:**
  - the mechanics of the four elite and boss encounters
  - the Hound Alpha (`data/enemies.json`), its bite (`alphas_bite`, enemy-only), and their art
  - the 8 kits (`data/economy.json`)
- **UI:**
  - `EncounterInfo` (new): mechanic text and boxes, a day's hover text
  - `day_bar.gd`: the act's days, three icon kinds, hover details
  - `fight_choice_screen.gd` and the fight screen's enemy preview: the mechanic
  - `run_start_screen.gd`: the kit cards
  - `fight_screen.gd`: the hidden log panel (Log, L), the chart, the banners, the remembered speed
  - `FightTally` (new, `src/ui/fight_tally.gd`): adds up the log entries played so far, by hero, type, and source
  - `FightChart` (new widget): tabs, legend, stacked bars, hover breakdowns. The type colors were checked with the dataviz palette validator as neighbors in a stack on the panel color; the gaps between segments, the legend, and the hover back them up.
  - `FightBanners` (new widget): the banner queue
  - `RunSession.fight_speed`, `set_fight_speed`, `load_settings` (`user://settings.json`)
- **Tests:**
  - every day's fights are known from the start and match what the day offers; other seeds plan other fights
  - kits follow the team's affinities, top up from other keywords, and give an infused item; kit data is checked
  - every elite and boss has a mechanic, and the check refuses one without
  - the Hound Alpha hunts the weakest and frenzies in a real fight
  - the tally credits each entry to the right hero, type, and source (status damage to its applier, relics to their own bar, a real fight matching the damage meter)
  - the chart's bars, legend, tabs, hover text, and in-place updates
  - banner texts and the queue; a new synergy's banner at the start
  - the hidden log, the remembered and saved speed, the day bar's act, the fight cards' mechanics, the kit cards

## Balance

## Decisions (from the user, 2026-09-27)

- **Lookahead:** the day bar shows every fight in the act. Elites and the boss have their own icons, different from normal fights, and hovering them shows the elite and boss details.
- **Start kits:** themed kits replace the random-item package.
- **Fight speed:** 1x by default; a speed the player changes is remembered.
- **The mechanics, the kits, and the banners:** fine as proposed, for now.
- **The fight chart** (section 5): the user's addition. Damage by type per hero, a breakdown on hover, and tabs for Healing and Shield and for Damage taken.
- **Snowball rules:** still open (the user is looking at examples).
