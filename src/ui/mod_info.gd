class_name ModInfo
extends RefCounted
## The numbers line for a kit mod (docs/plans/rebuild-phase5c-combos.md,
## step 2; part 7, section 6: every stat change says its amount). An item's,
## an upgrade's, a relic's, or a duo bond's sentence says what it's for; this
## line, worked out from its mod, says how much, the way UnitInfo's numbers
## line does for an ability: "+15% DEF · Signature: +20% healing, +2s
## duration · +20 starting mana". Parts are joined by " · ".
##
## Where a card is for one hero, `kit` is that hero's kit, so an added
## effect that scales with a stat shows its number; null shows the effect
## for any hero.

const SLOT_NAMES: Dictionary[String, String] = {
	KitMod.SLOT_BASIC: "Basic attack", KitMod.SLOT_SIGNATURE: "Signature", KitMod.SLOT_ABILITIES: "Every ability",
}
## What an amount_bp is a power bonus to, by effect type.
const POWER_WORDS: Dictionary[int, String] = {
	EffectDef.Type.DAMAGE: "damage", EffectDef.Type.HEAL: "healing", EffectDef.Type.SHIELD: "Shield",
}


## A kit mod's numbers line ("" for a mod that changes nothing).
static func mod_numbers(mod: KitMod, kit: UnitDef, content: ContentDb) -> String:
	return " · ".join(mod_parts(mod, kit, content))


static func mod_parts(mod: KitMod, kit: UnitDef, content: ContentDb) -> Array[String]:
	var parts: Array[String] = []
	var shown: UnitDef = kit if kit != null else _any_hero()
	for stat: int in mod.stats_bp.size():
		if mod.stats_bp[stat] != FixedMath.BP_ONE:
			parts.append("%s %s" % [UnitInfo.signed_percent(mod.stats_bp[stat] - FixedMath.BP_ONE), UnitStats.LABELS[stat]])
	for stat: int in mod.stats_add.size():
		if mod.stats_add[stat] != 0:
			parts.append("%s %s" % [signed(mod.stats_add[stat]), UnitStats.LABELS[stat]])
	for change: KitMod.AbilityChange in mod.changes:
		var change_text: String = _change_text(change, mod, shown, content)
		if not change_text.is_empty():
			parts.append(change_text)
	for part: PartDef in mod.passives:
		parts.append("%s: %s" % [part.name, UnitInfo.passive_numbers(part, shown, content)])
	if mod.mana_max_bp != FixedMath.BP_ONE:
		parts.append("%s max mana" % UnitInfo.signed_percent(mod.mana_max_bp - FixedMath.BP_ONE))
	if mod.mana_max_add != 0:
		parts.append("%s max mana" % signed(mod.mana_max_add))
	if mod.mana_regen_add != 0:
		parts.append("%s mana a second" % signed(mod.mana_regen_add))
	if mod.mana_start_add != 0:
		parts.append("%s starting mana" % signed(mod.mana_start_add))
	if mod.mana_start_bp > 0:
		parts.append("starts with %s mana" % ValueBreakdown._percent(mod.mana_start_bp))
	if not mod.gambit_label.is_empty():
		match mod.place_rule:
			"neutral":
				parts.append("may start on the middle row")
			"front":
				parts.append("may start on the middle row or the enemies' front row")
			"edge":
				parts.append("may start on any edge hex")
			"share":
				parts.append("may share a hex with another hero")
		if mod.arrive_ticks > 0:
			parts.append("enters at %s%s" % [UnitInfo.seconds(mod.arrive_ticks), " beside the hindmost enemy" if mod.arrive_at == "back_line" else ""])
		if mod.swap_ticks > 0:
			parts.append("swaps with its farthest ally at %s%s" % [UnitInfo.seconds(mod.swap_ticks), " (or 5s or 15s, as you choose)" if mod.swap_choice else ""])
		if mod.swap_shield_bp > 0:
			parts.append("both Shielded %s of max HP" % ValueBreakdown._percent(mod.swap_shield_bp))
	if mod.prefer != null:
		parts.append("its attacks go for enemies that are %s first" % mod.prefer.describe())
	if mod.hop_within_add != 0:
		parts.append("hops away from %s hexes, not 1" % _hexes_text(HexGrid.HEX + mod.hop_within_add))
	if mod.hop_cooldown_add_ticks != 0:
		parts.append("hop cooldown %s%s" % ["+" if mod.hop_cooldown_add_ticks > 0 else "−", UnitInfo.seconds(absi(mod.hop_cooldown_add_ticks))])
	if mod.mana_per_attack_add != 0:
		parts.append("%s mana per attack" % signed(mod.mana_per_attack_add))
	if mod.mana_taken_bp != FixedMath.BP_ONE:
		parts.append("%s mana from damage taken" % UnitInfo.signed_percent(mod.mana_taken_bp - FixedMath.BP_ONE))
	if mod.plant_add_ticks != 0:
		parts.append("plants %s %s" % [UnitInfo.seconds(absi(mod.plant_add_ticks)), "sooner" if mod.plant_add_ticks < 0 else "later"])
	if mod.break_free_add_ticks != 0:
		parts.append("enemies it engages take %s longer to break free" % UnitInfo.seconds(mod.break_free_add_ticks))
	if mod.engage_reach_add != 0:
		@warning_ignore("integer_division")
		parts.append("its Engage reaches %d more hex%s" % [mod.engage_reach_add / HexGrid.HEX, "" if mod.engage_reach_add == HexGrid.HEX else "es"])
	if mod.places_lantern:
		parts.append("you place its first signature area before the fight")
	if mod.drops_signature:
		parts.append("no signature")
	for part_id: String in mod.drops_passives:
		var at: int = KitMod._passive_index(shown, KitMod.PASSIVE_PREFIX + part_id)
		parts.append("no %s" % (shown.passives[at].name if at >= 0 else part_id))
	for trigger: TriggerDef in mod.also_fires:
		var when: String = UnitInfo.trigger_text(trigger, shown)
		parts.append("Signature also fires: %s%s" % [when.left(1).to_lower(), when.substr(1)])
	if mod.echo_ticks > 0:
		parts.append("Signature fires again %s later at %s" % [UnitInfo.seconds(mod.echo_ticks), ValueBreakdown._percent(mod.echo_bp)])
	return parts


