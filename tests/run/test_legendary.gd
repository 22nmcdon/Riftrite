extends GutTest
## Legendary items and their upgrade paths (docs/plans/legendary-items.md):
## path data, progress and tier-ups, the six paths, feeding and devouring,
## save and load, the run's rules, and where Legendaries come from.

const K = preload("res://tests/sim/sim_test_kit.gd")

static var _run_content: RunContent


func _content() -> ContentDb:
	return K.content()


func _run() -> RunContent:
	if _run_content == null:
		_run_content = RunContent.load_dir("res://data", _content())
		assert(_run_content.is_valid(), str(_run_content.errors))
	return _run_content


func _refused(result: RunActions.Result, expected: String) -> void:
	assert_false(result.ok, "refused")
	assert_true(result.error.contains(expected), "\"%s\" in \"%s\"" % [expected, result.error])


## A run with Brannoc (rank C) fielded and Legendary `item_id` on his row.
func _holding(item_id: String) -> RunState:
	var state: RunState = RunState.make(3)
	assert_true(RunActions.add_hero(state, _content(), "brannoc").ok)
	assert_true(RunActions.add_item(state, _content(), item_id).ok)
	assert_true(RunActions.move_item(state, _content(), state.stash[0].uid, "brannoc", 0).ok)
	return state


func _legendary(state: RunState) -> RunItem:
	return state.hero("brannoc").items[0]


func _path_errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	LegendaryDef.read(DataReader.new(data, "legendary", errors))
	return errors


func _has(errors: Array[String], expected: String) -> bool:
	return errors.any(func(e: String) -> bool: return e.contains(expected))


## A finished fight's result with just the log lines a test needs.
func _result(outcome: FightResult.Outcome, entries: Array[LogEntry]) -> FightResult:
	var result := FightResult.new()
	result.outcome = outcome
	for entry: LogEntry in entries:
		result.combat_log.add(entry)
	return result


func _entry(kind: LogEntry.Kind, source_unit: String, source_item: String, target: String) -> LogEntry:
	var entry := LogEntry.new()
	entry.kind = kind
	entry.source_unit = source_unit
	entry.source_item = source_item
	entry.target = target
	entry.amount = 5
	return entry


# --- path data ----------------------------------------------------------------

func test_path_data_is_read() -> void:
	var path: LegendaryDef = _content().items["hungering_censer"].legendary
	assert_eq([path.path, path.start_tier, path.goals], ["essence", 1, [1, 2] as Array[int]])
	assert_eq([path.goal_at(1), path.goal_at(2), path.goal_at(3), path.goal_at(0)], [1, 2, 0, 0], "no goal at S or below the start")
	assert_eq([path.wanted_at(1), path.wanted_at(2), path.wanted_at(3)], ["ember", "venom", ""])
	var maw: LegendaryDef = _content().items["maw_of_the_hollow"].legendary
	assert_eq([maw.trace_for("common"), maw.trace_for("epic"), maw.trace_for("legendary")], [300, 1200, 0])
	assert_null(_content().items["hearth_knife"].legendary, "only Legendaries have a path")


func test_bad_path_data_is_reported() -> void:
	assert_true(_has(_path_errors({"path": "wish", "start_tier": "c", "goals": [1, 1, 1]}), "unknown value \"wish\""))
	assert_true(_has(_path_errors({"path": "hits", "start_tier": "s", "goals": []}), "can't start at S"))
	assert_true(_has(_path_errors({"path": "hits", "start_tier": "b", "goals": [5]}), "needs 2 number(s), one per tier from B to S"))
	assert_true(_has(_path_errors({"path": "hits", "start_tier": "a", "goals": [0]}), "goals[0]: must be at least 1"))
	assert_true(_has(_path_errors({"path": "essence", "start_tier": "a", "goals": [1], "wants": ["ember", "frost"]}), "one essence per goal"))
	assert_true(_has(_path_errors({"path": "devour", "start_tier": "a", "goals": [1]}), "trace_bp"))
	assert_eq(_path_errors({"path": "boss", "start_tier": "a", "goals": [1]}), [] as Array[String])


