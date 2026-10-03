class_name Events
extends RefCounted
## A unit's events, read from the combat log (docs/plans/rebuild-phase1-arena-sim.md,
## section 3, step 6; the trigger names are EffectDef's event triggers):
##   on_basic_attack  its basic attack fires
##   on_ability       its signature fires (for passives)
##   on_holder_crit   one of its hits crits
##   on_shielded      it gains Shield
##   on_hit_taken     an enemy's hit lands on it
##   on_heal          it restores HP to a unit
##   on_status        it applies a status
##   on_kill          an enemy it hit last falls
##   on_hop           it hops away (hop_away)
## Phase 5c step 3 (docs/plans/rebuild-phase5c-combos.md, section 8.4):
##   on_holder_hit    one of its hits lands on an enemy
##   on_shield_broken a hit or damage over time takes the last of its Shield
##   on_ally_ability  an ally's signature fires
##   on_status_ended  a status on it runs out (phase 5c step 5b)
## Phase 5c step 6b: on_charged (a charge or leap's hit lands on it) and
## on_enemy_fell (an enemy falls; raised beside on_kill).
## Phase 8 part 2: on_ally_shield_broken (a Shield on one of its side breaks;
## Thornweave), on_wall_block (its wall stops a shot or takes a strike;
## The Unbroken Gate), naming the shooter or striker, and on_rise (it rises:
## Second Dawn or its own rise passive; Dread Return).
## After every unit has acted, CombatSim hands over the entries logged since
## the last read, in log order (so what happens in the deaths step is read
## on the next tick); kills are raised as deaths are settled. Relic effects
## raise nothing.
## Chains (section 8.5): what a passive's effect does can raise more events.
## Each entry carries its depth (LogEntry.chain: one more than the entry that
## set the effect off), and dispatch keeps reading while the log grows, so a
## chain resolves in the tick it starts; an entry at the fight's chain_limit
## raises nothing. A kill carries the chain of the hit that felled the unit.
## Count signatures (Signatures.on_event) and ability passives
## (Passives.on_event) listen, and so do ally_fires signatures (a FIRE of
## their ally's ability; Signatures.ally_fired).


## The log kinds that raise events (the rest are skipped at once).
const _RAISES: Array[LogEntry.Kind] = [LogEntry.Kind.FIRE, LogEntry.Kind.DAMAGE, LogEntry.Kind.SHIELD, LogEntry.Kind.HEAL,
	LogEntry.Kind.STATUS_APPLIED, LogEntry.Kind.HOP, LogEntry.Kind.STATUS_DAMAGE, LogEntry.Kind.STATUS_ENDED, LogEntry.Kind.LIFESTEAL,
	LogEntry.Kind.PUSH, LogEntry.Kind.GUARD, LogEntry.Kind.ARRIVE, LogEntry.Kind.SHOT_FIZZLED, LogEntry.Kind.WALL_HIT, LogEntry.Kind.RISE]


