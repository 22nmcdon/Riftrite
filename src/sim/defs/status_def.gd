class_name StatusDef
extends RefCounted
## A status effect from data/statuses.json. The kind decides how the sim runs
## it; the numbers come from data. Which fields a kind needs:
##   damage_over_time: interval_ms, damage_per_stack, and optionally
##                     stacks_lost_per_interval (flat), stacks_lost_bp (a share,
##                     rounded up), vs_shield_bp (how hard it hits shields:
##                     10000 normal, 5000 half, 0 = skips shields entirely),
##                     defense_shred_per_stack (lowers the target's DEF)
##   slow:             slow_bp_per_stack, duration_ms, optional "threshold"
##   freeze:           duration_ms
##   blind:            (none; each stack makes one attack miss)
## A threshold turns stacks into another status: at `stacks` stacks, apply
## `apply_stacks` of `apply_status` and (if `consume`) clear this status.

enum Kind { DAMAGE_OVER_TIME, SLOW, FREEZE, BLIND }

const KIND_NAMES: Array[String] = ["damage_over_time", "slow", "freeze", "blind"]

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
var slow_bp_per_stack: int
## 0 means the status has no timer.
var duration_ticks: int
var has_threshold: bool = false
var threshold_stacks: int
var threshold_status_id: String
var threshold_apply_stacks: int
var threshold_consume: bool


static func read(reader: DataReader) -> StatusDef:
	var def := StatusDef.new()
	def.id = reader.req_string("id")
	def.name = reader.req_string("name")
	var kind_name: String = reader.req_choice("kind", KIND_NAMES)
	def.kind = maxi(KIND_NAMES.find(kind_name), 0) as Kind
	def.max_stacks = reader.opt_int("max_stacks", 0, 0)

	match def.kind:
		Kind.DAMAGE_OVER_TIME:
			def.interval_ticks = reader.req_ticks("interval_ms", FixedMath.MS_PER_TICK)
			def.damage_per_stack = reader.req_int("damage_per_stack", 0)
			def.stacks_lost_per_interval = reader.opt_int("stacks_lost_per_interval", 0, 0)
			def.stacks_lost_bp = reader.opt_int("stacks_lost_bp", 0, 0, FixedMath.BP_ONE)
			def.vs_shield_bp = reader.opt_int("vs_shield_bp", FixedMath.BP_ONE, 0, FixedMath.BP_ONE)
			def.defense_shred_per_stack = reader.opt_int("defense_shred_per_stack", 0, 0)
		Kind.SLOW:
			def.slow_bp_per_stack = reader.req_int("slow_bp_per_stack", 0, FixedMath.BP_ONE)
			def.duration_ticks = reader.req_ticks("duration_ms", FixedMath.MS_PER_TICK)
			if reader.has("threshold"):
				_read_threshold(def, reader.req_object("threshold"))
		Kind.FREEZE:
			def.duration_ticks = reader.req_ticks("duration_ms", FixedMath.MS_PER_TICK)
		Kind.BLIND:
			pass
	reader.finish()
	return def


static func _read_threshold(def: StatusDef, reader: DataReader) -> void:
	if reader == null:
		return
	def.has_threshold = true
	def.threshold_stacks = reader.req_int("stacks", 1)
	def.threshold_status_id = reader.req_string("apply_status")
	def.threshold_apply_stacks = reader.opt_int("apply_stacks", 1, 1)
	def.threshold_consume = reader.opt_bool("consume", true)
	reader.finish()
