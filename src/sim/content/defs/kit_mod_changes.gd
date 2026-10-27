class_name KitModChanges
extends RefCounted
## What an ability change does to an ability and its effects, for KitMod.apply
## and KitMod.affects: a copy of the ability or effect list with the change's
## knobs applied (amounts, reach, areas, statuses, every, times, holders,
## copied targets, and an area's own effects), and whether a change reaches any
## effect at all. Nothing here changes the definitions it's handed; each
## returns copies (the clean-up, docs/plans/phases/cleanup-and-layout.md).

## The effects Wide copies onto more targets.
const COPIED_TYPES: Array[EffectDef.Type] = [EffectDef.Type.DAMAGE, EffectDef.Type.HEAL, EffectDef.Type.SHIELD, EffectDef.Type.APPLY_STATUS,
	EffectDef.Type.CLEANSE, EffectDef.Type.MANA_DRAIN, EffectDef.Type.KNOCKBACK, EffectDef.Type.PULL, EffectDef.Type.EXTEND_STATUS]


static func changed_ability(ability: AbilityDef, change: KitMod.AbilityChange) -> AbilityDef:
	var copy: AbilityDef = DefCopy.shallow(ability) as AbilityDef
	if change.cooldown_bp != FixedMath.BP_ONE:
		copy.cooldown_ticks = maxi(FixedMath.apply_bp(copy.cooldown_ticks, change.cooldown_bp), 1)
	if change.cast_bp != FixedMath.BP_ONE:
		copy.cast_ticks = FixedMath.apply_bp(copy.cast_ticks, change.cast_bp)
	if change.prefer != null:
		copy.prefer = change.prefer
	if change.reach_add != 0 and ability.is_signature():
		# From the unit's own reach when it has none (a melee unit's: 1).
		copy.max_range = maxi((copy.max_range if copy.max_range > 0 else 1) + change.reach_add, 1)
	if change.grip_fast_vs != null and not ability.grip_status.is_empty():
		copy.grip_fast_vs = change.grip_fast_vs
	if change.grows_add_bp != 0 and ability.grows_bp > 0:
		copy.grows_bp = maxi(ability.grows_bp + change.grows_add_bp, 0)
	if change.grows_boosts_add_bp != 0 and ability.grows_boosts_bp > 0:
		copy.grows_boosts_bp = maxi(ability.grows_boosts_bp + change.grows_boosts_add_bp, 0)
	if change.hp_cost_add_bp != 0 and ability.hp_cost_bp > 0:
		copy.hp_cost_bp = clampi(ability.hp_cost_bp + change.hp_cost_add_bp, 1, 9000)
	if change.touches_effects():
		copy.effects = changed_effects(ability.effects, change)
		# A grip's effects too (phase 8 part 4, Tightening Cord).
		if not ability.grip_effects.is_empty():
			copy.grip_effects = changed_effects(ability.grip_effects, change)
	else:
		copy.effects = copy.effects.duplicate()
	if change.targets_add > 0:
		copy.effects.append_array(extra_targets(ability, change))
	# Added effects go before the ability spends its Shield, so they still
	# read it (phase 8 part 4, Shared Ward).
	var spends: int = -1
	for i: int in copy.effects.size():
		if copy.effects[i].type == EffectDef.Type.SPEND_SHIELD:
			spends = i
			break
		# And before mana to the lowest-mana ally, so they reach the ally the
		# mana does (phase 8 part 6, Fizzing Vial).
		if copy.effects[i].type == EffectDef.Type.GAIN_MANA and copy.effects[i].target == EffectDef.Target.LOWEST_MANA_ALLY:
			spends = i
			break
	if spends < 0 or change.add_effects.is_empty():
		copy.effects.append_array(change.add_effects)
	else:
		var before: Array[EffectDef] = copy.effects.slice(0, spends)
		before.append_array(change.add_effects)
		before.append_array(copy.effects.slice(spends))
		copy.effects = before
	for effect: EffectDef in change.add_effects:
		copy.has_hit_effects = copy.has_hit_effects or effect.trigger != EffectDef.Trigger.ON_FIRE
	return copy


