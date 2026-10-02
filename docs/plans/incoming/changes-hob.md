# Changes: Hob, the eighth hero (the scavenger)

Decided 2026-10-02. This adds Hob Gleaner, a skirmisher who is weaker in a fight and makes the run richer. He is the fourth hero from the build map's roster plan and fills Economy (maker and payoff), plus a Mark maker (Bounty Hunter). Most of his apex snowballs last the whole run, not one fight: he's the long-game hero. It also adds the first "feat" deed (one Bounty collected) and a per-fight shard cap.

Each section below is one file. **Replace** means swap the quoted text for the new text, **Add** means insert it where stated, and **Remove** means delete it. Paths are from the repo root. Apply after `changes-aldous.md` (and the files it depends on) and `changes-economy.md`.

---

## 1. `docs/plans/rebuild-heroes.md` (part 2)

**Add** a new section after Aldous's section (8e), before "## 9. How the heroes fit together":

```markdown
## 8f. Hob Gleaner: the scavenger (skirmisher)

*Added 2026-10-02.* **Role:** a light mid-line skirmisher who picks at weak enemies and pockets what drops. **Deliberately weaker in a fight than the other heroes:** you give up power now for a richer run. Builds (`build-map.md`): Economy (maker and payoff), Mark (maker).

| | |
| --- | --- |
| **Stats** | HP 300, ATK 16, DEF 12, CRIT 10 |
| **Speed / range** | speed 3, sling at up to 2 hexes |
| **Basic attack: Sling Stone** | a stone at the nearest enemy in range; his main source of mana |
| **Signature: Grab** (50 mana) | darts to the lowest-HP enemy within 3 hexes and hits it for 150% of his ATK |
| **Passive: Pickings** | when an enemy dies within 2 hexes of him, +1 shard |

- **The cap:** everything Hob earns in one fight, from any source in his kit, is capped at **8 shards** (raised by some apexes). Without it, endless mode becomes infinite money.
- **Shards from the sim:** shards he earns in a fight are combat log entries (with their source, rule 4), and the run reads them after the fight. That's a new log kind: it needs an audit rule in `test_arena_log.gd` and a form on the board (a coin popping from the enemy).

### Path 1: Hoarder (Economy: payoff for saving)

The fantasy: the heavier the purse, the harder he hits.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Nest Egg:** +1% ATK and DEF per 10 shards held (up to +10%) | +1% ATK and DEF per 5 shards held, with no cap; allies get half as much |
| **Signature** | Grab | **Heavy Purse:** slams his target for his ATK plus 2 damage per shard held |
| **Cost** | –10% max HP | Rerolls cost him 1 more shard |

- **Deed:** extra damage from Nest Egg. Only Nest Egg turns held shards into damage.
- **The gamble:** every relic you buy makes him weaker.

### Path 2: Fence (Economy: payoff for spending)

The fantasy: everything has a price, and he always gets a better one.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Haggle:** the first reroll in each shop is free | Rerolls cost half (rounded down). **Every shard spent in a shop gives the team +0.1% ATK, MGK, and max HP for the rest of the run** |
| **Signature** | Grab | **Cut Purse:** a hit that makes the target drop 1 shard (once per enemy) and lowers its ATK by 15% for 4s |
| **Cost** | –10% ATK | Shops buy items back from him for a quarter of their price, not half |

- **Deed:** shards saved by Haggle. (Counting shards *spent* wouldn't need the taste: everyone spends.)

### Path 3: Bounty Hunter (Mark: maker; Economy)

The fantasy: every fight has a price on one head.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Bounty:** at the fight's start, the toughest enemy (most max HP) is a Bounty, Marked for 8s. Killing it while it's still Marked pays 2 shards | The toughest enemy is a Bounty, Marked for as long as it lives; when it dies, the next toughest becomes the Bounty. Each Bounty pays 3 shards |
| **Signature** | Grab | **Collect:** strikes the Bounty for 200% of his ATK, from anywhere within 4 hexes |
| **Cost** | –1 speed | –10% damage to enemies that aren't the Bounty |

- **Deed: collect 1 Bounty.** The first **feat deed**: one kill transforms him, but it needs planning (place your damage next to the toughest enemy, pick a fight where the kill is realistic, burst it within 8s).
- **Plays off:** Mark payoffs (Tamsin's Headhunter, Inquisitor, Aldous's Requiem, Brand the Marked): a Mark that never drops on the toughest enemy.

- **Upgrade pool:** `upgrade-pools.md`. **Apexes:** `apexes.md`.
```

