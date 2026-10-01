# Loadout: tactics, gambits, sigils, and charms

Status: **agreed in discussion (2026-09-30); being built as phase 5c step 6** (`../rebuild-phase5c-combos.md`, section 14): the frame (ranks, counters, selling, prices), every charm, and every sigil built in 6a and 6b (2026-10-01); the tactics, the gambits, and the Magpie's stall to come. What a hero can slot, one file per kind. Replaces the first drafts in `../rebuild-content-pool.md` (part 7b, sections 3–5) and part 6's examples, and builds on part 6 (`../rebuild-between-fights.md`, sections 2 and 8); where they disagree, this folder wins, and part 6 carries notes saying so. **Numbers and names are placeholders** until the sim runner has had a pass at them.

| Kind | File | What it changes | Price | Ranks up |
| --- | --- | --- | --- | --- |
| **Tactic** | `tactics.md` | How the hero behaves, with a small payoff for following the order | 4 shards | Rank II after 60s of fighting while following it; rank III after 180s more |
| **Gambit** | `gambits.md` | A placement or fight-start rule | 12 shards | Rank II after using it in 3 fights; rank III after 6 more |
| **Sigil** | `sigils.md` | How the hero's signature fires | 8 shards | Rank II after 10 casts of the signature; rank III after 25 more |
| **Charm** | `charms.md` | A small change to the hero's kit (the Magpie sells them at rank II) | 6 shards | Rank II after 4 won fights with it equipped; rank III after 8 more |

## Rules for everything in a loadout

