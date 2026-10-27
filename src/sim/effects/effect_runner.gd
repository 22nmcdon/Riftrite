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
	if ability.by_companion and unit.owner == null:
		# Its companion does it, from where it stands (phase 8 part 6, Sic 'Em).
		var pet: UnitState = sim.companion_of(unit)
		if pet == null:
			return false
		var done: bool = fire(sim, pet, pet.command(state), target, pet.stats.get_stat(UnitStats.Stat.RANGE), log_failure, note)
		if done:
			state.fires += 1
		return done
	var source: EffectSource = state.source
	var leap: EffectDef = ability.leap_effect() if target != null else null
	if leap != null and not leap.leap_home and not leap.leap_step and Displacement.leap_spot(sim, unit, target, leap.hexes, leap.leap_behind).x < 0:
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
		shot.from_stealth = not unit.statuses.is_empty() and Statuses.is_stealthed(unit)
	for effect: EffectDef in ability.effects:
		if effect.trigger != EffectDef.Trigger.ON_FIRE or not effect.active_at(sim.tick):
			continue
		if effect.every > 1 and state.fires % effect.every != 0:
			continue
		if effect.type == EffectDef.Type.AREA:
			if effect.at_groups > 0:
				# On each of the largest groups (phase 8 part 6, Firestorm).
				for middle: UnitState in Targeting.largest_groups(sim, unit, effect.at_groups):
					Areas.cast(sim, unit, ability, source, effect, middle, heal_boost_bp)
				continue
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
		var named_stacks: int = -1
		if not effect.stacks_of.is_empty():
			# As many stacks as the ability's target has (phase 8 part 6,
			# Immolate's splash), read as it fires.
			named_stacks = stacks_from(effect, target, unit)
			if named_stacks <= 0:
				continue
		if shot != null and effect.target == EffectDef.Target.TARGET:
			var amount: int = per_stack(effect, target, amount_of(effect, unit, 0, sim) if named_stacks < 0 else named_stacks)
			var crit: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability, target))
			shot.effects.append(effect)
			shot.amounts.append(amount)
			shot.powers.append(power)
			shot.crits.append(crit)
			continue
		if effect.target == EffectDef.Target.ENEMIES_NEAR_ALLIES:
			# Round each ally, pushing away from it (phase 8 part 4, Gale).
			for pair: Array in EffectTargets.around_allies(sim, unit, effect):
				var crit_round: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability, pair[0]))
				land(sim, unit, ability, source, effect, pair[0], amount_of(effect, unit, 0, sim), crit_round, (pair[1] as UnitState).pos, power)
			continue
		for victim: UnitState in EffectTargets.reached(sim, unit, effect.target, target, null, effect):
			var crit_now: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability, victim))
			land(sim, unit, ability, source, effect, victim, per_stack(effect, victim, amount_of(effect, unit, 0, sim) if named_stacks < 0 else named_stacks), crit_now, NO_POINT, power)
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
		EffectHits.deal_hit(sim, source, next, amount, sim.rng.roll_bp(crit_chance_bp(sim, unit, ability, next)), power, true, "ricochet")
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
	# Only with enough of its side on the same target (phase 8 part 3, the
	# Cliffmite).
	if effect.when_attackers > 0 and attackers_on(sim, unit, victim, effect.when_attackers_kits) < effect.when_attackers:
		return
	match effect.type:
		EffectDef.Type.DAMAGE:
			var dealt: int = EffectHits.deal_hit(sim, source, victim, amount, crit, power, not effect.plain, "", false, effect.ignores_def, effect.lifesteal_bp)
			if effect.execute_below_bp > 0 and not sim.last_dodged and (effect.execute_vs == null or effect.execute_vs.holds(victim, unit)):
				EffectHits.execute(sim, source, victim, effect.execute_below_bp)
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
			if effect.as_lifesteal:
				# It lands as the target's own lifesteal (phase 8 part 5, The Iron
				# Maw): a LIFESTEAL line, Engorge past full; never healing.
				EffectHits.steal(sim, victim, DamageRule.apply(amount, power, 0, 0, unit.relic_bonus_bp), source)
				return
			var ceiling: int = -1
			if effect.heal_cap_bp > 0 and (effect.heal_cap_vs == null or effect.heal_cap_vs.holds(victim, unit)):
				# Lantern Vigil (phase 8 part 6): no higher than the cap; the rest
				# is a Shield.
				ceiling = FixedMath.apply_bp(victim.max_hp, effect.heal_cap_bp)
			var overheal: int = EffectHits.heal(sim, victim, amount, source, effect.overheal_shield_bp, power, false, unit.relic_bonus_bp, ceiling)
			if effect.overheal_max_hp_per > 0 and overheal > 0:
				EffectHits.grow_max_hp(sim, unit, overheal, effect.overheal_max_hp_per, source)
			if effect.overheal_per > 0 and overheal >= effect.overheal_per:
				# Kindred Flame (phase 8 part 6): the heal past full sets the enemy
				# nearest the healed unit Burning.
				var nearest: UnitState = Targeting.straight_nearest(victim, sim.targetable_enemies_of(victim))
				if nearest != null:
					@warning_ignore("integer_division")
					Statuses.apply(sim, nearest, effect.overheal_status, overheal / effect.overheal_per, 0, source)
		EffectDef.Type.SHIELD:
			if effect.amount_bp_of_max_hp > 0:
				amount = FixedMath.apply_bp(victim.max_hp, effect.amount_bp_of_max_hp)
			if effect.plus_per_shard_bp > 0:
				# Golden Aegis (phase 8 part 5): more for the shards held.
				amount += FixedMath.apply_bp(sim.shards_held(unit), effect.plus_per_shard_bp)
			if not unit.vs_conditions.is_empty():
				# A Shield's bonus on some allies (phase 5c step 7c, Front Ward).
				power += Passives.vs_bonus_bp(unit, victim, AuraDef.Stat.SHIELD_BP, source.ability_id)
			var given: int = DamageRule.apply(amount, power, 0, 0, unit.relic_bonus_bp)
			if effect.cap_bp_of_max_hp > 0:
				# No more than fills it to its cap (phase 8 part 4, Plated Blows).
				given = mini(given, maxi(FixedMath.apply_bp(victim.max_hp, effect.cap_bp_of_max_hp) - victim.shield, 0))
				if given <= 0:
					return
			if effect.shield_up_to:
				# Up to its amount (phase 8 part 6, Recast the Idol).
				given = maxi(given - victim.shield, 0)
				if given <= 0:
					return
			var shield_entry: LogEntry = EffectHits.give_shield(sim, victim, given, source)
			shield_entry.set_rule(amount, power, 0, 0, unit.relic_bonus_bp)
		EffectDef.Type.SPEND_SHIELD:
			EffectHits.spend_shield(sim, victim, source, effect.keep_bp)
		EffectDef.Type.RELEASE_STORED:
			EffectHits.release_stored(sim, victim, source)
		EffectDef.Type.SPEND_ENGORGED:
			EffectHits.spend_engorged(sim, victim, source)
		EffectDef.Type.GAIN_MAX_HP:
			EffectHits.gain_max_hp(sim, victim, amount, source)
		EffectDef.Type.SHARDS:
			# Collection (phase 8 part 5): shards for the run, from this fight,
			# each spending a stack of its window while one is left.
			if not effect.spends.is_empty() and not Statuses.spend_stack(sim, unit, effect.spends):
				return
			# Its kit's cap for the fight (phase 8 part 6, Gilded Death): the
			# rest is logged as capped, and never paid.
			var paying: int = amount if unit.def.shard_cap <= 0 else clampi(unit.def.shard_cap - unit.shards_paid, 0, amount)
			unit.shards_paid += paying
			if paying > 0:
				var paid: LogEntry = sim.new_entry(LogEntry.Kind.SHARDS, source)
				paid.target = unit.id
				paid.amount = paying
				sim.combat_log.add(paid)
			if paying < amount:
				var capped: LogEntry = sim.new_entry(LogEntry.Kind.SHARDS, source)
				capped.target = unit.id
				capped.amount = amount - paying
				capped.capped = true
				capped.note = "capped"
				sim.combat_log.add(capped)
		EffectDef.Type.EXTEND_STATUS:
			if effect.extend_statuses.is_empty():
				Statuses.extend(sim, victim, effect.status_id, effect.duration_ticks, source)
			else:
				for status_id: String in effect.extend_statuses:
					Statuses.extend(sim, victim, status_id, effect.duration_ticks, source)
		EffectDef.Type.APPLY_STATUS:
			var status_id: String = unit.status_swaps.get(effect.status_id, effect.status_id)
			if not effect.smaller_of.is_empty():
				# The smaller of its statuses on the unit, raised (phase 8 part
				# 6, Solvent): the first named on a tie.
				var fewest: int = -1
				var most: int = 0
				for named: String in effect.smaller_of:
					var stacks: int = Statuses.stacks_on(victim, named)
					most = maxi(most, stacks)
					if fewest < 0 or stacks < fewest:
						fewest = stacks
						status_id = named
				if effect.larger_share_bp > 0:
					amount = FixedMath.apply_bp(most, effect.larger_share_bp)
				if amount <= 0:
					return
			# fresh_only: never on a unit that has it already (Snaring Shot).
			if not effect.fresh_only or Statuses.find(victim, status_id) == null:
				Statuses.apply(sim, victim, status_id, amount, effect.duration_ticks, source, effect.marks_stack, effect.until_near, effect.strength_add_bp, power)
		EffectDef.Type.CLEANSE:
			if effect.cleanse_count > 0:
				Statuses.cleanse_newest(sim, victim, effect.cleanse_count, source, effect.cleanse_statuses)
			else:
				Statuses.cleanse_over_time(sim, victim, mini(amount, FixedMath.BP_ONE), source, false, effect.cleanse_statuses)
		EffectDef.Type.MANA_DRAIN:
			Mana.drain(sim, victim, amount, source)
		EffectDef.Type.GAIN_MANA:
			var gained: int = 0
			if effect.mana_bp > 0:
				# A share of its bar (phase 5c step 6b; Execution's refund).
				if victim.def.mana != null:
					gained = Mana.gain(sim, victim, FixedMath.apply_bp(victim.def.mana.max * Mana.SCALE, effect.mana_bp))
			else:
				# A share of the mana its unit gained is in hundredths (phase 8
				# part 4, Chorister); a stack of its grows_per_stack status
				# makes it more (Wellspring).
				var hundredths: int = amount if effect.amount_bp_of_damage > 0 else amount * Mana.SCALE
				if not effect.grows_status.is_empty():
					hundredths = FixedMath.apply_bp(hundredths, FixedMath.BP_ONE + effect.grows_stack_bp * Statuses.stacks_on(unit, effect.grows_status))
				gained = Mana.gain(sim, victim, hundredths)
			if victim != unit and gained > 0:
				# Mana given to another unit is logged (phase 8 part 4).
				var given: LogEntry = sim.new_entry(LogEntry.Kind.MANA_GIVEN, source)
				given.target = victim.id
				given.amount = gained
				sim.combat_log.add(given)
		EffectDef.Type.KNOCKBACK:
			var distance: int = FixedMath.apply_bp(effect.hexes * HexGrid.HEX, effect.distance_bp)
			if effect.toward == EffectDef.Toward.EDGE:
				# Toward the nearest edge (phase 8 part 3, the Cliffmite).
				Displacement.shove_to_edge(sim, victim, unit.pos if push_from == NO_POINT else push_from, unit.forward(), distance, source)
			else:
				Displacement.knockback(sim, victim, unit.pos if push_from == NO_POINT else push_from, unit.forward(), effect.hexes, source, distance)
		EffectDef.Type.PULL:
			if effect.hook:
				# All the way to beside the unit (phase 8 part 3, the Gulf Angler).
				Displacement.hook(sim, victim, unit, source)
				return
			match effect.toward:
				EffectDef.Toward.WATER:
					# Toward the nearest water (phase 8 part 3, Coiling Eel).
					if sim.has_water and not sim.water.hexes.is_empty():
						Displacement.pull_to(sim, victim, sim.water.nearest_center(sim.grid, victim.pos), effect.hexes, source)
				EffectDef.Toward.AREA:
					# Toward its area's middle (Undertow Tidecaller).
					if push_from != NO_POINT:
						Displacement.pull_to(sim, victim, push_from, effect.hexes, source)
				EffectDef.Toward.ALLY:
					# Toward the unit's nearest standing ally (phase 8 part 4,
					# Tamsin's Drag), else toward the unit.
					var ally: UnitState = EffectTargets.nearest_ally(sim, unit, victim)
					if ally == null:
						Displacement.pull(sim, victim, unit, effect.hexes, source)
					else:
						Displacement.pull(sim, victim, ally, effect.hexes, source)
				_:
					Displacement.pull(sim, victim, unit, effect.hexes, source)
		EffectDef.Type.LEAP:
			if effect.leap_home:
				Displacement.leap_home(sim, unit, effect, source)
			elif effect.leap_step:
				Displacement.step(sim, unit, victim, effect, source)
			else:
				Displacement.leap(sim, unit, victim, effect, source)
		EffectDef.Type.HOP:
			Displacement.hop(sim, victim, source)
		EffectDef.Type.CHARGE:
			Displacement.charge(sim, unit, victim, effect, source)
		EffectDef.Type.START_COLLAPSE:
			Collapse.start_now(sim, source)
		EffectDef.Type.SEVER:
			Islands.sever(sim, source, effect)
		EffectDef.Type.SUMMON:
			Summons.summon(sim, unit, source, effect, unit.target)


