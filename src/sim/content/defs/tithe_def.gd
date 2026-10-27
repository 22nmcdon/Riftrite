class_name TitheDef
extends RefCounted
## Tithe (phase 8 part 5, docs/plans/phases/rebuild-phase8-severine-edric.md
## section 6; Edric's Tithe-Collector): shards the run pays after a won day
## fight, worked out from what the fight reports. The sim never reads it.
##   {"per_standing": 2}                    a path's stage, an apex's stage
##   {"elite_bp": 10000}, {"harder_add": 1} its cards (Elite Tithe, Bold Tithe)
## A hero's Tithe is its stage's (RunContent.tithe: its path's vowed or
## transformed one, plus its vowed apex's taste, or its earned apex's own)
## with its held cards' added on. Every field adds:
##   per_standing:   shards for each hero standing at the fight's end
##   fallen_pays:    shards for each hero down at the end (Insurance)
##   flawless_add:   more when no hero is down at the end
##   flawless_grows: each flawless fight since its apex was earned raises
##                   flawless_add by this much, up to flawless_max (Collector
##                   of Debts; its count is the apex's growth, RunState.Hero
##                   .growth "apex:<id>")
##   harder_add:     more after the harder of the day's fights
##   elite_bp:       an elite's Tithe, plus this share (10000: doubled)
##   per_step:       more for each step of its card's own growth (Ledger of
##                   Debts: +1 for every 10 fights won)
##   once_per_act:   more after the first won day fight in each act from
##                   when it's held (phase 8 part 6, Lucky Find, a hero card's;
##                   RunState.Hero.tithe_act; paid by RunFlow._tithes)

var per_standing: int = 0
var fallen_pays: int = 0
var flawless_add: int = 0
var flawless_grows: int = 0
var flawless_max: int = 0
var harder_add: int = 0
var elite_bp: int = 0
var per_step: int = 0
var once_per_act: int = 0

const FIELDS: Array[String] = ["per_standing", "fallen_pays", "flawless_add", "flawless_grows", "flawless_max", "harder_add", "elite_bp", "per_step", "once_per_act"]


static func read(reader: DataReader) -> TitheDef:
	var def := TitheDef.new()
	def.per_standing = reader.opt_int("per_standing", 0, 0, 20)
	def.fallen_pays = reader.opt_int("fallen_pays", 0, 0, 20)
	def.flawless_add = reader.opt_int("flawless_add", 0, 0, 50)
	def.flawless_grows = reader.opt_int("flawless_grows", 0, 0, 10)
	def.flawless_max = reader.opt_int("flawless_max", 0, 0, 100)
	def.harder_add = reader.opt_int("harder_add", 0, 0, 20)
	def.elite_bp = reader.opt_int("elite_bp", 0, 0, 5 * FixedMath.BP_ONE)
	def.per_step = reader.opt_int("per_step", 0, 0, 10)
	def.once_per_act = reader.opt_int("once_per_act", 0, 0, 50)
	if def.flawless_grows > 0 and def.flawless_max == 0:
		reader.error("flawless_grows needs a flawless_max")
	reader.finish()
	if not def.anything():
		reader.error("a Tithe pays something: give one of %s" % ", ".join(FIELDS))
	return def


## True if it pays nothing but once an act (a hero card may carry only
## that: Lucky Find).
func only_once_per_act() -> bool:
	var rest: TitheDef = merged(null)
	rest.once_per_act = 0
	return once_per_act > 0 and not rest.anything()


## True if it pays or changes anything.
func anything() -> bool:
	return per_standing > 0 or fallen_pays > 0 or flawless_add > 0 or flawless_grows > 0 or flawless_max > 0 or harder_add > 0 or elite_bp > 0 or per_step > 0 or once_per_act > 0


## This Tithe with `other`'s added on (a new one; null: a copy).
func merged(other: TitheDef) -> TitheDef:
	var sum := TitheDef.new()
	for field: String in FIELDS:
		sum.set(field, int(get(field)) + (int(other.get(field)) if other != null else 0))
	return sum


## What it pays after a won fight: `standing` heroes up and `fallen` down at
## the end, `tier` the fight's, `flawless_count` the flawless fights its apex
## has counted, `steps` its cards' growth steps (each card's per_step times
## its steps, summed by the caller into `step_shards`).
func pays(standing: int, fallen: int, tier: String, flawless_count: int, step_shards: int) -> int:
	var paid: int = per_standing * standing + fallen_pays * fallen + step_shards
	if fallen == 0:
		paid += flawless_add + mini(flawless_count * flawless_grows, flawless_max)
	if tier == "harder":
		paid += harder_add
	if tier == "elite" and elite_bp > 0:
		paid = FixedMath.apply_bp(paid, FixedMath.BP_ONE + elite_bp)
	return paid
