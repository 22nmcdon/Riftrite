# Rebuild plan, part 6: more decisions between fights

Status: **agreed in discussion (2026-09-28, answers 2026-09-29), not built.** Adds to part 1 (`rebuild-heroes.md`) and part 4 (`rebuild-run.md`); where this part changes a rule there, this part wins. Numbers are placeholders to tune.

**Why:** with items and currency gone, a day had about three decisions (camp, fight, placement), plus an upgrade pick now and then. Making decisions is the heart of a roguelite, so this part adds three things that feed each other:

1. **A pick after every fight.**
2. **Loadout slots:** charms, tactics, and sigils each hero equips, **bought with a currency**.
3. **Wounds** that carry between fights.

## Decisions

- **A pick after every won fight:** 1 of 3 upgrades for your heroes.
- **Loadout slots hold charms, tactics, and sigils. None of them are abilities.** No slotted thing adds a new move; each changes how a hero's existing kit works or behaves.
- **A currency comes back**, earned from fights. It **buys** slotted things; **swapping what's equipped between fights is free.**
- **Wounds:** a hero who falls gets a wound. Wounds are cleared by **resting at camp** (free, but it uses the camp pick) or by **paying currency** (one wound at a time).
- **Nothing slotted may become useless when its hero transforms** (section 3).

**Answers (2026-09-29):**

- **After-fight picks replace the deed picks.** Two sources of upgrade picks is redundant and makes it harder to reason about how fast a hero grows. Deeds keep the big moments: filling a deed transforms the hero, and later unlocks the apex. All the steady growth comes from after-fight picks, which draw from the path's pool once the hero has transformed.
- **Each camp option has one job:**
  - **Train:** a pick.
  - **Hunt:** currency, no pick. A risk-free fight that also gave a pick would be the right choice almost every day; with currency only, it's a real choice.
  - **Pedlar:** spending.
  - **Rest:** clears wounds.
- **A tie pays out like a win** (the pick and the currency). It already counts as a victory, and paying less for a tie would be a rule no one remembers.
- **A hero saved by Undying or would-fall didn't fall, so no wound.** That gives Last Rites and Last Watch Brannoc more value across the run, which suits them.
- **Nothing sells** except a charm a transformation broke (section 3, rule 4). Tight currency is what makes buying a commitment.
- **Tactics get tried early, in Practice**, as a small phase before paths (`rebuild-build-order.md`, phase 3b): target casters first, hold your hex, and a heal threshold. They're the idea most likely to change how fights feel, and the riskiest if they don't work.
- **One modifier shape for charms and enemy specializations.** Rule 3 already pushes both toward the existing part types (auras, grants, triggers). The real work is one shared data shape for "modifies the kit's basic attack or signature"; decide it before either is built.
- **Charms with costs: a few spiky ones, not most.** If every charm had a downside, the loadout would feel like a tax. Most of the tradeoff comes from narrowness instead: "+1 range while you haven't moved for 2s" is strong on a hero who stands still and useless on one who roams.
- **The three cards are one per hero by default**, and sometimes one is a wild card for any hero, so there's room to double down on a carry.
- **Separate random streams:** shop stock, picks, camp, and fight seeds each get their own stream from the run seed, so buying or rerolling never changes a later fight. The determinism rule already asks for this; build it in from the start.
- **A loadout gate for the sim runner:** sample loadouts (every combination is too many) and check that the best beats the worst by a margin. It catches filler charms the way the placement gate catches filler formations.
- **Wounds show as a greyed chunk of the HP bar.** It reads at a glance, needs no new marker, and shows what matters: how much HP is missing.

## 1. A pick after every fight

- **Every won fight offers 1 of 3 upgrades.** Each card names the hero it's for, so the choice is also *who* gets stronger. By default the three cards are one per hero; sometimes one is a wild card for any hero.
- **Before a hero transforms,** their offers come from their hero layer and role layer, plus some that lean toward the path they've vowed to.
- **After a hero transforms,** their path's pool joins the offers.
- **Deeds still drive the big moments:** transformations and apexes. Picks are the steady drip in between, and the only source of upgrades.
- **Upgrades are permanent.** They aren't slotted and can't be swapped.
- **A lost fight gives no pick.** A tie gives one, like a win. Train at camp gives one; a Hunt pays currency, not a pick.

## 2. Loadout slots

Each hero has **3 slots** (a tuning value). Before each fight, after seeing the enemies, you choose what fills them. You'll own more than fit, so the loadout is a real choice.

Three kinds of slotted things can share the slots:

| Kind | What it does | Examples |
| --- | --- | --- |
| **Charm** | A small passive change to the hero's kit | "Your basic attack Slows on crits", "+1 range while you haven't moved for 2s", "Your heals also cleanse Bleed" |
| **Tactic** | Changes how the hero behaves, not what they can do | "Target casters first", "Hold your starting hex until an enemy comes within 2", "Heal only allies below 50% HP" |
| **Sigil** | Changes how the hero's signature fires | "Your signature costs 15 less mana", "Your signature also fires when an ally falls", "Your signature's area is 1 hex larger" |

