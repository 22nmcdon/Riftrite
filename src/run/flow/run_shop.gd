class_name RunShop
extends RefCounted
## The shops' rules for RunFlow (phase 5c steps 5a, 6, and 6e;
## docs/plans/design/relics/ and loadout/): opening and closing the Pedlar, the
## boss shop, and the Magpie; prices, buying, selling, rerolls, treating wounds,
## transmuting (Ottilie), Hob's shop rules and black market, and buying,
## selling, and swapping relics. RunFlow keeps the actions' names (buy,
## reroll, sell_relic, ...) and delegates here; every function takes the flow
## it acts on and changes only its state.


## Opens a shop ("pedlar" after the fight, "magpie" as his node), its wares
## and relics drawn now (the day opens it; tests open one directly). Phase 5c step 5a:
## every shop shows a relic (more with shop_relics_add); the boss day's
## Pedlar, after the boss, is the boss shop (a legendary first, rerolls from
## boss_reroll; Decision 48); the Magpie's are epic or legendary, one look. As a shop
## opens, the relics' shop_shards and miser pay.
static func open_shop(flow: RunFlow, kind: String) -> String:
	if flow.state.phase != RunState.Phase.SHOP and flow.state.phase != RunState.Phase.NODE:
		return flow._not_now("open a shop")
	match kind:
		"pedlar":
			flow.state.wares = Offers.pedlar(flow.run, flow.state, 0)
		"magpie":
			flow.state.wares = Offers.magpie(flow.run, flow.state)
		_:
			return "there's no shop \"%s\"" % kind
	flow.state.shop = kind
	_mark_rank_ii(flow)
	flow.state.shop_dear_bp = flow.state.dear_shop_bp
	flow.state.dear_shop_bp = 0
	flow.state.rerolls = 0
	flow.state.transmutes = 0
	flow.state.shop_relics_bought = 0
	flow.state.ledger_rerolls = 0
	flow.state.black_market_rerolled = 0
	flow.state.magpie_swapped = false
	flow.state.shop_relics = _draw_shop_relics(flow)
	flow.state.shards += flow.run.relic_sum(flow.state, "shop_shards")
	# A shop visited (phase 8 part 6, Old Contacts: "shops").
	RunRecord._grow_by_run(flow, "shops")
	if flow.run.relic_rule(flow.state, "miser"):
		@warning_ignore("integer_division")
		flow.state.shards += mini(flow.state.shards / 5, 6)
	return ""


static func _draw_shop_relics(flow: RunFlow) -> Array[String]:
	var count: int = 1 + flow.run.relic_sum(flow.state, "shop_relics_add") + (1 if boss_shop(flow) else 0)
	var drawn: Array[String] = Offers.shop_relics(flow.run, flow.state, flow.state.rerolls, count, flow.state.shop == "magpie", boss_shop(flow))
	# Black Market (phase 8 part 6): the Pedlar's second slot, a tier up.
	flow.state.black_market_slot = -1
	flow.state.black_market_tier = ""
	var rules: ShopRulesDef = shop_rules(flow)
	if flow.state.shop == "pedlar" and rules != null and rules.black_market > 0:
		var black: Array[String] = Offers.black_market_relic(flow.run, flow.state, flow.state.rerolls * 10 + flow.state.black_market_rerolled, drawn)
		if not black[0].is_empty():
			flow.state.black_market_slot = drawn.size()
			flow.state.black_market_tier = black[1]
			drawn.append(black[0])
	return drawn


## The black-market slot's free rerolls left in the open shop.
static func black_market_rerolls_left(flow: RunFlow) -> int:
	var rules: ShopRulesDef = shop_rules(flow)
	if flow.state.shop != "pedlar" or rules == null or flow.state.black_market_slot < 0 or flow.state.shop_relics[flow.state.black_market_slot].is_empty():
		return 0
	return maxi(rules.black_market_rerolls - flow.state.black_market_rerolled, 0)