static func _on_hit(sim: CombatSim, unit: UnitState, ability: AbilityDef, source: EffectSource, hit: Hit) -> void:
	for effect: EffectDef in ability.effects:
		var wanted: bool = effect.trigger == EffectDef.Trigger.ON_HIT or (effect.trigger == EffectDef.Trigger.ON_CRIT and hit.crit)
		if not wanted or not effect.active_at(sim.tick):
			continue
		for victim: UnitState in EffectTargets.reached(sim, unit, effect.target, null, hit, effect):
			var amount: int = amount_of(effect, unit, hit.damage, sim)
			var crit: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability, victim))
			land(sim, unit, ability, source, effect, victim, amount, crit, NO_POINT, power_of(effect, unit))


## An ability passive's effect, set off by an event (Passives.on_event):
## `other` is the unit the event names, `damage` the hit it's about. It
## lands at once, and never sets off on_hit effects. `aim` stands for the
## unit's target (a companion doing its hero's passive aims at hers).
static func run_event(sim: CombatSim, unit: UnitState, ability: AbilityDef, source: EffectSource, effect: EffectDef, other: UnitState, damage: int, aim: UnitState = null) -> void:
	if ability.by_companion and unit.owner == null:
		# Its companion does it (phase 8 part 6, Sic 'Em's habit).
		var pet: UnitState = sim.companion_of(unit)
		if pet == null:
			return
		run_event(sim, pet, ability, EffectSource.make(pet.id, ability.id, ability.name), effect, other, damage, unit.target)
		return
	if effect.type == EffectDef.Type.AREA:
		if effect.at_groups > 0:
			for middle: UnitState in Targeting.largest_groups(sim, unit, effect.at_groups):
				Areas.cast(sim, unit, ability, source, effect, middle)
			return
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
	if effect.type == EffectDef.Type.RAISE:
		# The fallen enemy the event names stands up on the unit's side
		# (phase 8 part 5, Gravecaller).
		Summons.raise(sim, unit, source, effect, other)
		return
	if effect.type == EffectDef.Type.SUMMON and not unit.alive:
		# From where it fell (phase 8 part 3, the Glass Shambler's Shatter):
		# a summon aims at no unit, so a fallen one still makes it.
		Summons.summon(sim, unit, source, effect, unit.target)
		return
	var hit: Hit = null
	if other != null:
		hit = Hit.new()
		hit.target = other
		hit.damage = damage
	var amount: int = amount_of(effect, unit, damage, sim)
	if not effect.stacks_of.is_empty():
		# As many stacks as the unit the event names has (Pyre Ash).
		amount = stacks_from(effect, other, unit)
		if amount <= 0:
			return
	if effect.target == EffectDef.Target.ENEMIES_NEAR_ALLIES:
		for pair: Array in EffectTargets.around_allies(sim, unit, effect):
			var crit_round: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability, pair[0]))
			land(sim, unit, ability, source, effect, pair[0], amount, crit_round, (pair[1] as UnitState).pos, power_of(effect, unit))
		return
	for victim: UnitState in EffectTargets.reached(sim, unit, effect.target, aim if aim != null else unit.target, hit, effect):
		# A plain hit never crits (the tuning phase: Thorned Bandage, Splinter
		# Shot), and rolls nothing.
		var crit: bool = effect.type == EffectDef.Type.DAMAGE and not effect.plain and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability, victim))
		land(sim, unit, ability, source, effect, victim, per_stack(effect, victim, amount), crit, NO_POINT, power_of(effect, unit))


