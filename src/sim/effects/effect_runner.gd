class_name EffectRunner
extends RefCounted
## Runs an ability's effects and writes each result to the combat log with
## its source (CLAUDE.md rule 4).
##
## When an ability fires, its on_fire effects run. Every hit a damage effect
## lands then runs the ability's on_hit effects, plus on_crit ones if it
## crit; their own hits never set off more. From 2 or more hexes away (see
## AbilityDef.is_shot), the effects aimed at the target ride a shot (Shots)
## and land when it does; the rest (on the unit itself, or every ally) happen
## as it fires.
##
## Numbers come from the unit's stats (with its auras). Damage, heals, and
## Shields then carry their power bonus (Passives.power_bp: output auras and
## a kit mod's power_bp, plus a tactic's payoff) to where they land, and the
## damage rule (DamageRule) applies it there with the hit's other kinds;
## statuses it applies may be swapped (replace_status).
## Built so far: damage, heal, shield, apply_status, cleanse, mana_drain,
## knockback, pull, leap, charge (Displacement), area (Areas; an area is
## cast as the ability fires, never riding a shot), and start_collapse
## (Collapse), and summon (Summons; near the ability's target, or for an
## event, the unit's current target). Phase 4 adds gain_mana, an on_fire
## effect's "every" (counted per ability: AbilityState.fires), the targets
## near the target and lowest_hp_ally, heals worth a share of the hit
## (lifesteal), and overheal that comes back as Shield.


## No point given (land's push_from).
const NO_POINT: Vector2i = Vector2i(-1073741824, -1073741824)


## What an on_hit or on_crit effect knows about the hit that set it off.
class Hit:
	var target: UnitState
	var damage: int
	var crit: bool


## The unit's basic attack fires at its target, and gives it mana.
static func basic_attack(sim: CombatSim, unit: UnitState) -> void:
	fire(sim, unit, unit.attack, unit.target, unit.stats.get_stat(UnitStats.Stat.RANGE))
	unit.sure_crit = false
	unit.tactic_backing = false if unit.tactic != null and unit.tactic.kind == TacticDef.Kind.KITE else unit.tactic_backing
	unit.attack.spend()
	if unit.submerges:
		# It surfaces to attack (phase 8 part 3, Submerge).
		unit.surfaced_until = sim.tick + Water.SURFACE_TICKS
		unit.submerged = false
	Mana.on_attack(sim, unit)


## `ability` fires from `unit` at `target`; `reach` (in hexes) decides whether
## it's a shot (AbilityDef.is_shot). An ability aimed at the unit itself never
## is. One that leaps fails whole if there's no room to land: nothing fires,
## and it returns false (the failure is logged unless `log_failure` is off).
static func fire(sim: CombatSim, unit: UnitState, state: AbilityState, target: UnitState, reach: int, log_failure: bool = true, note: String = "") -> bool:
	var ability: AbilityDef = state.def
	var source: EffectSource = state.source
	var leap: EffectDef = ability.leap_effect() if target != null else null
	if leap != null and Displacement.leap_spot(sim, unit, target, leap.hexes).x < 0:
		if log_failure:
			Displacement.leap_failed(sim, unit, target, source)
		return false
	# Wait to heal's payoff: its signature only ever fires once an ally is
	# hurt enough (Tactics.hurt_enough), and each such fire heals more.
	var heal_boost_bp: int = 0
	if state == unit.signature and unit.tactic != null and unit.tactic.heal_bp > 0:
		heal_boost_bp = unit.tactic.heal_bp  # power, like the healer's auras
		source = source.with_bonus(Tactics.bonus_note(heal_boost_bp, unit.tactic))
	# Wait for a crowd's and Save it for the kill's payoff (phase 5c step 6c):
	# the signature that waited deals more.
	var tactic_power_bp: int = 0
	if state == unit.signature and unit.tactic != null and (unit.tactic.power_bp > 0 or unit.tactic.per_extra_bp > 0):
		tactic_power_bp = Tactics.signature_power_bp(sim, unit, target)
		if tactic_power_bp > 0:
			source = source.with_bonus(Tactics.bonus_note(tactic_power_bp, unit.tactic))
	state.fires += 1
	var fired: LogEntry = sim.new_entry(LogEntry.Kind.FIRE, source)
	fired.target = target.id if target != null else ""
	fired.note = note
	sim.combat_log.add(fired)
	var shot: Shots.Shot = null
	if target != null and target != unit and ability.is_shot(reach):
		shot = Shots.Shot.new()
		shot.source = source
		shot.shooter = unit
		shot.ability = ability
		shot.target = target
	for effect: EffectDef in ability.effects:
		if effect.trigger != EffectDef.Trigger.ON_FIRE or not effect.active_at(sim.tick):
			continue
		if effect.every > 1 and state.fires % effect.every != 0:
			continue
		if effect.type == EffectDef.Type.AREA:
			Areas.cast(sim, unit, ability, source, effect, target, heal_boost_bp)
			continue
		if effect.type == EffectDef.Type.SNARE:
			Snares.set_ahead(sim, unit, ability, source, effect, target)
			continue
		if effect.type == EffectDef.Type.WALL:
			Walls.raise(sim, unit, source, effect, target)
			continue
		if effect.type == EffectDef.Type.FLOOD:
			Water.flood(sim, unit, source, effect, target)
			continue
		if effect.type == EffectDef.Type.SUMMON:
			Summons.summon(sim, unit, source, effect, target)
			continue
		var power: int = power_of(effect, unit, heal_boost_bp)
		if tactic_power_bp > 0 and effect.type == EffectDef.Type.DAMAGE:
			power += tactic_power_bp
		if shot != null and effect.target == EffectDef.Target.TARGET:
			var amount: int = amount_of(effect, unit, 0, sim)
			var crit: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability, target))
			shot.effects.append(effect)
			shot.amounts.append(amount)
			shot.powers.append(power)
			shot.crits.append(crit)
			continue
		for victim: UnitState in _targets(sim, unit, effect.target, target, null, effect):
			var crit_now: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability, victim))
			land(sim, unit, ability, source, effect, victim, amount_of(effect, unit, 0, sim), crit_now, NO_POINT, power)
			if effect.ricochet > 0 and effect.type == EffectDef.Type.DAMAGE:
				_ricochet(sim, unit, ability, source, effect, [target, victim] as Array[UnitState], amount_of(effect, unit, 0, sim), power)
	if shot != null and not shot.effects.is_empty():
		Shots.fire(sim, shot)
	return true


