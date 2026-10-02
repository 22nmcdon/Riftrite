# Changes: the full set of duo bonds and bond relics

Decided 2026-10-02. With 13 heroes, the duo bonds get written against the real roster. There are **24 bonds**: every path has 1 or 2, and **every synergy team in `test-teams.md` has at least one**. Each bond relic ties the two paths' own mechanics together, so it plays like those two heroes working as a pair, not as a generic boost to a build. That needs one rule change: **bond relics may name the bonded paths' mechanics.** Of the three old Act 1 drafts, Sentry and Sniper stays (reworked), and Snare and Cleave and Light and Iron are replaced.

Each section below is one file. **Replace** means swap the quoted text for the new text, **Add** means insert it where stated, and **Remove** means delete it. Paths are from the repo root. Apply after `changes-kestra.md` (step 21 in `apply-order.md`), with `test-teams.md` already in `docs/plans/`.

---

## 1. `docs/plans/duo-bonds.md` (created by `changes-duo-bonds.md`)

**Replace** the rule bullet:

> - **The only way to get a bond relic is to have its bond.** A bond relic is still team-wide and follows every relic rule (`relics/README.md`); only who can *get* it depends on the heroes. Its effect should play off both paths' mechanics.

with:

> - **The only way to get a bond relic is to have its bond.** It follows the relic rules (`relics/README.md`) with **one exception: a bond relic may name the bonded paths' mechanics** (snares, Haul, Sentence, Grit, and so on). Both heroes are guaranteed to be on the team and transformed, so it can be about them. It should make the two paths work as a pair, often as a small loop between them, not boost the build in general.

**Replace** in "How many":

> - **With three heroes, only a few exist** (3 for the Act 1 slice). They grow as heroes are added; with about 6 heroes, the full set gets written against the real roster.

with:

> - **With 13 heroes, there are 24 bonds:** every path has 1 or 2. New heroes add bonds for their own paths, keeping to 1–2 per path.
> - **Every synergy team in `test-teams.md` has at least one bond.**

**Replace** the whole section "## The Act 1 bonds (drafts)" (its heading and table) with:

