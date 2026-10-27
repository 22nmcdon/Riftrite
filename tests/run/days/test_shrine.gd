extends GutTest
## The Shrine's offerings (docs/plans/rebuild-phase5c-combos.md, step 8b,
## section 16.6): shards or a wound for a rare relic, a relic for one a tier
## higher; nothing spent until the relic is taken.

const Bot = preload("res://tools/run_bot.gd")
const R = preload("res://tests/run/run_test_kit.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


## A flow at the Shrine, waiting for an offering.
func _at_shrine() -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, 7, Bot.first_vows(_run.content), errors)
	R.to_camp(flow, ["shrine"] as Array[String])
	assert_eq(flow.choose_camp(0), "")
	assert_eq(flow.state.shrine, "open")
	return flow


func test_shards_for_a_rare() -> void:
	var flow: RunFlow = _at_shrine()
	var state: RunState = flow.state
	state.shards = 14
	assert_eq(flow.shrine_offer("shards"), "it asks 15 shards; there are 14")
	state.shards = 20
	assert_eq(flow.shrine_offer("shards"), "")
	assert_eq([state.relic_choice.size(), state.relic_choice_price, state.shrine], [1, 15, "shards"])
	assert_eq(_run.relics[state.relic_choice[0]].tier, RelicDef.Tier.RARE)
	assert_eq(flow.shrine_offer("shards"), "the Shrine isn't waiting for an offering", "one offering")
	assert_eq(flow.leave_node(), "choose a relic or neither first")
	var relic: String = state.relic_choice[0]
	assert_eq(flow.take_relic(0), "")
	assert_eq([state.shards, state.relics, state.shrine], [5, [relic], ""])


func test_a_wound_for_a_rare() -> void:
	var flow: RunFlow = _at_shrine()
	var state: RunState = flow.state
	state.hero("vell").wounds = 3
	assert_eq(flow.shrine_offer("wound", "vell"), "vell can't take another wound")
	assert_eq(flow.shrine_offer("wound", "nobody"), "unknown hero \"nobody\"")
	assert_eq(flow.shrine_offer("wound", "maren"), "")
	assert_eq([state.relic_choice_price, state.shrine, state.hero("maren").wounds], [0, "wound:maren", 0], "nothing spent yet")
	var shards: int = state.shards
	assert_eq(flow.take_relic(0), "")
	assert_eq([state.hero("maren").wounds, state.shards, state.relics.size()], [1, shards, 1], "the wound, no shards")


func test_a_relic_for_one_a_tier_higher() -> void:
	var flow: RunFlow = _at_shrine()
	var state: RunState = flow.state
	assert_eq(flow.shrine_offer("relic", "bone_dice"), "the run doesn't hold \"bone_dice\"")
	var by_tier: Dictionary[int, String] = {}
	for id: String in _run.relic_ids:
		if not by_tier.has(_run.relics[id].tier):
			by_tier[_run.relics[id].tier] = id
	for tier: int in [RelicDef.Tier.LEGENDARY, RelicDef.Tier.BOSS, RelicDef.Tier.BOND]:
		assert_eq(flow.shrine_tier(by_tier[tier]), "", "%s: nothing higher" % RelicDef.TIER_NAMES[tier])
	var common: String = by_tier[RelicDef.Tier.COMMON]
	flow._gain_relic(common)
	assert_eq(flow.shrine_offer("relic", common), "")
	assert_eq(state.shrine, "relic:" + common)
	assert_eq(_run.relics[state.relic_choice[0]].tier, RelicDef.Tier.RARE, "a common for a rare")
	var given: String = state.relic_choice[0]
	assert_eq(flow.take_relic(0), "")
	assert_eq(state.relics, [given] as Array[String], "the offered relic is gone")


func test_turning_it_down_keeps_the_offering() -> void:
	var flow: RunFlow = _at_shrine()
	var state: RunState = flow.state
	assert_eq(flow.shrine_offer("wound", "brannoc"), "")
	assert_eq(flow.decline_relic(), "")
	assert_eq([state.hero("brannoc").wounds, state.relics, state.shrine], [0, [] as Array[String], ""], "nothing given, and the Shrine is done")
	assert_eq(flow.shrine_offer("shards"), "the Shrine isn't waiting for an offering")
	assert_eq(flow.leave_node(), "")


func test_the_shrine_saves() -> void:
	var flow: RunFlow = _at_shrine()
	flow.shrine_offer("wound", "maren")
	var loaded: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(flow.state.to_dict())))
	assert_eq(loaded.shrine, "wound:maren")
