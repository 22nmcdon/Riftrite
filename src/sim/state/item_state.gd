class_name ItemState
extends RefCounted
## An item (or basic auto-attack) during a fight.
##
## Everything that depends on infusions is *derived* (see derive()): the
## item's own essences at their level's strength, plus spills from Resonant
## neighbors, fold into its effect list, conversions, stats, and numbers.
## derive() runs at fight start and again whenever an infusion in the
## holder's row levels up. Cooldown progress and Slow survive a re-derive;
## fractional carries restart.

var def: ItemDef
## Index of the owning unit in CombatSim.units (see CombatSim.owner_of).
## An index, not a reference: unit -> items -> unit would be a reference
## cycle, and Godot never frees RefCounted cycles.
var owner_index: int = -1
## First slot the item occupies; -1 for the basic auto-attack.
var slot: int
## 0 = C ... 3 = S. Always 0 for a basic auto-attack.
var tier: int = 0
## A Devourer's trace (see LegendaryDef): its own effects get +this share,
## multiplied on top like the tier.
var trace_bp: int = 0
## The basic auto-attack or an auto-attack item (ATSP speeds these up).
var is_auto_attack: bool = false
## The holder's stats, which the item's numbers scale from.
var stats: UnitStats

## The socketed essences, in socket order.
var essences: Array[EssenceDef] = []
## The named alloy for two different or matching essences, or null.
var alloy: AlloyDef = null
var infusion_xp: int = 0
var infusion_level: int = Infusions.Level.BASE
## An essence transformation active on this item (set at fight start by
## Synergies), or null. It replaces the item's own effects, uses one copy of
## its essence (the rest work as plain singles, with no alloy special), and
## stops all spill.
var transformation: SynergyDef = null
## XP and level going into the fight, for the fight result.
var start_xp: int = 0
var start_level: int = Infusions.Level.BASE

# --- derived -------------------------------------------------------------------
## The item's own effects first, then each essence application's.
var effects: Array[SourcedEffect] = []
## Essence applications that add an output kind, converting this item's output.
var conversions: Array[Conversions.Conversion] = []
## Spills this item currently receives from neighbors.
var spills_received: Array[EssenceApplication] = []
var cooldown_ticks: int
var crit_chance_bp: int
var extra_trigger_chance_bp: int = 0
## Which infusion grants the extra-trigger chance, for the log.
var extra_trigger_source: String = ""

# --- fight state -----------------------------------------------------------------
## Cooldown progress in basis points of a tick: a normal tick adds 10000, a
## slowed tick adds less, a frozen tick adds nothing. The item fires when
## progress reaches cooldown_ticks * 10000 (so it first fires one full
## cooldown in).
var progress_bp: int = 0
## Slow on this item (from Frost), or null.
var slow: StatusState = null


static func make(item_def: ItemDef, item_slot: int, holder_stats: UnitStats, content: ContentDb, item_essences: Array[EssenceDef] = [], item_tier: int = 0, xp: int = 0, trace: int = 0) -> ItemState:
	var state := ItemState.new()
	state.def = item_def
	state.slot = item_slot
	state.tier = item_tier
	state.trace_bp = trace
	state.stats = holder_stats
	state.is_auto_attack = item_def.is_basic_attack or item_def.auto_attack
	state.essences = item_essences
	if item_essences.size() == 2:
		state.alloy = content.alloy_for(item_essences[0].id, item_essences[1].id)
	state.infusion_xp = xp
	state.infusion_level = Infusions.level_for(xp, content.tuning)
	state.start_xp = xp
	state.start_level = state.infusion_level
	for i: int in item_def.effects.size():
		state.ability_triggered.append(PackedStringArray())
	state.derive(content, [], null)
	return state


## Applies an essence transformation (see `transformation`).
func transform(synergy: SynergyDef) -> void:
	transformation = synergy
	alloy = null


func has_essence(essence_id: String) -> bool:
	for essence: EssenceDef in essences:
		if essence.id == essence_id:
			return true
	return false


## The item's own effects: its def's, or its transformation's.
func own_effects() -> Array[EffectDef]:
	return transformation.item_effects if transformation != null else def.effects


## The infusion's name for the log: "Ember", "Plasma", or "Ember + Frost"
## for two essences with no named alloy yet.
func infusion_name() -> String:
	if alloy != null:
		return alloy.name
	var names: Array[String] = []
	for essence: EssenceDef in essences:
		names.append(essence.name)
	return " + ".join(names)


