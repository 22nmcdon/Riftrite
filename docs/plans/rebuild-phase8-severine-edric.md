# Phase 8 part 5: heroes 7 and 8, Severine and Edric

Status: **a build plan, for approval (2026-10-11).** The remaining heroes come in two at a time after the tuning phase (`rebuild-build-order.md`), Severine and Edric first. This plan builds Severine Hollowell and Edric Tithewell from their designs (`rebuild-heroes.md` sections 8g and 8h; `apexes.md`; `upgrade-pools.md`; `duo-bonds.md`), the way phase 8 part 4 built Garrow, Tamsin, and Aldous (`rebuild-phase8-heroes.md`): the draft frame, habits, the builds report, and the bots' draft are already built, so each hero is its kit, its sim pieces, and its content. Numbers are the designs' placeholders until the check (section 8). Questions are in section 10.

## 1. What it builds

- **Two heroes** (sections 4 and 5), each whole: the base kit, three paths (taste, cost, transformation, deed and its threshold, a habit where a transformation replaces the signature), six apexes (taste, deed, snowball), 12 hero cards, 6 taste cards, 12 path cards and 3 growing ones, 12 apex cards, a placeholder figure for the base form and each path, ability texts that name every reach, and the sim pieces they need.
- **Edric's run pieces** (section 6): Tithe-Collector earns shards between fights, so a path's deed and an apex's snowball can count in the run, not only in a fight. Nothing built does that yet.
- **Four bond relics** (section 7): every bond in `duo-bonds.md` whose two paths are both among the eight heroes'.
- **A check and a tuning pass for the two** (section 8): each new path and apex lands in the bars the built eighteen and thirty-six were tuned to, and each new hero's runs won land in the tuning phase's hero band (Decision 14 there). The acts are re-checked, not retuned, unless Act 1 leaves its 40–49% band.

Not in it: the other five designed heroes (Ilse, Hob, Ottilie, Lucan, Kestra), the role layer of upgrades, unlocks (both are open from the start, as the six are), and the bonds that wait for an unbuilt hero (Putrefaction, Nest of Rot, Tithe and Hoard).

## 2. Why these two, and why now

- **The sustain plan gets its real makers.** The tuning phase measured the half-plans with stand-ins, since "its real makers (Edric, Severine) aren't built" (`easy-start.md`). Severine is the lifesteal payoff the relics were written for (Shadow Engine, Blood Communion), and Edric makes Shields for the whole team.
- **Two synergy teams become playable** (`test-teams.md`): **Bulwark** (Edric, Garrow, Vell: Shield) and **Blood Price** (Severine, Vell, Garrow: Sustain). Both join `tools/test_teams.json`.
- **Four bonds wake** with built paths: Watched Over (Aegis + Last Watch), Iron Hunger (Bloodglut + Spitemail), Blood and Lamplight (Hemomancer + Lanternbearer), Psalm and Chorus (Psalmist + Chorister).
- **The roster:** two tanks (Brannoc, Garrow), three damage (Maren, Tamsin, and Severine, a melee bruiser who stands at the front), three supports (Vell, Aldous, Edric). The draft grows from 20 teams to 56.
- **Two at a time** keeps each pair's tuning small: the band moves a little with each pair, rather than all at once with seven.

## 3. What's built that they use

