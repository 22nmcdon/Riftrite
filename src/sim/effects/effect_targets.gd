class_name EffectTargets
extends RefCounted
## Who an effect reaches, for EffectRunner (docs/plans/phases/rebuild-phase1-arena-sim.md,
## section 6, and the targets added since): its ability's target, the unit hit,
## the unit itself, every enemy or ally, near-target groups, the farthest, the
## toughest, the most targeted, the lowest on mana, and those round each ally.
## Read only: picking targets changes nothing (the clean-up,
## docs/plans/phases/cleanup-and-layout.md).


## Who an effect reaches: its ability's target, the unit hit, the unit
## itself, every standing unit of a side (in the fight's order), or those
## near the target (phase 4: near the ability's target, or the unit hit).
static func reached(sim: CombatSim, unit: UnitState, target: EffectDef.Target, aimed_at: UnitState, hit: EffectRunner.Hit, effect: EffectDef = null) -> Array[UnitState]:
	var found: Array[UnitState] = []
	if effect != null and (target == EffectDef.Target.ENEMIES_NEAR_SELF or target == EffectDef.Target.ALLIES_NEAR_SELF):
		return near(sim, unit, effect, unit)
	if effect != null and target == EffectDef.Target.FARTHEST_ENEMIES:
		return farthest(sim, unit, effect)
	if effect != null and target == EffectDef.Target.LOWEST_MANA_ALLY:
		return lowest_mana(sim, unit, effect.count)
	if effect != null and target == EffectDef.Target.MOST_TARGETED_ALLY:
		return most_targeted(sim, unit, effect.count)
	if effect != null and target == EffectDef.Target.TOUGHEST_ENEMIES:
		return toughest(sim, unit, effect)
	if effect != null and target == EffectDef.Target.ENEMIES_NEAR_ALLIES:
		found.assign(around_allies(sim, unit, effect).map(func(pair: Array) -> UnitState: return pair[0]))
		return found
	if effect != null and EffectDef.NAMED_TARGETS.has(target):
		return near(sim, unit, effect, hit.target if hit != null else null)
	if effect != null and (EffectDef.NEAR_TARGETS.has(target) or target == EffectDef.Target.LOWEST_HP_ALLY):
		return near(sim, unit, effect, aimed_at if aimed_at != null else (hit.target if hit != null else null))
	match target:
		EffectDef.Target.TARGET:
			if aimed_at != null and aimed_at.alive:
				found.append(aimed_at)
		EffectDef.Target.HIT_TARGET:
			if hit != null and hit.target.alive:
				found.append(hit.target)
		EffectDef.Target.SELF:
			if unit.alive:
				found.append(unit)
		EffectDef.Target.TRIGGER_ALLY:
			if hit != null and hit.target.alive:
				found.append(hit.target)
		EffectDef.Target.ALL_ENEMIES:
			found = sim.standing_enemies_of(unit)
		EffectDef.Target.ALL_ALLIES:
			found = sim.standing_allies_of(unit)
	if effect != null and effect.only != null:
		# Only those that meet it (phase 8 part 3, Undertow: on water).
		found = found.filter(func(other: UnitState) -> bool: return effect.only.holds(other, unit))
	return found


## The `count` targetable enemies farthest from `unit` within the effect's
## reach, farthest first; ties go to the earlier unit in the fight's order
## (phase 8 part 4: Haul's habit).
static func farthest(sim: CombatSim, unit: UnitState, effect: EffectDef) -> Array[UnitState]:
	var reach_sq: int = effect.near_range * effect.near_range
	var keyed: Array[Array] = []
	for enemy: UnitState in sim.targetable_enemies_of(unit):
		var distance_sq: int = ArenaPlane.length_sq(enemy.pos - unit.pos)
		if distance_sq <= reach_sq:
			keyed.append([distance_sq, keyed.size(), enemy])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	if effect.prefer != null:
		# The enemies it prefers first, farthest first (phase 8 part 4,
		# Back-Line Hook); a stable split keeps each part's order.
		var first: Array[Array] = []
		var rest: Array[Array] = []
		for item: Array in keyed:
			if effect.prefer.holds(item[2], unit):
				first.append(item)
			else:
				rest.append(item)
		first.append_array(rest)
		keyed = first
	var found: Array[UnitState] = []
	for item: Array in keyed.slice(0, effect.count):
		found.append(item[2])
	return found


