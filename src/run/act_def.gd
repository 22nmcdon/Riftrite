class_name ActDef
extends RefCounted
## An act's shape (data/act1.json; docs/plans/rebuild-phase5-run.md, sections
## 2 and 3): its days (normal, elite, or boss), the shards a won fight pays by
## its tier, the shards a run starts with, how many losses end it, and each
## hero's loadout slots, the after-fight pick's shards and wild cards, and
## the shops' prices and sizes.

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
## Shards to treat one wound, and to reroll the Pedlar's wares.
var wound_price: int = 2
var reroll_price: int = 1
## How many wares the Pedlar and the Magpie lay out; the Magpie's prices
## are the items' times magpie_markup_pct (rounded up).
var pedlar_wares: int = 4
var magpie_wares: int = 4
var magpie_markup_pct: int = 150


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
		prices.finish()
	def.pedlar_wares = reader.req_int("pedlar_wares", 1, 8)
	def.magpie_wares = reader.req_int("magpie_wares", 1, 8)
	def.magpie_markup_pct = reader.req_int("magpie_markup_pct", 100, 400)
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
