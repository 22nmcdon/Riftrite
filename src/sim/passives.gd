class_name Passives
extends RefCounted
## Passives (PartDef) in a fight (docs/plans/rebuild-phase1-arena-sim.md,
## section 2):
##   aura            while its holder stands and its window is open, it
##                   boosts the holder or all its allies. Auras are folded
##                   into each unit's stats and output multipliers when the
##                   fight starts, when a window opens or closes, and when a
##                   holder falls (rederive). Each start and end is logged
##                   (AURA). Several on one stat multiply, in the fight's
##                   order, then each passive's.
##   ability         its effects run on the unit's events (Events). Each
##                   effect counts its own events and runs on every Nth
##                   ("once": only the first time), and only for statuses of
##                   its keywords and units that meet its "vs". What they do
##                   is marked from_event and one link deeper in a chain
##                   (LogEntry.chain; phase 5c step 3), so it can set off
##                   more events, down to the chain limit. Three triggers
##                   aren't events
##                   (docs/plans/rebuild-phase2-heroes-enemies.md, section 4):
##                   on_interval and on_ally_below_hp are checked after the
##                   events each tick (run_timed), and on_fall as the unit
##                   falls (on_fall).
##   replace_status  statuses the unit applies as `from` land as `to`.
## An aura with "while": "taunting" is on only while one of its holder's
## Taunts is in effect on a standing enemy; auras are folded in again when
## a Taunt starts or ends, or a taunted unit falls (CombatSim.taunt_auras).
## Phase 4's conditions (planted, below_hp, per fallen ally) are checked
## every tick for the units that have them, and auras are folded in again
## when one changes (condition_key, CombatSim.check_conditional_auras).
## A range aura adds hexes to its holder's reach; healing_taken_bp scales
## the heals the unit gets (EffectRunner.heal).


## One event effect of one of a unit's ability passives, with its count.
class Listener:
	var part: PartDef
	var effect: EffectDef
	var source: EffectSource
	var count: int = 0
	## on_ally_below_hp: the allies it has run for.
	var allies_done: Array[String] = []
	## on_below_hp: its unit is below the threshold now (it runs again only
	## after climbing back above).
	var below: bool = false
	## cooldown_per_unit_ms: the tick it last ran for each unit named (a
	## lookup, never iterated).
	var last_for: Dictionary[String, int] = {}
	## cooldown_ms: the tick it last ran (-1: never).
	var ran_at: int = -1


## An event effect waiting out its delay (EffectDef.delay_ticks).
class Delayed:
	var unit: UnitState
	var listener: Listener
	var other: UnitState
	var damage: int
	var chain: int
	var at: int


## AuraDef stats with no aura: x1 multipliers, +0 additions.
static func no_auras() -> Array[int]:
	var values: Array[int] = []
	for stat: int in AuraDef.Stat.size():
		values.append(0 if _is_additive(stat) else FixedMath.BP_ONE)
	return values


## Readies the unit's listeners and status swaps.
static func set_up(unit: UnitState) -> void:
	for part: PartDef in unit.def.passives:
		match part.kind:
			PartDef.Kind.ABILITY:
				for effect: EffectDef in part.ability.effects:
					var listener := Listener.new()
					listener.part = part
					listener.effect = effect
					listener.source = EffectSource.make(unit.id, part.id, part.name)
					unit.listeners.append(listener)
			PartDef.Kind.REPLACE_STATUS:
				unit.status_swaps[part.from_status] = part.to_status


# --- auras ---------------------------------------------------------------------

## Ticks where some aura window opens or closes (a lookup, never iterated).
static func aura_boundaries(sim: CombatSim) -> Dictionary[int, bool]:
	var ticks: Dictionary[int, bool] = {}
	for unit: UnitState in sim.units:
		for part: PartDef in unit.def.passives:
			if part.kind == PartDef.Kind.AURA:
				if part.aura.window_from_ticks > 0:
					ticks[part.aura.window_from_ticks] = true
				if part.aura.window_until_ticks > 0:
					ticks[part.aura.window_until_ticks] = true
	return ticks


static func has_aura(unit: UnitState) -> bool:
	for part: PartDef in unit.def.passives:
		if part.kind == PartDef.Kind.AURA:
			return true
	return false


