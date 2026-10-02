# Changes: Ottilie, the eleventh hero (the alchemist)

Decided 2026-10-02. This adds Ottilie Brack, a back-line caster who throws vials. Catalyst gives Burn and Poison their second payoff hero (and a payoff for mixing the two). Transmuter and Apothecary make Economy and Mana three-hero builds. It also adds a build-map rule: Economy and Mana, wanted in every run, need three or more heroes so no hero is mandatory.

Each section below is one file. **Replace** means swap the quoted text for the new text, **Add** means insert it where stated, and **Remove** means delete it. Paths are from the repo root. Apply after `changes-edric.md` (and the files it depends on).

---

## 1. `docs/plans/rebuild-heroes.md` (part 2)

**Add** a new section after Edric's section (8h), before "## 9. How the heroes fit together":

```markdown
## 8i. Ottilie Brack: the alchemist (caster)

*Added 2026-10-02.* **Role:** back-line caster who throws vials of fire and venom. Shares the damage role. Builds (`build-map.md`): Burn and Poison (payoff, Catalyst), Economy (maker, Transmuter), Mana (maker, Apothecary).

| | |
| --- | --- |
| **Stats** | HP 280, ATK 8, MGK 18, DEF 10 |
| **Speed / range** | speed 2, up to 3 hexes |
| **Basic attack: Toss** | a vial at the nearest enemy in range (MGK damage); her main source of mana |
| **Signature: Volatile Flask** (60 mana) | bursts on a 1-hex circle around her target: 120% of her MGK, plus Burn and Poison each equal to 20% of her MGK |
| **Passive: Brewing** | every 4s, her next Toss is a fire vial (Burn equal to 20% of her MGK) or a venom vial (Poison, the same amount), alternating |

**Her vials ride on her attacks:** Brewing, and Apothecary's mana vials, trigger on her *next Toss* after their timer, never on a free timer. With nothing in range, no vials fly.

### Path 1: Catalyst (Burn and Poison: payoff)

The fantasy: two poisons are worse than one, and she knows exactly how much worse.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Reaction:** +1% damage per 5 Burn and Poison on her target, combined (up to +10%) | +1% damage per 2 Burn and Poison on the target, with no cap, and +25% damage against enemies with both |
| **Signature** | Volatile Flask | **Reaction Flask:** hits her target and enemies within 1 hex for 100% of her MGK plus 3 per Burn and Poison on each. It reads them without using them up |
| **Cost** | –10% max HP | Brewing stops |

- **Deed:** extra damage from Reaction.
- **Reads totals, never sources** (section 5).
- **Plays off:** teams applying both Burn and Poison (Ilse with Severine, Tamsin's Poisoned Blades, the Burn relics). The only payoff for mixing the two.

### Path 2: Transmuter (Economy: maker)

The fantasy: lead into gold, and the dead into coin.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Gilded Death:** an enemy that dies while both Burning and Poisoned pays 1 shard (up to 3 per fight) | It pays 2 shards (up to 8 per fight), and once per shop she can turn an item you own into shards at its full price |
| **Signature** | Volatile Flask | **Philosopher's Flask:** hits her target and enemies within 1 hex for 120% of her MGK, plus Burn and Poison each equal to 20% of her MGK; enemies it kills pay 2 shards |
| **Cost** | –10% max HP | Brewing slows to every 6s |

- **Deed:** shards from Gilded Death.
- **Unlike Hob and Edric:** she earns from enemies dying while both Burning and Poisoned, and by transmuting items at full price (shops normally pay half).

### Path 3: Apothecary (Mana: maker)

The fantasy: a vial for the foe, and a tonic for the friend.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Tonic:** every 8s, her next Toss also throws a mana vial to the ally with the least mana (+10 mana) | Every 4s, her next Toss also throws a mana vial to the ally with the lowest mana (by %): +20 mana and +10% attack speed for 3s. Brewing stays |
| **Signature** | Volatile Flask | **Elixir:** every ally gains 30 mana, plus +10% ATK and MGK for 4s |
| **Cost** | –10% MGK | Toss deals 15% less damage |

- **Deed:** mana given by Tonic.
- **Unlike Aldous and Edric:** Aldous shares his own mana income, Edric gives mana when Shields break; Ottilie delivers it with her attacks, to whoever needs it most.

- **Upgrade pool:** `upgrade-pools.md`. **Apexes:** `apexes.md`.
```

**Add** a row to the mana table in section 4:

