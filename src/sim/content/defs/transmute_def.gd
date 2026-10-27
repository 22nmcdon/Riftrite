class_name TransmuteDef
extends RefCounted
## Transmuting (phase 8 part 6, docs/plans/phases/rebuild-phase8-last-heroes.md
## section 5; Ottilie's Transmuter): turning an item the run owns into shards
## at the Pedlar or the boss shop (Decision 6), at its full price where
## selling pays half. The sim never reads it.
##   {"per_shop": 1}                      a path's stage (transformed
##                                        Transmuter): items a shop
##   {"pay_bp": 2500}                     more of the price (a card: 125%)
##   {"rank_ii_add": 2, "rank_iii_add": 4}  more for an item at rank II or
##                                        III (Appraise)
##   {"into_per_act": 1}                  items it may turn into a random
##                                        item of the same kind, an act
##                                        (Grand Transmutation's taste)
##   {"into_shop": 1, "into_rank": 2}     its items a shop may also be turned
##                                        into items, arriving at that rank
##                                        (Grand Transmutation)
## A hero's is its stage's (RunContent.transmute: its path's vowed or
## transformed one, plus its vowed apex's taste, or its earned apex's own)
## with its held cards' added on. Every field adds.

var per_shop: int = 0
var pay_bp: int = 0
var rank_ii_add: int = 0
var rank_iii_add: int = 0
var into_per_act: int = 0
## 1: a shop's transmutes may turn items into items too (an int, so it adds).
var into_shop: int = 0
## The rank an item transmuted into arrives at (0: rank I).
var into_rank: int = 0

const FIELDS: Array[String] = ["per_shop", "pay_bp", "rank_ii_add", "rank_iii_add", "into_per_act", "into_shop", "into_rank"]


static func read(reader: DataReader) -> TransmuteDef:
	var def := TransmuteDef.new()
	def.per_shop = reader.opt_int("per_shop", 0, 0, 10)
	def.pay_bp = reader.opt_int("pay_bp", 0, 0, 5 * FixedMath.BP_ONE)
	def.rank_ii_add = reader.opt_int("rank_ii_add", 0, 0, 50)
	def.rank_iii_add = reader.opt_int("rank_iii_add", 0, 0, 50)
	def.into_per_act = reader.opt_int("into_per_act", 0, 0, 10)
	def.into_shop = reader.opt_int("into_shop", 0, 0, 1)
	def.into_rank = reader.opt_int("into_rank", 0, 0, ItemDef.RANKS)
	reader.finish()
	if not def.anything():
		reader.error("transmuting changes something: give one of %s" % ", ".join(FIELDS))
	return def


## Reads a "transmute" key if there (null: none).
static func read_in(reader: DataReader) -> TransmuteDef:
	if not reader.has("transmute"):
		return null
	var sub: DataReader = reader.req_object("transmute")
	return read(sub) if sub != null else null


func anything() -> bool:
	return per_shop > 0 or pay_bp > 0 or rank_ii_add > 0 or rank_iii_add > 0 or into_per_act > 0 or into_shop > 0 or into_rank > 0


## This one with `other`'s added on (a new one; null: a copy).
func merged(other: TransmuteDef) -> TransmuteDef:
	var sum := TransmuteDef.new()
	for field: String in FIELDS:
		sum.set(field, int(get(field)) + (int(other.get(field)) if other != null else 0))
	return sum


## What turning an item worth `price` at `rank` pays.
func pays(price: int, rank: int) -> int:
	var paid: int = FixedMath.apply_bp(price, FixedMath.BP_ONE + pay_bp)
	if rank == 2:
		paid += rank_ii_add
	elif rank >= 3:
		paid += rank_iii_add
	return paid