## The units a near-target effect (or lowest_hp_ally) reaches, around
## `center` (phase 4; EffectDef has the rules). Ties go to the earlier unit
## in the fight's order.
static func near(sim: CombatSim, unit: UnitState, effect: EffectDef, center: UnitState) -> Array[UnitState]:
	var found: Array[UnitState] = []
	var reach_sq: int = effect.near_range * effect.near_range
	if effect.target == EffectDef.Target.LOWEST_HP_ALLY:
		# A habit's preference (phase 8 part 5, The Lamp of Ichor: Severine first).
		var ally: UnitState = Targeting.pick(sim, unit, "lowest_hp_ally", reach_sq if effect.near_range > 0 else -1, effect.prefer)
		if ally != null:
			found.append(ally)
		if effect.count > 1 and ally != null:
			# The next lowest too (phase 8 part 5, Bastion of Saints' taste).
			var pool: Array[UnitState] = sim.standing_allies_of(unit).filter(func(other: UnitState) -> bool:
				return effect.near_range <= 0 or ArenaPlane.length_sq(other.pos - unit.pos) <= reach_sq)
			while found.size() < effect.count:
				pool = pool.filter(func(other: UnitState) -> bool: return not found.has(other))
				var next: UnitState = Targeting._lowest_share(pool)
				if next == null:
					break
				found.append(next)
		return found
	if center == null:
		return found
	var enemies: bool = effect.target != EffectDef.Target.ALLY_NEAR_TARGET and effect.target != EffectDef.Target.ALLIES_NEAR_TARGET \
		and effect.target != EffectDef.Target.ALLIES_NEAR_SELF
	var pool: Array[UnitState] = sim.targetable_enemies_of(unit) if enemies else sim.standing_allies_of(unit)
	var single: bool = effect.target == EffectDef.Target.ENEMY_NEAR_TARGET or effect.target == EffectDef.Target.ALLY_NEAR_TARGET \
		or effect.target == EffectDef.Target.ENEMY_NEAR_NAMED
	var best: UnitState = null
	var best_sq: int = 0
	for other: UnitState in pool:
		if other == center:
			continue
		# Only those that meet it (phase 8 part 4, Scent's step: Marked).
		if effect.only != null and not effect.only.holds(other, unit):
			continue
		var distance_sq: int = ArenaPlane.length_sq(other.pos - center.pos)
		if effect.near_range > 0 and distance_sq > reach_sq:
			continue
		if not single:
			found.append(other)
		elif best == null or distance_sq < best_sq:
			best = other
			best_sq = distance_sq
	if best != null:
		found.append(best)
	if effect.target == EffectDef.Target.ALLIES_NEAR_SELF and effect.nearest > 0 and found.size() > effect.nearest:
		# The nearest few (phase 8 part 6, Blessing): a stable sort keeps the
		# fight's order on ties.
		var keyed: Array[Array] = []
		for other: UnitState in found:
			keyed.append([ArenaPlane.length_sq(other.pos - center.pos), keyed.size(), other])
		keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		found.clear()
		for item: Array in keyed.slice(0, effect.nearest):
			found.append(item[2])
	return found


## The `count` of `pool` nearest any of `others` (ties to the earlier in the
## fight's order).
## The `count` other standing allies of `unit` with a mana bar whose bars are
## least full (a share of the bar), fight order on ties (phase 8 part 4,
## Shared Breath).
static func lowest_mana(sim: CombatSim, unit: UnitState, count: int) -> Array[UnitState]:
	var pool: Array[UnitState] = sim.standing_allies_of(unit).filter(func(ally: UnitState) -> bool: return ally != unit and ally.def.mana != null)
	var found: Array[UnitState] = []
	for i: int in mini(count, pool.size()):
		var best: UnitState = null
		var best_share: int = 0
		for ally: UnitState in pool:
			if found.has(ally):
				continue
			@warning_ignore("integer_division")
			var share: int = ally.mana * FixedMath.BP_ONE / maxi(ally.def.mana.max * Mana.SCALE, 1)
			if best == null or share < best_share:
				best = ally
				best_share = share
		found.append(best)
	return found


