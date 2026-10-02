# Changes: Edric, the tenth hero (the team shielder)

Decided 2026-10-02. This adds Edric Tithewell, a back-line support who wards the whole team. His three paths each grow out of Shields, into protection (Aegis), money (Tithe-Collector), and mana (Psalmist). That makes Economy and Mana two-hero builds, and gives Shield a third maker. It also:

- sets the Shield rule: a unit's Shield is one pool with no owner, so nothing may depend on who gave it;
- changes Wardweaver's Lasting Shields upgrade, which did nothing (every Shield already lasts until broken);
- relaxes the apex rule: not every apex needs a snowball;
- adds the build-map rule that no build may depend on a single hero.

Each section below is one file. **Replace** means swap the quoted text for the new text, **Add** means insert it where stated, and **Remove** means delete it. Paths are from the repo root. Apply after `changes-severine.md` (and the files it depends on).

---

## 1. `docs/plans/rebuild-heroes.md` (part 2)

**Add** a new section after Severine's section (8g), before "## 9. How the heroes fit together":

```markdown
## 8h. Edric Tithewell: the tithe-warden (support)

*Added 2026-10-02.* **Role:** a back-line support who wards the whole team. Wardweaver shields one ally at a time through her heals; Edric covers everyone, and each path asks what Shields pay out. Shares the support role with Vell and Aldous. Builds (`build-map.md`): Shield (maker; Bastion of Saints is also a payoff), Economy (maker and payoff), Mana (maker).

| | |
| --- | --- |
| **Stats** | HP 320, ATK 10, MGK 16, DEF 16 |
| **Speed / range** | speed 2, up to 3 hexes |
| **Basic attack: Seal** | a stamped seal at the nearest enemy in range (MGK damage); his main source of mana |
| **Signature: Ward** (70 mana) | every ally gains a Shield of 8% of their max HP |
| **Passive: Vigil** | Shielded allies within 2 hexes of him take 5% less damage |

**His paths count any Shield, never "his" Shields** (section 5: a Shield has no owner). His deeds count only what his own effect gives at that moment.

### Path 1: Aegis (Shield: maker)

The fantasy: no one under his watch goes unwarded.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Hallow:** every 6s, the lowest-HP ally gets a Shield of 4% of their max HP | Hallow every 3s, at 6% of their max HP |
| **Signature** | Ward | **Sanctuary:** every ally gains a Shield of 20% of their max HP |
| **Cost** | –10% MGK | None |

- **Deed:** Shield given by Hallow.

### Path 2: Tithe-Collector (Economy: maker)

The fantasy: the rift takes its toll, and he collects his share.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Tithe:** after a won fight, +1 shard for each hero still standing | +2 shards per hero still standing |
| **Signature** | Ward | **Collection:** every ally gains a Shield of 8% of their max HP, and each enemy that dies in the next 5s pays 1 shard (up to 3 per cast) |
| **Cost** | –10% DEF | –15% max HP |

- **Deed:** shards from Tithe.
- **Unlike Hob:** Hob earns by killing and pays in fight power; Edric earns by keeping everyone standing.

### Path 3: Psalmist (Mana: maker)

The fantasy: every ward that shatters becomes a breath of power.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Offering:** when any Shield on an ally breaks, that ally gains 5 mana | When any Shield on an ally breaks, they gain 10 mana, and allies gain mana 10% faster while they have any Shield |
| **Signature** | Ward | **Vesper Ward:** every ally gains a Shield of 10% of their max HP and 25 mana |
| **Cost** | –10% MGK | Vesper Ward's Shields are 25% smaller |

- **Deed:** mana given by Offering.
- **Unlike Aldous:** Aldous shares his own mana income; Edric gives mana when Shields break, so front-liners who take hits (Brannoc, Garrow, Severine) fill fastest.

- **Upgrade pool:** `upgrade-pools.md`. **Apexes:** `apexes.md`.
```

**Add** a row to the mana table in section 4:

```markdown
| Edric | 70 | +8 | none | 2/s | 0 |
```

**Add** to section 5 ("Shared statuses"):

> - **A Shield is one pool per unit, with no owner and no duration** (as the sim stores it). **Nothing may depend on who gave a Shield,** only on whether a unit has one, how big it is, or the moment a Shield is given or breaks. Shields last until broken.

**Add** to section 9 ("How the heroes fit together"):

