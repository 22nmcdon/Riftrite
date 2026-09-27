class_name EconomyDef
extends RefCounted
## Prices, rewards, and odds for runs, from data/economy.json. Every number
## here is a placeholder to tune with the run bot (tools/run_runner.gd).
## Weights are relative (they don't need to add up to anything).


var base_gold: int
var package_gold: int
## Item buy prices at tier C, by rarity (ItemDef.RARITIES order); each tier
## above C multiplies by tier_price_bp (see item_price_for).
var item_price: Array[int] = []
## By tier, C..S.
var tier_price_bp: Array[int] = []
## An essence merchant's essence.
var essence_price: int
## By rarity, in ItemDef.RARITIES order.
var relic_price: Array[int] = []
var sell_bp: int
var reroll_base: int
var reroll_step: int
## Items a shop offers (unless the shop says otherwise).
var shop_items: int
var win_gold_base: int
var win_gold_per_day: int
var elite_gold_bp: int
var boss_gold: int
var loss_gold_base: int
var loss_gold_per_win: int
var elite_key_chance_bp: int
var relic_choices: int
## The harder of the day's two fights: its gold, times this.
var hard_gold_bp: int
## The reward pick: pool items next to the enemy drop, and their rarity odds
## (after a harder fight, the hard odds).
var reward_pool_items: int
var reward_rarity_weights: Array[int] = []
var hard_reward_rarity_weights: Array[int] = []
## Item rarity weights for shops and Loot (by
## ItemDef.RARITIES). Legendary must be 0: those never come from there.
var rarity_weights: Array[int] = []
## Item rarity weights for the Vault's items and the item-by-rarity event:
## where Legendaries can turn up (docs/plans/legendary-items.md).
var vault_rarity_weights: Array[int] = []
var event_rarity_weights: Array[int] = []
## Tier weights for Loot and the item-by-tier event (C..S).
var loot_tier_weights: Array[int] = []
## Relic rarity weights: after elites, after the boss, and elsewhere.
var elite_relic_weights: Array[int] = []
var boss_relic_weights: Array[int] = []
var relic_weights: Array[int] = []
## Stop visits a day, and how many different nodes each visit offers (one
## of them a shop; weights are in data/nodes.json and data/events.json).
var stops_per_day: int
var node_choices: int
## How much gold a gold loot gives.
var loot_gold: int
## Start kits (docs/plans/fight-questions-and-readability.md, section 3): an
## item that comes infused, one kit per keyword. The start offers
## `kit_offers` of them, matching the drafted heroes' affinities.
var kits: Array[Kit] = []
var kit_offers: int


## A start kit: `item` at tier C, already infused with `essence`.
class Kit:
	var keyword: String
	var name: String
	var item: String
	var essence: String