## Ricochet (phase 5c step 7d): a near-target hit hits again, up to its
## `ricochet` times, each at the standing enemy nearest the last one hit
## (within its reach, never one already hit), with the same numbers; each a
## DAMAGE line noted "ricochet".
static func _ricochet(sim: CombatSim, unit: UnitState, ability: AbilityDef, source: EffectSource, effect: EffectDef, hit: Array[UnitState], amount: int, power: int) -> void:
	var reach: int = effect.near_range if effect.near_range > 0 else HexGrid.HEX
	for i: int in effect.ricochet:
		var from: UnitState = hit[hit.size() - 1]
		var next: UnitState = null
		var best: int = 0
		for enemy: UnitState in sim.standing_enemies_of(unit):
			if hit.has(enemy):
				continue
			var distance: int = ArenaPlane.length_sq(enemy.pos - from.pos)
			if distance <= reach * reach and (next == null or distance < best):
				next = enemy
				best = distance
		if next == null:
			return
		deal_hit(sim, source, next, amount, sim.rng.roll_bp(crit_chance_bp(sim, unit, ability, next)), power, true, "ricochet")
		hit.append(next)


## An effect's power bonus from `unit` (Passives.power_bp), with a heal
## payoff's `heal_boost_bp` added to its heals.
static func power_of(effect: EffectDef, unit: UnitState, heal_boost_bp: int = 0) -> int:
	var power: int = Passives.power_bp(unit, effect)
	if heal_boost_bp != 0 and effect.type == EffectDef.Type.HEAL:
		power += heal_boost_bp
	return power