## Raises the events in the log from entry `from` on, including those the
## events themselves add (a chain), and returns where it stopped. `to` is
## where the log ended when the units had acted.
static func dispatch(sim: CombatSim, from: int, to: int) -> int:
	var i: int = from
	var limit: int = sim.tuning.chain_limit
	while i < maxi(to, sim.combat_log.entries.size()):
		var entry: LogEntry = sim.combat_log.entries[i]
		i += 1
		if not _RAISES.has(entry.kind):
			continue
		if entry.chain >= (limit if sim.hero_rules.deeper_steps == 0 else sim.chain_limit_of(entry.source_unit, entry.source_relic_side)):
			continue
		if entry.kind == LogEntry.Kind.STATUS_ENDED:
			# Its holder's event, whoever put the status there (a relic too).
			if sim.status_end_listeners:
				_raise(sim, sim.unit_by_id(entry.target), EffectDef.Trigger.ON_STATUS_ENDED, entry.chain, sim.unit_by_id(entry.target), 0, entry.status)
			continue
		if entry.kind == LogEntry.Kind.RISE:
			# The risen unit's event, whatever raised it (phase 8 part 2,
			# Dread Return).
			var risen: UnitState = sim.unit_by_id(entry.target)
			_raise(sim, risen, EffectDef.Trigger.ON_RISE, entry.chain, risen)
			continue
		if entry.source_relic_side >= 0 or entry.source_unit.is_empty():
			continue
		var source: UnitState = sim.unit_by_id(entry.source_unit)
		var target: UnitState = sim.unit_by_id(entry.target) if not entry.target.is_empty() else null
		var chain: int = entry.chain
		match entry.kind:
			LogEntry.Kind.FIRE:
				# A boost that lasts until its holder attacks (phase 5c step 6b,
				# Shadow Step) ends: that attack had it.
				if not source.statuses.is_empty():
					Statuses.end_on_attack(sim, source)
				var basic: bool = entry.source_ability == source.def.basic_attack.id
				_raise(sim, source, EffectDef.Trigger.ON_BASIC_ATTACK if basic else EffectDef.Trigger.ON_ABILITY, chain)
				if not basic and sim.ally_ability_listeners:
					for ally: UnitState in (sim.heroes if source.side == EffectSource.Team.HEROES else sim.enemies):
						if ally != source:
							_raise(sim, ally, EffectDef.Trigger.ON_ALLY_ABILITY, chain, source)
				if sim.ally_fire_listeners:
					Signatures.ally_fired(sim, source, entry.source_ability, target)
			LogEntry.Kind.DAMAGE:
				if target == null:
					continue
				if entry.crit:
					_raise(sim, source, EffectDef.Trigger.ON_HOLDER_CRIT, chain, target, entry.amount)
				if source.side != target.side:
					# The ability rides along (on_holder_hit's from_ability, phase 8).
					_raise(sim, source, EffectDef.Trigger.ON_HOLDER_HIT, chain, target, entry.amount, entry.source_ability)
					_raise(sim, target, EffectDef.Trigger.ON_HIT_TAKEN, chain, source, entry.amount)
					# A charge or a leap's hit (phase 5c step 6b, Braced).
					if not target.listeners.is_empty() and source.def.signature != null and entry.source_ability == source.def.signature.id \
							and source.def.signature.moves_itself():
						_raise(sim, target, EffectDef.Trigger.ON_CHARGED, chain, source, entry.amount)
				if entry.broke_shield:
					_raise(sim, target, EffectDef.Trigger.ON_SHIELD_BROKEN, chain, source, entry.absorbed)
					if sim.ally_shield_listeners:
						_shield_broke_near(sim, target, source, entry.absorbed, chain)
			LogEntry.Kind.STATUS_DAMAGE:
				if target != null and entry.broke_shield:
					_raise(sim, target, EffectDef.Trigger.ON_SHIELD_BROKEN, chain, source, entry.absorbed)
					if sim.ally_shield_listeners:
						_shield_broke_near(sim, target, source, entry.absorbed, chain)
			LogEntry.Kind.SHIELD:
				if target != null and entry.amount > 0:
					_raise(sim, target, EffectDef.Trigger.ON_SHIELDED, chain, target)
			LogEntry.Kind.HEAL:
				if target != null and entry.amount > 0:
					# The HP healed and the ability ride along (on_heal's
					# was_below_pct and from_ability, phase 5c step 7c).
					_raise(sim, source, EffectDef.Trigger.ON_HEAL, chain, target, entry.amount, entry.source_ability)
					if entry.lifesteal:
						_raise(sim, source, EffectDef.Trigger.ON_LIFESTEAL, chain)
			LogEntry.Kind.LIFESTEAL:
				if entry.amount > 0:
					_raise(sim, source, EffectDef.Trigger.ON_LIFESTEAL, chain)
			# Phase 5c step 5d: knocking an enemy back, and a Guard taking its
			# share of a hit on an ally.
			LogEntry.Kind.PUSH:
				if target != null and target.side != source.side and entry.note.begins_with("knocked back"):
					_raise(sim, source, EffectDef.Trigger.ON_KNOCKBACK, chain, target)
			LogEntry.Kind.GUARD:
				if target != null and entry.amount > 0:
					# The share it took rides along (amount_bp_of_damage; phase 8
					# part 2, The Hearthkeeper).
					_raise(sim, source, EffectDef.Trigger.ON_GUARD, chain, target, entry.amount)
			LogEntry.Kind.STATUS_APPLIED:
				# Engaged comes from the Engage trait, not an effect.
				if target != null and entry.status != sim.content.engaged_status.id:
					_raise(sim, source, EffectDef.Trigger.ON_STATUS, chain, target, 0, entry.status)
			LogEntry.Kind.HOP:
				_raise(sim, source, EffectDef.Trigger.ON_HOP, chain)
			LogEntry.Kind.ARRIVE:
				_raise(sim, source, EffectDef.Trigger.ON_ARRIVE, chain)
			LogEntry.Kind.SHOT_FIZZLED:
				if not entry.wall_of.is_empty():
					_raise(sim, sim.unit_by_id(entry.wall_of), EffectDef.Trigger.ON_WALL_BLOCK, chain, source)
			LogEntry.Kind.WALL_HIT:
				if entry.note.begins_with("struck"):
					_raise(sim, sim.unit_by_id(entry.wall_of), EffectDef.Trigger.ON_WALL_BLOCK, chain, source)
	return i


