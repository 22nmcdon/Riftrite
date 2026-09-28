class_name Phases
extends RefCounted
## Phases in a fight (docs/plans/rebuild-phase1-arena-sim.md, section 3; the
## data is PhaseDef). Checked in tick step 6, after events: a standing unit
## (HP above 0) below its next phase's threshold enters it, and one that fell
## past several enters each in turn. Entering is logged (PHASE), and the unit
## goes on with the phase's kit from its next update:
##   - a new basic attack keeps the cooldown progress it had;
##   - a new signature starts fresh (a cast under way is cancelled);
##   - a new mana bar starts at its own start; a bar taken away is gone;
##   - a new targeting rule drops its target, so it picks again by it;
##   - passives are set up again (event counts, and the allies an
##     on_ally_below_hp passive has run for, carry over for those kept),
##     and auras are folded in again.


## Step 6's phase check.
static func check(sim: CombatSim) -> void:
	var entered: bool = false
	for unit: UnitState in sim.units:
		var phases: Array[PhaseDef] = unit.phases
		while unit.phase < phases.size() and unit.alive and unit.hp > 0 \
				and unit.hp * FixedMath.BP_ONE < unit.max_hp * phases[unit.phase].below_hp_bp:
			_enter(sim, unit, phases[unit.phase])
			unit.phase += 1
			entered = true
	if entered:
		sim.units_joined()


static func _enter(sim: CombatSim, unit: UnitState, phase: PhaseDef) -> void:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.PHASE, EffectSource.make(unit.id, phase.id, phase.name))
	entry.target = unit.id
	entry.note = phase.name
	sim.combat_log.add(entry)
	var before: UnitDef = unit.def
	var kit: UnitDef = phase.kit
	unit.def = kit
	if kit.basic_attack != before.basic_attack:
		var progress: int = unit.attack.progress_bp
		unit.attack = AbilityState.make(kit.basic_attack, unit.id)
		unit.attack.progress_bp = progress
	if kit.signature != before.signature:
		if unit.signature != null and unit.signature.casting():
			Signatures.cancel_cast(sim, unit, "phase")
		unit.signature = AbilityState.make(kit.signature, unit.id)
	if kit.mana != before.mana:
		Mana.set_bar(unit, kit.mana)
	if kit.targeting != before.targeting:
		unit.target = null
		unit.look_again_at = 0
	var kept: Dictionary[String, Passives.Listener] = {}
	for listener: Passives.Listener in unit.listeners:
		kept[_listener_key(listener)] = listener
	unit.listeners.clear()
	unit.status_swaps.clear()
	Passives.set_up(unit)
	for listener: Passives.Listener in unit.listeners:
		var before_listener: Passives.Listener = kept.get(_listener_key(listener))
		if before_listener != null:
			listener.count = before_listener.count
			listener.allies_done = before_listener.allies_done
	sim.note_listeners(unit)


## A listener's passive and effect, to carry its count over (the same part
## object: a passive the phase didn't replace).
static func _listener_key(listener: Passives.Listener) -> String:
	return "%d:%d" % [listener.part.get_instance_id(), listener.part.ability.effects.find(listener.effect)]
