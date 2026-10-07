extends GutTest
## The shop lean (docs/plans/easy-start.md, ES-4): RunContent.test_lean weights
## some items and relics up in the shops' and relic choices' draws, for the
## run report's test teams only. Empty, every draw is as it always was; and
## nothing in the game (src/) ever sets it.

const Bot = preload("res://tools/run_bot.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func after_each() -> void:
	_run.test_lean.clear()


func test_no_lean_draws_as_ever() -> void:
	var pool: Array[String] = _run.item_ids.duplicate()
	for seed_value: int in 20:
		var rng: SimRng = SimRng.new(seed_value)
		var plain: SimRng = SimRng.new(seed_value)
		var left: Array[String] = pool.duplicate()
		var expected: Array[String] = []
		for i: int in 5:
			expected.append(left.pop_at(plain.range_int(left.size())))
		assert_eq(Offers._draw(rng, pool, 5), expected, "seed %d: one roll a ware, equally likely" % seed_value)


func test_a_lean_draws_its_items_and_relics_more_often() -> void:
	var items: Array[String] = ["bramble_knot", "opportunist", "grasping"]
	var relics: Array[String] = ["bramble_seed", "rusted_fetter", "thornwoven_cloak", "grasping_mire"]
	var plain: Array[int] = _count(items, relics)
	for id: String in items + relics:
		_run.test_lean[id] = 3
	var leaned: Array[int] = _count(items, relics)
	assert_gt(leaned[0], plain[0] * 2, "items: %d leaned against %d" % [leaned[0], plain[0]])
	assert_gt(leaned[1], plain[1] * 2, "relics: %d leaned against %d" % [leaned[1], plain[1]])


func test_only_the_tools_set_the_lean() -> void:
	var found: Array[String] = []
	_scan("res://src", found)
	assert_eq(found, [] as Array[String], "the game never writes RunContent.test_lean (testing only)")
	var save: String = FileAccess.get_file_as_string("res://src/run/run_save.gd")
	assert_false(save.contains("test_lean"), "and never saves it")


## How often `items` show among the Pedlar's wares and `relics` among a
## shop's relics, over 200 runs' first shops.
func _count(items: Array[String], relics: Array[String]) -> Array[int]:
	var counts: Array[int] = [0, 0]
	for seed_value: int in 200:
		var errors: Array[String] = []
		var flow: RunFlow = RunFlow.start(_run, seed_value, Bot.first_vows(_run.content), errors)
		for id: String in Offers.pedlar(_run, flow.state, 0):
			counts[0] += 1 if items.has(id) else 0
		for id: String in Offers.shop_relics(_run, flow.state, 0, 3, false, false):
			counts[1] += 1 if relics.has(id) else 0
	return counts


## Every line under `dir` that writes test_lean (an assignment, or a call
## that changes it), as "file: line".
func _scan(dir: String, found: Array[String]) -> void:
	var writes: RegEx = RegEx.create_from_string("test_lean\\s*(\\[[^\\]]*\\]\\s*)?=[^=]|test_lean\\.(assign|merge|clear|erase|set|get_or_add)\\(")
	for file_name: String in DirAccess.get_files_at(dir):
		if not file_name.ends_with(".gd"):
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string(dir.path_join(file_name)).split("\n")
		for i: int in lines.size():
			if writes.search(lines[i]) != null:
				found.append("%s:%d: %s" % [file_name, i + 1, lines[i].strip_edges()])
	for sub: String in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(sub), found)
