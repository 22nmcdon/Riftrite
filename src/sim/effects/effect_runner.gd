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
## event, the unit's current target).


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
static func fire(sim: CombatSim, unit: UnitState, state: AbilityState, target: UnitState, reach: int, log_failure: bool = true) -> bool:
	var ability: AbilityDef = state.def
	var source: EffectSource = state.source
	var leap: EffectDef = ability.leap_effect() if target != null else null
	if leap != null and Displacement.leap_spot(sim, unit, target, leap.hexes).x < 0:
		if log_failure:
			Displacement.leap_failed(sim, unit, target, source)
		return false
	var fired: LogEntry = sim.new_entry(LogEntry.Kind.FIRE, source)
	fired.target = target.id if target != null else ""
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
		if effect.type == EffectDef.Type.AREA:
			Areas.cast(sim, unit, ability, source, effect, target)
			continue
		if effect.type == EffectDef.Type.SUMMON:
			Summons.summon(sim, unit, source, effect, target)
			continue
		if shot != null and effect.target == EffectDef.Target.TARGET:
			var amount: int = amount_of(effect, unit, 0, sim)
			var crit: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability))
			shot.effects.append(effect)
			shot.amounts.append(amount)
			shot.crits.append(crit)
			continue
		for victim: UnitState in _targets(sim, unit, effect.target, target, null):
			var crit_now: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability))
			land(sim, unit, ability, source, effect, victim, amount_of(effect, unit, 0, sim), crit_now)
	if shot != null and not shot.effects.is_empty():
		Shots.fire(sim, shot)
	return true


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
			heal(sim, victim, amount, source)
		EffectDef.Type.SHIELD:
			give_shield(sim, victim, amount, source)
		EffectDef.Type.APPLY_STATUS:
			var status_id: String = unit.status_swaps.get(effect.status_id, effect.status_id)
			Statuses.apply(sim, victim, status_id, amount, effect.duration_ticks, source)
		EffectDef.Type.CLEANSE:
			Statuses.cleanse_over_time(sim, victim, mini(amount, FixedMath.BP_ONE), source)
		EffectDef.Type.MANA_DRAIN:
			Mana.drain(sim, victim, amount, source)
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
		for victim: UnitState in _targets(sim, unit, effect.target, null, hit):
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
	var hit: Hit = null
	if other != null:
		hit = Hit.new()
		hit.target = other
		hit.damage = damage
	for victim: UnitState in _targets(sim, unit, effect.target, unit.target, hit):
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
## itself, or every standing unit of a side (in the fight's order).
static func _targets(sim: CombatSim, unit: UnitState, target: EffectDef.Target, aimed_at: UnitState, hit: Hit) -> Array[UnitState]:
	var found: Array[UnitState] = []
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


## Lands `amount` of hit damage (after crits) on `target`: a Mark, DEF, then
## Shield, then HP. Logs it and returns what got through DEF.
static func deal_hit(sim: CombatSim, source: EffectSource, target: UnitState, amount: int, crit: bool) -> int:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.DAMAGE, source)
	var marked: int = Statuses.damage_taken_bp(target) if not target.statuses.is_empty() else 0
	var dealt: int = sim.mitigate_hit(target, FixedMath.apply_bp(amount, FixedMath.BP_ONE + marked))
	entry.target = target.id
	entry.amount = dealt
	entry.mitigated = maxi(FixedMath.apply_bp(amount, FixedMath.BP_ONE + marked) - dealt, 0)
	entry.crit = crit
	entry.absorbed = sim.apply_damage(target, dealt)
	target.last_hit_source = source
	target.last_hit_status = ""
	if source.relic_side < 0 and source.unit_id != target.id:
		target.last_attacker = source.unit_id
	sim.combat_log.add(entry)
	return dealt


## Heals `target` (capped at its max HP), logs it, and if any HP came back,
## weakens its damage over time. The first heal in a window strips
## heal_cleanse_bp of each damage-over-time status; each further heal within
## heal_cleanse_window strips that share times heal_cleanse_falloff_bp again
## (by default 10%, 5%, 2.5%, ...), so rapid small heals can't wipe it out.
static func heal(sim: CombatSim, target: UnitState, amount: int, source: EffectSource) -> void:
	var healed: int = clampi(target.max_hp - target.hp, 0, amount)
	target.hp += healed
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.HEAL, source)
	entry.target = target.id
	entry.amount = healed
	sim.combat_log.add(entry)
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
