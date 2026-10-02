# Changes: the asset contract

Decided 2026-09-30. This moves the game from code-generated art to **asset-driven art**: the game loads image files to a fixed contract, and anything that meets it drops in without code changes. The Python kits stay as placeholder producers. The long-term goal is commissioned, highly detailed painted art (Bazaar-level detail), so the contract is built for that: high-resolution masters, layered sources, and parts for later animation.

Each section below is one file. **Replace** means swap the quoted text for the new text, **Add** means insert it where stated, and **Remove** means delete it. Paths are from the repo root.

---

## 1. New file: `docs/plans/asset-contract.md`

```markdown
# The asset contract

Status: **agreed in discussion (2026-09-30), not built.** What every art file must look like so the game can load it, whoever makes it. The look is in `../art-style-guide.md`; this file is the technical side. The game is **asset-driven**: the Python kits in `tools/art/` are placeholder producers, and commissioned art replaces their files one at a time.

## 1. The goal, and what it means for files

- **The end state is commissioned, highly detailed painted art** (in the spirit of The Bazaar's detail), not code-generated shapes.
- **Detail shows where art is big.** An arena figure is about 100–160 px tall on a 1080p screen, so it must read at that size first; the fine detail pays off in portraits, the hero sheet, the vow screen, shop cards, and key art. Every unit gets both an **arena figure** and a **portrait** (sections 3 and 4).
- **Masters are delivered large** (4× the game's canvas) so they stay sharp on 4K screens and when shown big in the UI.
- **Layered sources are always delivered,** with the body parts separated, even while the game uses flat images. Asking for parts up front is cheap; asking later means repainting.

## 2. General rules

| Rule | Value |
| --- | --- |
| **Game format** | PNG, RGBA, straight (not premultiplied) alpha, sRGB |
| **Placeholder format** | SVG (what the kits make now) |
| **Source format** | Layered PSD or KRA, named layers, kept in `art-src/` (Git LFS) or outside the repo |
| **Background** | Transparent. No baked backdrop, shadow, ground ring, glow, status, or bar: the game draws those |
| **Lighting** | Gold light from the top left, flat painted shadow on the lower right (`../art-style-guide.md`, section 2) |
| **Colors** | The style guide's palette; **reserved status colors are never used as decoration** |
| **Loading** | The game loads `<name>.png` if it exists, otherwise `<name>.svg`. Swapping art is dropping in a PNG with the same name |

## 3. Arena figures (heroes and enemies)

| Item | Value |
| --- | --- |
| **Canvas (game units)** | 300 × 520, feet at (150, 500), facing right. Unchanged from the kits (`src/ui/arena/figures.gd`) |
| **Master size** | 4×: **1200 × 2080 px**, feet at **(600, 2000)** |
| **Bosses** | Twice the canvas: 2400 × 4160 px master, feet at (1200, 4000), marked `"scale": 2` in the manifest |
| **Facing** | Right. The game flips for units facing left, so nothing may depend on reading direction (no text, no one-sided crest that must stay on one side) |
| **Fill** | The figure stands on its feet point; small creatures and fliers use only part of the canvas (the game measures the drawn part) |
| **Readability test** | Shrunk to 100 px tall and filled flat black, every form must still be recognisable, and no two forms of one hero may match |

**File names** (in `art/figures/`):

| What | File |
| --- | --- |
| A hero's form | `heroes/<hero>_<form>.png`: `maren_base`, `maren_deadeye`, later `maren_eagle_eye` (apexes) |
| An enemy | `enemies/<enemy>.png`: `rift_hound` |
| An enemy's specialization (optional) | `enemies/<enemy>_<spec>.png`: `rift_hound_ashback`. Without one, the base figure shows with the specialization badge |

**The manifest** (`art/figures/figures.json`), one entry per figure, all points in canvas units (300 × 520):

| Field | What it's for |
| --- | --- |
| `head` | Where the HP bar and status icons sit above the unit |
| `hand` | Where a held weapon pivots, for swings |
| `muzzle` | Where shots and spells leave from (bow tip, lantern, staff) |
| `scale` | 1, or 2 for bosses |
| `parts` | Optional, for animation (section 5) |

Missing fields fall back to sensible defaults (`head` at the drawn top, `muzzle` at the drawn center).

## 4. Portraits

| Item | Value |
| --- | --- |
| **Size** | **1024 × 1024 px**, head and shoulders, transparent background |
| **Where** | Hero sheet, vow screen, fight card, shop and pick cards, the Codex |
| **Files** | `art/portraits/<hero>_<form>.png`, `art/portraits/<enemy>.png` |
| **Detail** | This is where the full painted detail goes |

## 5. Animation

- **Now:** one image per figure, moved by the game's tweens (lunge, recoil, squash, flash; phase 3b).
- **Later:** cut-out animation in Godot (`Skeleton2D` or `AnimationPlayer` on separate parts). Each figure's layered source has these parts on their own layers, painted whole behind any overlap:
  - `body`, `head`, `arm_front`, `arm_back`, `leg_front`, `leg_back`, `weapon`, `offhand`, plus extras (`cape`, `lantern`, `tail`, `wings`).
- **When parts are used,** they're exported as `art/figures/<kind>/<name>/<part>.png` at the master scale, with each part's pivot in the manifest's `parts` field.
- **Frame-by-frame animation** is out of scope: for detailed painted art it costs many times more.

## 6. Icons

| Kind | Master | Files | Notes |
| --- | --- | --- | --- |
| **Items and relics** | 512 × 512 px | `art/ui/items/glyphs/<id>.png` | Glyph only, centered in a 400 × 400 safe area; the game draws the kind's frame, the rank pips, and the rarity |
| **Statuses** | 256 × 256 px | `art/ui/statuses/<status>.png` | Shape first, reserved color second (statuses must read without color) |
| **UI icons** | 256 × 256 px | `art/ui/icons/<name>.png` | Stats, nodes, camp options |

## 7. Backdrops and effects

- **Backdrops:** 3840 × 2160 px, in separate layers (sky, far, middle, ground) for light parallax: `art/backdrops/<name>/<layer>.png`.
- **The arena ground** stays separate from the hex overlay, the zones, and Rift Collapse, which the game draws.
- **Effects** (hits, Burn, Shields, area warnings) are drawn or tinted by the game, from greyscale sprites, so status colors stay exact. Free CC0 sprites (Kenney's Particle Pack) are fine placeholders.

## 8. Commissioning

**Order:**
1. **A style key:** one hero (Maren's base form) as a figure and a portrait. It sets the look everything else matches.
2. **The three base heroes.**
3. **The nine path forms.**
4. **The nine Act 1 enemies.**
5. **Old Mother Ash.**
6. Then icons, backdrops, and the apex forms as they're built.

**Every delivery includes:** the PNG master at the sizes above, the layered source with named parts (section 5), and the manifest points (or a marked-up image showing them).

**The brief** for an artist is this file plus `../art-style-guide.md` and the current placeholder for the same unit.

## 9. Credits

- **`CREDITS.md` at the repo root** lists every asset not made for the game: author, source, and license (CC BY icons need it; CC0 doesn't, but list it anyway).
- **Licenses allowed:** CC0, CC BY, MIT, and paid licenses that allow commercial use. **Not allowed:** GPL code or shaders, "non-commercial" licenses, and anything without a clear license.

## 10. Code changes this needs (for the build plan)

- `Figures` loads `.png` before `.svg`, and reads `figures.json` for `head`, `hand`, `muzzle`, and `scale`.
- Bars, status icons, and shots use the manifest's points instead of the drawn box.
- A portrait loader, and portraits shown where section 4 says.
- `ItemIcon` and `UiStyle` icons load `.png` before `.svg`.
- A test that every hero form and enemy has a figure (PNG or SVG), every manifest point is inside the canvas, and every PNG is the size this file says.
- The import settings for figures and portraits: mipmaps on, linear filtering.

## Open questions

- **Arena figure size:** about 100 px tall now. Painted detail would benefit from bigger figures (or a closer camera); that's for the overall UI redesign.
- **Where layered sources live:** Git LFS in the repo, or outside it.
- **Specialization art:** full figures for every specialization, or base figures plus badges for most.
```