## One "on" entry: its slot, then each of its changes.
static func _change_text(change: KitMod.AbilityChange, mod: KitMod, kit: UnitDef, content: ContentDb) -> String:
	var bits: Array[String] = []
	if change.amount_bp != FixedMath.BP_ONE:
		bits.append("%s %s" % [UnitInfo.signed_percent(change.amount_bp - FixedMath.BP_ONE), _power_word(change)])
	if change.duration_bp != FixedMath.BP_ONE:
		bits.append("%s%s duration" % [UnitInfo.signed_percent(change.duration_bp - FixedMath.BP_ONE), _statuses_word(change, content)])
	if change.duration_add_ticks != 0:
		bits.append("%s%s%s duration" % ["+" if change.duration_add_ticks > 0 else "−", UnitInfo.seconds(absi(change.duration_add_ticks)), _statuses_word(change, content)])
	if change.radius_add != 0:
		bits.append("%s hex area" % signed(change.radius_add))
	if change.cooldown_bp != FixedMath.BP_ONE:
		bits.append("%s cooldown" % UnitInfo.signed_percent(change.cooldown_bp - FixedMath.BP_ONE))
	if change.after_add_ticks != 0:
		bits.append("%s %s" % [UnitInfo.seconds(absi(change.after_add_ticks)), "sooner" if change.after_add_ticks < 0 else "later"])
	if change.cast_bp != FixedMath.BP_ONE:
		bits.append("instant cast" if change.cast_bp == 0 else "%s cast time" % UnitInfo.signed_percent(change.cast_bp - FixedMath.BP_ONE))
	if change.targets_add > 0:
		bits.append("+%d target%s%s" % [change.targets_add, "" if change.targets_add == 1 else "s", " (without an area)" if change.one_of else ""])
	# Phase 5c step 7b's knobs.
	if change.every_add != 0:
		bits.append("%s sooner in its count" % _count_word(-change.every_add) if change.every_add < 0 else "%s later in its count" % _count_word(change.every_add))
	if change.times_add != 0:
		bits.append("+%d time%s a fight" % [change.times_add, "" if change.times_add == 1 else "s"])
	if change.max_standing_add != 0:
		bits.append("+%d standing at once" % change.max_standing_add)
	if change.overheal_add_bp != 0:
		bits.append("+%s of overheal as Shield" % ValueBreakdown._percent(change.overheal_add_bp))
	if change.width_add != 0:
		bits.append("+%d hex wider" % change.width_add)
	if change.value_add != 0:
		var aura: AuraDef = KitMod._slot_aura(kit, change.slot) if kit != null else null
		bits.append("%s %s" % [UnitInfo.signed_percent(change.value_add), AuraDef.STAT_LABELS[aura.stat]] if aura != null else signed(change.value_add))
	if change.guard_share_add != 0:
		bits.append("%s%% of each hit" % signed(change.guard_share_add / 100))
	if change.guard_within_add != 0:
		bits.append("%s hex reach" % signed(change.guard_within_add / HexGrid.HEX))
	if change.guard_covers_all:
		bits.append("covers every ally in reach, not only those behind")
	if change.prefer != null:
		bits.append("goes for enemies that are %s first" % change.prefer.describe())
	if change.strength_add_bp != 0:
		bits.append("+%s stronger" % ValueBreakdown._percent(change.strength_add_bp))
	# Phase 5c step 7d.
	if change.follows:
		bits.append("its area follows the biggest group, 1 hex a pulse")
	if change.ricochet_add != 0:
		bits.append("hits ricochet %d more time%s" % [change.ricochet_add, "" if change.ricochet_add == 1 else "s"])
	if change.reflect_bp != 0:
		bits.append("sends stopped shots back at %s" % ValueBreakdown._percent(change.reflect_bp))
	if change.snags:
		bits.append("its snares catch leaps and charges")
	# Phase 8 part 2 (the apex cards' knobs).
	if change.per_enemy_add_bp != 0:
		bits.append("%s for each enemy passed" % UnitInfo.signed_percent(change.per_enemy_add_bp))
	if change.overheal_max_hp_add != 0:
		bits.append("+1 max HP every %s overheal" % ("%d less" % -change.overheal_max_hp_add if change.overheal_max_hp_add < 0 else "%d more" % change.overheal_max_hp_add))
	if change.at_stacks_add != 0:
		bits.append("%s stacks to go off" % signed(change.at_stacks_add))
	if change.per_taken_add_bp != 0:
		bits.append("%s for every 1,000 damage taken" % UnitInfo.signed_percent(change.per_taken_add_bp))
	if change.grows_add_bp != 0:
		bits.append("%s stronger each cast" % UnitInfo.signed_percent(change.grows_add_bp))
	if change.grows_boosts_add_bp != 0:
		bits.append("its boosts %s stronger each cast" % UnitInfo.signed_percent(change.grows_boosts_add_bp))
	if change.rise_add_bp != 0:
		bits.append("rises with %s more of max HP" % ValueBreakdown._percent(change.rise_add_bp))
	if change.per_shared_bp != FixedMath.BP_ONE:
		bits.append("its link's stacks every %s as much shared" % ValueBreakdown._percent(change.per_shared_bp))
	if change.holder != null:
		bits.append("only while it's %s" % change.holder.describe())
	if change.carries:
		bits.append("its charge carries every enemy in its line")
	# Phase 8 part 4 (Garrow's cards).
	if change.mana_max_add != 0:
		bits.append("%s mana (as a habit: 1 attack %s)" % [signed(change.mana_max_add), "sooner" if change.mana_max_add < 0 else "later"])
	if change.ignores_def:
		bits.append("ignores DEF")
	if change.per_twice != null:
		bits.append("enemies that are %s count twice" % change.per_twice.describe())
	for effect: EffectDef in change.add_to_areas:
		bits.append("in its area: " + " · ".join(UnitInfo.effect_numbers([effect] as Array[EffectDef], kit, content)))
	for effect: EffectDef in change.add_effects:
		var effect_text: String = " · ".join(UnitInfo.effect_numbers([effect] as Array[EffectDef], kit, content))
		match effect.trigger:
			EffectDef.Trigger.ON_HIT:
				effect_text = "on hit: " + effect_text
			EffectDef.Trigger.ON_CRIT:
				effect_text = "on crit: " + effect_text
		bits.append(effect_text)
	if bits.is_empty():
		return ""
	if not change.ability_id.is_empty():
		return "%s: %s" % [change.ability_id.replace("_", " ").capitalize(), ", ".join(bits)]
	return "%s: %s" % [_slot_name(change.slot), ", ".join(bits)]


