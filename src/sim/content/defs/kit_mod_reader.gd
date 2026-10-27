class_name KitModReader
extends RefCounted
## Reads a KitMod from its JSON entry and checks it (KitMod's header has every
## key and what it does): the stats, mana, passives, extra triggers, Echo,
## companions, gambits, and each ability change. KitMod.read is the way in;
## this file is its body (the clean-up, docs/plans/phases/cleanup-and-layout.md).


static func read(reader: DataReader) -> KitMod:
	var mod: KitMod = KitMod.make()
	if reader.has("stats_bp"):
		var bp_reader: DataReader = reader.req_object("stats_bp")
		if bp_reader != null:
			for stat: UnitStats.Stat in KitPatch.BP_STATS:
				mod.stats_bp[stat] = bp_reader.opt_int(UnitStats.STAT_NAMES[stat], FixedMath.BP_ONE, 1000, 50000)
			bp_reader.finish()
	if reader.has("stats_add"):
		var add_reader: DataReader = reader.req_object("stats_add")
		if add_reader != null:
			for stat: UnitStats.Stat in KitMod.ADD_STATS:
				mod.stats_add[stat] = add_reader.opt_int(UnitStats.STAT_NAMES[stat], 0, -100, 1000)
			add_reader.finish()
	for part_reader: DataReader in reader.opt_object_array("passives"):
		mod.passives.append(PartDef.read(part_reader))
	for change_reader: DataReader in reader.opt_object_array("on"):
		mod.changes.append(_read_change(change_reader))
	if reader.has("mana"):
		var mana_reader: DataReader = reader.req_object("mana")
		if mana_reader != null:
			mod.mana_max_add = mana_reader.opt_int("max_add", 0, -100, 100)
			mod.mana_start_add = mana_reader.opt_int("start_add", 0, -100, 100)
			mod.mana_per_attack_add = mana_reader.opt_int("per_attack_add", 0, -20, 20)
			mod.mana_regen_add = mana_reader.opt_int("regen_add", 0, -20, 20)
			mod.mana_max_bp = mana_reader.opt_int("max_bp", FixedMath.BP_ONE, 5000, 20000)
			mod.mana_start_bp = mana_reader.opt_int("start_bp", 0, 0, FixedMath.BP_ONE)
			mod.mana_taken_bp = mana_reader.opt_int("taken_bp", FixedMath.BP_ONE, 1000, 50000)
			mana_reader.finish()
	mod.plant_add_ticks = _signed_ticks(reader, "plant_add_ms")
	mod.shard_cap_add = reader.opt_int("shard_cap_add", 0, -100, 100)
	for companion_reader: DataReader in reader.opt_object_array("companions"):
		var change := KitMod.CompanionChange.new()
		change.kit_id = companion_reader.opt_string("kit", "")
		change.hp_add_bp = companion_reader.opt_int("hp_add_pct", 0, -100, 100) * 100
		change.atk_add_bp = companion_reader.opt_int("atk_add_pct", 0, -100, 100) * 100
		change.return_add_ticks = _signed_ticks(companion_reader, "return_add_ms")
		if companion_reader.has("mod"):
			var inner: DataReader = companion_reader.req_object("mod")
			change.mod = read(inner) if inner != null else null
		if change.hp_add_bp == 0 and change.atk_add_bp == 0 and change.return_add_ticks == 0 and change.mod == null:
			companion_reader.error("a companion change needs hp_add_pct, atk_add_pct, return_add_ms, or a mod")
		companion_reader.finish()
		mod.companion_changes.append(change)
	mod.places_lantern = reader.opt_bool("places_lantern", false)
	mod.drops_signature = reader.opt_bool("drops_signature", false)
	if reader.has("drops_passives"):
		mod.drops_passives = reader.req_string_array("drops_passives")
	if reader.has("engage"):
		var engage_reader: DataReader = reader.req_object("engage")
		if engage_reader != null:
			mod.break_free_add_ticks = _signed_ticks(engage_reader, "break_free_add_ms")
			mod.engage_reach_add = engage_reader.opt_int("reach_add", 0, 0, 3) * HexGrid.HEX
			engage_reader.finish()
	if reader.has("prefer"):
		var prefer_reader: DataReader = reader.req_object("prefer")
		if prefer_reader != null:
			mod.prefer_label = prefer_reader.req_string("label")
			mod.prefer = UnitCondition.read(prefer_reader.req_object("vs"))
			mod.prefer_reach = prefer_reader.opt_int("within_hexes", 0, 0, 20) * HexGrid.HEX
			prefer_reader.finish()
	if reader.has("gambit"):
		var gambit: DataReader = reader.req_object("gambit")
		if gambit != null:
			mod.gambit_label = gambit.req_string("label")
			mod.place_rule = gambit.opt_string_choice("place", "", Gambits.PLACES)
			mod.arrive_ticks = gambit.opt_ticks("arrive_ms", 0)
			mod.arrive_at = gambit.opt_string_choice("arrive_at", "", Gambits.ARRIVE_AT)
			if not mod.arrive_at.is_empty() and mod.arrive_ticks == 0:
				gambit.error("arrive_at needs arrive_ms")
			mod.swap_ticks = gambit.opt_ticks("swap_ms", 0)
			mod.swap_shield_bp = gambit.opt_int("swap_shield_bp", 0, 0, FixedMath.BP_ONE)
			mod.swap_choice = gambit.opt_bool("swap_choice", false)
			gambit.finish()
	if reader.has("hop"):
		var hop_reader: DataReader = reader.req_object("hop")
		if hop_reader != null:
			mod.hop_within_add = hop_reader.opt_int("within_add", 0, 0, 2 * HexGrid.HEX)
			mod.hop_cooldown_add_ticks = _signed_ticks(hop_reader, "cooldown_add_ms")
			hop_reader.finish()
	for trigger_reader: DataReader in reader.opt_object_array("also_fires"):
		var trigger: TriggerDef = TriggerDef.read(trigger_reader)
		if not TriggerDef.ALSO_KINDS.has(trigger.kind):
			reader.error("also_fires: a signature can also fire on hp_below, ally_falls, or every, not %s" % TriggerDef.KIND_NAMES[trigger.kind])
		mod.also_fires.append(trigger)
	if reader.has("echo"):
		var echo_reader: DataReader = reader.req_object("echo")
		if echo_reader != null:
			mod.echo_ticks = echo_reader.req_ticks("after_ms", FixedMath.MS_PER_TICK)
			mod.echo_bp = echo_reader.req_int("share_pct", 1, 100) * 100
			echo_reader.finish()
	if not mod.changes_anything():
		reader.error("a mod needs stats_bp, stats_add, passives, on, mana, also_fires, or echo")
	reader.finish()
	return mod


