class_name ItemInfo
extends RefCounted
## Tooltip text for items and relics: what an item is and what it does, with
## each number's base -> stat-scaled -> final breakdown (ItemState's own
## derivation, so the UI never re-implements game math).


static func item_text(content: ContentDb, item_id: String, tier: int, essence_ids: Array[String], xp: int, holder_stats: UnitStats = null) -> String:
	var def: ItemDef = content.items[item_id]
	var essences: Array[EssenceDef] = []
	for essence_id: String in essence_ids:
		essences.append(content.essences[essence_id])
	var stats: UnitStats = holder_stats if holder_stats != null else UnitStats.make(1)
	var state: ItemState = ItemState.make(def, 0, stats, content, essences, tier, xp)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s  (%s, tier %s)" % [def.name, def.rarity.capitalize(), TuningDef.TIER_LABELS[tier]])
	var kind: PackedStringArray = PackedStringArray(["Size %d" % def.size])
	if def.auto_attack:
		kind.append("auto-attack")
	if def.enemy_only:
		kind.append("enemy-only")
	if not def.tags.is_empty():
		kind.append(", ".join(def.tags))
	lines.append(" · ".join(kind))
	if not def.effects.is_empty():
		lines.append("Cooldown %.2fs" % (state.cooldown_ticks / float(FixedMath.TICKS_PER_SECOND)))
	if not essences.is_empty():
		lines.append("Infusion: %s (%s, %d XP)" % [state.infusion_name(), Infusions.LEVEL_NAMES[state.infusion_level], xp])
	for line: String in state.describe_values():
		lines.append("  " + line)
	for aura: AuraDef in def.auras:
		lines.append("  aura: " + aura.describe())
	if def.backup != null:
		lines.append("Backup mode: acts from the bench")
	if holder_stats == null:
		lines.append("(numbers shown without a holder's stats)")
	return "\n".join(lines)


static func relic_text(content: ContentDb, relic_id: String) -> String:
	var def: RelicDef = content.relics[relic_id]
	var lines: PackedStringArray = PackedStringArray(["%s  (%s relic)" % [def.name, def.rarity.capitalize()]])
	for aura: AuraDef in def.auras:
		lines.append("  " + aura.describe())
	for grant: GrantDef in def.grants:
		lines.append("  grants %s items: %s" % ["matching" if grant.filter != null else "all", EffectDef.TYPE_NAMES[grant.effect.type]])
	for effect: EffectDef in def.effects:
		lines.append("  %s: %s" % [EffectDef.TRIGGER_NAMES[effect.trigger], EffectDef.TYPE_NAMES[effect.type]])
	return "\n".join(lines)


## A hero's rank-adjusted stats, for item numbers on their row.
static func hero_stats(content: ContentDb, hero: RunHero) -> UnitStats:
	return content.heroes[hero.hero_id].stats.boosted(content.tuning.rank_multiplier_bp[hero.rank])
