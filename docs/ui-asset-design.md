# UI Asset Design: Riftrite (working title)

> Status: v0.2, adopted as the UI's reference **for now** (it will probably be replaced later). v0.1 was written before some game decisions were made; v0.2 fixes the parts that disagreed with `docs/design.md` and `CLAUDE.md`, marked **(Fixed)**. Where this doc and the game design disagree, the game design wins: raise it and fix this doc.
>
> **Decided (September 2026):**
> - The UI stays at **1920×1080** with smooth (non-pixel) placeholder art drawn in code. The pixel-art resolution below is not used for now.
> - Relics are **hex tokens in a row** that grows, with no sockets.
> - Fights show **heroes at the bottom and enemies at the top**.
> - The spill rules are the game's (section 8.3).
>
> What's built from this doc so far: `docs/plans/first-ui.md`, "Asset design pass".

---

## 1. Design Pillars

1. **Cozy hearth, grim rift.** The guild hall is warm, lamplit, and lived-in. The rift is cold, cracked, and hungry. UI chrome lives in the cozy world (wood, brass, parchment, stitched cloth); anything touched by the rift bleeds into the grim (cracks, violet-black ink, glowing seams).
2. **Readable at a glance during auto-battle.** The player watches, not clicks. HP, cooldowns, and triggers must be legible without reading numbers.
3. **Items are the star.** Item icons are the largest, most detailed assets. Frames and chrome stay quiet so icons carry rarity, essence, and synergy.
4. **Movement must feel physical.** Items and relics are objects you pick up and place. Every draggable has a pickup, hover, snap, and reject state.
5. **One shape language.** Rounded-square "tokens" for items, hexagonal tokens for relics, gems for essences. Shape tells you category before color does. **(Fixed)** Relics have no sockets or board (see 8.2).

---

## 2. Art Direction

**Style (decided for now):** smooth art at 1920×1080, drawn in code as placeholders until real art is made. v0.1 recommended hand-painted pixel art at a small base resolution; revisit that when real art starts.

| Aspect | Cozy layer (chrome, hub, shop) | Grim layer (battle, rift, enemy-only things) |
|---|---|---|
| Materials | Oak, brass, felt, parchment, stitched leather | Slate, cracked obsidian, rusted iron, bone |
| Light | Warm amber, soft glow | Cold teal-violet, hard rim light |
| Edges | Rounded, slightly wobbly | Angular, chipped, fractured |
| Motion | Gentle ease, small bounces | Snappy, heavy hits, screen shake |
| Texture | Cloth weave, paper grain | Cracks, ash, scratches |

**Rift bleed rule:** the more a thing belongs to the rift, the more its frame shows violet cracks and the less brass it has. **(Fixed)** There are no cursed items. The rift bleed marks **enemy-only items** (even when the guild holds them), **elite** and **boss** fights and units, and **Legendary boss relics**.

---

## 3. Color System

### Core palette

| Token | Hex | Use |
|---|---|---|
| `ink-900` | `#14101A` | Deepest background, outlines |
| `ink-700` | `#2A2233` | Panels in battle |
| `oak-600` | `#5B3A29` | Cozy panel base |
| `oak-400` | `#8A5A3C` | Panel highlight |
| `parchment-100` | `#F1E6CC` | Text panels, tooltips |
| `parchment-300` | `#D9C79E` | Secondary text panel |
| `brass-500` | `#C9993B` | Frames, buttons, gold accents |
| `brass-300` | `#E8C877` | Highlights, hover |
| `ember-500` | `#E0703A` | Primary action, damage numbers |
| `moss-500` | `#6E9A5A` | Heal, positive, success |
| `rift-500` | `#7A4FD1` | Rift / corruption / drawback |
| `rift-300` | `#B79CF0` | Rift glow, rift-touched text |
| `frost-400` | `#5FB4C9` | Shield, cold, neutral info |
| `blood-500` | `#B33A3A` | HP loss, danger, enemy |

### Rarity ladder (frame color plus a non-color cue)

| Tier | Frame | Extra cue (colorblind-safe) |
|---|---|---|
| Common | Bare oak | No ornament |
| Uncommon | Brass edge | Two corner rivets |
| Rare | Silver-teal edge | Four corner rivets |
| Epic | Violet edge | Rivets plus top crest |
| Legendary | Gold edge, animated shimmer | Rivets, crest, and side wings |

### Essence colors (gem-shaped, distinct hue and distinct glyph)

Each essence gets a hue **and** a glyph so they can be told apart without color. **(Fixed)** These are the game's 8 essences (`data/essences.json`), not v0.1's placeholders.

