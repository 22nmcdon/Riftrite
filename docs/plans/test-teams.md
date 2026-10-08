# Test teams

Status: **first draft (2026-10-02); partly built in `easy-start.md` ES-4:** `tools/test_teams.json` holds the plan teams (burst, sustain, control, and the old three as tank) with their leans, and four bad stand-ins from the six built heroes (only Glass proved bad); `run_runner.gd --test-teams` plays them, the lean is for testing only (`RunContent.test_lean`), and the run report has By team and By group. The synergy teams below come in as their heroes are built. Teams for the run bot (phase 6) to play, to check that builds work and that synergy matters. Each team has a **build** it's meant to show, the **why**, and the **relics and items** the bot should lean toward. Heroes and paths: `rebuild-heroes.md`; builds: `build-map.md`. Suggested home: `docs/plans/test-teams.md`, with the teams themselves as data in `tools/sim_teams.json`.

## How to test

Run every team in three groups, on the same seeds and difficulty:

| Group | What it is | What it should show |
| --- | --- | --- |
| **Synergy** | The teams in section 1, vowed as listed, with the bot leaning toward each team's relics and items | Builds work: these should beat random |
| **Random** | 3 random heroes, random vows, normal bot drafting (no lean) | The baseline |
| **Bad** | The teams in section 2: no front line, payoffs with no makers, anti-synergies | Synergy matters: these should lose to random |

**What to measure:**
- win rate by act (1, 2, 3);
- endless depth (deepest floor);
- average fight length;
- hero falls per run;
- shards earned and spent;
- **per path:** win-rate gain from the transform (floor and ceiling), and for engines, how often the build came together.

**What to flag:**
- **A synergy team at or below random:** its build doesn't work. Check the makers, payoffs, and numbers.
- **A bad team at or above random:** synergy doesn't matter enough, or the "bad" team isn't bad.
- **One synergy team far above the rest:** a candidate for tuning down. Endless depth shows this best.
- **A build never wins a single run:** something in it is broken (a dead keyword, a payoff that never fires).

**The bot's lean:** each team lists **key relics and items**. The bot weights those up in shops and picks (say, ×3), so the test measures the build, not luck in the shop. Also run each synergy team once with **no lean**, to see how much a build needs its items.

**Floor and ceiling runs** (`build-tuning.md`): besides the three groups, each path is run twice: once on a **neutral team** (random teammates, no lean) for its floor, and once in its **synergy team** (with the lean) for its ceiling. Enablers are also run in their synergy team with the enabler swapped out, to measure their **lift**. For engines, the random group also logs **how often the build came together** by the transform; that sets the engine's ceiling.

**Apexes:** each team names the apex it vows toward. Test both apexes where the table lists two.

---

## 1. Synergy teams

### Keyword builds

| # | Team | Build | Why it should work | Key relics and items |
| --- | --- | --- | --- | --- |
| 1 | **Thicket:** Maren (Trapper → Huntmaster), Tamsin (Garrote → Pinmaster), Garrow (Chainwarden → Undertow) | Root | Garrow drags enemies into Maren's snares and Roots them with Maelstrom. Tamsin's Garrote crits held enemies and keeps them held. Huntmaster and Pinmaster make held enemies take more from everyone | Thicket Engine, Thornwoven Cloak, Grasping Mire, Bramble Seed, Snare Wire, Heavy Pommel, Iron Garden; Bramble Knot, Opportunist, Grasping (sigil) |
| 2 | **Hunt:** Aldous (Bellwarden → The Great Bell or Requiem), Tamsin (Headhunter → Executioner or Bloodtrail), Vell (Vigil Keeper → Inquisitor) | Mark | Aldous Marks everything, Tamsin dives and executes Marked targets, and Vell's smites hit Marked enemies harder. Three payoffs on one maker that Marks the whole field | Hunter's Engine, Executioner's Mark, Hunter's Ledger, Brand of Guilt, Tally Drum (proposed); Hunter's Chalk, Tolling (sigil) |
| 3 | **Pyre:** Ilse (Ember Choir → Cinder Saint), Maren (Volley → Hailstorm), Kestra (Cinderhound → Firestarter) | Burn (many sources) | Ember Choir sets every ally's hit on fire, Volley's split arrows multiply those hits, and Kestra's hound adds more. Ilse's Heat turns all that Burn into faster casts | Ashen Engine, Ember Heart, Ashen Censer, Pyre Ash, Pyre Banner (proposed); Ember-Tipped, Flint and Tinder, Kindled (sigil) |
| 4 | **Furnace:** Ilse (Furnace → Blast Furnace), Aldous (Windcaller → Long Wind), Kestra (Cinderhound → Hellhound) | Burn (one target) | Furnace scales with attack speed; Aldous's Tailwind and Peal give it. Kestra's hound keeps Burn on Ilse's target for Stoke to multiply | Ashen Engine, Ashen Censer, attack-speed relics; Ember-Tipped, Quick Pour-style upgrades |
| 5 | **Rot:** Ottilie (Catalyst → Solvent or Grand Reaction), Severine (Plaguebearer → Pestilence), Ilse (Wildfire → Living Flame) | Burn and Poison mixed | Ilse and Severine stack Burn and Poison on the same enemies; Ottilie's Catalyst hits harder against both, and Solvent keeps the two piles even | Ashen Engine, Pyre Ash; Kindled (sigil), Ember-Tipped |
| 6 | **Venom:** Severine (Plaguebearer → Gravecaller), Kestra (Serpent-Keeper → Brood Mother), Edric (Aegis → Bastion of Saints) | Poison | Two Poison makers. Severine's lifesteal doubles against Poisoned enemies, and Edric keeps the two fragile Poison sources Shielded | Lifesteal relics (Leech Tooth, Shadow Engine), Shield relics; Leech Fang |

