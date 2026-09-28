class_name StatusDef
extends RefCounted
## A status effect from data/statuses.json (docs/plans/rebuild-phase1-arena-sim.md,
## section 8). The kind decides how the sim runs it; the numbers come from
## data. Which fields a kind needs:
##   damage_over_time: interval_ms, damage_per_stack, and optionally
##                     stacks_lost_per_interval (flat), stacks_lost_bp (a share,
##                     rounded up), vs_shield_bp (how hard it hits shields:
##                     10000 normal, 5000 half, 0 = skips shields entirely),
##                     defense_shred_per_stack (lowers the target's DEF),
##                     cleanse_effectiveness_bp (how much heals strip it;
##                     10000 normal), max_stacks
##   root, stun, taunt, silence:   duration_ms
##   slow:     duration_ms, slow_bp (moves and attacks that much slower)
##   marked:   duration_ms, damage_taken_bp (takes that much more damage)
##   undying:  duration_ms (its HP can't drop below 1)
##   engaged:  nothing (held by an engager; only the Engage trait sets and
##             clears it, and effects can't apply it)
##   stealth:  duration_ms (no enemy can pick it as a target, and one
##             targeting it picks again; areas and shots already flying
##             still hit it, and it keeps attacking. Added at playtest
##             gate 1 for Maren's hop: a code change, since no other kind
##             can hide a unit)
## A timed status's duration_ms is its default; an apply_status effect can
## give its own. A new application refreshes the timer.

enum Kind { DAMAGE_OVER_TIME, ROOT, STUN, SLOW, TAUNT, SILENCE, MARKED, UNDYING, ENGAGED, STEALTH }

const KIND_NAMES: Array[String] = ["damage_over_time", "root", "stun", "slow", "taunt", "silence", "marked", "undying", "engaged", "stealth"]

var id: String
var name: String
var kind: Kind
## 0 means no cap.
var max_stacks: int
var interval_ticks: int
var damage_per_stack: int
var stacks_lost_per_interval: int = 0
## Share of stacks lost each interval, rounded up (so at least 1 if > 0).
var stacks_lost_bp: int = 0
## How effective this damage is against shields; 0 = goes straight to HP.
var vs_shield_bp: int = FixedMath.BP_ONE
## DEF removed from the target per stack.
var defense_shred_per_stack: int = 0
## How effective heals are at stripping this status.
var cleanse_effectiveness_bp: int = FixedMath.BP_ONE
## Timed kinds: how long it lasts unless the effect says otherwise.
var duration_ticks: int = 0
var slow_bp: int = 0
var damage_taken_bp: int = 0


static func read(reader: DataReader) -> StatusDef:
	var def := StatusDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	var kind_name: String = reader.req_choice("kind", KIND_NAMES)
	def.kind = maxi(KIND_NAMES.find(kind_name), 0) as Kind
	if kind_name.is_empty():
		reader.finish()
		return def
	if def.kind == Kind.DAMAGE_OVER_TIME:
		def.max_stacks = reader.opt_int("max_stacks", 0, 0)
		def.interval_ticks = reader.req_ticks("interval_ms", FixedMath.MS_PER_TICK)
		def.damage_per_stack = reader.req_int("damage_per_stack", 0)
		def.stacks_lost_per_interval = reader.opt_int("stacks_lost_per_interval", 0, 0)
		def.stacks_lost_bp = reader.opt_int("stacks_lost_bp", 0, 0, FixedMath.BP_ONE)
		def.vs_shield_bp = reader.opt_int("vs_shield_bp", FixedMath.BP_ONE, 0, FixedMath.BP_ONE)
		def.defense_shred_per_stack = reader.opt_int("defense_shred_per_stack", 0, 0)
		def.cleanse_effectiveness_bp = reader.opt_int("cleanse_effectiveness_bp", FixedMath.BP_ONE, 0, FixedMath.BP_ONE)
	elif def.kind == Kind.ENGAGED:
		pass
	else:
		def.duration_ticks = reader.req_ticks("duration_ms", FixedMath.MS_PER_TICK)
		match def.kind:
			Kind.SLOW:
				def.slow_bp = reader.req_int("slow_bp", 1, FixedMath.BP_ONE)
			Kind.MARKED:
				def.damage_taken_bp = reader.req_int("damage_taken_bp", 1)
	reader.finish()
	return def


func is_timed() -> bool:
	return kind != Kind.DAMAGE_OVER_TIME and kind != Kind.ENGAGED
