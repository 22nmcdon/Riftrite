class_name ShopRulesDef
extends RefCounted
## Shop rules (phase 8 part 6, docs/plans/rebuild-phase8-last-heroes.md
## section 8; Hob's Fence and Hoarder): how the Pedlar and the boss shop
## price things for the team (Decision 6: the Magpie keeps his own). The sim
## never reads it.
##   {"free_rerolls": 1}       the first rerolls in each shop are free
##                             (Haggle)
##   {"cheap_rerolls": 1}      the next ones cost 1 shard (Second Haggle)
##   {"reroll_less_bp": 5000}  rerolls cost that share less, rounded down
##                             (transformed Fence: half)
##   {"reroll_add": 1}         rerolls cost that many shards more (Hoarder's
##                             cost)
##   {"sell_less_bp": 2500}    items sell for that share of their price less
##                             (Fence's cost: a quarter, not half)
##   {"item_less": 1}          loadout items cost that many shards less
##                             (Wholesale)
##   {"first_relic_less": 2}   the first relic bought in each shop costs that
##                             many less (Black Market's taste)
##   {"black_market": 1}       each shop also shows a relic one tier higher,
##                             at its own tier's price (Black Market)
##   {"rank_ii_charms": 1}     that many of each shop's charms come at rank II
##                             (Insider)
##   {"relic_less_per_bought": 1}  relics cost that much less for each relic
##                             bought since Black Market was earned, down to
##                             half their price (Black Market; Volume Discount)
##   {"black_market_rerolls": 1}  the black-market slot rerolls free that many
##                             times a shop (Smuggler's Route)
## A hero's is its stage's (RunContent.shop_rules: its path's vowed or
## transformed one, plus its vowed apex's taste, or its earned apex's own)
## with its held cards' added on; the team's is its heroes' added together.
## Every field adds.

var free_rerolls: int = 0
var cheap_rerolls: int = 0
var reroll_less_bp: int = 0
var reroll_add: int = 0
var sell_less_bp: int = 0
var item_less: int = 0
var first_relic_less: int = 0
var black_market: int = 0
var rank_ii_charms: int = 0
var relic_less_per_bought: int = 0
var black_market_rerolls: int = 0

const FIELDS: Array[String] = ["free_rerolls", "cheap_rerolls", "reroll_less_bp", "reroll_add", "sell_less_bp", "item_less", "first_relic_less", "black_market", "rank_ii_charms",
	"relic_less_per_bought", "black_market_rerolls"]


static func read(reader: DataReader) -> ShopRulesDef:
	var def := ShopRulesDef.new()
	def.free_rerolls = reader.opt_int("free_rerolls", 0, 0, 10)
	def.cheap_rerolls = reader.opt_int("cheap_rerolls", 0, 0, 10)
	def.reroll_less_bp = reader.opt_int("reroll_less_bp", 0, 0, FixedMath.BP_ONE)
	def.reroll_add = reader.opt_int("reroll_add", 0, 0, 10)
	def.sell_less_bp = reader.opt_int("sell_less_bp", 0, 0, 5000)
	def.item_less = reader.opt_int("item_less", 0, 0, 20)
	def.first_relic_less = reader.opt_int("first_relic_less", 0, 0, 30)
	def.black_market = reader.opt_int("black_market", 0, 0, 1)
	def.rank_ii_charms = reader.opt_int("rank_ii_charms", 0, 0, 5)
	def.relic_less_per_bought = reader.opt_int("relic_less_per_bought", 0, 0, 10)
	def.black_market_rerolls = reader.opt_int("black_market_rerolls", 0, 0, 5)
	reader.finish()
	if not def.anything():
		reader.error("shop rules change something: give one of %s" % ", ".join(FIELDS))
	return def


## Reads a "shop" key if there (null: none).
static func read_in(reader: DataReader) -> ShopRulesDef:
	if not reader.has("shop"):
		return null
	var sub: DataReader = reader.req_object("shop")
	return read(sub) if sub != null else null


func anything() -> bool:
	for field: String in FIELDS:
		if int(get(field)) != 0:
			return true
	return false


## This one with `other`'s added on (a new one; null: a copy).
func merged(other: ShopRulesDef) -> ShopRulesDef:
	var sum := ShopRulesDef.new()
	for field: String in FIELDS:
		sum.set(field, int(get(field)) + (int(other.get(field)) if other != null else 0))
	return sum


## What the shop's reroll number `index` (0: its first) costs at `price`
## under these rules.
func reroll_price(index: int, price: int) -> int:
	if index < free_rerolls:
		return 0
	if index < free_rerolls + cheap_rerolls:
		return mini(price, 1)
	# What's left of it, rounded down (half of 3 is 1).
	@warning_ignore("integer_division")
	return price * (FixedMath.BP_ONE - mini(reroll_less_bp, FixedMath.BP_ONE)) / FixedMath.BP_ONE + reroll_add
