class_name LogEntry
extends RefCounted
## One line of the combat log. Every effect names its source unit and item
## (CLAUDE.md rule 4); Rift Collapse uses the source item "rift_collapse".

enum Kind { FIGHT_START, FIRE, DAMAGE, HEAL, SHIELD, COLLAPSE, DEATH, FIGHT_END }

const COLLAPSE_SOURCE: String = "rift_collapse"

var tick: int
var kind: Kind
var source_unit: String = ""
var source_item: String = ""
var source_item_name: String = ""
var target: String = ""
## DAMAGE/COLLAPSE: the hit's full damage. HEAL: HP restored. SHIELD: shield given.
var amount: int = 0
## DAMAGE/COLLAPSE: how much of `amount` the target's shield absorbed.
var absorbed: int = 0
var crit: bool = false
var note: String = ""


func to_text() -> String:
	var line: String = "[%s] " % _format_time(tick)
	var source: String = "%s · %s" % [source_unit, source_item_name]
	match kind:
		Kind.FIGHT_START:
			return line + "Fight begins (%s)" % note
		Kind.FIRE:
			return line + "%s fires" % source
		Kind.DAMAGE:
			return line + "%s hits %s for %d%s" % [source, target, amount, _damage_detail()]
		Kind.HEAL:
			return line + "%s heals %s for %d" % [source, target, amount]
		Kind.SHIELD:
			return line + "%s gives %s %d shield" % [source, target, amount]
		Kind.COLLAPSE:
			return line + "Rift Collapse hits %s for %d%s" % [target, amount, _damage_detail()]
		Kind.DEATH:
			return line + "%s falls (%s)" % [target, note]
		Kind.FIGHT_END:
			return line + note
	return line + "?"


func _damage_detail() -> String:
	var parts: Array[String] = []
	if crit:
		parts.append("crit")
	if absorbed > 0:
		parts.append("%d absorbed by shield" % absorbed)
	return "" if parts.is_empty() else " (%s)" % ", ".join(parts)


static func _format_time(at_tick: int) -> String:
	var ms: int = at_tick * FixedMath.MS_PER_TICK
	@warning_ignore("integer_division")
	return "%d.%02ds" % [ms / 1000, (ms % 1000) / 10]
