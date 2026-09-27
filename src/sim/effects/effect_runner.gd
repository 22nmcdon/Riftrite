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
## Built so far: damage, heal, and shield. Statuses and cleanse come with
## step 3, and the arena's own effects (knockback, pull, leap, charge, area,
## summon, mana drain, start_collapse) with their steps.


## What an on_hit or on_crit effect knows about the hit that set it off.
class Hit:
	var target: UnitState
	var damage: int
	var crit: bool


## The unit's basic attack fires at its target.
static func basic_attack(sim: CombatSim, unit: UnitState) -> void:
	fire(sim, unit, unit.attack.def, unit.target)
	unit.attack.spend()


## `ability` fires from `unit` at `target`.
static func fire(sim: CombatSim, unit: UnitState, ability: AbilityDef, target: UnitState) -> void:
	var source: EffectSource = EffectSource.make(unit.id, ability.id, ability.name)
	var fired: LogEntry = sim.new_entry(LogEntry.Kind.FIRE, source)
	fired.target = target.id if target != null else ""
	sim.combat_log.add(fired)
	var shot: Shots.Shot = null
	if target != null and ability.is_shot(unit.stats.get_stat(UnitStats.Stat.RANGE)):
		shot = Shots.Shot.new()
		shot.source = source
		shot.shooter = unit
		shot.ability = ability
		shot.target = target
	for effect: EffectDef in ability.effects:
		if effect.trigger != EffectDef.Trigger.ON_FIRE or not effect.active_at(sim.tick):
			continue
		if shot != null and effect.target == EffectDef.Target.TARGET:
			var amount: int = amount_of(effect, unit)
			var crit: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability))
			shot.effects.append(effect)
			shot.amounts.append(amount)
			shot.crits.append(crit)
			continue
		for victim: UnitState in _targets(sim, unit, effect.target, target, null):
			var crit_now: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability))
			land(sim, unit, ability, source, effect, victim, amount_of(effect, unit), crit_now)
	if shot != null and not shot.effects.is_empty():
		Shots.fire(sim, shot)


## One effect reaching `victim` with its number already worked out (as it
## fired, or as its shot left). A damage hit then sets off the ability's
## on_hit (and on a crit, on_crit) effects.
static func land(sim: CombatSim, unit: UnitState, ability: AbilityDef, source: EffectSource, effect: EffectDef, victim: UnitState, amount: int, crit: bool) -> void:
	match effect.type:
		EffectDef.Type.DAMAGE:
			var damage: int = FixedMath.apply_bp(amount, sim.tuning.crit_damage_bp) if crit else amount
			var hit := Hit.new()
			hit.target = victim
			hit.crit = crit
			hit.damage = deal_hit(sim, source, victim, damage, crit)
			if effect.trigger == EffectDef.Trigger.ON_FIRE:
				_on_hit(sim, unit, ability, source, hit)
		EffectDef.Type.HEAL:
			heal(sim, victim, amount, source)
		EffectDef.Type.SHIELD:
			give_shield(sim, victim, amount, source)
		_:
			push_error("EffectRunner: %s isn't built yet (phase 1, step 3)" % EffectDef.TYPE_NAMES[effect.type])


static func _on_hit(sim: CombatSim, unit: UnitState, ability: AbilityDef, source: EffectSource, hit: Hit) -> void:
	for effect: EffectDef in ability.effects:
		var wanted: bool = effect.trigger == EffectDef.Trigger.ON_HIT or (effect.trigger == EffectDef.Trigger.ON_CRIT and hit.crit)
		if not wanted or not effect.active_at(sim.tick):
			continue
		for victim: UnitState in _targets(sim, unit, effect.target, null, hit):
			var amount: int = amount_of(effect, unit)
			if effect.amount_bp_of_damage > 0:
				amount = FixedMath.apply_bp(hit.damage, effect.amount_bp_of_damage)
			var crit: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(crit_chance_bp(sim, unit, ability))
			land(sim, unit, ability, source, effect, victim, amount, crit)


## The effect's number from the unit's stats: base plus stat scaling.
## (The same number ValueBreakdown.compute gives with no multipliers, worked
## out without building the breakdown.)
static func amount_of(effect: EffectDef, unit: UnitState) -> int:
	var amount: int = effect.base_value()
	for stat: int in effect.scaling.size():
		if effect.scaling[stat] != 0:
			amount += FixedMath.apply_bp(unit.stats.values[stat], effect.scaling[stat])
	return amount


static func crit_chance_bp(sim: CombatSim, unit: UnitState, ability: AbilityDef) -> int:
	return ability.crit_chance_bp + unit.stats.get_stat(UnitStats.Stat.CRIT) * sim.tuning.crit_bp_per_point


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
		EffectDef.Target.ALL_ENEMIES:
			found = sim.standing_enemies_of(unit)
		EffectDef.Target.ALL_ALLIES:
			found = sim.standing_allies_of(unit)
	return found


## Lands `amount` of hit damage (after crits) on `target`: DEF, then Shield,
## then HP. Logs it and returns what got through DEF.
static func deal_hit(sim: CombatSim, source: EffectSource, target: UnitState, amount: int, crit: bool) -> int:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.DAMAGE, source)
	var dealt: int = sim.mitigate_hit(target, amount)
	entry.target = target.id
	entry.amount = dealt
	entry.mitigated = amount - dealt
	entry.crit = crit
	entry.absorbed = sim.apply_damage(target, dealt)
	target.last_hit_by = source.describe()
	if source.relic_side < 0 and source.unit_id != target.id:
		target.last_attacker = source.unit_id
	sim.combat_log.add(entry)
	return dealt


## Heals `target`, capped at its max HP, and logs it.
static func heal(sim: CombatSim, target: UnitState, amount: int, source: EffectSource) -> void:
	var healed: int = clampi(target.max_hp - target.hp, 0, amount)
	target.hp += healed
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.HEAL, source)
	entry.target = target.id
	entry.amount = healed
	sim.combat_log.add(entry)


static func give_shield(sim: CombatSim, target: UnitState, amount: int, source: EffectSource) -> void:
	target.shield += amount
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.SHIELD, source)
	entry.target = target.id
	entry.amount = amount
	sim.combat_log.add(entry)