- **The draft frame** (`HeroTeam`, `RunFlow.start`, the start screen's draft, Practice's team row): a hero joins by being in `heroes.json` with its paths built (`HeroTeam.ready`). No frame work is expected.
- **Habits** (`rebuild-phase8-heroes.md` section 3b): Gorge, Plague Burst, Exsanguinate, Sanctuary, Collection, and Vesper Ward replace a signature, so each transformed path keeps the old one (Drain, Ward) as a habit on every 8th basic attack (`rebuild-heroes.md`'s table: Drain strikes for 200% of her ATK with 50% lifesteal, from range on MGK for Hemomancer; Ward gives every ally a Shield of 8% of max HP).
- **Tools:** the builds report (floor, ceiling, lift), the paths, deeds, and apex reports, the run report's By hero and By team, the bots' draft (`Bot.team`), `--team`, and the placement refit, all reading any team.

## 4. Severine Hollowell (part 8e-2)

The design: `rebuild-heroes.md` 8g, `apexes.md` Severine, `upgrade-pools.md` Severine, the bonds Iron Hunger and Blood and Lamplight.

- **Base kit:** HP 330, ATK 20, MGK 12, DEF 12, speed 2, melee. Rend (15% lifesteal; her mana); Drain (60 mana: 200% of her ATK, 50% lifesteal); Hemophage (her lifesteal doubled against enemies below 50% HP). **She never heals:** all her sustain is lifesteal.
- **Paths:** Bloodglut (Engorge, Gorge), Plaguebearer (Blight, Plague Burst), Hemomancer (Blood Price; transformed: a caster from 3 hexes on MGK, starting at 50% HP, Blood Bolt, Exsanguinate).
- **Apexes:** Leviathan, Sanguine Nova, Gravecaller, Pestilence, Blood Tide, Blood Rite.

| Piece | Built already | New |
| --- | --- | --- |
| Rend, Drain, Hemophage | `lifesteal_bp` auras, worked out per hit with `from_basic`, `from_signature`, and `"vs"` (below an HP share) | none expected: "doubled" is a per-hit aura of the same share against enemies below 50% |
| Engorge | lifesteal as a heal (`lifesteal_heals`); a heal's overheal into max HP (`overheal_max_hp_per`, MAX_HP_UP) | **lifesteal past full HP raises max HP** (an aura stat, capped at a share of her starting max HP; no cap once transformed), logged as MAX_HP_UP sourced to Engorge |
| Rend's bonus, Gorge | damage from ATK; a heal's `amount_bp_of_max_hp` (the healed unit's) | **damage from the unit's own max HP** (a damage effect's share of its holder's max HP, added to its ATK part) |
| Blight, Plague Burst | the `poison` status; `apply_status` from ATK; zones (areas that last) | none expected; Poison never counts toward lifesteal (damage over time doesn't lifesteal today) |
| Plaguebearer's doubled lifesteal | per-hit `vs` lifesteal (Poisoned: a status condition) | none |
| Blood Price | a signature's mana cost | **an HP cost** (a signature that costs a share of max HP, with or without mana; it never takes her below 1 HP, Question SA), logged as the ability's line with the HP spent |
| Hemomancer | ranged basic attacks on MGK; signatures on an HP threshold | **a starting HP share** (she starts at 50% of max HP); **a signature cast whenever she's above an HP share**, paid in HP, no mana, instant (Question SA) |
| Exsanguinate | damage to the target and enemies within 1 hex | **damage plus a multiple of the HP just spent** (the cast's spent HP carried into its effects) |
| Deeds | MAX_HP_UP; `applied` (Poison) | **the count `hp_spent`** |
| Leviathan | stacking whole-fight boosts | **a boost per share of max HP gained** (every 10% gained: +5% lifesteal; Thick Hide: +1 DEF per 5%) |
| Sanguine Nova | areas; MAX_HP_UP | **release bonus max HP as damage**: half of what Engorge added, dealt within 2 hexes, then lost (a new effect, its own log line) |
| Gravecaller | rises (`Summons.rise_as`, enemy side); summons on the caster's side | **a hero-side rise**: a Poisoned enemy that falls rises on the heroes' side as its own kit, at 30% of its HP, for 8s, up to 3 at once (Question SB): a summon's lifetime and a rise that turns sides |
| Pestilence | Plague Burst; on_enemy_fell `vs` Poisoned; growing power | a growing Poison strength (`grows_per_stack` or a whole-fight boost on Poison applied) |
| Blood Tide, Blood Rite | timed boosts on allies; whole-fight boosts | **a boost per HP spent** (every 100 HP spent: every hero +2% ATK and MGK) |

**The Mirrorwight:** Drain and Gorge (damage) are copyable; Exsanguinate copies as its MGK part only (a copier has spent no HP); Plague Burst (a zone of Poison) is copyable. **The rift learns:** lifesteal isn't healing, so it doesn't count toward the healing habit (Question SG).

## 5. Edric Tithewell (part 8e-3)

The design: `rebuild-heroes.md` 8h, `apexes.md` Edric, `upgrade-pools.md` Edric, the bonds Watched Over and Psalm and Chorus.

- **Base kit:** HP 320, ATK 10, MGK 16, DEF 16, speed 2, range 3. Seal (MGK; his mana); Ward (70 mana: every ally a Shield of 8% of their max HP); Vigil (Shielded allies within 2 hexes of him take 5% less damage). **His paths count any Shield,** never "his": a deed counts only what his own effect gives at that moment.
- **Paths:** Aegis (Hallow, Sanctuary), Tithe-Collector (Tithe, Collection), Psalmist (Offering, Vesper Ward).
- **Apexes:** Bastion of Saints, Reforged Ward, Golden Aegis, Collector of Debts, Choir of Wards, Evensong.

| Piece | Built already | New |
| --- | --- | --- |
| Seal, Ward | ranged MGK attacks; Shields of max HP on `all_allies` | none |
| Vigil | `allies_near` auras; `damage_reduced_bp`; an aura's `"only"` (Shielded) | none expected |
| Hallow, Sanctuary | `on_interval`; `lowest_hp_ally`; Shields of max HP | none |
| Tithe, Collection | | **run pieces** (section 6) |
| Offering, Psalmist | `on_ally_shield_broken`; `gain_mana` on the event's unit; MANA_GIVEN and the count `mana_given`; `mana_gain_bp` auras while Shielded | none expected |
| Vesper Ward | Shields and `gain_mana` on all allies | none |
| Bastion of Saints | Hallow on every ally; growing signatures (`grows_bp`) | **Hallowed Ground**: for 5s every Shield on an ally absorbs twice the damage (an aura stat on the Shielded unit, the defender's side of the built `shield_damage_bp`) |
| Reforged Ward | `on_ally_shield_broken`, `cooldown_per_unit_ms` | none |
| Golden Aegis | Shields | **shards held, in a fight** (the run's shards passed in the setup, read by an effect's amount; Question SD) and a run snowball (section 6) |
| Collector of Debts | | run pieces (section 6) |
| Choir of Wards, Evensong | `on_ally_shield_broken`, timed boosts; `on_ally_ability`, Shields on all allies | none |

**The Mirrorwight:** Ward, Sanctuary, and Vesper Ward's Shield are copyable (Shields); Vesper Ward's mana and Collection's shards aren't. **The rift learns:** his Shields count toward the Shields habit as Vell's and Garrow's do.

## 6. Edric's run pieces

Tithe-Collector earns between fights; the sim stays a pure function of its setup (rule 1), so every shard is paid by the run from what a fight reports.

- **A path's run rule** (Tithe): after a won fight (a tie counts as a win), +N shards for each hero standing at the end (`FightResult` already knows who's down at the end). It sits on the path's stage (vowed 1, transformed 2; Elite Tithe, Bold Tithe, and Collector of Debts change it), and `RunFlow.record` pays it beside the fight's pay. The day screen's pay line names it ("Tithe: +3").
- **A deed counted by the run** (Tithe-Collector's: shards from Tithe): the deed's total is added in `RunFlow.record`, not by `Deeds` in the fight, so it fills only in a run (Question SC). Practice shows the deed as "counted in a run".
- **Shards from a fight** (Collection): each enemy that falls within 5s of a cast pays 1 shard, at most 3 a cast. The fight counts it as a tally (like Overkill Tithe's), and the run pays it; the cap is per cast, kept in the sim's state.
- **Shards held, in a fight** (Golden Aegis, and Hoarder later): `FightSetup.shards`, the run's shards as the fight starts, read by an effect's amount ("2 per shard held").
- **Run snowballs on apexes** (Golden Aegis: +1% max HP to every hero per flawless fight; Collector of Debts: +1 to the flawless bonus per flawless fight, up to 15): a growth (`GrowthDef`) on an apex, counting a new fight count, **flawless** (won with no hero down at the end), from when the apex is earned. Its steps reset with the run, so rule 5 holds.
- **The bots:** Tithe's shards are worth what the shard worth says (the good bot's practice fights can't see them); Collection's tally is counted as shards in its practice runs.
- **Save version 11** if the state needs new fields (the run's apex growths may fit the built growth maps).

## 7. The bond relics

Four, from `duo-bonds.md`, as relics of tier `bond` (the built frame: a bond on once both paths transform, its relic 20% of the shops' draws):

- **Watched Over** (Aegis + Last Watch): **The Last Ward**: Hallow always goes to Brannoc first while he's below 30% HP, and while he's Shielded below 30% his Last Watch ATK and DEF bonuses are doubled.
- **Iron Hunger** (Bloodglut + Spitemail): **The Iron Maw**: while Severine is within 2 hexes of Garrow, damage he sends back also heals her as lifesteal (feeding Engorge), and every max HP she gains from Engorge he gains too.
- **Blood and Lamplight** (Hemomancer + Lanternbearer): **The Lamp of Ichor**: each Exsanguinate gives Vell 10 mana, and Vell's Mend always goes to Severine when she's at or below 50% HP, healing her 50% more.
- **Psalm and Chorus** (Psalmist + Chorister): **The Psalter**: when any Shield on an ally breaks, Aldous also gains that mana (and shares half, as Chorister does), and Crescendo gives every ally a Shield equal to the mana it gave.

Each needs a small piece or two (a target preference "Brannoc first below 30%", a doubled aura while a condition holds, thorns damage counted as another unit's lifesteal, max HP gains shared, a Shield from a share of mana given); each part lists them as it builds them.

## 8. Tools, bots, the check, and the tuning

- **The reports:** `tools/apex_teams.json` gains a team for each new bond and each new hero's carry apex (Leviathan or Blood Tide; Bastion of Saints); `tools/build_teams.json` a build team for each new path (Bulwark and Blood Price among them); `tools/test_teams.json` gains Bulwark and Blood Price, and the sustain stand-in is read again beside them.
- **The bots:** `Bot.team` drafts from eight; the run report cycles 56 teams by seed (each team's 27 vow combinations), so 120 runs hold about two runs a team and 45 a hero (Question SE). The placement weights are refitted once with teams drawn from the eight (Act 1, water, and void sets) and checked with `placement_check.gd`.
- **The check** (as 8d-5's): each vow within 5 points of base on the paths report, each transformation at its type's floor on the builds report (`build-tuning.md`: Bloodglut and Plaguebearer self-sufficient, Hemomancer an engine that wants healing, Aegis and Psalmist enablers with lift, and Tithe-Collector long-game, judged by its shards over a run rather than a fight), each vowed deed sized to about 4 fights on the deeds report (T-3's yardsticks), and each apex's half point within the built thirty-six's spread on the apex sweep.
- **The tuning** (Question SF): the good bot's runs over all 56 teams; Severine's and Edric's runs won brought into the hero band (±8 points of the mean of the eight), lifting or trimming only the two; then Act 1, Act 2, and Act 3 read against their targets, and retuned only if Act 1 leaves 40–49%.

## 9. Parts

- **8e-1, the frame check:** both heroes' base kits in `heroes.json` with their figures (not draftable until their paths are built), the team list and the reports reading eight, and the tests that name the roster.
- **8e-2, Severine:** her pieces (section 4), her paths and habits, her cards, her apexes and their pieces (Gravecaller's hero-side rise among them), Iron Hunger and Blood and Lamplight, her paths tuned by build, and her docs.
- **8e-3, Edric:** his fight pieces (Hallowed Ground), the run pieces (section 6), his paths and habits, his cards, his apexes, Watched Over and Psalm and Chorus, his paths tuned by build, and his docs.
- **8e-4, the check and the tuning:** section 8: the check, the placement refit, the runs over all 56 teams, the two heroes into the band, the acts read.
- **8e-5, the docs and the build:** HOW-TO-PLAY (the two heroes, their bonds, what we want to know), screenshots (the draft, a fight with each), the design doc, `CLAUDE.md`, and a playtest build.

Every new piece is skipped by a fight that doesn't use it, so the bench's fingerprints stay as they are; each gets a small-fight test, an audit rule and a board form if it adds a log kind, a place in the chaos fight, and a mutation check.

## 10. Questions

- **SA. Severine's HP costs:** Blood Price (vowed) costs 30 mana plus 5% of her max HP; transformed Hemomancer casts Exsanguinate "whenever she's above 50% HP, with no cooldown", for 10% of her max HP. Proposed: an HP cost never takes her below 1 HP (with less, the signature waits, like a bar not yet full); Exsanguinate fires at most once a tick while she's above 50% before paying, so at 55% she casts once and drops to 45%, and lifesteal decides the next cast. Wounds lower her max HP, and 50% is of that.
- **SB. What Gravecaller raises:** "Poisoned enemies that die rise as her thralls, up to 3 at once." Proposed: any Poisoned enemy that falls, summons included, except elites and bosses (as no apex controls one) and a unit that fell into the void; the fallen enemy's own on_fall still happens (a Glass Shambler splits and rises); a thrall's kills are its own (not Severine's); thralls count toward the 30 a side and toward nothing else (deeds, the rift learns).
- **SC. Tithe-Collector's deed in Practice:** it fills only between won fights in a run, so Practice can't fill it (Vow and Transform are free there anyway). Proposed: the card says "counted in a run"; Tithe pays on endless floors too (floors pay flat, endless Decision 4).
- **SD. Golden Aegis in Practice:** it reads the shards held, which Practice doesn't have. Proposed: Practice fights as if holding 30 shards, said on the card ("in Practice: 30 shards").
- **SE. How many runs:** 56 teams make 120 runs about two a team and 45 a hero, against 60 a hero with six. Proposed: 160 runs for the band (60 a hero, about 3.5 hours), 120 for everything else.
- **SF. Tuning the two, not the eight:** proposed as section 8: bring the two into the band and leave the six alone, read the acts and retune only if Act 1 leaves 40–49%. Or a short tuning pass over all eight after the pair?
- **SG. The rift learns and lifesteal:** proposed: lifesteal isn't healing (the design's rule), so Severine doesn't feed the healing habit; Poison doesn't get a habit until a second Poison maker is built (Kestra, Ottilie).
