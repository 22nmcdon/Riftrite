class_name TacticDef
extends RefCounted
## A tactic in data/tactics.json (docs/plans/rebuild-phase3b-tactics.md,
## sections 1 and 2; the loadout pool, docs/plans/rebuild-phase5c-combos.md,
## section 14.6): a change to how a hero behaves in a fight, never to what
## they can do. A hero takes at most one (UnitSetup.tactic). Each has a
## kind, which is code (no effect, trigger, or part could change how a unit
## picks, walks, or holds its signature), and that kind's numbers:
##   prefer_target        goes for the nearest enemy it prefers first:
##                        "archetypes" (EnemyDef's names), "prefers" (a
##                        UnitCondition: fliers, Marked), or "pick" (a rule
##                        of its own: "lowest_hp_in_reach", "most_def",
##                        "farthest" for Dive)
##   hold_ground          doesn't walk until an enemy comes within
##                        "release_hexes" (whole hexes), then lets go for good
##   signature_threshold  its mana signature (one that heals: Tactics.can_wait)
##                        waits, full, until an ally in its reach is below
##                        "below_pct" of max HP
##   stop_near            doesn't walk while an enemy stands within
##                        "stop_hexes"; closes in again when none does
##   guard_ally           goes for the enemy attacking its ally lowest on HP
##                        (Guard the weakest)
##   kite                 backs away to keep its target at its full reach
##                        (Keep your distance)
##   leash                stays within "leash_hexes" of its ally with the most
##                        DEF (Stay with the tank)
##   signature_crowd      its mana signature with an area waits, full, until
##                        "crowd" enemies (or all still standing, if fewer)
##                        are in its area, "max_wait_ms" at most
##   signature_finish     its mana signature that deals damage waits, full,
##                        until its target is below "below_pct" of max HP
## Any hero can take any tactic (the loadout's rule 1); one that can't follow
## it (Tactics.can_follow) does nothing in a run, and Practice doesn't offer
## it. "text" is the player's sentence, like every ability's.
## "payoff" pays for the behavior, only while it applies (round 2, section
## 9; the loadout's tactics), every key optional:
##   damage_vs_bp   more damage from its own hits on the enemies it prefers
##                  (or "payoff_vs": a UnitCondition of its own)
##   crit_vs_bp     more crit chance on them (Marked first)
##   def_ignore_bp  its hits on its target ignore that share of its DEF
##   atsp_bp        a faster attack (hold_ground: while it holds)
##   atsp_add       ATSP points while its order applies (kite)
##   def_add, def_bp, atk_mgk_bp   DEF points, DEF, or ATK and MGK while its
##                  order applies (an aura Tactics adds to its kit)
##   window_ms      ATK and MGK (atk_mgk_bp) only for its first that long
##                  (Dive)
##   heal_bp        more healing from the fire that waited
##   power_bp       more damage from the signature that waited
##   regen_bp       that share of its max HP a second while its order applies
## And a rank III's twist (code, in Tactics), each optional:
##   keep_bp            hold_ground: that share of atsp_bp after letting go
##   first_hit          {"status", "duration_ms", "stacks"}: put on each
##                      enemy it prefers (any, with "pick") the first time it
##                      hits it
##   crit_extends_mark_ms  its crits on Marked enemies make the Mark last
##                      that much longer
##   kill_mana          its kills give it that much mana
##   restart_on_kill    a kill within window_ms starts the window again
##   cleanse_one        the heal that waited also takes one harmful status
##                      off the unit it heals
##   ally_def_add       guard_ally: the ally it guards gets DEF points too
##   crit_after_back    kite: its first attack after backing away crits
##   per_extra_bp       signature_crowd: more for each enemy in the area
##                      past "crowd"
##   refund_bp          signature_finish: a kill with its signature refunds
##                      that share of its bar
## "ranks": [{...}, {...}] are ranks II and III: each changes any of the
## kind's numbers, the payoff's keys, and the twists (at_rank()).

enum Kind { PREFER_TARGET, HOLD_GROUND, SIGNATURE_THRESHOLD, STOP_NEAR, GUARD_ALLY, KITE, LEASH, SIGNATURE_CROWD, SIGNATURE_FINISH }

const KIND_NAMES: Array[String] = ["prefer_target", "hold_ground", "signature_threshold", "stop_near", "guard_ally", "kite", "leash",
	"signature_crowd", "signature_finish"]
const PICKS: Array[String] = ["lowest_hp_in_reach", "most_def", "farthest"]
## The kinds that hold a mana signature.
const SIGNATURE_KINDS: Array[Kind] = [Kind.SIGNATURE_THRESHOLD, Kind.SIGNATURE_CROWD, Kind.SIGNATURE_FINISH]

