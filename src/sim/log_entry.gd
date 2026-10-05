class_name LogEntry
extends RefCounted
## One line of the combat log. Every effect names its source unit and
## ability (CLAUDE.md rule 4); Rift Collapse uses the source ability
## "rift_collapse". The arena sim adds move, push, shot, and area kinds
## (docs/plans/rebuild-phase1-arena-sim.md, section 11).

enum Kind {
	FIGHT_START,
	FIRE,
	DAMAGE,
	HEAL,
	SHIELD,
	COLLAPSE,
	DEATH,
	FIGHT_END,
	STATUS_APPLIED,
	STATUS_DAMAGE,
	STATUS_ENDED,
	STATUS_REDUCED,
	AURA,
	SYNERGY,
	PHASE,
	DEED_LEVEL,
	MOVE,
	STOP,
	TARGET,
	SHOT,
	SHOT_FIZZLED,
	CAST,
	CAST_CANCELLED,
	SAVED,
	MANA_DRAIN,
	BREAK_FREE,
	PUSH,
	LEAP,
	CHARGE,
	HOP,
	AREA_WARNING,
	AREA_LANDED,
	COLLAPSE_RING,
	SUMMON,
	TACTIC,
	ZONE,
	SNARE,
	WALL,
	GUARD,
	LIFESTEAL,
	STATUS_EXTENDED,
	RISE,
	RESISTED,
	DODGED,
	ARRIVE,
	## Phase 8 part 2 (Links): a linked ally's part of a hit on another;
	## target: the ally; note: the unit first hit; source: the link.
	SHARED,
	## Phase 8 part 2 (Walls): a wall with HP is worn down (note "shot" or
	## "struck", ", broken" when it breaks; source: the shot's or attack's,
	## amount: what it took) or taken down by a newer one ("gone", amount 0,
	## source: the wall's); wall_of: the wall's unit; from_pos and to_pos
	## its ends.
	WALL_HIT,
	## Phase 8 part 2 (The Hearthkeeper): target gains `amount` max HP (and
	## HP) for the fight; source: what gave it.
	MAX_HP_UP,
	## Phase 8 part 3 (Water): the water changes; note: how ("floods 7 hexes
	## for 6s", "recedes"); amount: how many hexes are water now; to_pos:
	## where; source: the flood's.
	WATER,
	## Phase 8 part 3 (Islands): target falls into the void at to_pos (it
	## goes in the deaths step); source: the push, pull, or carry that moved
	## it there; note "into the void".
	FELL,
}

const COLLAPSE_SOURCE: String = "rift_collapse"

var tick: int
var kind: Kind
var source_unit: String = ""
var source_ability: String = ""
var source_ability_name: String = ""
## Relic effects: the side holding the relic (source_ability is the relic);
## -1 when the source is a unit.
var source_relic_side: int = -1
## The source is a duo bond's own effect (see EffectSource.synergy).
var source_synergy: bool = false
## The source is a Rift Tear's own effect (see EffectSource.rift).
var source_rift: bool = false
## DAMAGE, HEAL: what made the number bigger ("+20% from Casters first": a
## tactic's payoff), or "".
var bonus: String = ""
var target: String = ""
## DAMAGE/COLLAPSE/STATUS_DAMAGE: the hit's full damage. HEAL: HP restored.
## SHIELD: shield given. STATUS_APPLIED: stacks added. MANA_DRAIN: mana
## taken, in hundredths (Mana.SCALE).
var amount: int = 0
## Damage kinds: how much of `amount` the target's shield absorbed.
var absorbed: int = 0
## DAMAGE: how much DEF blocked before `amount` (amount is what got through).
var mitigated: int = 0
var crit: bool = false
## Status kinds: which status.
var status: String = ""
var status_name: String = ""
## STATUS_APPLIED: the status's total stacks afterward.
var stacks: int = 0
var note: String = ""
## Made by a passive's effect (an event's, a timed one's, on_fall's).
var from_event: bool = false
## How deep in a chain of event effects it was made (phase 5c step 3): 0 for
## what a unit does on its own, one more than the entry that set off the
## effect that made it. One at the fight's chain_limit sets off nothing.
var chain: int = 0
## DAMAGE, STATUS_DAMAGE: it took the last of the target's Shield.
var broke_shield: bool = false
## DAMAGE: what went past the target's last HP (phase 5c step 5b).
var overkill: int = 0
## HEAL: lifesteal that heals (Blood Communion; phase 5c step 5c).
var lifesteal: bool = false
## SHOT_FIZZLED stopped by a wall, WALL_HIT: the wall's unit (phase 8 part 2).
var wall_of: String = ""
## DAMAGE: how many times it crit in a row (Crown of Stars; 1 for a plain
## crit, 0 for none).
var crits: int = 0
## For testing only (phase 5c step 9a, the combo readout; never in the
## log's text): how the damage rule made a DAMAGE, HEAL, SHIELD, or
## STATUS_DAMAGE number: its base (-1 where no rule was applied: an
## overheal's Shield, a relic's) and each kind's bonus (basis points; plain
## ints, so a hit allocates nothing); and whether this is the first entry of
## a passive's firing (Passives._run), so engines' fires can be counted.
var rule_base: int = -1
var rule_power: int = 0
var rule_crit: int = 0
var rule_vulnerability: int = 0
var rule_relic: int = 0
var starts_fire: bool = false