func test_items_need_a_path_exactly_when_legendary() -> void:
	var backup: Dictionary = {"auras": [{"target": "all_allies", "stat": "def_bp", "value": 100}]}
	var legendary: Dictionary = K.DEFAULT_ITEM.duplicate(true)
	legendary.merge({"id": "x", "rarity": "legendary", "backup": backup}, true)
	var errors: Array[String] = []
	ItemDef.read(DataReader.new(legendary, "x", errors))
	assert_true(_has(errors, "Legendary items need an upgrade path"))
	var rare: Dictionary = K.DEFAULT_ITEM.duplicate(true)
	rare.merge({"id": "y", "rarity": "rare", "legendary": {"path": "boss", "start_tier": "a", "goals": [1]}}, true)
	errors.clear()
	ItemDef.read(DataReader.new(rare, "y", errors))
	assert_true(_has(errors, "only Legendary items have an upgrade path"))


func test_wanted_essences_must_exist() -> void:
	var texts: Dictionary[String, String] = {}
	for file_name: String in ContentDb.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	var items: Array = JSON.parse_string(texts[ContentDb.ITEMS_FILE])
	for item: Dictionary in items:
		if item["id"] == "hungering_censer":
			item["legendary"]["wants"] = ["ember", "moonlight"]
		if item["id"] == "kinstone_aegis":
			item["enemy_only"] = true
	texts[ContentDb.ITEMS_FILE] = JSON.stringify(items)
	var db: ContentDb = ContentDb.load_texts(texts)
	assert_true(_has(db.errors, "legendary.wants: unknown essence \"moonlight\""), str(db.errors))
	assert_true(_has(db.errors, "a Legendary can't be enemy-only"), str(db.errors))


# --- joining the guild --------------------------------------------------------

func test_a_legendary_joins_at_its_start_tier_once() -> void:
	var state: RunState = RunState.make(3)
	assert_true(RunActions.add_item(state, _content(), "riftbreakers_brand", 0).ok)
	assert_eq(state.stash[0].tier, 2, "boss-forged starts at A, whatever the offer says")
	assert_true(RunActions.add_item(state, _content(), "tallymans_bow", 3).ok)
	assert_eq(state.stash[1].tier, 0, "grows by use starts at C")
	assert_eq(state.legendaries_seen, ["riftbreakers_brand", "tallymans_bow"] as Array[String])
	_refused(RunActions.add_item(state, _content(), "tallymans_bow"), "already holds The Tallyman's Bow")
	assert_eq(state.stash.size(), 2)
	assert_eq(state.check(_content()), [] as Array[String])


func test_legendaries_never_combine_or_take_the_anvil() -> void:
	var state: RunState = _holding("kinstone_aegis")
	var aegis: RunItem = _legendary(state)
	var copy := RunItem.make(state.take_uid(), "kinstone_aegis", aegis.tier)
	state.stash.append(copy)
	_refused(RunActions.combine_items(state, _content(), aegis.uid, copy.uid), "Legendaries never combine")
	state.phase = "stop"
	state.stop_kind = "upgrade"
	_refused(RunFlow.upgrade(state, _content(), aegis.uid), "their own paths")
	assert_eq(aegis.tier, 1)


# --- progress -------------------------------------------------------------------

func test_progress_tiers_up_carries_over_and_stops_at_s() -> void:
	var content: ContentDb = _content()
	var bow := RunItem.make(1, "tallymans_bow", 0)
	assert_eq(RunLegendary.advance(content, bow, 59), [] as Array[String])
	assert_eq([bow.tier, bow.progress], [0, 59])
	assert_eq(RunLegendary.advance(content, bow, 5), ["The Tallyman's Bow grows to B"] as Array[String])
	assert_eq([bow.tier, bow.progress], [1, 4], "the extra 4 carries over")
	assert_eq(RunLegendary.advance(content, bow, 116 + 200 + 50).size(), 2, "two tiers at once")
	assert_eq([bow.tier, bow.progress], [3, 0], "at S progress stops")
	assert_eq(RunLegendary.advance(content, bow, 10), [] as Array[String])
	assert_eq(bow.progress, 0)
	var knife := RunItem.make(2, "hearth_knife", 0)
	assert_eq(RunLegendary.advance(content, knife, 10), [] as Array[String])
	assert_eq([knife.tier, knife.progress], [0, 0], "only Legendaries have a path")
	assert_eq(RunLegendary.advance(content, RunItem.make(3, "tallymans_bow", 0), 0), [] as Array[String])


