extends GutTest
## The Magpie's stall (docs/plans/rebuild-phase5c-combos.md, step 6e,
## section 14.8; magpie.md): two charms at rank II, a relic at 25% off,
## buying relics, and one swap a visit.

const Bot = preload("res://tools/run_bot.gd")
const R = preload("res://tests/run/run_test_kit.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _magpie() -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, 7, Bot.first_vows(_run.content), errors)
	assert_eq(errors, [] as Array[String])
	flow.state.shards = 100
	R.to_magpie(flow)
	assert_eq(flow.state.shop, "magpie")
	return flow


func _hold(flow: RunFlow, ids: Array) -> void:
	for id: String in ids:
		flow._gain_relic(id)


func test_two_charms_at_rank_ii() -> void:
	var flow: RunFlow = _magpie()
	var state: RunState = flow.state
	assert_eq(state.wares.size(), 2)
	for id: String in state.wares:
		assert_eq(_run.items[id].kind, ItemDef.Kind.CHARM, "%s is a charm" % id)
	assert_eq(state.wares, Offers.magpie(_run, state), "the same state, the same stall")
	var first: String = state.wares[0]
	assert_eq(flow.buy(0), "")
	assert_eq([state.shards, state.item_ranks[first]], [88, 2], "12 shards, and it comes at rank II")
	state.wares[1] = first
	assert_eq(flow.buy(1), "")
	assert_eq(state.item_ranks[first], 3, "a copy of one you own: rank III")
	for id: String in _run.item_ids:
		if _run.items[id].kind == ItemDef.Kind.CHARM:
			state.item_ranks[id] = 3
	assert_eq(Offers.magpie(_run, state), [] as Array[String], "never one held at rank III")
	assert_eq(flow.sell(first), "only the Pedlar buys items", "he doesn't buy items")


func test_he_buys_relics() -> void:
	var flow: RunFlow = _magpie()
	var state: RunState = flow.state
	_hold(flow, ["bloodstone", "hollow_crown"])
	assert_eq(flow.relic_sell_price("bloodstone"), _run.acts[0].relic_sell[RelicDef.TIER_NAMES[_run.relics["bloodstone"].tier]])
	assert_eq(_run.acts[0].relic_sell, {"common": 2, "rare": 6, "epic": 10, "legendary": 15, "boss": 15, "bond": 0})
	var shards: int = state.shards
	assert_eq(flow.sell_relic("bloodstone"), "")
	assert_eq([state.relics.has("bloodstone"), state.shards], [false, shards + flow.relic_sell_price("bloodstone")])
	assert_eq(flow.sell_relic("bloodstone"), "the run doesn't hold \"bloodstone\"")
	state.hero("maren").slots[3] = "fleet"
	assert_eq(flow.sell_relic("hollow_crown"), "")
	assert_eq(state.hero("maren").slots.size(), _run.acts[0].slots, "the slot it gave goes")
	assert_has(state.stash, "fleet", "and what was in it goes back to the stash")
	R.to_pedlar(flow)
	_hold(flow, ["bloodstone"])
	assert_eq(flow.sell_relic("bloodstone"), "only the Magpie buys relics")


func test_one_swap_a_visit() -> void:
	var flow: RunFlow = _magpie()
	var state: RunState = flow.state
	_hold(flow, ["bloodstone", "hollow_crown"])
	var tier: RelicDef.Tier = _run.relics["bloodstone"].tier
	assert_eq(flow.swap_relic("bloodstone"), "")
	assert_false(state.relics.has("bloodstone"))
	var swapped: String = state.relics.back()
	assert_eq(_run.relics[swapped].tier, tier, "one of the same tier")
	assert_ne(swapped, "hollow_crown")
	assert_eq(flow.swap_relic("hollow_crown"), "he swaps once a visit")
	flow.close_shop()
	assert_eq(flow.open_shop("magpie"), "")
	assert_eq(flow.swap_relic("hollow_crown"), "", "again on the next visit")


func test_a_boss_relic_swaps_for_a_boss_relic_and_a_bond_relic_doesnt() -> void:
	var flow: RunFlow = _magpie()
	var boss: String = _run.relic_ids.filter(func(id: String) -> bool: return _run.relics[id].tier == RelicDef.Tier.BOSS)[0]
	var bond: String = _run.relic_ids.filter(func(id: String) -> bool: return _run.relics[id].tier == RelicDef.Tier.BOND)[0]
	_hold(flow, [boss, bond])
	assert_eq(_run.relics[Offers.magpie_swap(_run, flow.state, boss)].tier, RelicDef.Tier.BOSS)
	assert_eq(Offers.magpie_swap(_run, flow.state, bond), "")
	assert_string_starts_with(flow.swap_relic(bond), "he has nothing to swap")
	assert_eq(flow.relic_sell_price(bond), 0, "a bond relic sells for nothing")


func test_the_swap_saves() -> void:
	var flow: RunFlow = _magpie()
	_hold(flow, ["bloodstone"])
	flow.swap_relic("bloodstone")
	var loaded: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(flow.state.to_dict())))
	assert_true(loaded.magpie_swapped)
	assert_eq(JSON.stringify(loaded.to_dict()), JSON.stringify(flow.state.to_dict()))
