class_name UnitCondition
extends RefCounted
## "A unit that is ..." (docs/plans/rebuild-phase5c-combos.md, step 3,
## section 8.3): the one shape cards use to look at a unit's state. Every
## field given must hold; a list holds if any of it does:
##   {"keywords": ["rooted"]}                Rooted (Keywords.NAMES)
##   {"statuses": ["root", "stun"]}          Rooted or Stunned (any status id)
##   {"all_statuses": ["burn", "poison"]}    Burning and Poisoned: every one
##                                           (phase 8 part 6, Ottilie)
##   {"below_hp_pct": 30}                    below 30% of its max HP
##   {"above_hp_pct": 90}                    above 90% of its max HP (the
##                                           tuning phase; Full Vigor)
##   {"flying": true}                        a flier (false: not one)
##   {"archetypes": ["caster", "support"]}   an enemy of these archetypes
##   {"front_most": true}                    its side's standing unit nearest
##                                           the other side (phase 5c step
##                                           7c; CombatSim marks it each tick)
##   {"ranks": ["elite", "boss"]}            an enemy of these ranks (phase 8
##                                           part 6, Assayer; UnitDef.rank)
##   {"kits": ["drowned_thrall"]}            of one of these kits (phase 8
##                                           part 3; the Tolling Bellringer)
##   {"on_water": true}                      standing on water (phase 8 part
##                                           3; Water.mark; false: not)
##   {"same_island": true}                   on the island the condition's
##                                           holder stands on (phase 8 part
##                                           3; Islands.mark; every unit is,
##                                           in a fight without void)
##   {"engorged_pct": 20}                    Engorge has raised its max HP by
##                                           at least this share of what it
##                                           was before (phase 8 part 5,
##                                           Heavy Frame)
##   {"shield_above_pct": 100}               its Shield is more than this
##                                           share of its max HP (phase 8
##                                           part 4; Plate on Plate)
##   {"targets_holder": false}               its target isn't (true: is) the
##                                           condition's holder (phase 8
##                                           part 4; Backstab)
##   {"targets_owner": true}                 its target is the holder's
##                                           owner (a companion's hero;
##                                           phase 8 part 6, Guard Dog)
##   {"chased_by_summons": 2}                at least that many summons of
##                                           the other side target it
##                                           (phase 8 part 6, Pack Tactics;
##                                           CombatSim.mark_chasers)
##   {"target": {...a condition...}}         its target meets that one
##                                           (phase 8 part 4; Stalker: while
##                                           her target is Marked)
##   {"ranged": true}                        its range is 2 or more (false:
##                                           melee; phase 8 part 4, Gale)
##   {"target_beyond_hexes": 3}              its target stands this many
##                                           hexes away or more (phase 8
##                                           part 4, Tailwind)
##   {"shielded": false}                     it has no Shield (true: it has
##                                           one; phase 8 part 5, Steady
##                                           Hallow)
##   {"raised": true}                        a thrall Gravecaller raised (phase
##                                           8 part 5; Plague Thralls)
##   {"fired_over_full": true}               its signature last fired with
##                                           mana past a full bar (phase 8
##                                           part 4, Wellspring)
##   {"summon": true}                        a summon (phase 8 part 6, Howl:
##                                          companions, Nest's vipers, thralls)
##   {"copy": true}                          a copy (phase 8 part 6, Lucan's
##                                          cards: UnitState.mirror_of)
##   {"struck_from_stealth": true}           its last basic attack's hit was
##                                          from Stealth (phase 8 part 6,
##                                          Veilweaver: an on_ally_hit's "by")
##   {"without": ["bounty"]}                 none of these statuses on it
##                                           (phase 8 part 6, Bounty: the
##                                           next toughest without one)
##   {"others": true}                        any unit but the condition's
##                                           holder (phase 8 part 6, Elixir:
##                                           mana for every other ally)
## Used as an event effect's "vs" (the unit the event names), a damage_bp
## aura's "vs" (the target of the hit), and an aura's "while": "state" (its
## holder).

enum Flying { ANY, YES, NO }

