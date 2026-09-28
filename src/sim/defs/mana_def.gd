class_name ManaDef
extends RefCounted
## A unit's mana bar (docs/plans/rebuild-phase1-arena-sim.md, section 5). Only
## a unit whose signature fires on mana has one; the data gives whole mana:
##   "mana": {"max": 60, "start": 20, "per_attack": 12,
##            "per_10_damage_taken": 0, "regen_per_s": 2}
## max is the signature's cost: the bar fills to it, the signature fires,
## and the bar empties.

var max: int
var start: int = 0
var per_attack: int = 0
var per_10_damage_taken: int = 0
var regen_per_s: int = 0


static func read(reader: DataReader) -> ManaDef:
	var def := ManaDef.new()
	def.max = reader.req_int("max", 1)
	def.start = reader.opt_int("start", 0, 0, maxi(def.max, 0))
	def.per_attack = reader.opt_int("per_attack", 0, 0)
	def.per_10_damage_taken = reader.opt_int("per_10_damage_taken", 0, 0)
	def.regen_per_s = reader.opt_int("regen_per_s", 0, 0)
	reader.finish()
	return def
