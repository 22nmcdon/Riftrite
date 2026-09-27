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
var target: String = ""
## DAMAGE/COLLAPSE/STATUS_DAMAGE: the hit's full damage. HEAL: HP restored.
## SHIELD: shield given. STATUS_APPLIED: stacks added.
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
## Made by an event effect: never sets off another one.
var from_event: bool = false


func set_source(source: EffectSource) -> void:
	source_unit = source.unit_id
	source_ability = source.ability_id
	source_ability_name = source.ability_name
	source_relic_side = source.relic_side
	source_synergy = source.synergy


func source() -> EffectSource:
	var result: EffectSource = EffectSource.make(source_unit, source_ability, source_ability_name)
	result.relic_side = source_relic_side
	result.synergy = source_synergy
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
			return line + "%s heals %s for %d" % [source_text(), target, amount]
		Kind.SHIELD:
			return line + "%s gives %s %d shield" % [source_text(), target, amount]
		Kind.COLLAPSE:
			return line + "Rift Collapse hits %s for %d%s" % [target, amount, _damage_detail()]
		Kind.DEATH:
			return line + "%s falls (%s)" % [target, note]
		Kind.FIGHT_END:
			return line + note
		Kind.STATUS_APPLIED:
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
		Kind.STATUS_REDUCED:
			return line + "%s on %s loses %d stacks (%s)" % [status_name, target, amount, note]
	return line + "?"


func _damage_detail() -> String:
	var parts: Array[String] = []
	if crit:
		parts.append("crit")
	if mitigated > 0:
		parts.append("%d blocked by defense" % mitigated)
	if absorbed > 0:
		parts.append("%d absorbed by shield" % absorbed)
	return "" if parts.is_empty() else " (%s)" % ", ".join(parts)


static func _format_time(at_tick: int) -> String:
	var ms: int = at_tick * FixedMath.MS_PER_TICK
	@warning_ignore("integer_division")
	return "%d.%02ds" % [ms / 1000, (ms % 1000) / 10]
