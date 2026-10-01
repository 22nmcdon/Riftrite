extends GutTest
## Every card's stat change says its amount (docs/plans/rebuild-phase5c-combos.md,
## step 2): ModInfo's numbers line for kit mods, items, upgrades, relics, and
## duo bonds.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb
var _run: RunContent


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")
	_run = RunContent.load_dir("res://data", _content)


func _mod(data: Dictionary) -> KitMod:
	var errors: Array[String] = []
	var made: KitMod = KitMod.read(DataReader.new(data, "mod", errors))
	assert_eq(errors, [] as Array[String])
	return made


func test_each_part_of_a_mod() -> void:
	assert_eq(ModInfo.mod_numbers(_mod({"stats_bp": {"def": 11500, "hp": 9200}}), null, _content), "−8% HP · +15% DEF")
	assert_eq(ModInfo.mod_numbers(_mod({"stats_add": {"speed": -1, "crit": 5}}), null, _content), "+5 CRIT · −1 Speed")
	assert_eq(ModInfo.mod_numbers(_mod({"on": [{"slot": "signature", "types": ["damage"], "amount_bp": 12000, "duration_add_ms": 2000, "radius_add": 1, "cooldown_bp": 9000}]}), null, _content),
		"Signature: +20% damage, +2s duration, +1 hex area, −10% cooldown")
	assert_eq(ModInfo.mod_numbers(_mod({"on": [{"slot": "basic_attack", "add_effects": [{"trigger": "on_crit", "type": "apply_status", "status": "slow", "target": "target"}]}]}), null, _content),
		"Basic attack: on crit: Slow 2s")
	assert_eq(ModInfo.mod_numbers(_mod({"mana": {"max_add": -15, "start_add": 20, "per_attack_add": 2}}), null, _content), "−15 max mana · +20 starting mana · +2 mana per attack")
	assert_eq(ModInfo.mod_numbers(_mod({"also_fires": [{"kind": "hp_below", "threshold_bp": 4000}]}), null, _content), "Signature also fires: once, below 40% HP")
	assert_eq(ModInfo.mod_numbers(_mod({"echo": {"after_ms": 2000, "share_pct": 50}}), null, _content), "Signature fires again 2s later at 50%")


func test_an_added_effect_that_scales_uses_the_heros_numbers() -> void:
	var mod: KitMod = _mod({"on": [{"slot": "basic_attack", "add_effects": [{"trigger": "on_hit", "type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 5000}}]}]})
	var kit: UnitDef = K.kit("hero", {"stats": {"hp": 100, "atk": 40}})
	assert_eq(ModInfo.mod_numbers(mod, kit, _content), "Basic attack: on hit: 20 damage (50% ATK)", "worked out from the hero's ATK")


## Part 7, section 6: no card with a mod goes without its amounts.
func test_every_card_in_the_data_has_a_numbers_line() -> void:
	for id: String in _run.item_ids:
		for rank: int in range(1, ItemDef.RANKS + 1):
			assert_false(ModInfo.item_numbers(_run.items[id], null, _content, rank).is_empty(), "%s rank %d" % [id, rank])
	for id: String in _run.upgrade_ids:
		assert_false(ModInfo.upgrade_numbers(_run.upgrades[id], null, _content).is_empty(), id)
	for id: String in _run.relic_ids:
		assert_false(ModInfo.relic_numbers(_run.relics[id], _content).is_empty(), id)
	for id: String in _run.bond_ids:
		# A bond is the key to its relic (phase 5c step 5d), which says its numbers.
		assert_false(ModInfo.relic_numbers(_run.relics[_run.bonds[id].relic], _content).is_empty(), id)


func test_every_stat_change_names_its_amount() -> void:
	for id: String in _run.item_ids:
		var item: ItemDef = _run.items[id]
		for rank: int in range(1, item.ranks.size() + 1):
			var mod: KitMod = item.mod_at(rank)
			var numbers: String = ModInfo.item_numbers(item, null, _content, rank)
			for stat: int in mod.stats_bp.size():
				if mod.stats_bp[stat] != FixedMath.BP_ONE:
					assert_string_contains(numbers, "%s %s" % [UnitInfo.signed_percent(mod.stats_bp[stat] - FixedMath.BP_ONE), UnitStats.LABELS[stat]], id)


func test_a_relics_run_rules_and_who_its_mods_are_for() -> void:
	assert_eq(ModInfo.relic_numbers(_run.relics["bloodstone"], _content), "Heroes: +8% ATK")
	assert_eq(ModInfo.relic_numbers(_run.relics["hollow_crown"], _content), "+1 loadout slot")
	assert_eq(ModInfo.relic_numbers(_run.relics["rift_glass_eye"], _content), "every fight Scouted")
	assert_eq(ModInfo.relic_numbers(_run.relics["gravediggers_coin"], _content), "+3 shards per won fight")
	assert_eq(ModInfo.relic_numbers(_run.relics["whetstone_of_the_fallen"], _content), "Heroes: +6 ATK")
	assert_eq(ModInfo.relic_numbers(_run.relics["collectors_chain"], _content), "Grows: +1 ATK per 10 kills, counted for the whole team")
	assert_eq(ModInfo.relic_numbers(_run.relics["bloodied_coin"], _content), "Grows: +1 shard per 1 kills, counted for the whole team")
	assert_eq(ModInfo.relic_numbers(_run.relics["tally_of_the_dead"], _content), "Grows: +2% HP per 1 elites won, counted for the whole team")
	assert_eq(ModInfo.relic_numbers(_run.relics["tinkers_purse"], _content), "the first reroll in every shop is free")
	assert_eq(ModInfo.relic_numbers(_run.relics["bounty_board"], _content), "+25 shards, once, for 3 won fights in a row with no hero falling")
	assert_eq(ModInfo.relic_numbers(_run.relics["gilded_rift"], _content), "Heroes: +1% ATK and MGK per 5 shards held")


func test_a_tactic_item_takes_its_tactics_line() -> void:
	var item: ItemDef = _run.items["hold_ground_orders"]
	assert_eq(ModInfo.item_numbers(item, null, _content), UnitInfo.tactic_numbers(item.tactic))