## Smuggler's Route (phase 8 part 6): the black-market slot alone drawn
## again, free, as many times a shop as the team's shop rules allow.
static func reroll_black_market(flow: RunFlow) -> String:
	var rules: ShopRulesDef = shop_rules(flow)
	if flow.state.shop != "pedlar" or flow.state.black_market_slot < 0 or flow.state.shop_relics[flow.state.black_market_slot].is_empty():
		return "there's no black-market relic to reroll"
	if rules == null or flow.state.black_market_rerolled >= rules.black_market_rerolls:
		return "the black-market relic can't be rerolled again in this shop"
	flow.state.black_market_rerolled += 1
	var others: Array[String] = flow.state.shop_relics.duplicate()
	var black: Array[String] = Offers.black_market_relic(flow.run, flow.state, flow.state.rerolls * 10 + flow.state.black_market_rerolled, others)
	if not black[0].is_empty():
		flow.state.shop_relics[flow.state.black_market_slot] = black[0]
		flow.state.black_market_tier = black[1]
	return ""


## True if the open shop is the boss shop: the Pedlar of the boss's day,
## after the boss fight and its relic choice (Decision 48; it was the day
## before the boss's until then).
static func boss_shop(flow: RunFlow) -> bool:
	return flow.state.shop == "pedlar" and flow.run.day_kind(flow.state, flow.state.day) == "boss"


static func close_shop(flow: RunFlow) -> void:
	flow.state.shop = ""
	flow.state.shop_dear_bp = 0
	flow.state.wares.clear()
	flow.state.rerolls = 0
	flow.state.transmutes = 0
	flow.state.shop_relics_bought = 0
	flow.state.shop_relics.clear()
	flow.state.wares_rank_ii.clear()
	flow.state.ledger_rerolls = 0
	flow.state.black_market_slot = -1
	flow.state.black_market_tier = ""
	flow.state.black_market_rerolled = 0


## What ware `item_id` costs at the open shop: its kind's price at the
## Pedlar (with relics' price_add), the Magpie's charm price at his stall.
static func price_of(flow: RunFlow, item_id: String) -> int:
	if flow.state.shop == "magpie":
		return flow.act.magpie_charm_price
	var rules: ShopRulesDef = shop_rules(flow)
	# Wholesale (phase 8 part 6): the team's shop rules take some off.
	return maxi(_marked_up(flow, flow.act.item_prices[ItemDef.KIND_NAMES[flow.run.items[item_id].kind]]) - (rules.item_less if rules != null else 0), 1)


## What the Pedlar pays for `item_id`: half its kind's price, rounded down,
## whatever its rank (loadout rule 9); less by the team's shop rules (phase 8
## part 6, Fence: a quarter).
static func sell_price(flow: RunFlow, item_id: String) -> int:
	var rules: ShopRulesDef = shop_rules(flow)
	var share_bp: int = 5000 - (rules.sell_less_bp if rules != null else 0)
	@warning_ignore("integer_division")
	return flow.act.item_prices[ItemDef.KIND_NAMES[flow.run.items[item_id].kind]] * maxi(share_bp, 0) / FixedMath.BP_ONE


## Sells an item the run owns to the Pedlar, from the stash or a slot. Its
## rank goes with it.
static func sell(flow: RunFlow, item_id: String) -> String:
	if flow.state.shop != "pedlar":
		return "only the Pedlar buys items"
	if not flow.state.item_ranks.has(item_id):
		return "the run doesn't own \"%s\"" % item_id
	var paid: int = sell_price(flow, item_id)
	_drop_item(flow, item_id)
	flow.state.shards += paid
	return ""


## Takes an item the run owns away, from the stash or a slot, rank and all.
static func _drop_item(flow: RunFlow, item_id: String) -> void:
	if flow.state.stash.has(item_id):
		flow.state.stash.erase(item_id)
	else:
		for hero: RunState.Hero in flow.state.heroes:
			var slot: int = hero.slots.find(item_id)
			if slot >= 0:
				hero.slots[slot] = ""
	flow.state.item_ranks.erase(item_id)
	flow.state.item_counts.erase(item_id)


## The team's transmuting (phase 8 part 6, Transmuter): its heroes'
## TransmuteDefs added together (null: none of them transmutes).
static func _transmuting(flow: RunFlow) -> TransmuteDef:
	var sum: TransmuteDef = null
	for hero: RunState.Hero in flow.state.heroes:
		var own: TransmuteDef = flow.run.transmute(hero)
		if own != null:
			sum = own.merged(sum)
	return sum