## Folds every active aura into every unit again, and logs the auras that
## started or ended since the last time. `was_active` holds "unit:part" keys
## of the auras active before; returns the ones active now.
static func rederive(sim: CombatSim, was_active: Array[String]) -> Array[String]:
	for unit: UnitState in sim.units:
		unit.aura_bp = no_auras()
		unit.vs_conditions.clear()
		unit.vs_stats.clear()
		unit.vs_bonus_bp.clear()
		unit.vs_basic.clear()
		unit.vs_signature.clear()
		unit.vs_per_stacks.clear()
		unit.vs_within.clear()
	var now_active: Array[String] = []
	for holder: UnitState in sim.units:
		if not holder.alive:
			continue
		for part: PartDef in holder.def.passives:
			if part.kind != PartDef.Kind.AURA or not part.aura.active_at(sim.tick):
				continue
			if part.aura.while_taunting and not taunting(sim, holder):
				continue
			if part.aura.is_conditional() and not condition_holds(sim, holder, part.aura):
				continue
			now_active.append("%s:%s" % [holder.id, part.id])
			# A factor's change adds to the others' of its stat (the damage
			# rule, phase 5c): x1.1 and x1.1 make x1.2.
			var change: int = aura_change(sim, holder, part.aura)
			var targets: Array[UnitState] = [holder]
			if part.aura.target == AuraDef.Target.ALL_ALLIES:
				targets = sim.standing_allies_of(holder)
			elif part.aura.target == AuraDef.Target.ALLIES_NEAR:
				# The other allies near it now (phase 5c step 7c, Sanctuary).
				var reach_sq: int = part.aura.target_range * part.aura.target_range
				targets = sim.standing_allies_of(holder).filter(func(ally: UnitState) -> bool:
					return ally != holder and ArenaPlane.length_sq(ally.pos - holder.pos) <= reach_sq)
			for target: UnitState in targets:
				if part.aura.is_per_hit():
					# Only on some hits (phase 5c steps 3, 5b, 5c: against
					# targets that meet it, its basic attack's, per stack on the
					# unit hit); worked out per hit (EffectRunner).
					target.vs_conditions.append(part.aura.vs)
					target.vs_stats.append(part.aura.stat)
					target.vs_bonus_bp.append(change)
					target.vs_basic.append(part.aura.from_basic)
					target.vs_signature.append(part.aura.from_signature)
					target.vs_per_stacks.append(part.aura.per_target_stacks)
					target.vs_within.append(part.aura.hit_range)
					continue
				target.aura_bp[part.aura.stat] += change
	# Timed boosts (phase 5c step 5b) count like the unit's own auras, once
	# per stack (step 5c).
	for unit: UnitState in sim.units:
		for state: StatusState in unit.statuses:
			if state.def.kind == StatusDef.Kind.BOOST:
				var stacks: int = state.timed_stacks()
				for i: int in state.def.boost_stats.size():
					var stat: int = state.def.boost_stats[i]
					var change: int = stacks * (state.def.boost_values[i] if _is_additive(stat) else state.def.boost_values[i] - FixedMath.BP_ONE)
					if state.boost_strength_bp != 0:
						change = FixedMath.apply_bp(change, FixedMath.BP_ONE + state.boost_strength_bp)
					unit.aura_bp[stat] += change
	for unit: UnitState in sim.units:
		unit.stats = unit.base_stats.copy()
		for aura_stat: int in AuraDef.Stat.size():
			if not AuraDef.UNIT_STAT_FOR.has(aura_stat):
				continue
			var stat: int = AuraDef.UNIT_STAT_FOR[aura_stat]
			unit.stats.values[stat] = FixedMath.apply_bp(unit.base_stats.values[stat], factor(unit, aura_stat))
		unit.stats.values[UnitStats.Stat.RANGE] = unit.base_stats.values[UnitStats.Stat.RANGE] + unit.aura_bp[AuraDef.Stat.RANGE]
		unit.stats.values[UnitStats.Stat.ATSP] += unit.aura_bp[AuraDef.Stat.ATSP]
		unit.stats.values[UnitStats.Stat.DEF] += unit.aura_bp[AuraDef.Stat.DEF]
		if unit.aura_bp[AuraDef.Stat.MAX_HP_BP] != FixedMath.BP_ONE or unit.max_hp != unit.base_max_hp:
			# Max HP boosts (phase 5c step 5c): HP rises by what it gains.
			var new_max: int = maxi(FixedMath.apply_bp(unit.base_max_hp, factor(unit, AuraDef.Stat.MAX_HP_BP)), 1)
			if unit.alive:
				unit.hp = mini(unit.hp + maxi(new_max - unit.max_hp, 0), new_max)
			unit.max_hp = new_max
		unit.attack.set_cooldown_add(unit.aura_bp[AuraDef.Stat.COOLDOWN_BP])
		unit.attack_rate_bp = sim.attack_rate_bp(unit)
		unit.refresh_reach()
	_log_changes(sim, was_active, now_active)
	return now_active


