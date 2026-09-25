class_name EffectRunner
extends RefCounted
## Runs an item's effects and writes each result to the combat log.
##
## Trigger flow: when an item fires, its on_fire effects run. Every hit a
## damage effect lands then runs the item's on_hit effects, plus on_crit if the
## hit crit. Damage dealt by an on_hit/on_crit effect does not trigger further
## on_hit effects, so triggers can't loop.


## What an on_hit/on_crit effect needs to know about the hit that caused it.
class Hit:
	var target: UnitState
	var damage: int
	var crit: bool


static func fire(sim: CombatSim, item: ItemState) -> void:
	var entry: LogEntry = _entry(sim, LogEntry.Kind.FIRE, item)
	sim.combat_log.add(entry)
	for effect: EffectDef in item.def.effects:
		if effect.trigger == EffectDef.Trigger.ON_FIRE:
			_run(sim, item, effect, null)


static func _run(sim: CombatSim, item: ItemState, effect: EffectDef, hit: Hit) -> void:
	var hit_target: UnitState = hit.target if hit != null else null
	for target: UnitState in Targeting.pick(effect.target, sim.owner_of(item), hit_target, sim):
		match effect.type:
			EffectDef.Type.DAMAGE:
				_hit(sim, item, target, effect.amount, hit == null)
			EffectDef.Type.HEAL:
				var healed: int = mini(effect.amount, target.max_hp - target.hp)
				target.hp += healed
				var heal_entry: LogEntry = _entry(sim, LogEntry.Kind.HEAL, item)
				heal_entry.target = target.id
				heal_entry.amount = healed
				sim.combat_log.add(heal_entry)
			EffectDef.Type.SHIELD:
				var amount: int = effect.amount
				if effect.amount_bp_of_damage > 0:
					amount = FixedMath.apply_bp(hit.damage, effect.amount_bp_of_damage)
				target.shield += amount
				var shield_entry: LogEntry = _entry(sim, LogEntry.Kind.SHIELD, item)
				shield_entry.target = target.id
				shield_entry.amount = amount
				sim.combat_log.add(shield_entry)
			EffectDef.Type.APPLY_STATUS:
				assert(false, "apply_status is rejected by UnitSetup.validate until build step 4")


static func _hit(sim: CombatSim, item: ItemState, target: UnitState, base_amount: int, can_trigger: bool) -> void:
	var hit := Hit.new()
	hit.target = target
	hit.crit = sim.rng.roll_bp(item.def.crit_chance_bp)
	hit.damage = FixedMath.apply_bp(base_amount, sim.tuning.crit_damage_bp) if hit.crit else base_amount

	var entry: LogEntry = _entry(sim, LogEntry.Kind.DAMAGE, item)
	entry.target = target.id
	entry.amount = hit.damage
	entry.crit = hit.crit
	entry.absorbed = sim.apply_damage(target, hit.damage)
	target.last_hit_by_unit = sim.owner_of(item).id
	target.last_hit_by_item = item.def.name
	sim.combat_log.add(entry)

	if not can_trigger:
		return
	for effect: EffectDef in item.def.effects:
		if effect.trigger == EffectDef.Trigger.ON_HIT or (effect.trigger == EffectDef.Trigger.ON_CRIT and hit.crit):
			_run(sim, item, effect, hit)


static func _entry(sim: CombatSim, kind: LogEntry.Kind, item: ItemState) -> LogEntry:
	var entry := LogEntry.new()
	entry.tick = sim.tick
	entry.kind = kind
	entry.source_unit = sim.owner_of(item).id
	entry.source_item = item.def.id
	entry.source_item_name = item.def.name
	return entry