```markdown
| Ottilie | 60 | +10 | none | 2/s | 0 |
```

**Add** to section 9 ("How the heroes fit together"):

> - **Ottilie bridges the damage-over-time heroes:** Brewing adds both Burn and Poison to any team, and Catalyst cashes in Ilse's Burn and Severine's Poison together. Transmuter and Apothecary give every team a third choice for shards and mana.

---

## 2. `docs/plans/apexes.md` (created by `changes-apexes.md`)

**Add** a new section after Edric's section, before "## Notes":

```markdown
## Ottilie

| Apex | Taste (on vow) | Deed | The apex | Upgrades |
| --- | --- | --- | --- | --- |
| **Grand Reaction** (Catalyst) | Reaction Flask's splash reaches 2 hexes | Damage dealt by Reaction Flask | Enemies with both Burn and Poison take +25% damage from everyone. **Snowball:** each enemy that dies with both makes that bonus +20% bigger for the rest of the fight | **Chain Reaction:** +30% per kill. **Volatile:** such enemies explode when they die, dealing 50% of her MGK within 1 hex |
| **Solvent** (Catalyst) | Her hits add 1 to whichever of Burn or Poison is smaller on the target | Stacks added by Solvent | Each hit raises the smaller of Burn or Poison on the target by 20% of the larger, so Catalyst's "both" bonuses always apply. No snowball | **Saturate:** 30% of the larger. **Dissolve:** her hits on enemies with both ignore 20% of their DEF |
| **Midas Touch** (Transmuter) | Gilded Death pays up to 4 shards per fight, not 3 | Shards from Gilded Death | Enemies dying with either Burn or Poison pay 1 shard, with both 3, capped at 12 per fight. **Run snowball (money):** every 20 shards from it raises that cap by 1 for the rest of the run, up to 20 | **Golden Fever:** every 15 shards. **Gilt Flask:** Philosopher's Flask kills pay 3 |
| **Grand Transmutation** (Transmuter) | Once per act, she can transmute an item into a random item of the same kind | Items transmuted into items | She can transmute 2 items per shop at full price, and turning an item into another item gives it at rank II. No snowball | **Philosopher's Gold:** transmuting pays 125% of the price. **Endless Lab:** 3 per shop |
| **Panacea** (Apothecary) | Tonic gives 5 more mana | Mana given by Tonic | Her vial-carrying Toss throws vials to the 2 lowest-mana allies, 25 mana each, and an ally who drinks one gets a 20% stronger next signature. No snowball | **Strong Draught:** 30 mana per vial. **Potent:** +25% to the next signature |
| **Mana Flood** (Apothecary) | Elixir gives 10 more mana | Mana given by Elixir | Elixir gives 50 mana, and for 6s allies' signatures cost 30% less. **Snowball:** each ally signature during that window makes it last 1s longer | **Long Flood:** +2s per signature. **Potent Elixir:** Elixir's ATK and MGK bonus is +20% |
```

**Add** to "Notes":

> - **Grand Transmutation works on items only:** the Magpie stays the only place to sell a relic (`magpie.md`).
> - **Mana Flood loops** with Aldous's Chorister and Edric's Psalmist: more signatures stretch the window, the window makes signatures cheaper.

---

## 3. `docs/plans/upgrade-pools.md` (created by `changes-upgrade-pools.md`)

**Add** a new section after Edric's section, before "## Left out on purpose":

