# Plan: the infusion rework (redesign step 2)

Step 2 of `docs/plans/fun-redesign.md` (section 5, and the infusion decisions at its end). Neighbor spill went away with item rows in step 1. This step replaces it.

## Rules

**Fusing.** Every item holds one infusion of up to **2 essences**. The Epic/Legendary-only second socket (`two_socket_rarities`) is removed.
- A second essence fuses with the first: two different essences make their alloy, two of the same make a pure double.
- There's no third essence. The order doesn't matter.
- Fusing resets XP, and reforging removes the whole infusion (both as before).

**Keywords.** Every guild and enemy item carries 1–3 **keywords** (`"keywords"` in `data/items.json`, defined in `data/keywords.json`). They're shown on items. The old `tags` stay, because relic and specialization filters use them. Step 5 builds affinities and duo bonds on the same keywords.

| Keyword | Goes on |
|---|---|
| Blade | melee items |
| Bow | ranged items |
| Spell | magic items |
| Mend | healing items |
| Ward | defense and shield items |
| Burn | items that apply Burn |
| Bleed | items that apply Bleed |
| Hex | items that apply Poison, Slow, Blind, or Freeze |

A few items fit none of these; they get hand-picked keywords.

**Keyword spill (singles).** A Resonant **single** spreads a share of its effect (`spill_single_bp`, 30%) to the holder's other items that **share a keyword** with it.
- The spill carries everything the essence does: its conversion, its extra effects (Frost's Slow), and its stat changes (Storm's cooldown).
- Each item gets **at most one spill per essence**, even when two Resonant singles of that essence match it.
- The spill stays in the holder's loadout. The built-in basic attack and slotless abilities have no keywords, so they never receive it.

**Awakening (alloys and pure doubles).** Before Resonant, an alloy or pure double gives both essences' normal effects and nothing more. **At Resonant it awakens: its special switches on** (Inferno's Golden Flame, Plasma, Bloom's heal echo, and so on). Alloys and pure doubles never spill. The essence pairs without a named alloy have nothing to awaken into yet.

**Transformations** never spill and never awaken (unchanged).

**Passives can be infused.** What an infusion does on a passive is decided in step 5. Until then the normal rules apply: a passive earns only battle XP (it never fires), its essences add nothing to it, and a Resonant single on a passive spills by keyword like any other item.

## Data

- `data/keywords.json` (new): `[{"id": "blade", "name": "Blade", "text": "..."}]`.
- `data/items.json`: `"keywords"` on every item.
- `data/tuning.json`: removes `two_socket_rarities`, `spill_alloy_bp`, and `spill_pure_double_bp`. Keeps `spill_single_bp`.
- `data/alloys.json`: same shape. Each special now describes what the alloy does once awakened.

## Code

- `src/sim/defs/keyword_def.gd` (new), loaded by `ContentDb`. `ItemDef` reads `keywords`, and the content check refuses unknown ones.
- `Infusions.MAX_ESSENCES = 2` replaces `TuningDef.socket_count`.
- `ItemState`:
  - `awakened()` gates the alloy's `replaces` and `heal_echo_bp`.
  - `keyword_spill()` replaces `spill_to(side)`.
- `UnitState.rederive_items` hands each item its keyword spills, in loadout order, at most one per essence.
- The level-up log says "awakens" when an alloy reaches Resonant.
- `RunActions.infuse` and `RunState.check` use the 2-essence limit.
- UI:
  - Spill arrows are removed.
  - Items show their keywords.
  - The tooltip says what a Resonant single spills and to which keywords, what an alloy awakens into, and which spills an equipped item receives.

## Tests

Fusing (any rarity, no third), keyword matching, one spill per essence, the basic attack gets no spill, only Resonant singles spill, alloys awaken only at Resonant and never spill, transformations do neither, and passives can be infused. Plus the rewritten alloy and socket tests, mutation checks, the data validator, and the run bot.

## Decisions (from the user)

- The 8 keywords above: "that works for now".
- Awakening: an alloy's special switches on at Resonant (the first option).
- Passives can be infused; their infusion effects will differ, decided in step 5.
- Spill arrows are removed.