## One effect reaching `victim` with its number already worked out (as it
## fired, as its shot left, or as its area was cast): for damage, heals, and
## Shields, the base and its `power` bonus, which the damage rule applies
## here. A damage hit then sets off the ability's on_hit (and on a crit,
## on_crit) effects. A knockback goes away from `push_from` (an area's
## center), or else from the unit.
static func land(sim: CombatSim, unit: UnitState, ability: AbilityDef, source: EffectSource, effect: EffectDef, victim: UnitState, amount: int, crit: bool, push_from: Vector2i = NO_POINT, power: int = 0) -> void:
	match effect.type:
		EffectDef.Type.DAMAGE:
			var dealt: int = deal_hit(sim, source, victim, amount, crit, power)
			if effect.execute_below_bp > 0 and not sim.last_dodged:
				execute(sim, source, victim, effect.execute_below_bp)
			if effect.trigger == EffectDef.Trigger.ON_FIRE and ability != null and ability.has_hit_effects and not sim.last_dodged:
				var hit := Hit.new()
				hit.target = victim
				hit.crit = crit
				hit.damage = dealt
				_on_hit(sim, unit, ability, source, hit)
		EffectDef.Type.HEAL:
			if effect.amount_bp_of_max_hp > 0:
				amount = FixedMath.apply_bp(victim.max_hp, effect.amount_bp_of_max_hp)
			if not unit.vs_conditions.is_empty():
				# A heal's bonus on some allies (phase 5c step 7c, Urgent Mercy).
				power += Passives.vs_bonus_bp(unit, victim, AuraDef.Stat.HEAL_BP, source.ability_id)
			var overheal: int = heal(sim, victim, amount, source, effect.overheal_shield_bp, power, false, unit.relic_bonus_bp)
			if effect.overheal_max_hp_per > 0 and overheal > 0:
				_grow_max_hp(sim, unit, overheal, effect.overheal_max_hp_per, source)
		EffectDef.Type.SHIELD:
			if effect.amount_bp_of_max_hp > 0:
				amount = FixedMath.apply_bp(victim.max_hp, effect.amount_bp_of_max_hp)
			if not unit.vs_conditions.is_empty():
				# A Shield's bonus on some allies (phase 5c step 7c, Front Ward).
				power += Passives.vs_bonus_bp(unit, victim, AuraDef.Stat.SHIELD_BP, source.ability_id)
			var shield_entry: LogEntry = give_shield(sim, victim, DamageRule.apply(amount, power, 0, 0, unit.relic_bonus_bp), source)
			shield_entry.set_rule(amount, power, 0, 0, unit.relic_bonus_bp)
		EffectDef.Type.EXTEND_STATUS:
			Statuses.extend(sim, victim, effect.status_id, effect.duration_ticks, source)
		EffectDef.Type.APPLY_STATUS:
			var status_id: String = unit.status_swaps.get(effect.status_id, effect.status_id)
			# fresh_only: never on a unit that has it already (Snaring Shot).
			if not effect.fresh_only or Statuses.find(victim, status_id) == null:
				Statuses.apply(sim, victim, status_id, amount, effect.duration_ticks, source, effect.marks_stack, effect.until_near, effect.strength_add_bp, power)
		EffectDef.Type.CLEANSE:
			if effect.cleanse_count > 0:
				Statuses.cleanse_newest(sim, victim, effect.cleanse_count, source)
			else:
				Statuses.cleanse_over_time(sim, victim, mini(amount, FixedMath.BP_ONE), source, false, effect.cleanse_statuses)
		EffectDef.Type.MANA_DRAIN:
			Mana.drain(sim, victim, amount, source)
		EffectDef.Type.GAIN_MANA:
			if effect.mana_bp > 0:
				# A share of its bar (phase 5c step 6b; Execution's refund).
				if victim.def.mana != null:
					Mana.gain(sim, victim, FixedMath.apply_bp(victim.def.mana.max * Mana.SCALE, effect.mana_bp))
			else:
				Mana.gain(sim, victim, amount * Mana.SCALE)
		EffectDef.Type.KNOCKBACK:
			Displacement.knockback(sim, victim, unit.pos if push_from == NO_POINT else push_from, unit.forward(), effect.hexes, source)
		EffectDef.Type.PULL:
			match effect.toward:
				EffectDef.Toward.WATER:
					# Toward the nearest water (phase 8 part 3, Coiling Eel).
					if sim.has_water and not sim.water.hexes.is_empty():
						Displacement.pull_to(sim, victim, sim.water.nearest_center(sim.grid, victim.pos), effect.hexes, source)
				EffectDef.Toward.AREA:
					# Toward its area's middle (Undertow Tidecaller).
					if push_from != NO_POINT:
						Displacement.pull_to(sim, victim, push_from, effect.hexes, source)
				_:
					Displacement.pull(sim, victim, unit, effect.hexes, source)
		EffectDef.Type.LEAP:
			Displacement.leap(sim, unit, victim, effect, source)
		EffectDef.Type.HOP:
			Displacement.hop(sim, victim, source)
		EffectDef.Type.CHARGE:
			Displacement.charge(sim, unit, victim, effect, source)
		EffectDef.Type.START_COLLAPSE:
			Collapse.start_now(sim, source)
		EffectDef.Type.SUMMON:
			Summons.summon(sim, unit, source, effect, unit.target)


static func _on_hit(sim: CombatSim, unit: UnitState, ability: AbilityDef, source: EffectSource, hit: Hit) -> void:
	for effect: EffectDef in ability.effects:
		var wanted: bool = effect.trigger == EffectDef.Trigger.ON_HIT or (effect.trigger == EffectDef.Trigger.ON_CRIT and hit.crit)
		if not wanted or not effect.active_at(sim.tick):
			continue
		for victim: UnitState in _targets(sim, unit, effect.target, null, hit, effect):
			var amount: int = amount_of(effect, unit, hit.damage, sim)
			var crit: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability, victim))
			land(sim, unit, ability, source, effect, victim, amount, crit, NO_POINT, power_of(effect, unit))


## An ability passive's effect, set off by an event (Passives.on_event):
## `other` is the unit the event names, `damage` the hit it's about. It
## lands at once, and never sets off on_hit effects.
static func run_event(sim: CombatSim, unit: UnitState, ability: AbilityDef, source: EffectSource, effect: EffectDef, other: UnitState, damage: int) -> void:
	if effect.type == EffectDef.Type.AREA:
		Areas.cast(sim, unit, ability, source, effect, other if other != null else unit.target)
		return
	if effect.type == EffectDef.Type.SNARE:
		if effect.under_front:
			Snares.under_front(sim, unit)
		elif effect.snare_at_named and other != null:
			Snares.place(sim, unit, ability, source, effect, sim.nearest_safe_point(other.pos, 0))
		else:
			Snares.set_ahead(sim, unit, ability, source, effect, other if other != null else unit.target)
		return
	if effect.type == EffectDef.Type.WALL:
		Walls.raise(sim, unit, source, effect, other if other != null else unit.target)
		return
	if effect.type == EffectDef.Type.FLOOD:
		Water.flood(sim, unit, source, effect, other if other != null else unit.target)
		return
	var hit: Hit = null
	if other != null:
		hit = Hit.new()
		hit.target = other
		hit.damage = damage
	var amount: int = amount_of(effect, unit, damage, sim)
	if not effect.stacks_of.is_empty():
		# As many stacks as the unit the event names has (Pyre Ash).
		var state: StatusState = Statuses.find(other, effect.stacks_of) if other != null else null
		amount = state.total_stacks() if state != null and not state.def.is_timed() else 0
		if amount <= 0:
			return
		if effect.stacks_share_bp > 0:
			# A share of them, at least 1 (Ashen Engine; phase 5c step 5c).
			amount = maxi(FixedMath.apply_bp(amount, effect.stacks_share_bp), 1)
	for victim: UnitState in _targets(sim, unit, effect.target, unit.target, hit, effect):
		var crit: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability, victim))
		land(sim, unit, ability, source, effect, victim, amount, crit, NO_POINT, power_of(effect, unit))