## Sets the damage rule's note (see rule_base).
func set_rule(base: int, power_bp: int, crit_bp: int, vulnerability_bp: int, relic_bp: int) -> void:
	rule_base = base
	rule_power = power_bp
	rule_crit = crit_bp
	rule_vulnerability = vulnerability_bp
	rule_relic = relic_bp


## The number the rule made (-1 without one).
func ruled_amount() -> int:
	return DamageRule.apply(rule_base, rule_power, rule_crit, rule_vulnerability, rule_relic) if rule_base >= 0 else -1
## MOVE: where the leg starts and the point it heads for; the unit moves
## `amount` a tick straight at it (FixedMath / ArenaPlane.step_toward) until it
## gets there or its next MOVE or STOP. STOP: to_pos is where it stands.
## SHOT: from the shooter to where the target stood when it was fired.
var from_pos: Vector2i = Vector2i.ZERO
var to_pos: Vector2i = Vector2i.ZERO
## MOVE: the tick it should arrive; SHOT: the tick it lands; CAST: the tick
## the cast ends; STATUS_APPLIED: the tick a timed status ends (-1: it isn't
## timed, like Engaged).
var end_tick: int = 0
## COLLAPSE_RING: amount is the ring (0 = the border), note "warned" or
## "crumbled", from_pos and to_pos the corners of the safe rectangle it
## leaves, end_tick the tick it crumbles.
## SUMMON: target is the new unit and to_pos where it appears; or, when a
## summon is dropped, target is the kit and note says why.
## AREA_WARNING, AREA_LANDED, ZONE: the shape ("circle 2"); from_pos is where
## it's placed (a line's or cone's start), to_pos a line's or cone's far end
## (or the center again). AREA_LANDED: amount is how many it hit. ZONE: a
## zone appears, and end_tick is the tick it ends (phase 4).
## SNARE (phase 4): note "set" (from_pos: where), "sprung" (target: who), or
## "gone". WALL: from_pos and to_pos its ends, end_tick when it falls.
## GUARD: the guard (source) takes `amount` of a hit on `target`.
var shape: String = ""


func set_source(source: EffectSource) -> void:
	source_unit = source.unit_id
	source_ability = source.ability_id
	source_ability_name = source.ability_name
	source_relic_side = source.relic_side
	source_synergy = source.synergy
	source_rift = source.rift
	bonus = source.bonus


func source() -> EffectSource:
	var result: EffectSource = EffectSource.make(source_unit, source_ability, source_ability_name)
	result.relic_side = source_relic_side
	result.synergy = source_synergy
	result.rift = source_rift
	return result


func source_text() -> String:
	return source().describe()