## "1 step" or "2 steps" (an "every" count's change).
static func _count_word(steps: int) -> String:
	return "%d step%s" % [steps, "" if steps == 1 else "s"]


## " Stealth" for a change only to some statuses (phase 5c step 5b), else "".
static func _statuses_word(change: KitMod.AbilityChange, content: ContentDb) -> String:
	var names: Array[String] = []
	for status_id: String in change.statuses:
		names.append(content.statuses[status_id].name if content.statuses.has(status_id) else status_id)
	return "" if names.is_empty() else " " + " and ".join(names)


## "1.5" for 1500 plane units.
static func _hexes_text(units: int) -> String:
	@warning_ignore("integer_division")
	var whole: int = units / HexGrid.HEX
	@warning_ignore("integer_division")
	var tenths: int = (units % HexGrid.HEX) / 100
	return "%d" % whole if tenths == 0 else "%d.%d" % [whole, tenths]


static func _slot_name(slot: String) -> String:
	if slot.begins_with(KitMod.PASSIVE_PREFIX):
		return slot.trim_prefix(KitMod.PASSIVE_PREFIX).replace("_", " ").capitalize()
	return SLOT_NAMES.get(slot, slot)


## "damage", "healing", "damage and healing", or "effects" (any type).
static func _power_word(change: KitMod.AbilityChange) -> String:
	if change.types.is_empty():
		return "effects"
	var words: Array[String] = []
	for type: EffectDef.Type in change.types:
		words.append(POWER_WORDS.get(type, EffectDef.TYPE_NAMES[type].replace("_", " ")))
	return " and ".join(words)