func test_the_path_reads_in_plain_words() -> void:
	var content: ContentDb = _content()
	var bow := RunItem.make(1, "tallymans_bow", 0)
	bow.progress = 23
	assert_eq(RunLegendary.describe(content, bow), "Grows by use: 23/60 hits to B")
	assert_eq(RunLegendary.describe(content, RunItem.make(2, "hungering_censer", 2)), "Essence-hungry: feed it Venom (0/2 fed to S)")
	assert_true(RunLegendary.describe(content, RunItem.make(3, "maw_of_the_hollow", 0)).begins_with("Devourer: feed it other items (0/3 meals to B"))
	assert_eq(RunLegendary.describe(content, RunItem.make(4, "riftbreakers_brand", 3)), "Boss-forged: fully grown (S)")
	assert_eq(RunLegendary.describe(content, RunItem.make(5, "hearth_knife", 0)), "")


# --- grows by use (hits) --------------------------------------------------------

func test_hits_count_only_the_items_own_direct_damage_on_enemies() -> void:
	var entries: Array[LogEntry] = [
		_entry(LogEntry.Kind.DAMAGE, "maren", "tallymans_bow", "rift_pup_1"),
		_entry(LogEntry.Kind.DAMAGE, "maren", "tallymans_bow", "rift_pup_2"),
		_entry(LogEntry.Kind.STATUS_DAMAGE, "maren", "tallymans_bow", "rift_pup_1"),
		_entry(LogEntry.Kind.DAMAGE, "maren", "hearth_knife", "rift_pup_1"),
		_entry(LogEntry.Kind.DAMAGE, "wren", "tallymans_bow", "rift_pup_1"),
		_entry(LogEntry.Kind.DAMAGE, "maren", "tallymans_bow", "wren"),
		_entry(LogEntry.Kind.HEAL, "maren", "tallymans_bow", "rift_pup_1"),
	]
	var granted: LogEntry = _entry(LogEntry.Kind.DAMAGE, "maren", "tallymans_bow", "rift_pup_1")
	granted.source_granted_by = "cinder_crown"
	entries.append(granted)
	var relic: LogEntry = _entry(LogEntry.Kind.DAMAGE, "maren", "tallymans_bow", "rift_pup_1")
	relic.source_relic_side = 0
	entries.append(relic)
	var result: FightResult = _result(FightResult.Outcome.DEFEAT, entries)
	assert_eq(RunLegendary.hits(result.combat_log, "maren", "tallymans_bow", ["maren", "wren"] as Array[String]), 2)


func test_the_bow_grows_from_a_real_fight_won_or_lost() -> void:
	var state: RunState = _holding("tallymans_bow")
	var bow: RunItem = _legendary(state)
	state.encounter_id = "pup_litter"
	var setup: FightSetup = RunFight.setup_for(state, _content(), state.encounter_id)
	var result: FightResult = CombatSim.run(setup, _content())
	var expected: int = RunLegendary.hits(result.combat_log, "brannoc", "tallymans_bow", ["brannoc"] as Array[String])
	assert_gt(expected, 0, "the bow hit something")
	bow.progress = 60 - expected
	var notes: Array[String] = RunFight.apply_result(state, _content(), result)
	assert_eq(notes, ["The Tallyman's Bow grows to B"] as Array[String])
	assert_eq([bow.tier, bow.progress], [1, 0])


func test_backup_hits_count_too() -> void:
	var state: RunState = _holding("tallymans_bow")
	assert_true(RunActions.add_hero(state, _content(), "wren").ok)
	assert_true(RunActions.move_item(state, _content(), _legendary(state).uid, "wren", 0).ok)
	assert_true(RunActions.set_benched(state, "wren", true).ok)
	state.encounter_id = "pup_litter"
	var result: FightResult = CombatSim.run(RunFight.setup_for(state, _content(), state.encounter_id), _content())
	RunFight.apply_result(state, _content(), result)
	assert_gt(state.hero("wren").items[0].progress, 0, "Tally Volley hits from the bench")


# --- martyr, boss-forged, bonded ------------------------------------------------

