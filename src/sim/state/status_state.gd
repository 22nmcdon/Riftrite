class_name StatusState
extends RefCounted
## One status on one unit. Stacks are kept in groups by source, oldest first,
## so damage over time is credited to whoever applied each stack, and stacks
## are lost (or capped) oldest first.


class StackGroup:
	var source: EffectSource
	var stacks: int


var def: StatusDef
## Position in ContentDb.status_ids; a unit's statuses are kept in this order
## so they always tick in the same order.
var order: int
var groups: Array[StackGroup] = []
## Ticks left before the status ends (0 = no timer).
var timer_ticks: int = 0
## Damage over time: ticks until the next damage tick.
var interval_left: int = 0


func total_stacks() -> int:
	var total: int = 0
	for group: StackGroup in groups:
		total += group.stacks
	return total


func add_stacks(source: EffectSource, count: int) -> void:
	if not groups.is_empty() and groups[-1].source.same_as(source):
		groups[-1].stacks += count
		return
	var group := StackGroup.new()
	group.source = source
	group.stacks = count
	groups.append(group)


## Removes up to `count` stacks, oldest first.
func remove_oldest(count: int) -> void:
	var left: int = count
	while left > 0 and not groups.is_empty():
		var taken: int = mini(left, groups[0].stacks)
		groups[0].stacks -= taken
		left -= taken
		if groups[0].stacks == 0:
			groups.remove_at(0)