```markdown
## The bonds

Each bond links two paths of two different heroes. Its relic ties their mechanics together.

### Keyword bonds

| Bond | Paths | Bond relic | What it implies |
| --- | --- | --- | --- |
| **Dragged to the Snare** | Chainwarden (Garrow) + Trapper (Maren) | **The Snaring Chain:** each enemy Garrow pulls with Haul or Maelstrom drops onto a fresh snare where it lands (Maren's snare rules) | His chains drag them into her traps |
| **Hold and Break** | Garrote (Tamsin) + Ironbrand (Brannoc) | **Hammer and Wire:** Tamsin's Garrote can grab any enemy Stunned by Brannoc's knockbacks within 4 hexes (she steps to it), and Garrote on a Stunned enemy hits twice as often | He knocks them senseless; she's already behind them |
| **Price and Prey** | Bounty Hunter (Hob) + Headhunter (Tamsin) | **The Contract:** Bounties Tamsin kills pay double, and when a Bounty dies, Tamsin steps straight to the new Bounty and her next attack is a crit | He names the price; she collects |
| **The Hunter's Bell** | Bellwarden (Aldous) + Headhunter (Tamsin) | **Death's Appointment:** whenever Death Knell rings, Tamsin's Sentence is ready at once, and it can strike any Marked enemy on the field | The bell tolls; she answers it |
| **Toll and Judgment** | Bellwarden (Aldous) + Vigil Keeper (Vell) | **The Toll of Dawn:** each Death Knell also fires Vell's Sunfall along its target's line at half strength, and her smites jump to every enemy the bell Marked | His bell calls down her light |
| **Burning Volley** | Ember Choir (Ilse) + Volley (Maren) | **Fire on the Wind:** Maren's split arrows always carry Hymn of Cinders' Burn (20% of Ilse's MGK), and Arrow Storm rains fire: enemies under it gain that Burn each second | Ilse's blessing rides on every arrow |
| **The Bellows** | Furnace (Ilse) + Windcaller (Aldous) | **Bellows of the Wind:** Ilse always counts as attacking from range for Tailwind, and every enemy Gale knocks back is Stoked (its Burn grows by 25%) | His wind fans her fire |
| **Gilded Ash** | Transmuter (Ottilie) + Cinderhound (Kestra) | **The Gilded Hound:** Grit's bites count as Poison for Ottilie's Gilded Death (a Burning enemy he bit counts as both), and Grit fetches 1 shard each time he kills | The hound brings back gold |
| **Putrefaction** | Catalyst (Ottilie) + Plaguebearer (Severine) | **Plague Alchemy:** Plague Burst also applies Burn equal to its Poison, and Severine's lifesteal is tripled against enemies with both | Ottilie's reagents in Severine's cloud |
| **Nest of Rot** | Plaguebearer (Severine) + Serpent-Keeper (Kestra) | **Mother of Serpents:** each enemy that dies inside Plague Burst hatches a viper (Nest's rules) for 6s, and Severine's lifesteal is doubled against enemies a viper has bitten | Her plague feeds Kestra's brood |

### Defense and control bonds

| Bond | Paths | Bond relic | What it implies |
| --- | --- | --- | --- |
| **Sentry and Sniper** | Hearthwall (Brannoc) + Deadeye (Maren) | **The Watchtower:** while Maren stands within 2 hexes behind Brannoc's wall, she's always planted (no plant time), Heartseeker passes through the wall with +30% damage, and each arrow the wall blocks gives her 5 mana | She shoots from behind his wall |
| **Woven Fang** | Aegisfang (Garrow) + Wardweaver (Vell) | **The Woven Fang:** Vell's Weave on Garrow ignores his Shield cap, and when Bulwark Burst fires, Vell casts a free Weave on him | She reloads his armor every time he spends it |
| **Watched Over** | Aegis (Edric) + Last Watch (Brannoc) | **The Last Ward:** Hallow always goes to Brannoc first while he's below 30% HP, and while he's Shielded below 30%, his Last Watch ATK and DEF bonuses are doubled | Edric keeps the martyr standing at the edge |
| **The Firepit** | Chainwarden (Garrow) + Wildfire (Ilse) | **The Firepit:** every Maelstrom starts Ilse's burning ground under the crowd it pulls, and Crowd Strength counts Burning enemies twice | He drags them into her fire |
| **Lantern Vigil** | Last Watch (Brannoc) + Lanternbearer (Vell) | **The Vigil Lamp:** while Brannoc is below 30% HP, Vell's lantern follows him, and her heals on him never lift him above 30%; the extra becomes Shield instead | She keeps him exactly where he's strongest |
| **Iron Hunger** | Bloodglut (Severine) + Spitemail (Garrow) | **The Iron Maw:** while Severine is within 2 hexes of Garrow, damage he sends back also heals her as lifesteal (feeding Engorge), and every max HP she gains from Engorge, he gains too | He takes the blows; she drinks them |
| **Unseen Blade** | Nightblade (Tamsin) + Veilweaver (Lucan) | **The Shroud of Knives:** Shroud picks Tamsin first whenever she's out of Stealth, and each of her kills makes every hidden ally stay hidden 1s longer | He covers her; her kills cover everyone |

### Engine bonds

| Bond | Paths | Bond relic | What it implies |
| --- | --- | --- | --- |
| **Blood and Lamplight** | Hemomancer (Severine) + Lanternbearer (Vell) | **The Lamp of Ichor:** each Exsanguinate gives Vell 10 mana, and Vell's Mend always goes to Severine when she's at or below 50% HP, healing her 50% more | She bleeds, Vell refills her, she casts again |
| **Psalm and Chorus** | Chorister (Aldous) + Psalmist (Edric) | **The Psalter:** when any Shield on an ally breaks, Aldous also gains that mana (and shares half, as Chorister does), and Crescendo gives every ally a Shield equal to the mana it gave | Breaking wards and swelling song feed each other |
| **Tonic and Hymn** | Apothecary (Ottilie) + Chorister (Aldous) | **The Tonic Choir:** Ottilie's mana vials also give Aldous the same mana (which he shares on), and Crescendo makes Ottilie's next 3 Tosses throw vials | Her tonics, his chorus |
| **The Menagerie** | Puppeteer (Lucan) + Packleader (Kestra) | **The Menagerie:** Lucan's copies count as hounds for Pack Call and Pack Fury, and Kestra's hounds count twice for Strings | Puppets and beasts, one pack |
| **Hall of Arrows** | Mirrorwright (Lucan) + Volley (Maren) | **Mirror Step:** each time Maren hops, she leaves a copy of herself where she stood for 3s, at 40% of her stats, firing split arrows (it counts toward Lucan's copy limit) | She vanishes; her reflection keeps shooting |

### Economy bonds

| Bond | Paths | Bond relic | What it implies |
| --- | --- | --- | --- |
| **Tithe and Hoard** | Hoarder (Hob) + Tithe-Collector (Edric) | **The Counting House:** shards from Edric's Tithe count double for Hob's Nest Egg until they're spent, and Edric's Ward Shields grow by 1% per 5 shards Hob holds | Edric collects; Hob hoards |
| **Black Market Ledger** | Fence (Hob) + Transmuter (Ottilie) | **The Black Market Ledger:** when Ottilie transmutes an item, its full price counts as shards spent for Hob's Fence bonus, and each transmute gives a free reroll in that shop | She turns goods to gold; he turns gold to power |

### Coverage

Every path has 1 or 2 bonds:

| Bonds | Paths |
| --- | --- |
| **2** | Volley, Last Watch, Lanternbearer, Headhunter, Chainwarden, Chorister, Bellwarden, Plaguebearer, Transmuter |
| **1** | Deadeye, Trapper, Hearthwall, Ironbrand, Wardweaver, Vigil Keeper, Furnace, Wildfire, Ember Choir, Nightblade, Garrote, Aegisfang, Spitemail, Windcaller, Hoarder, Fence, Bounty Hunter, Bloodglut, Hemomancer, Aegis, Tithe-Collector, Psalmist, Catalyst, Apothecary, Mirrorwright, Veilweaver, Puppeteer, Cinderhound, Serpent-Keeper, Packleader |
```

