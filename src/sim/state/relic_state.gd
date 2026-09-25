class_name RelicState
extends RefCounted
## A relic during a fight, or an active synergy's bonus (which works the same
## way): which side holds it, and which allies have already set off each of
## its on_ally_below_hp effects.

var def: RelicDef
var side: UnitSetup.Side
## Per effect (same index as def.effects): ids of allies that have set it off.
var triggered_by: Array[PackedStringArray] = []
## For a synergy: the synergy (null for a relic).
var synergy: SynergyDef = null
## For a pair, signature, or transformation: the hero's index in
## CombatSim.units and the row slots of the matched items; -1 / empty for
## side-wide bonuses.
var holder_index: int = -1
var matched_slots: Array[int] = []
## For resonance and class traits: the count that was reached.
var count: int = 0


static func make(relic_def: RelicDef, relic_side: UnitSetup.Side) -> RelicState:
	var state := RelicState.new()
	state.def = relic_def
	state.side = relic_side
	for i: int in relic_def.effects.size():
		state.triggered_by.append(PackedStringArray())
	return state


## Who to credit in the log: "relic · Name", "enemy relic · Name", or
## "synergy · Name".
func source() -> EffectSource:
	var result: EffectSource = EffectSource.relic(def, side)
	result.synergy = synergy != null
	return result
