class_name EffectRunner
extends RefCounted
## Runs an item's effects (its own and its infusions') and writes each result
## to the combat log.
##
## Trigger flow: when an item fires, its on_fire effects run. Every hit a
## damage effect lands then runs the item's on_hit effects, plus on_crit if the
## hit crit. Damage dealt by an on_hit/on_crit effect does not trigger further
## on_hit effects, so triggers can't loop. A blinded attacker's hit misses:
## no damage and no on_hit effects.
##
## Extra trigger (Storm): after an item fires, it may fire once more at once.
## The extra fire can't chain into another.


## What an on_hit/on_crit effect needs to know about the hit that caused it.
class Hit:
	var target: UnitState
	var damage: int
	var crit: bool


static func fire(sim: CombatSim, item: ItemState) -> void:
	_fire_once(sim, item, "")
	if sim.rng.roll_bp(item.extra_trigger_chance_bp):
		_fire_once(sim, item, "again (%s)" % item.extra_trigger_source)


static func _fire_once(sim: CombatSim, item: ItemState, note: String) -> void:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.FIRE, _source(sim, item, null))
	entry.note = note
	sim.combat_log.add(entry)
	for sourced: SourcedEffect in item.effects:
		if sourced.effect.trigger == EffectDef.Trigger.ON_FIRE:
			_run(sim, item, sourced, null)


static func _run(sim: CombatSim, item: ItemState, sourced: SourcedEffect, hit: Hit) -> void:
	var effect: EffectDef = sourced.effect
	var source: EffectSource = _source(sim, item, sourced)
	var hit_target: UnitState = hit.target if hit != null else null
	for target: UnitState in Targeting.pick(effect.target, sim.owner_of(item), hit_target, sim):
		match effect.type:
			EffectDef.Type.DAMAGE:
				_hit(sim, item, source, target, sourced.final_amount(), hit == null)
			EffectDef.Type.HEAL:
				var healed: int = mini(sourced.final_amount(), target.max_hp - target.hp)
				target.hp += healed
				var heal_entry: LogEntry = sim.new_entry(LogEntry.Kind.HEAL, source)
				heal_entry.target = target.id
				heal_entry.amount = healed
				sim.combat_log.add(heal_entry)
			EffectDef.Type.SHIELD:
				var amount: int = sourced.final_amount()
				if effect.amount_bp_of_damage > 0:
					amount = FixedMath.apply_bp(hit.damage, effect.amount_bp_of_damage)
				target.shield += amount
				var shield_entry: LogEntry = sim.new_entry(LogEntry.Kind.SHIELD, source)
				shield_entry.target = target.id
				shield_entry.amount = amount
				sim.combat_log.add(shield_entry)
			EffectDef.Type.APPLY_STATUS:
				Statuses.apply(sim, target, effect.status_id, sourced.final_amount(), source)


static func _hit(sim: CombatSim, item: ItemState, source: EffectSource, target: UnitState, base_amount: int, can_trigger: bool) -> void:
	var attacker: UnitState = sim.owner_of(item)
	if Statuses.consume_blind(sim, attacker):
		var miss: LogEntry = sim.new_entry(LogEntry.Kind.MISS, source)
		miss.target = target.id
		miss.note = "Blind"
		sim.combat_log.add(miss)
		return

	var hit := Hit.new()
	hit.target = target
	hit.crit = sim.rng.roll_bp(item.crit_chance_bp)
	hit.damage = FixedMath.apply_bp(base_amount, sim.tuning.crit_damage_bp) if hit.crit else base_amount

	var entry: LogEntry = sim.new_entry(LogEntry.Kind.DAMAGE, source)
	var dealt: int = sim.mitigate_hit(target, hit.damage)
	entry.target = target.id
	entry.amount = dealt
	entry.mitigated = hit.damage - dealt
	entry.crit = hit.crit
	entry.absorbed = sim.apply_damage(target, dealt)
	target.last_hit_by = source.describe()
	sim.combat_log.add(entry)

	if not can_trigger:
		return
	for sourced: SourcedEffect in item.effects:
		var trigger: EffectDef.Trigger = sourced.effect.trigger
		if trigger == EffectDef.Trigger.ON_HIT or (trigger == EffectDef.Trigger.ON_CRIT and hit.crit):
			_run(sim, item, sourced, hit)


static func _source(sim: CombatSim, item: ItemState, sourced: SourcedEffect) -> EffectSource:
	var infusion: String = sourced.infusion_id if sourced != null else ""
	var infusion_name: String = sourced.infusion_name if sourced != null else ""
	return EffectSource.make(sim.owner_of(item).id, item.def.id, item.def.name, infusion, infusion_name)