**Add** a row to the mana table in section 4:

```markdown
| Hob | 50 | +8 | none | 2/s | 0 |
```

**Add** to section 2's rules ("The rules"):

> - **A deed can be a feat:** one hard thing done once (Bounty Hunter: collect 1 Bounty), instead of a running total. A feat must still need the taste, and must be something the player plans for (placement, fight choice).

**Add** to section 9 ("How the heroes fit together"):

> - **Hob trades fight power for run power:** Hoarder pays off saving, Fence pays off spending, and Bounty Hunter gives the Mark heroes a permanent target.

---

## 2. `docs/plans/apexes.md` (created by `changes-apexes.md`)

**Add** to "How apexes work":

> - **Run-long snowballs:** a hero built for the long game (Hob) can have a snowball that lasts the rest of the run instead of the fight. In-fight snowballs stay for carries and for money-making.

**Add** a new section after Aldous's section, before "## Notes":

```markdown
## Hob

| Apex | Taste (on vow) | Deed | The apex | Snowball | Upgrades |
| --- | --- | --- | --- | --- | --- |
| **Dragon's Hoard** (Hoarder) | Heavy Purse deals 3 damage per shard held, not 2 | Damage dealt by Heavy Purse | Nest Egg's bonus goes to every hero at full value, and adds +1% max HP per 5 shards | **Run:** each fight won while holding 30+ shards gives every hero +1% ATK, MGK, and max HP for the rest of the run | **Deep Vault:** +1.5% per fight. **Low Bar:** counts from 25 shards held |
| **Golden Idol** (Hoarder; the carry) | He starts each fight with a Shield of 2 per shard held | Shield gained from shards | +2 ATK per shard held. He starts each fight with a Shield of 10 per shard held; when it breaks, he gets +50% attack speed for 5s. New signature **Recast the Idol:** restores his Shield to 10 per shard held (replacing any smaller Shield) and strikes his target for 300% of his ATK | **Fight (Compounding):** each Recast makes his held shards count 10% more for the rest of the fight, toward everything that reads them (ATK, Shield, Nest Egg) | **Compound Interest:** +15% per cast. **Idol's Gaze:** while Shielded, enemies within 2 hexes deal 10% less damage |
| **Black Market** (Fence) | The first relic bought in each shop costs 2 shards less | Shards saved on relics | Every shop gets a second relic slot: a black-market relic one tier higher than normal, at its own tier's price | **Run:** each relic bought makes all relics 1 shard cheaper for the rest of the run, down to half price | **Volume Discount:** 2 shards cheaper per relic. **Smuggler's Route:** the black-market slot rerolls free once per shop |
| **Silver Tongue** (Fence) | Cut Purse lowers the target's ATK by 20%, not 15% | Enemies weakened by Cut Purse | Cut Purse hits every enemy within 2 hexes; each drops a shard and loses 25% ATK for 4s. His shard cap per fight rises to 12 | **Fight (money):** each shard taken makes Cut Purse cost 5 less mana for the rest of the fight (down to 15) | **Deft Touch:** 8 less mana per shard. **Light Fingers:** the cap rises to 15 |
| **Manhunter** (Bounty Hunter) | Collect deals +25% damage to Bounties | Damage dealt to Bounties | Two Bounties at once (the two toughest enemies), and Collect executes a Bounty below 20% HP | **Run:** each Bounty collected gives the team +1% damage against Bounties for the rest of the run (elites and bosses are usually the toughest) | **Hunting Party:** +2% per Bounty. **Dead or Alive:** Bounties are Slowed 20% |
| **Price on Their Heads** (Bounty Hunter) | Bounties pay 1 extra shard | Shards from Bounties | Every enemy is a Bounty worth 1 shard (the toughest is worth 5), with the cap at 12. Only the toughest is Marked | **Run (money):** each Bounty collected raises the toughest Bounty's pay by 1 for the rest of the run, up to 15 | **Blood Money:** +2 per Bounty, up to 20. **Reward Poster:** whoever kills a Bounty gains 10 mana |
```

**Add** to "Notes":

> - **Hob's snowballs mostly last the run:** Golden Idol (the carry) and Silver Tongue (money) are the in-fight exceptions.
> - **Dragon's Hoard grows per fight won, not as interest,** so it doesn't copy the Miser's Vault relic.
> - **Manhunter vs Price on Their Heads:** a run-long boss killer versus a run-long money engine.

---