var keywords: Array[String] = []
var statuses: Array[String] = []
## Every one of these (phase 8 part 6).
var all_statuses: Array[String] = []
## None of these (phase 8 part 6, Bounty).
var without: Array[String] = []
## Of these ranks (phase 8 part 6).
var ranks: Array[String] = []
## 0: no HP condition.
var below_hp_bp: int = 0
var above_hp_bp: int = 0
var flying: Flying = Flying.ANY
var archetypes: Array[String] = []
var front_most: bool = false
var on_water: Flying = Flying.ANY
var kits: Array[String] = []
## Built in code, never read (phase 8 part 6, The Menagerie): a unit meets the
## condition if it meets any of these (KitMod's per_twice on an aura that
## already has one keeps both).
var any_of: Array[UnitCondition] = []
var same_island: bool = false
## 0: no Shield condition.
var shield_above_bp: int = 0
## Engorge's growth, as a share of max HP before it (0: no such condition).
var engorged_bp: int = 0
## Whether its target is the holder (ANY: either; phase 8 part 4).
var targets_holder: Flying = Flying.ANY
## A condition its target meets (null: none; phase 8 part 4).
var target: UnitCondition = null
## Its range is 2 or more (YES) or 1 (NO) (phase 8 part 4).
var ranged: Flying = Flying.ANY
## Has a Shield, or (NO) none (phase 8 part 5).
var shielded: Flying = Flying.ANY
## 0: no distance to its target asked (phase 8 part 4).
var target_beyond: int = 0
## Its signature last fired from past a full bar (phase 8 part 4).
var fired_over_full: bool = false
var raised: bool = false
## Not the holder itself (phase 8 part 6).
var others: bool = false
## A summon (phase 8 part 6).
var summon: bool = false
## A copy (phase 8 part 6, Lucan).
var copy: bool = false
## Its last basic attack's hit was from Stealth (phase 8 part 6).
var struck_from_stealth: bool = false
## Its target is the holder's owner (phase 8 part 6).
var targets_owner: bool = false
## 0: not asked; else at least that many summons target it (phase 8 part 6).
var chased_by_summons: int = 0


static func read(reader: DataReader) -> UnitCondition:
	var def := UnitCondition.new()
	if reader == null:
		return def
	def.keywords = reader.opt_choice_array("keywords", Keywords.NAMES)
	if reader.has("statuses"):
		def.statuses = reader.req_string_array("statuses")
	if reader.has("all_statuses"):
		def.all_statuses = reader.req_string_array("all_statuses")
	if reader.has("without"):
		def.without = reader.req_string_array("without")
	def.ranks = reader.opt_choice_array("ranks", ["elite", "boss"])
	if reader.has("below_hp_pct"):
		def.below_hp_bp = reader.req_int("below_hp_pct", 1, 99) * 100
	if reader.has("above_hp_pct"):
		def.above_hp_bp = reader.req_int("above_hp_pct", 1, 99) * 100
	if reader.has("flying"):
		def.flying = Flying.YES if reader.opt_bool("flying", true) else Flying.NO
	def.archetypes = reader.opt_choice_array("archetypes", EnemyDef.ARCHETYPE_NAMES)
	def.front_most = reader.opt_bool("front_most", false)
	if reader.has("kits"):
		def.kits = reader.req_string_array("kits")
	if reader.has("on_water"):
		def.on_water = Flying.YES if reader.opt_bool("on_water", true) else Flying.NO
	def.same_island = reader.opt_bool("same_island", false)
	if reader.has("engorged_pct"):
		def.engorged_bp = reader.req_int("engorged_pct", 1, 1000) * 100
	if reader.has("shield_above_pct"):
		def.shield_above_bp = reader.req_int("shield_above_pct", 1, 1000) * 100
	if reader.has("targets_holder"):
		def.targets_holder = Flying.YES if reader.opt_bool("targets_holder", true) else Flying.NO
	if reader.has("target"):
		def.target = read(reader.req_object("target"))
	if reader.has("ranged"):
		def.ranged = Flying.YES if reader.opt_bool("ranged", true) else Flying.NO
	if reader.has("shielded"):
		def.shielded = Flying.YES if reader.opt_bool("shielded", true) else Flying.NO
	if reader.has("target_beyond_hexes"):
		def.target_beyond = reader.req_int("target_beyond_hexes", 1, 10) * HexGrid.HEX
	def.fired_over_full = reader.opt_bool("fired_over_full", false)
	def.raised = reader.opt_bool("raised", false)
	def.others = reader.opt_bool("others", false)
	def.summon = reader.opt_bool("summon", false)
	def.copy = reader.opt_bool("copy", false)
	def.struck_from_stealth = reader.opt_bool("struck_from_stealth", false)
	def.targets_owner = reader.opt_bool("targets_owner", false)
	def.chased_by_summons = reader.opt_int("chased_by_summons", 0, 0, 30)
	if def.is_empty():
		reader.error("a condition needs at least one of keywords, statuses, all_statuses, without, ranks, below_hp_pct, above_hp_pct, flying, archetypes, front_most, on_water, same_island, shield_above_pct, engorged_pct, targets_holder, target, ranged, shielded, target_beyond_hexes, fired_over_full, raised, others, summon, copy, struck_from_stealth, targets_owner, chased_by_summons, or kits")
	reader.finish()
	return def