static func _read_change(reader: DataReader) -> KitMod.AbilityChange:
	var change := KitMod.AbilityChange.new()
	change.slot = reader.req_string("slot")
	if not change.slot in [KitMod.SLOT_BASIC, KitMod.SLOT_SIGNATURE, KitMod.SLOT_ABILITIES] and not change.slot.begins_with(KitMod.PASSIVE_PREFIX):
		reader.error("slot: expected basic_attack, signature, abilities, or passive:<id>, got \"%s\"" % change.slot)
	if reader.has("types"):
		for type_name: String in reader.opt_choice_array("types", EffectDef.TYPE_NAMES):
			change.types.append(EffectDef.TYPE_NAMES.find(type_name) as EffectDef.Type)
	if reader.has("statuses"):
		change.statuses = reader.req_string_array("statuses")
		if change.statuses.is_empty():
			reader.error("statuses: name at least one")
		if not change.types.is_empty():
			reader.error("an \"on\" entry takes types or statuses, not both")
	change.amount_bp = reader.opt_int("amount_bp", FixedMath.BP_ONE, 1000, 50000)
	change.duration_bp = reader.opt_int("duration_bp", FixedMath.BP_ONE, 1000, 50000)
	change.duration_add_ticks = _signed_ticks(reader, "duration_add_ms")
	change.radius_add = reader.opt_int("radius_add", 0, -3, 3)
	change.cooldown_bp = reader.opt_int("cooldown_bp", FixedMath.BP_ONE, 1000, 50000)
	for effect_reader: DataReader in reader.opt_object_array("add_effects"):
		change.add_effects.append(EffectDef.read(effect_reader))
	change.after_add_ticks = _signed_ticks(reader, "after_add_ms")
	change.cast_bp = reader.opt_int("cast_bp", FixedMath.BP_ONE, 0, FixedMath.BP_ONE)
	change.targets_add = reader.opt_int("targets_add", 0, 0, 5)
	change.one_of = reader.opt_bool("one_of", false)
	for target_name: String in reader.opt_choice_array("at", EffectDef.TARGET_NAMES):
		change.at.append(EffectDef.TARGET_NAMES.find(target_name) as EffectDef.Target)
	change.every_add = reader.opt_int("every_add", 0, -10, 10)
	change.times_add = reader.opt_int("times_add", 0, 0, 5)
	change.max_standing_add = reader.opt_int("max_standing_add", 0, 0, 5)
	change.overheal_add_bp = reader.opt_int("overheal_shield_add_bp", 0, 0, FixedMath.BP_ONE)
	change.width_add = reader.opt_int("width_add", 0, 0, 3)
	for effect_reader: DataReader in reader.opt_object_array("add_to_areas"):
		change.add_to_areas.append(EffectDef.read(effect_reader, false, true))
	change.value_add = reader.opt_int("value_add", 0, -100000, 100000)
	change.strength_add_bp = reader.opt_int("strength_add_bp", 0, 0, FixedMath.BP_ONE)
	var follow_rule: String = reader.opt_string_choice("follows", "", ["largest_group", "holder"])
	change.follows = follow_rule == "largest_group"
	change.follows_holder = follow_rule == "holder"
	change.ricochet_add = reader.opt_int("ricochet_add", 0, 0, 5)
	change.reflect_bp = reader.opt_int("reflect_bp", 0, 0, FixedMath.BP_ONE)
	change.snags = reader.opt_bool("snags", false)
	change.per_enemy_add_bp = reader.opt_int("per_enemy_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.overheal_max_hp_add = reader.opt_int("overheal_max_hp_add", 0, -100, 100)
	change.at_stacks_add = reader.opt_int("at_stacks_add", 0, -10, 10)
	change.per_taken_add_bp = reader.opt_int("per_taken_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.grows_add_bp = reader.opt_int("grows_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.grows_boosts_add_bp = reader.opt_int("grows_boosts_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.rise_add_bp = reader.opt_int("rise_add_pct", 0, -99, 99) * 100
	change.per_shared_bp = reader.opt_int("per_shared_bp", FixedMath.BP_ONE, 1000, 50000)
	if (change.grows_add_bp != 0 or change.grows_boosts_add_bp != 0) and change.slot != KitMod.SLOT_SIGNATURE:
		reader.error("grows_add_bp and grows_boosts_add_bp change a signature (\"slot\": \"signature\")")
	if reader.has("guard"):
		var guard: DataReader = reader.req_object("guard")
		if guard != null:
			change.guard_share_add = guard.opt_int("share_add", 0, -100, 100) * 100
			change.guard_within_add = guard.opt_int("within_add", 0, -3, 3) * HexGrid.HEX
			change.guard_covers_all = guard.opt_bool("covers_all", false)
			guard.finish()
	if reader.has("prefer"):
		change.prefer = UnitCondition.read(reader.req_object("prefer"))
	if reader.has("holder"):
		change.holder = UnitCondition.read(reader.req_object("holder"))
	change.carries = reader.opt_bool("carries", false)
	change.ability_id = reader.opt_string("ability", "")
	change.mana_max_add = reader.opt_int("mana_max_add", 0, -100, 100)
	change.ignores_def = reader.opt_bool("ignores_def", false)
	change.lifesteal_add_bp = reader.opt_int("lifesteal_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.plus_max_hp_add_bp = reader.opt_int("plus_max_hp_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.raise_grow_add_bp = reader.opt_int("raise_grow_add_pct", 0, -100, 100) * 100
	change.hp_cost_add_bp = reader.opt_int("hp_cost_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.per_stack_add_bp = reader.opt_int("per_stack_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	if reader.has("per_twice"):
		change.per_twice = UnitCondition.read(reader.req_object("per_twice"))
	change.reach_add = reader.opt_int("reach_add", 0, -3, 9)
	change.within_add = reader.opt_int("within_add", 0, -3, 3) * HexGrid.HEX
	change.count_add = reader.opt_int("count_add", 0, 0, 4)
	change.share_add_bp = reader.opt_int("share_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.copy_grow_add_bp = reader.opt_int("per_copy_add_pct", 0, -100, 100) * 100
	change.grow_every_add_ticks = reader.opt_ticks("grow_every_add_ms", 0, -10000)
	change.grow_max_add = reader.opt_int("grow_max_add", 0, -3, 3)
	change.per_stacks_add = reader.opt_int("per_stacks_add", 0, -10, 10)
	change.cap_add_bp = reader.opt_int("cap_add_bp", 0, -FixedMath.BP_ONE, FixedMath.BP_ONE)
	change.per_stack_amount_add = reader.opt_int("per_stack_amount_add", 0, -10, 10)
	change.per_shards_add = reader.opt_int("per_shards_add", 0, -20, 20)
	change.per_shards_max_add = reader.opt_int("per_shards_max_add", 0, -20, 50)
	if reader.has("heal_cap"):
		var cap: DataReader = reader.req_object("heal_cap")
		if cap != null:
			change.heal_cap_bp = cap.req_int("pct", 1, 99) * 100
			if cap.has("vs"):
				change.heal_cap_vs = UnitCondition.read(cap.req_object("vs"))
			cap.finish()
	if reader.has("grip_fast_vs"):
		change.grip_fast_vs = UnitCondition.read(reader.req_object("grip_fast_vs"))
	if (change.reach_add != 0 or change.grip_fast_vs != null) and change.slot != KitMod.SLOT_SIGNATURE and change.ability_id.is_empty():
		reader.error("reach_add and grip_fast_vs change a signature (\"slot\": \"signature\", or a named \"ability\")")
	if not change.ability_id.is_empty() and change.slot != KitMod.SLOT_ABILITIES:
		reader.error("\"ability\" names one of its abilities (\"slot\": \"abilities\")")
	if change.mana_max_add != 0 and change.ability_id.is_empty():
		reader.error("mana_max_add changes what a named ability costs (\"ability\")")
	if (change.cast_bp != FixedMath.BP_ONE or change.targets_add > 0) and change.slot != KitMod.SLOT_SIGNATURE \
			or change.prefer != null and change.slot != KitMod.SLOT_SIGNATURE and change.ability_id.is_empty():
		reader.error("cast_bp, targets_add, and prefer change a signature (\"slot\": \"signature\"; prefer also a named \"ability\")")
	if (change.changes_part() or change.after_add_ticks != 0) and not change.slot.begins_with(KitMod.PASSIVE_PREFIX):
		reader.error("after_add_ms, value_add, guard, rise_add_pct, per_shared_bp, per_twice, per_stacks_add, cap_add_bp, per_shards_add, and per_shards_max_add change a named passive (\"slot\": \"passive:<id>\")")
	if not (change.touches_effects() or change.cooldown_bp != FixedMath.BP_ONE or not change.add_effects.is_empty() or change.after_add_ticks != 0
			or change.cast_bp != FixedMath.BP_ONE or change.targets_add > 0 or change.changes_part() or change.prefer != null
			or change.grows_add_bp != 0 or change.grows_boosts_add_bp != 0 or change.mana_max_add != 0 or change.reach_add != 0 or change.grip_fast_vs != null
			or change.hp_cost_add_bp != 0):
		reader.error("an \"on\" entry needs amount_bp, duration_bp, duration_add_ms, radius_add, cooldown_bp, add_effects, after_add_ms, cast_bp, targets_add, or one of step 7b's knobs")
	reader.finish()
	return change


## A signed duration in ms (whole ticks), as ticks.
static func _signed_ticks(reader: DataReader, key: String) -> int:
	var ms: int = reader.opt_int(key, 0, -60000, 60000)
	if ms % FixedMath.MS_PER_TICK != 0:
		reader.error("%s: must be a multiple of %d ms (one tick)" % [key, FixedMath.MS_PER_TICK])
	return FixedMath.ms_to_ticks(ms)