## stacks_of's number: the stacks `named` has of the effect's status (a
## share of them, at least 1, with stacks_share_bp: Ashen Engine), or 0.
static func stacks_from(effect: EffectDef, named: UnitState, unit: UnitState = null) -> int:
	var state: StatusState = Statuses.find(named, effect.stacks_of) if named != null else null
	var stacks: int = state.total_stacks() if state != null and not state.def.is_timed() else 0
	var share_bp: int = effect.stacks_share_bp
	if share_bp > 0 and unit != null and not effect.grows_status.is_empty():
		# Its share grows with a status on its unit (phase 8 part 6, Crucible).
		share_bp += effect.grows_stack_bp * Statuses.stacks_on(unit, effect.grows_status)
	if stacks > 0 and share_bp > 0:
		stacks = maxi(FixedMath.apply_bp(stacks, share_bp), 1)
	return stacks


## A damage effect's amount_per_stack (phase 8 part 6, Immolate): `amount`
## plus that much for each stack of its status (or statuses: Reaction Flask)
## on `victim`.
static func per_stack(effect: EffectDef, victim: UnitState, amount: int) -> int:
	if effect.amount_per_stack <= 0 or victim == null:
		return amount
	var stacks: int = Statuses.stacks_on(victim, effect.per_stack_status)
	for status_id: String in effect.per_stack_more:
		stacks += Statuses.stacks_on(victim, status_id)
	return amount + effect.amount_per_stack * stacks


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
	elif effect.amount_bp_of_shield > 0:
		# Its unit's own Shield (phase 8 part 4, Bulwark Burst).
		amount = FixedMath.apply_bp(unit.shield, effect.amount_bp_of_shield)
	elif effect.amount_bp_of_stored > 0:
		# The damage its unit stored (phase 8 part 4, Vengeance).
		amount = FixedMath.apply_bp(unit.stored, effect.amount_bp_of_stored)
	elif effect.amount_bp_of_engorged > 0:
		# The max HP Engorge added to it (phase 8 part 5, Sanguine Nova).
		amount = FixedMath.apply_bp(unit.engorged, effect.amount_bp_of_engorged)
	else:
		amount = effect.base_value()
		# A companion's may read its owner's stats (phase 8 part 6).
		var by: UnitState = unit.owner if effect.scaling_of_owner and unit.owner != null else unit
		for stat: int in effect.scaling.size():
			if effect.scaling[stat] != 0:
				amount += FixedMath.apply_bp(by.stats.values[stat], effect.scaling[stat])
	# Its unit's own max HP, and the HP its fire just spent (phase 8 part 5).
	if effect.plus_bp_of_max_hp > 0:
		amount += FixedMath.apply_bp(unit.max_hp, effect.plus_bp_of_max_hp)
	if effect.plus_bp_of_spent > 0:
		amount += FixedMath.apply_bp(unit.last_hp_spent, effect.plus_bp_of_spent)
	if effect.plus_per_shard_bp > 0 and effect.type == EffectDef.Type.DAMAGE and sim != null:
		# Heavy Purse (phase 8 part 6): more for the shards its unit holds.
		amount += FixedMath.apply_bp(sim.shards_held(unit), effect.plus_per_shard_bp)
	if effect.bonus_bp_per_ally > 0 and sim != null:
		amount = FixedMath.apply_bp(amount, FixedMath.BP_ONE + effect.bonus_bp_per_ally * allies_near(sim, unit, effect))
	return Passives.boosted(unit, effect, amount)