**Replace** in Open questions:

> - **The Act 1 three:** all three include Brannoc. Should Vell and Maren get one of their own?

with:

> - **Bond relic strength:** they're free, and several create loops between two heroes. The test teams (with and without bond relics) show whether one decides runs on its own.
> - **New things the sim needs from bonds:** Severine's Exsanguinate giving Vell mana (Blood and Lamplight), Maren's hop leaving a copy (Mirror Step), and heals capped below a threshold with the rest turned into Shield (Lantern Vigil).

---

## 2. `docs/plans/relics/README.md`

**Replace** in the Bond row of the tier table (as added by `changes-duo-bonds.md`):

> | 3 (Act 1) |

with:

> | 24 |

**Replace** the rule bullet (as added by `changes-duo-bonds.md`):

> - **Bond relics** are the one kind whose availability depends on the heroes: only a run with that duo bond can find one. What they do is still team-wide.

with:

> - **Bond relics** are the one kind tied to heroes: only a run with that duo bond can find one, and a bond relic may name the bonded paths' mechanics (`../duo-bonds.md`). Every other relic stays team-wide and never names a hero.

---

## 3. `docs/plans/test-teams.md`

**Add** a section after section 1 ("Synergy teams"):

```markdown
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
```

---

## 4. `CLAUDE.md`

**Replace** the `duo-bonds.md` row's description in the plan table:

> duo bonds as keys to free bond relics, and the Act 1 drafts

with:

> duo bonds as keys to free bond relics that make two paths work as a pair: 24 bonds, 1–2 per path, at least one in every synergy team
