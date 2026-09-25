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
## Stats after the rank boost.
var stats: UnitStats
var max_hp: int
var hp: int
var shield: int = 0
var alive: bool = true
## Items that fire, in resolution order: the basic auto-attack first (if the
## unit has no auto-attack item), then row items left to right.
var items: Array[ItemState] = []
## Active statuses, kept in content order (StatusState.order).
var statuses: Array[StatusState] = []
## What dealt the last damage, for the death log line.
var last_hit_by: String = ""


static func from_setup(setup: UnitSetup, unit_side: UnitSetup.Side, unit_column: int, content: ContentDb) -> UnitState:
	var state := UnitState.new()
	state.id = setup.id
	state.name = setup.name
	state.side = unit_side
	state.row = setup.row
	state.column = unit_column
	state.stats = setup.stats.boosted(content.tuning.rank_multiplier_bp[setup.rank])
	state.max_hp = state.stats.get_stat(UnitStats.Stat.HP)
	state.hp = state.max_hp

	var has_auto_attack_item: bool = false
	for item: ItemSetup in setup.items:
		has_auto_attack_item = has_auto_attack_item or item.def.auto_attack
	if not has_auto_attack_item:
		state.items.append(ItemState.make(setup.basic_attack, -1, state.stats, content.tuning))
	var slot: int = 0
	for item: ItemSetup in setup.items:
		var essences: Array[EssenceDef] = []
		for essence_id: String in item.essence_ids:
			essences.append(content.essences[essence_id])
		state.items.append(ItemState.make(item.def, slot, state.stats, content.tuning, essences, item.tier))
		slot += item.def.size
	return state


## DEF used against incoming hits.
func defense() -> int:
	return maxi(stats.get_stat(UnitStats.Stat.DEF), 0)


func is_standing() -> bool:
	return alive and hp > 0


func find_status(status_id: String) -> StatusState:
	for status: StatusState in statuses:
		if status.def.id == status_id:
			return status
	return null


func has_status_kind(kind: StatusDef.Kind) -> bool:
	for status: StatusState in statuses:
		if status.def.kind == kind:
			return true
	return false


## How much slower this unit's cooldowns run, in basis points (max 100%).
func slow_bp() -> int:
	var total: int = 0
	for status: StatusState in statuses:
		if status.def.kind == StatusDef.Kind.SLOW:
			total += status.total_stacks() * status.def.slow_bp_per_stack
	return mini(total, FixedMath.BP_ONE)


## Cooldown progress this unit's items make per tick (10000 = normal speed).
func cooldown_rate_bp() -> int:
	if has_status_kind(StatusDef.Kind.FREEZE):
		return 0
	return FixedMath.BP_ONE - slow_bp()
