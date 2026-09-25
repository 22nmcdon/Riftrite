class_name ItemState
extends RefCounted
## An item (or basic auto-attack) during a fight.

var def: ItemDef
## Index of the owning unit in CombatSim.units (see CombatSim.owner_of).
## An index, not a reference: unit -> items -> unit would be a reference
## cycle, and Godot never frees RefCounted cycles.
var owner_index: int = -1
## First slot the item occupies; -1 for the basic auto-attack.
var slot: int
var cooldown_ticks: int
## Ticks until the item next fires. It first fires one full cooldown in.
var remaining_ticks: int


static func make(item_def: ItemDef, item_slot: int) -> ItemState:
	var state := ItemState.new()
	state.def = item_def
	state.slot = item_slot
	state.cooldown_ticks = item_def.cooldown_ticks
	state.remaining_ticks = item_def.cooldown_ticks
	return state
