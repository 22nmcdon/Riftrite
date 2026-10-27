class_name EffectReader
extends RefCounted
## Reads an EffectDef from its JSON entry and checks it (EffectDef's header has
## every key and what it does): its trigger's fields, its type's fields, its
## target, its area and shape, a summon or a copy, its scaling, and its nested
## effects. EffectDef.read is the way in; this file is its body, split off so
## the effect's shape and its reading are each a file of their own (the clean-up,
## docs/plans/phases/cleanup-and-layout.md).


## `relic`: read a relic's effect (relic triggers and targets, flat numbers).
## `in_area`: one of an area's own effects (it may have a "side").
static func read(reader: DataReader, relic: bool = false, in_area: bool = false) -> EffectDef:
	var def := EffectDef.new()
	var trigger_name: String = reader.opt_string_choice("trigger", "on_fire", EffectDef.TRIGGER_NAMES)
	var type_name: String = reader.req_choice("type", EffectDef.TYPE_NAMES)
	def.trigger = maxi(EffectDef.TRIGGER_NAMES.find(trigger_name), 0) as EffectDef.Trigger
	def.type = maxi(EffectDef.TYPE_NAMES.find(type_name), 0) as EffectDef.Type
	# An area has an anchor instead of a target; start_collapse and summon
	# need none.
	var target_name: String = "target"
	if EffectDef.UNTARGETED.has(def.type) and not type_name.is_empty():
		target_name = "self"
	elif type_name != "area" and type_name != "snare" and type_name != "wall" and type_name != "flood":
		target_name = reader.req_choice("target", EffectDef.TARGET_NAMES)
	def.target = maxi(EffectDef.TARGET_NAMES.find(target_name), 0) as EffectDef.Target

	if not type_name.is_empty():
		match def.type:
			EffectDef.Type.DAMAGE:
				if int(reader.has("amount")) + int(reader.has("amount_bp_of_damage")) + int(reader.has("amount_bp_of_shield")) + int(reader.has("amount_bp_of_stored")) \
						+ int(reader.has("amount_bp_of_engorged")) != 1:
					reader.error("damage needs exactly one of \"amount\", \"amount_bp_of_damage\", \"amount_bp_of_shield\", \"amount_bp_of_stored\", or \"amount_bp_of_engorged\"")
				def.amount = reader.opt_int("amount", 0, 0)
				def.amount_bp_of_damage = reader.opt_int("amount_bp_of_damage", 0, 0)
				def.amount_bp_of_shield = reader.opt_int("amount_bp_of_shield", 0, 0)
				def.amount_bp_of_stored = reader.opt_int("amount_bp_of_stored", 0, 0)
				def.amount_bp_of_engorged = reader.opt_int("amount_bp_of_engorged", 0, 0)
				if reader.has("bonus_per_ally"):
					_read_bonus(def, reader.req_object("bonus_per_ally"))
				def.ricochet = reader.opt_int("ricochet", 0, 0, 5)
				def.execute_below_bp = reader.opt_int("execute_below_pct", 0, 0, 50) * 100
				if reader.has("execute_vs"):
					def.execute_vs = UnitCondition.read(reader.req_object("execute_vs"))
					if def.execute_below_bp == 0:
						reader.error("execute_vs limits an execution (\"execute_below_pct\")")
				def.ignores_def = reader.opt_bool("ignores_def", false)
				# A plain hit (the tuning phase: Thorned Bandage, Splinter
				# Shot): it never crits and never lifesteals.
				def.plain = reader.opt_bool("plain", false)
				def.lifesteal_bp = reader.opt_int("lifesteal_pct", 0, 0, 500) * 100
				def.plus_bp_of_max_hp = reader.opt_int("plus_bp_of_max_hp", 0, 0, 50000)
				def.plus_bp_of_spent = reader.opt_int("plus_bp_of_spent", 0, 0, 100000)
				def.plus_per_shard_bp = reader.opt_int("plus_per_shard_bp", 0, 0, 10 * FixedMath.BP_ONE)
				if def.plain and def.lifesteal_bp > 0:
					reader.error("a plain hit never lifesteals (\"lifesteal_pct\")")
			EffectDef.Type.HEAL:
				var kinds: int = int(reader.has("amount")) + int(reader.has("amount_bp_of_max_hp")) + int(reader.has("amount_bp_of_damage"))
				if kinds != 1:
					reader.error("heal needs exactly one of \"amount\", \"amount_bp_of_max_hp\", or \"amount_bp_of_damage\"")
				def.amount = reader.opt_int("amount", 0, 0)
				def.amount_bp_of_max_hp = reader.opt_int("amount_bp_of_max_hp", 0, 0, FixedMath.BP_ONE)
				def.amount_bp_of_damage = reader.opt_int("amount_bp_of_damage", 0, 0)
				def.overheal_shield_bp = reader.opt_int("overheal_shield_bp", 0, 0, 5 * FixedMath.BP_ONE)
				def.overheal_max_hp_per = reader.opt_int("overheal_max_hp_per", 0, 0, 1000)
				def.as_lifesteal = reader.opt_bool("as_lifesteal", false)
				if reader.has("overheal_status"):
					var spill: DataReader = reader.req_object("overheal_status")
					if spill != null:
						def.overheal_status = spill.req_string("status")
						def.overheal_per = spill.req_int("per", 1, 1000)
						spill.finish()
				if reader.has("cap"):
					var cap: DataReader = reader.req_object("cap")
					if cap != null:
						def.heal_cap_bp = cap.req_int("pct", 1, 99) * 100
						if cap.has("vs"):
							def.heal_cap_vs = UnitCondition.read(cap.req_object("vs"))
						cap.finish()
				if def.as_lifesteal and (def.overheal_shield_bp > 0 or def.overheal_max_hp_per > 0 or def.amount_bp_of_max_hp > 0):
					reader.error("a heal as lifesteal is only its amount (\"amount\" or \"amount_bp_of_damage\")")
			EffectDef.Type.SHARDS:
				def.amount = reader.req_int("amount", 1, 10)
				if def.target != EffectDef.Target.SELF:
					reader.error("shards go to the run through the unit itself (\"target\": \"self\")")
				def.spends = reader.opt_string("spends", "")
			EffectDef.Type.GAIN_MAX_HP:
				if int(reader.has("amount")) + int(reader.has("amount_bp_of_damage")) != 1:
					reader.error("gain_max_hp needs exactly one of \"amount\" or \"amount_bp_of_damage\"")
				def.amount = reader.opt_int("amount", 0, 0)
				def.amount_bp_of_damage = reader.opt_int("amount_bp_of_damage", 0, 0)
			EffectDef.Type.MANA_DRAIN:
				def.amount = reader.req_int("amount", 1)
			EffectDef.Type.GAIN_MANA:
				if reader.has("amount_bp_of_max_mana"):
					def.mana_bp = reader.req_int("amount_bp_of_max_mana", 1, FixedMath.BP_ONE)
				elif reader.has("amount_bp_of_damage"):
					# A share of the mana the event's unit gained (phase 8
					# part 4, Chorister: on_mana_gained carries it).
					def.amount_bp_of_damage = reader.req_int("amount_bp_of_damage", 1, FixedMath.BP_ONE)
				else:
					def.amount = reader.req_int("amount", 1)
			EffectDef.Type.KNOCKBACK, EffectDef.Type.PULL:
				def.hook = def.type == EffectDef.Type.PULL and reader.opt_string_choice("to", "", ["beside"]) == "beside"
				if not def.hook:
					def.hexes = reader.req_int("hexes", 1)
				elif reader.has("hexes") or reader.has("toward"):
					reader.error("a hook carries its catch all the way, so it takes no \"hexes\" or \"toward\"")
				if reader.has("toward"):
					def.toward = maxi(EffectDef.TOWARD_NAMES.find(reader.req_choice("toward", EffectDef.TOWARD_NAMES)), 0) as EffectDef.Toward
					if def.toward == EffectDef.Toward.AREA and not in_area:
						reader.error("only an area's own pull goes \"toward\": \"area\"")
					if (def.type == EffectDef.Type.KNOCKBACK) != (def.toward == EffectDef.Toward.EDGE) and def.toward != EffectDef.Toward.UNIT:
						reader.error("a knockback goes \"toward\" only \"edge\", and a pull never does")
				if def.type == EffectDef.Type.KNOCKBACK:
					def.distance_bp = reader.opt_int("distance_bp", FixedMath.BP_ONE, 1, FixedMath.BP_ONE)
			EffectDef.Type.SEVER:
				def.warning_ticks = reader.req_ticks("warning_ms", FixedMath.MS_PER_TICK)
				def.zone_ticks = reader.req_ticks("duration_ms", FixedMath.MS_PER_TICK)
			EffectDef.Type.FLOOD:
				def.flood_mode = maxi(EffectDef.FLOOD_MODE_NAMES.find(reader.req_choice("mode", EffectDef.FLOOD_MODE_NAMES)), 0) as EffectDef.FloodMode
				if def.flood_mode == EffectDef.FloodMode.CIRCLE or def.flood_mode == EffectDef.FloodMode.DRAIN:
					def.flood_radius = reader.req_int("radius", 0, 7)
				if def.flood_mode == EffectDef.FloodMode.CIRCLE:
					def.anchor = maxi(EffectDef.ANCHOR_NAMES.find(reader.opt_string_choice("anchor", "target", EffectDef.ANCHOR_NAMES.slice(0, 2))), 0) as EffectDef.Anchor
					def.zone_ticks = reader.opt_ticks("duration_ms", 0)
			EffectDef.Type.LEAP:
				var to: String = reader.opt_string_choice("to", "", ["start", "behind", "step"])
				def.leap_home = to == "start"
				def.leap_behind = to == "behind"
				def.leap_step = to == "step"
				if def.leap_home:
					if target_name != "self":
						reader.error("a leap back to the start goes on \"self\"")
				elif def.leap_step:
					# Phase 8 part 6 (The Contract): or the toughest enemy.
					if target_name != "enemy_near_named" and target_name != "enemy_near_target" and target_name != "toughest_enemies":
						reader.error("a step goes to one enemy: \"enemy_near_named\", \"enemy_near_target\", or \"toughest_enemies\"")
					def.resets_attack = reader.opt_bool("resets_attack", false)
				else:
					def.hexes = reader.req_int("max_hexes", 1)
				if reader.has("land_ms"):
					def.land_ticks = reader.req_ticks("land_ms")
			EffectDef.Type.CHARGE:
				def.hexes = reader.req_int("hexes", 1)
				def.knockback_hexes = reader.opt_int("knockback", 0, 0)
				def.carries = reader.opt_bool("carries", false)
				if def.carries and def.knockback_hexes == 0:
					reader.error("a charge that carries needs \"knockback\"")
			EffectDef.Type.AREA:
				_read_area(def, reader)
			EffectDef.Type.SUMMON:
				_read_summon(def, reader)
			EffectDef.Type.SNARE:
				def.max_standing = reader.opt_int("max_standing", 0, 0)
				def.snags = reader.opt_bool("snags", false)
				def.under_front = reader.opt_string_choice("under", "", ["front_ally"]) == "front_ally"
				def.snare_at_named = reader.opt_string_choice("at", "", ["named"]) == "named"
				if def.snare_at_named and not EffectDef.EVENT_VS_TRIGGERS.has(def.trigger):
					reader.error("a snare \"at\": \"named\" needs an event that names a unit")
				if not def.under_front:
					_read_nested(def, reader, "a snare")
			EffectDef.Type.WALL:
				def.width_range = reader.req_int("width_hexes", 1, 8) * HexGrid.HEX
				def.ahead_range = reader.req_int("ahead_hexes", 0, 4) * HexGrid.HEX
				def.reflect_bp = reader.opt_int("reflect_bp", 0, 0, FixedMath.BP_ONE)
				def.blocks_movement = reader.opt_bool("blocks_movement", false)
				def.wall_hp_bp = reader.opt_int("hp_bp_of_max_hp", 0, 0, 5 * FixedMath.BP_ONE)
				def.until_broken = reader.opt_bool("until_broken", false)
				def.max_standing = reader.opt_int("max_standing", 0, 0)
				def.at_target = reader.opt_string_choice("at", "", ["target"]) == "target"
				if def.until_broken:
					if def.wall_hp_bp == 0:
						reader.error("a wall that stands until broken needs \"hp_bp_of_max_hp\"")
					if reader.has("duration_ms"):
						reader.error("a wall that stands until broken has no \"duration_ms\"")
				else:
					def.zone_ticks = reader.req_ticks("duration_ms", FixedMath.MS_PER_TICK)
				if reader.has("effects"):
					_read_nested(def, reader, "a wall")
			EffectDef.Type.SHIELD:
				if int(reader.has("amount")) + int(reader.has("amount_bp_of_damage")) + int(reader.has("amount_bp_of_max_hp")) + int(reader.has("amount_bp_of_shield")) != 1:
					reader.error("shield needs exactly one of \"amount\", \"amount_bp_of_damage\", \"amount_bp_of_max_hp\", or \"amount_bp_of_shield\"")
				def.plus_per_shard_bp = reader.opt_int("plus_per_shard_bp", 0, 0, 10 * FixedMath.BP_ONE)
				def.amount = reader.opt_int("amount", 0, 0)
				def.amount_bp_of_damage = reader.opt_int("amount_bp_of_damage", 0, 0)
				def.amount_bp_of_max_hp = reader.opt_int("amount_bp_of_max_hp", 0, 0, FixedMath.BP_ONE)
				def.amount_bp_of_shield = reader.opt_int("amount_bp_of_shield", 0, 0)
				def.cap_bp_of_max_hp = reader.opt_int("cap_bp_of_max_hp", 0, 1, 10 * FixedMath.BP_ONE)
				def.shield_up_to = reader.opt_bool("up_to", false)
			EffectDef.Type.SPEND_SHIELD:
				if def.target != EffectDef.Target.SELF:
					reader.error("spend_shield spends the unit's own Shield (\"target\": \"self\")")
				def.keep_bp = reader.opt_int("keep_bp", 0, 0, FixedMath.BP_ONE - 1)
			EffectDef.Type.RELEASE_STORED:
				if def.target != EffectDef.Target.SELF:
					reader.error("release_stored lets go of the unit's own stored damage (\"target\": \"self\")")
			EffectDef.Type.SPEND_ENGORGED:
				if def.target != EffectDef.Target.SELF:
					reader.error("spend_engorged gives up the unit's own Engorged max HP (\"target\": \"self\")")
			EffectDef.Type.RAISE:
				def.raise_hp_bp = reader.req_int("hp_pct", 1, 100) * 100
				def.raise_ticks = reader.req_ticks("duration_ms", FixedMath.MS_PER_TICK)
				def.max_standing = reader.opt_int("max_standing", 0, 0)
				def.raise_grow_hp_bp = reader.opt_int("grow_hp_pct", 0, 0, 100) * 100
				def.raise_grow_ticks = reader.opt_ticks("grow_ms", 0)
			EffectDef.Type.APPLY_STATUS:
				# Phase 8 part 6 (Solvent): whichever of these the unit hit has
				# fewer of, "status" naming none; its stacks a share of the
				# larger's with "larger_share_bp", else "stacks".
				if reader.has("to_smaller_of"):
					def.smaller_of = reader.req_string_array("to_smaller_of")
					if def.smaller_of.size() < 2:
						reader.error("to_smaller_of names two statuses or more")
					def.status_id = def.smaller_of[0] if not def.smaller_of.is_empty() else ""
					def.larger_share_bp = reader.opt_int("larger_share_bp", 0, 1, FixedMath.BP_ONE)
				else:
					def.status_id = reader.req_string("status")
				# 0 base stacks only with a "scaling" (phase 8 part 5, Blight:
				# Poison equal to a share of ATK).
				def.stacks = reader.opt_int("stacks", 1, 0)
				def.duration_ticks = reader.opt_ticks("duration_ms", 0)
				def.stacks_of = reader.opt_string("stacks_of", "")
				def.stacks_share_bp = reader.opt_int("stacks_share_bp", 0, 1, FixedMath.BP_ONE)
				if def.stacks_share_bp > 0 and def.stacks_of.is_empty():
					reader.error("stacks_share_bp is a share of stacks_of")
				def.fresh_only = reader.opt_bool("fresh_only", false)
				def.marks_stack = reader.opt_bool("marks_stack", false)
				if reader.has("until_enemy_within_hexes"):
					def.until_near = reader.req_int("until_enemy_within_hexes", 1, 10) * HexGrid.HEX
				def.strength_add_bp = reader.opt_int("strength_add_bp", 0, 0, FixedMath.BP_ONE)
			EffectDef.Type.EXTEND_STATUS:
				if reader.has("statuses"):
					def.extend_statuses = reader.req_string_array("statuses")
					if def.extend_statuses.is_empty():
						reader.error("statuses needs at least one id")
					else:
						def.status_id = def.extend_statuses[0]
					if reader.has("status"):
						reader.error("extend_status takes \"status\" or \"statuses\", not both")
				else:
					def.status_id = reader.req_string("status")
				def.duration_ticks = reader.req_ticks("duration_ms", FixedMath.MS_PER_TICK)
			EffectDef.Type.CLEANSE:
				if reader.has("count"):
					def.cleanse_count = reader.req_int("count", 1, 10)
				else:
					def.amount = reader.req_int("amount_bp", 1, FixedMath.BP_ONE)
				if reader.has("statuses"):
					def.cleanse_statuses = reader.req_string_array("statuses")
		if reader.has("grows_per_stack"):
			var grows: DataReader = reader.req_object("grows_per_stack")
			if grows != null:
				def.grows_status = grows.req_string("status")
				def.grows_stack_bp = grows.req_int("bp", 1, FixedMath.BP_ONE)
				grows.finish()
			if def.type != EffectDef.Type.DAMAGE and def.type != EffectDef.Type.HEAL and def.type != EffectDef.Type.SHIELD and def.type != EffectDef.Type.GAIN_MANA and def.type != EffectDef.Type.APPLY_STATUS:
				reader.error("only damage, heals, Shields, mana gained, and statuses applied grow per stack")
		if reader.has("amount_per_stack"):
			var per: DataReader = reader.req_object("amount_per_stack")
			if per != null:
				if per.is_array("status"):
					var named: Array[String] = per.req_string_array("status")
					if not named.is_empty():
						def.per_stack_status = named[0]
						def.per_stack_more = named.slice(1)
				else:
					def.per_stack_status = per.req_string("status")
				def.amount_per_stack = per.req_int("per", 1, 100)
				per.finish()
			if def.type != EffectDef.Type.DAMAGE:
				reader.error("amount_per_stack is a damage effect's")
		if reader.has("per_damage"):
			def.per_damage = reader.req_int("per_damage", 1)
			if def.type != EffectDef.Type.APPLY_STATUS and def.type != EffectDef.Type.HEAL:
				reader.error("per_damage is an apply_status's or a heal's")
		if reader.has("scaling"):
			if def.amount_bp_of_damage > 0 or def.amount_bp_of_max_hp > 0 or def.amount_bp_of_shield > 0 or def.amount_bp_of_stored > 0 or def.amount_bp_of_engorged > 0:
				reader.error("\"scaling\" can't be combined with %s" % ("amount_bp_of_damage" if def.amount_bp_of_damage > 0 else "amount_bp_of_max_hp" if def.amount_bp_of_max_hp > 0 else "amount_bp_of_shield"))
			_read_scaling(def, reader.req_object("scaling"))
		def.scaling_of_owner = reader.opt_string_choice("scaling_of", "", ["owner"]) == "owner"
	if def.type == EffectDef.Type.APPLY_STATUS and def.stacks == 0 and not reader.has("scaling"):
		reader.error("an apply_status with 0 stacks needs a \"scaling\"")

	def.when_attackers = reader.opt_int("when_attackers", 0, 0, 10)
	if reader.has("when_attackers_kits"):
		def.when_attackers_kits.assign(reader.req_string_array("when_attackers_kits"))
		if def.when_attackers == 0:
			reader.error("\"when_attackers_kits\" needs \"when_attackers\"")
	if reader.has("only"):
		def.only = UnitCondition.read(reader.req_object("only"))
		if def.target != EffectDef.Target.ALL_ENEMIES and def.target != EffectDef.Target.ALL_ALLIES and def.target != EffectDef.Target.TOUGHEST_ENEMIES and not EffectDef.NEAR_TARGETS.has(def.target):
			reader.error("only all_enemies, all_allies, toughest_enemies, and the near targets take \"only\"")
	if def.target == EffectDef.Target.FARTHEST_ENEMIES:
		def.count = reader.req_int("count", 1, 10)
	if def.target == EffectDef.Target.LOWEST_MANA_ALLY or def.target == EffectDef.Target.LOWEST_HP_ALLY or def.target == EffectDef.Target.MOST_TARGETED_ALLY or def.target == EffectDef.Target.TOUGHEST_ENEMIES:
		# The allies with the least of their bar (phase 8 part 4, Shared Breath),
		# or of their HP (phase 8 part 5, Bastion of Saints' taste).
		def.count = reader.opt_int("count", 1, 1, 5)
	if def.target == EffectDef.Target.ALLIES_NEAR_SELF:
		# Only the nearest that many (phase 8 part 6, Ilse's Blessing; 0:
		# every ally within reach).
		def.nearest = reader.opt_int("nearest", 0, 1, 5)
	elif reader.has("nearest"):
		reader.req_int("nearest")
		reader.error("only allies_near_self takes \"nearest\"")
	if def.target == EffectDef.Target.ENEMIES_NEAR_ALLIES and reader.has("around"):
		# Only round the allies that meet it (phase 8 part 4, Gale: ranged).
		def.around = UnitCondition.read(reader.req_object("around"))
	elif reader.has("around"):
		reader.req_object("around")
		reader.error("only enemies_near_allies takes \"around\"")
	if def.target == EffectDef.Target.NEAREST_ENEMIES:
		def.count = reader.req_int("count", 1, 30)
		if not relic:
			reader.error("nearest_enemies is a relic's target (nearest any of its side)")
	if EffectDef.NEAR_TARGETS.has(def.target) or def.target == EffectDef.Target.LOWEST_HP_ALLY:
		if EffectDef.REACH_TARGETS.has(def.target) or reader.has("within_hexes"):
			def.near_range = reader.req_int("within_hexes", 1, 20) * HexGrid.HEX
	elif reader.has("within_hexes"):
		reader.req_int("within_hexes")
		reader.error("within_hexes is only for the targets near the target and lowest_hp_ally")
	if reader.has("side"):
		var side_name: String = reader.req_choice("side", ["enemies", "allies"])
		def.side = maxi(EffectDef.SIDE_NAMES.find(side_name), 0) as EffectDef.AreaSide
		if not in_area:
			reader.error("only an area's own effects have a \"side\"")
	read_window(reader, def)
	if not trigger_name.is_empty():
		_read_trigger_fields(def, reader, relic, in_area)
	if EffectDef.PLACED.has(def.type) and (def.trigger == EffectDef.Trigger.ON_HIT or def.trigger == EffectDef.Trigger.ON_CRIT):
		reader.error("%s is %s as its ability fires or on a passive's trigger, never on_hit or on_crit" % ["an area" if def.type == EffectDef.Type.AREA else "a " + type_name, "cast" if def.type == EffectDef.Type.AREA else "placed"])
	# A hop (phase 8 part 2, Windrunner): the unit hops a hex away from its
	# nearest enemy, as the hop_away trait does; it aims at the unit itself.
	if def.type == EffectDef.Type.HOP and not target_name.is_empty() and def.target != EffectDef.Target.SELF:
		reader.error("a hop moves the unit itself, so it needs \"target\": \"self\"")
	if EffectDef.MOVES_SELF.has(def.type) and not def.leap_home and not def.leap_step and not type_name.is_empty() and not target_name.is_empty():
		# A leap behind may be a passive's too (phase 8 part 4, Shadowstep's
		# habit: behind the unit's target).
		# A companion's leap may be a passive's (phase 8 part 6, Sic 'Em's
		# habit: PartDef checks the passive is done by a companion).
		if def.target != EffectDef.Target.TARGET or (def.trigger != EffectDef.Trigger.ON_FIRE and not def.leap_behind and def.trigger != EffectDef.Trigger.ON_BASIC_ATTACK):
			reader.error("%s moves the unit itself to its target, so it needs \"target\": \"target\" and the on_fire trigger" % type_name)

	# "hit_target" and damage-based shields need a hit to refer to.
	var needs_hit: bool = def.target == EffectDef.Target.HIT_TARGET or def.amount_bp_of_damage > 0
	if needs_hit and not trigger_name.is_empty() and not relic and def.trigger == EffectDef.Trigger.ON_FIRE:
		reader.error("\"%s\" needs a hit, so its trigger must be on_hit or on_crit, not on_fire" % (target_name if def.target == EffectDef.Target.HIT_TARGET else "amount_bp_of_damage"))
	if not trigger_name.is_empty() and (EffectDef.EVENT_TRIGGERS.has(def.trigger) or EffectDef.UNIT_TRIGGERS.has(def.trigger)):
		if def.target == EffectDef.Target.HIT_TARGET and not EffectDef.EVENT_UNIT_TRIGGERS.has(def.trigger):
			reader.error("%s names no unit, so it can't use hit_target" % trigger_name)
		if def.amount_bp_of_damage > 0 and not EffectDef.EVENT_HIT_TRIGGERS.has(def.trigger):
			reader.error("%s names no hit, so it can't use amount_bp_of_damage" % trigger_name)
	if EffectDef.NAMED_TARGETS.has(def.target) and not EffectDef.EVENT_VS_TRIGGERS.has(def.trigger):
		reader.error("%s needs an event that names a unit" % EffectDef.TARGET_NAMES[def.target])
	if not def.stacks_of.is_empty() and not EffectDef.EVENT_VS_TRIGGERS.has(def.trigger) and def.trigger != EffectDef.Trigger.ON_FIRE:
		reader.error("stacks_of needs an event that names a unit")
	if def.type == EffectDef.Type.RAISE and not type_name.is_empty() and def.trigger != EffectDef.Trigger.ON_ENEMY_FELL and def.trigger != EffectDef.Trigger.ON_KILL:
		reader.error("a raise stands up the enemy an event names as it falls (on_enemy_fell or on_kill)")
	if def.trigger == EffectDef.Trigger.ON_FALL and not type_name.is_empty():
		if def.type == EffectDef.Type.AREA and def.anchor != EffectDef.Anchor.SELF:
			reader.error("on_fall runs once the unit has fallen, so its area is anchored on it (\"anchor\": \"self\")")
		elif def.type != EffectDef.Type.AREA and EffectDef.FIELD_ONLY_TARGETS.has(def.target) and not EffectDef.UNTARGETED.has(def.type):
			reader.error("on_fall runs once the unit has fallen, so it can't aim at \"%s\"" % EffectDef.TARGET_NAMES[def.target])
	reader.finish()
	return def