## The effect's number: base plus stat scaling from the unit's stats (or a
## share of the hit's `damage`, for amount_bp_of_damage). A status's stacks
## then take the unit's damage-over-time auras; damage, heals, and Shields
## take their power where they land (power_of). (The same base
## ValueBreakdown.compute gives, worked out without building the breakdown.)
## `sim` counts the allies near the unit for a damage effect's
## bonus_per_ally.
static func amount_of(effect: EffectDef, unit: UnitState, damage: int = 0, sim: CombatSim = null) -> int:
	var amount: int
	if effect.amount_bp_of_damage > 0:
		amount = FixedMath.apply_bp(damage, effect.amount_bp_of_damage)
	else:
		amount = effect.base_value()
		for stat: int in effect.scaling.size():
			if effect.scaling[stat] != 0:
				amount += FixedMath.apply_bp(unit.stats.values[stat], effect.scaling[stat])
	if effect.bonus_bp_per_ally > 0 and sim != null:
		amount = FixedMath.apply_bp(amount, FixedMath.BP_ONE + effect.bonus_bp_per_ally * allies_near(sim, unit, effect))
	return Passives.boosted(unit, effect, amount)


## How many other standing allies (of bonus_kit, if it's set) stand within
## the effect's bonus_within of the unit.
static func allies_near(sim: CombatSim, unit: UnitState, effect: EffectDef) -> int:
	var count: int = 0
	var reach_sq: int = effect.bonus_within * effect.bonus_within
	for ally: UnitState in sim.standing_allies_of(unit):
		if ally != unit and (effect.bonus_kit.is_empty() or ally.def.id == effect.bonus_kit) and ArenaPlane.length_sq(ally.pos - unit.pos) <= reach_sq:
			count += 1
	return count


## `target`: what the attack is aimed at, for crit chance "vs" some targets
## (phase 5c step 5b; Executioner's Mark).
static func crit_chance_bp(sim: CombatSim, unit: UnitState, ability: AbilityDef, target: UnitState = null) -> int:
	var chance: int = ability.crit_chance_bp + unit.stats.get_stat(UnitStats.Stat.CRIT) * sim.tuning.crit_bp_per_point + unit.aura_bp[AuraDef.Stat.CRIT_CHANCE_BP]
	if target != null and not unit.vs_conditions.is_empty():
		chance += Passives.vs_bonus_bp(unit, target, AuraDef.Stat.CRIT_CHANCE_BP, ability.id)
	if unit.tactic != null:
		# Marked first's payoff, and Keep your distance's sure crit (phase 5c
		# step 6c).
		chance += Tactics.crit_bonus_bp(unit, target)
		if unit.sure_crit and ability == unit.def.basic_attack:
			chance += 2 * FixedMath.BP_ONE
	return chance


## Who an effect reaches: its ability's target, the unit hit, the unit
## itself, every standing unit of a side (in the fight's order), or those
## near the target (phase 4: near the ability's target, or the unit hit).
static func _targets(sim: CombatSim, unit: UnitState, target: EffectDef.Target, aimed_at: UnitState, hit: Hit, effect: EffectDef = null) -> Array[UnitState]:
	var found: Array[UnitState] = []
	if effect != null and (target == EffectDef.Target.ENEMIES_NEAR_SELF or target == EffectDef.Target.ALLIES_NEAR_SELF):
		return near(sim, unit, effect, unit)
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
		found = found.filter(func(other: UnitState) -> bool: return effect.only.holds(other))
	return found


## The units a near-target effect (or lowest_hp_ally) reaches, around
## `center` (phase 4; EffectDef has the rules). Ties go to the earlier unit
## in the fight's order.
static func near(sim: CombatSim, unit: UnitState, effect: EffectDef, center: UnitState) -> Array[UnitState]:
	var found: Array[UnitState] = []
	var reach_sq: int = effect.near_range * effect.near_range
	if effect.target == EffectDef.Target.LOWEST_HP_ALLY:
		var ally: UnitState = Targeting.pick(sim, unit, "lowest_hp_ally", reach_sq if effect.near_range > 0 else -1)
		if ally != null:
			found.append(ally)
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
	return found