## 3. `docs/plans/upgrade-pools.md` (created by `changes-upgrade-pools.md`)

**Add** a new section after Aldous's section, before "## Left out on purpose":

```markdown
## Hob

### Hero pool

These never give shard-based power (Hoarder), shop discounts or spending bonuses (Fence), or Bounties (Bounty Hunter).

| Upgrade | Effect |
| --- | --- |
| **Lean Muscle** | ATK +10% of his current ATK (stacks) |
| **Quick Sling** | Attack speed +10% of his current attack speed (stacks) |
| **Patched Coat** | Max HP +10% of his current max HP (stacks) |
| **Lucky Charm** | CRIT +25% of his current CRIT (stacks) |
| **Wider Pickings** | Pickings counts enemies dying within 3 hexes |
| **Long Grab** | Grab reaches 4 hexes |
| **Hard Grab** | Grab hits for 200% of his ATK |
| **Slippery Exit** | +1 speed for 3s after Grab |
| **Scavenger's Nose** | Grab goes for enemies below 30% HP within 5 hexes first |
| **Lucky Find** | Once per act, a won fight pays 5 extra shards |
| **Pocket Sand** | His crits Slow by 20% for 1s |
| **Well-Worn Sling** | Grows: +1% ATK per 20 shards from Pickings, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Hoarder** | **Deep Pockets:** Nest Egg's taste cap rises to +15%. **Penny Wise:** Nest Egg counts every 8 shards, not 10 | **Stunning Purse:** Heavy Purse Stuns for 0.5s. **Guarded Gold:** +10 DEF while holding 30+ shards. **Miser's Grip:** Heavy Purse costs 10 less mana. **Shared Wealth:** allies get 3/4 of Nest Egg's bonus, not half. Growing: **Old Coins** (+1% to Nest Egg's bonus per 5 fights won while holding 30+ shards) |
| **Fence** | **Second Haggle:** the second reroll in each shop costs 1 shard. **Quick Count:** Cut Purse costs 10 less mana | **Wholesale:** loadout items cost 1 shard less. **Fair Trade:** Cut Purse makes elites and bosses drop 2 shards. **Insider:** each shop shows one charm already at rank II. **Big Spender:** the per-shard team bonus is +0.15%. Growing: **Old Contacts** (+1 shard after each won fight per 5 shops visited, up to +5) |
| **Bounty Hunter** | **Wanted Poster:** the taste's Bounty Mark lasts 12s, not 8s. **Clear Sight:** +15% damage to the Bounty | **Long Arm:** Collect reaches 6 hexes. **Hunter's Rest:** collecting a Bounty heals him 15% of his max HP. **Tracker:** the team deals +10% damage to the Bounty. **Fast Collect:** Collect costs 10 less mana. Growing: **Seasoned Hunter** (+1% attack speed per 3 Bounties collected) |
```

---

## 4. `docs/plans/economy.md` (created by `changes-economy.md`)

**Add** a row to the Income table:

```markdown
| **Hob** (the scavenger) | Pickings, Cut Purse, and Bounties; capped at 8 per fight (12–15 with some apexes) |
```

**Add** to "The target":

> - **With Hob on the team,** income rises and so does spending power; his paths trade fight strength for it. The run bot's report should show runs with and without him.

---

## 5. `docs/plans/build-map.md` (created by `changes-build-map.md`)

In section 3's table:

- **Economy row:** "Makers now" → `Hob (Pickings, Cut Purse, Bounties, Silver Tongue, Price on Their Heads); money relics`. "Payoffs now" → `Hoarder, Dragon's Hoard, Golden Idol, Fence, Black Market (Hob); Gilded Rift, Miser's Vault`. "What's missing" → `Covered for now`.
- **Mark row:** "Makers now" → `Bellwarden (Aldous); Bounty Hunter (Hob); Maren's base Marking Shot`.

In section 4's table, **replace** the scavenger row's "Notes" cell with:

> **Designed: Hob Gleaner** (`rebuild-heroes.md`, section 8f)

**Replace** in Open questions (as set by `changes-aldous.md`):

> - **Which hero comes after Aldous:** the blood warlock (Sustain's lifesteal payoff) or the scavenger (Economy).

with:

> - **The last hero in the plan:** the blood warlock (Sustain's lifesteal payoff).

---

## 6. `CLAUDE.md`

**Replace** in "The design the rebuild builds toward", the heroes bullet (as set by `changes-aldous.md`):

> and Aldous (the battery)

with:

> Aldous (the battery), and Hob (the scavenger)