### Defense and control builds

| # | Team | Build | Why it should work | Key relics and items |
| --- | --- | --- | --- | --- |
| 7 | **Bulwark:** Edric (Aegis → Bastion of Saints), Garrow (Aegisfang → Endless Bulwark or Shatterburst), Vell (Wardweaver → Thornweave) | Shield | Edric and Vell keep Shields on everyone; Garrow's Bulwark Burst spends all of his Shield, including theirs. Hallowed Ground doubles every Shield for 5s | Warden's Engine, Shattered Aegis, Tithe of Iron, Overflow Chalice, Shieldbearer's Oath (proposed); Warding Thread, Kindling Ward, Bulwark (sigil) |
| 8 | **Whirlpool:** Garrow (Chainwarden → Undertow or Grinder), Ilse (Wildfire → Ring of Fire), Maren (Volley → Hailstorm) | Clump | Garrow pulls enemies into one knot; Ilse's fire and Maren's split arrows and Arrow Storm hit the whole knot at once | Area and split-hit relics; Wide (sigil), Grasping (sigil) |
| 9 | **Last Stand:** Brannoc (Last Watch → Martyr's Pyre), Vell (Lanternbearer → The Beacon), Ilse (Wildfire → Ring of Fire) | Clump and Sustain | Brannoc's taunts hold enemies in a clump at his feet; Vell keeps him hovering at low HP; Ilse burns the clump | Second Dawn, healing relics; Last Breath, Warding Thread |
| 10 | **Gallery:** Aldous (Windcaller → Long Wind), Maren (Deadeye → Eagle Eye), Brannoc (Hearthwall → The Unbroken Gate) | Rangers | Brannoc's wall keeps enemies far away; Long Wind pays off distance; Deadeye shoots from 6 hexes | Ranged-damage and crit relics; Steady Stance, Fletched for Wings, Hold your ground (tactic) |

### Engine builds

| # | Team | Build | Why it should work | Key relics and items |
| --- | --- | --- | --- | --- |
| 11 | **Blood Price:** Severine (Hemomancer → Blood Tide or Blood Rite), Vell (Lanternbearer → Dawnbringer), Garrow (Spitemail → Thorned King) | Sustain | Vell's heals push Severine above 50% HP, and every point above the line becomes an Exsanguinate. Garrow takes the hits and returns them | Healing and lifesteal relics, MGK relics; Leech Fang |
| 12 | **Shadow:** Tamsin (Nightblade → Phantom), Lucan (Veilweaver → Unseen Host), Maren (Deadeye → Stormline) | Stealth | Lucan hides whoever is threatened, and every first strike from Stealth hits harder and Silences. Tamsin lives in Stealth; Maren's hop hides her too | Veil of the Lost, Shadow Engine, Smoke Pouch; Shadow Step, Veiled (sigil), Smoke Vial |
| 13 | **Host:** Lucan (Puppeteer → Grand Puppeteer), Kestra (Packleader → Alpha), Severine (Plaguebearer → Gravecaller) | Summons | Severine's thralls, Kestra's hounds, and Lucan's copies fill the field; Puppeteer and Packleader both grow with every summon | Relics that buff allies; Last Breath |
| 14 | **Mirror Volley:** Lucan (Mirrorwright → True Reflection), Maren (Volley → Hailstorm), Ilse (Ember Choir → Cinder Saint) | Summons and Burn | Hall of Mirrors copies Maren's split arrows; every copy's hit carries Ember Choir's Burn | Ember Heart, Ashen Engine; Echo (sigil) on Lucan |
| 15 | **Choir:** Aldous (Chorister → Grand Chorus), Edric (Psalmist → Evensong), Vell (Vigil Keeper → Sanctifier) | Mana | Aldous shares mana, Edric turns broken Shields into mana and signatures into Shields, and Vell's Sunfall fires as often as the mana allows | The Second Sun, Overcharge; Echo, Opener, Thrift (sigils) |

### Economy builds

| # | Team | Build | Why it should work | Key relics and items |
| --- | --- | --- | --- | --- |
| 16 | **Bounty:** Hob (Bounty Hunter → Manhunter), Tamsin (Headhunter → Executioner), Garrow (Aegisfang → Shatterburst) | Economy and Mark | Hob's Bounty is a permanent Mark on the toughest enemy, which Tamsin executes; Garrow holds the line. Money plus a boss killer | Money relics, Mark relics |
| 17 | **Full Greed:** Hob (Hoarder → Golden Idol), Edric (Tithe-Collector → Collector of Debts), Ottilie (Transmuter → Midas Touch) | Economy (stress test) | Three money makers. This team should be weak early and rich late. It tests whether greed ever pays off, and whether it pays off too much | Money relics only |

### Bonds in each synergy team

| Team | Bond (relic) |
| --- | --- |
| 1 Thicket | Dragged to the Snare (The Snaring Chain) |
| 2 Hunt | The Hunter's Bell (Death's Appointment); Toll and Judgment (The Toll of Dawn) |
| 3 Pyre | Burning Volley (Fire on the Wind) |
| 4 Furnace | The Bellows (Bellows of the Wind) |
| 5 Rot | Putrefaction (Plague Alchemy) |
| 6 Venom | Nest of Rot (Mother of Serpents) |
| 7 Bulwark | Woven Fang (The Woven Fang) |
| 8 Whirlpool | The Firepit (The Firepit) |
| 9 Last Stand | Lantern Vigil (The Vigil Lamp) |
| 10 Gallery | Sentry and Sniper (The Watchtower) |
| 11 Blood Price | Blood and Lamplight (The Lamp of Ichor) |
| 12 Shadow | Unseen Blade (The Shroud of Knives) |
| 13 Host | The Menagerie (The Menagerie) |
| 14 Mirror Volley | Hall of Arrows (Mirror Step); Burning Volley (Fire on the Wind) |
| 15 Choir | Psalm and Chorus (The Psalter) |
| 16 Bounty | Price and Prey (The Contract) |
| 17 Full Greed | Tithe and Hoard (The Counting House) |