## Logs, in the fight's order, each aura that ended and each that started.
static func _log_changes(sim: CombatSim, was_active: Array[String], now_active: Array[String]) -> void:
	for holder: UnitState in sim.units:
		for part: PartDef in holder.def.passives:
			if part.kind != PartDef.Kind.AURA:
				continue
			var key: String = "%s:%s" % [holder.id, part.id]
			var was: bool = was_active.has(key)
			if was == now_active.has(key):
				continue
			var entry: LogEntry = sim.new_entry(LogEntry.Kind.AURA, EffectSource.make(holder.id, part.id, part.name))
			entry.note = ("starts: %s" % part.aura.describe()) if not was else "ends"
			sim.combat_log.add(entry)


## An active aura's change (bp, or points for an additive stat) on
## `holder`: its value's change, once per fallen ally, grown by its planted
## steps (phase 5c step 5c), or worked out from the holder's Shield.
static func aura_change(sim: CombatSim, holder: UnitState, aura: AuraDef) -> int:
	if aura.per_shield_bp > 0:
		return holder.shield * aura.per_shield_bp
	var change: int = aura.value if _is_additive(aura.stat) else aura.value - FixedMath.BP_ONE
	if aura.per_fallen_ally:
		change *= fallen_allies(sim, holder)
	if aura.step_ticks > 0:
		@warning_ignore("integer_division")
		change += aura.step_value * ((sim.tick - holder.moved_at - aura.after_ticks) / aura.step_ticks)
	return change


## True if one of `holder`'s Taunts is in effect on a standing enemy.
static func taunting(sim: CombatSim, holder: UnitState) -> bool:
	for enemy: UnitState in sim.standing_enemies_of(holder):
		for state: StatusState in enemy.statuses:
			if state.def.kind == StatusDef.Kind.TAUNT and state.source != null and state.source.unit_id == holder.id:
				return true
	return false


## Whether a conditional aura's condition (planted, below_hp, an ally of a
## kit standing, a fallen ally) holds for its holder now.
static func condition_holds(sim: CombatSim, holder: UnitState, aura: AuraDef) -> bool:
	match aura.while_kind:
		AuraDef.While.PLANTED:
			if sim.tick - holder.moved_at < aura.after_ticks:
				return false
		AuraDef.While.BELOW_HP:
			if holder.hp * FixedMath.BP_ONE >= aura.below_bp * holder.max_hp:
				return false
		AuraDef.While.STATE:
			if not aura.state.holds(holder, holder):
				return false
		AuraDef.While.ALLY_NEAR:
			var reach_sq: int = aura.near_range * aura.near_range
			if not (sim.heroes if holder.side == EffectSource.Team.HEROES else sim.enemies).any(func(ally: UnitState) -> bool:
					return ally != holder and ally.alive and ArenaPlane.length_sq(ally.pos - holder.pos) <= reach_sq):
				return false
		AuraDef.While.BEHIND_WALL:
			if sim.walls.is_empty() or not Walls.behind(sim, holder, aura.near_range):
				return false
		AuraDef.While.TACTIC:
			if holder.tactic == null or not Tactics.applies(sim, holder):
				return false
		AuraDef.While.MOVED:
			# Moved within that long (phase 5c step 7c, Restless).
			if holder.moved_at == UnitState.NEVER_MOVED or sim.tick - holder.moved_at > aura.moved_ticks:
				return false
		AuraDef.While.CROWDED:
			# That many enemies that close (phase 5c step 7c, Crowd Sense).
			var crowd_sq: int = aura.near_range * aura.near_range
			if sim.standing_enemies_of(holder).filter(func(enemy: UnitState) -> bool:
					return ArenaPlane.length_sq(enemy.pos - holder.pos) <= crowd_sq).size() < aura.crowd:
				return false
		AuraDef.While.ALLY_STANDING:
			if not (sim.heroes if holder.side == EffectSource.Team.HEROES else sim.enemies).any(
					func(unit: UnitState) -> bool: return unit != holder and unit.alive and unit.def.id == aura.ally_kit):
				return false
	if aura.per_shield_bp > 0 and holder.shield <= 0:
		return false
	return not aura.per_fallen_ally or fallen_allies(sim, holder) > 0


