class_name UnitInfo
extends RefCounted
## A unit's details for the enemy panel and the hero popup
## (docs/plans/rebuild-phase3-fight-sandbox.md, section 7, Decision 3): one
## line per ability, passive, and trait, each with its sentence and a numbers
## line under it.
##   - The sentence is the data's "text" (hand-written, so it reads well; a
##     trait's is fixed here, since traits are rules, not content).
##   - The numbers line is generated from the kit, so it's always true: when
##     it fires (cooldown, mana, trigger), its cast, its reach, and what it
##     does, with amounts worked out from the kit's stats.
##   - reaches() lists the distances a sentence must name, since the board
##     never draws an enemy's reach (Decision 5); a test holds every kit to
##     it.
## During a fight, live_text() and recent_lines() add the unit's numbers now
## and its last few log lines.

const TRAIT_NAMES: Dictionary[String, String] = {"engage": "Engage", "flying": "Flying", "hop_away": "Hop away"}
const EVENT_WORDS: Dictionary[int, String] = {
	EffectDef.Trigger.ON_ABILITY: "ability", EffectDef.Trigger.ON_BASIC_ATTACK: "basic attack",
	EffectDef.Trigger.ON_HOLDER_CRIT: "crit", EffectDef.Trigger.ON_SHIELDED: "Shield taken",
	EffectDef.Trigger.ON_HIT_TAKEN: "hit taken", EffectDef.Trigger.ON_HEAL: "heal",
	EffectDef.Trigger.ON_STATUS: "status applied", EffectDef.Trigger.ON_KILL: "kill",
}
const ORDINALS: Array[String] = ["th", "st", "nd", "rd"]
const CHATTER: Array[LogEntry.Kind] = [LogEntry.Kind.MOVE, LogEntry.Kind.STOP, LogEntry.Kind.TARGET]


## One line of a unit's details.
class Line:
	## "Basic attack", "Signature", "Passive", or "Trait".
	var kind: String
	var name: String
	var text: String
	var numbers: String


## Every line for a kit, in order: basic attack, signature, passives,
## traits, then phases (what changes, and when).
## `who` names the unit in a trait's sentence ("Maren", or "it").
static func lines(kit: UnitDef, who: String, content: ContentDb) -> Array[Line]:
	var result: Array[Line] = []
	result.append(_line("Basic attack", kit.basic_attack.name, kit.basic_attack.text, basic_numbers(kit, content)))
	if kit.signature != null:
		result.append(_line("Signature", kit.signature.name, kit.signature.text, signature_numbers(kit, content)))
	for part: PartDef in kit.passives:
		result.append(_line("Passive", part.name, part.text, passive_numbers(part, kit, content)))
	for trait_id: String in kit.traits:
		result.append(_line("Trait", TRAIT_NAMES[trait_id], trait_text(trait_id, who), trait_numbers(trait_id, kit, content.tuning)))
	for phase: PhaseDef in kit.phases:
		result.append(_line("Phase", phase.name, "", phase_numbers(phase)))
	return result


## "Below 80% HP · new signature: Call the Brood".
static func phase_numbers(phase: PhaseDef) -> String:
	var parts: Array[String] = ["Below %s HP" % ValueBreakdown._percent(phase.below_hp_bp)]
	if phase.signature != null:
		parts.append("new signature: %s" % phase.signature.name)
	if phase.basic_attack != null:
		parts.append("new basic attack: %s" % phase.basic_attack.name)
	for part: PartDef in phase.passives:
		parts.append("new passive: %s" % part.name)
	return " · ".join(parts)


static func _line(kind: String, line_name: String, text: String, numbers: String) -> Line:
	var line := Line.new()
	line.kind = kind
	line.name = line_name
	line.text = text
	line.numbers = numbers
	return line


static func trait_text(trait_id: String, who: String) -> String:
	match trait_id:
		"engage":
			return "A foe next to %s that's after someone else is held, and must break free before it can move." % who
		"flying":
			return "%s flies over units and rocks, and lands only to attack." % who.capitalize()
		"hop_away":
			return "When a foe comes within 1 hex, %s hops a hex away from it." % who
	return ""


static func trait_numbers(trait_id: String, kit: UnitDef, tuning: TuningDef) -> String:
	match trait_id:
		"engage":
			return "Breaking free takes %s" % seconds(tuning.break_free_ticks)
		"hop_away":
			return "At most once every %s" % seconds(kit.hop_cooldown_ticks)
	return ""