## A relic's effect at the fight's start (phase 5c step 5b; RelicDef
## "at_start"), sourced to the relic: on all of a side, or the enemies
## nearest its side. Its numbers are flat, times `scale_bp` (Reliquary's
## doubling for a common), and so are timed statuses' durations.
static func run_relic(sim: CombatSim, source: EffectSource, effect: EffectDef, scale_bp: int = FixedMath.BP_ONE) -> void:
	var side: EffectSource.Team = source.relic_side as EffectSource.Team
	var own: Array[UnitState] = (sim.heroes if side == EffectSource.Team.HEROES else sim.enemies).filter(func(unit: UnitState) -> bool: return unit.alive)
	var foes: Array[UnitState] = (sim.enemies if side == EffectSource.Team.HEROES else sim.heroes).filter(func(unit: UnitState) -> bool: return unit.alive)
	var victims: Array[UnitState] = []
	match effect.target:
		EffectDef.Target.ALL_ALLIES:
			victims = own
		EffectDef.Target.ALL_ENEMIES:
			victims = foes
		EffectDef.Target.NEAREST_ENEMIES:
			victims = nearest_to(foes, own, effect.count)
	for victim: UnitState in victims:
		match effect.type:
			EffectDef.Type.APPLY_STATUS:
				var duration: int = effect.duration_ticks if effect.duration_ticks > 0 else sim.content.statuses[effect.status_id].duration_ticks
				Statuses.apply(sim, victim, effect.status_id, FixedMath.apply_bp(effect.stacks, scale_bp), FixedMath.apply_bp(duration, scale_bp), source)
			EffectDef.Type.SHIELD:
				var amount: int = FixedMath.apply_bp(victim.max_hp, effect.amount_bp_of_max_hp) if effect.amount_bp_of_max_hp > 0 else effect.amount
				give_shield(sim, victim, FixedMath.apply_bp(amount, scale_bp), source)
			EffectDef.Type.HEAL:
				heal(sim, victim, FixedMath.apply_bp(effect.amount, scale_bp), source)
			EffectDef.Type.DAMAGE:
				deal_hit(sim, source, victim, FixedMath.apply_bp(effect.amount, scale_bp), false)


## The `count` of `pool` nearest any of `others` (ties to the earlier in the
## fight's order).
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


## Lands a hit of `amount` (its base) on `target`: the damage rule (its
## `power`, plus a tactic's payoff; the crit's; the target's Mark), then
## DEF, then Shield, then HP. Logs it and returns what got through DEF.
## `steals`: false for a hit that never lifesteals (Shadow Engine's strike,
## which comes from lifesteal). `note` says what made it, if not an ability.
## `ruled`: a hit a hero rule made (an echo, a carry), which starts no echo
## or carry of its own (phase 5c step 5c).
## An execution (phase 8 part 2): a target the hit left standing below
## `below_bp` of its max HP loses the rest of its HP, past any Shield or
## DEF, logged as a DAMAGE line noted "executed" from the same source. The
## fall itself is the deaths step's, as for any other hit.
static func execute(sim: CombatSim, source: EffectSource, victim: UnitState, below_bp: int) -> void:
	if victim.hp <= 0 or victim.hp * FixedMath.BP_ONE >= below_bp * victim.max_hp:
		return
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.DAMAGE, source)
	entry.note = "executed"
	entry.target = victim.id
	entry.amount = victim.hp
	entry.set_rule(victim.hp, 0, 0, 0, 0)
	victim.hp = 0
	victim.executed = true
	victim.last_hit_chain = entry.chain
	victim.last_hit_source = source
	victim.last_hit_status = ""
	if source.relic_side < 0 and source.unit_id != victim.id:
		victim.last_attacker = source.unit_id
	sim.combat_log.add(entry)