static func _read_area(def: EffectDef, reader: DataReader) -> void:
	if reader.has("duration_ms") or reader.has("every_ms"):
		def.zone_ticks = reader.req_ticks("duration_ms", FixedMath.MS_PER_TICK)
		def.pulse_ticks = reader.req_ticks("every_ms", FixedMath.MS_PER_TICK)
		if def.pulse_ticks > def.zone_ticks:
			reader.error("a zone lands every_ms, which can't be longer than its duration_ms")
	var shape_reader: DataReader = reader.req_object("shape")
	def.shape = ShapeDef.read(shape_reader) if shape_reader != null else ShapeDef.new()
	var anchor_name: String = reader.req_choice("anchor", EffectDef.ANCHOR_NAMES)
	def.anchor = maxi(EffectDef.ANCHOR_NAMES.find(anchor_name), 0) as EffectDef.Anchor
	def.warning_ticks = reader.opt_ticks("warning_ms", 0)
	if def.zone_ticks > 0 and def.warning_ticks > 0:
		reader.error("a zone lands from the moment it's cast, so it takes no warning_ms")
	var follow_rule: String = reader.opt_string_choice("follows", "", ["largest_group", "nearest", "holder"])
	def.follows = not follow_rule.is_empty()
	def.follows_nearest = follow_rule == "nearest"
	def.follows_holder = follow_rule == "holder"
	if def.follows and def.zone_ticks == 0:
		reader.error("only a zone (an area with a duration) follows")
	if reader.has("grows"):
		var grows: DataReader = reader.req_object("grows")
		if grows != null:
			def.grow_ticks = grows.req_ticks("every_ms", FixedMath.MS_PER_TICK)
			def.grow_max = grows.req_int("max_radius", 1, 10)
			grows.finish()
		if def.zone_ticks == 0 or def.shape.is_aimed():
			reader.error("only a circle or ring zone grows")
		elif def.grow_max <= def.shape.size:
			reader.error("a zone grows to a max_radius past its radius")
	def.at_groups = reader.opt_int("at_largest_groups", 0, 1, 5)
	if reader.has("stays_near_hexes"):
		def.stays_near = reader.req_int("stays_near_hexes", 1, 10) * HexGrid.HEX
	def.radius_per_stack = reader.opt_string("radius_per_stack", "")
	if (def.stays_near > 0 or not def.radius_per_stack.is_empty()) and (def.zone_ticks == 0 or def.shape.is_aimed()):
		reader.error("only a circle or ring zone stays near enemies or grows per stack")
	if def.at_groups > 0 and def.anchor != EffectDef.Anchor.TARGET:
		reader.error("an area at the largest groups is anchored on each (\"anchor\": \"target\")")
	def.hits = maxi(EffectDef.HITS_NAMES.find(reader.req_choice("hits", EffectDef.HITS_NAMES)), 0) as EffectDef.Hits
	def.per_enemy_bp = reader.opt_int("per_enemy_bp", 0, 0, FixedMath.BP_ONE)
	# A zone that may stand only so many at once from its ability (phase 8
	# part 2, Sanctifier): once that many stand, a new cast lays no more.
	def.max_standing = reader.opt_int("max_standing", 0, 0)
	if def.max_standing > 0 and def.zone_ticks == 0:
		reader.error("only a zone (an area with a duration) has max_standing")
	if not anchor_name.is_empty() and def.shape.is_aimed() != (def.anchor == EffectDef.Anchor.TARGET_DIRECTION):
		reader.error("anchor: a %s takes %s" % [ShapeDef.KIND_NAMES[def.shape.kind], "target_direction" if def.shape.is_aimed() else "target or self"])
	_read_nested(def, reader, "an area")


