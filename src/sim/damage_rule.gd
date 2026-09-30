class_name DamageRule
extends RefCounted
## The damage rule (docs/plans/rebuild-combos.md, section 3; phase 5c,
## docs/plans/rebuild-phase5c-combos.md, step 1): a number is its base times
## one factor per bonus kind. Bonuses of one kind add; the kinds multiply.
##
##   base x (1 + power) x (1 + crit) x (1 + vulnerability) x (1 + relic)
##
##   - power: the attacker's own (damage, heal, and shield auras; a kit mod
##     on an ability's amount, EffectDef.power_bp; a tactic's payoff).
##   - crit: only on a crit (the crit's own +50%, and crit bonuses).
##   - vulnerability: the target's side (Marked on damage; healing taken on
##     heals).
##   - relic: relics' bonuses (none built yet).
## Each kind's total is basis points, never below FLOOR_BP (so nothing is
## cut by more than 90%). The factors are combined at basis-point precision
## in this fixed order, and the number is rounded once, at the end.

## The most a kind can take off: -90%.
const FLOOR_BP: int = -9000


## A kind's factor (basis points) from its total bonus.
static func factor(bonus_bp: int) -> int:
	return FixedMath.BP_ONE + maxi(bonus_bp, FLOOR_BP)


## `base` with each kind's total bonus (basis points, 0: none) applied.
static func apply(base: int, power_bp: int, crit_bp: int = 0, vulnerability_bp: int = 0, relic_bp: int = 0) -> int:
	if power_bp == 0 and crit_bp == 0 and vulnerability_bp == 0 and relic_bp == 0:
		return base
	var total: int = factor(power_bp)
	for bonus: int in [crit_bp, vulnerability_bp, relic_bp]:
		if bonus != 0:
			total = FixedMath.mul_div(total, factor(bonus), FixedMath.BP_ONE)
	return FixedMath.apply_bp(base, total)
