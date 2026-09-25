# Plan: the Act 1 boss (Phase 3, step 6)

Status: **built** (Phase 3, step 6). Answers, notes, and balance findings are at the end.

**What the design asks for:**
- An act ends in a boss "with a unique mechanic".
- Bosses carry enemy-only items, and "some items are enemy-only, especially on bosses, which gives bosses their unique mechanics".
- A boss drops an item or a relic, and you then pick one of 3 stronger, game-altering relics.

Today day 6 is a placeholder (The Rift Throne: two Sentinels, a Hound, two Witches).

## The draft boss: Old Mother Ash (placeholder name)

The Ashen Hollow's first days are pups and hounds, so the boss is their mother: a huge rift-beast who fights **with her pack** and **gets worse as she's hurt**.

| When | What she does |
| --- | --- |
| **Start** | She stands in the **back row** behind two Rift Hounds. Each hound carries **Pack Bond** (an enemy-only charm): the whole pack, her included, gets ×1.5 DEF while that hound stands. Kill the hounds first, or bring back-row reach and push through the bond. |
| **Below 60% HP: Molt** | She sheds her ash hide and gets ×1.3 ATSP, and her bite now applies **Bleed**. |
| **Below 25% HP: Last Ember** | Every 3s she breathes embers on **every hero** (Burn), and gains a one-time shield. |

- **What it tests:** reach (back-row and all-enemy damage), sustained damage against her shield, and **cleansing** Burn and Bleed (Vell's Wardweaver, heals).
- **Length:** about 60–90s for a typical day-6 guild (2–4 heroes around rank B). She's tuned with the run bot.
- **Her drop:** one of the team's enemy-only items: **Pack Bond** (from a hound: a charm with an ally DEF aura while its holder stands) or **Ember Maw** (her bite as an auto-attack item that applies Bleed).

## What the sim needs

One new piece: **enemy phases.** An enemy can list phases, each entered once when it first drops below an HP threshold (checked with the other HP triggers: after firings, before deaths). A phase is made of the same **parts** as a specialization, so nothing else is new:

```json
"phases": [
  { "name": "Molt", "below_hp_bp": 6000, "parts": [
      {"key": "fury", "kind": "aura", "target": "holder", "stat": "atsp_bp", "value": 13000},
      {"key": "bleed", "kind": "grant", "filter": {"auto_attack": true}, "effect": {"trigger": "on_hit", "type": "apply_status", "status": "bleed", "stacks": 1, "target": "hit_target"}} ] },
  { "name": "Last Ember", "below_hp_bp": 2500, "parts": [
      {"key": "breath", "kind": "ability", "name": "Ember Breath", "cooldown_ms": 3000, "effects": [
        {"trigger": "on_fire", "type": "apply_status", "status": "burn", "stacks": 1, "target": "all_enemies"}]},
      {"key": "hide", "kind": "ability", "name": "Last Hide", "effects": [
        {"trigger": "on_fight_start", "type": "shield", "amount": 60, "target": "self"}]} ] }
]
```

- **How phases stack:** a phase's parts add to what the enemy already has. A part with the same key as an earlier phase's replaces it (as with locked potential).
- **Pack Bond ends on its own:** it's an ordinary item aura on the hounds, which stops when its holder falls.
- **Abilities that start with the phase:** an ability's `on_fight_start` effects run when its phase begins.
- **The log:** `[52.30s] mother_ash_1 enters Molt`, then everything the phase does is credited to it, e.g. `mother_ash_1 · Ember Breath (Last Ember)`.
- **Code:**
  - `EnemyDef.phases`, reusing `SpecializationDef.Part`
  - `UnitState` keeps its active phase parts
  - `CombatSim` checks thresholds once per tick and re-derives when one is crossed
- **Tests:**
  - a phase is entered once, at the right threshold
  - parts apply and replace by key
  - a phase's `on_fight_start` fires on entry
  - several phases crossed in one tick apply in order
  - the log lines are right
  - the determinism fight includes a phased enemy

## Content and balance

- **Data:** `mother_ash` goes in `data/enemies.json`, the two enemy-only items (Pack Bond, Ember Maw) in `data/items.json`, the boss's hounds carry Pack Bond, and the encounter `the_ash_mother` becomes `acts.json`'s boss (replacing The Rift Throne).
- **Balance:**
  - the balance runner gets a boss matchup
  - the run bot reports how often runs that reach day 6 win
  - target: a guild that reaches the boss wins about half the time

## Answers

1. **Old Mother Ash is fine for now;** we'll see how she feels.
2. **HP-threshold phases** are the shape for bosses.
3. **Summons wait** for a later fight or a later update to this one.
4. **Boss relics are Legendary relics.** They come only from winning a boss fight or from rare events at an event stop. So:
   - the boss's relic choice draws from Legendary relics only
   - Legendary relics never come from elites, Loot, the Vault, other events, or the relic merchant
   - a rare event, the Ancient Reliquary, offers one
   - drafting a few Legendary relics is part of this step

## Built notes

- **Code:**
  - `PhaseDef` (parts read with `SpecializationDef.read_part`)
  - `EnemyDef.phases` and `UnitSetup.phases`
  - `CombatSim._check_phases`, which runs after relics' HP triggers and before deaths
  - a new `LogEntry.Kind.PHASE`
- **Aura log lines** now remember each aura's source when it starts, so parts that change mid-fight (phases) still log their start and end correctly.
- **Data:**
  - the enemies `ash_hound` (a Rift Hound carrying Pack Bond) and `mother_ash`
  - the items `pack_bond` and `ember_maw` (both enemy-only)
  - the encounter `the_ash_mother` (Act 1's boss; the placeholder Rift Throne is gone)
  - 4 Legendary relics: The Ashen Crown, The Undying Lantern, The Everflame Hourglass, and The Rift-Eater's Fang
  - the rare Ancient Reliquary event (weight 1, against 5 for each other event)
  - Legendary weights set to 0 everywhere but the boss's relic choice
- **Her numbers:** 11000 HP, 50 ATK, 15 DEF. Ember Breath applies 8 Burn to every hero every 3s, and Last Hide is a 300 + DEF shield.

## Balance findings (placeholders)

- **The run bot** (`tools/run_runner.gd -- --runs=200 --seed=1`): 59 of 200 runs reach her, and **58% of those beat her** (1.15 boss fights each, counting a replay after a loss). 17% of runs clear the act.
- **The fixed balance parties** (four heroes at C or A, no relics) all lose to her now, in about 55s. By day 6, a bot run's guild is much stronger than those parties (more heroes, higher tiers, relics, infusions).
- **Tuning steps tried** (bot win rate against the boss): 2400 HP → 100%, 5000 → 97%, 7500 → 88%, 11000 → 58%.
