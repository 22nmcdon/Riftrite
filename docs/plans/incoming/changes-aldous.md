# Changes: Aldous, the seventh hero (the battery)

Decided 2026-10-02. This adds Aldous Vesper, a back-line support who powers the team up rather than healing it. He is the third hero from the build map's roster plan and fills Mana (maker, Chorister), Rangers (support, Windcaller), and a third Mark maker (Bellwarden).

Each section below is one file. **Replace** means swap the quoted text for the new text, **Add** means insert it where stated, and **Remove** means delete it. Paths are from the repo root. Apply after `changes-garrow.md` (and the files it depends on).

---

## 1. `docs/plans/rebuild-heroes.md` (part 2)

**Add** a new section after Garrow's section (8d), before "## 9. How the heroes fit together":

```markdown
## 8e. Aldous Vesper: the bell-ringer (support)

*Added 2026-10-02.* **Role:** back-line support who powers the team up rather than healing it. Shares the support role with Vell. Builds (`build-map.md`): Mana (maker), Rangers (support), Mark (maker).

| | |
| --- | --- |
| **Stats** | HP 290, ATK 10, MGK 16, DEF 10 |
| **Speed / range** | speed 2, up to 3 hexes |
| **Basic attack: Toll** | a ringing note at the nearest enemy in range (MGK damage); his main source of mana |
| **Signature: Peal** (60 mana) | allies within 3 hexes gain +15% attack speed for 4s |
| **Passive: Resonance** | allies within 2 hexes of him get +5% attack speed |

His base kit gives no mana to allies, has no ranged-ally bonus, and never Marks: each path's deed needs its taste.

### Path 1: Chorister (Mana: maker)

The fantasy: his breath becomes the whole band's breath.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Shared Breath:** when he fires his signature, the ally with the least mana gains 15 mana | Each time he gains mana, allies within 3 hexes gain half as much |
| **Signature** | Peal | **Crescendo:** allies within 3 hexes gain 40 mana |
| **Cost** | –10% max HP | His own signature costs 20 more mana |

- **Deed:** mana given to allies.
- **Gives mana, never cheaper signatures** (that's the Thrift sigil's job).
- **Plays off:** heroes with strong mana signatures: Ilse (a second fuel beside Heat), Vell, Tamsin's Sentence, and anyone holding Echo or The Second Sun.

### Path 2: Windcaller (Rangers: support)

The fantasy: the wind carries his allies' shots and keeps the enemy off them.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Tailwind:** allies attacking from 3 or more hexes away get +5% attack speed | Allies attacking from 3+ hexes deal +20% damage, and their shots fly 50% faster |
| **Signature** | Peal | **Gale:** knocks back every enemy within 2 hexes of each ranged ally |
| **Cost** | –1 range | Peal and Resonance no longer reach melee allies |

- **Deed:** attacks allies make under Tailwind.
- **No range and no pierce:** extra range would let base Maren fill Deadeye's deed without the vow, and pierce belongs to Volley and Stormline. Windcaller buffs damage and shot speed, and protects the back line.
- **Plays off:** ranged heroes (Maren, Ilse, Vell), and Ember Choir (faster attacks, more Burn).

### Path 3: Bellwarden (Mark: maker)

The fantasy: the bell names who dies next.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Toll the Hour:** every 4th Toll Marks its target for 2s | Every Toll Marks its target for 3s, and enemies he Marks take an extra +5% damage |
| **Signature** | Peal | **Death Knell:** Marks every enemy within 3 hexes of his target for 5s |
| **Cost** | –10% MGK | Toll deals 20% less damage |

- **Deed:** Marks he applies.
- **Plays off:** Mark payoffs: Tamsin's Headhunter, Inquisitor (Vigil Keeper), Brand the Marked (Ironbrand), and the Mark relics.

- **Upgrade pool:** `upgrade-pools.md`. **Apexes:** `apexes.md`.
```

**Add** a row to the mana table in section 4:

```markdown
| Aldous | 60 | +10 | none | 2/s | 0 |
```

