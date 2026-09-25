class_name UnitState
extends RefCounted
## A unit during a fight.
##
## "Standing" (hp > 0) and "alive" differ within a tick: a unit knocked to 0 HP
## stops being a target at once but stays alive, and still fires what it had
## ready, until deaths are processed at the end of the tick.

var id: String
var name: String
var side: UnitSetup.Side
var row: UnitSetup.Row
## Position within the row, 0 = leftmost.
var column: int
var max_hp: int
var hp: int
var shield: int = 0
var alive: bool = true
## Items that fire, in resolution order: the basic auto-attack first (if the
## unit has no auto-attack item), then row items left to right.
var items: Array[ItemState] = []
## Who dealt the last damage, for the death log line.
var last_hit_by_unit: String = ""
var last_hit_by_item: String = ""


static func from_setup(setup: UnitSetup, unit_side: UnitSetup.Side, unit_column: int) -> UnitState:
	var state := UnitState.new()
	state.id = setup.id
	state.name = setup.name
	state.side = unit_side
	state.row = setup.row
	state.column = unit_column
	state.max_hp = setup.max_hp
	state.hp = setup.max_hp

	var has_auto_attack_item: bool = false
	for item: ItemDef in setup.items:
		has_auto_attack_item = has_auto_attack_item or item.auto_attack
	if not has_auto_attack_item:
		state.items.append(ItemState.make(setup.basic_attack, -1))
	var slot: int = 0
	for item: ItemDef in setup.items:
		state.items.append(ItemState.make(item, slot))
		slot += item.size
	return state


func is_standing() -> bool:
	return alive and hp > 0
