# Plan: the synergy engine (Phase 3, step 2)

Status: **proposed, awaiting approval and answers (end of file).** Nothing here is built yet.

Design (docs/design.md, "Synergies"): five layers, from secret to visible.

| Layer | Condition | Shown |
| --- | --- | --- |
| Named pair | two specific items on the same hero | hidden until found |
| Essence transformation | a specific item + a specific essence | hidden until found |
| Signature gear | a specific item on a specific hero | hinted as "???" |
| Essence resonance | 3 / 5 / 7 of one essence socketed team-wide | always |
| Class trait | 2+ heroes of a class fielded | always |

## How it works

- **When:** synergies are checked **once, at fight start**. Nothing a synergy looks at (items, essences, heroes, classes) changes during a fight. A synergy stays on for the whole fight, even if its hero falls; a fallen hero's items just stop firing.
- **What a synergy does:** it reuses the relic blocks, **auras, grants, and relic-trigger effects**. A synergy is really a relic that switches on when its condition holds. A transformation also **replaces its item's effects** (below).
- **Scope:**
  - Resonances and class traits act side-wide, like relics: `all_items` and `all_allies`, with filters.
  - Pairs, signatures, and transformations act on **the items that matched** (a new aura target and grant scope, `matched_items`) and the **hero who holds them** (`holder`).
- **The log names the synergy** (CLAUDE.md rule 4):
  - At fight start: `[0.00s] Paper Cuts: wren · Whetstone + Twin Daggers`.
  - Its auras and grants are credited the way a relic's are: `wren · Twin Daggers (Paper Cuts) ...` and `synergy · Frost Resonance (5) aura starts ...`.
- **Discovery:** the sim doesn't know the Codex. Each `FightResult` lists the synergies that were active and where. The run layer (step 4) records discoveries, and the UI shows the "discovered!" banner the first time. The shop sparks come with the Caravan.

## Each layer

### Named pairs

```json
{ "id": "paper_cuts", "name": "Paper Cuts", "layer": "pair", "items": ["whetstone", "twin_daggers"],
  "grants": [ { "filter": {"item": "twin_daggers"},
                "effect": {"trigger": "on_hit", "type": "charge", "amount_ms": 200, "target": "partner_items"} } ] }
```

- **Matching:** both items in the same hero's row, at any tier.
  - A hero holding two copies of one half still makes only one pair; it matches the leftmost copy of each half.
  - Two heroes can each have the pair.
- **New effect type, `charge`** (the design's Paper Cuts needs it; nothing existing can move another item's cooldown). It advances target items' cooldowns by `amount_ms`. Item targets:
  - `self_item`, `left_item`, `right_item`, `adjacent_items`, `row_items`
  - `partner_items`: the other items that matched this synergy

  It's logged like any effect (`wren · Twin Daggers (Paper Cuts) charges Whetstone by 0.20s`). It's also useful for plain items later.

### Essence transformations

```json
{ "id": "wildfire_torch", "name": "Wildfire Torch", "layer": "transformation", "item": "tallow_torch", "essence": "ember",
  "effects": [ {"trigger": "on_fire", "type": "apply_status", "status": "burn", "stacks": 1, "target": "all_enemies"} ] }
```

- **Matching:** the item has the essence socketed.
- **The transformation replaces the item's own effects** with its `effects` list. Those effects are numbered like the item's own: base + stat scaling, tier, and auras.
- **The essence's normal effect and conversion don't apply** on that item. The essence *is* the transformation.
- **It never spills,** even at Resonant.
- **It still counts** as its essence for resonance.
- **XP and levels:** the infusion still gains XP and levels up. Attuned and Resonant make the transformation ×1.5 and ×2, like any infusion.

### Signature gear

```json
{ "id": "vells_lantern", "name": "Lantern of Mercy", "layer": "signature", "hero": "vell", "item": "old_lantern",
  "grants": [ { "effect": {"trigger": "on_fire", "type": "shield", "amount": 8, "target": "ally_lowest_hp"} } ] }
```

- **Matching:** that hero has that item in their row.
- **Draft change:** the design's example ("lantern heals also cleanse") needs a cleanse effect that doesn't exist yet. The drafts use existing effects until one's needed.

### Essence resonance