**Add** to section 9 ("How the heroes fit together"):

> - **Aldous makes everyone else better at what they already do:** more signatures (Chorister), stronger ranged allies (Windcaller), or Marks for the payoff heroes (Bellwarden).

---

## 2. `docs/plans/apexes.md` (created by `changes-apexes.md`)

**Add** a new section after Garrow's section, before "## Notes":

```markdown
## Aldous

| Apex | Taste (on vow) | Deed | The apex | Upgrades |
| --- | --- | --- | --- | --- |
| **Grand Chorus** (Chorister) | Allies within 3 hexes gain 5% more mana from every source | Ally signatures fired within 3 hexes of him | Crescendo also makes each ally's next signature 30% stronger. **Snowball:** for the rest of the fight, whenever any ally fires a signature, every ally gains 4 mana, so signatures bring the next ones sooner | **Rising Chorus:** 6 mana per signature. **Encore:** Crescendo gives him back 20 mana |
| **Wellspring** (Chorister) | Allies can hold up to 120% of their max mana | Mana allies gain past full | **Allies' mana has no cap.** Signatures still cost their normal amount, and while an ally holds mana above full, their signature is +1% stronger per 2 extra mana. **Snowball:** each ally signature fired while over full makes his mana sharing (Chorister's half-share) +10% bigger for the rest of the fight | **Deep Reservoir:** +15% per signature. **Overflowing Start:** allies start each fight with 20 mana over full |
| **Long Wind** (Windcaller) | Ranged allies deal +1% damage per hex between them and their target | Damage ranged allies deal from 4 or more hexes | Ranged allies deal +5% damage per hex of distance to their target. **Snowball:** each kill by a ranged ally from 3+ hexes gives every ranged ally +8% damage for the rest of the fight | **Far Wind:** +12% per kill. **Clear Air:** ranged allies ignore 20% of the target's DEF |
| **Singing Arrows** (Windcaller) | Every 5th shot by a ranged ally carries a Toll: extra damage equal to 10% of his MGK | Tolls carried by allies' shots | Every shot by a ranged ally carries a Toll for 20% of his MGK and gives him 2 mana. **Snowball:** each carried Toll makes the next Toll on that same enemy 5% stronger (it builds on each enemy and resets when it dies) | **Rising Pitch:** +8% per Toll. **Ringing Arrows:** carried Tolls Slow by 10% for 1s |
| **The Great Bell** (Bellwarden) | Death Knell's Marks last 1s longer | Enemies Marked by Death Knell | Death Knell Marks every enemy on the field for 5s, and they take +15% more damage. **Snowball:** each Death Knell makes Marks deal +5% more damage for the rest of the fight | **Deep Bronze:** +8% per Knell. **Ringing Ears:** Death Knell Slows every enemy it Marks by 20% for 3s |
| **Requiem** (Bellwarden) | When an enemy he Marked dies, enemies within 1 hex take damage equal to 20% of his MGK | Damage from his tolls | When any Marked enemy dies, the bell tolls: enemies within 2 hexes take damage equal to 100% of his MGK and are Marked. **Snowball:** each toll makes later tolls +15% stronger, for the rest of the fight | **Dirge:** +25% per toll. **Silent Toll:** tolls Silence for 1s |
```

**Add** to "Notes":

> - **Three Mark payoff apexes, three shapes:** Bloodtrail (Tamsin) grows Marks per kill, The Great Bell per cast of Death Knell, and Requiem turns Marked deaths into chain blasts.
> - **Long Wind gives no range,** so it stays clear of Deadeye's key mechanic; it pays for spacing instead.
> - **Grand Chorus can loop** in a team full of signatures; the 4 mana per signature is the number to tune.

---

## 3. `docs/plans/upgrade-pools.md` (created by `changes-upgrade-pools.md`)

**Add** a new section after Garrow's section, before "## Left out on purpose":