> - **Edric turns Shields into whatever the team lacks:** more protection (Aegis), money (Tithe-Collector), or mana (Psalmist). Every Shield maker on the team (Wardweaver, Hearthguard, Garrow's Aegisfang, Tithe of Iron) feeds his paths.

---

## 2. `docs/plans/apexes.md` (created by `changes-apexes.md`)

**Replace** in "How apexes work":

> - **What the apex gives:** the full mechanic with numbers, a stat change where it fits, and **one snowball**: something that grows during a fight or feeds itself.

with:

> - **What the apex gives:** the full mechanic with numbers, a stat change where it fits, and **usually one snowball**: something that grows during a fight or feeds itself. **Not every apex needs one**; a strong steady effect is fine.

**Add** a new section after Severine's section, before "## Notes":

```markdown
## Edric

| Apex | Taste (on vow) | Deed | The apex | Upgrades |
| --- | --- | --- | --- | --- |
| **Bastion of Saints** (Aegis) | Hallow reaches the 2 lowest-HP allies | Shield given by Hallow | Hallow shields every ally every 3s, at 6% of their max HP. New signature **Hallowed Ground:** for 5s, every Shield on an ally absorbs twice as much damage. **Snowball:** each Hallow makes the next one +0.5% of max HP bigger, for the rest of the fight | **Saintly:** +1% per Hallow. **Consecrated:** Shielded allies within 2 hexes of him deal +10% damage |
| **Reforged Ward** (Aegis) | When any Shield on an ally breaks, they get a new Shield of 2% of their max HP (once every 8s per ally) | Shield given by Reforge | When any Shield on an ally breaks, they get a new Shield of 5% of their max HP (once every 4s per ally). No snowball | **Thick Forge:** reforged Shields are 7%. **Quick Forge:** once every 3s per ally |
| **Golden Aegis** (Tithe-Collector) | His signature also gives each ally 1 Shield per 3 shards held | Shield given by that shard bonus | His signature gives 8% of max HP plus 2 per shard held. **Run snowball:** each fight won with every hero standing gives every hero +1% max HP for the rest of the run | **Gold Leaf:** +1.5% per flawless fight. **Ward Tax:** his signature costs 10 less mana while you hold 30+ shards |
| **Collector of Debts** (Tithe-Collector) | Tithe pays 1 more shard if no hero fell | Shards from flawless fights | Tithe pays 3 per hero standing, and a flawless fight pays 5 more. **Run snowball (money):** each flawless fight raises that bonus by 1 for the rest of the run, up to +15 | **Compound Debt:** +2 per flawless fight, up to +20. **Insurance:** a hero who falls still pays 1 |
| **Choir of Wards** (Psalmist) | Offering gives 7 mana, not 5 | Mana given by Offering | A breaking Shield gives 20 mana, plus +10% ATK and MGK for 3s. No snowball | **Loud Psalm:** 25 mana per break. **Antiphon:** Offering also gives the ally a Shield of 3% of their max HP |
| **Evensong** (Psalmist) | When an ally fires a signature, they gain a Shield of 3% of their max HP | Shield given by Evensong | When any ally fires a signature, every ally gains a Shield of 10% of their max HP. No snowball | **Swelling Song:** Evensong's Shields are 13%. **Vespers:** Evensong's Shields also give 5 mana |
```

**Add** to "Notes":

> - **Hallowed Ground** reads the team's Shield pools as they are, so it's a Shield payoff for every Shield maker on the team.
> - **Evensong with Psalmist is a loop:** signature → Shields on everyone → Shields break → mana → the next signature.
> - **Tithe-Collector's snowballs last the run** (like Hob's), and reward flawless fights rather than kills.

---

## 3. `docs/plans/upgrade-pools.md` (created by `changes-upgrade-pools.md`)

**Replace** in Vell's Wardweaver path upgrades:

> **Lasting Shields:** her Shields last until broken.

with:

> **Thick Weave:** Weave's Shields are 20% larger.

(Every Shield already lasts until broken, so the old upgrade did nothing.)

**Add** a new section after Severine's section, before "## Left out on purpose":

