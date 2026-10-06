class_name Grips
extends RefCounted
## A signature that grips its target (phase 8 part 4, Tamsin's Garrote;
## docs/plans/rebuild-phase8-heroes.md section 5): AbilityDef's "grip".
##   "grip": {"status": "garroted", "every_ms": 500,
##            "effects": [...effects at "target"...], "veil": "garroting"}
## When the signature fires, its unit grips its target (its on_fire effects
## put "status" there, a Root). Every every_ms after, the grip's effects land
## on the target, sourced to the signature (its DAMAGE lines are the
## ability's hits). While it grips, the unit doesn't walk (Movement waits,
## "gripping"), and "veil" (a Stealth of its own, optional) stays on it. The
## grip ends when the target no longer has "status" (it ran out, or was
## cleansed), the target falls, or the unit falls or fires the signature at
## another; the veil ends with it, noted "the grip ended". A unit with no
## grip never reaches this code.


## `unit` grips `target` with its signature `state` (it just fired).
static func start(sim: CombatSim, unit: UnitState, state: AbilityState, target: UnitState) -> void:
	var ability: AbilityDef = state.def
	if ability.grip_status.is_empty() or target == null or target == unit:
		return
	if unit.grip_target != null:
		end(sim, unit, "it gripped another")
	unit.grip_target = target
	unit.grip_state = state
	unit.grip_next = sim.tick + ability.grip_every_ticks
	sim.any_grips = true
	if not ability.grip_veil.is_empty():
		# It lasts as long as the grip (it ends with it).
		Statuses.apply(sim, unit, ability.grip_veil, 1, sim.tuning.tie_ticks, state.source)


## The grip's part of the unit's update: it ends, or its effects land when
## due.
static func tick(sim: CombatSim, unit: UnitState) -> void:
	var target: UnitState = unit.grip_target
	var ability: AbilityDef = unit.grip_state.def
	if not unit.alive or not target.alive or target.hp <= 0 or Statuses.find(target, ability.grip_status) == null:
		end(sim, unit, "the grip ended")
		return
	if sim.tick < unit.grip_next:
		return
	unit.grip_next = sim.tick + ability.grip_every_ticks
	var source: EffectSource = unit.grip_state.source
	for effect: EffectDef in ability.grip_effects:
		var crit: bool = effect.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(EffectRunner.crit_chance_bp(sim, unit, ability, target))
		EffectRunner.land(sim, unit, ability, source, effect, target, EffectRunner.amount_of(effect, unit, 0, sim), crit, EffectRunner.NO_POINT, EffectRunner.power_of(effect, unit))
		if not target.alive or target.hp <= 0:
			break


## The grip ends; its veil goes with it.
static func end(sim: CombatSim, unit: UnitState, why: String) -> void:
	var ability: AbilityDef = unit.grip_state.def
	unit.grip_target = null
	unit.grip_state = null
	if not ability.grip_veil.is_empty():
		var veil: StatusState = Statuses.find(unit, ability.grip_veil)
		if veil != null:
			Statuses.end_now(sim, unit, veil, why)
