# Plan: the Act 1 boss (Phase 3, step 6)

Status: **proposed, awaiting approval and answers (end of file).** Nothing here is built yet.

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

## Questions

1. **The concept:** is Old Mother Ash and her pack the right kind of first boss? Or would you rather have something else, such as a lone colossus with no adds?
2. **Phases:** are HP-threshold phases the right shape for bosses in general?
3. **Summons:** should a boss be able to call **new** units mid-fight (say, a pup at each phase)? That's a bigger sim change (units joining a fight). I'd leave it for a later act unless you want it now.
4. **Boss relics:** the boss's relic choice currently draws from the general pool, weighted to Rare, Epic, and Legendary. Should I draft a few **boss-only** relics now (game-altering, only from boss choices), or leave that for the content step?
