class_name StatusDef
extends RefCounted
## A status effect from data/statuses.json. The kind decides how the sim runs
## it; the numbers come from data. Which fields a kind needs:
##   damage_over_time: interval_ms, damage_per_stack, stacks_lost_per_interval
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
var stacks_lost_per_interval: int
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
			def.stacks_lost_per_interval = reader.req_int("stacks_lost_per_interval", 0)
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