func to_text() -> String:
	var line: String = "[%s] " % _format_time(tick)
	match kind:
		Kind.FIGHT_START:
			return line + "Fight begins (%s)" % note
		Kind.FIRE:
			return line + "%s fires%s" % [source_text(), "" if note.is_empty() else " " + note]
		Kind.DAMAGE:
			return line + "%s hits %s for %d%s" % [source_text(), target, amount, _damage_detail()]
		Kind.HEAL:
			var why: Array[String] = []
			if not bonus.is_empty():
				why.append(bonus)
			if lifesteal:
				why.append("lifesteal")
			return line + "%s heals %s for %d%s" % [source_text(), target, amount, "" if why.is_empty() else " (%s)" % ", ".join(why)]
		Kind.SHIELD:
			return line + "%s gives %s %d shield" % [source_text(), target, amount]
		Kind.COLLAPSE:
			return line + "Rift Collapse hits %s for %d%s" % [target, amount, _damage_detail()]
		Kind.DEATH:
			return line + "%s falls (%s)" % [target, note]
		Kind.FIGHT_END:
			return line + note
		Kind.STATUS_APPLIED:
			if stacks == 0 and end_tick < 0:
				return line + "%s applies %s to %s" % [source_text(), status_name, target]
			if stacks == 0:
				return line + "%s applies %s to %s until %s" % [source_text(), status_name, target, _format_time(end_tick)]
			return line + "%s applies %d %s to %s (%d total)%s" % [source_text(), amount, status_name, target, stacks, "" if note.is_empty() else " " + note]
		Kind.STATUS_DAMAGE:
			return line + "%s (%s) hits %s for %d%s" % [status_name, source_text(), target, amount, _damage_detail()]
		Kind.STATUS_ENDED:
			return line + "%s on %s%s ends" % [status_name, target, "" if note.is_empty() else " (%s)" % note]
		Kind.AURA:
			return line + "%s aura %s" % [source_text(), note]
		Kind.SYNERGY:
			return line + note
		Kind.PHASE:
			return line + "%s enters %s" % [target, note]
		Kind.DEED_LEVEL:
			return line + "%s reaches %s" % [target, note]
		Kind.WATER:
			return line + "%s %s (%d water hexes)" % [source_text(), note, amount]
		Kind.FELL:
			return line + "%s falls into the void at %s (moved by %s)" % [target, _point(to_pos), source_text()]
		Kind.MOVE:
			return line + "%s walks from %s toward %s%s" % [source_unit, _point(from_pos), _point(to_pos), "" if note.is_empty() else " (%s)" % note]
		Kind.STOP:
			return line + "%s stops at %s%s" % [source_unit, _point(to_pos), "" if note.is_empty() else " (%s)" % note]
		Kind.TARGET:
			if target.is_empty():
				return line + "%s has no target (%s)" % [source_unit, note]
			return line + "%s targets %s: %s" % [source_unit, target, note]
		Kind.SHOT:
			return line + "%s shoots at %s (lands at %s)" % [source_text(), target, _format_time(end_tick)]
		Kind.SHOT_FIZZLED:
			return line + "%s's shot at %s fizzles (%s)" % [source_text(), target, note]
		Kind.STATUS_REDUCED:
			return line + "%s on %s loses %d stacks (%s)" % [status_name, target, amount, note]
		Kind.CAST:
			return line + "%s starts casting at %s (lands at %s)" % [source_text(), target, _format_time(end_tick)]
		Kind.CAST_CANCELLED:
			return line + "%s's cast is cancelled (%s)" % [source_text(), note]
		Kind.SAVED:
			return line + "%s is held at 1 HP by %s (%s)" % [target, source_text(), note]
		Kind.PUSH:
			return line + "%s: %s is %s from %s to %s" % [source_text(), target, note, _point(from_pos), _point(to_pos)]
		Kind.LEAP:
			if from_pos == to_pos:
				return line + "%s can't leap to %s (%s)" % [source_text(), target, note]
			return line + "%s leaps from %s to %s beside %s (lands at %s)" % [source_text(), _point(from_pos), _point(to_pos), target, _format_time(end_tick)]
		Kind.CHARGE:
			return line + "%s charges at %s from %s to %s%s" % [source_text(), target, _point(from_pos), _point(to_pos), "" if note.is_empty() else " (%s)" % note]
		Kind.AREA_WARNING:
			return line + "%s marks a %s at %s (lands at %s)" % [source_text(), shape, _point(from_pos), _format_time(end_tick)]
		Kind.AREA_LANDED:
			return line + "%s: the %s at %s lands, hitting %d%s" % [source_text(), shape, _point(from_pos), amount, "" if note.is_empty() else " (%s)" % note]
		Kind.ZONE:
			return line + "%s: a %s stays at %s until %s" % [source_text(), shape, _point(from_pos), _format_time(end_tick)]
		Kind.SNARE:
			match note:
				"set":
					return line + "%s sets a snare at %s" % [source_text(), _point(from_pos)]
				"sprung":
					return line + "%s: %s steps in the snare at %s" % [source_text(), target, _point(from_pos)]
			return line + "%s: the snare at %s is gone (too many standing)" % [source_text(), _point(from_pos)]
		Kind.WALL:
			if end_tick >= CombatSim.NEVER:
				return line + "%s raises a wall from %s to %s (it stands until broken)" % [source_text(), _point(from_pos), _point(to_pos)]
			return line + "%s raises a wall from %s to %s (falls at %s)" % [source_text(), _point(from_pos), _point(to_pos), _format_time(end_tick)]
		Kind.MAX_HP_UP:
			return line + "%s: %s's max HP rises by %d" % [source_text(), target, amount]
		Kind.WALL_HIT:
			if note == "gone":
				return line + "%s: the wall from %s to %s comes down (too many standing)" % [source_text(), _point(from_pos), _point(to_pos)]
			return line + "%s %s %s's wall for %d%s" % [source_text(), "strikes" if note.begins_with("struck") else "shoots", wall_of, amount, ", and it breaks" if note.ends_with("broken") else ""]
		Kind.GUARD:
			return line + "%s takes %d of the hit on %s" % [source_text(), amount, target]
		Kind.SHARED:
			return line + "%s: %s takes %d of the hit on %s" % [source_text(), target, amount, note]
		Kind.RISE:
			return line + "%s: %s rises at %s with %d HP" % [source_text(), target, _point(to_pos), amount]
		Kind.RESISTED:
			return line + "%s resists %s from %s (%s)" % [target, status_name, source_text(), note]
		Kind.DODGED:
			return line + "%s's hit misses %s (Sidestep)" % [source_text(), target]
		Kind.ARRIVE:
			return line + "%s: %s arrives at %s" % [source_text(), target, _point(to_pos)]
		Kind.LIFESTEAL:
			return line + "%s: %s steals back %d HP" % [source_text(), target, amount]
		Kind.STATUS_EXTENDED:
			return line + "%s makes %s on %s last until %s" % [source_text(), status_name, target, _format_time(end_tick)]
		Kind.COLLAPSE_RING:
			if note == "warned":
				return line + "%s: ring %d will crumble at %s" % [source_text(), amount, _format_time(end_tick)]
			return line + "Rift Collapse: ring %d crumbles, leaving %s to %s" % [amount, _point(from_pos), _point(to_pos)]
		Kind.TACTIC:
			return line + "%s: %s" % [source_text(), note]
		Kind.SUMMON:
			if not note.is_empty():
				return line + "%s can't summon %s (%s)" % [source_text(), target, note]
			return line + "%s summons %s at %s" % [source_text(), target, _point(to_pos)]
		Kind.HOP:
			return line + "%s hops away from %s, from %s to %s%s" % [source_unit, target, _point(from_pos), _point(to_pos), "" if note.is_empty() else " (%s)" % note]
		Kind.BREAK_FREE:
			return line + "%s breaks free of %s" % [source_unit, target]
		Kind.MANA_DRAIN:
			return line + "%s drains %s mana from %s%s" % [source_text(), Mana.text(amount), target, "" if note.is_empty() else " (%s)" % note]
	return line + "?"