## An item's numbers line at `rank` (1 to 3): its mod's, or its tactic's.
static func item_numbers(item: ItemDef, kit: UnitDef, content: ContentDb, rank: int = 1) -> String:
	if item.tactic != null:
		return UnitInfo.tactic_numbers(item.tactic.at_rank(rank))
	var mod: KitMod = item.mod_at(rank)
	return mod_numbers(mod, kit, content) if mod != null else ""


## What an item's next rank brings, as "Rank II: ..." ("" at rank III).
static func next_rank_line(item: ItemDef, content: ContentDb, rank: int) -> String:
	if rank >= ItemDef.RANKS:
		return ""
	return "Rank %s: %s" % [ItemDef.RANK_NAMES[rank], item_numbers(item, null, content, rank + 1)]


## An upgrade's: its mod's, what changes once the hero transforms, and how
## it grows (a stacking card's share: "+10% of ATK when taken").
static func upgrade_numbers(upgrade: UpgradeDef, kit: UnitDef, content: ContentDb) -> String:
	if upgrade.stacks():
		return "+%d%% of %s when taken (stacks)" % [upgrade.stack_pct, _stat_word(upgrade.stack_stat)]
	var parts: Array[String] = []
	if upgrade.mod != null:
		parts = mod_parts(upgrade.mod, kit, content)
	if upgrade.transformed_mod != null:
		parts.append("transformed: " + mod_numbers(upgrade.transformed_mod, kit, content))
	if upgrade.grows != null:
		parts.append(growth_numbers(upgrade.grows, kit, content))
	return " · ".join(parts)


## A stacking card on the pick: what it would lock in now ("+2 ATK now ·
## stacks").
static func stack_now(upgrade: UpgradeDef, amount: int) -> String:
	return "%s now · stacks" % _locked_amount(upgrade, amount)


## A stacking card held: each take's locked amount ("+2, +3, +5 ATK").
static func stack_locked(upgrade: UpgradeDef, locked: Array) -> String:
	var amounts: Array[String] = []
	var unit: String = "%" if upgrade.stack_stat == UnitStats.Stat.ATSP else ""
	for amount: Variant in locked:
		amounts.append("+%d%s" % [int(amount), unit])
	return "%s %s" % [", ".join(amounts), _stat_word(upgrade.stack_stat)]