## How many of `holder`'s side have fallen (summons included; one still to
## arrive hasn't).
static func fallen_allies(sim: CombatSim, holder: UnitState) -> int:
	var count: int = 0
	for unit: UnitState in (sim.heroes if holder.side == EffectSource.Team.HEROES else sim.enemies):
		if not unit.alive and not unit.arriving:
			count += 1
	return count


## True if the unit has a conditional aura (checked every tick).
static func has_conditional_aura(unit: UnitState) -> bool:
	for part: PartDef in unit.def.passives:
		if part.kind == PartDef.Kind.AURA and part.aura.is_conditional():
			return true
	return false


## A number that changes whenever one of the unit's conditional auras turns
## on or off, or changes how much it gives (per fallen ally, a planted
## step, per Shield).
static func condition_key(sim: CombatSim, unit: UnitState) -> int:
	var key: int = 0
	for part: PartDef in unit.def.passives:
		if part.kind != PartDef.Kind.AURA or not part.aura.is_conditional():
			continue
		key = key * 1000003
		if unit.alive and condition_holds(sim, unit, part.aura):
			key += 1 + aura_change(sim, unit, part.aura)
			if part.aura.target == AuraDef.Target.ALLIES_NEAR:
				# Who's near changes it too (phase 5c step 7c, Sanctuary).
				var reach_sq: int = part.aura.target_range * part.aura.target_range
				for ally: UnitState in sim.standing_allies_of(unit):
					key = key * 31 + int(ally != unit and ArenaPlane.length_sq(ally.pos - unit.pos) <= reach_sq)
	return key


## True if the unit has an aura of `stat` (any target).
static func has_aura_of(unit: UnitState, stat: AuraDef.Stat) -> bool:
	for part: PartDef in unit.def.passives:
		if part.kind == PartDef.Kind.AURA and part.aura.stat == stat:
			return true
	return false


## True if the unit has an aura worked out per hit ("vs", "from_basic",
## "per_target_stacks").
static func has_vs_aura(unit: UnitState) -> bool:
	for part: PartDef in unit.def.passives:
		if part.kind == PartDef.Kind.AURA and part.aura.is_per_hit():
			return true
	return false


## What `attacker`'s per-hit auras of `stat` give on a hit on `target` by
## `ability_id` (bp): a damage_bp aura's power, a crit_chance_bp,
## lifesteal_bp, or crit_damage_bp aura's amount. Each counts if the target
## meets its "vs", the hit is its basic attack's ("from_basic"), and times
## the target's stacks of its "per_target_stacks".
static func vs_bonus_bp(attacker: UnitState, target: UnitState, stat: int = AuraDef.Stat.DAMAGE_BP, ability_id: String = "") -> int:
	var bonus: int = 0
	for i: int in attacker.vs_conditions.size():
		if attacker.vs_stats[i] != stat:
			continue
		if attacker.vs_conditions[i] != null and not attacker.vs_conditions[i].holds(target, attacker):
			continue
		if attacker.vs_basic[i] and ability_id != attacker.def.basic_attack.id:
			continue
		if attacker.vs_signature[i] and (attacker.def.signature == null or ability_id != attacker.def.signature.id):
			continue
		if attacker.vs_within[i] > 0 and ArenaPlane.length_sq(target.pos - attacker.pos) > attacker.vs_within[i] * attacker.vs_within[i]:
			continue
		var times: int = 1 if attacker.vs_per_stacks[i].is_empty() else Statuses.stacks_on(target, attacker.vs_per_stacks[i])
		bonus += times * attacker.vs_bonus_bp[i]
	return bonus