## An area's or a snare's own effects: each aims at "target" (every unit it
## lands on), on_fire; no placed thing, leap, or charge among them.
static func _read_nested(def: EffectDef, reader: DataReader, what: String) -> void:
	var effect_readers: Array[DataReader] = reader.opt_object_array("effects")
	if effect_readers.is_empty():
		reader.error("%s needs effects" % what)
	for effect_reader: DataReader in effect_readers:
		var effect: EffectDef = EffectDef.read(effect_reader, false, def.type == EffectDef.Type.AREA)
		# A snare may grow a wall where it springs (phase 8 part 2, Warden
		# of Thorns).
		var snare_wall: bool = def.type == EffectDef.Type.SNARE and effect.type == EffectDef.Type.WALL and effect.at_target
		if (EffectDef.PLACED.has(effect.type) and not snare_wall) or EffectDef.MOVES_SELF.has(effect.type) or EffectDef.UNTARGETED.has(effect.type):
			effect_reader.error("%s's effects can't be an area, a leap, or a charge (nor a snare, a wall, a summon, or start_collapse)" % what)
		elif effect.target != EffectDef.Target.TARGET or effect.trigger != EffectDef.Trigger.ON_FIRE:
			effect_reader.error("%s's effects aim at \"target\" (%s), on_fire" % [what, "each unit hit" if def.type == EffectDef.Type.AREA else ("each enemy touching it" if def.type == EffectDef.Type.WALL else "the enemy that springs it")])
		def.area_effects.append(effect)