| Essence | Hue | Glyph |
|---|---|---|
| Ember | `#E0703A` | Flame |
| Venom | `#7ED14F` | Droplet |
| Wrath | `#D14545` | Three claw slashes |
| Stone | `#A8906C` | Square block |
| Verdant | `#6E9A5A` | Leaf |
| Frost | `#5FB4C9` | Snowflake |
| Storm | `#E8C877` | Lightning bolt |
| Umbral | `#7A4FD1` | Crescent |

---

## 4. Typography

| Role | Face (suggested, free) | Size (at 1x) | Notes |
|---|---|---|---|
| Title / logo | Custom hand-lettered | n/a | Commission or draw last; name is undecided |
| Headings | Pixel serif such as *Alagard* or *m6x11* | 16 / 24 | Warm, slightly medieval |
| Body / tooltips | *m5x7* or *Silkscreen* alternative | 8 / 10 | Must stay crisp at 1x and 2x |
| Numbers (damage, HP, gold) | Bold pixel numerals with 1px dark outline | 8 / 12 / 16 | Outline is required for legibility over battle FX |

Rules: keep body text above 8px at 1x; never place body text directly on a busy icon; damage numbers always get an outline and a drop shadow.

---

## 5. Grid, Scale, and Layout

- **Base resolution:** **1920×1080 for now (decided)**, scaled to the window. The pixel sizes below are v0.1's 480×270 numbers; multiply by 4 at 1920×1080.
- **Item cell (Fixed):** items are 1 to 3 slots wide by size (Small, Medium, Large), so an item token is as wide as its slots.
- **Relic token (Fixed):** a 28x28 px icon on a 40x36 hex token (no socket).
- **Essence gem:** 8x8 (in-slot pip), 16x16 (tooltip/inventory), 32x32 (shop).
- **Safe margin:** 8 px on all edges; keep critical info out of the outer 4 px.
- **Panel nine-slice:** every panel is a nine-slice with a 6 px border so any size can be built without new art.

---

## 6. Screen Inventory and Layout Sketches

### 6.1 Guild Hub (between runs; the Guildhall, not built yet)

A cozy single-room view: guild hall interior with clickable stations (recruitment board, armory chest, rift gate, trophy wall, options).

- Background: layered parallax room, 3 layers plus foreground props.
- Station hotspots have a hover outline and a small floating label on a parchment tag.
- The rift gate is the only grim element: violet cracks and a slow pulse.

### 6.2 The day (Fixed: no Rift Map)

There's no branching map. Each act is a set number of days, and each day is **Caravan → a stop → one fight** (`docs/plans/day-structure.md`).

- **The day bar** shows the act, the day (for example "Day 3 of 6"), the day's steps with the current one lit, losses left, gold, keys, and today's fight (with its kind and the essence it yields). The thread-and-lantern look from v0.1's map can dress the day bar: a stitched thread through the day's steps, with a lantern on the current step.
- **Stop cards:** the stop choice offers 3 of these stops: Forge, Loot, Vault, Retrain, Event, and Upgrade (the anvil before the boss). Each card gets a stop icon (section 10).
- **Fight kinds:** normal, elite (rift bleed), and boss (full rift bleed).

### 6.3 Battle Screen (main auto-battler view)

**(Fixed)** Heroes are at the bottom and enemies at the top, each side in a front and a back row, with the two front rows facing each other in the middle. The log sits beside the field. Relics show as hex tokens in the guild panel (between fights), not on a board.

```
+--------------------------------------------------+---------------+
| Day bar: Act · Day 3 of 6 · Caravan › Stop › [Fight] · Gold · Seed |
+--------------------------------------------------+---------------+
|   ENEMY BACK ROW     [E3] [E4]                   | [Pause] 0.5x  |
|   ENEMY FRONT ROW    [E1] [E2]                   | 1x 2x 4x Skip |
|   ------------------ (the front rows meet) ----- |               |
|   YOUR FRONT ROW     [Hero1] [Hero2]             | COMBAT LOG    |
|   YOUR BACK ROW      [Hero3]                     | (names, sides |
|   IN BACKUP          [Hero4]                     |  colored)     |
|  each card: portrait, HP bar + shield + ghost,   |               |
|  status pips, item tray with cooldown sweeps     |               |
+--------------------------------------------------+---------------+
```

- Item cooldowns shown as a radial sweep over the icon; a trigger flash ripples along the tray.
- The synergy links between adjacent items render as a faint thread that lights up when an essence spill fires.
- Damage numbers pop upward from the target; crits are larger with a brass outline.
- **(Fixed)** Speeds are 0.5x, 1x, 2x, and 4x (the design requires 0.5x).