---

## 2. `docs/art-style-guide.md`

**Replace** in the intro:

> **How it's made:** code-generated placeholders (`tools/art/hero_kit.py`) for the proof of concept. A commission (at most key art, such as the store image and hero portraits) is only considered once the game has proven itself; see "Budget" below.

with:

> **How it's made:** the game is **asset-driven** (`plans/asset-contract.md`): it loads image files to a fixed contract. Code-generated placeholders (`tools/art/hero_kit.py`, `enemy_kit.py`) fill it for now. The goal is commissioned, highly detailed painted art, starting once the game has proven itself; see "Budget" below.

**Replace** the decision bullet:

> - **Code-generated art for now**, built from the kit's shapes and colors. No art spend until the game proves itself.

with:

> - **Asset-driven, with code-generated placeholders for now.** Commissioned art replaces the placeholders file by file, to the contract in `plans/asset-contract.md`. The goal is highly detailed painted art.

**Replace** in section 8 ("Budget"):

> - **Once the game proves itself** (a playable demo, playtester interest, Steam wishlists), the first spend is **key art**: the store capsule and maybe the three hero portraits, a few hundred dollars.

with:

> - **Once the game proves itself** (a playable demo, playtester interest, Steam wishlists), the first spend is a **style key**: Maren's base form as a figure and a portrait, to the asset contract. Then the three base heroes, the path forms, the Act 1 enemies, and the boss, in that order (`plans/asset-contract.md`, section 8).

---

## 3. `docs/plans/rebuild-build-order.md`

**Replace** phase 7's row's middle cell:

> Style guide first (can start any time after phase 3), then characters, enemies, arena tiles, UI chrome, effects

with:

> Style guide first (can start any time after phase 3), then the asset contract's loader changes (`asset-contract.md`, section 10), then commissioned art in the contract's order: characters, enemies, arena, UI chrome, effects

---

## 4. `CLAUDE.md`

**Add** to the plan table, after the `ui-new-systems.md` row:

```markdown
| `asset-contract.md` | what every art file must look like (sizes, anchors, names, layers, manifest), so commissioned art drops in |
```

**Replace** in "Tone and naming":

> All art is placeholder until the art rehaul (rebuild phase 7).

with:

> All art is placeholder until the art rehaul (rebuild phase 7). The game is asset-driven: new art follows `docs/plans/asset-contract.md`, and any asset not made for the game goes in `CREDITS.md` with its license.
