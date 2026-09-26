class_name ItemInfo
extends RefCounted
## Tooltip text for items and relics: what an item is and what it does, with
## each number's base -> stat-scaled -> final breakdown (ItemState's own
## derivation, so the UI never re-implements game math).


## When an effect happens, in plain words (by EffectDef.Trigger).
const TRIGGER_WORDS: Array[String] = ["When it fires", "On hit", "On a crit", "At the fight's start", "At %s", "When an ally drops below %s HP"]
## Who an effect lands on (by EffectDef.Target).
const TARGET_WORDS: Array[String] = [
	"the unit it hit", "its holder", "the most-hurt ally", "the front enemy", "a back-row enemy",
	"a random enemy", "the most-hurt enemy", "its linked ally", "every enemy", "every ally",
	"the ally to its left", "the ally to its right", "its linked allies", "allies in its row", "that ally",
]
## Which items a charge speeds up (by EffectDef.ItemTarget).
const ITEM_TARGET_WORDS: Array[String] = ["itself", "the item to its left", "the item to its right", "the items beside it", "every item in its row", "its partner items"]


static func item_text(content: ContentDb, item_id: String, tier: int, essence_ids: Array[String], xp: int, holder_stats: UnitStats = null, trace_bp: int = 0) -> String:
	var def: ItemDef = content.items[item_id]
	var essences: Array[EssenceDef] = []
	for essence_id: String in essence_ids:
		essences.append(content.essences[essence_id])
	var stats: UnitStats = holder_stats if holder_stats != null else UnitStats.make(1)
	var state: ItemState = ItemState.make(def, 0, stats, content, essences, tier, xp, trace_bp)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s  (%s, tier %s)" % [def.name, def.rarity.capitalize(), TuningDef.TIER_LABELS[tier]])
	var kind: PackedStringArray = PackedStringArray(["%d slot%s" % [def.size, "" if def.size == 1 else "s"]])
	if def.auto_attack:
		kind.append("auto-attack (replaces the basic attack)")
	if def.enemy_only:
		kind.append("enemy-only")
	if not def.tags.is_empty():
		kind.append(", ".join(def.tags))
	lines.append(" · ".join(kind))
	if not def.effects.is_empty():
		lines.append("Fires every %ss" % _seconds(state.cooldown_ticks))
	var sockets: int = content.tuning.socket_count(def)
	if essences.is_empty():
		lines.append("Sockets: %d empty" % sockets)
	else:
		lines.append("Infusion: %s, %s (%d XP)%s" % [state.infusion_name(), Infusions.LEVEL_NAMES[state.infusion_level], xp,
			"" if essences.size() >= sockets else ", 1 socket free"])
	lines.append("")
	for sourced: SourcedEffect in state.effects:
		lines.append("• " + effect_line(content, sourced))
	for aura: AuraDef in def.auras:
		lines.append("• Aura: " + aura.describe())
	if def.backup != null:
		lines.append("• Backup mode: acts from the bench")
	if def.legendary != null:
		lines.append("• Never combines. Upgrade path: %s (starts at %s)" % [LegendaryDef.NAMES[def.legendary.path], TuningDef.TIER_LABELS[def.legendary.start_tier]])
	if holder_stats == null:
		lines.append("")
		lines.append("(numbers shown without a holder's stats)")
	return "\n".join(lines)


## One effect in plain words, with its number's breakdown, e.g. "When it
## fires: deal 9 damage to the front enemy (base 3 + 40% ATK 6 = 9)".
static func effect_line(content: ContentDb, sourced: SourcedEffect) -> String:
	var value: ValueBreakdown = sourced.value
	var line: String = effect_words(content, sourced.effect, value.final)
	var origin: String = sourced.infusion_name
	if not sourced.granted_by.is_empty():
		origin = sourced.granted_by
	elif not sourced.transformed_by.is_empty():
		origin = sourced.transformed_by
	if not origin.is_empty():
		line += " [%s]" % origin
	var detail: String = value.to_text()
	if detail != str(value.final):
		line += "\n    " + detail.trim_prefix(str(value.final) + " ")
	return line


## "<when>: <what>" for an effect with this final amount (stacks for a
## status, ticks for a charge).
static func effect_words(content: ContentDb, effect: EffectDef, amount: int) -> String:
	var when: String = TRIGGER_WORDS[effect.trigger]
	if effect.trigger == EffectDef.Trigger.AT_TIME:
		when = when % (_seconds(effect.at_ticks) + "s")
	elif effect.trigger == EffectDef.Trigger.ON_ALLY_BELOW_HP:
		@warning_ignore("integer_division")
		when = when % ("%d%%" % (effect.threshold_bp / 100))
	var who: String = TARGET_WORDS[effect.target]
	var what: String
	match effect.type:
		EffectDef.Type.DAMAGE:
			what = "deal %d damage to %s" % [amount, who]
		EffectDef.Type.HEAL:
			what = "heal %s for %d" % [who, amount]
		EffectDef.Type.SHIELD:
			what = "shield %s for %d" % [who, amount]
		EffectDef.Type.APPLY_STATUS:
			var status: String = content.statuses[effect.status_id].name if content.statuses.has(effect.status_id) else effect.status_id
			what = "apply %d %s to %s" % [amount, status, who]
		EffectDef.Type.CHARGE:
			what = "speed up %s by %ss" % [ITEM_TARGET_WORDS[effect.item_target], _seconds(amount)]
		_:
			what = "cleanse %d from %s" % [amount, who]
	return "%s: %s" % [when, what]


