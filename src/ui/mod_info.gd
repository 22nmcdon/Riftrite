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
		bits.append("%s duration" % UnitInfo.signed_percent(change.duration_bp - FixedMath.BP_ONE))
	if change.duration_add_ticks != 0:
		bits.append("%s%s duration" % ["+" if change.duration_add_ticks > 0 else "−", UnitInfo.seconds(absi(change.duration_add_ticks))])
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


## An upgrade's: its mod's, and what changes once the hero transforms.
static func upgrade_numbers(upgrade: UpgradeDef, kit: UnitDef, content: ContentDb) -> String:
	var parts: Array[String] = mod_parts(upgrade.mod, kit, content)
	if upgrade.transformed_mod != null:
		parts.append("transformed: " + mod_numbers(upgrade.transformed_mod, kit, content))
	return " · ".join(parts)


## A relic's: its mods, each for whom it's for, then its run rules.
static func relic_numbers(relic: RelicDef, content: ContentDb) -> String:
	var parts: Array[String] = []
	if relic.mod != null:
		parts.append("Heroes: " + mod_numbers(relic.mod, null, content))
	if relic.enemy_mod != null:
		parts.append("Enemies: " + mod_numbers(relic.enemy_mod, null, content))
	if relic.rest_mod != null:
		parts.append("After a Rest: " + mod_numbers(relic.rest_mod, null, content))
	if relic.slots_add != 0:
		parts.append("%s loadout slot%s" % [signed(relic.slots_add), "" if absi(relic.slots_add) == 1 else "s"])
	if relic.wound_bp_add != 0:
		parts.append("%s HP lost per wound" % UnitInfo.signed_percent(relic.wound_bp_add))
	if relic.always_scout:
		parts.append("every fight Scouted")
	if relic.price_add != 0:
		parts.append("%s shard on every price" % signed(relic.price_add))
	if relic.pay_add != 0:
		parts.append("%s shards per won fight" % signed(relic.pay_add))
	if relic.pick_cards > 0:
		parts.append("%d cards on each pick" % relic.pick_cards)
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
