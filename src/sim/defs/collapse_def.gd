class_name CollapseDef
extends RefCounted
## Rift Collapse numbers for one act (see "The arena" in docs/design.md).
## Damage per second starts at `base`, grows by `growth` each second, and from
## the surge time onward the growth itself goes up by `accel` each second.

var act: int
var base: int
var growth: int
var accel: int


static func read(reader: DataReader, act_number: int) -> CollapseDef:
	var def := CollapseDef.new()
	def.act = act_number
	def.base = reader.req_int("base", 0)
	def.growth = reader.req_int("growth", 0)
	def.accel = reader.req_int("accel", 0)
	reader.finish()
	return def