## How many standing units of `unit`'s side (itself among them; of `kits`,
## if any are named) have `victim` as their target (phase 8 part 3,
## when_attackers).
static func attackers_on(sim: CombatSim, unit: UnitState, victim: UnitState, kits: Array[String] = []) -> int:
	var count: int = 0
	for ally: UnitState in (sim.heroes if unit.side == EffectSource.Team.HEROES else sim.enemies):
		if ally.alive and ally.target == victim and (kits.is_empty() or kits.has(ally.def.id)):
			count += 1
	return count


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


## The units a near-target effect (or lowest_hp_ally) reaches, around `center`
## (phase 4; EffectDef has the rules; EffectTargets).
static func near(sim: CombatSim, unit: UnitState, effect: EffectDef, center: UnitState) -> Array[UnitState]:
	return EffectTargets.near(sim, unit, effect, center)


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
			victims = EffectTargets.nearest_to(foes, own, effect.count)
	for victim: UnitState in victims:
		match effect.type:
			EffectDef.Type.APPLY_STATUS:
				var duration: int = effect.duration_ticks if effect.duration_ticks > 0 else sim.content.statuses[effect.status_id].duration_ticks
				Statuses.apply(sim, victim, effect.status_id, FixedMath.apply_bp(effect.stacks, scale_bp), FixedMath.apply_bp(duration, scale_bp), source)
			EffectDef.Type.SHIELD:
				var amount: int = FixedMath.apply_bp(victim.max_hp, effect.amount_bp_of_max_hp) if effect.amount_bp_of_max_hp > 0 else effect.amount
				EffectHits.give_shield(sim, victim, FixedMath.apply_bp(amount, scale_bp), source)
			EffectDef.Type.HEAL:
				EffectHits.heal(sim, victim, FixedMath.apply_bp(effect.amount, scale_bp), source)
			EffectDef.Type.DAMAGE:
				EffectHits.deal_hit(sim, source, victim, FixedMath.apply_bp(effect.amount, scale_bp), false)