static func deal_hit(sim: CombatSim, source: EffectSource, target: UnitState, amount: int, crit: bool, power: int = 0, steals: bool = true, note: String = "", ruled: bool = false) -> int:
	sim.last_dodged = false
	# Sidestep (phase 5c step 6b): a hit on it misses, then not again for a
	# while. Logged as DODGED; nothing else of the hit happens.
	if target.aura_bp[AuraDef.Stat.DODGE_EVERY_MS] > 0 and sim.tick >= target.dodge_ready_at:
		target.dodge_ready_at = sim.tick + maxi(FixedMath.ms_to_ticks(target.aura_bp[AuraDef.Stat.DODGE_EVERY_MS]), 1)
		var dodged: LogEntry = sim.new_entry(LogEntry.Kind.DODGED, source)
		dodged.target = target.id
		sim.combat_log.add(dodged)
		sim.last_dodged = true
		return 0
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.DAMAGE, source)
	entry.note = note
	if sim.damage_payoffs:
		var payoff: int = Tactics.damage_bonus_bp(sim, source, target)
		if payoff > 0:
			power += payoff
			entry.bonus = Tactics.bonus_note(payoff, sim.unit_by_id(source.unit_id).tactic)
	var attacker: UnitState = sim.unit_by_id(source.unit_id) if source.relic_side < 0 else null
	var per_hit: bool = sim.vs_auras and attacker != null and not attacker.vs_conditions.is_empty()
	if per_hit:
		power += Passives.vs_bonus_bp(attacker, target, AuraDef.Stat.DAMAGE_BP, source.ability_id)
	var marked: int = Statuses.damage_taken_bp(target)
	# Crit damage bonuses (phase 5c step 5b) add to the crit's own +50%.
	var crit_bp: int = sim.tuning.crit_damage_bp - FixedMath.BP_ONE + (attacker.aura_bp[AuraDef.Stat.CRIT_DAMAGE_BP] if attacker != null else 0) if crit else 0
	if crit and attacker != null:
		crit_bp += _more_crit_damage(sim, attacker, target, source, per_hit)
	var heroes_hit: bool = attacker != null and attacker.side == EffectSource.Team.HEROES and target.side != EffectSource.Team.HEROES
	entry.crits = 1 if crit else 0
	if crit and heroes_hit and sim.hero_rules.crit_steps > 0:
		crit_bp = _crit_chain(sim, attacker, target, source, crit_bp, entry)
	var raw: int = DamageRule.apply(amount, power, crit_bp, marked, attacker.relic_bonus_bp if attacker != null else 0)
	entry.set_rule(amount, power, crit_bp, marked, attacker.relic_bonus_bp if attacker != null else 0)
	# Iron Skin (phase 5c step 6b): its first hits taken land at half.
	if target.hits_halved < target.aura_bp[AuraDef.Stat.HALVED_HITS]:
		target.hits_halved += 1
		raw = FixedMath.apply_bp(raw, 5000)
		entry.note = ("%s, " % entry.note if not entry.note.is_empty() else "") + "halved"
	# Guard (phase 4): an ally's guard takes its share of the hit, against its
	# own DEF.
	var guard: UnitState = Guards.covering(sim, source, target) if not sim.guards.is_empty() else null
	var guarded_raw: int = FixedMath.apply_bp(raw, guard.guard.share_bp) if guard != null else 0
	var ignore_bp: int = 0
	if attacker != null:
		ignore_bp = attacker.aura_bp[AuraDef.Stat.DEF_IGNORE_BP] + (Tactics.def_ignore_bp(attacker, target) if attacker.tactic != null else 0)
	var dealt: int = sim.mitigate_hit(target, raw - guarded_raw, ignore_bp)
	var guarded: int = sim.mitigate_hit(guard, guarded_raw) if guard != null else 0
	entry.target = target.id
	entry.mitigated = maxi(raw - guarded_raw - dealt, 0)
	entry.amount = dealt
	entry.crit = crit
	var had_shield: bool = target.shield > 0
	var hp_before: int = target.hp
	# Linked Shields (phase 8 part 2): its link spreads part of the hit over
	# its other linked allies first (SHARED lines, logged before this one's).
	if not sim.linkers.is_empty() and target.woven_by != null:
		var kept: int = Links.split(sim, target, dealt, source)
		if kept != dealt:
			entry.note = ("%s, " % entry.note if not entry.note.is_empty() else "") + "shared"
			dealt = kept
			entry.amount = dealt
	entry.absorbed = sim.apply_damage(target, dealt)
	entry.broke_shield = had_shield and target.shield == 0
	# What went past the target's last HP (phase 5c step 5b; Overkill Tithe).
	entry.overkill = maxi(dealt - entry.absorbed - hp_before, 0)
	sim.last_overkill = entry.overkill
	target.last_hit_chain = entry.chain
	target.last_hit_source = source
	target.last_hit_status = ""
	if source.relic_side < 0 and source.unit_id != target.id:
		target.last_attacker = source.unit_id
	sim.combat_log.add(entry)
	if guarded > 0:
		Guards.take(sim, guard, target, guarded, source)
	# A tactic's first hit on each enemy, and a crit stretching a Mark (phase
	# 5c step 6c).
	if sim.damage_payoffs and attacker != null and attacker.tactic != null and Tactics.own_hit(attacker, source):
		Tactics.on_hit(sim, attacker, target, crit)
	if steals and attacker != null and sim.lifesteal and dealt > 0 and attacker.side != target.side:
		lifesteal(sim, attacker, target, dealt, source)
	if heroes_hit and not ruled:
		var overkill: int = entry.overkill
		if sim.hero_rules.echo_steps > 0 and dealt > 0:
			_echo(sim, attacker, target, dealt, source)
		if sim.hero_rules.carry_steps > 0 and overkill > 0:
			_carry(sim, attacker, target, overkill, source)
	return dealt


## Crown of Stars (the heroes' rule crit_chain; phase 5c step 5c): a crit
## rolls again, the k-th extra roll at the crit chance times (100% − fade·k)
## and adding the crit bonus times as much (under Chain of Echoes, times
## growth_bp(k) instead), until one misses or the steps run out. Returns the
## crit kind's bonus with the extra crits; the entry counts them.
static func _crit_chain(sim: CombatSim, attacker: UnitState, target: UnitState, source: EffectSource, crit_bp: int, entry: LogEntry) -> int:
	var rules: SideRules = sim.hero_rules
	var chance: int = attacker.stats.get_stat(UnitStats.Stat.CRIT) * sim.tuning.crit_bp_per_point + attacker.aura_bp[AuraDef.Stat.CRIT_CHANCE_BP]
	if not attacker.vs_conditions.is_empty():
		chance += Passives.vs_bonus_bp(attacker, target, AuraDef.Stat.CRIT_CHANCE_BP, source.ability_id)
	var total: int = crit_bp
	for k: int in range(1, rules.crit_steps + rules.deeper_steps + 1):
		var factor: int = rules.growth_bp(k) if rules.deeper_steps > 0 else FixedMath.BP_ONE - rules.crit_fade_bp * k
		if factor <= 0 or not sim.rng.roll_bp(FixedMath.apply_bp(chance, factor)):
			break
		total += FixedMath.apply_bp(crit_bp, factor)
		entry.crits += 1
	return total