## True if the unit has an aura that holds only while it's taunting.
static func has_taunting_aura(unit: UnitState) -> bool:
	for part: PartDef in unit.def.passives:
		if part.kind == PartDef.Kind.AURA and part.aura.while_taunting:
			return true
	return false


## True if one of the unit's passive effects runs on `trigger`.
static func listens_for(unit: UnitState, trigger: EffectDef.Trigger) -> bool:
	for listener: Listener in unit.listeners:
		if listener.effect.trigger == trigger:
			return true
	return false


## True if the unit has passive effects on on_interval or on_ally_below_hp.
static func has_timed(unit: UnitState) -> bool:
	for listener: Listener in unit.listeners:
		if listener.effect.trigger == EffectDef.Trigger.ON_INTERVAL or listener.effect.trigger == EffectDef.Trigger.ON_ALLY_BELOW_HP \
				or listener.effect.trigger == EffectDef.Trigger.ON_BELOW_HP:
			return true
	return false


static func _is_additive(stat: int) -> bool:
	return AuraDef.ADDITIVE.has(stat)


## A factor stat's multiplier on the unit (its auras' changes added, floored
## by the damage rule).
static func factor(unit: UnitState, stat: int) -> int:
	return DamageRule.factor(unit.aura_bp[stat] - FixedMath.BP_ONE)


## The unit's power bonus (bp) for an effect: its output aura for the
## effect's type (damage, heal, shield) plus the effect's own power_bp (a kit
## mod's). The damage rule adds it to the hit's other power bonuses.
static func power_bp(unit: UnitState, effect: EffectDef) -> int:
	if effect.type == EffectDef.Type.APPLY_STATUS:
		# A boost from a signature that grows with each cast (phase 8 part 2):
		# its growth so far (0 otherwise; a status has no other power).
		return unit.grow_power_bp
	var power: int = effect.power_bp
	if unit.fire_power_bp != 0 and (effect.type == EffectDef.Type.DAMAGE or effect.type == EffectDef.Type.HEAL or effect.type == EffectDef.Type.SHIELD):
		# Overcharge's extra fires (phase 5c step 5c).
		power += unit.fire_power_bp
	if effect.power_per_taken_bp > 0:
		# Growing with the damage its unit has taken (phase 8 part 2).
		@warning_ignore("integer_division")
		power += effect.power_per_taken_bp * (unit.taken_total / effect.taken_per)
	match effect.type:
		EffectDef.Type.DAMAGE:
			power += unit.aura_bp[AuraDef.Stat.DAMAGE_BP] - FixedMath.BP_ONE
		EffectDef.Type.HEAL:
			power += unit.aura_bp[AuraDef.Stat.HEAL_BP] - FixedMath.BP_ONE
		EffectDef.Type.SHIELD:
			power += unit.aura_bp[AuraDef.Stat.SHIELD_BP] - FixedMath.BP_ONE
	return power


## A status's stacks after the unit's damage-over-time auras (the only
## number still boosted as it's worked out; damage, heals, and Shields carry
## their power to where they land).
static func boosted(unit: UnitState, effect: EffectDef, amount: int) -> int:
	if effect.type != EffectDef.Type.APPLY_STATUS or unit.aura_bp[AuraDef.Stat.OVER_TIME_BP] == FixedMath.BP_ONE:
		return amount
	return FixedMath.apply_bp(amount, factor(unit, AuraDef.Stat.OVER_TIME_BP))


# --- events ------------------------------------------------------------------------

