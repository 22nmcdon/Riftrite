# Plan: fight questions and readability (redesign step 6)

Step 6 of `docs/plans/fun-redesign.md`: sections 7 and 8. The user's answers so far are under **Decisions** at the end; the rest is proposed and waits for approval.

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
- **Kit contents** are content, built directly and reviewed in the PR.

## 4. Readability

- **The combat log is hidden by default,** one click away (a "Log" button opens the side panel). The log rule in `CLAUDE.md` is unchanged: every effect still writes to it.
- **Banners at the moment they happen,** in the middle of the arena, one at a time (about 1.5s each, queued):
  - a boss or elite enters a phase ("Old Mother Ash: Last Ember")
  - an infusion reaches Resonant or awakens ("Ember + Storm awakens: Plasma")
  - a deed level ("✦ Wren: Opening Wounds")
  - a synergy triggers for the first time in a run ("✦ Synergy discovered: Ash and Ink")

  Today the synergy banner shows from the start of the fight, and phases and Awakening are log lines only. The banners read the log entries the fight player is already playing back, so the sim doesn't change.
- **Fight speed starts at 1x, and a speed you change is remembered** (the user's answer). It's saved in the player's settings (`user://settings.json`), not in the run, so it never touches the sim.

## 5. Code

- **Run layer:** `RunFlow.fights_for_day`; start kits in `RunFlow` (the start offers) and `data/economy.json` (the kit list); the validator checks kits and encounter mechanics.
- **Data:** `"mechanic"` on elite and boss encounters; the Hound Alpha enemy, its items, and its phase; the 8 kits.
- **UI:**
  - `day_bar.gd`: every day's fights, three icon kinds, hover details
  - `fight_choice_screen.gd` and the fight screen's enemy preview: the mechanic
  - `fight_screen.gd`: the hidden log, the banner queue
  - `fight_player.gd`: the remembered speed
  - `run_start_screen.gd`: the kits
- **Tests:** fights for any day match the fights that day actually offers (also after a lost fight); kit offers follow the team and are deterministic; picking a kit gives an infused item; every elite and boss has a mechanic; the Hound Alpha targets the weakest hero and enters its phase; the banner queue picks the right log entries; the speed setting is remembered. Then mutation checks, the balance sim on the Hound Alpha, and the run bot.

## Balance

The Hound Alpha makes the day-3 elite harder, so its numbers are tuned against the run bot's targets (elites about 30% lost). The kits make the start a bit stronger; the run bot shows by how much.

## Open questions

- **The mechanics in section 2:** is this list right, and is the new Hound Alpha fine?
- **Kits:** two kits from the team's affinities next to gold and a relic, and the item comes infused? Or a different shape?
- **Banners:** is the list in section 4 right, or too many?

## Decisions (from the user, 2026-09-27)

- **Lookahead:** the day bar shows every fight in the act. Elites and the boss have their own icons, different from normal fights, and hovering them shows the elite and boss details.
- **Start kits:** themed kits replace the random-item package.
- **Fight speed:** 1x by default; a speed the player changes is remembered.
- **Snowball rules:** still open (the user is looking at examples).