1. **Any hero can hold anything.** Nothing is locked to a hero or a path, and items are written against things every hero has ("your basic attack", "your signature").
2. **No warnings when something does nothing on a hero.** A sigil that needs mana on a hero without mana, or a charm that needs a hop, simply does nothing. Reading your hero and your items is on the player. (This drops the "no effect on this hero" marker from part 6, section 8.)
3. **Ranks:** every item has three ranks. **Rank II** makes the payoff bigger; **rank III** adds a twist. Each kind has one rank-up rule for all its items (table above), and **buying a copy of an item you own skips it to the next rank.**
4. **One gambit per hero.** A gambit takes one of the hero's loadout slots.
5. **No downsides** (the relic rule applies here too). Tactics give up some freedom by their nature; that's the order, not a penalty.
6. **Buffs raise ATK or MGK, not "damage"**; "damage" stays for bonuses tied to the target, hit multipliers, and effects scoped to one kind of attack. Every stat change states its amount.
7. **Swapping what's equipped between fights is free** (part 6).
8. **No item grants a path's key mechanic** (range, roots as a path's core, extra targets, taunts, leaps, surviving a would-be fall), so no deed fills without its vow, **and no item undoes a path's cost** (no mana bar for Last Watch, say). This was the graft rule; grafts are cut (`../magpie.md`). Extra targets means the basic attack's (Volley's): a signature that hits one more target (Wide, a sigil) is allowed (2026-09-30).
9. **Any shop buys items back** for half their price, whatever their rank. Relics sell only to the Magpie (`../magpie.md`).

## Decisions (2026-09-30)

These win over part 6 (`../rebuild-between-fights.md`) and phase 5's build plan (`../rebuild-phase5-run.md`) where they disagree; part 6 carries notes saying so.

| Topic | Decision |
| --- | --- |
| **The kinds** | Four: **tactics, gambits, sigils, charms**. Gambits are new (a placement or fight-start rule, one per hero) |
| **Grafts** | **Cut and merged into charms** (`../magpie.md`): Smoke Vial, Sidestep, Iron Skin, Spite Brand, Bloodletter, and Scavenger are charms now (marked * in `charms.md`). The graft frame and the "one exception to never an ability" rule go; the graft rule (no path's key mechanic, no undoing a path's cost) moves to every item (rule 8) |
| **Ranks** | Every item has three ranks. Each kind ranks up by one rule (the table above), counted in run state, and buying a copy of an item you own skips it to the next rank. Ranks reset with the run, so rule 5 of `CLAUDE.md` holds. (Heroes still have no ranks.) |
| **Prices** | Tactic 4, charm 6, sigil 8, gambit 12 (placeholders; every price and income is in `../economy.md`) |
| **No warnings** | An item that does nothing on its hero shows nothing. The built "no effect on this hero" marker, and the `needs` tags behind it, go |
| **Shops** | **No filtering:** a shop never checks what the team can use. Any shop buys items back for half their price (rule 9). The Magpie is a node with a fixed stall (`../magpie.md`), and the only place to sell a relic. The rest of the shops' setup is being changed (the playtester's, to come) |
| **Wide** | Its "+1 target" is allowed: rule 8's extra targets are the basic attack's (Volley's), and a signature reaching one more target doesn't fill Volley's deed |
| **The items already built** | Mapped into the pool or cut (below) |

## The items already built

Phase 5 built 10 charms, 4 tactics, 5 sigils, and 3 grafts (`data/items.json`, `../rebuild-phase5-run.md`, step 4). What becomes of each:

| Built | Kind | Decision |
| --- | --- | --- |
| **Casters first**, **Hold your ground**, **Wait to heal**, **Plant your feet** | tactic | **Kept**, with their ranks (`tactics.md`). Rank I matches what's built, except Plant your feet, which gains +10 DEF while stopped. Wait to heal stops being Vell's only (rule 1) |
| **Swift Boots** | charm | Becomes **Fleet** (charm) |
| **Thorned Mail** | charm | Becomes **Spiteful Blood** (charm) |
| **Ember Charm** | charm | Becomes **Ember-Tipped** (charm) |
| **Deep Well** | charm | Becomes **Opener** (sigil) |
| **Sigil of Haste** | sigil | Becomes **Thrift** |
| **Sigil of the Last Breath** | sigil | Becomes **Desperate** |
| **Sigil of Reach** | sigil | Becomes **Wide** |
| **Sigil of Echoes** | sigil | Becomes **Echo** (the built Echo piece, `AbilityDef.echo`, carries it) |
| **Frost-Tipped**, **Vital Stone**, **Whetstone**, **Serrated Edge**, **Mending Salve** | charm | **Cut** |
| **Iron Skin** | charm | **Cut as built** (+15% DEF); the name returns as a new charm from the grafts (the first hits taken each fight deal half damage) |
| **Sigil of Grief** | sigil | **Cut** (nothing else uses its trigger, `ally_falls`; the build plan decides whether the sim keeps it) |
| **Shake It Off**, **Second Wind** | graft | **Cut** (grafts are cut) |
| **Sidestep** | graft | Becomes the **Sidestep** charm, with a new rule (every 6s, a hit on you misses) |

## Art

Eight items already have their own glyph in the uploaded icons (`art/ui/items/glyphs/`): Braced, Fletched for Wings, Light Feet, and Purifying Light (charms), Casters first and Fliers first (tactics), and Echo and Opener (sigils). The rest share glyphs until more are drawn, as the built items do (`../rebuild-phase5b-art.md`, section 5). Gambits need a frame; the rose-octagon graft frame goes with grafts.

## Open questions

- **Rank-up numbers:** 60s/180s, 3/6 fights, 10/25 casts, and 4/8 wins are guesses.
- **Stacking with relics:** charms that add to a relic's lane (Leech Fang with Leech Tooth, Armor Breaker with Sunder) stack. Fine, or should charms stay out of relic lanes?
- **Shop mix:** how often the shop shows a gambit versus the others (waits on the new shop setup).
- **Gambits' frame:** the item language has a frame per kind (part 6, section 9); gambits need one.
- **What counts toward a rank:** "fighting while following the order" (tactics) and "using it in a fight" (gambits) need exact definitions, counted by the sim like deeds.