func is_empty() -> bool:
	return keywords.is_empty() and statuses.is_empty() and all_statuses.is_empty() and without.is_empty() and ranks.is_empty() and below_hp_bp == 0 and above_hp_bp == 0 and flying == Flying.ANY and archetypes.is_empty() and not front_most and on_water == Flying.ANY and kits.is_empty() and not same_island and shield_above_bp == 0 and engorged_bp == 0 \
		and targets_holder == Flying.ANY and target == null and ranged == Flying.ANY and target_beyond == 0 and not fired_over_full and not raised \
		and shielded == Flying.ANY and not others and not summon and not copy and not struck_from_stealth and not targets_owner and chased_by_summons == 0 and any_of.is_empty()


## A condition met by a unit that meets `first` or `second`.
static func either(first: UnitCondition, second: UnitCondition) -> UnitCondition:
	var def := UnitCondition.new()
	def.any_of.append_array(first.any_of if not first.any_of.is_empty() else [first])
	def.any_of.append(second)
	return def


## True if `unit` meets every field given (or, built by either(), any of
## its conditions). `holder`: whose condition it is (the unit an aura or
## event effect belongs to), for same_island; without one, same_island never
## holds.
func holds(unit: UnitState, holder: UnitState = null) -> bool:
	if not any_of.is_empty():
		return any_of.any(func(each: UnitCondition) -> bool: return each.holds(unit, holder))
	if others and unit == holder:
		return false
	if not without.is_empty() and without.any(func(status_id: String) -> bool: return Statuses.find(unit, status_id) != null):
		return false
	if copy and unit.mirror_of == null:
		return false
	if struck_from_stealth and not unit.struck_from_stealth:
		return false
	if summon and not unit.summoned:
		return false
	if targets_owner and (holder == null or holder.owner == null or unit.target != holder.owner):
		return false
	if chased_by_summons > 0 and unit.chased_by_summons < chased_by_summons:
		return false
	if same_island and (holder == null or unit.island < 0 or unit.island != holder.island):
		return false
	if below_hp_bp > 0 and unit.hp * FixedMath.BP_ONE >= below_hp_bp * unit.max_hp:
		return false
	if above_hp_bp > 0 and unit.hp * FixedMath.BP_ONE <= above_hp_bp * unit.max_hp:
		return false
	if engorged_bp > 0 and unit.engorged * FixedMath.BP_ONE < engorged_bp * (unit.base_max_hp - unit.engorged):
		return false
	if shield_above_bp > 0 and unit.shield * FixedMath.BP_ONE <= shield_above_bp * unit.max_hp:
		return false
	if flying != Flying.ANY and unit.flying != (flying == Flying.YES):
		return false
	if not archetypes.is_empty() and not archetypes.has(unit.def.archetype):
		return false
	if front_most and not unit.front_most:
		return false
	if on_water != Flying.ANY and unit.on_water != (on_water == Flying.YES):
		return false
	if not kits.is_empty() and not kits.has(unit.def.id):
		return false
	if not keywords.is_empty() and not _has_keyword(unit):
		return false
	if not statuses.is_empty() and not _has_status(unit):
		return false
	for status_id: String in all_statuses:
		if Statuses.find(unit, status_id) == null:
			return false
	if not ranks.is_empty() and not ranks.has(unit.def.rank):
		return false
	if targets_holder != Flying.ANY and (holder == null or (unit.target == holder) != (targets_holder == Flying.YES)):
		return false
	if target != null and (unit.target == null or not unit.target.alive or not target.holds(unit.target, holder)):
		return false
	if ranged != Flying.ANY and (unit.stats.get_stat(UnitStats.Stat.RANGE) >= 2) != (ranged == Flying.YES):
		return false
	if shielded != Flying.ANY and (unit.shield > 0) != (shielded == Flying.YES):
		return false
	if target_beyond > 0 and (unit.target == null or not unit.target.alive or ArenaPlane.length_sq(unit.target.pos - unit.pos) < target_beyond * target_beyond):
		return false
	if fired_over_full and unit.last_overflow <= 0:
		return false
	if raised and not unit.raised:
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
	if not any_of.is_empty():
		return " or ".join(any_of.map(func(each: UnitCondition) -> String: return each.describe()))
	var parts: Array[String] = []
	var states: Array[String] = []
	for keyword: String in keywords:
		states.append(Keywords.label(keyword))
	for status_id: String in statuses:
		states.append(status_id.replace("_", " ").capitalize())
	if not states.is_empty():
		parts.append(" or ".join(states))
	if not all_statuses.is_empty():
		parts.append(" and ".join(all_statuses.map(func(status_id: String) -> String: return status_id.replace("_", " ").capitalize())))
	if not ranks.is_empty():
		parts.append(" or ".join(ranks) + "s" if ranks.size() == 1 else "elites or bosses")
	if below_hp_bp > 0:
		@warning_ignore("integer_division")
		parts.append("below %d%% HP" % (below_hp_bp / 100))
	if above_hp_bp > 0:
		@warning_ignore("integer_division")
		parts.append("above %d%% HP" % (above_hp_bp / 100))
	if shield_above_bp > 0:
		@warning_ignore("integer_division")
		parts.append("with a Shield over %d%% of max HP" % (shield_above_bp / 100))
	if engorged_bp > 0:
		@warning_ignore("integer_division")
		parts.append("grown %d%% past its max HP" % (engorged_bp / 100))
	if flying != Flying.ANY:
		parts.append("flying" if flying == Flying.YES else "not flying")
	if not archetypes.is_empty():
		parts.append(" or ".join(archetypes))
	if front_most:
		parts.append("the front-most")
	if on_water != Flying.ANY:
		parts.append("on water" if on_water == Flying.YES else "not on water")
	if same_island:
		parts.append("on its island")
	if not kits.is_empty():
		parts.append(" or ".join(kits.map(func(kit_id: String) -> String: return kit_id.replace("_", " ").capitalize())))
	if targets_holder != Flying.ANY:
		parts.append("targeting it" if targets_holder == Flying.YES else "not targeting it")
	if target != null:
		parts.append("with a target that's %s" % target.describe())
	if ranged != Flying.ANY:
		parts.append("ranged" if ranged == Flying.YES else "melee")
	if shielded != Flying.ANY:
		parts.append("Shielded" if shielded == Flying.YES else "without a Shield")
	if target_beyond > 0:
		@warning_ignore("integer_division")
		parts.append("attacking from %d hexes or more" % (target_beyond / HexGrid.HEX))
	if fired_over_full:
		parts.append("casting from past a full bar")
	if raised:
		parts.append("a raised thrall")
	if not without.is_empty():
		parts.append("without " + " or ".join(without).replace("_", " "))
	if others:
		parts.append("another")
	if summon:
		parts.append("a summon")
	if copy:
		parts.append("a copy")
	if struck_from_stealth:
		parts.append("striking from Stealth")
	if targets_owner:
		parts.append("targeting its hero")
	if chased_by_summons > 0:
		parts.append("attacked by %d or more summons" % chased_by_summons)
	return ", ".join(parts)
