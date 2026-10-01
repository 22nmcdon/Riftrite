class_name ActDef
extends RefCounted
## An act's shape (data/act1.json; docs/plans/rebuild-phase5-run.md, sections
## 2 and 3): its days (normal, elite, or boss), the shards a won fight pays by
## its tier, the shards a run starts with, how many losses end it, and each
## hero's loadout slots, the after-fight pick's shards and wild cards, and
## the shops' prices and sizes. Phase 5c step 5a (economy.md, relics/):
## relics by tier, the shops' odds for each tier, the rerolls' climb, the
## Magpie's discount, the elite's chance of an epic, the boss relics offered,
## and the Shrine's price. Phase 5c step 6: the loadout's prices and ranks.

const DAY_KINDS: Array[String] = ["normal", "elite", "boss"]

var act: int
## One per day: "normal", "elite", or "boss".
var days: Array[String] = []
## Tier -> shards for a win or a tie.
var pay: Dictionary[String, int] = {}
var start_shards: int = 0
var losses_to_end: int = 2
## Loadout slots per hero (a relic may add one).
var slots: int = 3
## What "Take shards instead" pays on a pick.
var pick_shards: int = 3
## The chance (percent) that a pick has a wild card: one card for any hero.
var wild_card_pct: int = 0
## Shards to treat one wound, and a shop's first reroll (each after it costs
## 1 more); the boss shop's first reroll.
var wound_price: int = 4
var reroll_price: int = 1
var boss_reroll_price: int = 5
## Relic tier name -> its price (RelicDef.TIER_NAMES; boss relics are free).
var relic_prices: Dictionary[String, int] = {}
## The Magpie's relics, as a share of their price (75: 25% off, rounded down).
var magpie_relic_pct: int = 75
## The Pedlar's relic and the Magpie's: tier names and their weights, in
## order.
var relic_odds: Array[String] = []
var relic_weights: Array[int] = []
var magpie_odds: Array[String] = []
var magpie_weights: Array[int] = []
## The chance (percent) that one of an elite's 2 relics is an epic.
var elite_epic_pct: int = 0
## The chance a shop's relic draw is an on bond's relic (phase 5c step 5d,
## Decision 27).
var bond_relic_pct: int = 0
## How many boss relics a won boss fight offers.
var boss_relics: int = 3
## The Shrine's rare relic.
var shrine_price: int = 15
## How many wares the Pedlar lays out, and how many charms the Magpie does
## (at rank II, for magpie_charm_price each; phase 5c step 6e, magpie.md).
var pedlar_wares: int = 4
var magpie_wares: int = 2
var magpie_charm_price: int = 12
## What the Magpie pays for a relic, by tier (RelicDef.TIER_NAMES; a bond
## relic: nothing).
var relic_sell: Dictionary[String, int] = {}
## The loadout pool (phase 5c step 6, docs/plans/loadout/): an item's price
## by its kind (ItemDef.KIND_NAMES), and what ranks it up: for each kind,
## how much it must count to reach rank II, then how much more for rank III
## (the count starts again at each rank). Tactics count ms its hero stands
## in a fight with it (Decision 32), gambits fights, sigils casts of the
## signature, charms won fights; all only while it's equipped.
var item_prices: Dictionary[String, int] = {}
var item_ranks: Dictionary[String, Array] = {}


static func read(reader: DataReader) -> ActDef:
	var def := ActDef.new()
	def.act = reader.req_int("act", 1)
	def.start_shards = reader.req_int("start_shards", 0)
	def.losses_to_end = reader.req_int("losses_to_end", 1)
	def.slots = reader.req_int("slots", 0, 6)
	def.pick_shards = reader.req_int("pick_shards", 0)
	def.wild_card_pct = reader.req_int("wild_card_pct", 0, 100)
	var prices: DataReader = reader.req_object("prices")
	if prices != null:
		def.wound_price = prices.req_int("wound", 0)
		def.reroll_price = prices.req_int("reroll", 0)
		def.boss_reroll_price = prices.req_int("boss_reroll", 0)
		def.shrine_price = prices.req_int("shrine", 0)
		def.magpie_relic_pct = prices.req_int("magpie_relic_pct", 1, 100)
		var relics: DataReader = prices.req_object("relics")
		if relics != null:
			for tier: String in RelicDef.TIER_NAMES.slice(0, RelicDef.Tier.BOSS):
				def.relic_prices[tier] = relics.req_int(tier, 0)
			def.relic_prices["boss"] = 0
			def.relic_prices["bond"] = 0
			relics.finish()
		prices.finish()
	_read_odds(reader, "relic_odds", def.relic_odds, def.relic_weights)
	_read_odds(reader, "magpie_odds", def.magpie_odds, def.magpie_weights)
	def.elite_epic_pct = reader.req_int("elite_epic_pct", 0, 100)
	def.bond_relic_pct = reader.req_int("bond_relic_pct", 0, 100)
	def.boss_relics = reader.req_int("boss_relics", 0, 5)
	def.pedlar_wares = reader.req_int("pedlar_wares", 1, 8)
	def.magpie_wares = reader.req_int("magpie_wares", 1, 8)
	def.magpie_charm_price = reader.req_int("magpie_charm_price", 0)
	var sell: DataReader = reader.req_object("relic_sell")
	if sell != null:
		for tier: String in RelicDef.TIER_NAMES:
			if tier != "bond":
				def.relic_sell[tier] = sell.req_int(tier, 0)
		def.relic_sell["bond"] = 0
		sell.finish()
	var items: DataReader = reader.req_object("items")
	if items != null:
		var item_prices: DataReader = items.req_object("prices")
		var item_ranks: DataReader = items.req_object("ranks")
		for kind: String in ItemDef.KIND_NAMES:
			if item_prices != null:
				def.item_prices[kind] = item_prices.req_int(kind, 0)
			if item_ranks != null:
				var needs: Array[int] = item_ranks.req_int_array(kind)
				if needs.any(func(need: int) -> bool: return need < 1):
					item_ranks.error("%s: each count is at least 1" % kind)
				if needs.size() != ItemDef.RANKS - 1:
					item_ranks.error("%s: what reaches rank II and rank III" % kind)
				def.item_ranks[kind] = needs
		if item_prices != null:
			item_prices.finish()
		if item_ranks != null:
			item_ranks.finish()
		items.finish()
	var pay_reader: DataReader = reader.req_object("pay")
	if pay_reader != null:
		for tier: String in EncounterDef.TIERS:
			def.pay[tier] = pay_reader.req_int(tier, 0)
		pay_reader.finish()
	for day: String in reader.req_string_array("days"):
		if not DAY_KINDS.has(day):
			reader.error("days: \"%s\" isn't normal, elite, or boss" % day)
		def.days.append(day)
	if def.days.is_empty():
		reader.error("an act needs days")
	elif def.days.back() != "boss":
		reader.error("an act's last day is its boss")
	reader.finish()
	return def


## Tier name -> weight, in RelicDef's tier order (never boss).
static func _read_odds(reader: DataReader, key: String, tiers: Array[String], weights: Array[int]) -> void:
	var odds: DataReader = reader.req_object(key)
	if odds == null:
		return
	for tier: String in RelicDef.TIER_NAMES.slice(0, RelicDef.Tier.BOSS):
		var weight: int = odds.opt_int(tier, 0, 0, 1000)
		if weight > 0:
			tiers.append(tier)
			weights.append(weight)
	odds.finish()
	if tiers.is_empty():
		reader.error("%s needs a tier with a weight" % key)