## Items the open shop may still transmute (0: none; only the Pedlar and the
## boss shop, Decision 6).
static func transmutes_left(flow: RunFlow) -> int:
	var transmuting: TransmuteDef = _transmuting(flow)
	if flow.state.shop != "pedlar" or transmuting == null:
		return 0
	return maxi(transmuting.per_shop - flow.state.transmutes, 0)


## What transmuting `item_id` pays: its kind's full price (selling pays
## half), and more by the team's transmuting cards.
static func transmute_price(flow: RunFlow, item_id: String) -> int:
	var transmuting: TransmuteDef = _transmuting(flow)
	var price: int = flow.act.item_prices[ItemDef.KIND_NAMES[flow.run.items[item_id].kind]]
	return transmuting.pays(price, flow.state.item_ranks.get(item_id, 1)) if transmuting != null else price


## Turns an item the run owns into shards at its full price (phase 8 part 6,
## transformed Transmuter: once a shop, at the Pedlar or the boss shop), from
## the stash or a slot. Its rank goes with it.
static func transmute(flow: RunFlow, item_id: String) -> String:
	if transmutes_left(flow) <= 0:
		return "nobody can transmute here" if flow.state.shop != "pedlar" or _transmuting(flow) == null else "no more transmuting in this shop"
	if not flow.state.item_ranks.has(item_id):
		return "the run doesn't own \"%s\"" % item_id
	var paid: int = transmute_price(flow, item_id)
	_drop_item(flow, item_id)
	flow.state.transmutes += 1
	flow.state.shards += paid
	if flow.run.relic_rule(flow.state, "ledger"):
		# The Black Market Ledger (phase 8 part 6): its full price counts as
		# spent, and the shop owes a free reroll.
		RunRecord._grow_by_run(flow, "spent", flow.act.item_prices[ItemDef.KIND_NAMES[flow.run.items[item_id].kind]])
		flow.state.ledger_rerolls += 1
	return ""


## How many items the open shop may still turn into other items (phase 8
## part 6, Grand Transmutation): its transmutes, if the team's transmuting
## allows items into items there, else what's left of the act's allowance.
static func transmutes_into_left(flow: RunFlow) -> int:
	var transmuting: TransmuteDef = _transmuting(flow)
	if flow.state.shop != "pedlar" or transmuting == null:
		return 0
	if transmuting.into_shop > 0 and transmutes_left(flow) > 0:
		return transmutes_left(flow)
	return maxi(transmuting.into_per_act - flow.state.transmuted_act, 0)


## Turns an item the run owns into a random item of the same kind it
## doesn't own (phase 8 part 6, Grand Transmutation: its taste once an act,
## its apex with a shop's transmutes, at rank II), and counts it toward every
## hero's "transmuted" deed.
static func transmute_into(flow: RunFlow, item_id: String) -> String:
	if transmutes_into_left(flow) <= 0:
		return "nobody can transmute an item into another here"
	if not flow.state.item_ranks.has(item_id):
		return "the run doesn't own \"%s\"" % item_id
	var kind: ItemDef.Kind = flow.run.items[item_id].kind
	var pool: Array[String] = flow.run.item_ids.filter(func(id: String) -> bool: return flow.run.items[id].kind == kind and not flow.state.item_ranks.has(id))
	if pool.is_empty():
		return "there's no other item of its kind to make"
	var transmuting: TransmuteDef = _transmuting(flow)
	var rng: SimRng = RunRandom.stream(flow.state.seed_value, [RunRandom.TRANSMUTE, flow.state.act, flow.state.day, flow.state.attempt, flow.state.transmutes + flow.state.transmuted_act * 16])
	var made: String = pool[rng.range_int(pool.size())]
	if transmuting.into_shop > 0 and transmutes_left(flow) > 0:
		flow.state.transmutes += 1
	else:
		flow.state.transmuted_act += 1
	_drop_item(flow, item_id)
	flow._gain_item(made, maxi(transmuting.into_rank, 1))
	for hero: RunState.Hero in flow.state.heroes:
		for key: String in hero.deeds:
			var deed: DeedDef = RunRecord._deed_of(flow, key)
			if deed != null and deed.counts == DeedDef.Counts.TRANSMUTED:
				hero.deeds[key] += 1
	return ""