## Shared Pain (echo_keywords): `dealt` on `target` echoes to every other
## standing enemy with the keyword the most of them share with it (ties to
## Keywords' order), at share_bp (compounded each step; under Chain of
## Echoes, growth_bp instead), and each echo echoes on, each enemy hit once a
## step, one chain step deeper each.
static func _echo(sim: CombatSim, attacker: UnitState, target: UnitState, dealt: int, source: EffectSource) -> void:
	var rules: SideRules = sim.hero_rules
	var foes: Array[UnitState] = []
	foes.assign(sim.standing_enemies_of(attacker).filter(func(unit: UnitState) -> bool: return unit.hp > 0))
	var keyword: String = ""
	var most: int = 0
	for name: String in Keywords.NAMES:
		if not Keywords.has(target, name):
			continue
		var sharing: int = foes.filter(func(unit: UnitState) -> bool: return unit != target and Keywords.has(unit, name)).size()
		if sharing > most:
			most = sharing
			keyword = name
	if keyword.is_empty():
		return
	var outer: int = sim.chain_depth
	var share: int = FixedMath.BP_ONE
	var last: Array[UnitState] = [target]
	for step: int in range(1, rules.echo_steps + rules.deeper_steps + 1):
		share = rules.growth_bp(step) if rules.deeper_steps > 0 else FixedMath.apply_bp(share, rules.echo_share_bp)
		var amount: int = FixedMath.apply_bp(dealt, share)
		if amount <= 0:
			break
		var hit: Array[UnitState] = []
		for foe: UnitState in sim.standing_enemies_of(attacker):
			if foe.hp > 0 and Keywords.has(foe, keyword) and last.any(func(echoer: UnitState) -> bool: return echoer != foe):
				hit.append(foe)
		if hit.is_empty():
			break
		sim.chain_depth = outer + step
		for foe: UnitState in hit:
			deal_hit(sim, source, foe, amount, false, 0, true, "Shared Pain", true)
		last = hit
	sim.chain_depth = outer


## The Hungering Rift (carry_overkill): `overkill` past `fallen`'s last HP
## hits the standing enemy nearest it, and that hit's overkill carries on,
## up to the steps (each carry ×growth_bp(1) under Chain of Echoes).
static func _carry(sim: CombatSim, attacker: UnitState, fallen: UnitState, overkill: int, source: EffectSource) -> void:
	var rules: SideRules = sim.hero_rules
	var outer: int = sim.chain_depth
	var from: UnitState = fallen
	var amount: int = overkill
	for step: int in range(1, rules.carry_steps + rules.deeper_steps + 1):
		var next: UnitState = null
		var best: int = -1
		for foe: UnitState in sim.standing_enemies_of(attacker):
			if foe == from or foe.hp <= 0:
				continue
			var distance_sq: int = ArenaPlane.length_sq(foe.pos - from.pos)
			if best < 0 or distance_sq < best:
				best = distance_sq
				next = foe
		if next == null or amount <= 0:
			break
		if rules.deeper_steps > 0:
			amount = FixedMath.apply_bp(amount, rules.growth_bp(1))
		sim.chain_depth = outer + step
		deal_hit(sim, source, next, amount, false, 0, true, "carried (The Hungering Rift)", true)
		amount = sim.last_overkill
		from = next
	sim.chain_depth = outer


## What a crit by `attacker` adds to crit damage beyond its auras (phase 5c
## step 5c): per-hit crit damage (Hunter's Engine, per Mark stack), and its
## crit chance past 100% times its crit_overflow_bp (Knife's Edge; the
## chance from CRIT and its crit-chance auras).
static func _more_crit_damage(sim: CombatSim, attacker: UnitState, target: UnitState, source: EffectSource, per_hit: bool) -> int:
	var more: int = Passives.vs_bonus_bp(attacker, target, AuraDef.Stat.CRIT_DAMAGE_BP, source.ability_id) if per_hit else 0
	var overflow: int = attacker.aura_bp[AuraDef.Stat.CRIT_OVERFLOW_BP]
	if overflow > 0:
		var chance: int = attacker.stats.get_stat(UnitStats.Stat.CRIT) * sim.tuning.crit_bp_per_point + attacker.aura_bp[AuraDef.Stat.CRIT_CHANCE_BP]
		if chance > FixedMath.BP_ONE:
			more += FixedMath.apply_bp(chance - FixedMath.BP_ONE, overflow)
	return more


## The attacker heals its lifesteal's share of a hit's `dealt` damage (phase
## 5c step 5b): its own line (LIFESTEAL), not a heal, so nothing that reacts
## to healing sees it (relics/README rule 5; Decision 21). Phase 5c step 5c:
## with lifesteal_heals (Blood Communion) it's a heal instead (a HEAL line
## marked lifesteal: heal power, healing taken, on_heal, and overheal to
## Shield all see it); and with overheal_strike_bp (Shadow Engine) what it
## would heal past full HP hits the attacker's target for that share.
static func lifesteal(sim: CombatSim, attacker: UnitState, target: UnitState, dealt: int, source: EffectSource) -> void:
	var share: int = attacker.aura_bp[AuraDef.Stat.LIFESTEAL_BP]
	if not attacker.vs_conditions.is_empty():
		share += Passives.vs_bonus_bp(attacker, target, AuraDef.Stat.LIFESTEAL_BP, source.ability_id)
	if share <= 0 or not attacker.alive:
		return
	var wanted: int = FixedMath.apply_bp(dealt, share)
	if wanted <= 0:
		return
	var overheal: int
	if attacker.aura_bp[AuraDef.Stat.LIFESTEAL_HEALS] > 0:
		overheal = heal(sim, attacker, wanted, source, 0, attacker.aura_bp[AuraDef.Stat.HEAL_BP] - FixedMath.BP_ONE, true)
	else:
		var healed: int = clampi(wanted, 0, attacker.max_hp - attacker.hp)
		overheal = wanted - healed
		if healed > 0:
			attacker.hp += healed
			var entry: LogEntry = sim.new_entry(LogEntry.Kind.LIFESTEAL, source)
			entry.target = attacker.id
			entry.amount = healed
			sim.combat_log.add(entry)
	# The strike is one chain step deeper, and none comes at the chain limit:
	# a strike's hit can echo (Shared Pain), and the echo's lifesteal strike
	# again, so without the guard the two would call each other forever.
	var strike: int = attacker.aura_bp[AuraDef.Stat.OVERHEAL_STRIKE_BP]
	if strike > 0 and overheal > 0 and attacker.target != null and attacker.target.alive and attacker.target.side != attacker.side \
			and sim.chain_depth < sim.chain_limit_of(attacker.id, -1):
		var outer: int = sim.chain_depth
		sim.chain_depth = outer + 1
		deal_hit(sim, source, attacker.target, FixedMath.apply_bp(overheal, strike), false, 0, false, "overheal from lifesteal")
		sim.chain_depth = outer