```markdown
## Edric

### Hero pool

These never give timed Shields like Hallow (Aegis), shards (Tithe-Collector), or mana from Shields (Psalmist).

| Upgrade | Effect |
| --- | --- |
| **Steady Faith** | MGK +10% of his current MGK (stacks) |
| **Iron Vestments** | DEF +10% of his current DEF (stacks) |
| **Pilgrim's Frame** | Max HP +10% of his current max HP (stacks) |
| **Quick Seal** | Attack speed +10% of his current attack speed (stacks) |
| **Strong Ward** | Ward's Shields are 10% of max HP, not 8% |
| **Swift Ward** | Ward costs 10 less mana |
| **Wide Vigil** | Vigil reaches allies within 3 hexes |
| **Deep Vigil** | Vigil cuts damage by 8%, not 5% |
| **Heavy Seal** | Seal Slows its target 15% for 1s |
| **Warding Seal** | Seal deals +20% damage to enemies attacking a Shielded ally |
| **First Ward** | At the fight's start, every ally gains a Shield of 5% of their max HP |
| **Old Prayers** | Grows: +1% to Ward's Shield size per 10 Wards cast, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Aegis** | **Quick Hallow:** Hallow every 5s, not 6s. **Strong Hallow:** Hallow's Shield is 5%, not 4% | **Faster Hallow:** Hallow every 2.5s. **Sanctified:** Sanctuary also gives +10 DEF for 4s. **Steady Hallow:** Hallow goes to allies without a Shield first. **Quick Sanctuary:** Sanctuary costs 15 less mana. Growing: **Sainthood** (+1% to Hallow's size per 50 Hallows) |
| **Tithe-Collector** | **Elite Tithe:** Tithe pays double after elites. **Bold Tithe:** Tithe pays 1 more after the harder of the day's fights | **Long Collection:** Collection lasts 8s. **Full Plate:** Collection pays up to 5 shards per cast. **Quick Collection:** Collection costs 10 less mana. **Thick Collection:** Collection's Shields are 12%. Growing: **Ledger of Debts** (+1 shard per won fight for every 10 fights won, up to +5) |
| **Psalmist** | **Shared Offering:** Offering also gives 3 mana to the nearest other ally. **Quick Breath:** +5% mana gain while Shielded | **Full Vesper:** Vesper Ward gives 35 mana. **Quick Vesper:** Vesper Ward costs 10 less mana. **Steady Song:** mana gain while Shielded is 15%, not 10%. **Bright Offering:** Offering also gives +10% attack speed for 2s. Growing: **Long Hymnal** (+1% mana gain while Shielded per 500 mana given by Offering) |
```

---

## 4. `docs/plans/economy.md` (created by `changes-economy.md`)

**Add** a row to the Income table:

```markdown
| **Edric** (Tithe-Collector) | Tithe after won fights (per hero standing), and Collection during fights (up to 3 per cast) |
```

---

## 5. `docs/plans/build-map.md` (created by `changes-build-map.md`)

**Add** to section 2's "Rules for the roster", as rule 5:

> 5. **No build may depend on a single hero.** Count paths and apexes (not upgrades or relics): every build needs makers on at least 2 heroes and payoffs on at least 2 heroes.

In section 3's table:

- **Shield row:** "Makers now" → `Aegis, Bastion of Saints, Reforged Ward (Edric); Wardweaver (Vell); Hearthguard (Brannoc); Aegisfang (Garrow)`. "Payoffs now" → `Aegisfang, Endless Bulwark, Shatterburst (Garrow); Bastion of Saints' Hallowed Ground (Edric); Thornweave (Vell)`.
- **Mana row:** "Makers now" → `Chorister and Wellspring (Aldous); Psalmist, Choir of Wards, Evensong (Edric)`. "What's missing" → `Covered: two heroes`.
- **Economy row:** "Makers now" → `Hob; Tithe-Collector and Collector of Debts (Edric); money relics`. "Payoffs now" → `Hoarder, Dragon's Hoard, Golden Idol, Fence, Black Market (Hob); Golden Aegis (Edric); Gilded Rift, Miser's Vault`. "What's missing" → `Covered: two heroes`.

**Replace** in Open questions (as set by `changes-severine.md`):

> - **The roster plan is done.** Gaps left: a Burn payoff that isn't Ilse, a Poison payoff on another hero, and the Summons build. Next heroes come from those.

with:

> - **Single-hero builds left (rule 5):** Burn payoff (Ilse only), Poison payoff (Severine only), Stealth payoff (Tamsin only), and Summons (Severine's Gravecaller only, no payoff). Planned: **the alchemist** (Catalyst path: the second Burn and Poison payoff) and **the illusionist** (Summons maker and payoff, Stealth payoff).

---

## 6. `CLAUDE.md`

**Replace** in "The design the rebuild builds toward", the heroes bullet (as set by `changes-severine.md`):

> and Severine (the blood warlock)

with:

> Severine (the blood warlock), and Edric (the team shielder)