func test_martyr_grows_when_its_holder_falls_in_a_win() -> void:
	var state: RunState = _holding("last_hearth_lantern")
	var lantern: RunItem = _legendary(state)
	var death: LogEntry = _entry(LogEntry.Kind.DEATH, "", "", "brannoc")
	var other_death: LogEntry = _entry(LogEntry.Kind.DEATH, "", "", "rift_pup_1")
	assert_eq(RunFight.apply_result(state, _content(), _result(FightResult.Outcome.DEFEAT, [death] as Array[LogEntry])), [] as Array[String], "not in a loss")
	RunFight.apply_result(state, _content(), _result(FightResult.Outcome.VICTORY, [other_death] as Array[LogEntry]))
	assert_eq([lantern.tier, lantern.progress], [1, 0], "not when someone else falls")
	var notes: Array[String] = RunFight.apply_result(state, _content(), _result(FightResult.Outcome.TIE, [death] as Array[LogEntry]))
	assert_eq(notes, ["The Last Hearth-Lantern grows to A"] as Array[String], "a tie counts as a win")


func test_boss_forged_grows_when_a_boss_falls_while_equipped() -> void:
	var state: RunState = _holding("riftbreakers_brand")
	var brand: RunItem = _legendary(state)
	var won: FightResult = _result(FightResult.Outcome.VICTORY, [] as Array[LogEntry])
	state.encounter_id = "pup_litter"
	RunFight.apply_result(state, _content(), won)
	assert_eq(brand.tier, 2, "not a boss")
	state.encounter_id = "the_ash_mother"
	RunFight.apply_result(state, _content(), _result(FightResult.Outcome.DEFEAT, [] as Array[LogEntry]))
	assert_eq(brand.tier, 2, "not a loss")
	assert_true(RunActions.add_hero(state, _content(), "wren").ok)
	assert_true(RunActions.move_item(state, _content(), brand.uid, "wren", 0).ok)
	assert_true(RunActions.set_benched(state, "wren", true).ok)
	assert_eq(RunFight.apply_result(state, _content(), won), ["The Riftbreaker's Brand grows to S"] as Array[String], "equipped in backup counts")
	var stashed: RunState = _holding("riftbreakers_brand")
	assert_true(RunActions.move_item(stashed, _content(), _legendary(stashed).uid, RunState.STASH, 0).ok)
	stashed.encounter_id = "the_ash_mother"
	RunFight.apply_result(stashed, _content(), won)
	assert_eq(stashed.stash[0].tier, 2, "not from the stash")


func test_bonded_grows_when_its_holder_ranks_up() -> void:
	var state: RunState = _holding("kinstone_aegis")
	var aegis: RunItem = _legendary(state)
	assert_true(RunActions.add_hero(state, _content(), "wren").ok)
	assert_eq(RunActions.add_hero(state, _content(), "wren").notes, [] as Array[String], "another hero ranking up")
	assert_eq(aegis.tier, 1)
	assert_true(RunActions.add_item(state, _content(), "tallymans_bow").ok)
	var bow: RunItem = state.stash[0]
	assert_true(RunActions.move_item(state, _content(), bow.uid, "brannoc", 9).ok)
	var ranked: RunActions.Result = RunActions.add_hero(state, _content(), "brannoc")
	assert_true(ranked.ok)
	assert_eq(ranked.notes, ["The Kinstone Aegis grows to A"] as Array[String])
	assert_eq(aegis.tier, 2)
	assert_eq([bow.tier, bow.progress], [0, 0], "only Bonded Legendaries grow with rank-ups")


# --- essence-hungry ---------------------------------------------------------------