static func _read_summon(def: EffectDef, reader: DataReader) -> void:
	if reader.has("copy_of"):
		_read_copy(def, reader)
		return
	def.summon_kit = reader.req_string("kit")
	var placement_name: String = reader.req_choice("placement", EffectDef.PLACEMENT_NAMES)
	def.placement = maxi(EffectDef.PLACEMENT_NAMES.find(placement_name), 0) as EffectDef.Placement
	if def.placement == EffectDef.Placement.HEXES:
		def.summon_hexes = reader.req_hex_array("hexes")
		def.count = def.summon_hexes.size()
		if reader.has("count"):
			reader.opt_int("count", 0)
			reader.error("summon on hexes makes one on each hex, so it takes no \"count\"")
	else:
		def.count = reader.opt_int("count", 1, 1)
	if def.placement == EffectDef.Placement.EDGES:
		def.near_target = reader.opt_string_choice("near", "self", EffectDef.NEAR_NAMES) == "target"
	# Phase 8 part 3 (the Drowned Bellringer): no more once that many of its
	# kit stand on the summoner's side.
	def.max_standing = reader.opt_int("max_standing", 0, 0)
	# Phase 8 part 6 (Nest): each goes quietly that long after it joins.
	def.lasts_ticks = reader.opt_ticks("lasts_ms", 0)