```markdown
## Ottilie

### Hero pool

These never give damage from Burn and Poison counts (Catalyst), shards (Transmuter), or mana to allies (Apothecary). Vial upgrades ride on her next Toss, like Brewing.

| Upgrade | Effect |
| --- | --- |
| **Steady Hand** | MGK +10% of her current MGK (stacks) |
| **Quick Pour** | Attack speed +10% of her current attack speed (stacks) |
| **Leather Apron** | Max HP +10% of her current max HP (stacks) |
| **Thick Gloves** | DEF +10% of her current DEF (stacks) |
| **Quick Brew** | Brewing every 3s, not 4s |
| **Strong Brew** | Brewing's vials apply 30% of her MGK, not 20% |
| **Wide Flask** | Volatile Flask's circle is 1 hex larger |
| **Quick Flask** | Volatile Flask costs 10 less mana |
| **Long Toss** | Toss reaches 4 hexes |
| **Sticky Vials** | Brewing's vials Slow 15% for 1s |
| **Acrid Fumes** | Enemies within 1 hex of her deal 10% less damage |
| **Notebook** | Grows: +1% MGK per 50 vials brewed, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Catalyst** | **Sharp Reaction:** Reaction counts every 4, up to +12%. **Mixed Flask:** Volatile Flask's Burn and Poison are 25% of her MGK | **Strong Reaction:** +35% against enemies with both, not +25%. **Heavy Flask:** Reaction Flask adds 4 per Burn and Poison, not 3. **Quick Reaction:** Reaction Flask costs 10 less mana. **Corrosive:** enemies with both have 15% less DEF. Growing: **Lab Notes** (+1% to Reaction's bonus per 1,000 Reaction damage) |
| **Transmuter** | **Assayer:** Gilded Death pays 1 more after elites. **Coin Flask:** Volatile Flask kills pay 1 shard | **Strong Philosopher:** Philosopher's Flask hits for 150% of her MGK. **Quick Philosopher:** it costs 10 less mana. **Appraise:** transmuting a rank II or III item pays 2 or 4 more shards. **Deep Purse:** Gilded Death's cap is 10. Growing: **Ledger** (+1 shard per won fight per 30 shards from Gilded Death, up to +5) |
| **Apothecary** | **Rich Tonic:** the vial gives 12 mana, not 10. **Quick Tonic:** every 6s, not 8s | **Fast Tonic:** every 3s, not 4s. **Fizzing Vial:** the vial's attack speed bonus is +15%. **Bracing Vial:** the vial also gives +10 DEF for 3s. **Long Elixir:** Elixir's bonus lasts 6s. Growing: **Recipe Book** (+1 mana per vial per 100 vials thrown, up to +10) |
```

**Add** to "Keyword sources this adds":

> - **Burning and Poisoned:** Brewing (Ottilie's base kit) applies both on every path.

---

## 4. `docs/plans/economy.md` (created by `changes-economy.md`)

**Add** a row to the Income table:

```markdown
| **Ottilie** (Transmuter) | Gilded Death (enemies dying while both Burning and Poisoned), Philosopher's Flask kills, and transmuting an item at full price once per shop |
```

---

## 5. `docs/plans/build-map.md` (created by `changes-build-map.md`)

**Add** to section 2's "Rules for the roster", as rule 6:

> 6. **Builds every run wants need three or more heroes.** Economy and Mana are wanted in every run, whatever the build, so they need makers on at least three heroes. Then no single hero becomes the always-pick.

In section 3's table:

- **Burn row:** "Payoffs now" → `Ilse (Furnace); Catalyst, Grand Reaction, Solvent (Ottilie)`. "What's missing" → `A Burn maker on a second hero (paths: Ilse only; Ottilie's Brewing helps but is base kit)`.
- **Poison row:** "Payoffs now" → `Plaguebearer, Pestilence (Severine); Catalyst, Grand Reaction, Solvent (Ottilie)`. "What's missing" → `A Poison maker on a second hero (paths: Severine only; Ottilie's Brewing helps but is base kit)`.
- **Mana row:** "Makers now" → `Chorister, Wellspring (Aldous); Psalmist, Choir of Wards, Evensong (Edric); Apothecary, Panacea, Mana Flood (Ottilie)`. "What's missing" → `Covered: three heroes`.
- **Economy row:** "Makers now" → `Hob; Tithe-Collector, Collector of Debts (Edric); Transmuter, Midas Touch, Grand Transmutation (Ottilie); money relics`. "What's missing" → `Covered: three heroes`.

**Replace** in Open questions (as set by `changes-edric.md`):

> - **Single-hero builds left (rule 5):** Burn payoff (Ilse only), Poison payoff (Severine only), Stealth payoff (Tamsin only), and Summons (Severine's Gravecaller only, no payoff). Planned: **the alchemist** (Catalyst path: the second Burn and Poison payoff) and **the illusionist** (Summons maker and payoff, Stealth payoff).

with:

> - **Single-hero builds left (rule 5):** Stealth payoff (Tamsin only), Summons (Severine's Gravecaller only, no payoff), Burn makers (Ilse only), and Poison makers (Severine only). Planned: **the illusionist** (Summons maker and payoff, Stealth payoff); a later hero for the Burn and Poison makers.

---

## 6. `CLAUDE.md`

**Replace** in "The design the rebuild builds toward", the heroes bullet (as set by `changes-edric.md`):

> and Edric (the team shielder)

with:

> Edric (the team shielder), and Ottilie (the alchemist)
