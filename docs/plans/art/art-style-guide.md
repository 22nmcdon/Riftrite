# The art style guide

Status: **a first draft, for the playtester (2026-10-28).** Its three foundations are agreed (Decisions 1–3); everything else is drafted from the art already in the game and the look tests, and waits on the playtester's mark-up (Open questions). What the game's art looks like. `asset-contract.md`, beside it, is the technical side (sizes, anchors, names, layers, the manifest); together with the current placeholder for the same unit they make an artist's brief.

**How it's made:** the game is **asset-driven** (`asset-contract.md`): it loads image files to a fixed contract. Code-generated placeholders (`tools/art/hero_kit.py`, `enemy_kit.py`, `backdrops.py`) fill it for now, and they follow this guide so the game already looks like a rough version of itself. The goal is commissioned art, **painted but ink-led** (Decision 2), starting once the game has proven itself; see section 8.

**What it's built from:** the luminous look tests in `art/look-tests/` (`maren_luminous_test`, `hero_lineup`, `enemy_lineup`, `arena_look_test`, `map_and_icons_look_test`, `shops_look_test`), the playtester's uploaded art in `art/ui/` (phase 5b), the mock's UI palette (`docs/mockups/hero-panel-layout.pdf`, `UiStyle`), and the two looks tried and set aside (`maren_look_test`, dark with woodcut hatching; `maren_silhouette_test`, black ink figures). The old game's look (`docs/archive/ui-asset-design.md`) is history, not a reference.

## Decisions

1. **A fresh guide** (the playtester, 2026-10-28). An earlier draft lived outside the repo; this one starts again from what's in the repo, and folds in the three edits `incoming/changes-asset-contract.md` (section 2) made to that draft: the intro, the decision below, and section 8's budget.
2. **Painted, ink-led** (the playtester, 2026-10-28). The look tests' bones stay: a bold ink outline, jewel colors, one gold light with a flat painted shadow, a silhouette that reads at 100 px. Commissioned art adds painted texture and detail *inside* those shapes: cloth weave, worn leather, chipped steel, glow that blooms. The detail shows most where art is big (portraits, the hero sheet, the vow screen, key art); an arena figure reads by shape and color first. One look from the arena up to the store page.
3. **Bright but wrong** (the playtester, 2026-10-28). The rift is beautiful and luminous, and quietly off: ruins that float, debris that hangs still, light that glows where nothing should, a seam of aquamarine down a gold sky. Danger reads through the enemies and the rift's light, not through darkness. The dark is saved for the later acts and the bosses (section 7). This is how the luminous look meets `CLAUDE.md`'s "dark and dangerous": the danger is real, the world just isn't dim.
4. **Asset-driven, with code-generated placeholders for now.** Commissioned art replaces the placeholders file by file, to the contract in `asset-contract.md`.

## 1. The look in short

- **A golden meadow under an aquamarine sky,** on islands floating in the rift, among marble ruins. Warm ground, cool sky.
- **Ink outlines** around every figure, prop, and island: the line is the style's signature, and what keeps a painted figure readable at arena size.
- **Jewel colors,** saturated but never neon: teal, wine, plum, bronze, moss.
- **One gold light** from the top left, and a **flat painted shadow** on the lower right (section 2).
- **The rift glows aquamarine.** Rift power on a unit shows as aquamarine light: eyes, runes, sigils, arrowheads, cracks. The more the rift is in something, the more it glows.
- **Heroes read warm, enemies read cool and dark** (section 5).

Three tests every piece must pass:

1. **The silhouette test** (`asset-contract.md`, section 3): shrunk to 100 px and filled flat black, it's still recognizable, and no two forms of one hero match.
2. **The meadow test:** on the golden ground at arena size, it separates from the ground and from its neighbors. A figure darker or more saturated than the ground passes; a figure in the ground's own ochres fails.
3. **The status test:** nothing in it could be mistaken for a status, a ring, or a warning the game draws (section 3, the reserved colors).

