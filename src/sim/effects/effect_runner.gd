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
## Numbers come from the unit's stats (with its auras) and its output auras
## (Passives.boosted); statuses it applies may be swapped (replace_status).
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
	unit.attack.spend()
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
		heal_boost_bp = unit.tactic.heal_bp
		source = source.with_bonus(Tactics.bonus_note(heal_boost_bp, unit.tactic))
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
		if effect.type == EffectDef.Type.SUMMON:
			Summons.summon(sim, unit, source, effect, target)
			continue
		if shot != null and effect.target == EffectDef.Target.TARGET:
			var amount: int = _boosted_heal(effect, amount_of(effect, unit, 0, sim), heal_boost_bp)
			var crit: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability))
			shot.effects.append(effect)
			shot.amounts.append(amount)
			shot.crits.append(crit)
			continue
		for victim: UnitState in _targets(sim, unit, effect.target, target, null, effect):
			var crit_now: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability))
			land(sim, unit, ability, source, effect, victim, _boosted_heal(effect, amount_of(effect, unit, 0, sim), heal_boost_bp), crit_now)
	if shot != null and not shot.effects.is_empty():
		Shots.fire(sim, shot)
	return true


## A heal's amount with a payoff's `boost_bp` on top (anything else as it is).
static func _boosted_heal(effect: EffectDef, amount: int, boost_bp: int) -> int:
	if boost_bp == 0 or effect.type != EffectDef.Type.HEAL:
		return amount
	return FixedMath.apply_bp(amount, FixedMath.BP_ONE + boost_bp)


## One effect reaching `victim` with its number already worked out (as it
## fired, as its shot left, or as its area was cast). A damage hit then sets
## off the ability's on_hit (and on a crit, on_crit) effects. A knockback
## goes away from `push_from` (an area's center), or else from the unit.
static func land(sim: CombatSim, unit: UnitState, ability: AbilityDef, source: EffectSource, effect: EffectDef, victim: UnitState, amount: int, crit: bool, push_from: Vector2i = NO_POINT) -> void:
	match effect.type:
		EffectDef.Type.DAMAGE:
			var damage: int = FixedMath.apply_bp(amount, sim.tuning.crit_damage_bp) if crit else amount
			var dealt: int = deal_hit(sim, source, victim, damage, crit)
			if effect.trigger == EffectDef.Trigger.ON_FIRE and ability.has_hit_effects:
				var hit := Hit.new()
				hit.target = victim
				hit.crit = crit
				hit.damage = dealt
				_on_hit(sim, unit, ability, source, hit)
		EffectDef.Type.HEAL:
			if effect.amount_bp_of_max_hp > 0:
				amount = Passives.boosted(unit, effect, FixedMath.apply_bp(victim.max_hp, effect.amount_bp_of_max_hp))
			heal(sim, victim, amount, source, effect.overheal_shield_bp)
		EffectDef.Type.SHIELD:
			give_shield(sim, victim, amount, source)
		EffectDef.Type.APPLY_STATUS:
			var status_id: String = unit.status_swaps.get(effect.status_id, effect.status_id)
			Statuses.apply(sim, victim, status_id, amount, effect.duration_ticks, source)
		EffectDef.Type.CLEANSE:
			Statuses.cleanse_over_time(sim, victim, mini(amount, FixedMath.BP_ONE), source)
		EffectDef.Type.MANA_DRAIN:
			Mana.drain(sim, victim, amount, source)
		EffectDef.Type.GAIN_MANA:
			Mana.gain(sim, victim, amount * Mana.SCALE)
		EffectDef.Type.KNOCKBACK:
			Displacement.knockback(sim, victim, unit.pos if push_from == NO_POINT else push_from, unit.forward(), effect.hexes, source)
		EffectDef.Type.PULL:
			Displacement.pull(sim, victim, unit, effect.hexes, source)
		EffectDef.Type.LEAP:
			Displacement.leap(sim, unit, victim, effect, source)
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
			var crit: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability))
			land(sim, unit, ability, source, effect, victim, amount, crit)


## An ability passive's effect, set off by an event (Passives.on_event):
## `other` is the unit the event names, `damage` the hit it's about. It
## lands at once, and never sets off on_hit effects.
static func run_event(sim: CombatSim, unit: UnitState, ability: AbilityDef, source: EffectSource, effect: EffectDef, other: UnitState, damage: int) -> void:
	if effect.type == EffectDef.Type.AREA:
		Areas.cast(sim, unit, ability, source, effect, other if other != null else unit.target)
		return
	if effect.type == EffectDef.Type.SNARE:
		Snares.set_ahead(sim, unit, ability, source, effect, other if other != null else unit.target)
		return
	if effect.type == EffectDef.Type.WALL:
		Walls.raise(sim, unit, source, effect, other if other != null else unit.target)
		return
	var hit: Hit = null
	if other != null:
		hit = Hit.new()
		hit.target = other
		hit.damage = damage
	for victim: UnitState in _targets(sim, unit, effect.target, unit.target, hit, effect):
		var crit: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability))
		land(sim, unit, ability, source, effect, victim, amount_of(effect, unit, damage, sim), crit)


## The effect's number: base plus stat scaling from the unit's stats (or a
## share of the hit's `damage`, for amount_bp_of_damage), then its output
## auras. (The same number ValueBreakdown.compute gives, worked out without
## building the breakdown.)
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