static func read(reader: DataReader) -> EconomyDef:
	var def := EconomyDef.new()
	def.base_gold = reader.req_int("base_gold", 0)
	def.package_gold = reader.req_int("package_gold", 0)
	def.item_price = _table(reader, "item_price", ItemDef.RARITIES, 0)
	def.tier_price_bp = _table(reader, "tier_price_bp", TuningDef.TIER_NAMES, 0)
	def.essence_price = reader.req_int("essence_price", 0)
	def.relic_price = _table(reader, "relic_price", ItemDef.RARITIES, 0)
	def.sell_bp = reader.req_int("sell_bp", 0, FixedMath.BP_ONE)
	def.reroll_base = reader.req_int("reroll_base", 0)
	def.reroll_step = reader.req_int("reroll_step", 0)
	def.shop_items = reader.req_int("shop_items", 1)
	def.win_gold_base = reader.req_int("win_gold_base", 0)
	def.win_gold_per_day = reader.req_int("win_gold_per_day", 0)
	def.elite_gold_bp = reader.req_int("elite_gold_bp", 0)
	def.boss_gold = reader.req_int("boss_gold", 0)
	def.loss_gold_base = reader.req_int("loss_gold_base", 0)
	def.loss_gold_per_win = reader.req_int("loss_gold_per_win", 0)
	def.elite_key_chance_bp = reader.req_int("elite_key_chance_bp", 0, FixedMath.BP_ONE)
	def.relic_choices = reader.req_int("relic_choices", 1)
	def.hard_gold_bp = reader.req_int("hard_gold_bp", 0)
	def.reward_pool_items = reader.req_int("reward_pool_items", 0)
	def.reward_rarity_weights = _table(reader, "reward_rarity_weights", ItemDef.RARITIES, 0)
	def.hard_reward_rarity_weights = _table(reader, "hard_reward_rarity_weights", ItemDef.RARITIES, 0)
	for key: String in ["reward_rarity_weights", "hard_reward_rarity_weights"]:
		var weights: Array[int] = def.reward_rarity_weights if key == "reward_rarity_weights" else def.hard_reward_rarity_weights
		if weights.size() == ItemDef.RARITIES.size() and weights[ItemDef.RARITIES.find("legendary")] != 0:
			reader.error("%s: legendary must be 0 (rewards never offer Legendaries)" % key)
	def.rarity_weights = _table(reader, "rarity_weights", ItemDef.RARITIES, 0)
	if def.rarity_weights.size() == ItemDef.RARITIES.size() and def.rarity_weights[ItemDef.RARITIES.find("legendary")] != 0:
		reader.error("rarity_weights: legendary must be 0 (shops and Loot never offer Legendaries)")
	def.vault_rarity_weights = _table(reader, "vault_rarity_weights", ItemDef.RARITIES, 0)
	def.event_rarity_weights = _table(reader, "event_rarity_weights", ItemDef.RARITIES, 0)
	def.loot_tier_weights = _table(reader, "loot_tier_weights", TuningDef.TIER_NAMES, 0)
	def.elite_relic_weights = _table(reader, "elite_relic_weights", ItemDef.RARITIES, 0)
	def.boss_relic_weights = _table(reader, "boss_relic_weights", ItemDef.RARITIES, 0)
	def.relic_weights = _table(reader, "relic_weights", ItemDef.RARITIES, 0)
	def.stops_per_day = reader.req_int("stops_per_day", 1)
	def.node_choices = reader.req_int("node_choices", 2)
	def.loot_gold = reader.req_int("loot_gold", 0)
	def.kit_offers = reader.req_int("kit_offers", 1)
	for kit_reader: DataReader in reader.opt_object_array("kits"):
		var kit := Kit.new()
		kit.keyword = kit_reader.req_string("keyword")
		kit.name = kit_reader.req_string("name")
		kit.item = kit_reader.req_string("item")
		kit.essence = kit_reader.req_string("essence")
		kit_reader.finish()
		for other: Kit in def.kits:
			if other.keyword == kit.keyword:
				reader.error("kits: two kits for \"%s\"" % kit.keyword)
		def.kits.append(kit)
	reader.finish()
	return def


## Reads {"c": .., "b": ..} (or any fixed key list) into an array in `keys` order.
static func _table(reader: DataReader, key: String, keys: Array[String], min_value: int) -> Array[int]:
	var table: Array[int] = []
	var sub: DataReader = reader.req_object(key)
	for name: String in keys:
		table.append(sub.req_int(name, min_value) if sub != null else 0)
	if sub != null:
		sub.finish()
	return table


## The kit for a keyword, or null.
func kit_for(keyword: String) -> Kit:
	for kit: Kit in kits:
		if kit.keyword == keyword:
			return kit
	return null


## An item's buy price: its rarity's price, times its tier's multiplier.
func item_price_for(rarity: String, tier: int) -> int:
	return FixedMath.apply_bp(item_price[ItemDef.RARITIES.find(rarity)], tier_price_bp[tier])


## What an item sells for: a share of its buy price, rounded down.
func sell_price(buy_price: int) -> int:
	@warning_ignore("integer_division")
	return buy_price * sell_bp / FixedMath.BP_ONE