## A price at the Pedlar, with the relics' price_add (never below 1).
static func _marked_up(flow: RunFlow, price: int) -> int:
	var marked: int = maxi(price + flow.run.relic_sum(flow.state, "price_add"), 1)
	# The Rift Merchant's toll on the next shop (phase 5c step 8c).
	return FixedMath.apply_bp(marked, flow.state.shop_dear_bp) if flow.state.shop_dear_bp > 0 else marked


## Buys ware `index` into the stash, or, owned, a rank up (a bought copy
## skips a rank).
static func buy(flow: RunFlow, index: int) -> String:
	if flow.state.shop.is_empty():
		return "no shop is open"
	if index < 0 or index >= flow.state.wares.size() or flow.state.wares[index].is_empty():
		return "there's no ware %d" % index
	var price: int = price_of(flow, flow.state.wares[index])
	if flow.state.shards < price:
		return "it costs %d shards; there are %d" % [price, flow.state.shards]
	flow.state.shards -= price
	_spent(flow, price)
	# The Magpie's charms come at rank II (phase 5c step 6e), and Insider's
	# at the Pedlar (phase 8 part 6).
	flow._gain_item(flow.state.wares[index], 2 if flow.state.shop == "magpie" or flow.state.wares_rank_ii.has(index) else 1)
	flow.state.wares[index] = ""
	return ""


## The rank buying ware `index` gives: an owned item's next, rank II at least
## at the Magpie or for Insider's charms (phase 8 part 6), at most III.
static func ware_rank(flow: RunFlow, index: int) -> int:
	var rank: int = flow.state.item_ranks.get(flow.state.wares[index], 0) + 1
	if flow.state.shop == "magpie" or flow.state.wares_rank_ii.has(index):
		rank = maxi(rank, 2)
	return mini(rank, ItemDef.RANKS)


## Insider (phase 8 part 6): the first of the Pedlar's charms, as many as
## the team's shop rules say, come at rank II.
static func _mark_rank_ii(flow: RunFlow) -> void:
	flow.state.wares_rank_ii.clear()
	var rules: ShopRulesDef = shop_rules(flow)
	if flow.state.shop != "pedlar" or rules == null:
		return
	for i: int in flow.state.wares.size():
		if flow.state.wares_rank_ii.size() < rules.rank_ii_charms and flow.run.items[flow.state.wares[i]].kind == ItemDef.Kind.CHARM:
			flow.state.wares_rank_ii.append(i)


## What the open shop's next reroll costs (phase 5c step 5a): the first
## reroll_price (boss_reroll_price in the boss shop), each after it 1
## more (flat_rerolls: never more); free_reroll makes the first free.
## The team's shop rules (phase 8 part 6, Hob) then change it (`full`:
## without them).
static func reroll_price(flow: RunFlow, full: bool = false) -> int:
	var price: int = _reroll_price(flow, full)
	# The Black Market Ledger's free rerolls (phase 8 part 6).
	return 0 if not full and price > 0 and flow.state.ledger_rerolls > 0 else price


static func _reroll_price(flow: RunFlow, full: bool) -> int:
	if flow.state.rerolls == 0 and flow.run.relic_rule(flow.state, "free_reroll"):
		return 0
	var base: int = flow.act.boss_reroll_price if boss_shop(flow) else flow.act.reroll_price
	var price: int = base + (0 if flow.run.relic_rule(flow.state, "flat_rerolls") else flow.state.rerolls)
	var rules: ShopRulesDef = shop_rules(flow)
	return price if full or rules == null or flow.state.shop != "pedlar" else rules.reroll_price(flow.state.rerolls, price)