var id: String
var name: String
var text: String
var kind: Kind
## Its rank (1 to 3): at_rank()'s.
var rank: int = 1
## prefer_target: the archetypes it goes for first (EnemyDef.ARCHETYPE_NAMES),
## a condition, or a pick of its own.
var archetypes: Array[String] = []
var prefers: UnitCondition = null
var pick: String = ""
## hold_ground: how near an enemy lets it go, on the plane (center to center).
var release_range: int = 0
## stop_near: how near an enemy stops its walking, on the plane.
var stop_range: int = 0
## signature_threshold, signature_finish: the HP share (basis points) an ally
## (its target) must be below.
var below_bp: int = 0
## leash: how near its ally with the most DEF it stays, on the plane.
var leash_range: int = 0
## signature_crowd: how many enemies, and how long it waits at most.
var crowd: int = 0
var max_wait_ticks: int = 0
## Who can take it, by hero id (empty: anyone; the loadout's rule 1).
var heroes: Array[String] = []
## The payoff, in basis points or points (0: none).
var damage_vs_bp: int = 0
var payoff_vs: UnitCondition = null
var crit_vs_bp: int = 0
var def_ignore_bp: int = 0
var atsp_bp: int = 0
var atsp_add: int = 0
var def_add: int = 0
var def_bp: int = 0
var atk_mgk_bp: int = 0
var window_ticks: int = 0
var heal_bp: int = 0
var power_bp: int = 0
var regen_bp: int = 0
## The twists (rank III's).
var keep_bp: int = 0
var first_hit_status: String = ""
var first_hit_ticks: int = 0
var first_hit_stacks: int = 1
var crit_extends_mark_ticks: int = 0
var kill_mana: int = 0
var restart_on_kill: bool = false
var cleanse_one: bool = false
var ally_def_add: int = 0
var crit_after_back: bool = false
var per_extra_bp: int = 0
var refund_bp: int = 0
## Ranks II and III: their own copies (at_rank).
var _ranks: Array[TacticDef] = []


static func read(reader: DataReader) -> TacticDef:
	var def := TacticDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	def.text = reader.req_string("text")
	def.kind = maxi(KIND_NAMES.find(reader.req_choice("kind", KIND_NAMES)), 0) as Kind
	_read_numbers(def, reader, true)
	if reader.has("payoff"):
		var payoff: DataReader = reader.req_object("payoff")
		if payoff != null:
			_read_payoff(def, payoff)
			payoff.finish()
	if def.kind == Kind.PREFER_TARGET and def.archetypes.is_empty() and def.prefers == null and def.pick.is_empty():
		reader.error("a prefer_target tactic needs \"archetypes\", \"prefers\", or \"pick\"")
	if reader.has("heroes"):
		def.heroes = reader.req_string_array("heroes")
		if def.heroes.is_empty():
			reader.error("\"heroes\": name at least one, or leave it out (anyone)")
	var ranks: Array[DataReader] = reader.opt_object_array("ranks")
	if reader.has("ranks") and ranks.size() != 2:
		reader.error("ranks: ranks II and III")
	for i: int in ranks.size():
		var base: TacticDef = def if i == 0 else def._ranks[0]
		var ranked: TacticDef = DefCopy.shallow(base) as TacticDef
		ranked.rank = i + 2
		ranked._ranks = []
		_read_numbers(ranked, ranks[i], false)
		_read_payoff(ranked, ranks[i])
		ranks[i].finish()
		def._ranks.append(ranked)
	reader.finish()
	return def


## This tactic at `rank` (1 to 3): rank II's and III's numbers (each from the
## rank before it), or itself.
func at_rank(at: int) -> TacticDef:
	if at <= 1 or _ranks.is_empty():
		return self
	return _ranks[mini(at, _ranks.size() + 1) - 2]