# --- numbers lines ----------------------------------------------------------------

static func basic_numbers(kit: UnitDef, content: ContentDb) -> String:
	var parts: Array[String] = ["Every %s" % seconds(kit.basic_attack.cooldown_ticks)]
	var reach: int = kit.stats.get_stat(UnitStats.Stat.RANGE)
	parts.append("reach %s" % hexes(reach) if reach >= 2 else "melee")
	parts.append_array(effect_numbers(kit.basic_attack.effects, kit, content))
	return " · ".join(parts)


static func signature_numbers(kit: UnitDef, content: ContentDb) -> String:
	var signature: AbilityDef = kit.signature
	var parts: Array[String] = [trigger_text(signature.trigger, kit)]
	if signature.cast_ticks > 0:
		parts.append("%s cast" % seconds(signature.cast_ticks))
	if signature.targeting != "self":
		parts.append("reach %s" % hexes(signature.reach_for(kit.stats.get_stat(UnitStats.Stat.RANGE))))
	parts.append_array(effect_numbers(signature.effects, kit, content))
	return " · ".join(parts)


static func passive_numbers(part: PartDef, kit: UnitDef, content: ContentDb) -> String:
	match part.kind:
		PartDef.Kind.AURA:
			return aura_text(part.aura)
		PartDef.Kind.REPLACE_STATUS:
			return "%s becomes %s" % [_status_name(part.from_status, content), _status_name(part.to_status, content)]
	var parts: Array[String] = [passive_trigger_text(part.ability.effects[0])]
	parts.append_array(effect_numbers(part.ability.effects, kit, content))
	return " · ".join(parts)


static func trigger_text(trigger: TriggerDef, kit: UnitDef) -> String:
	match trigger.kind:
		TriggerDef.Kind.MANA:
			return "At %d mana" % kit.mana.max
		TriggerDef.Kind.HP_BELOW:
			return "Once, below %s HP" % ValueBreakdown._percent(trigger.threshold_bp)
		TriggerDef.Kind.FIGHT_START:
			return "Once, as the fight starts"
		TriggerDef.Kind.AT_TIME:
			return "Once, at %s" % seconds(trigger.at_ticks)
		TriggerDef.Kind.COUNT:
			return "Every %s" % _nth(trigger.every, EVENT_WORDS[trigger.event])
	return "Once, when it would fall"


static func passive_trigger_text(effect: EffectDef) -> String:
	match effect.trigger:
		EffectDef.Trigger.ON_INTERVAL:
			return "Every %s" % seconds(effect.interval_ticks)
		EffectDef.Trigger.ON_FALL:
			return "As it falls"
		EffectDef.Trigger.ON_ALLY_BELOW_HP:
			return "When an ally drops below %s HP (%s)" % [ValueBreakdown._percent(effect.threshold_bp), "once a fight" if effect.once else "once per ally"]
	return "Every %s" % _nth(effect.every, EVENT_WORDS.get(effect.trigger, EffectDef.TRIGGER_NAMES[effect.trigger]))


static func aura_text(aura: AuraDef) -> String:
	var text: String = "x%s %s" % [ValueBreakdown._ratio(aura.value), AuraDef.STAT_LABELS[aura.stat]]
	if aura.target == AuraDef.Target.ALL_ALLIES:
		text += " for all allies"
	if aura.while_taunting:
		text += " while taunting"
	if aura.window_until_ticks >= 0:
		text += " until %s" % seconds(aura.window_until_ticks)
	return text


## What the effects do, in order, areas' own effects after the area.
static func effect_numbers(effects: Array[EffectDef], kit: UnitDef, content: ContentDb) -> Array[String]:
	var parts: Array[String] = []
	for effect: EffectDef in effects:
		var part: String = _effect_text(effect, kit, content)
		if not part.is_empty():
			parts.append(part)
		if effect.type == EffectDef.Type.AREA:
			parts.append_array(effect_numbers(effect.area_effects, kit, content))
	return parts