func test_feeding_the_censer_the_essence_it_wants() -> void:
	var state: RunState = _holding("hungering_censer")
	var censer: RunItem = _legendary(state)
	state.pouch.append_array(["venom", "ember", "ember", "venom", "venom"] as Array[String])
	# B -> A wants 1 Ember; A -> S wants 2 Venom.
	_refused(RunActions.feed_essence(state, _content(), censer.uid, 0), "wants Ember")
	_refused(RunActions.feed_essence(state, _content(), censer.uid, 9), "no essence there")
	_refused(RunActions.feed_essence(state, _content(), 999, 1), "isn't in the guild")
	assert_eq(state.pouch.size(), 5, "refusals change nothing")
	var fed: RunActions.Result = RunActions.feed_essence(state, _content(), censer.uid, 1)
	assert_true(fed.ok)
	assert_eq([censer.tier, censer.progress, fed.notes], [2, 0, ["The Hungering Censer grows to A"] as Array[String]])
	_refused(RunActions.feed_essence(state, _content(), censer.uid, 1), "wants Venom")
	assert_eq(state.pouch, ["venom", "ember", "venom", "venom"] as Array[String])
	var half: RunActions.Result = RunActions.feed_essence(state, _content(), censer.uid, 0)
	assert_eq([censer.tier, censer.progress, half.notes], [2, 1, [] as Array[String]])
	assert_eq(RunActions.feed_essence(state, _content(), censer.uid, 1).notes, ["The Hungering Censer grows to S"] as Array[String])
	assert_eq([censer.tier, censer.progress], [3, 0])
	_refused(RunActions.feed_essence(state, _content(), censer.uid, 1), "fully grown")
	assert_eq(state.pouch, ["ember", "venom"] as Array[String])
	var other: RunState = _holding("kinstone_aegis")
	other.pouch.append("ember")
	_refused(RunActions.feed_essence(other, _content(), _legendary(other).uid, 0), "only an Essence-hungry Legendary")
	assert_eq(state.check(_content()), [] as Array[String])


# --- the devourer ------------------------------------------------------------------

func test_the_maw_devours_items_and_keeps_a_trace() -> void:
	var state: RunState = _holding("maw_of_the_hollow")
	var maw: RunItem = _legendary(state)
	assert_true(RunActions.add_item(state, _content(), "hearth_knife", 1).ok)
	assert_true(RunActions.add_item(state, _content(), "rimewood_longbow", 0).ok)
	assert_true(RunActions.add_item(state, _content(), "tallymans_bow").ok)
	var knife: RunItem = state.stash[0]
	var longbow: RunItem = state.stash[1]
	var bow: RunItem = state.stash[2]
	_refused(RunActions.devour_item(state, _content(), maw.uid, maw.uid), "can't eat itself")
	_refused(RunActions.devour_item(state, _content(), maw.uid, bow.uid), "a Legendary can't be eaten")
	_refused(RunActions.devour_item(state, _content(), bow.uid, knife.uid), "only a Devourer")
	_refused(RunActions.devour_item(state, _content(), maw.uid, 999), "isn't in the guild")
	assert_eq(state.stash.size(), 3, "refusals change nothing")
	var ate: RunActions.Result = RunActions.devour_item(state, _content(), maw.uid, knife.uid)
	assert_true(ate.ok)
	assert_eq(ate.note, "Maw of the Hollow devours Hearth Knife")
	assert_eq([maw.tier, maw.progress, maw.eaten], [0, 2, ["hearth_knife"] as Array[String]], "a B meal is worth 2")
	assert_eq(RunActions.devour_item(state, _content(), maw.uid, longbow.uid).notes, ["Maw of the Hollow grows to B"] as Array[String])
	assert_eq([maw.tier, maw.progress], [1, 0])
	assert_eq(state.stash, [bow] as Array[RunItem], "eaten items are gone")
	assert_eq(maw.trace_bp(_content()), 300 + 1200, "Common + Epic traces")
	assert_eq(maw.to_entry(_content()).trace_bp, 1500)
	assert_eq(state.check(_content()), [] as Array[String])


func test_the_trace_multiplies_the_items_own_numbers() -> void:
	var def: ItemDef = _content().items["maw_of_the_hollow"]
	var stats: UnitStats = _content().heroes["brannoc"].stats
	var plain: ItemState = ItemState.make(def, 0, stats, _content())
	var fed: ItemState = ItemState.make(def, 0, stats, _content(), [], 0, 0, 5000)
	assert_eq(fed.effects[0].value.final, FixedMath.apply_bp(plain.effects[0].value.final, 15000))
	assert_true(fed.effects[0].value.to_text().contains("x1.5 devoured"), fed.effects[0].value.to_text())
	var backup: ItemState = ItemState.make(def.backup.as_item_def(def, "brannoc"), 0, stats, _content(), [], 0, 0, 5000)
	var plain_backup: ItemState = ItemState.make(def.backup.as_item_def(def, "brannoc"), 0, stats, _content())
	assert_gt(backup.effects[0].value.final, plain_backup.effects[0].value.final, "the backup mode too")