### 6.4 Loadout / Between-Battle Screen (the guild panel)

The main place items move. **(Fixed)** There are no hero tabs for now: up to 6 heroes, and every hero's row stays visible so rows can be compared and items dragged between them. Relics are a row of hex tokens, not a board.

```
+-----------------------------------------------------+------------+
| HERO ROWS (all visible): portrait, stats, row,      | INSPECTOR  |
|   fielded/backup, order; then the item row          | (pinned,   |
|   [item][item--][item] [free slots]                 | parchment) |
+-----------------------------------------------------+ what the   |
| STASH (shared, 6 slots, works like a hero row)      | selected   |
| ESSENCE POUCH (gems) · shards                       | item does, |
| RELICS: [hex][hex][hex]... (any number, no sockets) | + actions  |
+-----------------------------------------------------+------------+
```

- Dragging an item between hero grids is a first-class interaction (see section 9).
- Adjacent-slot effects preview live on hover: neighbors highlight and a ghost "spill" arrow shows direction.

### 6.5 The Caravan (shop) (Fixed: renamed; no enchantments)

A wagon-side market stall. Items and heroes for hire sit on cloth with price tags. There are no enchantments to sell (infusions are the game's enchantments, and essences come from fights). Reroll is a small brass lever. Selling drops the item into a coin dish. A ware that would combine with an item you hold is lit (brass glow).

### 6.6 Forge / Essence Infusion

**(Fixed)** Infusing happens any time between fights, from the guild panel, not at the Forge. The Forge stop is for **reforging** (removing an item's infusion). An infusion workbench view can still come later: place an item, drop one or two essence gems into its sockets (Epic and Legendary items have 2, others 1), and preview the result. Two different essences make an alloy (swirl animation, split gem; see section 8).

### 6.7 Event / Rift Encounter

Illustrated card on parchment with 2 to 4 choice buttons. Grim events use a cracked frame variant.

### 6.8 Run End (Victory / Defeat) and Meta Screens

Summary ledger (stitched cloth): days, wins, losses, synergies found, relics. Meta unlocks come later and never add stats. Defeat swaps brass for ash and cracked-glass overlays; victory brightens the lamplight.

---

## 7. Component Library

Every component needs the listed states. Build once, reuse everywhere.

| Component | States | Size (1x) | Notes |
|---|---|---|---|
| Button, primary | idle, hover, pressed, disabled, focus | 9-slice, min 48x16 | Brass on oak; ember for "Fight" |
| Button, secondary | same | 9-slice | Parchment |
| Icon button | same | 20x20 | Settings, pause, speed |
| Panel, cozy | default | 9-slice | Oak plus brass corners |
| Panel, grim | default | 9-slice | Slate plus cracks |
| Panel, tooltip | default | 9-slice | Parchment, 1px ink border, tail |
| Tab | idle, active, hover | 9-slice | Hero tabs show portrait |
| Hero portrait frame | idle, selected, fallen, in backup | 32x32 and 48x48 | |
| HP bar | full, damaged, shielded, poisoned | 9-slice | Damage ghost trails behind |
| Cooldown sweep | 16 frames | mask for 24x24 | Radial, overlay |
| Status pip | one per status | 8x8 | The game's statuses (section 10) |
| Toggle / slider | on, off, hover | 16x8, 64x8 | |
| Tooltip tail | 4 directions | 8x4 | |
| Scrollbar | idle, hover, drag | 4 px | |
| Currency chip | gold, keys, essence shards | 16x16 | |
| Toast / notification | info, success, warning | 9-slice | Slides in top-center |

---

## 8. Game Objects: Items, Relics, Essences

### 8.1 Item token

Layers, back to front:

1. **Slot well:** inset shadow, shows empty state.
2. **Rarity frame:** per the rarity ladder. Enemy-only items get the rift-bleed frame.
3. **Icon:** centered; the token is as wide as the item's slots.
4. **Tier:** C, B, A, or S.
5. **Essence pips:** one per socket (Epic and Legendary have 2, others 1); empty sockets show as dim dots.
6. **Overlays:** cooldown sweep, oathbound chain (later: an oathbound item can't be moved off its hero), "new" sparkle.

Item states: empty, filled, hover, picked-up (lifted with shadow), valid-drop, invalid-drop, selected, lit (combines with a held copy), oathbound, on-cooldown, triggering. **(Fixed)** No "cursed" state.

**Icon production spec:** 24x24, max 16 colors per icon, 1px dark outline, light from top-left, no text. Naming: `item_<slug>_24.png`.

### 8.2 Relic token

**(Fixed)** A hexagonal **token**, brass-rimmed, with no socket or board: the guild holds any number of relics, shown as a row that grows (wrapping as needed). Relics look heavier and more ornate than items (they are permanent and team-wide, and can't be removed once taken). The rim follows the rarity ladder; Legendary relics (boss relics) get the rift bleed with gold. States: filled, hover, active-pulse (when its trigger fires). Naming: `relic_<slug>_28.png`.

### 8.3 Essence gems and the spill language

Essences change how an item works, so they need the clearest visual grammar in the game.

**(Fixed)** These follow the game's infusion rules (`CLAUDE.md`, "Infusion rules"). **Only Resonant infusions spill**, so spill arrows show only at Resonant.

| Kind | Visual | What it spills (at Resonant) |
|---|---|---|
| Single essence | One round gem, single hue | Its partial effect to **both** neighbors |
| Alloy (two different essences) | Half-and-half split gem with a seam | The first essence to the **left**, the second to the **right**; the alloy's own effect never spills |
| Pure double (same essence twice) | Faceted gem with a bright inner core and a halo | The **same** as a single: the base essence's partial effect to both sides. Its bonus never spills and never strengthens the spill. (The one exception would be a pure double whose effect *is* doubled spill, an optional idea for Overgrowth.) |
| Essence Transformation (item + essence pair) | Gem with a small padlock | **Never** spills, even at Resonant |

**Spill indicators:** small chevron arrows on the left and right edges of an item token, tinted in the essence hue, shown only at Resonant. A single essence and a pure double show one arrow on each side in their hue. An alloy shows its first essence's color on the left and its second's on the right. A transformation shows a flat bar instead of arrows. Spills stay inside the hero's row, so the end of a row gets no arrow target. On hover, the arrows animate outward to the neighbors that would receive the effect.

**Discovery:** transformations are hidden synergies. The padlock shows only once that transformation has been discovered; until then the gem looks like a plain single.

Sizes: pip 8x8, tooltip gem 16x16, shop gem 32x32. Naming: `essence_<name>_<size>.png`, `essence_alloy_<a>_<b>_<size>.png`, `essence_pure_<name>_<size>.png`.

### 8.4 Enchantment badge (Fixed: removed)

There's no separate enchantment system: infusions are the game's enchantments. v0.1's banner strip isn't used.

---

## 9. Interaction and Motion Spec

| Interaction | Behavior | Duration |
|---|---|---|
| Hover item | Lift 1 px, brass rim glow, tooltip after 150 ms | 100 ms |
| Pick up item | Scale to 1.1x, drop shadow grows, slot shows ghost | 80 ms |
| Valid drop target | Slot glows moss-green outline | continuous |
| Invalid target | Slot outlines blood-red, item wobbles on release and returns | 200 ms |
| Drop / snap | Overshoot bounce, small "thunk" sound cue | 120 ms |
| Swap items | Both tokens arc past each other | 180 ms |
| Essence infuse | Gem drops in, ring pulse, spill arrows draw on | 400 ms |
| Trigger fire | Icon flash white, small screen-space pulse to synergy neighbors | 150 ms |
| Damage number | Rise 12 px, fade, outline | 600 ms |
| Screen transition | Cozy: page-turn wipe. Grim: crack-shatter wipe | 400 ms |

Rules: all motion respects a "reduce motion" setting (swap to instant states and simple fades). Keep everything under 400 ms except celebratory moments.

---

## 10. Iconography Set (small UI glyphs)

8x8 and 16x16 versions for each:

**(Fixed)** These lists are the game's own (`data/statuses.json`, `EffectDef` triggers, the stops).

- **Stats:** HP, ATK, MGK, DEF, CRIT, ATSP; plus shield, heal, gold, and keys.
- **Statuses** (a shape each, so they read without color): Burn (flame), Golden Flame (flame with a core), Poison (circle), Bleed (droplet), Plasma (diamond), Blight (square), Slow (hourglass), Freeze (snowflake), Blind (bar).
- **Triggers (item text keywords):** when it fires (every N seconds), on hit, on a crit, at the fight's start, at a set time, when an ally drops below an HP share.
- **Stops and fights:** Caravan, Forge, Loot, Vault, Retrain, Event, Upgrade; normal fight, elite, boss.
- **System:** settings, pause, play, speed 1x/2x/4x, back, close, info, lock, filter, sort.

Style: 1px outline, single flat color per glyph, reads at 8x8.

---

## 11. Characters and Portraits (UI usage)

- **Hero portrait:** 48x48 bust for loadout tabs; 32x32 for battle HUD. Expressions: neutral, hurt, dead (greyed), buffed.
- **Enemy portrait:** 32x32 for intent bar; full battle sprites are outside the UI scope.
- **Guild banner and crest:** 64x64, editable emblem used across the hub.
- **(Fixed)** Enemies show no intent icons for now; enemy cards show their items and, for bosses, their HP-threshold phases.

---

## 12. VFX Sprites Tied to UI

Small sprite sheets, 8 to 12 frames each, 32x32 unless noted:

- Essence spill trail (per essence hue, tintable white base)
- Trigger flash ring
- Heal sparkle, shield ripple, poison bubbles, burn embers
- Rift crack overlay (full-screen) for elite and boss fights
- Coin burst, level-up burst, item-fuse swirl
- Drop-target glow ring (looping)

Author VFX in grayscale and tint in-engine so one sheet serves every essence.

---

## 13. Audio Cues to Pair With UI (for later)

Pick up, drop, invalid, infuse, fuse, trigger, coin, reroll lever, page-turn transition, crack transition, victory sting, defeat sting. Cozy sounds are wooden and soft; grim sounds are stone and glass.

---

## 14. Accessibility

- Never rely on color alone: rarity uses rivets/crests, essences use glyphs, statuses use shapes.
- Minimum contrast 4.5:1 for body text on panels (parchment text on oak fails; use ink on parchment).
- Colorblind palette toggle (swaps essence hues to a safe set while keeping glyphs).
- UI scale option (1x to 2x on top of integer scaling) and a larger-text mode for tooltips.
- Full keyboard and controller navigation for loadout drag and drop (select, pick up, move with d-pad, drop).
- Reduce-motion and reduce-screen-shake toggles.

---

## 15. File Structure and Naming

```
/art/ui/
  atlas/          packed spritesheets (generated)
  source/         .aseprite / .psd
    chrome/       panels, buttons, tabs, bars
    items/        item_<slug>_24.png
    relics/       relic_<slug>_28.png
    essences/     essence_*.png
    glyphs/       stat_*, status_*, trigger_*, node_*, sys_*
    portraits/    hero_<name>_<size>_<expression>.png
    vfx/          vfx_<name>_<frames>.png
    fonts/
  export/         @1x and @2x PNG exports
```

Conventions: lowercase snake_case; suffix with pixel size; state suffixes `_idle`, `_hover`, `_pressed`, `_disabled`; animated strips end in `_<frameCount>f`. All chrome is exported as nine-slice with the slice values recorded in a sidecar `.json`.

---

## 16. Production Checklist and Priority

**Phase 1: Vertical slice (blocking gameplay)**
- [ ] Palette, fonts, nine-slice panels and buttons
- [ ] Battle HUD: HP bar, cooldown sweep, status pips, damage numbers
- [ ] Item token (all frames and states) with 10 to 15 placeholder icons
- [ ] Loadout screen with drag and drop states
- [ ] Essence gems (single, alloy, pure double, transformation) plus spill arrows
- [ ] Relic hex token plus 5 placeholder relics

**Phase 2: Full run loop**
- [ ] Day bar thread and stop cards (no map)
- [ ] Caravan and Forge screens
- [ ] Event cards, run-end screens
- [ ] Full icon glyph set

**Phase 3: Polish**
- [ ] Guild hub scene with parallax
- [ ] Transition wipes, rift bleed overlays
- [ ] Legendary shimmer, VFX pass
- [ ] Accessibility toggles and controller nav art (button prompts)

**(Fixed)** The run loop has no map screen (Phase 2's "Rift map" is the day bar and stop cards) and no Bazaar (it's the Caravan). The Forge is for reforging.

**Rough asset counts to plan for:** ~60 items, ~25 relics, 8 essences (plus alloy and pure-double variants), ~30 status/stat/trigger glyphs, ~15 reusable panels/buttons, ~8 screens.

---

## 17. Decisions

1. **Resolution and style:** 1920×1080, smooth placeholder art drawn in code, for now. Pixel art at 480×270 is revisited when real art starts.
2. **Essence roster:** the game's 8 essences (section 3).
3. **Item footprint:** items are 1 to 3 slots by size.
4. **Title and logo:** still blocked on the game name (Riftrite is a placeholder).
5. **Battle layout:** front and back rows, heroes at the bottom and enemies at the top. The hex arena comes later.
6. **Backpack model:** a shared stash of 6 slots that works like a hero row; relics can't go there.