static func _effect_text(effect: EffectDef, kit: UnitDef, content: ContentDb) -> String:
	match effect.type:
		EffectDef.Type.DAMAGE:
			var text: String = _amount(effect, kit, "damage")
			if effect.bonus_bp_per_ally > 0:
				var kin: String = _unit_name(effect.bonus_kit, content) if not effect.bonus_kit.is_empty() else "ally"
				text += ", +%s per other %s within %s" % [ValueBreakdown._percent(effect.bonus_bp_per_ally), kin, hexes(bonus_hexes(effect))]
			return text + _to_all(effect)
		EffectDef.Type.HEAL:
			if effect.amount_bp_of_max_hp > 0:
				return "heals %s of max HP" % ValueBreakdown._percent(effect.amount_bp_of_max_hp)
			return "heals " + _amount(effect, kit, "") + _to_all(effect)
		EffectDef.Type.SHIELD:
			if effect.amount_bp_of_damage > 0:
				return "Shield of %s of the hit" % ValueBreakdown._percent(effect.amount_bp_of_damage)
			return _amount(effect, kit, "Shield") + _to_all(effect)
		EffectDef.Type.APPLY_STATUS:
			var status: StatusDef = content.statuses[effect.status_id]
			if status.kind == StatusDef.Kind.DAMAGE_OVER_TIME:
				return "%d %s" % [effect.stacks, status.name]
			var ticks: int = effect.duration_ticks if effect.duration_ticks > 0 else status.duration_ticks
			return "%s %s" % [status.name, seconds(ticks)] if ticks > 0 else status.name
		EffectDef.Type.CLEANSE:
			return "cleanses %s of damage over time" % ValueBreakdown._percent(effect.amount)
		EffectDef.Type.MANA_DRAIN:
			return "drains %d mana" % effect.amount
		EffectDef.Type.KNOCKBACK:
			return "knocks back %s" % hexes(effect.hexes)
		EffectDef.Type.PULL:
			return "pulls %s" % hexes(effect.hexes)
		EffectDef.Type.LEAP:
			return "leaps up to %s" % hexes(effect.hexes)
		EffectDef.Type.CHARGE:
			return "charges %s, knocking back %s" % [hexes(effect.hexes), hexes(effect.knockback_hexes)]
		EffectDef.Type.AREA:
			var text: String = "%d-hex %s %s" % [effect.shape.size, ShapeDef.KIND_NAMES[effect.shape.kind], "around it" if effect.anchor == EffectDef.Anchor.SELF else "at the target"]
			if effect.warning_ticks > 0:
				text += " (%s warning)" % seconds(effect.warning_ticks)
			return text
		EffectDef.Type.START_COLLAPSE:
			return "starts Rift Collapse"
		EffectDef.Type.SUMMON:
			return "summons %d %s" % [effect.count, _unit_name(effect.summon_kit, content)]
	return ""


## An amount with its word and how it scales: "14 damage (100% ATK)",
## "40 (20 + 100% MGK)", "60 Shield".
static func _amount(effect: EffectDef, kit: UnitDef, word: String) -> String:
	var value: ValueBreakdown = ValueBreakdown.compute(effect.amount, effect.scaling, kit.stats, [])
	var amount: String = str(value.final) if word.is_empty() else "%d %s" % [value.final, word]
	if value.stat_parts.is_empty():
		return amount
	var sum: Array[String] = []
	if effect.amount != 0:
		sum.append(str(effect.amount))
	for part: Array in value.stat_parts:
		sum.append("%s %s" % [ValueBreakdown._percent(part[1]), UnitStats.LABELS[part[0]]])
	return "%s (%s)" % [amount, " + ".join(sum)]


## " to all allies" or " to all enemies", for an effect on a whole side.
static func _to_all(effect: EffectDef) -> String:
	match effect.target:
		EffectDef.Target.ALL_ALLIES:
			return " to all allies"
		EffectDef.Target.ALL_ENEMIES:
			return " to all enemies"
	return ""


## A damage bonus's "within", in hexes.
static func bonus_hexes(effect: EffectDef) -> int:
	@warning_ignore("integer_division")
	return effect.bonus_within / HexGrid.HEX


static func _unit_name(kit_id: String, content: ContentDb) -> String:
	if content.enemies.has(kit_id):
		return content.enemies[kit_id].name
	if content.heroes.has(kit_id):
		return content.heroes[kit_id].name
	return kit_id


static func _status_name(status_id: String, content: ContentDb) -> String:
	return content.statuses[status_id].name if content.statuses.has(status_id) else status_id


## "every 3rd basic attack", "every basic attack".
static func _nth(every: int, event: String) -> String:
	if every == 1:
		return event
	var last: int = every % 10
	var teen: bool = every % 100 >= 10 and every % 100 < 20
	var suffix: String = ORDINALS[last] if last < ORDINALS.size() and not teen else "th"
	return "%d%s %s" % [every, suffix, event]


