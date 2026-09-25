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
	Infusions.gain_xp(sim, item, item.def.xp_per_fire)
	if sim.rng.roll_bp(item.extra_trigger_chance_bp):
		_fire_once(sim, item, "again (%s)" % item.extra_trigger_source)
		Infusions.gain_xp(sim, item, item.def.xp_per_fire)


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
	# Only the item's own effects produce output that essences convert.
	var own: bool = sourced.infusion_id.is_empty()
	for target: UnitState in Targeting.pick(effect.target, sim.owner_of(item), hit_target, sim):
		var amount: int = sourced.take_amount()
		match effect.type:
			EffectDef.Type.DAMAGE:
				_hit(sim, item, source, target, amount, hit == null, own)
			EffectDef.Type.HEAL:
				heal(sim, target, amount, source, item)
				if own:
					Conversions.on_output(sim, item, "heal", amount, target, false)
			EffectDef.Type.SHIELD:
				if effect.amount_bp_of_damage > 0:
					amount = FixedMath.apply_bp(hit.damage, effect.amount_bp_of_damage)
				give_shield(sim, target, amount, source)
				if own:
					Conversions.on_output(sim, item, "shield", amount, target, false)
			EffectDef.Type.APPLY_STATUS:
				Statuses.apply(sim, target, item.replaced_status(effect.status_id), amount, source)
				if own and sim.content.is_output_kind(effect.status_id):
					Conversions.on_output(sim, item, effect.status_id, amount, target, false)


static func _hit(sim: CombatSim, item: ItemState, source: EffectSource, target: UnitState, base_amount: int, can_trigger: bool, own: bool) -> void:
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
	deal_hit(sim, source, target, hit.damage, hit.crit)
	if own:
		Conversions.on_output(sim, item, "damage", hit.damage, target, hit.crit)

	if not can_trigger:
		return
	for sourced: SourcedEffect in item.effects:
		var trigger: EffectDef.Trigger = sourced.effect.trigger
		if trigger == EffectDef.Trigger.ON_HIT or (trigger == EffectDef.Trigger.ON_CRIT and hit.crit):
			_run(sim, item, sourced, hit)


## Lands `amount` of hit damage (after crits) on `target`: DEF, then shield,
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
	sim.combat_log.add(entry)
	return dealt


## Heals `target` (capped at max HP), logs it, and if any HP came back,
## weakens the target's damage over time. The first heal in a window strips
## heal_cleanse_bp of each damage-over-time status; each further heal within
## heal_cleanse_window strips that share times heal_cleanse_falloff_bp again
## (by default: 10%, 5%, 2.5%, ...), so rapid small heals can't wipe it out.
## A heal from an item with a heal echo (Bloom) then echoes a share onto a
## random other ally; echoes don't echo.
static func heal(sim: CombatSim, target: UnitState, amount: int, source: EffectSource, item: ItemState = null) -> void:
	_heal_one(sim, target, amount, source)
	if item == null or item.heal_echo_bp() <= 0:
		return
	var others: Array[UnitState] = []
	for ally: UnitState in sim.allies_of(sim.owner_of(item)):
		if ally != target and ally.is_standing():
			others.append(ally)
	var echo: int = FixedMath.apply_bp(amount, item.heal_echo_bp())
	if others.is_empty() or echo <= 0:
		return
	var echo_source := EffectSource.make(source.unit_id, source.item_id, source.item_name, source.infusion_id, "%s echo" % item.infusion_name())
	_heal_one(sim, others[sim.rng.range_int(others.size())], echo, echo_source)


static func _heal_one(sim: CombatSim, target: UnitState, amount: int, source: EffectSource) -> void:
	var healed: int = mini(amount, target.max_hp - target.hp)
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
	Statuses.cleanse_over_time(sim, target, share_bp)


static func give_shield(sim: CombatSim, target: UnitState, amount: int, source: EffectSource) -> void:
	target.shield += amount
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.SHIELD, source)
	entry.target = target.id
	entry.amount = amount
	sim.combat_log.add(entry)


static func _source(sim: CombatSim, item: ItemState, sourced: SourcedEffect) -> EffectSource:
	var infusion: String = sourced.infusion_id if sourced != null else ""
	var infusion_name: String = sourced.infusion_name if sourced != null else ""
	return EffectSource.make(sim.owner_of(item).id, item.def.id, item.def.name, infusion, infusion_name)