## The Pedlar lays out fresh wares and relics (Decision 19), for the next
## reroll's price. The Magpie is one look.
static func reroll(flow: RunFlow) -> String:
	if flow.state.shop != "pedlar":
		return "only the Pedlar rerolls"
	var price: int = reroll_price(flow)
	if flow.state.shards < price:
		return "a reroll costs %d shards; there are %d" % [price, flow.state.shards]
	if price == 0 and _reroll_price(flow, false) > 0:
		flow.state.ledger_rerolls -= 1
	flow.state.shards -= price
	_spent(flow, price)
	_saved(flow, DeedDef.Counts.REROLLS_SAVED, reroll_price(flow, true) - price)
	flow.state.rerolls += 1
	flow.state.wares = Offers.pedlar(flow.run, flow.state, flow.state.rerolls)
	_mark_rank_ii(flow)
	flow.state.shop_relics = _draw_shop_relics(flow)
	return ""


## What treating a wound costs (with wound_price_add, never below 0).
static func wound_price(flow: RunFlow) -> int:
	return maxi(flow.act.wound_price + flow.run.relic_sum(flow.state, "wound_price_add"), 0)


## Treats one of `hero_id`'s wounds, wherever a shop is open.
static func treat_wound(flow: RunFlow, hero_id: String) -> String:
	if flow.state.shop.is_empty():
		return "no shop is open"
	var hero: RunState.Hero = flow.state.hero(hero_id)
	if hero == null:
		return "unknown hero \"%s\"" % hero_id
	if hero.wounds == 0:
		return "%s has no wounds" % hero_id
	if flow.state.shards < wound_price(flow):
		return "treating a wound costs %d shards; there are %d" % [wound_price(flow), flow.state.shards]
	flow.state.shards -= wound_price(flow)
	_spent(flow, wound_price(flow))
	hero.wounds -= 1
	return ""


## The team's shop rules (phase 8 part 6, ShopRulesDef): its heroes' added
## together (null: none of them has any).
static func shop_rules(flow: RunFlow) -> ShopRulesDef:
	var sum: ShopRulesDef = null
	for hero: RunState.Hero in flow.state.heroes:
		var own: ShopRulesDef = flow.run.shop_rules(hero)
		if own != null:
			sum = own.merged(sum)
	return sum


## Shards spent in a shop (phase 8 part 6, Decision 6): at the Pedlar, the
## boss shop, or the Magpie, on items, relics, rerolls, and wounds; the run
## counts them for what grows with "spent" (transformed Fence).
static func _spent(flow: RunFlow, amount: int) -> void:
	if amount > 0 and (flow.state.shop == "pedlar" or flow.state.shop == "magpie"):
		RunRecord._grow_by_run(flow, "spent", amount)


## Shards the team's shop rules saved (phase 8 part 6, Haggle's and Black
## Market's deeds): counted toward every hero's deed of that kind.
static func _saved(flow: RunFlow, counts: DeedDef.Counts, amount: int) -> void:
	if amount <= 0:
		return
	for hero: RunState.Hero in flow.state.heroes:
		for key: String in hero.deeds:
			var deed: DeedDef = RunRecord._deed_of(flow, key)
			if deed != null and deed.counts == counts:
				hero.deeds[key] += amount


## True while some boss relic isn't held.
static func _boss_relic_left(flow: RunFlow) -> bool:
	return flow.run.relic_ids.any(func(id: String) -> bool: return flow.run.relics[id].tier == RelicDef.Tier.BOSS and not flow.state.relics.has(id))


## Buys the open shop's relic `index`.
static func buy_relic(flow: RunFlow, index: int = 0) -> String:
	if flow.state.shop.is_empty() or index < 0 or index >= flow.state.shop_relics.size() or flow.state.shop_relics[index].is_empty():
		return "there's no relic for sale"
	var price: int = relic_price(flow, index)
	if flow.state.shards < price:
		return "it costs %d shards; there are %d" % [price, flow.state.shards]
	flow.state.shards -= price
	_spent(flow, price)
	_saved(flow, DeedDef.Counts.RELICS_SAVED, relic_price(flow, index, true) - price)
	flow.state.shop_relics_bought += 1
	flow._gain_relic(flow.state.shop_relics[index])
	flow.state.shop_relics[index] = ""
	# Each relic bought (phase 8 part 6, Black Market's run snowball).
	RunRecord._grow_by_run(flow, "relics_bought")
	return ""


