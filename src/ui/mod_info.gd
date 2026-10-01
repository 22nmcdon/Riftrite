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
	if mod.mana_max_add != 0:
		parts.append("%s max mana" % signed(mod.mana_max_add))
	if mod.mana_start_add != 0:
		parts.append("%s starting mana" % signed(mod.mana_start_add))
	if mod.mana_per_attack_add != 0:
		parts.append("%s mana per attack" % signed(mod.mana_per_attack_add))
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
	return "%s: %s" % [_slot_name(change.slot), ", ".join(bits)]


## " Stealth" for a change only to some statuses (phase 5c step 5b), else "".
static func _statuses_word(change: KitMod.AbilityChange, content: ContentDb) -> String:
	var names: Array[String] = []
	for status_id: String in change.statuses:
		names.append(content.statuses[status_id].name if content.statuses.has(status_id) else status_id)
	return "" if names.is_empty() else " " + " and ".join(names)


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


## An item's numbers line: its mod's, or its tactic's.
static func item_numbers(item: ItemDef, kit: UnitDef, content: ContentDb) -> String:
	if item.tactic != null:
		return UnitInfo.tactic_numbers(item.tactic)
	return mod_numbers(item.mod, kit, content) if item.mod != null else ""


## An upgrade's: its mod's, what changes once the hero transforms, and how
## it grows.
static func upgrade_numbers(upgrade: UpgradeDef, kit: UnitDef, content: ContentDb) -> String:
	var parts: Array[String] = []
	if upgrade.mod != null:
		parts = mod_parts(upgrade.mod, kit, content)
	if upgrade.transformed_mod != null:
		parts.append("transformed: " + mod_numbers(upgrade.transformed_mod, kit, content))
	if upgrade.grows != null:
		parts.append(growth_numbers(upgrade.grows, kit, content))
	return " · ".join(parts)


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
			return "%s Shield given" % amount
		DeedDef.Counts.EXTRA_HITS:
			return "%s extra enemies hit" % amount
		DeedDef.Counts.ROOTED_MS:
			return "%s of Root" % amount
		DeedDef.Counts.GUARDED:
			return "%s damage taken for allies" % amount
		DeedDef.Counts.APPLIED:
			if counts.keywords.is_empty():
				return "%s statuses put on enemies" % amount
			var names: Array[String] = []
			for keyword: String in counts.keywords:
				names.append(Keywords.label(keyword))
			return "%s enemies %s" % [amount, " or ".join(names)]
		DeedDef.Counts.TAKEN:
			return "%s damage taken" % amount
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
		parts.append("Heroes: " + mod_numbers(relic.mod, null, content))
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


## A duo bond's, for the hero on `path_id`.
static func bond_numbers(bond: BondDef, path_id: String, kit: UnitDef, content: ContentDb) -> String:
	return mod_numbers(bond.mods[path_id], kit, content) if bond.mods.has(path_id) else ""


## A whole number with its sign: "+2", "−12" (the minus UnitInfo's percents use).
static func signed(value: int) -> String:
	return ("+" if value >= 0 else "−") + str(absi(value))


## A stand-in kit for a card that's for any hero (no stats to scale from).
static func _any_hero() -> UnitDef:
	var kit := UnitDef.new()
	kit.stats = UnitStats.make(0)
	return kit