- **Most are hero-specific** (a Maren charm can't go on Vell); some tactics are shared by every hero with the same role.
- **Mixing kinds is the choice:** a stronger kit (charms), smarter behavior (tactics), or a different rhythm (sigils).
- **Tactics are the arena's answer to "fights are watch-only":** they're how the player shapes what heroes do in a fight they can't control.
- **Charms get their tradeoff mostly from narrowness**; only a few spiky ones carry a cost.

## 3. Nothing goes useless when a hero transforms

A transformation can replace a signature (Vigil Keeper's Sunfall replaces Mend) or change a basic attack (Ironbrand's mace). Rules so a slotted thing never becomes dead weight:

1. **Write against the slot, not the ability.** A charm says "your basic attack", "your signature", "your passive", or "your movement", never "Mend" or "Longshot". "Your signature costs 15 less mana" works whether the signature is Mend or Sunfall.
2. **Tactics and sigils are written this way by nature**, so they always survive a transformation.
3. **The few charms that must name an ability** are marked with the paths they fit, shown before you buy. Buying one is a known gamble.
4. **If a transformation makes a charm stop working anyway,** you can trade it back at full price the next time you can buy.

## 4. The currency

- **Earned from fights:** a normal win pays a set amount, the harder fight pays more, and elites and the boss pay more still. A tie pays like a win. **A Hunt at camp pays currency.** (A name to pick later; placeholder: **shards**.)
- **Spent on:**
  - **Buying** charms, tactics, and sigils.
  - **Treating one wound.**
  - **Rerolling** an offer, where rerolls exist.
- **Where you buy:** a **Pedlar** camp option (a place's menu includes it) shows about 4 things for sale, drawn for your heroes and your paths. Some camp places also carry a smaller stall.
- **Never** for upgrades from the after-fight pick, which stay free.
- **Starting amount:** a little, so there's a first purchase before day 2.
- **Nothing sells back**, except a charm a transformation broke.

This reverses part 4's "no currency to start": currency now exists, but only for these jobs.

## 5. Wounds

- **A hero who falls in a fight, won or lost, gets a wound: –15% max HP.** A hero saved by Undying or would-fall didn't fall.
- **Wounds stack, up to 3** (–45%). A hero with 3 wounds still fights.
- **Clearing wounds:**
  - **Rest** at camp clears every wound on the team. It's free, but it uses the camp pick.
  - **Paying currency** clears one wound, anywhere you can buy, without giving up the camp pick.
- **Every fight still starts at full HP**, meaning full *current* max HP. Wounds lower the max.
- **On the board,** the HP a wound takes shows as a greyed chunk at the end of the HP bar.

This changes two rules in the earlier plans:

- "Fallen heroes always come back after a fight, **with no downside**": they still come back, now wounded.
- **Rest at camp** changes from "the next loss doesn't count" to "clear all wounds". (Whether Rest keeps its old effect too is an open question.)

Wounds give real stakes to close wins, make the easier fight tempting when someone's hurt, and give Last Watch Brannoc's low-HP game a real cost.

## 6. A day, with this part

| Step | Decision |
| --- | --- |
| Camp | Which option: Train for a pick, Hunt for currency, the Pedlar, Rest to clear wounds, or another |
| Route | Which fight, with the next days in view |
| Loadout | Which charms, tactics, and sigils each hero brings, against the enemies you can see |
| Placement | Where everyone stands |
| After the fight | 1 of 3 upgrades, and which hero it helps (a win or a tie) |
| Any time you can buy | Spend now or save; treat a wound or buy something new |
| Now and then | Transformations and apexes when deeds fill, and relics |

## 7. What it means for the code

- **Run state gains:** the currency, owned slotted things, each hero's equipped slots, and wounds.
- **Random streams:** shop stock, picks, camp, and fight seeds each come from their own stream of the run seed (`RunRandom`).
- **The sim gains:** tactics (targeting and behavior overrides on a unit), sigils (signature cost, trigger, and area changes), charms (the existing parts: auras, grants, triggers), and max HP lowered by wounds. Charms and enemy specializations share one modifier shape.
- **The UI gains:** a loadout step before placement, the Pedlar, the after-fight pick, and wound markers on heroes (a greyed chunk of the HP bar).
- **The sim runner gains** a loadout gate: sampled loadouts, the best beating the worst by a margin.
- **Build order:** the first three tactics come early, in Practice (phase 3b). The rest lands in **phase 5** (the run), with the loadout step in the placement screen.

## Open questions

- **Slot count:** 3 each, or fewer early (2) and one more later?
- **Prices and income:** what things cost, and what fights pay.
- **The currency's name.**
- **Rest:** does it also keep "the next loss doesn't count"?
- **Wound size and cap:** is –15% up to 3 right?
- **Wounds from a lost fight:** a loss usually means all three fell, and the day replays with every hero wounded. Should a loss's falls wound (a death spiral risk), or is the loss its own cost?
- **Sigils on signatures without mana:** "costs 15 less mana" does nothing for a signature that fires on HP, a count, or would-fall. Write sigils by what they do ("your signature comes sooner"), or mark them with the triggers they fit?
- **Tactics:** how many choices per hero, and which are shared by role?
- **How fast heroes grow:** a pick after every win is about 8 picks in Act 1, where part 4 aimed for 1–2 per hero by the boss. Picks should stay small so transformations still feel big; the run bot will measure it.
