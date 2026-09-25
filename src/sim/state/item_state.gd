class_name ItemState
extends RefCounted
## An item (or basic auto-attack) during a fight, with its infusions already
## folded in: essence effects are added to its effect list, essence
## modifiers are applied to its stats, and every effect's number is computed
## from the holder's stats and the item's multipliers (see ValueBreakdown).

var def: ItemDef
## Index of the owning unit in CombatSim.units (see CombatSim.owner_of).
## An index, not a reference: unit -> items -> unit would be a reference
## cycle, and Godot never frees RefCounted cycles.
var owner_index: int = -1
## First slot the item occupies; -1 for the basic auto-attack.
var slot: int
## 0 = C ... 3 = S. Always 0 for a basic auto-attack.
var tier: int = 0
## The basic auto-attack or an auto-attack item (ATSP speeds these up).
var is_auto_attack: bool = false
## The item's own effects first, then each socketed essence's.
var effects: Array[SourcedEffect] = []
var cooldown_ticks: int
var crit_chance_bp: int
var extra_trigger_chance_bp: int = 0
## Which infusion grants the extra-trigger chance, for the log.
var extra_trigger_source: String = ""
## Cooldown progress in basis points of a tick: a normal tick adds 10000, a
## slowed tick adds less, a frozen tick adds nothing. The item fires when
## progress reaches cooldown_ticks * 10000 (so it first fires one full
## cooldown in).
var progress_bp: int = 0


static func make(item_def: ItemDef, item_slot: int, stats: UnitStats, tuning: TuningDef, essences: Array[EssenceDef] = [], item_tier: int = 0) -> ItemState:
	var state := ItemState.new()
	state.def = item_def
	state.slot = item_slot
	state.tier = item_tier
	state.is_auto_attack = item_def.is_basic_attack or item_def.auto_attack
	for effect: EffectDef in item_def.effects:
		state.effects.append(SourcedEffect.make(effect))

	var cooldown_bp: int = 0
	state.crit_chance_bp = item_def.crit_chance_bp + stats.get_stat(UnitStats.Stat.CRIT) * tuning.crit_bp_per_point
	for essence: EssenceDef in essences:
		for effect: EffectDef in essence.effects:
			state.effects.append(SourcedEffect.make(effect, essence.id, essence.name))
		for modifier: ModifierDef in essence.modifiers:
			match modifier.stat:
				ModifierDef.Stat.COOLDOWN_BP:
					cooldown_bp += modifier.value
				ModifierDef.Stat.CRIT_CHANCE_BP:
					state.crit_chance_bp += modifier.value
				ModifierDef.Stat.EXTRA_TRIGGER_CHANCE_BP:
					state.extra_trigger_chance_bp += modifier.value
					state.extra_trigger_source = essence.name
	state.cooldown_ticks = maxi(FixedMath.apply_bp(item_def.cooldown_ticks, FixedMath.BP_ONE + cooldown_bp), 1)
	state.crit_chance_bp = clampi(state.crit_chance_bp, 0, FixedMath.BP_ONE)
	state._compute_values(stats, tuning)
	return state


## Works out every effect's number: base + stat scaling, times the item's
## multipliers. The item's own effects get the tier multiplier; essence
## effects are flat.
func _compute_values(stats: UnitStats, tuning: TuningDef) -> void:
	var tier_boost: Array[ValueBreakdown.Multiplier] = []
	if not def.is_basic_attack:
		tier_boost.append(ValueBreakdown.multiplier("%s tier" % TuningDef.TIER_LABELS[tier], tuning.tier_multiplier_bp[tier]))
	for sourced: SourcedEffect in effects:
		var boosts: Array[ValueBreakdown.Multiplier] = []
		if sourced.infusion_id.is_empty():
			boosts = tier_boost
		sourced.value = ValueBreakdown.compute(sourced.effect.base_value(), sourced.effect.scaling, stats, boosts)


## Advances the cooldown by `rate_bp` (10000 = one normal tick). Returns true
## if the item fires this tick.
func advance(rate_bp: int) -> bool:
	progress_bp += rate_bp
	var needed: int = cooldown_ticks * FixedMath.BP_ONE
	if progress_bp < needed:
		return false
	progress_bp -= needed
	return true


## One line per effect showing base and final values, for the UI.
func describe_values() -> PackedStringArray:
	var lines := PackedStringArray()
	for sourced: SourcedEffect in effects:
		var label: String = EffectDef.TYPE_NAMES[sourced.effect.type]
		if sourced.effect.type == EffectDef.Type.APPLY_STATUS:
			label = "%s stacks" % sourced.effect.status_id
		var origin: String = "" if sourced.infusion_name.is_empty() else " [%s]" % sourced.infusion_name
		lines.append("%s%s: %s" % [label, origin, sourced.value.to_text()])
	return lines