```json
{ "id": "frost_resonance", "name": "Frost Resonance", "layer": "resonance", "essence": "frost",
  "tiers": [
    {"count": 3, "auras": [ {"target": "all_items", "filter": {"essence": "frost"}, "stat": "damage_bp", "value": 11500} ]},
    {"count": 5, "auras": [ ... ]},
    {"count": 7, "auras": [ ... ]} ] }
```

- **Counting essences:** a single counts 1, an alloy 1 of each half, a pure double 2, and a transformation counts its socketed essence(s).
- **Tiers:** only the highest tier reached applies, so each tier's entry is the whole bonus.

### Class traits

```json
{ "id": "warden_trait", "name": "Wardens", "layer": "class_trait", "class": "warden",
  "tiers": [ {"count": 2, "auras": [ {"target": "all_allies", "filter": {"row": "front"}, "stat": "shield_bp", "value": 11500} ]} ] }
```

- **Matching:** fielded heroes of that class. Only the highest tier reached applies.

## Code shape

- **Definitions:** `src/sim/defs/synergy_def.gd`, one class with its layer and condition, plus auras, grants, effects, and (for transformations) replacement effects. It also has tiers for resonance and class traits.
- **Matching:** `src/sim/synergies.gd`, with `find_active(sim) -> Array[ActiveSynergy]`. It runs in `CombatSim._init` before the first `rederive_all`. Each active synergy records the synergy, the tier, the holder, and the matched items.
- **Applying:** `rederive_all` applies active synergies' auras and grants exactly as it does relics' (the same code path, now shared). `RelicRunner` runs their triggered effects. A transformation is applied in `ItemState.derive`.
- **Results:** a new `LogEntry.Kind.SYNERGY`, and `FightResult.synergies`.
- **Data:** `data/synergies.json`, loaded and checked by `ContentDb`: items, heroes, essences, and classes exist; tiers go up; each layer has the right fields.

## Draft content (placeholders)

About 20, a few of each (the full slice set comes with the content step):
- **Pairs (3):** Paper Cuts (new items Whetstone + Twin Daggers), plus two from existing items (e.g. Hearth Banner + Hearth Stew, Bell of Vigil + Oak Buckler).
- **Transformations (2):** Tallow Torch + Ember (Burn spreads to every enemy), Oak Buckler + Stone (the buckler shields the whole row).
- **Signatures (4):** one per current hero, e.g. Vell + Old Lantern, Brannoc + Oak Buckler, Wren + First-Light Dagger, Odo + Dusk Tome.
- **Resonances (8):** one per essence, with 3 / 5 / 7 tiers.
- **Class traits (4):** Warden, Striker, Mender, Arcanist, at 2 (and 3) heroes.

## Tests

- **Data:** each layer's required fields, unknown references, tiers in order, and `charge` targets.
- **Matching:** a pair needs both items on the *same* hero; a signature needs the right hero; a transformation needs the essence; resonance counts singles, alloys, pure doubles, and transformations correctly; only the highest tier applies; class traits count fielded heroes.
- **Effects:**
  - pair and signature grants reach only matched items
  - `charge` moves a partner's cooldown and never crosses heroes
  - a transformation replaces the item's effects, drops the essence's own effect, never spills, and still counts for resonance
- **Log and results:** synergy log lines and sources, and `FightResult.synergies`.
- **Determinism:** the determinism fight includes a pair, a transformation, a resonance, and a class trait.
- **Balance:** the balance runner reports which synergies were active.

## Questions

1. **Who counts for resonance:** only fielded heroes' items, or backup heroes' too? (I'd count both, since they're all the guild's essences.)
2. **Enemies and synergies:** do enemy teams get resonances and class traits too? I'd say **heroes only** for now, with enemy combos done through their relics and enemy-only items, like your Witch Coven idea.
3. **Class trait tiers:** with 1–5 fielded and six classes, are **2 and 3** heroes the right tiers? (Resonance stays 3 / 5 / 7.)
4. **Transformations on 2-socket items:** say an item has Frost + Ember and a Frost transformation.
   - My draft: the transformation takes the Frost, Ember works as a plain single, and there's no alloy special.
   - For a pure double (Frost + Frost), the transformation applies once, the double still counts 2 for resonance, and there's no pure-double bonus.

   Does that sound right?
5. **The new `charge` effect** (advance another item's cooldown): OK to add? Paper Cuts needs it, and it'll be handy for items later.