## on_kill for a unit that just fell, credited to whoever hit it last (an
## enemy of it that still stands), naming the fallen (Decision 13).
static func kill(sim: CombatSim, fallen: UnitState) -> void:
	if fallen.last_attacker.is_empty() or fallen.last_hit_chain >= sim.chain_limit_of(fallen.last_attacker, -1):
		return
	var killer: UnitState = sim.unit_by_id(fallen.last_attacker)
	if killer != null and killer.alive and killer.side != fallen.side:
		# The ability that felled it rides as `status` (on_kill's
		# from_signature, phase 5c step 6b).
		_raise(sim, killer, EffectDef.Trigger.ON_KILL, fallen.last_hit_chain, fallen, 0,
			fallen.last_hit_source.ability_id if fallen.last_hit_source != null else "")
		if sim.tactic_kills and killer.tactic != null:
			Tactics.on_kill(sim, killer, fallen)


## on_enemy_fell (phase 5c step 6b, Scavenger): each standing enemy of the
## fallen with a passive on it hears it, naming the fallen.
static func enemy_fell(sim: CombatSim, fallen: UnitState) -> void:
	if fallen.last_hit_chain >= sim.tuning.chain_limit:
		return
	for unit: UnitState in (sim.enemies if fallen.side == EffectSource.Team.HEROES else sim.heroes):
		if unit.alive and not unit.listeners.is_empty():
			_raise(sim, unit, EffectDef.Trigger.ON_ENEMY_FELL, fallen.last_hit_chain, fallen)


## `chain`: the depth of the entry that raised it; `other`: the unit the
## event names; `damage`: the hit (or Shield) it's about; `status`: the
## status applied (on_status).
## A Shield on `holder` broke (phase 8 part 2, Thornweave): every standing
## unit of its side hears it, in the fight's order.
static func _shield_broke_near(sim: CombatSim, holder: UnitState, breaker: UnitState, absorbed: int, chain: int) -> void:
	for ally: UnitState in (sim.heroes if holder.side == EffectSource.Team.HEROES else sim.enemies):
		_raise(sim, ally, EffectDef.Trigger.ON_ALLY_SHIELD_BROKEN, chain, breaker, absorbed)


static func _raise(sim: CombatSim, unit: UnitState, event: EffectDef.Trigger, chain: int, other: UnitState = null, damage: int = 0, status: String = "") -> void:
	if unit == null or not unit.alive:
		return
	if unit.signature != null:
		Signatures.on_event(unit, event)
	if not unit.listeners.is_empty():
		Passives.on_event(sim, unit, event, other, damage, status, chain)