## Wide's extra targets (phase 5c step 6b): a copy of each of `ability`'s
## effects on its target, reaching the `targets_add` units nearest that
## target of its side (an ally for a signature that picks allies). None for
## one aimed at itself, or (`one_of`) one with an area.
static func extra_targets(ability: AbilityDef, change: KitMod.AbilityChange) -> Array[EffectDef]:
	var extra: Array[EffectDef] = []
	if ability.targeting == "self" or (change.one_of and ability.effects.any(func(effect: EffectDef) -> bool: return effect.type == EffectDef.Type.AREA)):
		return extra
	for effect: EffectDef in ability.effects:
		if effect.trigger != EffectDef.Trigger.ON_FIRE or effect.target != EffectDef.Target.TARGET or not COPIED_TYPES.has(effect.type):
			continue
		var copy: EffectDef = DefCopy.shallow(effect) as EffectDef
		copy.target = EffectDef.Target.ALLY_NEAR_TARGET if ability.targeting == "lowest_hp_ally" else EffectDef.Target.ENEMY_NEAR_TARGET
		copy.count = change.targets_add
		copy.near_range = 0
		extra.append(copy)
	return extra


static func changed_effects(effects: Array[EffectDef], change: KitMod.AbilityChange) -> Array[EffectDef]:
	var result: Array[EffectDef] = []
	for effect: EffectDef in effects:
		var copy: EffectDef = DefCopy.shallow(effect) as EffectDef
		if change.touches(effect) and change.amount_bp != FixedMath.BP_ONE and change.as_power and KitMod.POWER_TYPES.has(effect.type):
			copy.power_bp += change.amount_bp - FixedMath.BP_ONE
		elif change.touches(effect):
			copy.amount = FixedMath.apply_bp(copy.amount, change.amount_bp)
			if change.moves(effect):
				copy.hexes = FixedMath.apply_bp(copy.hexes, change.amount_bp)
			copy.amount_bp_of_damage = FixedMath.apply_bp(copy.amount_bp_of_damage, change.amount_bp)
			for stat: int in copy.scaling.size():
				copy.scaling[stat] = FixedMath.apply_bp(copy.scaling[stat], change.amount_bp)
		if change.touches(effect):
			if change.cooldown_bp != FixedMath.BP_ONE:
				if copy.interval_ticks > 0:
					copy.interval_ticks = maxi(FixedMath.apply_bp(copy.interval_ticks, change.cooldown_bp), 1)
					if copy.first_ticks > 0:
						copy.first_ticks = maxi(FixedMath.apply_bp(copy.first_ticks, change.cooldown_bp), 1)
				if copy.cooldown_ticks > 0:
					copy.cooldown_ticks = maxi(FixedMath.apply_bp(copy.cooldown_ticks, change.cooldown_bp), 1)
				if copy.cooldown_per_unit_ticks > 0:
					copy.cooldown_per_unit_ticks = maxi(FixedMath.apply_bp(copy.cooldown_per_unit_ticks, change.cooldown_bp), 1)
			if copy.duration_ticks > 0:
				copy.duration_ticks = maxi(FixedMath.apply_bp(copy.duration_ticks, change.duration_bp) + change.duration_add_ticks, 1)
			if copy.zone_ticks > 0:
				copy.zone_ticks = maxi(FixedMath.apply_bp(copy.zone_ticks, change.duration_bp) + change.duration_add_ticks, 1)
			if copy.lasts_ticks > 0:
				# A summon's lifetime too (phase 8 part 6, Long Nest).
				copy.lasts_ticks = maxi(FixedMath.apply_bp(copy.lasts_ticks, change.duration_bp) + change.duration_add_ticks, 1)
			if copy.shape != null and change.radius_add != 0:
				copy.shape = DefCopy.shallow(copy.shape) as ShapeDef
				copy.shape.size = maxi(copy.shape.size + change.radius_add, 1)
			# Phase 8 part 4's: near targets' reach, and a lowest_mana_ally's count.
			if change.within_add != 0 and effect.near_range > 0:
				copy.near_range = maxi(effect.near_range + change.within_add, HexGrid.HEX)
			if change.count_add != 0 and (effect.target == EffectDef.Target.LOWEST_MANA_ALLY or effect.target == EffectDef.Target.MOST_TARGETED_ALLY):
				copy.count = mini(effect.count + change.count_add, 5)
			# Phase 8 part 6 (Ilse's cards): on_status_tick's reach (Fan the
			# Coals), allies_near_self's nearest (Shared Blessing), a stacks_of
			# share (Deep Stoke), and a growing zone (Fast and Far Spread).
			if change.within_add != 0 and effect.trigger == EffectDef.Trigger.ON_STATUS_TICK and effect.near_trigger_range > 0:
				copy.near_trigger_range = maxi(effect.near_trigger_range + change.within_add, HexGrid.HEX)
			if change.within_add != 0 and effect.fell_range > 0:
				# on_enemy_fell's reach (phase 8 part 6, Wider Pickings).
				copy.fell_range = maxi(effect.fell_range + change.within_add, HexGrid.HEX)
			if change.count_add != 0 and effect.nearest > 0:
				copy.nearest = mini(effect.nearest + change.count_add, 5)
			if change.share_add_bp != 0 and effect.stacks_share_bp > 0:
				copy.stacks_share_bp = clampi(effect.stacks_share_bp + change.share_add_bp, 1, FixedMath.BP_ONE)
			if change.share_add_bp != 0 and effect.copy_of != EffectDef.CopyOf.NONE:
				copy.copy_share_bp = clampi(effect.copy_share_bp + change.share_add_bp, 100, FixedMath.BP_ONE)
			if change.copy_grow_add_bp != 0 and effect.copy_grows_bp > 0:
				copy.copy_grows_bp = maxi(effect.copy_grows_bp + change.copy_grow_add_bp, 0)
			if change.grow_every_add_ticks != 0 and effect.grow_ticks > 0:
				copy.grow_ticks = maxi(effect.grow_ticks + change.grow_every_add_ticks, 1)
			if change.grow_max_add != 0 and effect.grow_ticks > 0:
				copy.grow_max = maxi(effect.grow_max + change.grow_max_add, effect.shape.size + 1)
			if change.heal_cap_bp != 0 and effect.type == EffectDef.Type.HEAL:
				copy.heal_cap_bp = change.heal_cap_bp
				copy.heal_cap_vs = change.heal_cap_vs
			# Phase 8 part 6 (Heavy Flask): more for each stack.
			if change.per_stack_amount_add != 0 and effect.amount_per_stack > 0:
				copy.amount_per_stack = maxi(effect.amount_per_stack + change.per_stack_amount_add, 1)
			# Step 7b's knobs.
			if change.every_add != 0 and effect.every > 1:
				copy.every = maxi(effect.every + change.every_add, 1)
			if change.times_add != 0 and _runs_times(effect):
				copy.times = effect.times + change.times_add
			if change.max_standing_add != 0 and effect.max_standing > 0:
				copy.max_standing = effect.max_standing + change.max_standing_add
			# The apex cards' knobs (phase 8 part 2).
			if change.width_add != 0 and effect.type == EffectDef.Type.WALL:
				copy.width_range = effect.width_range + change.width_add * HexGrid.HEX
			if change.per_enemy_add_bp != 0 and effect.per_enemy_bp > 0:
				copy.per_enemy_bp = maxi(effect.per_enemy_bp + change.per_enemy_add_bp, 0)
			if change.overheal_max_hp_add != 0 and effect.overheal_max_hp_per > 0:
				copy.overheal_max_hp_per = maxi(effect.overheal_max_hp_per + change.overheal_max_hp_add, 1)
			if change.at_stacks_add != 0 and effect.at_stacks > 0:
				copy.at_stacks = maxi(effect.at_stacks + change.at_stacks_add, 2)
			if change.per_taken_add_bp != 0 and effect.power_per_taken_bp > 0:
				copy.power_per_taken_bp = maxi(effect.power_per_taken_bp + change.per_taken_add_bp, 0)
			if change.overheal_add_bp != 0 and effect.overheal_shield_bp > 0:
				copy.overheal_shield_bp = effect.overheal_shield_bp + change.overheal_add_bp
			if change.strength_add_bp != 0 and effect.type == EffectDef.Type.APPLY_STATUS:
				copy.strength_add_bp = effect.strength_add_bp + change.strength_add_bp
			if change.follows and effect.zone_ticks > 0:
				copy.follows = true
			if change.ricochet_add != 0 and effect.type == EffectDef.Type.DAMAGE:
				copy.ricochet = effect.ricochet + change.ricochet_add
			if change.reflect_bp != 0 and effect.type == EffectDef.Type.WALL:
				copy.reflect_bp = effect.reflect_bp + change.reflect_bp
			if change.snags and effect.type == EffectDef.Type.SNARE:
				copy.snags = true
			if change.holder != null and _takes_holder(effect):
				copy.holder = change.holder
			if change.carries and effect.type == EffectDef.Type.CHARGE and effect.knockback_hexes > 0:
				copy.carries = true
			if change.ignores_def and effect.type == EffectDef.Type.DAMAGE:
				copy.ignores_def = true
			if change.lifesteal_add_bp != 0 and effect.lifesteal_bp > 0:
				copy.lifesteal_bp = maxi(effect.lifesteal_bp + change.lifesteal_add_bp, 0)
			if change.plus_max_hp_add_bp != 0 and effect.plus_bp_of_max_hp > 0:
				copy.plus_bp_of_max_hp = maxi(effect.plus_bp_of_max_hp + change.plus_max_hp_add_bp, 0)
			if change.raise_grow_add_bp != 0 and effect.type == EffectDef.Type.RAISE:
				copy.raise_grow_hp_bp = maxi(effect.raise_grow_hp_bp + change.raise_grow_add_bp, 0)
			if change.follows_holder and effect.zone_ticks > 0:
				copy.follows = true
				copy.follows_nearest = false
				copy.follows_holder = true
			if change.per_stack_add_bp != 0 and not effect.grows_status.is_empty():
				copy.grows_stack_bp = maxi(effect.grows_stack_bp + change.per_stack_add_bp, 0)
			if change.prefer != null and (effect.target == EffectDef.Target.FARTHEST_ENEMIES or effect.target == EffectDef.Target.LOWEST_HP_ALLY):
				copy.prefer = change.prefer
			if change.width_add != 0 and copy.shape != null and copy.shape.kind == ShapeDef.Kind.LINE:
				copy.shape = DefCopy.shallow(copy.shape) as ShapeDef
				copy.shape.width += change.width_add
		if not effect.area_effects.is_empty():
			copy.area_effects = changed_effects(effect.area_effects, change)
		if not change.add_to_areas.is_empty() and effect.type == EffectDef.Type.AREA and change.touches(effect):
			copy.area_effects = copy.area_effects.duplicate()
			copy.area_effects.append_array(change.add_to_areas)
		result.append(copy)
	return result


