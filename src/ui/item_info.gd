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
	"a random enemy", "the most-hurt enemy", "every enemy", "every ally", "allies in its row", "that ally",
]
## Which items a charge speeds up (by EffectDef.ItemTarget).
const ITEM_TARGET_WORDS: Array[String] = ["itself", "its holder's other items", "its partner items"]


## `received`: lines about the keyword spills the item gets from its holder
## (see spills_received), shown under its infusion.
static func item_text(content: ContentDb, item_id: String, tier: int, essence_ids: Array[String], xp: int, holder_stats: UnitStats = null, trace_bp: int = 0, received: PackedStringArray = PackedStringArray()) -> String:
	var def: ItemDef = content.items[item_id]
	var essences: Array[EssenceDef] = []
	for essence_id: String in essence_ids:
		essences.append(content.essences[essence_id])
	var stats: UnitStats = holder_stats if holder_stats != null else UnitStats.make(1)
	var state: ItemState = ItemState.make(def, 0, stats, content, essences, tier, xp, trace_bp)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s  (%s, tier %s)" % [def.name, def.rarity.capitalize(), TuningDef.TIER_LABELS[tier]])
	var kind: PackedStringArray = PackedStringArray([ItemDef.SLOT_LABELS[def.slot]])
	if def.auto_attack:
		kind[0] += " (replaces the hero's own)"
	if def.enemy_only:
		kind.append("enemy-only")
	if not def.tags.is_empty():
		kind.append(", ".join(def.tags))
	lines.append(" · ".join(kind))
	lines.append("Keywords: %s" % keyword_names(content, def.keywords))
	if not def.effects.is_empty():
		lines.append("Fires every %ss" % _seconds(state.cooldown_ticks))
	lines.append_array(infusion_lines(content, state))
	lines.append_array(received)
	lines.append("")
	for sourced: SourcedEffect in state.effects:
		lines.append("• " + effect_line(content, sourced))
	for aura: AuraDef in def.auras:
		lines.append("• Aura: " + aura.describe())
	if def.legendary != null:
		lines.append("• Never combines. Upgrade path: %s (starts at %s)" % [LegendaryDef.NAMES[def.legendary.path], TuningDef.TIER_LABELS[def.legendary.start_tier]])
	if holder_stats == null:
		lines.append("")
		lines.append("(numbers shown without a holder's stats)")
	return "\n".join(lines)


## "Blade, Bleed".
static func keyword_names(content: ContentDb, keyword_ids: Array[String]) -> String:
	var names: PackedStringArray = PackedStringArray()
	for keyword: String in keyword_ids:
		names.append(content.keywords[keyword].name if content.keywords.has(keyword) else keyword)
	return ", ".join(names)


## The infusion in plain words: what it is, its level, and what it spills or
## awakens into (docs/plans/infusion-rework.md).
static func infusion_lines(content: ContentDb, state: ItemState) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if state.essences.is_empty():
		lines.append("Infusion: empty (holds up to %d essences)" % Infusions.MAX_ESSENCES)
		return lines
	lines.append("Infusion: %s, %s (%d XP)" % [state.infusion_name(), Infusions.LEVEL_NAMES[state.infusion_level], state.infusion_xp])
	var keywords: String = keyword_names(content, state.def.keywords).replace(", ", " or ")
	@warning_ignore("integer_division")
	var share: int = content.tuning.spill_single_bp / 100
	if state.essences.size() == 1:
		var essence: String = state.essences[0].name
		if state.spills():
			lines.append("Spills %d%% of its %s to its holder's other %s items." % [share, essence, keywords])
		else:
			lines.append("At Resonant it spills %d%% of its %s to its holder's other %s items. A second essence fuses with it instead." % [share, essence, keywords])
	elif state.alloy == null:
		lines.append("No named alloy for this pair yet: it gives both essences' effects, and has nothing to awaken.")
	elif state.awakened():
		lines.append("Awakened: %s" % alloy_words(content, state.alloy))
	else:
		lines.append("Awakens at Resonant: %s" % alloy_words(content, state.alloy))
	return lines


## What an alloy's special does, e.g. "its Burn lands as Golden Flame".
static func alloy_words(content: ContentDb, alloy: AlloyDef) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var replaced: Array = alloy.replaces.keys()
	replaced.sort()
	for from_status: String in replaced:
		parts.append("its %s lands as %s" % [_status_name(content, from_status), _status_name(content, alloy.replaces[from_status])])
	if alloy.heal_echo_bp > 0:
		@warning_ignore("integer_division")
		parts.append("each heal echoes %d%% onto another ally" % (alloy.heal_echo_bp / 100))
	return "; ".join(parts) + "."


static func _status_name(content: ContentDb, status_id: String) -> String:
	return content.statuses[status_id].name if content.statuses.has(status_id) else status_id