## "+2 ATK", or "+11% attack speed" (ATSP points are percents).
static func _locked_amount(upgrade: UpgradeDef, amount: int) -> String:
	return "+%d%s %s" % [amount, "%" if upgrade.stack_stat == UnitStats.Stat.ATSP else "", _stat_word(upgrade.stack_stat)]


## A stat's name on a card: "ATK", "max HP", "attack speed".
static func _stat_word(stat: int) -> String:
	match stat:
		UnitStats.Stat.HP:
			return "max HP"
		UnitStats.Stat.ATSP:
			return "attack speed"
	return UnitStats.STAT_NAMES[stat].to_upper()


## How a growing card grows (phase 5c step 4): "Grows: +1% ATK per 10
## enemies Marked".
static func growth_numbers(growth: GrowthDef, kit: UnitDef, content: ContentDb) -> String:
	var step: String = step_text(growth.each, kit, content) if growth.each.changes_anything() else ""
	if growth.each_shards > 0:
		step = ("%s, " % step if not step.is_empty() else "") + "+%d shard%s" % [growth.each_shards, "" if growth.each_shards == 1 else "s"]
	var what: String = "%d elites won" % growth.per if growth.run_counts == "elite_wins" else counted(growth.counts, growth.per)
	var text: String = "Grows: %s per %s" % [step, what]
	if growth.max_steps > 0:
		text += " (at most %d time%s)" % [growth.max_steps, "" if growth.max_steps == 1 else "s"]
	return text


## Where a held growing card is: "Now: +3% ATK (4 / 10 enemies Marked to
## the next)", or "Now: nothing yet (...)".
static func growth_now(growth: GrowthDef, count: int, kit: UnitDef, content: ContentDb) -> String:
	var steps: int = growth.steps(count)
	var now: String = "nothing yet"
	if steps > 0:
		now = step_text(growth.each.times(steps), kit, content) if growth.each.changes_anything() else "+%d shards so far" % (steps * growth.each_shards)
	if growth.max_steps > 0 and steps >= growth.max_steps:
		return "Now: %s (done)" % now
	var what: String = "%d elites won" % growth.per if growth.run_counts == "elite_wins" else counted(growth.counts, growth.per)
	return "Now: %s (%s / %s to the next)" % [now, str(count % growth.per) if growth.run_counts != "" else _amount(growth.counts, count % growth.per), what]


## One step's (or several steps') change, the way a card says it: an added
## aura's amount, without its name.
static func step_text(mod: KitMod, kit: UnitDef, content: ContentDb) -> String:
	var bare: KitMod = KitMod.make()
	bare.stats_bp = mod.stats_bp
	bare.stats_add = mod.stats_add
	bare.changes = mod.changes
	var parts: Array[String] = mod_parts(bare, kit, content)
	for part: PartDef in mod.passives:
		if part.kind == PartDef.Kind.AURA:
			parts.append(UnitInfo.aura_text(part.aura))
	return ", ".join(parts)


## What a growing card counts, `per` of it: "10 enemies Marked", "300
## damage dealt from beyond 4 hexes", "3s below 30% HP".
static func counted(counts: DeedDef, per: int) -> String:
	var amount: String = _amount(counts, per)
	match counts.counts:
		DeedDef.Counts.DAMAGE:
			var what: String = "%s damage dealt" % amount
			if counts.from_range > 0:
				@warning_ignore("integer_division")
				what += " from beyond %s" % UnitInfo.hexes(counts.from_range / HexGrid.HEX)
			if counts.from_basic:
				what += " by basic attacks"
			if not counts.from_ability.is_empty():
				what += " by " + ", ".join(counts.from_ability).replace("_", " ")
			return what
		DeedDef.Counts.HEALING:
			return "%s healing given%s" % [amount, " beside the target" if counts.off_target else ""]
		DeedDef.Counts.SHIELD:
			return "%s Shield given%s" % [amount, "" if counts.from_ability.is_empty() else " by " + ", ".join(counts.from_ability).replace("_", " ")]
		DeedDef.Counts.PULLED:
			return "%s enemies pulled" % amount
		DeedDef.Counts.EXTRA_HITS:
			return "%s extra enemies hit" % amount
		DeedDef.Counts.HITS:
			var hits: String = "%s hits on enemies" % amount
			if not counts.from_ability.is_empty():
				hits += " by " + ", ".join(counts.from_ability).replace("_", " ")
			return hits
		DeedDef.Counts.ROOTED_MS:
			return "%s of Root" % amount
		DeedDef.Counts.GUARDED:
			return "%s damage taken for allies" % amount
		DeedDef.Counts.SHARED:
			return "%s damage shared through links" % amount
		DeedDef.Counts.BLOCKED:
			return "%s enemy shots stopped by walls" % amount
		DeedDef.Counts.APPLIED:
			if counts.keywords.is_empty():
				return "%s statuses put on enemies" % amount
			var names: Array[String] = []
			for keyword: String in counts.keywords:
				names.append(Keywords.label(keyword))
			return "%s enemies %s" % [amount, " or ".join(names)]
		DeedDef.Counts.TAKEN:
			return "%s damage taken%s" % [amount, " after rising" if counts.after_rising else ""]
		DeedDef.Counts.MS_BELOW:
			return "%s below %s HP" % [amount, ValueBreakdown._percent(counts.while_below_bp)]
		DeedDef.Counts.KILLS:
			return "%s kills" % amount
		DeedDef.Counts.CRITS:
			return "%s crits" % amount
		DeedDef.Counts.OVERKILL:
			return "%s overkill damage" % amount
	return amount


