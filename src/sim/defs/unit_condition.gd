class_name UnitCondition
extends RefCounted
## "A unit that is ..." (docs/plans/rebuild-phase5c-combos.md, step 3,
## section 8.3): the one shape cards use to look at a unit's state. Every
## field given must hold; a list holds if any of it does:
##   {"keywords": ["rooted"]}                Rooted (Keywords.NAMES)
##   {"statuses": ["root", "stun"]}          Rooted or Stunned (any status id)
##   {"below_hp_pct": 30}                    below 30% of its max HP
##   {"flying": true}                        a flier (false: not one)
##   {"archetypes": ["caster", "support"]}   an enemy of these archetypes
##   {"front_most": true}                    its side's standing unit nearest
##                                           the other side (phase 5c step
##                                           7c; CombatSim marks it each tick)
## Used as an event effect's "vs" (the unit the event names), a damage_bp
## aura's "vs" (the target of the hit), and an aura's "while": "state" (its
## holder).

enum Flying { ANY, YES, NO }

var keywords: Array[String] = []
var statuses: Array[String] = []
## 0: no HP condition.
var below_hp_bp: int = 0
var flying: Flying = Flying.ANY
var archetypes: Array[String] = []
var front_most: bool = false


static func read(reader: DataReader) -> UnitCondition:
	var def := UnitCondition.new()
	if reader == null:
		return def
	def.keywords = reader.opt_choice_array("keywords", Keywords.NAMES)
	if reader.has("statuses"):
		def.statuses = reader.req_string_array("statuses")
	if reader.has("below_hp_pct"):
		def.below_hp_bp = reader.req_int("below_hp_pct", 1, 99) * 100
	if reader.has("flying"):
		def.flying = Flying.YES if reader.opt_bool("flying", true) else Flying.NO
	def.archetypes = reader.opt_choice_array("archetypes", EnemyDef.ARCHETYPE_NAMES)
	def.front_most = reader.opt_bool("front_most", false)
	if def.is_empty():
		reader.error("a condition needs at least one of keywords, statuses, below_hp_pct, flying, archetypes, or front_most")
	reader.finish()
	return def


func is_empty() -> bool:
	return keywords.is_empty() and statuses.is_empty() and below_hp_bp == 0 and flying == Flying.ANY and archetypes.is_empty() and not front_most


## True if `unit` meets every field given.
func holds(unit: UnitState) -> bool:
	if below_hp_bp > 0 and unit.hp * FixedMath.BP_ONE >= below_hp_bp * unit.max_hp:
		return false
	if flying != Flying.ANY and unit.flying != (flying == Flying.YES):
		return false
	if not archetypes.is_empty() and not archetypes.has(unit.def.archetype):
		return false
	if front_most and not unit.front_most:
		return false
	if not keywords.is_empty() and not _has_keyword(unit):
		return false
	if not statuses.is_empty() and not _has_status(unit):
		return false
	return true


func _has_keyword(unit: UnitState) -> bool:
	for keyword: String in keywords:
		if Keywords.has(unit, keyword):
			return true
	return false


func _has_status(unit: UnitState) -> bool:
	for state: StatusState in unit.statuses:
		if statuses.has(state.def.id):
			return true
	return false


## In words, for the log and the cards: "Rooted or Shielded, below 30% HP".
## Status ids read as names ("stun" -> "Stun").
func describe() -> String:
	var parts: Array[String] = []
	var states: Array[String] = []
	for keyword: String in keywords:
		states.append(Keywords.label(keyword))
	for status_id: String in statuses:
		states.append(status_id.replace("_", " ").capitalize())
	if not states.is_empty():
		parts.append(" or ".join(states))
	if below_hp_bp > 0:
		@warning_ignore("integer_division")
		parts.append("below %d%% HP" % (below_hp_bp / 100))
	if flying != Flying.ANY:
		parts.append("flying" if flying == Flying.YES else "not flying")
	if not archetypes.is_empty():
		parts.append(" or ".join(archetypes))
	if front_most:
		parts.append("the front-most")
	return ", ".join(parts)