static func crit_chance_bp(sim: CombatSim, unit: UnitState, ability: AbilityDef) -> int:
	return ability.crit_chance_bp + unit.stats.get_stat(UnitStats.Stat.CRIT) * sim.tuning.crit_bp_per_point + unit.aura_bp[AuraDef.Stat.CRIT_CHANCE_BP]


## Who an effect reaches: its ability's target, the unit hit, the unit
## itself, every standing unit of a side (in the fight's order), or those
## near the target (phase 4: near the ability's target, or the unit hit).
static func _targets(sim: CombatSim, unit: UnitState, target: EffectDef.Target, aimed_at: UnitState, hit: Hit, effect: EffectDef = null) -> Array[UnitState]:
	var found: Array[UnitState] = []
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
	var enemies: bool = effect.target == EffectDef.Target.ENEMY_NEAR_TARGET or effect.target == EffectDef.Target.ENEMIES_NEAR_TARGET
	var pool: Array[UnitState] = sim.targetable_enemies_of(unit) if enemies else sim.standing_allies_of(unit)
	var single: bool = effect.target == EffectDef.Target.ENEMY_NEAR_TARGET or effect.target == EffectDef.Target.ALLY_NEAR_TARGET
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


## Lands `amount` of hit damage (after crits) on `target`: a Mark, DEF, then
## Shield, then HP. Logs it and returns what got through DEF.
static func deal_hit(sim: CombatSim, source: EffectSource, target: UnitState, amount: int, crit: bool) -> int:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.DAMAGE, source)
	if sim.damage_payoffs:
		var payoff: int = Tactics.damage_bonus_bp(sim, source, target)
		if payoff > 0:
			amount = FixedMath.apply_bp(amount, FixedMath.BP_ONE + payoff)
			entry.bonus = Tactics.bonus_note(payoff, sim.unit_by_id(source.unit_id).tactic)
	var marked: int = Statuses.damage_taken_bp(target) if not target.statuses.is_empty() else 0
	var raw: int = FixedMath.apply_bp(amount, FixedMath.BP_ONE + marked)
	# Guard (phase 4): an ally's guard takes its share of the hit, against its
	# own DEF.
	var guard: UnitState = Guards.covering(sim, source, target) if not sim.guards.is_empty() else null
	var guarded_raw: int = FixedMath.apply_bp(raw, guard.guard.share_bp) if guard != null else 0
	var dealt: int = sim.mitigate_hit(target, raw - guarded_raw)
	var guarded: int = sim.mitigate_hit(guard, guarded_raw) if guard != null else 0
	entry.target = target.id
	entry.mitigated = maxi(raw - guarded_raw - dealt, 0)
	entry.amount = dealt
	entry.crit = crit
	entry.absorbed = sim.apply_damage(target, dealt)
	target.last_hit_source = source
	target.last_hit_status = ""
	if source.relic_side < 0 and source.unit_id != target.id:
		target.last_attacker = source.unit_id
	sim.combat_log.add(entry)
	if guarded > 0:
		Guards.take(sim, guard, target, guarded, source)
	return dealt


## Heals `target` (capped at its max HP), logs it, and if any HP came back,
## weakens its damage over time. The first heal in a window strips
## heal_cleanse_bp of each damage-over-time status; each further heal within
## heal_cleanse_window strips that share times heal_cleanse_falloff_bp again
## (by default 10%, 5%, 2.5%, ...), so rapid small heals can't wipe it out.
## `overheal_shield_bp`: what the heal would have restored past full HP comes
## back as that share of Shield (phase 4, Ward Thread).
static func heal(sim: CombatSim, target: UnitState, amount: int, source: EffectSource, overheal_shield_bp: int = 0) -> void:
	if target.aura_bp[AuraDef.Stat.HEALING_TAKEN_BP] != FixedMath.BP_ONE:
		amount = FixedMath.apply_bp(amount, target.aura_bp[AuraDef.Stat.HEALING_TAKEN_BP])
	var healed: int = clampi(target.max_hp - target.hp, 0, amount)
	target.hp += healed
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.HEAL, source)
	entry.target = target.id
	entry.amount = healed
	sim.combat_log.add(entry)
	if overheal_shield_bp > 0 and amount > healed:
		var shield: int = FixedMath.apply_bp(amount - healed, overheal_shield_bp)
		if shield > 0:
			give_shield(sim, target, shield, source)
	if healed <= 0:
		return
	var window_start: int = sim.tick - sim.tuning.heal_cleanse_window_ticks
	while not target.recent_heal_ticks.is_empty() and target.recent_heal_ticks[0] <= window_start:
		target.recent_heal_ticks.remove_at(0)
	var share_bp: int = sim.tuning.heal_cleanse_bp
	for i: int in target.recent_heal_ticks.size():
		share_bp = FixedMath.apply_bp(share_bp, sim.tuning.heal_cleanse_falloff_bp)
	target.recent_heal_ticks.append(sim.tick)
	if not target.statuses.is_empty():
		Statuses.cleanse_over_time(sim, target, share_bp, source, true)


static func give_shield(sim: CombatSim, target: UnitState, amount: int, source: EffectSource) -> void:
	target.shield += amount
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.SHIELD, source)
	entry.target = target.id
	entry.amount = amount
	sim.combat_log.add(entry)