```markdown
## Aldous

### Hero pool

These never give mana to allies (Chorister), bonuses for ranged allies (Windcaller), or Marks (Bellwarden).

| Upgrade | Effect |
| --- | --- |
| **Bright Voice** | MGK +10% of his current MGK (stacks) |
| **Quick Rhythm** | Attack speed +10% of his current attack speed (stacks) |
| **Traveler's Coat** | Max HP +10% of his current max HP (stacks) |
| **Padded Vestments** | DEF +10% of his current DEF (stacks) |
| **Long Peal** | Peal lasts 2s longer |
| **Wide Peal** | Peal reaches allies within 4 hexes |
| **Strong Resonance** | Resonance gives +8% attack speed, not 5% |
| **Far Resonance** | Resonance reaches allies within 3 hexes |
| **Cracked Bell** | Toll Slows its target 15% for 1s |
| **Clear Note** | Toll deals +20% damage to enemies targeting an ally |
| **Steadying Hymn** | Peal also removes Slow from allies |
| **Old Rope** | Grows: +1% to Peal's attack speed bonus per 10 Peals, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Chorister** | **Deep Breath:** Shared Breath gives 25 mana, not 15. **Two Breaths:** Shared Breath reaches the 2 allies with the least mana | **Quick Crescendo:** Crescendo costs 10 less mana. **Wide Chorus:** his half-share of mana reaches allies within 4 hexes. **Kindled Chorus:** allies who gain mana from him get +5% ATK and MGK for 3s. **Full Voice:** Crescendo gives 50 mana, not 40. Growing: **Long Choir** (+1% to his half-share per 300 mana given) |
| **Windcaller** | **Steady Tailwind:** Tailwind gives +8% attack speed, not 5%. **Gusting:** under Tailwind, allies' shots fly 25% faster | **Strong Gale:** Gale knocks back 1 hex further. **Quick Gale:** Gale costs 10 less mana. **Eye of the Storm:** ranged allies take 10% less damage while no enemy is within 2 hexes of them. **Keen Wind:** ranged allies get +5 CRIT. Growing: **Prevailing Wind** (+1% damage for ranged allies per 500 attacks made under Tailwind) |
| **Bellwarden** | **Sharp Toll:** every 3rd Toll Marks, not every 4th. **Long Toll:** Toll the Hour's Marks last 3s | **Wide Knell:** Death Knell reaches 4 hexes. **Ringing Mark:** his Marks also Slow 10%. **Quick Knell:** Death Knell costs 10 less mana. **Heavy Toll:** Toll deals +30% damage to Marked enemies. Growing: **Bell Metal** (+1% to his Marks' damage bonus per 50 Marks he applies) |
```

**Add** to "Keyword sources this adds":

> - **Marked:** Bellwarden (Aldous) is the first path built to make Marks for others.

---

## 4. `docs/plans/build-map.md` (created by `changes-build-map.md`)

In section 3's table:

- **Mark row:** "Makers now" → `Bellwarden (Aldous); Maren's base Marking Shot`. "What's missing" → `Covered for now`.
- **Rangers row:** "Makers now" → `Windcaller (Aldous); Hearthwall (protects the back line)`. "What's missing" → `Covered for now`.
- **Mana row:** "Makers now" → `Chorister and Wellspring (Aldous); Vigilant (a Vell upgrade); charms`. "Payoffs now" → `Grand Chorus and Wellspring (Aldous); sigils (Echo); The Second Sun (boss relic); Ilse (Heat-fed casting)`. "What's missing" → `Covered for now`.

In section 4's table, **replace** the battery row's "Notes" cell with:

> **Designed: Aldous Vesper** (`rebuild-heroes.md`, section 8e)

**Replace** in Open questions (as set by `changes-garrow.md`):

> - **Which hero comes after Garrow:** the battery (Mana and Rangers, both still open).

with:

> - **Which hero comes after Aldous:** the blood warlock (Sustain's lifesteal payoff) or the scavenger (Economy).

---

## 5. `CLAUDE.md`

**Replace** in "The design the rebuild builds toward", the heroes bullet (as set by `changes-garrow.md`):

> and Garrow (the shield-bruiser)

with:

> Garrow (the shield-bruiser), and Aldous (the battery)