## Ticks as seconds, e.g. 24 -> "1.2" (display only).
static func _seconds(ticks: int) -> String:
	return String.num(ticks / float(FixedMath.TICKS_PER_SECOND), 2)


## A hero on offer (or held): class, stats at that rank, basic attack, and
## Backup effect.
static func hero_text(content: ContentDb, hero_id: String, rank: int) -> String:
	var def: HeroDef = content.heroes[hero_id]
	var stats: UnitStats = def.stats.boosted(content.tuning.rank_multiplier_bp[rank])
	var lines: PackedStringArray = PackedStringArray(["%s  (%s, rank %s)" % [def.name, def.hero_class.capitalize(), TuningDef.TIER_LABELS[rank]]])
	lines.append(stat_line(stats))
	lines.append("%d item slots" % HeroDef.slots_at_rank(rank))
	lines.append("")
	var basic: ItemState = ItemState.make(def.basic_attack, 0, stats, content)
	lines.append("Basic attack: %s, every %ss" % [def.basic_attack.name, _seconds(basic.cooldown_ticks)])
	for sourced: SourcedEffect in basic.effects:
		lines.append("• " + effect_line(content, sourced))
	if def.backup != null:
		lines.append("")
		lines.append("Backup: %s (acts while this hero sits in backup)" % def.backup.name)
	return "\n".join(lines)


static func stat_line(stats: UnitStats) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for stat: int in UnitStats.LABELS.size():
		parts.append("%s %d" % [UnitStats.LABELS[stat], stats.get_stat(stat)])
	return "  ".join(parts)


static func relic_text(content: ContentDb, relic_id: String) -> String:
	var def: RelicDef = content.relics[relic_id]
	var lines: PackedStringArray = PackedStringArray(["%s  (%s relic)" % [def.name, def.rarity.capitalize()], "Shared by the whole guild; can't be removed once taken.", ""])
	for aura: AuraDef in def.auras:
		lines.append("• Aura: " + aura.describe())
	for grant: GrantDef in def.grants:
		lines.append("• Gives %s items: %s" % ["matching" if grant.filter != null else "all", effect_words(content, grant.effect, _flat(grant.effect))])
	for effect: EffectDef in def.effects:
		lines.append("• " + effect_words(content, effect, _flat(effect)))
	return "\n".join(lines)


## A synergy: what sets it off, and what it does.
static func synergy_text(content: ContentDb, synergy_id: String) -> String:
	var def: SynergyDef = content.synergies[synergy_id]
	var lines: PackedStringArray = PackedStringArray(["%s  (%s)" % [def.name, SynergyDef.LAYER_NAMES[def.layer].replace("_", " ")]])
	var item_names: PackedStringArray = PackedStringArray()
	for item_id: String in def.items:
		item_names.append(content.items[item_id].name)
	match def.layer:
		SynergyDef.Layer.PAIR:
			lines.append("When one fielded hero holds %s." % " and ".join(item_names))
		SynergyDef.Layer.TRANSFORMATION:
			lines.append("%s infused with %s: the item works differently (and never spills)." % [item_names[0], content.essences[def.essence].name])
		SynergyDef.Layer.SIGNATURE:
			lines.append("When %s, fielded, holds %s." % [content.heroes[def.hero].name, item_names[0]])
		SynergyDef.Layer.RESONANCE:
			lines.append("Counting %s essences in the guild's items (fielded and backup):" % content.essences[def.essence].name)
		SynergyDef.Layer.CLASS_TRAIT:
			lines.append("Counting fielded %ss:" % def.unit_class.capitalize())
	lines.append("")
	if def.is_tiered():
		for tier: SynergyDef.Tier in def.tiers:
			lines.append("%d+:" % tier.count)
			lines.append_array(_bonus_lines(content, tier.bonus))
	elif def.layer == SynergyDef.Layer.TRANSFORMATION:
		for effect: EffectDef in def.item_effects:
			lines.append("• " + effect_words(content, effect, _flat(effect)))
	else:
		lines.append_array(_bonus_lines(content, def.bonus))
	return "\n".join(lines)


static func _bonus_lines(content: ContentDb, bonus: RelicDef) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if bonus == null:
		return lines
	for aura: AuraDef in bonus.auras:
		lines.append("• Aura: " + aura.describe())
	for grant: GrantDef in bonus.grants:
		lines.append("• Gives %s: %s" % ["matching items" if grant.filter != null else "the items", effect_words(content, grant.effect, _flat(grant.effect))])
	for effect: EffectDef in bonus.effects:
		lines.append("• " + effect_words(content, effect, _flat(effect)))
	return lines


## An effect's flat number (stacks for a status).
static func _flat(effect: EffectDef) -> int:
	return effect.stacks if effect.type == EffectDef.Type.APPLY_STATUS else effect.amount


## A hero's rank-adjusted stats, for item numbers on their row.
static func hero_stats(content: ContentDb, hero: RunHero) -> UnitStats:
	return content.heroes[hero.hero_id].stats.boosted(content.tuning.rank_multiplier_bp[hero.rank])
