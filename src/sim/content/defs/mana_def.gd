class_name ManaDef
extends RefCounted
## A unit's mana bar (docs/plans/rebuild-phase1-arena-sim.md, section 5). Only
## a unit whose signature fires on mana has one; the data gives whole mana:
##   "mana": {"max": 60, "start": 20, "per_attack": 12,
##            "per_10_damage_taken": 0, "regen_per_s": 2}
## Optional (phase 4): "far_hexes": 5, "per_far_attack": 20 (a basic attack
## at a target that far or farther gives that instead).
## max is the signature's cost: the bar fills to it, the signature fires,
## and the bar empties.

var max: int
var start: int = 0
var per_attack: int = 0
var per_10_damage_taken: int = 0
var regen_per_s: int = 0
## A basic attack at a target at least far_hexes away gives per_far_attack
## instead of per_attack (phase 4, Deadeye; 0: no such bonus).
var far_hexes: int = 0
var per_far_attack: int = 0
## The mana from damage taken, times this (phase 5c step 7b: an upgrade's
## mod, Grudge; the data never sets it).
var taken_bp: int = FixedMath.BP_ONE


static func read(reader: DataReader) -> ManaDef:
	var def := ManaDef.new()
	def.max = reader.req_int("max", 1)
	def.start = reader.opt_int("start", 0, 0, maxi(def.max, 0))
	def.per_attack = reader.opt_int("per_attack", 0, 0)
	def.per_10_damage_taken = reader.opt_int("per_10_damage_taken", 0, 0)
	def.regen_per_s = reader.opt_int("regen_per_s", 0, 0)
	if reader.has("far_hexes") or reader.has("per_far_attack"):
		def.far_hexes = reader.req_int("far_hexes", 2, 20)
		def.per_far_attack = reader.req_int("per_far_attack", 0)
	reader.finish()
	return def
