class_name EconomyDef
extends RefCounted
## Prices, rewards, and odds for runs, from data/economy.json. Every number
## here is a placeholder to tune with the run bot (tools/run_runner.gd).
## Weights are relative (they don't need to add up to anything).

## Stops the day's stop choice draws from (the Upgrade stop isn't drawn: it's
## always the stop before the boss).
const STOPS: Array[String] = ["forge", "loot", "vault", "retrain", "event"]
const LOOT_KINDS: Array[String] = ["item", "essence", "gold"]

var base_gold: int
var package_gold: int
## Buy prices by tier (items) and rank (heroes), C..S.
var item_price: Array[int] = []
var hero_price: Array[int] = []
## By rarity, in ItemDef.RARITIES order.
var relic_price: Array[int] = []
var sell_bp: int
var reroll_base: int
var reroll_step: int
var caravan_items: int
var caravan_heroes: int
var win_gold_base: int
var win_gold_per_day: int
var elite_gold_bp: int
var boss_gold: int
var loss_gold_base: int
var loss_gold_per_win: int
var shards_per_essence: int
var elite_key_chance_bp: int
var relic_choices: int
## Item rarity weights for the Caravan, Loot, and tier shops (by
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
## By STOPS.
var stop_weights: Array[int] = []
## By LOOT_KINDS, plus how much gold a gold loot gives.
var loot_weights: Array[int] = []
var loot_gold: int


static func read(reader: DataReader) -> EconomyDef:
	var def := EconomyDef.new()
	def.base_gold = reader.req_int("base_gold", 0)
	def.package_gold = reader.req_int("package_gold", 0)
	def.item_price = _table(reader, "item_price", TuningDef.TIER_NAMES, 0)
	def.hero_price = _table(reader, "hero_price", TuningDef.TIER_NAMES, 0)
	def.relic_price = _table(reader, "relic_price", ItemDef.RARITIES, 0)
	def.sell_bp = reader.req_int("sell_bp", 0, FixedMath.BP_ONE)
	def.reroll_base = reader.req_int("reroll_base", 0)
	def.reroll_step = reader.req_int("reroll_step", 0)
	def.caravan_items = reader.req_int("caravan_items", 0)
	def.caravan_heroes = reader.req_int("caravan_heroes", 0)
	def.win_gold_base = reader.req_int("win_gold_base", 0)
	def.win_gold_per_day = reader.req_int("win_gold_per_day", 0)
	def.elite_gold_bp = reader.req_int("elite_gold_bp", 0)
	def.boss_gold = reader.req_int("boss_gold", 0)
	def.loss_gold_base = reader.req_int("loss_gold_base", 0)
	def.loss_gold_per_win = reader.req_int("loss_gold_per_win", 0)
	def.shards_per_essence = reader.req_int("shards_per_essence", 1)
	def.elite_key_chance_bp = reader.req_int("elite_key_chance_bp", 0, FixedMath.BP_ONE)
	def.relic_choices = reader.req_int("relic_choices", 1)
	def.rarity_weights = _table(reader, "rarity_weights", ItemDef.RARITIES, 0)
	if def.rarity_weights.size() == ItemDef.RARITIES.size() and def.rarity_weights[ItemDef.RARITIES.find("legendary")] != 0:
		reader.error("rarity_weights: legendary must be 0 (the Caravan, Loot, and tier shops never offer Legendaries)")
	def.vault_rarity_weights = _table(reader, "vault_rarity_weights", ItemDef.RARITIES, 0)
	def.event_rarity_weights = _table(reader, "event_rarity_weights", ItemDef.RARITIES, 0)
	def.loot_tier_weights = _table(reader, "loot_tier_weights", TuningDef.TIER_NAMES, 0)
	def.elite_relic_weights = _table(reader, "elite_relic_weights", ItemDef.RARITIES, 0)
	def.boss_relic_weights = _table(reader, "boss_relic_weights", ItemDef.RARITIES, 0)
	def.relic_weights = _table(reader, "relic_weights", ItemDef.RARITIES, 0)
	def.stop_weights = _table(reader, "stop_weights", STOPS, 0)
	def.loot_weights = _table(reader, "loot_weights", LOOT_KINDS, 0)
	def.loot_gold = reader.req_int("loot_gold", 0)
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


## What an item sells for: a share of its buy price, rounded down.
func sell_price(buy_price: int) -> int:
	@warning_ignore("integer_division")
	return buy_price * sell_bp / FixedMath.BP_ONE