## A copy (phase 8 part 6, Lucan; see the top).
static func _read_copy(def: EffectDef, reader: DataReader) -> void:
	def.copy_of = maxi(EffectDef.COPY_OF_NAMES.find(reader.req_choice("copy_of", ["self", "each_ally"])), 1) as EffectDef.CopyOf
	def.copy_share_bp = reader.req_int("share_pct", 1, 100) * 100
	def.copy_grows_bp = reader.opt_int("grows_per_copy_pct", 0, 0, 100) * 100
	def.copy_share_max_bp = reader.opt_int("share_max_pct", 100, 1, 100) * 100
	def.copy_casts = reader.opt_bool("casts", false)
	def.placement = EffectDef.Placement.ADJACENT
	def.max_standing = reader.opt_int("max_standing", 0, 0)
	def.lasts_ticks = reader.opt_ticks("lasts_ms", 0)
	if def.lasts_ticks <= 0:
		reader.error("a copy needs \"lasts_ms\"")
	for key: String in ["kit", "placement", "count"]:
		if reader.has(key):
			reader.error("a copy takes no \"%s\"" % key)


## Checks the trigger is allowed here and reads its extra fields.
static func _read_trigger_fields(def: EffectDef, reader: DataReader, relic: bool, in_area: bool = false) -> void:
	var allowed: Array[EffectDef.Trigger] = EffectDef.RELIC_TRIGGERS if relic else EffectDef.ABILITY_TRIGGERS
	if not allowed.has(def.trigger):
		reader.error("%s effects can't use the trigger \"%s\"" % ["relic" if relic else "ability", EffectDef.TRIGGER_NAMES[def.trigger]])
	match def.trigger:
		EffectDef.Trigger.AT_TIME:
			def.at_ticks = reader.req_ticks("at_ms", FixedMath.MS_PER_TICK)
		EffectDef.Trigger.ON_ALLY_BELOW_HP:
			def.threshold_bp = reader.req_int("threshold_bp", 1, FixedMath.BP_ONE - 1)
			def.once = reader.opt_bool("once", false)
			def.below_hp_enemies = reader.opt_bool("enemies", false)
		EffectDef.Trigger.ON_INTERVAL:
			def.interval_ticks = reader.req_ticks("interval_ms", FixedMath.MS_PER_TICK)
			def.first_ticks = reader.opt_ticks("first_ms", 0, 0)
			def.once = reader.opt_bool("once", false)
		EffectDef.Trigger.ON_BELOW_HP:
			def.threshold_bp = reader.req_int("threshold_bp", 1, FixedMath.BP_ONE - 1)
			def.times = reader.opt_int("times", 1, 1, 10)
		EffectDef.Trigger.ON_ENEMY_NEAR:
			# The tuning phase (Snare Wire): an enemy first comes this near.
			def.near_trigger_range = reader.req_int("near_hexes", 1, 10) * HexGrid.HEX
			def.once_per_enemy = reader.opt_bool("once_per_enemy", false)
		EffectDef.Trigger.ON_STATUS_TICK:
			# Phase 8 part 6 (Ilse's Heat): only those statuses' ticks, on an
			# enemy within "near_hexes" of the unit if given.
			if reader.has("statuses"):
				def.statuses = reader.req_string_array("statuses")
			if reader.has("near_hexes"):
				def.near_trigger_range = reader.req_int("near_hexes", 1, 20) * HexGrid.HEX
		EffectDef.Trigger.ON_HIT_TAKEN:
			def.min_hit_bp = reader.opt_int("min_bp_of_max_hp", 0, 0, FixedMath.BP_ONE)
		EffectDef.Trigger.ON_ENEMY_FELL:
			if reader.has("fell_within_hexes"):
				def.fell_range = reader.req_int("fell_within_hexes", 1, 20) * HexGrid.HEX
			if reader.has("by"):
				def.by = UnitCondition.read(reader.req_object("by"))
			if reader.has("by_beyond_hexes"):
				def.by_range = reader.req_int("by_beyond_hexes", 1, 10) * HexGrid.HEX
		EffectDef.Trigger.ON_ALLY_HIT:
			if reader.has("by"):
				def.by = UnitCondition.read(reader.req_object("by"))
			# Phase 8 part 6 (Ilse's Blessing): a stacking status on the ally
			# that hit; it runs only while that ally holds a stack, and spends
			# one (its next N basic attacks).
			if def.type != EffectDef.Type.SHARDS:
				def.spends = reader.opt_string("spends", "")
		EffectDef.Trigger.ON_KILL:
			def.from_signature = reader.opt_bool("from_signature", false)
			def.off_target = reader.opt_bool("off_target", false)
			def.executed = reader.opt_bool("executed", false)
			if reader.has("from_ability"):
				def.from_abilities = reader.req_string_array("from_ability")
		EffectDef.Trigger.ON_HOLDER_CRIT:
			if reader.has("beyond_hexes"):
				def.beyond_range = reader.req_int("beyond_hexes", 1, 10) * HexGrid.HEX
			# Only those abilities' crits (phase 8 part 4, Choke: her Knife's).
			if reader.has("from_ability"):
				def.from_abilities = reader.req_string_array("from_ability")
		EffectDef.Trigger.ON_HEAL, EffectDef.Trigger.ON_HOLDER_HIT, EffectDef.Trigger.ON_PULL, EffectDef.Trigger.ON_MAX_HP_UP, EffectDef.Trigger.ON_ZONE_ENTER:
			if reader.has("from_ability"):
				def.from_abilities = reader.req_string_array("from_ability")
			# Only its signature's hits (the tuning phase, Weighted Net).
			if def.trigger == EffectDef.Trigger.ON_HOLDER_HIT:
				def.from_signature = reader.opt_bool("from_signature", false)
				# Phase 8 part 6 (Ottilie's vials): a stacking status on the
				# unit itself; it runs only while the unit holds a stack, and
				# the hit spends one for every effect of its passive that
				# spends it (her next Toss carries the vial).
				def.spends = reader.opt_string("spends", "")
			if def.trigger == EffectDef.Trigger.ON_HEAL and reader.has("was_below_pct"):
				def.was_below_bp = reader.req_int("was_below_pct", 1, 99) * 100
		EffectDef.Trigger.ON_STATUS, EffectDef.Trigger.ON_STATUS_ENDED:
			# A cleanse's or an extend's "statuses" are its own (phase 8 part
			# 4, Mist Step); such an event filters by "keywords".
			if reader.has("statuses") and def.type != EffectDef.Type.CLEANSE and def.type != EffectDef.Type.EXTEND_STATUS:
				def.statuses = reader.req_string_array("statuses")
			def.keywords = reader.opt_choice_array("keywords", Keywords.NAMES)
			if reader.has("at_stacks"):
				def.at_stacks = reader.req_int("at_stacks", 2, 50)
				if def.trigger != EffectDef.Trigger.ON_STATUS or def.statuses.size() != 1:
					reader.error("at_stacks goes on on_status with one status in \"statuses\"")
			if def.keywords.has(Keywords.SHIELDED):
				reader.error("Shielded isn't a status; on_shielded is when a unit gains Shield")
	if reader.has("grows_per_damage_taken"):
		var grows: DataReader = reader.req_object("grows_per_damage_taken")
		if grows != null:
			def.taken_per = grows.req_int("per", 1)
			def.power_per_taken_bp = grows.req_int("bp", 1, FixedMath.BP_ONE)
			grows.finish()
		if def.type != EffectDef.Type.DAMAGE and def.type != EffectDef.Type.HEAL and def.type != EffectDef.Type.SHIELD:
			reader.error("only damage, heals, and Shields grow with damage taken")
	if EffectDef.EVENT_TRIGGERS.has(def.trigger) or (def.trigger == EffectDef.Trigger.ON_FIRE and not relic and not in_area):
		def.every = reader.opt_int("every", 1, 1)
	if EffectDef.EVENT_TRIGGERS.has(def.trigger):
		def.once = reader.opt_bool("once", false)
		def.delay_ticks = reader.opt_ticks("delay_ms", 0, FixedMath.MS_PER_TICK)
		def.cooldown_per_unit_ticks = reader.opt_ticks("cooldown_per_unit_ms", 0, FixedMath.MS_PER_TICK)
		def.once_per_enemy = reader.opt_bool("once_per_enemy", false)
		if def.once_per_enemy and not EffectDef.EVENT_VS_TRIGGERS.has(def.trigger):
			reader.error("%s names no unit, so it can't take once_per_enemy" % EffectDef.TRIGGER_NAMES[def.trigger])
		def.cooldown_ticks = reader.opt_ticks("cooldown_ms", 0, FixedMath.MS_PER_TICK)
		if def.cooldown_per_unit_ticks > 0 and not EffectDef.EVENT_VS_TRIGGERS.has(def.trigger):
			reader.error("%s names no unit, so it can't take cooldown_per_unit_ms" % EffectDef.TRIGGER_NAMES[def.trigger])
		if reader.has("vs"):
			def.vs = UnitCondition.read(reader.req_object("vs"))
			if not EffectDef.EVENT_VS_TRIGGERS.has(def.trigger):
				reader.error("%s names no unit, so it can't take \"vs\"" % EffectDef.TRIGGER_NAMES[def.trigger])
	if def.per_damage > 0 and not EffectDef.EVENT_HIT_TRIGGERS.has(def.trigger):
		reader.error("per_damage needs an event that names a hit (%s doesn't)" % EffectDef.TRIGGER_NAMES[def.trigger])
	if reader.has("holder"):
		def.holder = UnitCondition.read(reader.req_object("holder"))
		if not (EffectDef.EVENT_TRIGGERS.has(def.trigger) or EffectDef.UNIT_TRIGGERS.has(def.trigger)):
			reader.error("only an event's or a timed effect can take \"holder\"")
	if def.target == EffectDef.Target.TRIGGER_ALLY and def.trigger != EffectDef.Trigger.ON_ALLY_BELOW_HP and def.trigger != EffectDef.Trigger.ON_ALLY_SHIELD_BROKEN and def.trigger != EffectDef.Trigger.ON_ENEMY_FELL:
		reader.error("\"trigger_ally\" only works with the on_ally_below_hp, on_ally_shield_broken, and on_enemy_fell triggers")
	if not relic:
		return
	if EffectDef.FIELD_ONLY_TARGETS.has(def.target):
		reader.error("\"%s\" needs a unit on the field, so a relic can't use it" % EffectDef.TARGET_NAMES[def.target])
	if def.amount_bp_of_damage > 0:
		reader.error("a relic has no hit, so it can't use amount_bp_of_damage")
	if def.scaling.any(func(ratio: int) -> bool: return ratio != 0):
		reader.error("relic numbers are flat, so relic effects can't have \"scaling\"")