## This item's own infusion, at its level's strength. An alloy keeps both
## essences' normal effects (its special is applied separately).
func own_applications(tuning: TuningDef) -> Array[EssenceApplication]:
	var apps: Array[EssenceApplication] = []
	var strength: int = tuning.infusion_level_bp[infusion_level]
	var label: String = infusion_name()
	if infusion_level != Infusions.Level.BASE:
		label = "%s, %s" % [label, Infusions.LEVEL_NAMES[infusion_level]]
	var skipped: bool = false
	for essence: EssenceDef in essences:
		# The transformation uses one copy of its essence.
		if transformation != null and not skipped and essence.id == transformation.essence:
			skipped = true
			continue
		apps.append(EssenceApplication.make(essence, strength, label))
	return apps


## What this item spills to its neighbor on one side (-1 left, +1 right), if
## it's Resonant. Every spill is a share of the essence's Resonant strength:
##   single essence: that essence, both sides (spill_single_bp)
##   pure double:    the base essence, both sides (spill_pure_double_bp)
##   alloy:          first socket's essence left, second's right (spill_alloy_bp)
## An alloy's special never spills.
func spill_to(side: int, tuning: TuningDef) -> Array[EssenceApplication]:
	var apps: Array[EssenceApplication] = []
	if infusion_level != Infusions.Level.RESONANT or essences.is_empty() or transformation != null:
		return apps
	var essence: EssenceDef = essences[0]
	var share_bp: int = tuning.spill_single_bp
	if essences.size() == 2 and essences[0].id == essences[1].id:
		share_bp = tuning.spill_pure_double_bp
	elif essences.size() == 2:
		share_bp = tuning.spill_alloy_bp
		essence = essences[0] if side < 0 else essences[1]
	var strength: int = FixedMath.apply_bp(tuning.infusion_level_bp[infusion_level], share_bp)
	apps.append(EssenceApplication.make(essence, strength, "%s spill from %s" % [essence.name, def.name]))
	return apps


## The status this item actually applies in place of `status_id` (an alloy
## like Inferno turns Burn into Golden Flame).
func replaced_status(status_id: String) -> String:
	var result: String = status_id
	if alloy != null:
		result = alloy.replaces.get(status_id, status_id)
	# A specialization's replacement applies to whatever the alloy left alone.
	if result == status_id:
		result = status_replacements.get(status_id, status_id)
	return result


## True if the item applies `status_id` through its own effects, its
## infusion, or a neighbor's spill (not through relic grants). A replaced
## status counts as both: an Inferno item applies Burn and Golden Flame.
func applies_status(status_id: String) -> bool:
	var essence_list: Array[EssenceDef] = essences.duplicate()
	for spill: EssenceApplication in spills_received:
		essence_list.append(spill.essence)
	var effect_list: Array[EffectDef] = own_effects().duplicate()
	for essence: EssenceDef in essence_list:
		effect_list.append_array(essence.effects)
		if essence.adds == status_id or replaced_status(essence.adds) == status_id:
			return true
	for effect: EffectDef in effect_list:
		if effect.type == EffectDef.Type.APPLY_STATUS and (effect.status_id == status_id or replaced_status(effect.status_id) == status_id):
			return true
	return false


## Share of each heal this item echoes onto a random other ally (Bloom).
func heal_echo_bp() -> int:
	return alloy.heal_echo_bp if alloy != null else 0


## Rebuilds everything infusion- and aura-dependent from the item's own
## infusion, the spills it receives, and the auras on it (may be null).
func derive(content: ContentDb, spills: Array[EssenceApplication], aura: ItemAura) -> void:
	var tuning: TuningDef = content.tuning
	spills_received = spills
	var apps: Array[EssenceApplication] = own_applications(tuning)
	apps.append_array(spills)

	effects.clear()
	conversions.clear()
	for effect: EffectDef in own_effects():
		var own: SourcedEffect = SourcedEffect.make(effect)
		if transformation != null:
			own.transformed_by = transformation.name
		effects.append(own)
	if aura != null:
		for grant: ItemAura.Grant in aura.grants:
			var granted: SourcedEffect = SourcedEffect.make(grant.def.effect)
			granted.granted_by = grant.relic_name
			granted.partner_slots = grant.partner_slots
			granted.grant_scaled = grant.scaled
			effects.append(granted)
	var cooldown_bp: int = 0
	crit_chance_bp = def.crit_chance_bp + stats.get_stat(UnitStats.Stat.CRIT) * tuning.crit_bp_per_point
	extra_trigger_chance_bp = 0
	extra_trigger_source = ""
	for app: EssenceApplication in apps:
		if not app.essence.adds.is_empty():
			conversions.append(Conversions.make(app))
		for effect: EffectDef in app.essence.effects:
			effects.append(SourcedEffect.make(effect, app.essence.id, app.label))
		for modifier: ModifierDef in app.essence.modifiers:
			var value: int = FixedMath.apply_bp(modifier.value, app.strength_bp)
			match modifier.stat:
				ModifierDef.Stat.COOLDOWN_BP:
					cooldown_bp += value
				ModifierDef.Stat.CRIT_CHANCE_BP:
					crit_chance_bp += value
				ModifierDef.Stat.EXTRA_TRIGGER_CHANCE_BP:
					extra_trigger_chance_bp += value
					extra_trigger_source = app.label
	if aura != null:
		cooldown_bp += aura.cooldown_add_bp
		crit_chance_bp += aura.crit_add_bp
	cooldown_ticks = maxi(FixedMath.apply_bp(def.cooldown_ticks, FixedMath.BP_ONE + cooldown_bp), 1)
	crit_chance_bp = clampi(crit_chance_bp, 0, FixedMath.BP_ONE)
	status_replacements.clear()
	if aura != null:
		status_replacements.merge(aura.status_replacements)
	_compute_values(content, apps, aura)