## 2. Light and shadow

- **The key light is gold** (Rift gold, section 3), from the **top left**. It catches the top and left edges of every form as a thin warm rim inside the ink line.
- **The shadow is flat and painted:** one shape on the lower right of each form, laid over the base color as a cool violet-indigo (Shade, at low opacity), never a gradient to black. Painted art may soften its edge and add a second, smaller occlusion shadow where forms meet (under a hood, inside a sleeve), but keeps the two-step read: lit side, shadow side.
- **Rift light is a second, local source,** aquamarine (or gold for holy things: Vell's lantern, Edric's seal). It lights only what's near it and blooms a little past the ink line. It never relights the whole figure.
- **Cast shadows on the ground are the game's,** not the art's: the figure has none baked in (`asset-contract.md`, section 2).
- **Figures face right,** lit from the top left either way: the game mirrors a figure facing left, and a mirrored figure's light then comes from the top right. That's accepted; nothing may depend on it.

## 3. Palette

The world (from the luminous look test):

| Name | Hex | Use |
| --- | --- | --- |
| Sky | `#FFF3CF` | the sky's warm top, light haze |
| Mist | `#BFF0E2` | the sky's middle, far distance |
| Rift sea | `#6CC7B6` to `#3F8F8A` | the sky's deep bottom, under the islands (`tools/art/backdrops.py`) |
| Meadow | `#C8B56A` | the ground, island tops |
| Deep | `#6F6A38` | island sides, the ground's shadow |
| Bone | `#F4EAD0` | marble ruins, robes, highlights |
| Ink | `#1A1024` | every outline; the darkest dark |
| Shade | `#20164A` | the flat painted shadow, laid over at low opacity |

Light:

| Name | Hex | Use |
| --- | --- | --- |
| Rift gold | `#FFD66E` | the key light's rim; holy light; the heroes' side |
| Aquamarine | `#62F2DF` | rift power: glowing eyes, runes, sigils, arrowheads, cracks |
| Ember | `#FF9A3C` | fire and heat (Ilse, Ashlings, Burn's effects) |

Heroes' materials (each hero's own colors are in section 5): moss `#1F7A68`, leather `#9A6236`, plum `#46355E`, skin `#E6B48C` (and the roster's other skin tones), wood `#A8703C`, iron `#8A95A8`, wine `#A8323F`, bronze `#C9963F`.

Enemies' materials (`tools/art/enemy_kit.py`): dusk `#56407E`, tide `#2A6570`, stone `#6F7B86`, ash `#4A3F4A`, bog `#2F4A36`; Act 2's glass `#8FC9D2`; Act 3's crag `#8A7A6A` and crown `#9C88D8`.

The UI (the mock's palette, `UiStyle`): navy `#0C1019` to `#2B3B55` for panels, teal `#3FC8B8`, gold `#FFD66D`, cream `#FAEBD5`. The UI frames the world; it doesn't paint inside it.

**Reserved colors.** The game draws these over the art to say something, so the art never uses them as decoration on a unit, and never near the feet (where the rings are):

| What | Color | Drawn by the game |
| --- | --- | --- |
| A hero's ring, your zone while placing | gold | under each hero; the bottom rows |
| An enemy's ring, their zone, a warned area, a breaking bridge | red | under each enemy; areas about to land |
| Burn, Bleed, Poison | `#E0703A`, `#D14545`, `#7ED14F` | damage numbers and tags |
| Root, Stun, Slow, Taunt, Silence, Marked | `#8FBF5A`, `#F0D060`, `#7FB8D8`, `#E07050`, `#B79CF0`, `#FF8A80` | status tags (`UnitToken.STATUS_COLORS`) |
| Shield | the Shield bar's color | the bar, Shield numbers |

A unit may *be* these colors in its body (Ilse's ember, Severine's blood) as long as no glowing shape on it looks like a status tag, a ring, or an area's edge. When in doubt, the status test (section 1) decides.

## 4. Line, shape, and detail

- **The outline** is Ink, unbroken around the silhouette, about 3 units on the 300 × 520 canvas (12 px on the 4× master). Inner lines (a belt, a fold, a strap) are thinner, about two thirds as wide. Glow is the only thing that may cross the outline.
- **Shapes are simple and big first:** a hooded triangle, a round shield, a long bow. Detail never changes the silhouette; it lives inside it.
- **Detail where it's big** (Decision 2): at arena size, a few painted strokes for texture and the rift glow; in a portrait, the full painting. A detail that only reads at 1024 px is welcome there and left out of the figure.
- **Proportions:** heroes are a little stylized, about 6 heads tall, with slightly big hands, heads, and props so their tools read at 100 px. Enemies may break human proportion freely.
- **Props tell the role:** each hero holds the one thing that says what they do (section 5), and holds it where the game can see it: the bow tip, the lantern, the bell are each a `muzzle` or `hand` point (`asset-contract.md`, section 3).

## 5. Figures

### Heroes

Heroes read **warm and upright,** in their own jewel colors with Bone and leather, lit gold. Each hero's base form has a signature color pair and a signature prop, kept through every form so the player can follow them (from `tools/art/hero_kit.py`):

| Hero | Who | Colors | Signature prop and read |
| --- | --- | --- | --- |
| Brannoc | the warden (tank) | wine and iron | round shield, helm, a square stance |
| Maren | the ranger | moss and leather | hood, long bow, quiver |
| Vell | the mender | Bone robe, plum trim | hooded veil, a hand lantern |
| Garrow | the anchor (tank) | rust and chain steel | chains wound on his arms |
| Tamsin | the knife | duskcloth and steel | hood and mask, two knives, a crouch |
| Aldous | the bell-ringer | slate cassock, bronze | hand bell, grey hair |
| Severine | the bloodwitch | nightsilk and blood | pale skin, black hair, claws |
| Edric | the tithe-warden | cream vestment, tithe blue | the seal, a ward ring |
| Ilse | the fire-speaker | ash and cinder | red hair, flame in hand |
| Ottilie | the alchemist | plum coat, apron | goggles, vials |
| Kestra | the beastwarden | fur and hide | her companions beside her (each its own figure) |
| Lucan | the illusionist | duskcoat and silver | pale hair, a tall coat |
| Hob | the scavenger | patchcoat, coin gold | a patched hood, a bulging pack |

**Forms grow by the rift** (the hero lineup shows the rule):

- **Base:** the hero as they came. The rift shows only as a thin rim and a glint.
- **A path's form** (on transforming): a new silhouette (a hood down, a bigger bow, a tower shield, a lantern staff) and more rift in them: an aquamarine eye, runes, a sigil, a glow at the feet. The colors stay the hero's, so the player knows who it is. The three paths of one hero must fail to match in the silhouette test.
- **An apex:** the path's form, larger in presence and most rift-touched. The glow is part of the costume now (a crown of light, a burning mantle, a halo of bells), and the silhouette grows past the base form's (a cloak that streams, a weapon that floats).

The apex forms are commissioned after the paths (section 8).

### Enemies

Enemies read **cool, dark, and rift-touched:** the palette's darker side (dusk, tide, stone, ash, bog), with **more aquamarine glow than heroes**, especially eyes. Against the golden meadow they read as shapes that don't belong.

- **One shape per archetype** (`rebuild-enemies.md`): a pup is low and round, a hound long and spined, a sentinel a slab with a door of a shield, an archer a tall hood. Two enemies of one archetype share a silhouette family and differ in detail.
- **Rift glow marks the dangerous part,** where it can: a hound's spines, a moth's body, the sentinel's cracks.
- **Specializations** (`enemy-growth.md`): by default the base figure, with the game's badge (Question SB). A specialization drawn as its own figure changes one thing only (an ashen back, a glass shell) and keeps the silhouette.
- **Elites** are a step bigger and brighter than their kind, with one extra mark that's theirs (a crest, a mantle, a crown of spines).
- **Bosses** (Old Mother Ash, the Mournwater, the Heart of the Rift) are drawn at twice the canvas (`asset-contract.md`, section 3) and each owns the act's darkest and strangest colors (section 7).

### Companions, summons, copies, and thralls

- **Kestra's companions** are figures of their own (`heroes/kestra/<companion>/`), in her fur and hide with a touch of each one's nature (the hound's ember, the serpent's venom green).
- **Summons** are figures like any enemy's, smaller.
- **Copies and thralls** are the game's: a copy is its original drawn paler (`UnitToken.COPY_ALPHA`), a thrall its enemy figure on the heroes' side. No art of their own.

## 6. Portraits and big art

- **Portraits** (`asset-contract.md`, section 4): head and shoulders, three-quarter view facing right, lit gold from the top left like the figure. This is where the painting goes deepest: faces, materials, the rift's light in the eyes.
- **Background:** transparent; the game sets the portrait on its card. A painted portrait may carry a soft rim of its own light past the outline.
- **Forms:** a portrait per form, so a transformation shows on every card. The hero must be plainly the same person.
- **Key art** (the store capsule, the title) follows the same rules at full size: the floating islands, the meadow, the sky, the heroes in front.

## 7. Places

### The arena

- **The board stands on a floating island** (`art/ui/arena/`): a meadow top with tufts and stones, cracked earth sides dropping into the rift, marble ruins as rocks, the sky all round. The arena look test is the reference.
- **The ground is quiet:** low contrast, mid value, so figures pop. Hex lines, zones, areas, Rift Collapse, and water are the game's and lie over the ground (`asset-contract.md`, section 7).
- **Rocks are ruins:** broken columns, plinths, an altar, in warm bone marble (`#D8CBA0`) with an Ink line, never in the reserved colors.
- **Water** (Act 2) is drawn by the game over the ground, glassy aquamarine with pale ripples. **The void** (Act 3) is the sky itself showing through.

### The acts

Each act keeps the look and moves the palette one step, so the climb shows (Decision 3: the dark is saved for later):

| Act | The place | Ground and sky | The rift's light |
| --- | --- | --- | --- |
| **Act 1** | the rift's edge: golden meadows, marble ruins, islands in a gold-and-aquamarine sky | Meadow and Deep under Sky and Mist (as now) | gold, with seams of aquamarine |
| **Act 2, the Glassmere** | a drowned lake of glass: shallows, reed beds, sunken bells, glass shards standing in the water | silvered, wet greens and glass blues; the sky lower and paler, a dawn haze instead of gold noon | colder: more aquamarine, the gold thin and low |
| **Act 3, the Shattered Crown** | the rift's heart: broken stone islands over nothing, narrow bridges, a crown of shattered light above | bare crag and violet stone; the sky deepening to indigo and violet with prism shards | strongest: crown violet and aquamarine, the gold almost gone |

Endless keeps the act it follows. Each act's bosses push its colors furthest (Old Mother Ash in ash and ember; the Mournwater in deep drowned teal; the Heart of the Rift in the void's violet).

### Backdrops, the map, and the shops

- **Backdrops** (`asset-contract.md`, section 7): sky, far, middle, and ground layers, so they can drift a little apart; floating islands and ruins in the far layers, motes of gold and aquamarine hanging in the air.
- **The act map** (`art/ui/map/`): one island a day joined by a gold thread, with each node as a round medallion on its island (the map look test).
- **The shops' keepers** are characters, a little more caricatured than the heroes (the shops look test): the Pedlar, a weathered traveller under a mountain of bundles, in warm browns and gold lanterns; the Magpie, a beaked and feathered dealer in midnight blue with an aquamarine lantern. Each stands in a scene of their own: the Pedlar's cart on the meadow in gold haze, the Magpie's stall on a floating rock in the rift.

## 8. Budget and commissioning

- **No art spend until the game proves itself:** a playable demo, playtester interest, Steam wishlists.
- **Once it has,** the first spend is a **style key**: Maren's base form as a figure and a portrait, to the asset contract. It sets the look everything else matches, and the guide is revised from it. Then the three base heroes, the path forms, the Act 1 enemies, and the boss, in that order (`asset-contract.md`, section 8).
- **The roster is big,** so the order after Act 1 follows play: the heroes a run drafts most, then Acts 2 and 3's enemies as players reach them, then the apex forms. Every unit has its placeholder until then, so nothing waits on art to be playable.
- **One artist for figures and portraits,** if possible, so the line and the light stay one hand's. Icons and backdrops may be someone else's, to this guide.

## 9. The UI, icons, and effects

- **The UI is the mock's** (`docs/mockups/hero-panel-layout.pdf`): navy panels, teal and gold accents, cream text, flat rounded boxes. It sits around the world, never over the arena's middle.
- **Fonts** (`art/fonts/`): Cinzel Bold for headings and names, Cinzel Black for the title, Alegreya for body text, Work Sans as the fallback (phase 5b, Decision 2).
- **The item language** (phase 5b): each kind has its own frame shape and color (charm, tactic, sigil, gambit, relic, upgrade, vow, path, bond; `art/ui/items/frames/`), and every item draws its glyph inside it (`asset-contract.md`, section 6). A glyph is Ink line on a single light fill, readable at 32 px.
- **Status icons** are shape first, color second: each status's icon must read in grey (`asset-contract.md`, section 6), then takes its reserved color.
- **Camp's and the map's icons** (`map_and_icons_look_test`): a round medallion with a colored rim by kind (red for fights, gold for camp, purple for the rift and events, teal for shops) and an Ink glyph.
- **Effects** are greyscale sprites the game tints, so status colors stay exact (`asset-contract.md`, section 7): soft, rounded shapes with a little Ink only where they need an edge, gold for the heroes' light, aquamarine for the rift's, ember for fire.

## 10. Never

- Dark, desaturated, gritty-realism rendering: the world is luminous (Decision 3).
- Outlines left out, or thinned to nothing: the line is the style (Decision 2).
- Detail that changes the silhouette, or that only reads big but sits on the arena figure.
- Gore. Blood is a color (Severine's) and a status, not wounds.
- A reserved color as decoration, or a glow at the feet that could be read as a ring.
- Text, crests, or anything that must read one way round on a figure (it's mirrored).
- Anything from Guildrun, The Bazaar, or Enter the Gungeon: their names, characters, or items (`CLAUDE.md`). Matching The Bazaar's level of detail is a goal (`asset-contract.md`, section 1); copying its look is not.

## Open questions

- **SA. Act 1's name.** The other acts have names (the Glassmere, the Shattered Crown); Act 1 is "the rift's edge" here as a stand-in. A name of your own?
- **SB. Specializations:** a badge on the base figure for all, or their own figures for some (`asset-contract.md`'s open question)? Proposed: badges, with figures only for a boss's or an elite's if any.
- **SC. Acts 2 and 3's palettes** (section 7) are drafted from the acts' descriptions. Right direction? *(Look tests made, 2026-10-28: `art/look-tests/act2_look_test.png`, `act3_look_test.png`, and `acts_side_by_side.png`, from `tools/art/act_look_tests.py`; waiting on the playtester's read.)*
- **SD. Skin tones and the roster:** the kit gives most heroes the same skin. Proposed: the style key settles a range (light to deep, all lit gold), and the roster is spread across it.
- **SE. Arena figure size** (`asset-contract.md`'s open question): about 100 px tall now. The style holds at that size; painted detail would show more with bigger figures or a closer camera, for the UI redesign to weigh.