## The `count` standing allies of `unit` (itself too) the most enemies are
## targeting, most first, ties to the lowest share of HP, then the fight's
## order (phase 8 part 6, Shroud): with none targeted, the lowest on HP
## (EffectTargets).
static func most_targeted(sim: CombatSim, unit: UnitState, count: int) -> Array[UnitState]:
	return EffectTargets.most_targeted(sim, unit, count)


## deal_hit (EffectHits).
static func deal_hit(sim: CombatSim, source: EffectSource, target: UnitState, amount: int, crit: bool, power: int = 0, steals: bool = true, note: String = "", ruled: bool = false, pierces: bool = false, steal_bp: int = 0) -> int:
	return EffectHits.deal_hit(sim, source, target, amount, crit, power, steals, note, ruled, pierces, steal_bp)


## `attacker` lifesteals `wanted` HP: a LIFESTEAL line (or a heal, with
## lifesteal_heals), what's past full HP to Engorge, and the overheal strike
## (EffectHits).
static func steal(sim: CombatSim, attacker: UnitState, wanted: int, source: EffectSource) -> void:
	EffectHits.steal(sim, attacker, wanted, source)


## Heals `target` (capped at its max HP), logs it, and if any HP came back,
## weakens its damage over time (EffectHits).
static func heal(sim: CombatSim, target: UnitState, amount: int, source: EffectSource, overheal_shield_bp: int = 0, power: int = 0, by_lifesteal: bool = false, relic_bp: int = 0,
		ceiling: int = -1) -> int:
	return EffectHits.heal(sim, target, amount, source, overheal_shield_bp, power, by_lifesteal, relic_bp, ceiling)


## `unit` gains `amount` max HP and HP for the fight (phase 8 part 5, The Iron
## Maw), logged as MAX_HP_UP (EffectHits).
static func gain_max_hp(sim: CombatSim, unit: UnitState, amount: int, source: EffectSource) -> void:
	EffectHits.gain_max_hp(sim, unit, amount, source)


## give_shield (EffectHits).
static func give_shield(sim: CombatSim, target: UnitState, amount: int, source: EffectSource) -> LogEntry:
	return EffectHits.give_shield(sim, target, amount, source)