## An amount of what's counted: time kinds in seconds.
static func _amount(counts: DeedDef, value: int) -> String:
	if counts.counts == DeedDef.Counts.ROOTED_MS or counts.counts == DeedDef.Counts.MS_BELOW:
		@warning_ignore("integer_division")
		return UnitInfo.seconds(value / FixedMath.MS_PER_TICK)
	return str(value)


## A relic's: its mods, each for whom it's for, then its run rules.
static func relic_numbers(relic: RelicDef, content: ContentDb) -> String:
	var parts: Array[String] = []
	if relic.mod != null:
		parts.append(("Ranged heroes: " if relic.mod_for_ranged else "Heroes: ") + mod_numbers(relic.mod, null, content))
	if relic.rules != null:
		parts.append_array(rules_numbers(relic.rules, content))
	if relic.enemy_mod != null:
		parts.append("Enemies: " + mod_numbers(relic.enemy_mod, null, content))
	if relic.slots_add != 0:
		parts.append("%s loadout slot%s" % [signed(relic.slots_add), "" if absi(relic.slots_add) == 1 else "s"])
	if relic.always_scout:
		parts.append("every fight Scouted")
	if relic.price_add != 0:
		parts.append("%s shard on every price at the Pedlar (at least 1)" % signed(relic.price_add))
	if relic.pay_add != 0:
		parts.append("%s shards per won fight" % signed(relic.pay_add))
	if relic.elite_pay_add != 0:
		parts.append("%s shards per won elite" % signed(relic.elite_pay_add))
	if relic.wound_price_add != 0:
		parts.append("%s shards to treat a wound" % signed(relic.wound_price_add))
	if relic.shop_shards != 0:
		parts.append("%s shards at every shop" % signed(relic.shop_shards))
	if relic.miser:
		parts.append("at every shop, +1 shard per 5 held (at most 6)")
	if relic.free_reroll:
		parts.append("the first reroll in every shop is free")
	if relic.flat_rerolls:
		parts.append("rerolls never cost more")
	if relic.shop_relics_add != 0 or relic.wares_add != 0:
		parts.append("%s relic and %s ware in every shop" % [signed(relic.shop_relics_add), signed(relic.wares_add)])
	if relic.pick_cards_add != 0:
		parts.append("%s card on each pick" % signed(relic.pick_cards_add))
	if relic.take_picks_add != 0:
		parts.append("take %d cards from each pick" % (1 + relic.take_picks_add))
	if relic.streak_wins > 0:
		parts.append("%s shards, once, for %d won fights in a row with no hero falling" % [signed(relic.streak_shards), relic.streak_wins])
	if relic.growth_bp > 0:
		parts.append("growing cards count x%s as fast" % ValueBreakdown._ratio(relic.growth_bp))
	if relic.per_relic_bp > 0:
		parts.append("Heroes: %s HP, ATK, MGK, DEF, CRIT, and ATSP per relic held" % UnitInfo.signed_percent(relic.per_relic_bp))
	if relic.per_shards > 0:
		parts.append("Heroes: %s ATK and MGK per %d shards held" % [UnitInfo.signed_percent(relic.per_shards_bp), relic.per_shards])
	if relic.covenant:
		parts.append("each hero has the team's highest HP, ATK, MGK, DEF, CRIT, and ATSP")
	if not relic.at_start.is_empty():
		parts.append("As a fight starts: " + ", ".join(UnitInfo.effect_numbers(relic.at_start, _any_hero(), content)))
	if relic.salt_circle:
		parts.append("the first enemy area each fight lands on nothing")
	if relic.doubles_commons:
		parts.append("every common relic held counts twice: its numbers doubled (not an ability's)")
	if relic.grows != null:
		parts.append("%s, counted for the whole team" % growth_numbers(relic.grows, null, content))
	return " · ".join(parts)


