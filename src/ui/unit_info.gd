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

const TRAIT_NAMES: Dictionary[String, String] = {"engage": "Engage", "flying": "Flying", "hop_away": "Hop away", "fires_moving": "Fires moving", "inert": "Inert",
	"swims": "Swims", "submerges": "Submerges"}
const EVENT_WORDS: Dictionary[int, String] = {
	EffectDef.Trigger.ON_ABILITY: "ability", EffectDef.Trigger.ON_BASIC_ATTACK: "basic attack",
	EffectDef.Trigger.ON_HOLDER_CRIT: "crit", EffectDef.Trigger.ON_SHIELDED: "Shield taken",
	EffectDef.Trigger.ON_HIT_TAKEN: "hit taken", EffectDef.Trigger.ON_HEAL: "heal",
	EffectDef.Trigger.ON_STATUS: "status applied", EffectDef.Trigger.ON_KILL: "kill",
	EffectDef.Trigger.ON_HOP: "hop",
	EffectDef.Trigger.ON_HOLDER_HIT: "hit", EffectDef.Trigger.ON_SHIELD_BROKEN: "Shield broken",
	EffectDef.Trigger.ON_ALLY_ABILITY: "ally's signature",
	EffectDef.Trigger.ON_STATUS_ENDED: "status running out",
	EffectDef.Trigger.ON_LIFESTEAL: "lifesteal heal",
	EffectDef.Trigger.ON_KNOCKBACK: "enemy knocked back",
	EffectDef.Trigger.ON_GUARD: "hit taken for an ally",
	EffectDef.Trigger.ON_CHARGED: "charge or leap that hits it",
	EffectDef.Trigger.ON_ENEMY_FELL: "enemy falling",
	EffectDef.Trigger.ON_ARRIVE: "arrival",
	EffectDef.Trigger.ON_ALLY_SHIELD_BROKEN: "ally's Shield breaking",
	EffectDef.Trigger.ON_WALL_BLOCK: "attack its wall blocks",
	EffectDef.Trigger.ON_BREAKS_SHIELD: "Shield it breaks",
	EffectDef.Trigger.ON_RISE: "rise from a fall",
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
		result.append(_line("Phase", phase.name, phase.text, phase_numbers(phase)))
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
		"fires_moving":
			return "While walking, %s shoots the nearest foe in reach without stopping." % who
		"inert":
			return "%s never moves or attacks: only what it does on its own counts." % who.capitalize()
		"swims":
			return "Water doesn't slow %s." % who
		"submerges":
			return "On water %s is under it and can't be targeted, until it surfaces to attack." % who
	return ""


static func trait_numbers(trait_id: String, kit: UnitDef, tuning: TuningDef) -> String:
	match trait_id:
		"engage":
			var held: String = "Breaking free takes %s" % seconds(tuning.break_free_ticks + kit.break_free_add_ticks)
			if kit.engage_reach_add > 0:
				# A farther Engage (phase 8 part 3, the Warden Sentinel).
				@warning_ignore("integer_division")
				held += " · holds foes within %d hexes" % ((tuning.engage_reach + kit.engage_reach_add) / HexGrid.HEX)
			return held
		"hop_away":
			return "At most once every %s" % seconds(kit.hop_cooldown_ticks)
		"fires_moving":
			return "Basic attack only, on its usual cooldown"
		"submerges":
			return "Up for %s after each basic attack" % seconds(Water.SURFACE_TICKS)
	return ""


## What a fight put into a deed: "1,240", or for time rooted "12.5s".
static func deed_amount_text(deed: DeedDef, amount: int) -> String:
	if deed.counts == DeedDef.Counts.ROOTED_MS:
		return "%.1fs" % (amount / 1000.0)
	return thousands(amount)


## 1240 -> "1,240".
static func thousands(amount: int) -> String:
	var digits: String = str(absi(amount))
	var grouped: String = ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + grouped


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
	# Growing with each cast (phase 8 part 2).
	if signature.grows_bp > 0:
		parts.append("%s stronger each cast" % signed_percent(signature.grows_bp))
	if signature.grows_boosts_bp > 0:
		parts.append("its boosts %s stronger each cast" % signed_percent(signature.grows_boosts_bp))
	return " · ".join(parts)


static func passive_numbers(part: PartDef, kit: UnitDef, content: ContentDb) -> String:
	match part.kind:
		PartDef.Kind.AURA:
			return aura_text(part.aura)
		PartDef.Kind.REPLACE_STATUS:
			return "%s becomes %s" % [_status_name(part.from_status, content), _status_name(part.to_status, content)]
		PartDef.Kind.GUARD:
			@warning_ignore("integer_division")
			return "Takes %s of each enemy hit on an ally %swithin %s" % [ValueBreakdown._percent(part.share_bp),
				"behind it " if part.behind_only else "", hexes(part.guard_range / HexGrid.HEX)]
		PartDef.Kind.RISE:
			var rises: String = "Rises %s after falling, at %s of max HP, %s a fight" % [seconds(part.rise_ticks), ValueBreakdown._percent(part.rise_hp_bp),
				"once" if part.rise_times == 1 else "up to %d times" % part.rise_times]
			if not part.rise_status.is_empty():
				rises += "; each rise: %s" % _status_name(part.rise_status, content)
			return rises
		PartDef.Kind.COPY:
			var copies: String = "Copies %s hero signature it sees" % ("each new" if part.copy_replace else "the first")
			if part.copy_twice_bp > 0:
				copies += "; casts it twice, each at %s" % ValueBreakdown._percent(part.copy_twice_bp)
			if part.copy_share:
				copies += "; its court gets each copy too"
			return copies
		PartDef.Kind.LINK:
			var linked: String = "Allies with its Shields share %s of each hit on one, evenly" % ValueBreakdown._percent(part.share_bp)
			if part.per_shared > 0:
				linked += "; every %d shared: %s on each" % [part.per_shared, _status_name(part.link_status, content)]
			return linked
	# Each effect's trigger, where it differs from the one before (a passive
	# may answer more than one event).
	var parts: Array[String] = []
	var said: String = ""
	for effect: EffectDef in part.ability.effects:
		var when: String = passive_trigger_text(effect)
		if when != said:
			parts.append(when)
			said = when
		parts.append_array(effect_numbers([effect] as Array[EffectDef], kit, content))
	return " · ".join(parts)


## A tactic's numbers line (phase 3b, round 2): what its behavior waits for
## or goes after, then its payoff.
static func tactic_numbers(tactic: TacticDef) -> String:
	var parts: Array[String] = []
	var pct: Callable = func(bp: int) -> String: return ValueBreakdown._percent(bp)
	match tactic.kind:
		TacticDef.Kind.PREFER_TARGET:
			if not tactic.archetypes.is_empty():
				var kinds: Array[String] = []
				for archetype: String in tactic.archetypes:
					kinds.append(archetype + "s")
				var named: String = " and ".join(kinds)
				parts.append("%s%s first" % [named.left(1).to_upper(), named.substr(1)])
			elif tactic.prefers != null:
				parts.append("Enemies that are %s first" % tactic.prefers.describe())
			else:
				parts.append({"lowest_hp_in_reach": "The enemy lowest on HP in reach first", "most_def": "The enemy with the most DEF first",
					"farthest": "The farthest enemy first"}[tactic.pick])
			if tactic.damage_vs_bp > 0:
				var vs: String = "enemies that are %s" % tactic.payoff_vs.describe() if tactic.payoff_vs != null else "them"
				parts.append("+%s damage to %s from its basic attack and signature" % [pct.call(tactic.damage_vs_bp), vs])
		TacticDef.Kind.HOLD_GROUND:
			@warning_ignore("integer_division")
			parts.append("Holds until an enemy is within %s" % hexes(tactic.release_range / HexGrid.HEX))
			if tactic.atsp_bp > 0:
				parts.append("+%s attack speed while it holds" % pct.call(tactic.atsp_bp))
			if tactic.keep_bp > 0:
				parts.append("%s of that after it moves out" % pct.call(tactic.keep_bp))
		TacticDef.Kind.SIGNATURE_THRESHOLD:
			parts.append("Waits until an ally is below %s HP" % pct.call(tactic.below_bp))
			if tactic.heal_bp > 0:
				parts.append("+%s healing from its signature" % pct.call(tactic.heal_bp))
		TacticDef.Kind.STOP_NEAR:
			@warning_ignore("integer_division")
			parts.append("Stops while an enemy is within %s" % hexes(tactic.stop_range / HexGrid.HEX))
		TacticDef.Kind.GUARD_ALLY:
			parts.append("The enemy attacking its weakest ally first")
		TacticDef.Kind.KITE:
			parts.append("Backs away to keep its target at full reach")
		TacticDef.Kind.LEASH:
			@warning_ignore("integer_division")
			parts.append("Stays within %s of its ally with the most DEF" % hexes(tactic.leash_range / HexGrid.HEX))
		TacticDef.Kind.SIGNATURE_CROWD:
			parts.append("Waits for %d enemies in its signature's area, %s at most" % [tactic.crowd, seconds(tactic.max_wait_ticks)])
		TacticDef.Kind.SIGNATURE_FINISH:
			parts.append("Waits until its target is below %s HP" % pct.call(tactic.below_bp))
	var applying: String = " for its first %s" % seconds(tactic.window_ticks) if tactic.window_ticks > 0 else " while it does"
	if tactic.crit_vs_bp > 0:
		parts.append("+%s crit chance on them" % pct.call(tactic.crit_vs_bp))
	if tactic.def_ignore_bp > 0:
		parts.append("its hits on its target ignore %s of its DEF" % pct.call(tactic.def_ignore_bp))
	if tactic.def_add > 0:
		parts.append("+%d DEF%s" % [tactic.def_add, applying])
	if tactic.def_bp > 0:
		parts.append("+%s DEF%s" % [pct.call(tactic.def_bp), applying])
	if tactic.atk_mgk_bp > 0:
		parts.append("+%s ATK and MGK%s" % [pct.call(tactic.atk_mgk_bp), applying])
	if tactic.atsp_add > 0:
		parts.append("+%d ATSP at full reach" % tactic.atsp_add)
	if tactic.power_bp > 0:
		parts.append("+%s damage from the signature that waited" % pct.call(tactic.power_bp))
	if tactic.regen_bp > 0:
		parts.append("%s of max HP a second%s" % [pct.call(tactic.regen_bp), applying])
	if not tactic.first_hit_status.is_empty():
		var lasts: String = " %s" % seconds(tactic.first_hit_ticks) if tactic.first_hit_ticks > 0 else ""
		var stacks: String = "%d " % tactic.first_hit_stacks if tactic.first_hit_stacks > 1 else ""
		parts.append("its first hit on each puts on %s%s%s" % [stacks, tactic.first_hit_status.replace("_", " ").capitalize(), lasts])
	if tactic.crit_extends_mark_ticks > 0:
		parts.append("its crits on Marked enemies make the Mark last %s longer" % seconds(tactic.crit_extends_mark_ticks))
	if tactic.kill_mana > 0:
		parts.append("+%d mana on a kill" % tactic.kill_mana)
	if tactic.restart_on_kill:
		parts.append("a kill in that time starts it again")
	if tactic.cleanse_one:
		parts.append("the heal that waited cleanses one harmful status")
	if tactic.ally_def_add > 0:
		parts.append("the ally it guards gets +%d DEF" % tactic.ally_def_add)
	if tactic.crit_after_back:
		parts.append("its first attack after backing away crits")
	if tactic.per_extra_bp > 0:
		parts.append("+%s more for each enemy past %d" % [pct.call(tactic.per_extra_bp), tactic.crowd])
	if tactic.refund_bp > 0:
		parts.append("a kill with it gives back %s of its bar" % pct.call(tactic.refund_bp))
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
		TriggerDef.Kind.ALLY_FALLS:
			return "Each time an ally falls"
		TriggerDef.Kind.ALLY_FIRES:
			return "Once, when an ally's %s fires" % trigger.ability.replace("_", " ").capitalize()
		TriggerDef.Kind.EVERY:
			return "Every %s" % seconds(trigger.at_ticks)
	return "Once, when it would fall"


static func passive_trigger_text(effect: EffectDef) -> String:
	match effect.trigger:
		EffectDef.Trigger.ON_INTERVAL:
			if effect.once and effect.times > 1:
				return "%d times, every %s" % [effect.times, seconds(effect.interval_ticks)]
			return ("Once, after %s" if effect.once else "Every %s") % seconds(effect.interval_ticks)
		EffectDef.Trigger.ON_WOULD_FALL:
			return "Once, when it would fall"
		EffectDef.Trigger.ON_FALL:
			return "As it falls"
		EffectDef.Trigger.ON_FIGHT_START:
			return "As the fight starts"
		EffectDef.Trigger.ON_ALLY_BELOW_HP:
			var how: String = "once per ally"
			if effect.once:
				how = "once a fight" if effect.times == 1 else "for the first %d allies" % effect.times
			return "When an ally drops below %s HP (%s)" % [ValueBreakdown._percent(effect.threshold_bp), how]
		EffectDef.Trigger.ON_BELOW_HP:
			return "When it drops below %s HP (%s)" % [ValueBreakdown._percent(effect.threshold_bp), "once a fight" if effect.times == 1 else "up to %d times a fight" % effect.times]
	var word: String = EVENT_WORDS.get(effect.trigger, EffectDef.TRIGGER_NAMES[effect.trigger])
	if effect.trigger == EffectDef.Trigger.ON_STATUS_ENDED and not effect.statuses.is_empty():
		var ended: Array[String] = []
		for status_id: String in effect.statuses:
			ended.append(status_id.replace("_", " ").capitalize())
		word = "time its %s runs out" % " or ".join(ended)
	elif not effect.keywords.is_empty():
		var names: Array[String] = []
		for keyword: String in effect.keywords:
			names.append(Keywords.label(keyword))
		word = "status applied that makes a unit %s" % " or ".join(names)
	var text: String = ("Once, on its %s" if effect.once else "Every %s") % (_nth(effect.every, word) if effect.every > 1 or not effect.once else "first " + word)
	if effect.fell_range > 0:
		@warning_ignore("integer_division")
		text += " within %d hexes" % (effect.fell_range / HexGrid.HEX)
	if effect.min_hit_bp > 0:
		text += " of at least %s of its max HP" % ValueBreakdown._percent(effect.min_hit_bp)
	if effect.executed:
		text = text.replace("kill", "execution")
	if effect.at_stacks > 0:
		text = "When %s reaches %d stacks on a unit (spent)" % [" or ".join(effect.statuses.map(func(status_id: String) -> String: return status_id.replace("_", " ").capitalize())), effect.at_stacks]
	if effect.from_signature:
		text += " by its signature"
	if not effect.from_abilities.is_empty():
		text += " from %s" % " or ".join(effect.from_abilities.map(func(ability_id: String) -> String: return ability_id.replace("_", " ").capitalize()))
	if effect.was_below_bp > 0:
		text += " on an ally below %s HP" % ValueBreakdown._percent(effect.was_below_bp)
	if effect.beyond_range > 0:
		@warning_ignore("integer_division")
		text += " from more than %s away" % hexes(effect.beyond_range / HexGrid.HEX)
	if effect.off_target:
		text += " of an enemy it wasn't aiming at"
	if effect.holder != null:
		text += " while it's %s" % effect.holder.describe()
	if effect.vs != null:
		text += " on a unit that's %s" % effect.vs.describe()
	if effect.cooldown_per_unit_ticks > 0:
		text += " (at most once every %s for each)" % seconds(effect.cooldown_per_unit_ticks)
	if effect.cooldown_ticks > 0:
		text += " (at most once every %s)" % seconds(effect.cooldown_ticks)
	if effect.delay_ticks > 0:
		text += ", %s later" % seconds(effect.delay_ticks)
	return text


static func aura_text(aura: AuraDef) -> String:
	var text: String
	if aura.per_shield_bp > 0:
		text = "+%s %s per point of Shield" % [ValueBreakdown._percent(aura.per_shield_bp), AuraDef.STAT_LABELS[aura.stat]]
	elif aura.stat == AuraDef.Stat.RANGE:
		text = "%+d range" % aura.value
	elif aura.stat == AuraDef.Stat.ATSP:
		text = "%+d ATSP" % aura.value
	elif aura.stat == AuraDef.Stat.DEF:
		text = "%+d DEF" % aura.value
	elif aura.stat == AuraDef.Stat.LIFESTEAL_HEALS:
		text = "lifesteal counts as healing"
	elif aura.stat == AuraDef.Stat.DAMAGE_REDUCED_BP:
		text = "%s damage taken" % signed_percent(-aura.value)
	elif aura.stat == AuraDef.Stat.UNPUSHABLE:
		text = "can't be knocked back or pulled"
	elif aura.stat == AuraDef.Stat.DODGE_EVERY_MS:
		text = "a hit on it misses, then not again for %s" % seconds(FixedMath.ms_to_ticks(aura.value))
	elif aura.stat == AuraDef.Stat.HALVED_HITS:
		text = "its first %d hits taken each fight deal half damage" % aura.value
	elif aura.stat == AuraDef.Stat.SEES_STEALTH:
		text = "can target the stealthed"
	elif aura.stat == AuraDef.Stat.ROOT_CAP_MS:
		text = "Roots on it last at most %s" % seconds(FixedMath.ms_to_ticks(aura.value))
	elif aura.stat == AuraDef.Stat.DEF_IGNORE_BP:
		text = "its hits ignore %s of the target's DEF" % ValueBreakdown._percent(aura.value)
	elif aura.is_additive():
		text = "%s %s" % [signed_percent(aura.value), AuraDef.STAT_LABELS[aura.stat]]
	else:
		# A factor's change, as the damage rule adds it (phase 5c): x1.5 is +50%.
		text = "%s %s" % [signed_percent(aura.value - FixedMath.BP_ONE), AuraDef.STAT_LABELS[aura.stat]]
	if aura.target == AuraDef.Target.ALL_ALLIES:
		text += " for all allies"
	if aura.only != null:
		# Only some of them (phase 8 part 3, the Spire Chanter).
		text += " %s" % aura.only.describe()
	match aura.while_kind:
		AuraDef.While.TAUNTING:
			text += " while taunting"
		AuraDef.While.PLANTED:
			text += " after %s still" % seconds(aura.after_ticks)
			if aura.step_ticks > 0:
				var step: String = "%+d" % aura.step_value if aura.is_additive() else signed_percent(aura.step_value)
				text += ", %s more every %s after" % [step, seconds(aura.step_ticks)]
		AuraDef.While.BELOW_HP:
			text += " below %s HP" % ValueBreakdown._percent(aura.below_bp)
		AuraDef.While.STATE:
			text += " while %s" % aura.state.describe()
		AuraDef.While.ALLY_NEAR:
			@warning_ignore("integer_division")
			text += " while an ally is within %s" % hexes(aura.near_range / HexGrid.HEX)
		AuraDef.While.TACTIC:
			text += " while it follows its tactic"
		AuraDef.While.ALLY_STANDING:
			text += " while another of its side stands" if aura.ally_kit.is_empty() else " while a %s stands" % aura.ally_kit.replace("_", " ")
		AuraDef.While.BEHIND_WALL:
			@warning_ignore("integer_division")
			text += " while behind an allied wall (within %s of it)" % hexes(aura.near_range / HexGrid.HEX)
		AuraDef.While.MOVED:
			text += " for %s after it moves" % seconds(aura.moved_ticks)
		AuraDef.While.CROWDED:
			@warning_ignore("integer_division")
			text += " while %d or more enemies are within %s" % [aura.crowd, hexes(aura.near_range / HexGrid.HEX)]
	if aura.target == AuraDef.Target.ALLIES_NEAR:
		@warning_ignore("integer_division")
		text += " for the other allies within %s" % hexes(aura.target_range / HexGrid.HEX)
	if aura.hit_range > 0:
		@warning_ignore("integer_division")
		text += " on targets within %s" % hexes(aura.hit_range / HexGrid.HEX)
	if aura.vs != null and aura.stat == AuraDef.Stat.DAMAGE_BP:
		text = text.replace(" damage", " damage against %s" % aura.vs.describe())
	elif aura.vs != null:
		text += " against enemies that are %s" % aura.vs.describe()
	if aura.per_fallen_ally:
		text += " per fallen ally"
	if aura.from_basic:
		text += " on its basic attacks"
	if aura.from_signature:
		text += " on its signature's hits"
	if not aura.per_target_stacks.is_empty():
		text += " per %s stack on the enemy hit" % aura.per_target_stacks.replace("_", " ").capitalize()
	if aura.window_until_ticks >= 0:
		text += " until %s" % seconds(aura.window_until_ticks)
	return text


## What a boost status gives: "+20% ATK, +20% MGK", and for a stacking one
## "+2 ATSP a stack" ("..., the whole fight" with no duration).
static func boost_text(status: StatusDef) -> String:
	var parts: Array[String] = []
	for i: int in status.boost_stats.size():
		var aura := AuraDef.new()
		aura.stat = status.boost_stats[i] as AuraDef.Stat
		aura.value = status.boost_values[i]
		parts.append(aura_text(aura))
	var text: String = ", ".join(parts)
	if status.stacking:
		text += " a stack" + ("" if status.duration_ticks > 0 else ", the whole fight")
	if status.until_attack:
		text += ", until its next attack"
	return text


## A share with its sign: "+15%", "−2%" (phase 5c, step 2: every stat change
## says its amount).
static func signed_percent(bp: int) -> String:
	return ("+" if bp >= 0 else "−") + ValueBreakdown._percent(absi(bp))


## What the effects do, in order, areas' own effects after the area.
static func effect_numbers(effects: Array[EffectDef], kit: UnitDef, content: ContentDb) -> Array[String]:
	var parts: Array[String] = []
	for effect: EffectDef in effects:
		var part: String = _effect_text(effect, kit, content)
		if not part.is_empty():
			parts.append(part)
		if effect.type == EffectDef.Type.AREA or effect.type == EffectDef.Type.SNARE:
			parts.append_array(effect_numbers(effect.area_effects, kit, content))
	return parts


static func _effect_text(effect: EffectDef, kit: UnitDef, content: ContentDb) -> String:
	if effect.power_per_taken_bp > 0:
		# Growing with the damage taken (phase 8 part 2, Martyr's Pyre).
		return _effect_text_plain(effect, kit, content) + " (%s for every %d damage it has taken)" % [signed_percent(effect.power_per_taken_bp), effect.taken_per]
	return _effect_text_plain(effect, kit, content)


static func _effect_text_plain(effect: EffectDef, kit: UnitDef, content: ContentDb) -> String:
	var text: String = _effect_core(effect, kit, content)
	if text.is_empty():
		return text
	text += _near(effect)
	match effect.side:
		EffectDef.AreaSide.ENEMIES:
			text += " to enemies"
		EffectDef.AreaSide.ALLIES:
			text += " to allies"
	if effect.every > 1 and effect.trigger == EffectDef.Trigger.ON_FIRE:
		text = "every %s: %s" % [_nth(effect.every, "fire"), text]
	if effect.when_attackers > 0:
		text += " (with %d of its side on the target)" % effect.when_attackers
	return text


## " to the enemy nearest the target (within 1 hex)" and the like (phase 4).
static func _near(effect: EffectDef) -> String:
	@warning_ignore("integer_division")
	var within: String = " (within %s)" % hexes(effect.near_range / HexGrid.HEX) if effect.near_range > 0 else ""
	match effect.target:
		EffectDef.Target.ENEMY_NEAR_TARGET:
			return " to the enemy nearest the target" + within
		EffectDef.Target.ENEMIES_NEAR_TARGET:
			return " to every enemy near the target" + within
		EffectDef.Target.ALLY_NEAR_TARGET:
			return " to the ally nearest the target" + within
		EffectDef.Target.ALLIES_NEAR_TARGET:
			return " to every ally near the target" + within
		EffectDef.Target.LOWEST_HP_ALLY:
			return " to the ally lowest on HP" + within
		EffectDef.Target.SELF:
			return " to itself" if effect.type == EffectDef.Type.GAIN_MANA else ""
		EffectDef.Target.ENEMIES_NEAR_SELF:
			return " to every enemy near it" + within
		EffectDef.Target.ALLIES_NEAR_SELF:
			return " to every ally near it" + within
		EffectDef.Target.ENEMIES_NEAR_NAMED:
			return " to every enemy near that unit" + within
		EffectDef.Target.ENEMY_NEAR_NAMED:
			return " to the enemy nearest that unit" + within
		EffectDef.Target.NEAREST_ENEMIES:
			return " to the %s nearest the heroes" % ("enemy" if effect.count == 1 else "%d enemies" % effect.count)
	return ""


static func _effect_core(effect: EffectDef, kit: UnitDef, content: ContentDb) -> String:
	match effect.type:
		EffectDef.Type.DAMAGE:
			if effect.amount_bp_of_damage > 0:
				return "%s of the %s as damage" % [ValueBreakdown._percent(effect.amount_bp_of_damage),
					"Shield it broke" if effect.trigger == EffectDef.Trigger.ON_SHIELD_BROKEN else "hit"]
			var text: String = _amount(effect, kit, "damage")
			if effect.bonus_bp_per_ally > 0:
				var kin: String = _unit_name(effect.bonus_kit, content) if not effect.bonus_kit.is_empty() else "ally"
				text += ", +%s per other %s within %s" % [ValueBreakdown._percent(effect.bonus_bp_per_ally), kin, hexes(bonus_hexes(effect))]
			if effect.execute_below_bp > 0:
				text += ", finishing it below %s HP" % ValueBreakdown._percent(effect.execute_below_bp)
			return text + _to_all(effect)
		EffectDef.Type.HEAL:
			if effect.amount_bp_of_max_hp > 0:
				return "heals %s of max HP" % ValueBreakdown._percent(effect.amount_bp_of_max_hp)
			if effect.amount_bp_of_damage > 0:
				var of_damage: String = "heals %s of the damage" % ValueBreakdown._percent(effect.amount_bp_of_damage)
				if effect.overheal_max_hp_per > 0:
					of_damage += ", and every %d past full HP gives it +1 max HP" % effect.overheal_max_hp_per
				return of_damage
			var healed: String = "heals " + _amount(effect, kit, "") + _to_all(effect)
			if effect.overheal_shield_bp > 0:
				healed += ", past full HP %s as Shield" % ValueBreakdown._percent(effect.overheal_shield_bp)
			return healed
		EffectDef.Type.SHIELD:
			if effect.amount_bp_of_damage > 0:
				return "Shield of %s of the hit" % ValueBreakdown._percent(effect.amount_bp_of_damage)
			if effect.amount_bp_of_max_hp > 0:
				return "Shield of %s of max HP%s" % [ValueBreakdown._percent(effect.amount_bp_of_max_hp), _to_all(effect)]
			return _amount(effect, kit, "Shield") + _to_all(effect)
		EffectDef.Type.APPLY_STATUS:
			var status: StatusDef = content.statuses[effect.status_id]
			if not effect.stacks_of.is_empty() and effect.stacks_share_bp > 0:
				return "%s of that unit's %s (at least 1)" % [ValueBreakdown._percent(effect.stacks_share_bp), _status_name(effect.stacks_of, content)]
			if not effect.stacks_of.is_empty():
				return "as much %s as that unit had" % _status_name(effect.stacks_of, content)
			if effect.fresh_only:
				var lasts: int = effect.duration_ticks if effect.duration_ticks > 0 else status.duration_ticks
				return "%s %s, if it isn't %s already" % [status.name, seconds(lasts), Keywords.label(status.keyword) if not status.keyword.is_empty() else "under it"]
			if status.kind == StatusDef.Kind.DAMAGE_OVER_TIME:
				return "%d %s%s" % [effect.stacks, status.name, _to_all(effect)]
			var ticks: int = effect.duration_ticks if effect.duration_ticks > 0 else status.duration_ticks
			var named: String = "%s %s" % [status.name, seconds(ticks)] if ticks > 0 else status.name
			if status.kind == StatusDef.Kind.BOOST:
				named += " (%s)" % boost_text(status)
			if effect.marks_stack:
				named += ", stacking as it refreshes"
			if effect.until_near > 0:
				@warning_ignore("integer_division")
				named = "%s until an enemy comes within %s" % [status.name, hexes(effect.until_near / HexGrid.HEX)]
			return named + _to_all(effect)
		EffectDef.Type.EXTEND_STATUS:
			return "its %s lasts %s longer" % [_status_name(effect.status_id, content), seconds(effect.duration_ticks)]
		EffectDef.Type.CLEANSE:
			if effect.cleanse_count > 0 and not effect.cleanse_statuses.is_empty():
				# Only those named (phase 8 part 3, the Unbinder).
				var ended: Array[String] = []
				for status_id: String in effect.cleanse_statuses:
					ended.append(_status_name(status_id, content))
				return "ends %s%s" % [", ".join(ended.slice(0, -1)) + ", and " if ended.size() > 1 else "", ended[-1]] + _to_all(effect)
			if effect.cleanse_count > 0:
				return "removes its %s newest harmful status%s" % ["" if effect.cleanse_count == 1 else str(effect.cleanse_count), "" if effect.cleanse_count == 1 else "es"]
			if not effect.cleanse_statuses.is_empty():
				var names: Array[String] = []
				for status_id: String in effect.cleanse_statuses:
					names.append(_status_name(status_id, content))
				return "cleanses %s of %s" % [ValueBreakdown._percent(effect.amount), " and ".join(names)]
			return "cleanses %s of damage over time" % ValueBreakdown._percent(effect.amount)
		EffectDef.Type.MANA_DRAIN:
			return "drains %d mana" % effect.amount
		EffectDef.Type.GAIN_MANA:
			if effect.mana_bp > 0:
				return "+%s of its mana" % ValueBreakdown._percent(effect.mana_bp)
			return "+%d mana" % effect.amount
		EffectDef.Type.SNARE:
			if effect.under_front:
				return "one of its snares under its front-most ally"
			return "a snare in the target's path" + (" (up to %d at once)" % effect.max_standing if effect.max_standing > 0 else "") \
				+ (", sprung by leaps and charges over it" if effect.snags else "")
		EffectDef.Type.WALL:
			@warning_ignore("integer_division")
			var wall: String = "a %s-wide wall %s ahead%s %s, stopping enemy shots" % [hexes(effect.width_range / HexGrid.HEX), hexes(effect.ahead_range / HexGrid.HEX),
				" of the target" if effect.at_target else "", "until broken" if effect.until_broken else "for " + seconds(effect.zone_ticks)]
			if effect.blocks_movement:
				wall += " and enemies' way"
			if effect.wall_hp_bp > 0:
				wall += " (HP %s of max HP)" % ValueBreakdown._percent(effect.wall_hp_bp)
			if effect.max_standing > 0:
				wall += ", up to %d at once" % effect.max_standing
			return wall
		EffectDef.Type.KNOCKBACK:
			var far: String = hexes(effect.hexes) if effect.distance_bp == FixedMath.BP_ONE else "%s of %s" % [ValueBreakdown._percent(effect.distance_bp), hexes(effect.hexes)]
			if effect.toward == EffectDef.Toward.EDGE:
				return "shoves %s toward the nearest edge" % far
			return "knocks back %s" % far
		EffectDef.Type.PULL:
			if effect.hook:
				return "hooks the target all the way to beside it"
			var way: String = ["", " toward the nearest water", " toward the area's middle"][effect.toward]
			return "pulls %s%s%s" % [hexes(effect.hexes), way, _to_all(effect)]
		EffectDef.Type.FLOOD:
			match effect.flood_mode:
				EffectDef.FloodMode.CIRCLE:
					return "floods a %d-hex circle %s%s" % [effect.flood_radius, "around it" if effect.anchor == EffectDef.Anchor.SELF else "at the target",
						" for " + seconds(effect.zone_ticks) if effect.zone_ticks > 0 else ""]
				EffectDef.FloodMode.SPREAD:
					return "every pool spreads a hex"
				EffectDef.FloodMode.DRAIN:
					return "drains the water to within %s of it" % hexes(effect.flood_radius)
			return "floods every hex but the rocks"
		EffectDef.Type.LEAP:
			if effect.leap_home:
				return "leaps back to where it started"
			return "leaps up to %s" % hexes(effect.hexes)
		EffectDef.Type.HOP:
			return "hops %s away from the nearest enemy" % hexes(1)
		EffectDef.Type.CHARGE:
			return "charges %s, %s %s" % [hexes(effect.hexes), "carrying every enemy in its line" if effect.carries else "knocking back", hexes(effect.knockback_hexes)]
		EffectDef.Type.AREA:
			var text: String = "%d-hex %s %s" % [effect.shape.size, ShapeDef.KIND_NAMES[effect.shape.kind], "around it" if effect.anchor == EffectDef.Anchor.SELF else "at the target"]
			if effect.warning_ticks > 0:
				text += " (%s warning)" % seconds(effect.warning_ticks)
			if effect.zone_ticks > 0:
				text += " for %s, every %s" % [seconds(effect.zone_ticks), seconds(effect.pulse_ticks)]
			if effect.per_enemy_bp > 0:
				text += ", +%s for each enemy it passes" % ValueBreakdown._percent(effect.per_enemy_bp)
			return text
		EffectDef.Type.START_COLLAPSE:
			return "starts Rift Collapse"
		EffectDef.Type.SEVER:
			return "the next bridge breaks after %s, for %s" % [seconds(effect.warning_ticks), seconds(effect.zone_ticks)]
		EffectDef.Type.SUMMON:
			return "summons %d %s" % [effect.count, _unit_name(effect.summon_kit, content)]
	return ""


## An amount with its word and how it scales: "14 damage (100% ATK)",
## "40 (20 + 100% MGK)", "60 Shield", and a kit mod's power bonus after it
## ("14 damage (100% ATK), +20%").
static func _amount(effect: EffectDef, kit: UnitDef, word: String) -> String:
	var value: ValueBreakdown = ValueBreakdown.compute(effect.amount, effect.scaling, kit.stats, [])
	var amount: String = str(value.final) if word.is_empty() else "%d %s" % [value.final, word]
	var power: String = "" if effect.power_bp == 0 else ", %s" % signed_percent(effect.power_bp)
	if value.stat_parts.is_empty():
		return amount + power
	var sum: Array[String] = []
	if effect.amount != 0:
		sum.append(str(effect.amount))
	for part: Array in value.stat_parts:
		sum.append("%s %s" % [ValueBreakdown._percent(part[1]), UnitStats.LABELS[part[0]]])
	return "%s (%s)%s" % [amount, " + ".join(sum), power]


## " to all allies" or " to all enemies", for an effect on a whole side.
static func _to_all(effect: EffectDef) -> String:
	var only: String = "" if effect.only == null else " %s" % effect.only.describe()
	match effect.target:
		EffectDef.Target.ALL_ALLIES:
			return " to all allies" + only
		EffectDef.Target.ALL_ENEMIES:
			return " to all enemies" + only
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
		if effect.near_range > 0:
			@warning_ignore("integer_division")
			found.append(effect.near_range / HexGrid.HEX)


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