func test_the_trace_reaches_the_fight() -> void:
	var state: RunState = _holding("maw_of_the_hollow")
	var maw: RunItem = _legendary(state)
	maw.eaten.append_array(["hearth_knife", "hearth_knife"] as Array[String])
	var setup: FightSetup = RunFight.setup_for(state, _content(), "pup_litter")
	assert_eq(setup.heroes[0].items[0].trace_bp, 600)


# --- save and the run's rules --------------------------------------------------

func test_progress_and_meals_survive_save_and_load() -> void:
	var state: RunState = _holding("maw_of_the_hollow")
	var maw: RunItem = _legendary(state)
	maw.progress = 2
	maw.eaten.append("hearth_knife")
	var loaded: Array = RunState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())), _content())
	assert_eq(loaded[1], [] as Array[String])
	var back: RunItem = (loaded[0] as RunState).hero("brannoc").items[0]
	assert_eq([back.progress, back.eaten], [2, ["hearth_knife"] as Array[String]])
	var plain: Dictionary = RunItem.make(4, "hearth_knife").to_dict()
	assert_false(plain.has("progress") or plain.has("eaten"), "only saved when set, so older saves still load")


func test_the_run_rules_cover_legendaries() -> void:
	var state: RunState = _holding("riftbreakers_brand")
	var brand: RunItem = _legendary(state)
	brand.tier = 1
	brand.progress = -1
	brand.eaten.append("ghost_item")
	var errors: Array[String] = state.check(_content())
	for expected: String in ["starts at A, so it can't be below it", "-1 path progress", "only a Devourer eats items", "ate an unknown item \"ghost_item\""]:
		assert_true(_has(errors, expected), "%s in %s" % [expected, errors])
	brand.tier = 3
	brand.progress = 1
	brand.eaten.clear()
	assert_true(_has(state.check(_content()), "0 at S"))
	brand.progress = 0
	state.stash.append(RunItem.make(state.take_uid(), "riftbreakers_brand", 2))
	assert_true(_has(state.check(_content()), "held twice"))
	state.stash.clear()
	state.legendaries_seen.clear()
	assert_true(_has(state.check(_content()), "not marked as seen"))
	var knife := RunItem.make(state.take_uid(), "hearth_knife")
	knife.progress = 3
	state.legendaries_seen.append("riftbreakers_brand")
	state.stash.append(knife)
	assert_true(_has(state.check(_content()), "no upgrade path, so no path progress"))


# --- where Legendaries come from ------------------------------------------------

func test_the_caravan_loot_and_tier_shops_never_offer_legendaries() -> void:
	var economy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
	economy["rarity_weights"]["legendary"] = 1
	var texts: Dictionary[String, String] = {}
	for file_name: String in RunContent.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	texts[RunContent.ECONOMY_FILE] = JSON.stringify(economy)
	assert_true(_has(RunContent.load_texts(texts, _content()).errors, "legendary must be 0"))
	for run_seed: int in range(1, 41):
		var state: RunState = RunFlow.new_run(run_seed, _content())
		RunFlow.pick_start_hero(state, _content(), 0)
		RunFlow.pick_package(state, _content(), _run(), 0)
		for offer: Dictionary in state.offers:
			if offer["type"] == "item":
				assert_ne(_content().items[offer["item"]].rarity, "legendary", "the Caravan")
		RunFlow._enter_stop(state, _content(), _run(), "loot")
		for offer: Dictionary in state.offers:
			if offer["type"] == "item":
				assert_ne(_content().items[offer["item"]].rarity, "legendary", "Loot")


func test_the_vault_can_hold_a_legendary_at_its_start_tier() -> void:
	var found: int = 0
	for run_seed: int in range(1, 120):
		var state: RunState = RunFlow.new_run(run_seed, _content())
		RunFlow.pick_start_hero(state, _content(), 0)
		RunFlow.pick_package(state, _content(), _run(), 0)
		state.keys = 1
		RunFlow._enter_stop(state, _content(), _run(), "vault")
		var offer: Dictionary = state.offers[0]
		if offer["type"] != "item":
			continue
		var def: ItemDef = _content().items[offer["item"]]
		assert_true(["rare", "epic", "legendary"].has(def.rarity), "the Vault holds Rare and up")
		if def.legendary != null:
			found += 1
			assert_eq(offer["tier"], def.legendary.start_tier)
			assert_true(state.legendaries_seen.has(def.id), "an offered Legendary counts as seen")
	assert_gt(found, 0, "some Vault finds a Legendary")


