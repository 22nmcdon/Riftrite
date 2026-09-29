extends GutTest
## data/tactics.json and tactics in a fight's setup (docs/plans/rebuild-phase3b-tactics.md,
## sections 1 and 3): reading each kind, the checks across files, enemies'
## archetypes on their kits, and Encounters and FightSetup taking a hero's
## tactic. What each kind does in a fight is test_tactics.gd's (step 2).

const GUARDED: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


func _real_texts() -> Dictionary[String, String]:
	var texts: Dictionary[String, String] = {}
	for file_name: String in ContentDb.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	return texts


## The real data with tactics.json replaced by `tactics`.
func _load_tactics(tactics: Array) -> ContentDb:
	var texts: Dictionary[String, String] = _real_texts()
	texts[ContentDb.TACTICS_FILE] = JSON.stringify(tactics)
	return ContentDb.load_texts(texts)


static func tactic(kind: String, extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {"id": "test", "name": "Test", "text": "Does a thing.", "kind": kind, "heroes": ["maren"]}
	match kind:
		"prefer_target":
			data["archetypes"] = ["caster"]
		"hold_ground":
			data["release_hexes"] = 2
		"signature_threshold":
			data["below_pct"] = 50
			data["heroes"] = ["vell"]
	data.merge(extra, true)
	return data


func _assert_error(db: ContentDb, expected: String) -> void:
	assert_true(db.errors.any(func(message: String) -> bool: return message.contains(expected)), "expected '%s' in %s" % [expected, db.errors])


func test_the_three_tactics() -> void:
	assert_true(_content.is_valid(), str(_content.errors))
	assert_eq(_content.tactic_ids, ["casters_first", "hold_ground", "wait_to_heal"] as Array[String])
	var casters: TacticDef = _content.tactics["casters_first"]
	assert_eq(casters.kind, TacticDef.Kind.PREFER_TARGET)
	assert_eq(casters.archetypes, ["caster", "support"] as Array[String], "casters are casters and supports (Decision 1)")
	var hold: TacticDef = _content.tactics["hold_ground"]
	assert_eq(hold.kind, TacticDef.Kind.HOLD_GROUND)
	assert_eq(hold.release_range, 2 * HexGrid.HEX)
	var wait: TacticDef = _content.tactics["wait_to_heal"]
	assert_eq(wait.kind, TacticDef.Kind.SIGNATURE_THRESHOLD)
	assert_eq(wait.below_bp, 6000, "below 60% (Decision 5)")
	assert_eq([casters.damage_vs_bp, hold.atsp_bp, wait.heal_bp], [2000, 2000, 1500], "each one's payoff (round 2)")
	assert_eq([casters.atsp_bp, casters.heal_bp, hold.damage_vs_bp, hold.heal_bp, wait.damage_vs_bp, wait.atsp_bp], [0, 0, 0, 0, 0, 0], "and only its own")
	for tactic_id: String in ["casters_first", "hold_ground"]:
		assert_eq(_content.tactics[tactic_id].heroes, ["brannoc", "maren", "vell"] as Array[String], "%s is for everyone (Decision 4)" % tactic_id)
	assert_eq(wait.heroes, ["vell"] as Array[String], "Wait to heal is Vell's")
	assert_true(wait.allows("vell"))
	assert_false(wait.allows("maren"))
	for tactic_id: String in _content.tactic_ids:
		assert_false(_content.tactics[tactic_id].text.is_empty())


func test_enemy_kits_carry_their_archetype() -> void:
	assert_eq(_content.enemies["cinder_moth"].kit.archetype, "caster")
	assert_eq(_content.enemies["gloam_witch"].kit.archetype, "support")
	assert_eq(_content.enemies["rift_pup"].kit.archetype, "swarm")
	for enemy_id: String in _content.enemy_ids:
		var enemy: EnemyDef = _content.enemies[enemy_id]
		assert_eq(enemy.kit.archetype, EnemyDef.ARCHETYPE_NAMES[enemy.archetype], enemy_id)
	assert_eq(_content.heroes["maren"].kit.archetype, "", "heroes have none")
	assert_eq(_content.enemies["gloam_witch"].kit.copy().archetype, "support", "a copy keeps it (scaled kits and phases)")


func test_each_kind_reads_its_own_numbers() -> void:
	for kind: String in TacticDef.KIND_NAMES:
		var db: ContentDb = _load_tactics([tactic(kind)])
		assert_true(db.is_valid(), "%s: %s" % [kind, db.errors])
	_assert_error(_load_tactics([tactic("hold_ground", {"archetypes": ["caster"]})]), "unknown key \"archetypes\"")
	_assert_error(_load_tactics([tactic("prefer_target", {"release_hexes": 2})]), "unknown key \"release_hexes\"")
	_assert_error(_load_tactics([tactic("prefer_target", {"below_pct": 50})]), "unknown key \"below_pct\"")


func test_each_kind_reads_only_its_own_payoff() -> void:
	var payoffs: Dictionary[String, String] = {"prefer_target": "damage_vs_bp", "hold_ground": "atsp_bp", "signature_threshold": "heal_bp"}
	for kind: String in payoffs:
		var db: ContentDb = _load_tactics([tactic(kind, {"payoff": {payoffs[kind]: 1500}})])
		assert_true(db.is_valid(), "%s: %s" % [kind, db.errors])
		for other: String in payoffs.values():
			if other != payoffs[kind]:
				_assert_error(_load_tactics([tactic(kind, {"payoff": {payoffs[kind]: 1500, other: 1500}})]), "unknown key \"%s\"" % other)
	assert_true(_load_tactics([tactic("hold_ground")]).is_valid(), "a payoff is optional")
	var none: TacticDef = _load_tactics([tactic("hold_ground")]).tactics["test"]
	assert_eq(none.atsp_bp, 0)
	_assert_error(_load_tactics([tactic("hold_ground", {"payoff": {"atsp_bp": 0}})]), "out of range")
	_assert_error(_load_tactics([tactic("hold_ground", {"payoff": {}})]), "missing required key \"atsp_bp\"")
	_assert_error(_load_tactics([tactic("hold_ground", {"payoff": 20})]), "payoff")


func test_bad_tactics_are_reported() -> void:
	_assert_error(_load_tactics([tactic("charge_blindly")]), "kind")
	_assert_error(_load_tactics([tactic("prefer_target", {"archetypes": []})]), "needs \"archetypes\"")
	_assert_error(_load_tactics([tactic("prefer_target", {"archetypes": ["wizard"]})]), "unknown value \"wizard\"")
	_assert_error(_load_tactics([tactic("hold_ground", {"release_hexes": 0})]), "out of range")
	_assert_error(_load_tactics([tactic("signature_threshold", {"below_pct": 100})]), "out of range")
	var no_text: Dictionary = tactic("hold_ground")
	no_text.erase("text")
	_assert_error(_load_tactics([no_text]), "missing required key \"text\"")
	var no_heroes: Dictionary = tactic("hold_ground")
	no_heroes.erase("heroes")
	_assert_error(_load_tactics([no_heroes]), "missing required key \"heroes\"")
	_assert_error(_load_tactics([tactic("hold_ground", {"heroes": []})]), "at least one hero")
	_assert_error(_load_tactics([tactic("hold_ground", {"heroes": ["nobody"]})]), "unknown hero \"nobody\"")
	_assert_error(_load_tactics([tactic("hold_ground", {"heroes": ["maren", "maren"]})]), "lists \"maren\" twice")
	_assert_error(_load_tactics([tactic("hold_ground"), tactic("hold_ground")]), "duplicate id \"test\"")


func test_only_a_healing_signature_can_wait() -> void:
	_assert_error(_load_tactics([tactic("signature_threshold", {"heroes": ["maren"]})]), "maren's signature doesn't heal the lowest ally on mana")
	_assert_error(_load_tactics([tactic("signature_threshold", {"heroes": ["brannoc"]})]), "brannoc's signature")
	assert_true(_load_tactics([tactic("signature_threshold", {"heroes": ["vell"]})]).is_valid())


func test_a_formation_takes_tactics() -> void:
	var errors: Array[String] = []
	var tactics: Dictionary[String, String] = {"maren": "hold_ground", "vell": "wait_to_heal"}
	var fight: FightSetup = Encounters.setup(_content, "witch_circle", GUARDED, 1, errors, tactics)
	assert_eq(errors, [] as Array[String])
	assert_eq(fight.validate(_content), [] as Array[String])
	assert_null(fight.heroes[0].tactic, "Brannoc took none")
	assert_eq(fight.heroes[1].tactic, _content.tactics["hold_ground"])
	assert_eq(fight.heroes[2].tactic, _content.tactics["wait_to_heal"])
	for enemy: UnitSetup in fight.enemies:
		assert_null(enemy.tactic)
	var plain: FightSetup = Encounters.setup(_content, "witch_circle", GUARDED, 1, errors)
	for hero: UnitSetup in plain.heroes:
		assert_null(hero.tactic, "no tactics unless given")


func test_unknown_tactics_and_missing_heroes_are_refused() -> void:
	var errors: Array[String] = []
	assert_null(Encounters.setup(_content, "witch_circle", GUARDED, 1, errors, {"maren": "charge_blindly"} as Dictionary[String, String]))
	assert_eq(errors, ["unknown tactic \"charge_blindly\""] as Array[String])
	errors.clear()
	var two: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0)}
	assert_null(Encounters.setup(_content, "witch_circle", two, 1, errors, {"vell": "wait_to_heal"} as Dictionary[String, String]))
	assert_eq(errors, ["a tactic for \"vell\", who isn't in the fight"] as Array[String])