## An effect that can take a holder condition: an event's or a timed one.
static func _takes_holder(effect: EffectDef) -> bool:
	return EffectDef.EVENT_TRIGGERS.has(effect.trigger) or EffectDef.UNIT_TRIGGERS.has(effect.trigger)


## A "once" effect, or on_below_hp's: it runs `times` a fight (times_add).
static func _runs_times(effect: EffectDef) -> bool:
	return effect.once or effect.trigger == EffectDef.Trigger.ON_BELOW_HP


static func any_effect(effects: Array[EffectDef], change: KitMod.AbilityChange) -> bool:
	for effect: EffectDef in effects:
		if change.touches(effect) and (change.every_add != 0 and effect.every > 1 or change.times_add != 0 and _runs_times(effect)
				or change.within_add != 0 and effect.near_range > 0 or change.count_add != 0 and (effect.target == EffectDef.Target.LOWEST_MANA_ALLY or effect.target == EffectDef.Target.MOST_TARGETED_ALLY)
				or change.within_add != 0 and effect.trigger == EffectDef.Trigger.ON_STATUS_TICK and effect.near_trigger_range > 0
				or change.within_add != 0 and effect.fell_range > 0
				or change.count_add != 0 and effect.nearest > 0 or change.share_add_bp != 0 and (effect.stacks_share_bp > 0 or effect.copy_of != EffectDef.CopyOf.NONE)
				or change.copy_grow_add_bp != 0 and effect.copy_grows_bp > 0
				or (change.grow_every_add_ticks != 0 or change.grow_max_add != 0) and effect.grow_ticks > 0
				or change.heal_cap_bp != 0 and effect.type == EffectDef.Type.HEAL
				or change.per_stack_amount_add != 0 and effect.amount_per_stack > 0
				or change.max_standing_add != 0 and effect.max_standing > 0
				or change.overheal_add_bp != 0 and effect.overheal_shield_bp > 0
				or change.width_add != 0 and effect.type == EffectDef.Type.WALL
				or change.per_enemy_add_bp != 0 and effect.per_enemy_bp > 0
				or change.overheal_max_hp_add != 0 and effect.overheal_max_hp_per > 0
				or change.at_stacks_add != 0 and effect.at_stacks > 0
				or change.per_taken_add_bp != 0 and effect.power_per_taken_bp > 0
				or change.width_add != 0 and effect.shape != null and effect.shape.kind == ShapeDef.Kind.LINE
				or not change.add_to_areas.is_empty() and effect.type == EffectDef.Type.AREA
				or change.strength_add_bp != 0 and effect.type == EffectDef.Type.APPLY_STATUS
				or change.follows and effect.zone_ticks > 0 or change.ricochet_add != 0 and effect.type == EffectDef.Type.DAMAGE
				or change.reflect_bp != 0 and effect.type == EffectDef.Type.WALL or change.snags and effect.type == EffectDef.Type.SNARE
				or change.holder != null and _takes_holder(effect)
				or change.carries and effect.type == EffectDef.Type.CHARGE and effect.knockback_hexes > 0 and not effect.carries
				or change.ignores_def and effect.type == EffectDef.Type.DAMAGE and not effect.ignores_def
				or change.lifesteal_add_bp != 0 and effect.lifesteal_bp > 0
				or change.plus_max_hp_add_bp != 0 and effect.plus_bp_of_max_hp > 0
				or change.raise_grow_add_bp != 0 and effect.type == EffectDef.Type.RAISE
				or change.follows_holder and effect.zone_ticks > 0 and not effect.follows_holder
				or change.per_stack_add_bp != 0 and not effect.grows_status.is_empty()
				or change.prefer != null and (effect.target == EffectDef.Target.FARTHEST_ENEMIES or effect.target == EffectDef.Target.LOWEST_HP_ALLY)):
			return true
		if change.touches(effect) and (change.amount_bp != FixedMath.BP_ONE and (effect.amount != 0 or effect.amount_bp_of_damage != 0 or effect.scaling.any(func(value: int) -> bool: return value != 0) or effect.amount_bp_of_max_hp != 0 or change.moves(effect))
				or (change.duration_bp != FixedMath.BP_ONE or change.duration_add_ticks != 0) and (effect.duration_ticks > 0 or effect.zone_ticks > 0 or effect.lasts_ticks > 0)
				or change.radius_add != 0 and effect.shape != null):
			return true
		if any_effect(effect.area_effects, change):
			return true
	return false