## The kind's numbers (`required`: the base entry, where a kind's own number
## is needed; a rank changes what it names).
static func _read_numbers(def: TacticDef, reader: DataReader, required: bool) -> void:
	match def.kind:
		Kind.PREFER_TARGET:
			if reader.has("archetypes"):
				def.archetypes = reader.opt_choice_array("archetypes", EnemyDef.ARCHETYPE_NAMES)
			if reader.has("prefers"):
				def.prefers = UnitCondition.read(reader.req_object("prefers"))
			if reader.has("pick"):
				def.pick = reader.req_choice("pick", PICKS)
		Kind.HOLD_GROUND:
			if required or reader.has("release_hexes"):
				def.release_range = reader.req_int("release_hexes", 1, 10) * HexGrid.HEX
		Kind.SIGNATURE_THRESHOLD, Kind.SIGNATURE_FINISH:
			if required or reader.has("below_pct"):
				def.below_bp = reader.req_int("below_pct", 1, 99) * 100
		Kind.STOP_NEAR:
			if required or reader.has("stop_hexes"):
				def.stop_range = reader.req_int("stop_hexes", 1, 10) * HexGrid.HEX
		Kind.LEASH:
			if required or reader.has("leash_hexes"):
				def.leash_range = reader.req_int("leash_hexes", 1, 10) * HexGrid.HEX
		Kind.SIGNATURE_CROWD:
			if required or reader.has("crowd"):
				def.crowd = reader.req_int("crowd", 2, 10)
			if required or reader.has("max_wait_ms"):
				def.max_wait_ticks = reader.req_ticks("max_wait_ms", FixedMath.MS_PER_TICK)


## The payoff's keys and the twists, each optional.
static func _read_payoff(def: TacticDef, reader: DataReader) -> void:
	def.damage_vs_bp = reader.opt_int("damage_vs_bp", def.damage_vs_bp, 0, 20000)
	if reader.has("payoff_vs"):
		def.payoff_vs = UnitCondition.read(reader.req_object("payoff_vs"))
	def.crit_vs_bp = reader.opt_int("crit_vs_bp", def.crit_vs_bp, 0, FixedMath.BP_ONE)
	def.def_ignore_bp = reader.opt_int("def_ignore_bp", def.def_ignore_bp, 0, FixedMath.BP_ONE)
	def.atsp_bp = reader.opt_int("atsp_bp", def.atsp_bp, 0, 20000)
	def.atsp_add = reader.opt_int("atsp_add", def.atsp_add, 0, 200)
	def.def_add = reader.opt_int("def_add", def.def_add, 0, 200)
	def.def_bp = reader.opt_int("def_bp", def.def_bp, 0, 20000)
	def.atk_mgk_bp = reader.opt_int("atk_mgk_bp", def.atk_mgk_bp, 0, 20000)
	if reader.has("window_ms"):
		def.window_ticks = reader.req_ticks("window_ms", FixedMath.MS_PER_TICK)
	def.heal_bp = reader.opt_int("heal_bp", def.heal_bp, 0, 20000)
	def.power_bp = reader.opt_int("power_bp", def.power_bp, 0, 20000)
	def.regen_bp = reader.opt_int("regen_bp", def.regen_bp, 0, FixedMath.BP_ONE)
	def.keep_bp = reader.opt_int("keep_bp", def.keep_bp, 0, FixedMath.BP_ONE)
	if reader.has("first_hit"):
		var first: DataReader = reader.req_object("first_hit")
		if first != null:
			def.first_hit_status = first.req_string("status")
			def.first_hit_ticks = first.opt_ticks("duration_ms", 0)
			def.first_hit_stacks = first.opt_int("stacks", 1, 1, 50)
			first.finish()
	if reader.has("crit_extends_mark_ms"):
		def.crit_extends_mark_ticks = reader.req_ticks("crit_extends_mark_ms", FixedMath.MS_PER_TICK)
	def.kill_mana = reader.opt_int("kill_mana", def.kill_mana, 0, 100)
	def.restart_on_kill = reader.opt_bool("restart_on_kill", def.restart_on_kill)
	def.cleanse_one = reader.opt_bool("cleanse_one", def.cleanse_one)
	def.ally_def_add = reader.opt_int("ally_def_add", def.ally_def_add, 0, 200)
	def.crit_after_back = reader.opt_bool("crit_after_back", def.crit_after_back)
	def.per_extra_bp = reader.opt_int("per_extra_bp", def.per_extra_bp, 0, FixedMath.BP_ONE)
	def.refund_bp = reader.opt_int("refund_bp", def.refund_bp, 0, FixedMath.BP_ONE)


## Whether the hero with this kit id can take it (anyone, unless it names
## its heroes).
func allows(kit_id: String) -> bool:
	return heroes.is_empty() or heroes.has(kit_id)


## True if `enemy` is one it prefers: of its archetypes, or meeting its
## condition (a pick of its own prefers none: it picks one).
func prefers_unit(enemy: UnitState) -> bool:
	if not archetypes.is_empty():
		return archetypes.has(enemy.def.archetype)
	return prefers != null and prefers.holds(enemy)


## The stat payoffs Tactics adds to its kit as an aura while its order
## applies.
func has_stat_payoff() -> bool:
	return def_add != 0 or def_bp != 0 or atk_mgk_bp != 0 or atsp_add != 0