func test_the_barrow_hoard_offers_an_unseen_legendary() -> void:
	var texts: Dictionary[String, String] = {}
	for file_name: String in RunContent.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	var events: Array = JSON.parse_string(texts[RunContent.EVENTS_FILE])
	texts[RunContent.EVENTS_FILE] = JSON.stringify(events.filter(func(e: Dictionary) -> bool: return e["kind"] == "legendary_item"))
	var hoard_only: RunContent = RunContent.load_texts(texts, _content())
	assert_eq(hoard_only.errors, [] as Array[String])
	var state: RunState = RunFlow.new_run(4, _content())
	RunFlow.pick_start_hero(state, _content(), 0)
	RunFlow.pick_package(state, _content(), _run(), 0)
	var seen: Array[String] = []
	for day: int in range(1, 7):
		state.day = day
		RunFlow._enter_stop(state, _content(), hoard_only, "event")
		assert_eq(state.offers.size(), 1)
		var offer: Dictionary = state.offers[0]
		assert_eq(offer["event"], "barrow_hoard")
		var def: ItemDef = _content().items[offer["item"]]
		assert_not_null(def.legendary)
		assert_eq(offer["tier"], def.legendary.start_tier)
		assert_false(seen.has(def.id), "never the same Legendary twice")
		seen.append(def.id)
	state.day = 7
	RunFlow._enter_stop(state, _content(), hoard_only, "event")
	assert_eq(state.offers, [] as Array[Dictionary], "all six seen: the hoard is empty")


func test_a_fights_growth_comes_back_with_the_result() -> void:
	var state: RunState = RunFlow.new_run(5, _content())
	RunFlow.pick_start_hero(state, _content(), 0)
	RunFlow.pick_package(state, _content(), _run(), 0)
	var hero: RunHero = state.heroes[0]
	hero.rank = 3
	hero.needs_specialization = false
	hero.items.clear()
	for item_id: String in ["hearthstone_ward", "first_light_dagger"]:
		hero.items.append(RunItem.make(state.take_uid(), item_id, 3))
	assert_true(RunActions.add_item(state, _content(), "tallymans_bow").ok)
	assert_true(RunActions.move_item(state, _content(), state.stash[-1].uid, hero.hero_id, 0).ok)
	state.stash.clear()
	hero.items[0].progress = 59
	assert_true(RunFlow.leave_caravan(state, _content(), _run()).ok)
	if state.phase == "stop_choice":
		RunFlow.pick_stop(state, _content(), _run(), 0)
	RunFlow.leave_stop(state)
	var out: Array = RunFlow.fight(state, _content(), _run())
	assert_true((out[0] as RunActions.Result).ok)
	assert_eq((out[0] as RunActions.Result).notes, ["The Tallyman's Bow grows to B"] as Array[String])


# --- the run bot ----------------------------------------------------------------------

func test_the_bot_feeds_legendaries() -> void:
	var state: RunState = _holding("hungering_censer")
	var censer: RunItem = _legendary(state)
	assert_true(RunActions.add_item(state, _content(), "maw_of_the_hollow").ok)
	var maw: RunItem = state.stash[0]
	state.pouch.append_array(["venom", "ember"] as Array[String])
	RunBot._feed_legendaries(state, _content())
	assert_eq([censer.tier, censer.progress], [2, 1], "Ember, then one Venom, before any infusing")
	assert_eq(state.pouch, [] as Array[String])
	assert_eq(maw.eaten, [] as Array[String], "a Devourer never eats itself")
	var knife := RunItem.make(state.take_uid(), "hearth_knife")
	state.stash.append(knife)
	RunBot._feed_legendaries(state, _content())
	assert_eq(maw.eaten, ["hearth_knife"] as Array[String], "stash leftovers go to the Devourer")
	assert_eq(state.stash, [maw] as Array[RunItem])
	assert_eq(state.check(_content()), [] as Array[String])