## A relic's hero rules, each as a line (phase 5c step 5c).
static func rules_numbers(rules: SideRules, content: ContentDb) -> Array[String]:
	var parts: Array[String] = []
	if rules.marks_stack:
		parts.append("Marks heroes apply stack")
	if rules.crit_steps > 0:
		parts.append("a crit rolls again up to %d times, each step %s less likely and weaker" % [rules.crit_steps, ValueBreakdown._percent(rules.crit_fade_bp)])
	if rules.echo_steps > 0:
		parts.append("damage echoes to enemies sharing a keyword at %s, %d steps deep" % [ValueBreakdown._percent(rules.echo_share_bp), rules.echo_steps])
	if rules.carry_steps > 0:
		parts.append("overkill carries to the nearest enemy, up to %d times" % rules.carry_steps)
	if rules.overcharge_steps > 0:
		parts.append("each full bar past the first fires the signature again, %s more power each time, up to %d more" % [UnitInfo.signed_percent(rules.overcharge_power_bp), rules.overcharge_steps])
	if rules.rise_ticks > 0:
		parts.append("a hero's first fall: it rises after %s at %s HP" % [UnitInfo.seconds(rules.rise_ticks), ValueBreakdown._percent(rules.rise_hp_bp)])
	if rules.deeper_steps > 0:
		parts.append("every chain the heroes start goes %d steps deeper, each step %s stronger than the last" % [rules.deeper_steps, UnitInfo.signed_percent(rules.deeper_grow_bp)])
	if rules.keywords_twice:
		parts.append("keywords heroes apply: double stacks or double duration")
	if rules.keywords_last:
		parts.append("keywords heroes put on enemies last the whole fight and can't be removed")
	if rules.unbending:
		parts.append("statuses enemies apply to heroes are blocked; each gives that hero %s for the fight" % _boost(content, "unbending"))
	if rules.collapse_immune:
		parts.append("heroes take no damage from crumbled ground")
	if rules.collapse_enemy_bp > 0:
		parts.append("enemies on crumbled ground take %s of max HP a second more" % ValueBreakdown._percent(rules.collapse_enemy_bp))
	if rules.watch_every_ticks > 0:
		parts.append("no tie until %s; from %s, every hero %s every %s" % [UnitInfo.seconds(rules.watch_tie_ticks), UnitInfo.seconds(rules.watch_from_ticks),
			_boost(content, "long_watch"), UnitInfo.seconds(rules.watch_every_ticks)])
	return parts


## A boost status's numbers, without "a stack" ("+1% DEF, +1% max HP").
static func _boost(content: ContentDb, status_id: String) -> String:
	if not content.statuses.has(status_id):
		return status_id
	var status: StatusDef = content.statuses[status_id]
	var parts: Array[String] = []
	for i: int in status.boost_stats.size():
		var aura := AuraDef.new()
		aura.stat = status.boost_stats[i] as AuraDef.Stat
		aura.value = status.boost_values[i]
		parts.append(UnitInfo.aura_text(aura))
	return ", ".join(parts)


## A whole number with its sign: "+2", "−12" (the minus UnitInfo's percents use).
static func signed(value: int) -> String:
	return ("+" if value >= 0 else "−") + str(absi(value))


## A stand-in kit for a card that's for any hero (no stats to scale from).
static func _any_hero() -> UnitDef:
	var kit := UnitDef.new()
	kit.stats = UnitStats.make(0)
	return kit