- **Bond relics are part of the test:** bots buy a team's bond relic when it shows up. Also run each team with bond relics turned off, to see how much a bond decides a run.

---

## 2. Bad teams (expected to lose to random)

| # | Team | Why it should be bad | What a good result looks like |
| --- | --- | --- | --- |
| B1 | **Glass:** Ilse (Furnace), Ottilie (Catalyst), Lucan (Puppeteer) | Three fragile back-liners, no front line, no protection | Loses early fights to flankers (Rift Hounds, Bog Lurkers) |
| B2 | **No makers:** Tamsin (Headhunter), Ottilie (Catalyst), Lucan (Puppeteer) | Three payoffs with nothing to pay off: no Marks, no Burn or Poison, almost no summons | Each payoff's deed and bonus barely move |
| B3 | **Crossed wires:** Severine (Hemomancer), Aldous (Chorister → Wellspring), Hob (Fence) | Wellspring does nothing for Hemomancer (she has no mana); Fence wants spending, Hemomancer wants HP | Below random; Aldous's deed fills slowly |
| B4 | **Wrong fuel:** Garrow (Aegisfang), Severine (Bloodglut), Kestra (Packleader) | No team Shields for Garrow, no healing or summons beyond Grit, three melee fighters with no ranged support | Below random against archers and casters |
| B5 | **All tanks:** Brannoc (Hearthwall), Garrow (Spitemail), Edric (Aegis) | Lots of survival, very little damage; fights run long and the collapse wins | Long fights, ties, losses to Rift Collapse |

---

## 3. Notes

- **Each team covers different heroes** on purpose: every hero appears in at least two synergy teams, so a weak hero shows up across builds rather than in one comp.
- **The proposed build relics** (Tally Drum, Pyre Banner, Shieldbearer's Oath; Iron Garden replaced Huntsman's Horn, 2026-10-08) aren't in the relic files yet (`build-map.md`, section 5). Run once without them, and again once they're added, to see how much they matter.
- **Combo fixtures** (part 7, section 7) test single combos in one fight; these teams test whole runs. A team that fails here but whose fixture passes means the run doesn't deliver the pieces (shops, picks, economy), not that the combo is broken.
- **Data shape** for `tools/sim_teams.json` (a proposal): each team has a name, a group (synergy or bad), three hero and vow pairs, an apex vow for each, and a list of relic and item ids to lean toward.