## Heals `target` (capped at its max HP), logs it, and if any HP came back,
## weakens its damage over time. The first heal in a window strips
## heal_cleanse_bp of each damage-over-time status; each further heal within
## heal_cleanse_window strips that share times heal_cleanse_falloff_bp again
## (by default 10%, 5%, 2.5%, ...), so rapid small heals can't wipe it out.
## `overheal_shield_bp`: what the heal would have restored past full HP comes
## back as that share of Shield (phase 4, Ward Thread).
## `amount` is the heal's base: the damage rule applies its `power` and the
## target's healing taken (the target's side, like a Mark on damage).
## The healer's overheal_shield_bp aura (Overflow Chalice; phase 5c step 5c)
## adds to the heal's own share. `by_lifesteal` marks lifesteal that heals
## (Blood Communion). Returns what it would have restored past full HP.
## `relic_bp`: the relic kind's bonus (Chain of Echoes' growth).
static func heal(sim: CombatSim, target: UnitState, amount: int, source: EffectSource, overheal_shield_bp: int = 0, power: int = 0, by_lifesteal: bool = false, relic_bp: int = 0) -> int:
	var base: int = amount
	var taken_bp: int = target.aura_bp[AuraDef.Stat.HEALING_TAKEN_BP] - FixedMath.BP_ONE
	amount = DamageRule.apply(amount, power, 0, taken_bp, relic_bp)
	var healed: int = clampi(target.max_hp - target.hp, 0, amount)
	target.hp += healed
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.HEAL, source)
	entry.set_rule(base, power, 0, taken_bp, relic_bp)
	entry.target = target.id
	entry.amount = healed
	entry.lifesteal = by_lifesteal
	sim.combat_log.add(entry)
	if sim.overheal_auras and source.relic_side < 0:
		var healer: UnitState = sim.unit_by_id(source.unit_id)
		if healer != null:
			overheal_shield_bp += healer.aura_bp[AuraDef.Stat.OVERHEAL_SHIELD_BP]
	if overheal_shield_bp > 0 and amount > healed:
		var shield: int = FixedMath.apply_bp(amount - healed, overheal_shield_bp)
		if shield > 0:
			give_shield(sim, target, shield, source)
	if healed <= 0:
		return amount - healed
	var window_start: int = sim.tick - sim.tuning.heal_cleanse_window_ticks
	while not target.recent_heal_ticks.is_empty() and target.recent_heal_ticks[0] <= window_start:
		target.recent_heal_ticks.remove_at(0)
	var share_bp: int = sim.tuning.heal_cleanse_bp
	for i: int in target.recent_heal_ticks.size():
		share_bp = FixedMath.apply_bp(share_bp, sim.tuning.heal_cleanse_falloff_bp)
	target.recent_heal_ticks.append(sim.tick)
	if not target.statuses.is_empty():
		Statuses.cleanse_over_time(sim, target, share_bp, source, true)
	return amount - healed


## `unit` banks `overheal` and gains +1 max HP (and HP) for every `per` of
## it, for the fight (phase 8 part 2, The Hearthkeeper; MAX_HP_UP).
static func _grow_max_hp(sim: CombatSim, unit: UnitState, overheal: int, per: int, source: EffectSource) -> void:
	unit.overheal_bank += overheal
	@warning_ignore("integer_division")
	var gain: int = unit.overheal_bank / per
	if gain <= 0 or not unit.alive:
		return
	unit.overheal_bank -= gain * per
	unit.base_max_hp += gain
	unit.max_hp += gain
	unit.hp += gain
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.MAX_HP_UP, source)
	entry.target = unit.id
	entry.amount = gain
	sim.combat_log.add(entry)


static func give_shield(sim: CombatSim, target: UnitState, amount: int, source: EffectSource) -> LogEntry:
	target.shield += amount
	# A Shield from a unit with a link links its holder (phase 8 part 2).
	if not sim.linkers.is_empty() and amount > 0 and source.relic_side < 0:
		var giver: UnitState = sim.unit_by_id(source.unit_id)
		if giver != null and giver.link != null and giver.side == target.side:
			target.woven_by = giver
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.SHIELD, source)
	entry.target = target.id
	entry.amount = amount
	sim.combat_log.add(entry)
	return entry
