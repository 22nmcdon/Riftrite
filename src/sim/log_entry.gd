class_name LogEntry
extends RefCounted
## One line of the combat log. Every effect names its source unit, item, and
## infusion (CLAUDE.md rule 4); Rift Collapse uses the source item
## "rift_collapse".

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
	MISS,
	STATUS_REDUCED,
}

const COLLAPSE_SOURCE: String = "rift_collapse"

var tick: int
var kind: Kind
var source_unit: String = ""
var source_item: String = ""
var source_item_name: String = ""
## Essence id if the effect came from an infusion, else "".
var source_infusion: String = ""
var source_infusion_name: String = ""
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


func set_source(source: EffectSource) -> void:
	source_unit = source.unit_id
	source_item = source.item_id
	source_item_name = source.item_name
	source_infusion = source.infusion_id
	source_infusion_name = source.infusion_name


func source_text() -> String:
	return EffectSource.make(source_unit, source_item, source_item_name, source_infusion, source_infusion_name).describe()


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
			return line + "%s on %s ends" % [status_name, target]
		Kind.STATUS_REDUCED:
			return line + "%s on %s loses %d stacks (%s)" % [status_name, target, amount, note]
		Kind.MISS:
			return line + "%s misses %s (%s)" % [source_text(), target, note]
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