## Works out every effect's number: base + stat scaling, times multipliers.
## A relic grant's number is flat: only side-wide aura multipliers.
## The item's own effects get the tier multiplier, a same-kind bonus from
## each essence application that adds the same output kind (+50% at full
## strength), and aura multipliers for their output kind. Essence effects get
## their application's strength.
func _compute_values(content: ContentDb, apps: Array[EssenceApplication], aura: ItemAura) -> void:
	var tuning: TuningDef = content.tuning
	for sourced: SourcedEffect in effects:
		var boosts: Array[ValueBreakdown.Multiplier] = []
		if not sourced.granted_by.is_empty():
			if aura != null:
				boosts.append_array(aura.multipliers_for(Conversions.output_kind(sourced.effect, content), not sourced.grant_scaled))
		elif sourced.infusion_id.is_empty():
			if transformation != null:
				boosts.append(ValueBreakdown.multiplier("%s, %s" % [transformation.name, Infusions.LEVEL_NAMES[infusion_level]], tuning.infusion_level_bp[infusion_level]))
			if not def.is_basic_attack:
				boosts.append(ValueBreakdown.multiplier("%s tier" % TuningDef.TIER_LABELS[tier], tuning.tier_multiplier_bp[tier]))
				if trace_bp > 0:
					boosts.append(ValueBreakdown.multiplier("devoured", FixedMath.BP_ONE + trace_bp))
			var kind: String = Conversions.output_kind(sourced.effect, content)
			for app: EssenceApplication in apps:
				if not kind.is_empty() and app.essence.adds == kind and not app.essence.adds_on_crit_only:
					boosts.append(ValueBreakdown.multiplier(app.label, FixedMath.BP_ONE + FixedMath.apply_bp(tuning.convert_same_kind_bp, app.strength_bp)))
			if aura != null:
				boosts.append_array(aura.multipliers_for(kind))
		else:
			for app: EssenceApplication in apps:
				if app.label == sourced.infusion_name:
					boosts.append(ValueBreakdown.multiplier(app.label, app.strength_bp))
					break
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


## For a specialization ability: per effect (index into def.effects), ids of
## allies that have set off its on_ally_below_hp trigger.
var ability_triggered: Array[PackedStringArray] = []
## Status replacements from the holder's specialization (see ItemAura).
var status_replacements: Dictionary[String, String] = {}


## Moves the cooldown forward by `ticks`, but never past ready: the item
## fires at its next cooldown step, and a charge can't bank a second fire.
func charge(ticks: int) -> void:
	progress_bp = mini(progress_bp + ticks * FixedMath.BP_ONE, cooldown_ticks * FixedMath.BP_ONE)


## How much slower this item's cooldown runs, in basis points (capped by the
## status's max_slow_bp).
func slow_bp() -> int:
	if slow == null:
		return 0
	return mini(slow.total_stacks() * slow.def.slow_bp_per_stack, slow.def.max_slow_bp)


## One line per effect showing base and final values, for the UI.
func describe_values() -> PackedStringArray:
	var lines := PackedStringArray()
	for sourced: SourcedEffect in effects:
		var label: String = EffectDef.TYPE_NAMES[sourced.effect.type]
		if sourced.effect.type == EffectDef.Type.APPLY_STATUS:
			label = "%s stacks" % sourced.effect.status_id
		var origin: String = "" if sourced.infusion_name.is_empty() else " [%s]" % sourced.infusion_name
		if not sourced.granted_by.is_empty():
			origin = " (%s)" % sourced.granted_by
		elif not sourced.transformed_by.is_empty():
			origin = " (%s)" % sourced.transformed_by
		lines.append("%s%s: %s" % [label, origin, sourced.value.to_text()])
	return lines