## What the open shop's relic `index` costs: its tier's price (the Magpie's
## at his discount, rounded down), with the Pedlar's price_add and (phase 8
## part 6) the team's shop rules (`full`: without them).
static func relic_price(flow: RunFlow, index: int = 0, full: bool = false) -> int:
	if index < 0 or index >= flow.state.shop_relics.size() or flow.state.shop_relics[index].is_empty():
		return 0
	var price: int = flow.act.relic_prices[RelicDef.TIER_NAMES[flow.run.relics[flow.state.shop_relics[index]].tier]]
	if flow.state.shop == "magpie":
		@warning_ignore("integer_division")
		return price * flow.act.magpie_relic_pct / 100
	# A bond relic is free (phase 5c step 5d), whatever the prices.
	if price == 0:
		return 0
	var rules: ShopRulesDef = shop_rules(flow)
	if full or rules == null:
		return _marked_up(flow, price)
	if index == flow.state.black_market_slot and not flow.state.black_market_tier.is_empty():
		# The black-market relic, at the price of the tier it was drawn at.
		price = flow.act.relic_prices[flow.state.black_market_tier]
	var marked: int = _marked_up(flow, price)
	if rules.first_relic_less > 0 and flow.state.shop_relics_bought == 0:
		# Black Market's taste: the first relic bought in each shop.
		marked -= rules.first_relic_less
	# Black Market's snowball: less for each relic bought since, down to half.
	@warning_ignore("integer_division")
	marked -= mini(_relics_bought(flow) * rules.relic_less_per_bought, _marked_up(flow, price) / 2)
	return maxi(marked, 0)


## The relics bought since an earned apex began counting them (phase 8 part
## 6, Black Market), its apex cards' snowball added on.
static func _relics_bought(flow: RunFlow) -> int:
	var count: int = 0
	for hero: RunState.Hero in flow.state.heroes:
		var apex: ApexDef = flow.run.earned_apex(hero)
		if apex != null and apex.grows != null and apex.grows.run_counts == "relics_bought":
			count += flow.run.apex_count(hero, apex)
	return count


## What the Magpie pays for `relic_id` (its tier's relic_sell).
static func relic_sell_price(flow: RunFlow, relic_id: String) -> int:
	return flow.act.relic_sell.get(RelicDef.TIER_NAMES[flow.run.relics[relic_id].tier], 0)


## Sells a relic the run holds to the Magpie, the only one who buys them
## (phase 5c step 6e, magpie.md). What it counted is lost with it.
static func sell_relic(flow: RunFlow, relic_id: String) -> String:
	if flow.state.shop != "magpie":
		return "only the Magpie buys relics"
	if not flow.state.relics.has(relic_id):
		return "the run doesn't hold \"%s\"" % relic_id
	_lose_relic(flow, relic_id)
	flow.state.shards += relic_sell_price(flow, relic_id)
	return ""


## The Magpie's swap, once a visit: `relic_id` for a relic of its tier the
## run doesn't hold, free.
static func swap_relic(flow: RunFlow, relic_id: String) -> String:
	if flow.state.shop != "magpie":
		return "only the Magpie swaps relics"
	if flow.state.magpie_swapped:
		return "he swaps once a visit"
	if not flow.state.relics.has(relic_id):
		return "the run doesn't hold \"%s\"" % relic_id
	var other: String = Offers.magpie_swap(flow.run, flow.state, relic_id)
	if other.is_empty():
		return "he has nothing to swap for %s" % flow.run.relics[relic_id].name
	_lose_relic(flow, relic_id)
	flow._gain_relic(other)
	flow.state.magpie_swapped = true
	return ""


## The run lets go of a relic: its growth goes, and a loadout slot it gave
## goes from each hero (what was in it back to the stash).
static func _lose_relic(flow: RunFlow, relic_id: String) -> void:
	flow.state.relics.erase(relic_id)
	flow.state.growth.erase(relic_id)
	for i: int in flow.run.relics[relic_id].slots_add:
		for hero: RunState.Hero in flow.state.heroes:
			var last: String = hero.slots.pop_back()
			if not last.is_empty():
				flow.state.stash.append(last)