## Runs the unit's event effects for `event`. `other` is the unit the event
## names (hit_target), `damage` the hit it's about (amount_bp_of_damage),
## `status` the status applied (on_status), `chain` the depth of the entry
## that raised it.
static func on_event(sim: CombatSim, unit: UnitState, event: EffectDef.Trigger, other: UnitState, damage: int, status: String, chain: int = 0) -> void:
	for listener: Listener in unit.listeners:
		var effect: EffectDef = listener.effect
		if effect.trigger != event or not effect.active_at(sim.tick):
			continue
		if event == EffectDef.Trigger.ON_STATUS or event == EffectDef.Trigger.ON_STATUS_ENDED:
			if not effect.statuses.is_empty() and not effect.statuses.has(status):
				continue
			if not effect.keywords.is_empty() and not effect.keywords.has(sim.content.statuses[status].keyword):
				continue
			if effect.at_stacks > 0:
				# Spent at so many stacks (phase 8 part 2, Forgebreaker): the
				# stacks come off before its effects run.
				var state: StatusState = Statuses.find(other, status) if other != null else null
				if state == null or Statuses.stacks_on(other, status) < effect.at_stacks:
					continue
				Statuses.end_now(sim, other, state, "spent by %s" % unit.id)
		if effect.vs != null and (other == null or not effect.vs.holds(other, unit)):
			continue
		# Phase 5c step 6b: a hit big enough, an enemy that fell near enough,
		# a kill by the signature (`status` names the ability), and a cooldown.
		if effect.min_hit_bp > 0 and damage * FixedMath.BP_ONE < unit.max_hp * effect.min_hit_bp:
			continue
		if effect.fell_range > 0 and (other == null or ArenaPlane.length_sq(other.pos - unit.pos) > effect.fell_range * effect.fell_range):
			continue
		if effect.from_signature and (unit.def.signature == null or status != unit.def.signature.id):
			continue
		# Phase 5c step 7c: the holder's own state, how far the unit hit
		# stands, a kill off its target, and a heal's ability and the HP it
		# healed from (on_heal carries the ability as `status`, the HP healed
		# as `damage`).
		if effect.holder != null and not effect.holder.holds(unit, unit):
			continue
		if effect.beyond_range > 0 and (other == null or ArenaPlane.length_sq(other.pos - unit.pos) <= effect.beyond_range * effect.beyond_range):
			continue
		if effect.off_target and (other == null or other == unit.target or status != unit.def.basic_attack.id):
			continue
		if not effect.from_abilities.is_empty() and not effect.from_abilities.has(status):
			continue
		if effect.executed and (other == null or not other.executed):
			continue
		if effect.was_below_bp > 0 and (other == null or (other.hp - damage) * FixedMath.BP_ONE >= effect.was_below_bp * other.max_hp):
			continue
		if effect.cooldown_ticks > 0 and listener.ran_at >= 0 and sim.tick - listener.ran_at < effect.cooldown_ticks:
			continue
		if effect.once and listener.count >= effect.every * effect.times:
			continue
		if effect.cooldown_per_unit_ticks > 0 and other != null:
			if listener.last_for.has(other.id) and sim.tick - listener.last_for[other.id] < effect.cooldown_per_unit_ticks:
				continue
		listener.count += 1
		if listener.count % effect.every != 0:
			continue
		if effect.cooldown_per_unit_ticks > 0 and other != null:
			listener.last_for[other.id] = sim.tick
		listener.ran_at = sim.tick
		if effect.delay_ticks > 0:
			# It runs later (phase 8 part 3, the Gloam Hound): run_delayed.
			var waiting := Delayed.new()
			waiting.unit = unit
			waiting.listener = listener
			waiting.other = other
			waiting.damage = damage
			waiting.chain = chain
			waiting.at = sim.tick + effect.delay_ticks
			sim.delayed.append(waiting)
			continue
		_run(sim, unit, listener, other, damage, chain)


## The event effects whose delay is up run, in the order they were set off,
## if their unit still stands (phase 8 part 3).
static func run_delayed(sim: CombatSim) -> void:
	var due: Array = sim.delayed.filter(func(waiting: Delayed) -> bool: return sim.tick >= waiting.at)
	if due.is_empty():
		return
	sim.delayed = sim.delayed.filter(func(waiting: Delayed) -> bool: return sim.tick < waiting.at)
	for waiting: Delayed in due:
		if waiting.unit.alive:
			_run(sim, waiting.unit, waiting.listener, waiting.other if waiting.other != null and waiting.other.alive else null, waiting.damage, waiting.chain)


