# Rebuild plan, part 6: more decisions between fights

Status: **agreed in discussion (2026-09-28, answers and section 8 on 2026-09-29), not built.** The playtester's mock of the screens is `docs/mockups/hero-panel-layout.pdf` (section 9). Adds to part 1 (`rebuild-heroes.md`) and part 4 (`rebuild-run.md`); where this part changes a rule there, this part wins. Numbers are placeholders to tune.

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
- **Any hero can hold anything; the Pedlar only sells what your team can use; the Magpie sells other heroes' gear, grafts, and one relic** (section 8, 2026-09-29). This replaces the earlier "most slotted things are hero-specific".

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
- **A tactic may carry a small payoff** (2026-09-29, from the phase 3b tactics report), but only while its behavior applies, or to what the behavior produced ("+20% attack speed while it holds its ground"). A tactic is still a behavior first. A flat number change is a charm's job.
- **A future tactic: the inverse of Hold your ground** (added 2026-09-29, the playtester's idea; working name **Plant your feet**). The hero **stops walking while any enemy is within 2 hexes**, and walks toward its target again when none is. A tank then stands still against melee instead of chasing, which keeps the fight in one place and makes it easy for Vell to stay within 1 hex of it for Hearthlight's heal. It's a behavior like the other three, so it can be written against the slot and survives a transformation. Not built; it comes with the rest of the tactics in phase 5 (or sooner, as a 3b round if the playtest asks for more tactics). Its open questions are below.
- **Now and then the Pedlar carries one relic** (added 2026-09-29): about 1 visit in 3, or only at certain places (a market in the ruins, say). It's expensive, about two days of income, so buying it means skipping charms and paying for wounds yourself for a while. It **counts toward the 3–5 relics a run**, so the total stays the same; it's just another way to get one. Relics stay rare, and currency gets a second big use.

## 1. A pick after every fight

- **Every won fight offers 1 of 3 upgrades.** Each card names the hero it's for, so the choice is also *who* gets stronger. By default the three cards are one per hero; sometimes one is a wild card for any hero.
- **Before a hero transforms,** their offers come from their hero layer and role layer, plus some that lean toward the path they've vowed to.
- **After a hero transforms,** their path's pool joins the offers.
- **Deeds still drive the big moments:** transformations and apexes. Picks are the steady drip in between, and the only source of upgrades.
- **Upgrades are permanent.** They aren't slotted and can't be swapped.
- **A lost fight gives no pick.** A tie gives one, like a win. Train at camp gives one; a Hunt pays currency, not a pick.
- **Or take currency instead** (from the mock, section 9): the pick screen has "Take 3 shards instead", for when none of the three is worth it.

## 2. Loadout slots

Each hero has **3 slots** (a tuning value). Before each fight, after seeing the enemies, you choose what fills them. You'll own more than fit, so the loadout is a real choice.

Three kinds of slotted things can share the slots:

| Kind | What it does | Examples |
| --- | --- | --- |
| **Charm** | A small passive change to the hero's kit | "Your basic attack Slows on crits", "+1 range while you haven't moved for 2s", "Your heals also cleanse Bleed" |
| **Tactic** | Changes how the hero behaves, not what they can do | "Target casters first", "Hold your starting hex until an enemy comes within 2", "Heal only allies below 50% HP", "Stop walking while an enemy is within 2 hexes; close in again when none is" |
| **Sigil** | Changes how the hero's signature fires | "Your signature costs 15 less mana", "Your signature also fires when an ally falls", "Your signature's area is 1 hex larger", "Your heal goes to the healthiest ally instead, and overheal becomes a shield twice as big" (the playtester's, for Vell) |

- **Any hero can hold any charm, tactic, or sigil** (section 8). Knowing who gets the most out of each one is the skill.
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
  - **Now and then, a relic** at the Pedlar (about two days of income; below).
  - **Treating one wound.**
  - **Rerolling** an offer, where rerolls exist.
- **Where you buy:** a **Pedlar** camp option (a place's menu includes it) shows about 4 things for sale, drawn for your heroes and your paths. Some camp places also carry a smaller stall.
- **The Pedlar's relic:** about 1 visit in 3 (or only at certain places, like a market in the ruins), the Pedlar also carries **one relic**, priced at about two days of income. Buying it means going without charms and wound treatment for a while. It counts toward the run's 3–5 relics: another way to get one, not more of them. Like every relic, it has a cost.
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
- **The UI gains:** a loadout step before placement, the Pedlar, the Magpie, the after-fight pick, relic choices, the hero bar, and wound markers on heroes (a greyed chunk of the HP bar), all in the item language of section 9. A slot holding something that does nothing on its hero says "no effect on this hero".
- **Items gain tags** for what they need (hops, mana, heals, ranged, and so on), which the Pedlar filters by and the slot's "no effect" check reads. Grafts are a fourth slotted kind.
- **The sim runner gains** a loadout gate: sampled loadouts, the best beating the worst by a margin.
- **Build order:** the first three tactics come early, in Practice (phase 3b). The rest lands in **phase 5** (the run), with the loadout step in the placement screen.

## 8. Who can hold what, and the Magpie

Agreed in discussion (2026-09-29).

**Any hero can hold any charm, tactic, or sigil.** Nothing is locked to a hero. A charm made for Maren works on Brannoc if its rule applies to him; the player's job is to know where each one pays off most.

- **Write items against things every hero has:** "your basic attack", "your signature", "when you're hit", "when an ally falls". Then an item is rarely useless on anyone, only better or worse.
- **Items that need something** (hops, mana, heals) are tagged with what they need.
- **An item that does nothing on a hero can still be equipped, but its slot says "no effect on this hero".** A wasted placement should feel like a choice, never like a bug.

**The Pedlar sells only what someone on your team can use** (by those tags). Unchanged otherwise: about 4 wares, now and then a relic (section 4: expensive, and it counts toward the 3–5 per run).

**The Magpie** (the exotic shop) is a rare event, about once per act. He sells what he took from other bands who fell in the rift.

- **Always one relic.** It counts toward the 3–5 per run.
- **Other heroes' gear:** charms, tactics, and sigils from the pools of heroes not on your team. Until there's a fourth hero, gear from other roles' pools stands in (tank charms for Vell, and so on).
- **Grafts:** the only way to give a hero something new to do (a small dodge, a cleanse, a once-per-fight trigger).
  - A graft **takes a normal loadout slot**, so it's a trade against a charm, tactic, or sigil, never a free extra.
  - A graft **never grants a path's key mechanic** (range, roots, extra targets, Shield, hops, and so on), so no deed fills without its vow.
  - A graft **never undoes a path's cost** (for example, no mana bar for Last Watch Brannoc).
  - This is the one exception to "slotted things are never abilities", on purpose.
- **Prices are higher than the Pedlar's, and there are no rerolls**: you get one look.

## 9. The screens (the playtester's mock)

`docs/mockups/hero-panel-layout.pdf` (2026-09-29) is the design for the screens between fights. Its page 1, the hero panel, was built for Practice in phase 4 (`rebuild-phase4-paths.md`, section 6); the rest comes with the run in phase 5, in placeholder art until the art rehaul (phase 7).

- **Page 1, the hero bar and the hero panel:** the day, the act and place, shards, and relics along the top; the hero bar along the bottom of every screen between fights (each hero's figure, path and stage, HP bar with wounds as a greyed chunk, deed progress, and their three slots as chips); clicking a hero opens the panel. The run adds what Practice left out: deed progress toward a threshold ("1,240 / 2,000"), Switch vow, the upgrades taken, and the duo bond ("a bond stirs; revealed when both have transformed").
- **Page 2, the item language:** one frame shape per kind, so a kind reads without its color:

  | Kind | Frame | Where it comes from |
  | --- | --- | --- |
  | Upgrade | arch, gold | a hero or role upgrade from the after-fight pick; permanent, listed on the Path tab |
  | Path upgrade | arch, rift | the path's pool once the hero has transformed; vow picks are a gold arch with rift inside |
  | Charm | medallion, gold | bought; slotted, swapped free between fights |
  | Tactic | banner, cream | bought; slotted, swapped free |
  | Sigil | diamond, rift | bought; slotted; survives transformations |
  | Relic | hexagon, plum | rare; stays for the run, in the relic strip |
  | Duo bond | linked rings | found by transforming both paths; kept in the Codex |

  Each thing shows at **three sizes**: a card (shop, pick, reward: kind, the hero it's for, name, rule), a slot (loadout, panel), and a chip (hero bar, relic strip). **Hovering or long-pressing any chip** shows its card as a tooltip (a relic's shows its boon, its cost, and where it came from). Page 3 is one icon from the set (an upgrade on a round medallion).
- **Page 4, the after-fight pick** ("Victory · Day 3: Choose an upgrade"): what the fight paid (shards), who fell and their wound, and how far the vowed deed moved ("62% → 71%"); three arch cards, each with the hero's portrait ("for Maren"), its kind and source ("VOW · DEADEYE", "PATH · HEARTHWALL", "HERO · VELL"), its rule, and a line on why it matters ("Works on every path"); Take on each; and **"Take 3 shards instead"**.
- **Page 5, the Pedlar** ("Camp · Day 4"): the shards; about four ware cards, each with its kind, who it's for ("MAREN", "ANY RANGED", "ANY HERO"), its rule, **the fight it answers** ("Answers flankers (Rift Hound)"), and Buy with its price; now and then a relic ("TODAY ONLY"), with its boon and cost; **Treat a wound** (who, what it costs them, and the price); **New wares** (reroll, redraws all four); and Leave.
- **Page 6, a relic choice** ("Rift Tear survived: Choose a relic, or none"): two relic cards, each with a line of flavor, its boon, and its cost; "Take neither"; and the relic strip ("1 of about 3 to 5 this run"). Relics in the mock (examples, not a list): Ember Heart, Hollow Crown (a fourth loadout slot; wounds take 20%), Rift-Glass Eye (always Scouted; enemies have 10% more HP), Pilgrim's Lantern (Rest also gives +10% max HP; the Pedlar charges 1 more).

## Open questions

- **Slot count:** 3 each, or fewer early (2) and one more later?
- **Prices and income:** what things cost, and what fights pay.
- **The Pedlar's relic:** about 1 visit in 3 everywhere, or only at certain places?
- **The currency's name.**
- **Rest:** does it also keep "the next loss doesn't count"?
- **Wound size and cap:** is –15% up to 3 right?
- **Wounds from a lost fight:** a loss usually means all three fell, and the day replays with every hero wounded. Should a loss's falls wound (a death spiral risk), or is the loss its own cost?
- **Sigils on signatures without mana:** "costs 15 less mana" does nothing for a signature that fires on HP, a count, or would-fall. Write sigils by what they do ("your signature comes sooner"), or mark them with the triggers they fit?
- **Tactics:** how many choices per hero, and which are shared by role?
- **Plant your feet** (the future tactic above):
  - **Its payoff.** Round 2's rule says a tactic's payoff applies only while its behavior does. Something while it stands still fits, such as more DEF or more healing taken, but nothing is chosen yet.
  - **A target out of reach.** While it stands, it could attack only what's in reach, like a holder does. Or it could switch to the nearest enemy in reach, which would change targeting as well as movement.
  - **Who takes it.** Every hero, or tanks only? On Maren, it would keep her from walking into melee reach.
  - **Engage and pushes.** Brannoc's Engage pulls him to enemies that come close; does Engage still move him? A push moves a unit without it walking, so it isn't affected, but should the tactic say so?
- **Grafts:** the list, and whether they need their own frame shape in the item language (a proposal: a split medallion).
- **The Magpie:** exact frequency, and whether buying a locked hero's gear counts toward unlocking that hero.
- **From the mock:**
  - **"Take 3 shards instead"** on the after-fight pick: a fixed amount, or the fight's own pay again?
  - **A struck-out price** on one of the Pedlar's wares (Purifying Light, "2 ~~3~~"): a sale, a relic's discount, or a price for something the team already partly has?
  - **"Answers ..." lines** on wares: written by hand per item, or generated from the item's tags and the enemies it counters?
- **How fast heroes grow:** a pick after every win is about 8 picks in Act 1, where part 4 aimed for 1–2 per hero by the boss. Picks should stay small so transformations still feel big; the run bot will measure it.