## The keyword spills an equipped item gets from its holder's other items,
## in plain words ("Gets 30% Ember spill from Hearth Knife"). Empty for the
## stash.
static func spills_received(content: ContentDb, holder: RunHero, item: RunItem) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if holder == null:
		return lines
	var states: Array[ItemState] = []
	var target: ItemState = null
	for held: RunItem in holder.items:
		var essences: Array[EssenceDef] = []
		for essence_id: String in held.essence_ids:
			essences.append(content.essences[essence_id])
		var state: ItemState = ItemState.make(content.items[held.item_id], 0, UnitStats.make(1), content, essences, held.tier, held.xp)
		states.append(state)
		if held == item:
			target = state
	if target == null:
		return lines
	@warning_ignore("integer_division")
	var share: int = content.tuning.spill_single_bp / 100
	for app: EssenceApplication in ItemState.spills_into(target, states, content.tuning):
		lines.append("Gets %d%% %s" % [share, app.label])
	return lines


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


## A hero on offer (or held): class, stats at that rank, slots, basic
## attack, and innate.
static func hero_text(content: ContentDb, hero_id: String, rank: int) -> String:
	var def: HeroDef = content.heroes[hero_id]
	var stats: UnitStats = def.stats.boosted(content.tuning.rank_multiplier_bp[rank])
	var lines: PackedStringArray = PackedStringArray(["%s  (%s, rank %s)" % [def.name, def.hero_class.capitalize(), TuningDef.TIER_LABELS[rank]]])
	lines.append(stat_line(stats))
	lines.append("Slots: 1 basic attack, %d abilities, %d passive%s" % [content.tuning.ability_slots[rank], content.tuning.passive_slots[rank], "" if content.tuning.passive_slots[rank] == 1 else "s"])
	lines.append("")
	var basic: ItemState = ItemState.make(def.basic_attack, 0, stats, content)
	lines.append("Basic attack: %s, every %ss" % [def.basic_attack.name, _seconds(basic.cooldown_ticks)])
	for sourced: SourcedEffect in basic.effects:
		lines.append("• " + effect_line(content, sourced))
	lines.append("")
	lines.append("Innate: %s. %s" % [def.innate_name, def.innate_text])
	if def.calling != null:
		lines.append("")
		lines.append("Calling: %s. %s" % [def.calling_name, def.calling_text])
		lines.append_array(track_lines(def.calling, 0, -1))
	return "\n".join(lines)


## A deed track in plain words: the deed, then each level's unlock (both
## options at the choice level), marking what's reached and chosen.
static func track_lines(track: DeedTrackDef, progress: int, choice: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var level: int = track.level_for(progress)
	lines.append("Deed: %s (%d / %d toward level %d)" % [track.deed.text, progress, track.deed.goals[mini(level, DeedDef.LEVELS - 1)], mini(level + 1, DeedDef.LEVELS)] if level < DeedDef.LEVELS \
		else "Deed: %s (all 3 levels reached)" % track.deed.text)
	for i: int in track.levels.size():
		var reached: String = "✓" if level > i else "•"
		var unlock: DeedTrackDef.Level = track.levels[i]
		if unlock.is_choice():
			var names: PackedStringArray = PackedStringArray()
			for o: int in unlock.options.size():
				var option: DeedTrackDef.Level = unlock.options[o]
				names.append("%s%s: %s" % [option.name, " (chosen)" if choice == o else "", option.text])
			lines.append("%s Level %d, choose one: %s" % [reached, i + 1, " / ".join(names)])
		else:
			lines.append("%s Level %d: %s" % [reached, i + 1, unlock.text])
	return lines


## One line per hero and deed track about this fight's progress, e.g.
## "Brannoc · Shieldbearer: 120 → 300 / 882". A level reached says so. The
## tracks come from the fight's setup; `names` maps unit ids to names.
static func deed_result_lines(result: FightResult, setup: FightSetup, names: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for deed: FightResult.DeedResult in result.deeds:
		var track: DeedTrackDef = null
		for unit: UnitSetup in setup.heroes:
			if unit.id == deed.unit_id:
				for deed_setup: DeedSetup in unit.deeds:
					if deed_setup.track_id == deed.track_id:
						track = deed_setup.def
		if track == null:
			continue
		var goal: String = "" if deed.level_after >= DeedDef.LEVELS else " / %d" % track.deed.goals[deed.level_after]
		var line: String = "%s · %s (%s): %d → %d%s" % [names.get(deed.unit_id, deed.unit_id), track.name, track.deed.text, deed.progress_before, deed.progress_after, goal]
		if deed.level_after > deed.level_before:
			line += "  ✦ level %d!" % deed.level_after
		lines.append(line)
	return lines


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
			lines.append("When one hero holds %s." % " and ".join(item_names))
		SynergyDef.Layer.TRANSFORMATION:
			lines.append("%s infused with %s: the item works differently (and never spills)." % [item_names[0], content.essences[def.essence].name])
		SynergyDef.Layer.SIGNATURE:
			lines.append("When %s holds %s." % [content.heroes[def.hero].name, item_names[0]])
		SynergyDef.Layer.RESONANCE:
			lines.append("Counting %s essences in the team's items:" % content.essences[def.essence].name)
		SynergyDef.Layer.CLASS_TRAIT:
			lines.append("Counting %ss in the team:" % def.unit_class.capitalize())
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
