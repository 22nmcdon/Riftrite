class_name StatusState
extends RefCounted
## One status on one unit. Damage over time keeps its stacks in groups by
## source, oldest first, so each stack's damage is credited to whoever put it
## there, and stacks are lost (or capped) oldest first. A timed status keeps
## who put it there last and the tick it ends on.


class StackGroup:
	var source: EffectSource
	var stacks: int


var def: StatusDef
## Position in ContentDb.status_ids; a unit's statuses are kept in this order
## so they always tick in the same order.
var order: int
var groups: Array[StackGroup] = []
## Damage over time: ticks until the next damage tick.
var interval_left: int = 0
## Timed: who applied it last (for Taunt, the taunter) and the tick it ends.
var source: EffectSource = null
var ends_at: int = 0
## A stacking boost (phase 5c step 5c): each stack's last tick (NEVER: the
## fight's end), oldest first.
var stack_ends: Array[int] = []
## A timed status that stacks (Marks under Hunter's Engine, phase 5c step
## 5c): its stacks, all ending at ends_at.
var stacks: int = 1

const NEVER: int = 1 << 60


## A timed status's stacks: a stacking boost's count, or `stacks`.
func timed_stacks() -> int:
	return stack_ends.size() if def.stacking else stacks


func total_stacks() -> int:
	var total: int = 0
	for group: StackGroup in groups:
		total += group.stacks
	return total


func add_stacks(from: EffectSource, count: int) -> void:
	if not groups.is_empty() and groups[-1].source.same_as(from):
		groups[-1].stacks += count
		return
	var group := StackGroup.new()
	group.source = from
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