## The `count` standing allies of `unit` (itself too) the most enemies are
## targeting, most first, ties to the lowest share of HP, then the fight's
## order (phase 8 part 6, Shroud): with none targeted, the lowest on HP.
static func most_targeted(sim: CombatSim, unit: UnitState, count: int) -> Array[UnitState]:
	var pool: Array[UnitState] = sim.standing_allies_of(unit)
	var chasers: Dictionary[UnitState, int] = {}
	for enemy: UnitState in sim.standing_enemies_of(unit):
		if enemy.target != null and enemy.target.alive and enemy.target.side == unit.side:
			chasers[enemy.target] = chasers.get(enemy.target, 0) + 1
	var found: Array[UnitState] = []
	for i: int in mini(count, pool.size()):
		var best: UnitState = null
		for ally: UnitState in pool:
			if found.has(ally):
				continue
			var more: int = chasers.get(ally, 0) - (chasers.get(best, 0) if best != null else 0)
			if best == null or more > 0 or (more == 0 and Targeting._lower_share(ally, best)):
				best = ally
		found.append(best)
	return found


## The effect's "count" standing enemies of `unit` (among those that meet
## its "only") with the most max HP, the most first; ties go to the earlier
## in the fight's order (phase 8 part 6, Hob's Bounty).
static func toughest(sim: CombatSim, unit: UnitState, effect: EffectDef) -> Array[UnitState]:
	var keyed: Array[Array] = []
	for enemy: UnitState in sim.standing_enemies_of(unit):
		if effect.only == null or effect.only.holds(enemy, unit):
			keyed.append([enemy.max_hp, keyed.size(), enemy])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var found: Array[UnitState] = []
	for i: int in mini(effect.count, keyed.size()):
		found.append(keyed[i][2])
	return found


## The enemies within the effect's reach of each standing ally of `unit`
## (itself too) that meets its "around", each once, with the ally it's
## nearest by that order: [enemy, ally] (phase 8 part 4, Gale: a push goes
## away from that ally).
static func around_allies(sim: CombatSim, unit: UnitState, effect: EffectDef) -> Array[Array]:
	var pairs: Array[Array] = []
	var taken: Dictionary[String, bool] = {}
	var reach_sq: int = effect.near_range * effect.near_range
	for ally: UnitState in sim.standing_allies_of(unit):
		if effect.around != null and not effect.around.holds(ally, unit):
			continue
		for enemy: UnitState in sim.targetable_enemies_of(unit):
			if taken.has(enemy.id) or ArenaPlane.length_sq(enemy.pos - ally.pos) > reach_sq:
				continue
			if effect.only != null and not effect.only.holds(enemy, unit):
				continue
			taken[enemy.id] = true
			pairs.append([enemy, ally])
	return pairs


## The standing ally of `unit` (not itself or `besides`) nearest it, by
## distance then the fight's order; null if there's none.
static func nearest_ally(sim: CombatSim, unit: UnitState, besides: UnitState) -> UnitState:
	var best: UnitState = null
	var best_d: int = 0
	for other: UnitState in sim.standing_allies_of(unit):
		if other == unit or other == besides:
			continue
		var d: int = ArenaPlane.length_sq(other.pos - unit.pos)
		if best == null or d < best_d:
			best = other
			best_d = d
	return best


static func nearest_to(pool: Array[UnitState], others: Array[UnitState], count: int) -> Array[UnitState]:
	var picked: Array[UnitState] = []
	var left: Array[UnitState] = pool.duplicate()
	while picked.size() < count and not left.is_empty():
		var best: int = 0
		var best_sq: int = -1
		for i: int in left.size():
			for other: UnitState in others:
				var distance_sq: int = ArenaPlane.length_sq(left[i].pos - other.pos)
				if best_sq < 0 or distance_sq < best_sq:
					best_sq = distance_sq
					best = i
		picked.append(left.pop_at(best))
	return picked
