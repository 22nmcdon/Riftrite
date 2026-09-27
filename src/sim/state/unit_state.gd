class_name UnitState
extends RefCounted
## A unit during a fight.
##
## "Standing" (hp > 0) and "alive" differ within a tick: a unit knocked to 0 HP
## stops being a target at once but stays alive, and still fires what it had
## ready, until deaths are processed at the end of the tick.

var id: String
var name: String
## A hero's class, or "" (see UnitSetup.unit_class).
var unit_class: String = ""
var side: UnitSetup.Side
var row: UnitSetup.Row
## Position within the row, 0 = leftmost.
var column: int
## Stats after the rank boost.
var base_stats: UnitStats
## Stats in effect right now: base_stats with unit-stat auras applied.
var stats: UnitStats
var max_hp: int
var hp: int
var shield: int = 0
var alive: bool = true
## Items in resolution order: the built-in basic auto-attack first (if the
## unit has no basic-attack item), then innate and specialization abilities,
## then the loadout in order.
var items: Array[ItemState] = []
## Active statuses, kept in content order (StatusState.order).
var statuses: Array[StatusState] = []
## Ticks of recent heals that weakened damage over time (see EffectRunner.heal).
var recent_heal_ticks: Array[int] = []
## What dealt the last damage, for the death log line.
var last_hit_by: String = ""
## The innate's and the specialization's aura, grant, and replace_status
## parts that apply now (by rank); CombatSim.rederive_all applies them.
var spec_parts: Array[SpecializationDef.Part] = []
## Phases (see PhaseDef) and how many have begun.
var phases: Array[PhaseDef] = []
var phases_entered: int = 0
## Ability items added by phases, by part key (so a later phase's part with
## the same key replaces it). Looked up by key only.
var phase_abilities: Dictionary[String, ItemState] = {}


static func from_setup(setup: UnitSetup, unit_side: UnitSetup.Side, unit_column: int, content: ContentDb) -> UnitState:
	var state := UnitState.new()
	state.id = setup.id
	state.name = setup.name
	state.unit_class = setup.unit_class
	state.side = unit_side
	state.row = setup.row
	state.column = unit_column
	state.base_stats = setup.stats.boosted(content.tuning.rank_multiplier_bp[setup.rank])
	state.stats = state.base_stats
	state.max_hp = state.stats.get_stat(UnitStats.Stat.HP)
	state.hp = state.max_hp
	state.phases = setup.phases
	var parts: Array[SpecializationDef.Part] = setup.innate.duplicate()
	if setup.specialization != null:
		parts.append_array(setup.specialization.parts_at(setup.rank))
	var basic_attack: ItemDef = setup.basic_attack
	var abilities: Array[ItemDef] = []
	for part: SpecializationDef.Part in parts:
		match part.kind:
			SpecializationDef.Kind.AURA, SpecializationDef.Kind.GRANT, SpecializationDef.Kind.REPLACE_STATUS:
				state.spec_parts.append(part)
			SpecializationDef.Kind.ABILITY:
				abilities.append(part.item)
			SpecializationDef.Kind.BASIC_ATTACK:
				basic_attack = part.item

	var has_auto_attack_item: bool = false
	for item: ItemSetup in setup.items:
		has_auto_attack_item = has_auto_attack_item or item.def.auto_attack
	if not has_auto_attack_item:
		state.items.append(ItemState.make(basic_attack, -1, state.stats, content))
	# Abilities: slotless, after the auto-attack and before the loadout.
	for ability: ItemDef in abilities:
		state.items.append(ItemState.make(ability, -1, state.stats, content))
	for slot: int in setup.items.size():
		var item: ItemSetup = setup.items[slot]
		var essences: Array[EssenceDef] = []
		for essence_id: String in item.essence_ids:
			essences.append(content.essences[essence_id])
		state.items.append(ItemState.make(item.def, slot, state.stats, content, essences, item.tier, item.infusion_xp, item.trace_bp))
	state.rederive_items(content)
	return state


## Re-derives every item. `auras` lines up with `items` (empty = no auras);
## CombatSim.rederive_all gathers them. (Neighbor spill is gone with item
## rows; keyword spill comes with the infusion rework.)
func rederive_items(content: ContentDb, auras: Array[ItemAura] = []) -> void:
	var none: Array[EssenceApplication] = []
	for i: int in items.size():
		var item: ItemState = items[i]
		item.stats = stats
		item.derive(content, none, auras[i] if i < auras.size() else null)


## The loadout's items (everything but the built-in basic attack and
## slotless abilities), in loadout order.
func loadout_items() -> Array[ItemState]:
	var row: Array[ItemState] = []
	for item: ItemState in items:
		if item.slot >= 0:
			row.append(item)
	return row


## DEF used against incoming hits, after shred (Bleed), never below 0.
func defense() -> int:
	var shred: int = 0
	for status: StatusState in statuses:
		shred += status.total_stacks() * status.def.defense_shred_per_stack
	return maxi(stats.get_stat(UnitStats.Stat.DEF) - shred, 0)


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


## Cooldown progress this unit's items make per tick before per-item slows
## and ATSP (10000 = normal speed, 0 = frozen).
func cooldown_rate_bp() -> int:
	return 0 if has_status_kind(StatusDef.Kind.FREEZE) else FixedMath.BP_ONE