static func _read_bonus(def: EffectDef, reader: DataReader) -> void:
	if reader == null:
		return
	def.bonus_bp_per_ally = reader.req_int("bp", 1)
	def.bonus_within = reader.req_int("within_hexes", 1) * HexGrid.HEX
	def.bonus_kit = reader.opt_string("kit", "")
	reader.finish()


## Reads an optional "window" object into `holder` (an EffectDef or AuraDef,
## anything with window_from_ticks / window_until_ticks).
static func read_window(reader: DataReader, holder: Object) -> void:
	if not reader.has("window"):
		return
	var window: DataReader = reader.req_object("window")
	if window == null:
		return
	var from_ticks: int = window.opt_ticks("from_ms", 0)
	var until_ticks: int = -1
	if window.has("until_ms"):
		until_ticks = window.req_ticks("until_ms", FixedMath.MS_PER_TICK)
		if until_ticks <= from_ticks:
			window.error("until_ms must be later than from_ms")
	window.finish()
	holder.set("window_from_ticks", from_ticks)
	holder.set("window_until_ticks", until_ticks)


static func _read_scaling(def: EffectDef, reader: DataReader) -> void:
	if reader == null:
		return
	for key: String in reader.map_keys():
		var stat: int = UnitStats.STAT_NAMES.find(key)
		if stat < 0 or stat >= UnitStats.SCALING_STATS:
			reader.error("can't scale from \"%s\" (expected one of: %s)" % [key, ", ".join(UnitStats.STAT_NAMES.slice(0, UnitStats.SCALING_STATS))])
			continue
		def.scaling[stat] = reader.req_int(key, 0)
	reader.finish()