## 20 ticks -> "1s", 24 -> "1.2s", 3 -> "0.15s".
static func seconds(ticks: int) -> String:
	var ms: int = ticks * FixedMath.MS_PER_TICK
	@warning_ignore("integer_division")
	var whole: int = ms / 1000
	var rest: String = str(ms % 1000).pad_zeros(3).rstrip("0")
	return "%ds" % whole if rest.is_empty() else "%d.%ss" % [whole, rest]


static func hexes(count: int) -> String:
	return "1 hex" if count == 1 else "%d hexes" % count


# --- reach ------------------------------------------------------------------------

## The distances an ability's sentence must name, in hexes: a ranged basic
## attack's range, a signature's reach (unless it's on the unit itself), every
## area's size, and a bonus's "within".
static func reaches(ability: AbilityDef, kit: UnitDef) -> Array[int]:
	var found: Array[int] = []
	var unit_range: int = kit.stats.get_stat(UnitStats.Stat.RANGE)
	if ability == kit.basic_attack and unit_range >= 2:
		found.append(unit_range)
	if ability.is_signature() and ability.targeting != "self":
		found.append(ability.reach_for(unit_range))
	_effect_reaches(ability.effects, found)
	return found


static func _effect_reaches(effects: Array[EffectDef], found: Array[int]) -> void:
	for effect: EffectDef in effects:
		if effect.type == EffectDef.Type.AREA:
			found.append(effect.shape.size)
			_effect_reaches(effect.area_effects, found)
		if effect.bonus_within > 0:
			found.append(bonus_hexes(effect))


# --- during a fight ----------------------------------------------------------------

## "HP 210/420 · Shield 30 · Mana 40/80", then its statuses ("Taunt, 4 Burn").
static func live_text(unit: UnitState) -> String:
	if not unit.alive:
		return "Fallen"
	var parts: Array[String] = ["HP %d/%d" % [unit.hp, unit.max_hp]]
	if unit.shield > 0:
		parts.append("Shield %d" % unit.shield)
	if unit.mana_cap > 0:
		@warning_ignore("integer_division")
		parts.append("Mana %d/%d" % [unit.mana / Mana.SCALE, unit.mana_cap / Mana.SCALE])
	var text: String = " · ".join(parts)
	var statuses: Array[String] = []
	for status: StatusState in unit.statuses:
		var stacks: int = status.total_stacks()
		statuses.append("%d %s" % [stacks, status.def.name] if stacks > 0 else status.def.name)
	return text if statuses.is_empty() else "%s\n%s" % [text, ", ".join(statuses)]


## The last `count` log lines by or aimed at a unit, oldest first, leaving
## out the chatter.
static func recent_lines(unit_id: String, combat_log: CombatLog, names: FightNames, count: int = 3) -> Array[String]:
	var found: Array[String] = []
	var entries: Array[LogEntry] = combat_log.entries
	for i: int in range(entries.size() - 1, -1, -1):
		var entry: LogEntry = entries[i]
		if CHATTER.has(entry.kind) or (entry.source_unit != unit_id and entry.target != unit_id):
			continue
		found.push_front(names.text(entry))
		if found.size() == count:
			break
	return found


## "HP 210 · ATK 10 · Speed 3 · Range 1": the stats a kit has (zeros left
## out, except HP and ATK).
static func stats_text(unit_stats: UnitStats) -> String:
	var parts: Array[String] = []
	for stat: int in UnitStats.Stat.size():
		var value: int = unit_stats.get_stat(stat)
		if value != 0 or stat == UnitStats.Stat.HP or stat == UnitStats.Stat.ATK:
			parts.append("%s %d" % [UnitStats.LABELS[stat], value])
	return " · ".join(parts)


## The lines as labels in a column: the name and kind, the sentence, and the
## numbers under it.
static func column(unit_lines: Array[Line]) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	for line: Line in unit_lines:
		var heading: Label = UiStyle.label("%s · %s" % [line.name, line.kind.to_lower()], 16, UiStyle.HIGHLIGHT)
		box.add_child(heading)
		for text: String in [line.text, line.numbers]:
			if text.is_empty():
				continue
			var label: Label = UiStyle.label(text, 15 if text == line.text else 13, UiStyle.TEXT if text == line.text else UiStyle.TEXT_DIM)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(label)
	return box
