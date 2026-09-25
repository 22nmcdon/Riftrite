class_name RelicState
extends RefCounted
## A relic during a fight: which side holds it, and which allies have already
## set off each of its on_ally_below_hp effects.

var def: RelicDef
var side: UnitSetup.Side
## Per effect (same index as def.effects): ids of allies that have set it off.
var triggered_by: Array[PackedStringArray] = []


static func make(relic_def: RelicDef, relic_side: UnitSetup.Side) -> RelicState:
	var state := RelicState.new()
	state.def = relic_def
	state.side = relic_side
	for i: int in relic_def.effects.size():
		state.triggered_by.append(PackedStringArray())
	return state
