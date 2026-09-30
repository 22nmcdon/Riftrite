# Duo bonds

Status: **agreed in discussion (2026-09-30), not built.** Replaces part 4, section 6 (`rebuild-run.md`). **The bonds and relics below are drafts;** numbers and names are placeholders.

## The rules

- **A duo bond links two paths of two different heroes.** It has no boost of its own: **it's the key to a bond relic.**
- **It switches on when both heroes have transformed** into the bonded paths.
- **Once it's on, its bond relic joins the shop pool for the rest of the run.** It isn't guaranteed in the next shop; it's just more likely to show up than an epic (about twice as likely, to tune). You may have to reroll or wait for it.
- **The bond relic is free** when it shows up in a shop. It takes the shop's relic spot, like any relic.
- **It can show up in any shop,** including the pre-boss shop (as the relic next to the legendary). The Magpie doesn't sell it.
- **The only way to get a bond relic is to have its bond.** A bond relic is still team-wide and follows every relic rule (`relics/README.md`); only who can *get* it depends on the heroes. Its effect should play off both paths' mechanics.
- **The vow previews it:** vowing two heroes to bonded paths shows the bond as "?". Its name and relic are revealed once it switches on.
- **Found bonds and their relics go in the Codex.**

## How many

- **Rare on purpose:** each path has **1–2 bonds across the whole roster.** Bonds are a discovery, not something every run has.
- **With three heroes, only a few exist** (3 for the Act 1 slice). They grow as heroes are added; with about 6 heroes, the full set gets written against the real roster.

## The Act 1 bonds (drafts)

| Bond | Paths | Bond relic |
| --- | --- | --- |
| **Sentry and Sniper** | Hearthwall (Brannoc) + Deadeye (Maren) | **The Watchtower Stone:** allies standing behind a wall gain +1 range |
| **Snare and Cleave** | Ironbrand (Brannoc) + Trapper (Maren) | **The Hunter's Anvil:** enemies that are knocked back are Rooted for 1s when they land |
| **Light and Iron** | Hearthwall (Brannoc) + Wardweaver (Vell) | **The Hearth-Woven Mail:** when an ally takes a hit for another ally, the protected ally gains a Shield of 5% of their max HP (once every 2s per ally) |

## Where this meets what's built

Phase 5 built these three bonds with the old rule (`data/bonds.json`, `rebuild-phase5-run.md`): when both paths have transformed, each hero gets a boost (Sentry and Sniper: more mana for Brannoc's attacks, +1 range planted for Maren; Snare and Cleave: Brand Slam +20%, snares root 1s longer; Light and Iron: Weave's Shield +25%, Brannoc +8% DEF). Building this file drops the boosts and adds the three bond relics to the relic pool, with the shop's odds for them. The bond's switching on, its "?" on the vow, and its reveal stay as built.

## Open questions

- **How much more likely** than an epic a bond relic is to show up.
- **Two bonds at once:** if a run switches on two bonds, both relics join the pool. Fine, or one at a time?
- **The Act 1 three:** all three include Brannoc. Should Vell and Maren get one of their own?
