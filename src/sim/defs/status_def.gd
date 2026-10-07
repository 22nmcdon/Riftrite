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
##   warded:   duration_ms, damage_reduced_bp (takes that much less damage;
##             phase 4, Warding Circle: a code change, since a Mark only
##             ever adds)
##   undying:  duration_ms (its HP can't drop below 1)
##   engaged:  nothing (held by an engager; only the Engage trait sets and
##             clears it, and effects can't apply it)
##   stealth:  duration_ms (no enemy can pick it as a target, and one
##             targeting it picks again; areas and shots already flying
##             still hit it, and it keeps attacking. Added at playtest
##             gate 1 for Maren's hop: a code change, since no other kind
##             can hide a unit)
##   boost:    duration_ms, "auras": [{"stat": "atsp", "value": 30}] (AuraDef
##             stats; counted like auras while it lasts; phase 5c step 5b,
##             timed boosts). "stacking": true (step 5c): each application
##             adds a stack with its own timer (no duration_ms: it lasts the
##             fight), the auras count once per stack, and "max_stacks"
##             (optional) drops the oldest past it
##             "signature_power_bp": 3000 (phase 8 part 4, Grand Chorus):
##             its holder's next signature has that much more power, and it
##             ends as that signature fires ("auras" optional then)
##             "until_attack": true (phase 5c step 6b; Shadow Step): it
##             ends as its holder next attacks (that attack still has it)
##   stealth:  duration_ms; phase 8 part 4 (Tamsin): "until_attack": true
##             ends it as its holder's next basic attack fires (that attack
##             is still from Stealth), and "spares_attacks": N lets that
##             many basic attacks pass first (Shadow Dance)
##   grounded: duration_ms (a flier can't fly while it lasts: it walks, and
##             rocks and walls stop it; set down on the nearest free safe
##             spot if it's over something; phase 5c step 6b, Fletched for
##             Wings: a code change, since no other kind takes flight away)
## Any kind may carry a "keyword" (Keywords.NAMES; phase 5c step 3): the
## name cards use for a unit with this status (Marked, Rooted, Burning,
## Stealthed). It changes nothing in a fight by itself.
## A timed status's duration_ms is its default; an apply_status effect can
## give its own. A new application refreshes the timer.

enum Kind { DAMAGE_OVER_TIME, ROOT, STUN, SLOW, TAUNT, SILENCE, MARKED, UNDYING, ENGAGED, STEALTH, WARDED, BOOST, GROUNDED }

const KIND_NAMES: Array[String] = ["damage_over_time", "root", "stun", "slow", "taunt", "silence", "marked", "undying", "engaged", "stealth", "warded", "boost", "grounded"]

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
var damage_reduced_bp: int = 0
## boost: the aura stats it changes, and by how much (AuraDef values).
var boost_stats: Array[int] = []
var boost_values: Array[int] = []
## The keyword a unit with it has ("": none).
var keyword: String = ""
## boost: each application adds a stack with its own timer (phase 5c step 5c).
var stacking: bool = false
## boost: it ends as its holder next attacks (phase 5c step 6b).
var until_attack: bool = false
## boost: its holder's next signature's power, spent as it fires (phase 8
## part 4, Grand Chorus; 0: none).
var signature_power_bp: int = 0
## stealth with until_attack: the basic attacks it lets pass first (phase 8
## part 4, Shadow Dance).
var spares_attacks: int = 0


static func read(reader: DataReader) -> StatusDef:
	var def := StatusDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	var kind_name: String = reader.req_choice("kind", KIND_NAMES)
	def.kind = maxi(KIND_NAMES.find(kind_name), 0) as Kind
	def.keyword = reader.opt_string_choice("keyword", "", Keywords.NAMES)
	if def.keyword == Keywords.SHIELDED:
		reader.error("Shielded is a Shield above 0, not a status")
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
		if def.kind == Kind.BOOST:
			def.stacking = reader.opt_bool("stacking", false)
			def.until_attack = reader.opt_bool("until_attack", false)
			def.signature_power_bp = reader.opt_int("signature_power_bp", 0, 0, 50000)
		elif def.kind == Kind.STEALTH:
			def.until_attack = reader.opt_bool("until_attack", false)
			if def.until_attack:
				def.spares_attacks = reader.opt_int("spares_attacks", 0, 0, 10)
		if def.stacking:
			def.duration_ticks = reader.opt_ticks("duration_ms", 0, FixedMath.MS_PER_TICK)
			def.max_stacks = reader.opt_int("max_stacks", 0, 0)
		else:
			def.duration_ticks = reader.req_ticks("duration_ms", FixedMath.MS_PER_TICK)
		match def.kind:
			Kind.SLOW:
				def.slow_bp = reader.req_int("slow_bp", 1, FixedMath.BP_ONE)
			Kind.MARKED:
				def.damage_taken_bp = reader.req_int("damage_taken_bp", 1)
			Kind.WARDED:
				def.damage_reduced_bp = reader.req_int("damage_reduced_bp", 1, FixedMath.BP_ONE)
			Kind.BOOST:
				for aura: DataReader in reader.opt_object_array("auras"):
					var stat: int = AuraDef.STAT_NAMES.find(aura.req_choice("stat", AuraDef.STAT_NAMES))
					def.boost_stats.append(maxi(stat, 0))
					def.boost_values.append(aura.req_int("value", -50000, 50000))
					aura.finish()
				if def.boost_stats.is_empty() and def.signature_power_bp == 0:
					reader.error("a boost needs auras (or signature_power_bp)")
	reader.finish()
	return def


func is_timed() -> bool:
	return kind != Kind.DAMAGE_OVER_TIME and kind != Kind.ENGAGED