## Runs the on_interval passives that are due, the on_ally_below_hp ones
## an ally has just set off, and the on_below_hp ones the unit has (phase 5c
## step 6), for every standing unit in the fight's order
## (the allies, too, in the fight's order).
static func run_timed(sim: CombatSim) -> void:
	for unit: UnitState in sim.units:
		if not unit.alive or unit.listeners.is_empty():
			continue
		for listener: Listener in unit.listeners:
			var effect: EffectDef = listener.effect
			if not effect.active_at(sim.tick):
				continue
			if effect.holder != null and not effect.holder.holds(unit, unit):
				continue
			match effect.trigger:
				EffectDef.Trigger.ON_INTERVAL:
					var since: int = sim.tick - unit.joined_at
					if since > 0 and since % effect.interval_ticks == 0 and not (effect.once and listener.count >= effect.times):
						listener.count += 1
						_run(sim, unit, listener, null, 0)
				EffectDef.Trigger.ON_ALLY_BELOW_HP:
					for ally: UnitState in sim.standing_allies_of(unit):
						if effect.once and listener.allies_done.size() >= effect.times:
							break
						if ally == unit or ally.hp <= 0 or listener.allies_done.has(ally.id):
							continue
						if ally.hp * FixedMath.BP_ONE < ally.max_hp * effect.threshold_bp:
							listener.allies_done.append(ally.id)
							_run(sim, unit, listener, ally, 0)
				EffectDef.Trigger.ON_BELOW_HP:
					var below: bool = unit.hp * FixedMath.BP_ONE < unit.max_hp * effect.threshold_bp
					if below and not listener.below and listener.count < effect.times:
						listener.count += 1
						_run(sim, unit, listener, null, 0)
					listener.below = below


## The unit would fall (the deaths step, after Undying and a would_fall
## signature): its first unspent on_would_fall passive (phase 4) leaves it at
## 1 HP (SAVED, sourced to the passive) and runs. Returns true if one did.
static func would_fall(sim: CombatSim, unit: UnitState) -> bool:
	for listener: Listener in unit.listeners:
		if listener.effect.trigger != EffectDef.Trigger.ON_WOULD_FALL or listener.count > 0 or not listener.effect.active_at(sim.tick):
			continue
		listener.count = 1
		unit.hp = 1
		var saved: LogEntry = sim.new_entry(LogEntry.Kind.SAVED, listener.source)
		saved.target = unit.id
		saved.note = "would fall"
		sim.combat_log.add(saved)
		_run(sim, unit, listener, null, 0)
		return true
	return false


## The fight starts: the unit's on_fight_start passives run (phase 5c step
## 6d: a gambit's Stealth, Shield, or boost at the start).
static func fight_start(sim: CombatSim, unit: UnitState) -> void:
	for listener: Listener in unit.listeners:
		if listener.effect.trigger == EffectDef.Trigger.ON_FIGHT_START and listener.effect.active_at(sim.tick):
			listener.count += 1
			_run(sim, unit, listener, null, 0)


## The unit has just fallen: its on_fall passives run, from where it fell.
## Returns true if any did.
static func on_fall(sim: CombatSim, unit: UnitState) -> bool:
	var ran: bool = false
	for listener: Listener in unit.listeners:
		if listener.effect.trigger == EffectDef.Trigger.ON_FALL and listener.effect.active_at(sim.tick):
			# Where it fell (phase 8 part 3: the Steaming Ashling, on water).
			if listener.effect.holder != null and not listener.effect.holder.holds(unit, unit):
				continue
			_run(sim, unit, listener, null, 0)
			ran = true
	return ran


## Runs one listener's effect; what it does is marked from_event, one link
## deeper than `chain` (the depth of what set it off; 0 for the triggers
## that aren't events).
static func _run(sim: CombatSim, unit: UnitState, listener: Listener, other: UnitState, damage: int, chain: int = 0) -> void:
	var first: int = sim.combat_log.entries.size()
	var outer: int = sim.chain_depth
	sim.chain_depth = chain + 1
	# Chain of Echoes (phase 5c step 5c): a hero's event effect at depth d is
	# growth_bp(d) as strong, in the relic kind of the damage rule.
	var grows: bool = sim.hero_rules.deeper_steps > 0 and unit.side == EffectSource.Team.HEROES
	if grows:
		unit.relic_bonus_bp = sim.hero_rules.growth_bp(chain + 1) - FixedMath.BP_ONE
	EffectRunner.run_event(sim, unit, listener.part.ability, listener.source, listener.effect, other, damage)
	if grows:
		unit.relic_bonus_bp = 0
	sim.chain_depth = outer
	if first < sim.combat_log.entries.size():
		sim.combat_log.entries[first].starts_fire = true
	for i: int in range(first, sim.combat_log.entries.size()):
		var entry: LogEntry = sim.combat_log.entries[i]
		entry.from_event = true
		entry.chain = maxi(entry.chain, chain + 1)