func test_the_setup_checks_who_can_take_which() -> void:
	var errors: Array[String] = []
	var fight: FightSetup = Encounters.setup(_content, "witch_circle", GUARDED, 1, errors, {"maren": "wait_to_heal"} as Dictionary[String, String])
	assert_eq(errors, [] as Array[String], "Encounters only checks it exists")
	assert_eq(fight.validate(_content), ["maren at (3, 0) can't take the tactic Wait to heal"] as Array[String])
	fight = Encounters.setup(_content, "witch_circle", GUARDED, 1, errors)
	fight.enemies[0].tactic = _content.tactics["hold_ground"]
	assert_eq(fight.validate(_content).size(), 1)
	assert_string_contains(fight.validate(_content)[0], "can't take the tactic Hold your ground", "enemies take no tactics")
	# Even a hero's kit fighting on the enemies' side (a made-up setup).
	fight = Encounters.setup(_content, "witch_circle", GUARDED, 1, errors)
	var turned: UnitSetup = UnitSetup.make(_content.heroes["maren"].kit, EffectSource.Team.ENEMIES, 1, 6, "turncoat")
	turned.tactic = _content.tactics["hold_ground"]
	fight.enemies.append(turned)
	assert_eq(fight.validate(_content), ["turncoat at (1, 6) can't take the tactic Hold your ground"] as Array[String])