func _damage_detail() -> String:
	var parts: Array[String] = []
	if (kind == Kind.DAMAGE or kind == Kind.COLLAPSE or kind == Kind.STATUS_DAMAGE) and not note.is_empty():
		parts.append(note)
	if not bonus.is_empty():
		parts.append(bonus)
	if crit:
		parts.append("crit" if crits <= 1 else "crit x%d" % crits)
	if mitigated > 0:
		parts.append("%d blocked by defense" % mitigated)
	if absorbed > 0:
		parts.append("%d absorbed by shield" % absorbed)
	return "" if parts.is_empty() else " (%s)" % ", ".join(parts)


## A point on the plane in hexes, like "(3.10, 4.00)".
static func _point(point: Vector2i) -> String:
	return "(%s, %s)" % [_hexes(point.x), _hexes(point.y)]


static func _hexes(units: int) -> String:
	var sign: String = "-" if units < 0 else ""
	var value: int = absi(units)
	@warning_ignore("integer_division")
	return "%s%d.%02d" % [sign, value / 1000, (value % 1000) / 10]


static func _format_time(at_tick: int) -> String:
	var ms: int = at_tick * FixedMath.MS_PER_TICK
	@warning_ignore("integer_division")
	return "%d.%02ds" % [ms / 1000, (ms % 1000) / 10]
