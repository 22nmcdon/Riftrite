extends GutTest
## Paths and stages (docs/plans/rebuild-phase4-paths.md, sections 1 and 2):
## reading a path, building its vowed and transformed kits from the hero's
## base kit (KitPatch), the checks across files, and a fight's setup taking a
## hero's vow and stage. The deeds' counting is test_deeds.gd's.

const GUARDED: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}

var _content: ContentDb


func before_all() -> void:
	_content = _load_paths([maren_path(), vell_path()])
	assert_true(_content.is_valid(), str(_content.errors))


static func _real_texts() -> Dictionary[String, String]:
	var texts: Dictionary[String, String] = {}
	for file_name: String in ContentDb.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	return texts


## The real data with paths.json replaced by `paths`.
static func _load_paths(paths: Array) -> ContentDb:
	var texts: Dictionary[String, String] = _real_texts()
	texts[ContentDb.PATHS_FILE] = JSON.stringify(paths)
	return ContentDb.load_texts(texts)


## A test path for Maren: the vow slows her attack and adds a passive; the
## transformation sharpens her, reaches 2 farther, swaps her signature, and
## drops Slip Away.
static func maren_path(extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {
		"id": "sharpshot", "hero": "maren", "name": "Sharpshot", "title": "the test sniper",
		"fantasy": "She shoots from far away.", "placement": "A far corner.",
		"vowed": {"taste": "Aim: crits more.", "cost": "Attacks 10% slower.",
			"patch": {"stats_bp": {"atsp": 9000},
				"passives": [{"id": "aim", "name": "Aim", "kind": "aura", "text": "She crits more.",
					"aura": {"target": "holder", "stat": "crit_chance_bp", "value": 500}}]}},
		"transformed": {"text": "Reaches 6 hexes; Pierce replaces Marking Shot.", "cost": "No more slipping away.",
			"patch": {"stats_bp": {"atk": 12000}, "stats_add": {"range": 2, "crit": 6},
				"signature": {"id": "pierce", "name": "Pierce", "trigger": {"kind": "mana"}, "targeting": "nearest",
					"effects": [{"type": "damage", "amount": 40, "target": "target"}]},
				"remove_passives": ["slip_away"]}},
		"deed": {"text": "Damage from beyond 4 hexes", "counts": "damage", "beyond_hexes": 4},
	}
	data.merge(extra, true)
	return data


## A test path for Vell whose transformation trades Mend for a signature on
## HP, so she loses her mana bar.
static func vell_path(extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {
		"id": "last_light", "hero": "vell", "name": "Last Light", "title": "the test martyr",
		"fantasy": "She burns brightest when hurt.", "placement": "Up front.",
		"vowed": {"taste": "Tougher.", "cost": "Heals less.", "patch": {"stats_bp": {"def": 12000, "mgk": 9000}}},
		"transformed": {"text": "Flares when hurt.", "cost": "No mana.",
			"patch": {"signature": {"id": "flare", "name": "Flare", "trigger": {"kind": "hp_below", "threshold_bp": 3000}, "targeting": "self",
				"effects": [{"type": "heal", "amount": 50, "target": "self"}]}}},
		"deed": {"text": "Healing from Mend", "counts": "healing", "from_ability": ["mend"]},
	}
	data.merge(extra, true)
	return data


func _assert_error(db: ContentDb, expected: String) -> void:
	assert_true(db.errors.any(func(message: String) -> bool: return message.contains(expected)), "expected '%s' in %s" % [expected, db.errors])


func test_a_path_and_its_kits() -> void:
	var path: PathDef = _content.paths["sharpshot"]
	assert_eq([path.hero, path.name, path.title, path.fantasy, path.placement], ["maren", "Sharpshot", "the test sniper", "She shoots from far away.", "A far corner."])
	assert_eq([path.taste, path.vowed_cost, path.transformed_text, path.transformed_cost],
		["Aim: crits more.", "Attacks 10% slower.", "Reaches 6 hexes; Pierce replaces Marking Shot.", "No more slipping away."])
	var base: UnitDef = _content.heroes["maren"].kit
	var vowed: UnitDef = path.vowed_kit
	assert_eq(vowed.stats.get_stat(UnitStats.Stat.ATSP), 9, "10 ATSP, 10% slower")
	assert_eq(vowed.stats.get_stat(UnitStats.Stat.ATK), 22, "the rest as it was")
	assert_eq(vowed.ability_ids(), ["longshot", "marking_shot", "slip_away", "aim"] as Array[String], "the taste is added")
	assert_eq([vowed.id, vowed.name], [base.id, base.name], "still Maren")
	var transformed: UnitDef = path.transformed_kit
	assert_eq(transformed.ability_ids(), ["longshot", "pierce"] as Array[String], "no taste, a new signature, Slip Away gone")
	assert_eq(transformed.stats.get_stat(UnitStats.Stat.RANGE), 6)
	assert_eq(transformed.stats.get_stat(UnitStats.Stat.CRIT), 14)
	assert_eq(transformed.stats.get_stat(UnitStats.Stat.ATK), 26, "22 x 1.2, rounded")
	assert_eq(transformed.stats.get_stat(UnitStats.Stat.ATSP), 10, "the vow's cost doesn't carry over")
	assert_eq(transformed.mana, base.mana, "a mana signature keeps the bar")
	# The base kit is untouched.
	assert_eq(base.ability_ids(), ["longshot", "marking_shot", "slip_away"] as Array[String])
	assert_eq([base.stats.get_stat(UnitStats.Stat.RANGE), base.stats.get_stat(UnitStats.Stat.ATSP)], [4, 10])
	assert_eq(path.kit(PathDef.Stage.BASE, base), base)
	assert_eq(path.kit(PathDef.Stage.VOWED, base), vowed)
	assert_eq(path.kit(PathDef.Stage.TRANSFORMED, base), transformed)


func test_heroes_list_their_paths_in_file_order() -> void:
	var content: ContentDb = _load_paths([vell_path(), maren_path(), vell_path({"id": "second_light"})])
	assert_true(content.is_valid(), str(content.errors))
	assert_eq(content.path_ids, ["last_light", "sharpshot", "second_light"] as Array[String])
	assert_eq(content.heroes["vell"].paths, [content.paths["last_light"], content.paths["second_light"]] as Array[PathDef])
	assert_eq(content.heroes["vell"].path("second_light"), content.paths["second_light"])
	assert_null(content.heroes["vell"].path("sharpshot"))
	assert_eq(content.heroes["brannoc"].paths.size(), 0)


func test_the_mana_bar_follows_the_signature() -> void:
	var transformed: UnitDef = _content.paths["last_light"].transformed_kit
	assert_eq(transformed.signature.id, "flare")
	assert_null(transformed.mana, "a signature on HP takes the bar away")
	assert_not_null(_content.paths["last_light"].vowed_kit.mana)
	# "mana": null takes it away too, and a mana signature can't do without it.
	var no_bar: Dictionary = vell_path()
	no_bar["vowed"]["patch"] = {"mana": null}
	_assert_error(_load_paths([no_bar]), "a mana signature needs \"mana\"")
	var new_bar: Dictionary = vell_path()
	new_bar["vowed"]["patch"] = {"mana": {"max": 65, "start": 20, "per_attack": 12, "regen_per_s": 2}}
	var content: ContentDb = _load_paths([new_bar])
	assert_true(content.is_valid(), str(content.errors))
	assert_eq(content.paths["last_light"].vowed_kit.mana.max, 65)


func test_a_patch_replaces_a_passive_with_its_id() -> void:
	var replaced: Dictionary = maren_path()
	replaced["vowed"]["patch"] = {"passives": [{"id": "slip_away", "name": "Slip Away", "kind": "aura", "text": "Changed.",
		"aura": {"target": "holder", "stat": "def_bp", "value": 12000}}]}
	var content: ContentDb = _load_paths([replaced])
	assert_true(content.is_valid(), str(content.errors))
	var kit: UnitDef = content.paths["sharpshot"].vowed_kit
	assert_eq(kit.ability_ids(), ["longshot", "marking_shot", "slip_away"] as Array[String])
	assert_eq(kit.passives[0].text, "Changed.")
	assert_eq(content.heroes["maren"].kit.passives[0].kind, PartDef.Kind.ABILITY, "the base kit keeps its own")


func test_bad_paths_are_reported() -> void:
	_assert_error(_load_paths([maren_path({"hero": "nobody"})]), "unknown hero \"nobody\"")
	_assert_error(_load_paths([maren_path(), maren_path({"id": "b"}), maren_path({"id": "c"}), maren_path({"id": "d"})]), "maren already has 3 paths")
	_assert_error(_load_paths([maren_path(), maren_path()]), "duplicate id \"sharpshot\"")
	var gone: Dictionary = maren_path()
	gone["transformed"]["patch"]["remove_passives"] = ["hearthlight"]
	_assert_error(_load_paths([gone]), "transformed: it has no passive \"hearthlight\" to remove")
	var short: Dictionary = maren_path()
	short["vowed"]["patch"] = {"stats_add": {"range": -4}}
	_assert_error(_load_paths([short]), "vowed: its range would drop below 1")
	var slow: Dictionary = maren_path()
	slow["vowed"]["patch"] = {"stats_add": {"speed": -3}}
	_assert_error(_load_paths([slow]), "vowed: its Speed would drop below 0")
	var empty: Dictionary = maren_path()
	empty["vowed"]["patch"] = {}
	_assert_error(_load_paths([empty]), "a patch needs")
	var odd_stat: Dictionary = maren_path()
	odd_stat["vowed"]["patch"] = {"stats_bp": {"range": 12000}}
	_assert_error(_load_paths([odd_stat]), "unknown key \"range\"")
	var huge: Dictionary = maren_path()
	huge["vowed"]["patch"] = {"stats_bp": {"atk": 90000}}
	_assert_error(_load_paths([huge]), "out of range")
	var bad_status: Dictionary = maren_path()
	bad_status["vowed"]["patch"] = {"passives": [{"id": "hex", "name": "Hex", "kind": "replace_status", "from": "burn", "to": "doom"}]}
	_assert_error(_load_paths([bad_status]), "paths.json (sharpshot): vowed: unknown status \"doom\"")
	var twice: Dictionary = maren_path()
	twice["vowed"]["patch"] = {"passives": [{"id": "longshot", "name": "Again", "kind": "aura", "aura": {"target": "holder", "stat": "def_bp", "value": 12000}}]}
	_assert_error(_load_paths([twice]), "vowed: its abilities and passives need different ids")
	var no_vow: Dictionary = maren_path()
	no_vow.erase("vowed")
	_assert_error(_load_paths([no_vow]), "missing required key \"vowed\"")
	var no_title: Dictionary = maren_path()
	no_title.erase("title")
	_assert_error(_load_paths([no_title]), "missing required key \"title\"")


func test_bad_deeds_are_reported() -> void:
	_assert_error(_load_paths([maren_path({"deed": {"text": "x", "counts": "glory"}})]), "counts")
	_assert_error(_load_paths([maren_path({"deed": {"text": "x", "counts": "damage", "from_ability": ["nothing"]}})]), "the deed counts \"nothing\", which isn't in maren's kits")
	for ability_id: String in ["longshot", "aim", "pierce"]:
		var db: ContentDb = _load_paths([maren_path({"deed": {"text": "x", "counts": "damage", "from_ability": [ability_id]}})])
		assert_true(db.is_valid(), "%s is in one of her kits: %s" % [ability_id, db.errors])
	_assert_error(_load_paths([maren_path({"deed": {"text": "x", "counts": "healing", "beyond_hexes": 5}})]), "only filter damage")
	_assert_error(_load_paths([maren_path({"deed": {"text": "x", "counts": "shield", "while_below_pct": 30}})]), "only filter damage")
	_assert_error(_load_paths([maren_path({"deed": {"text": "x", "counts": "damage", "while_below_pct": 100}})]), "out of range")
	_assert_error(_load_paths([maren_path({"deed": {"text": "x", "counts": "damage", "from_ability": []}})]), "from_ability needs at least one id")
	var deed: DeedDef = _content.paths["sharpshot"].deed
	assert_eq([deed.text, deed.counts, deed.from_range, deed.while_below_bp], ["Damage from beyond 4 hexes", DeedDef.Counts.DAMAGE, 4 * HexGrid.HEX, 0])
	var low: DeedDef = _load_paths([maren_path({"deed": {"text": "x", "counts": "damage", "while_below_pct": 30}})]).paths["sharpshot"].deed
	assert_eq(low.while_below_bp, 3000)


func test_a_formation_takes_vows_and_stages() -> void:
	var errors: Array[String] = []
	var fight: FightSetup = Encounters.setup(_content, "witch_circle", GUARDED, 1, errors, {}, {"maren": "sharpshot", "vell": "last_light"} as Dictionary[String, String], ["vell"] as Array[String])
	assert_eq(errors, [] as Array[String])
	assert_eq(fight.validate(_content), [] as Array[String])
	var brannoc: UnitSetup = fight.heroes[0]
	var maren: UnitSetup = fight.heroes[1]
	var vell: UnitSetup = fight.heroes[2]
	assert_eq([brannoc.path, brannoc.stage, brannoc.def], [null, PathDef.Stage.BASE, _content.heroes["brannoc"].kit], "Brannoc took none")
	assert_eq([maren.path, maren.stage, maren.def], [_content.paths["sharpshot"], PathDef.Stage.VOWED, _content.paths["sharpshot"].vowed_kit])
	assert_eq([vell.path, vell.stage, vell.def], [_content.paths["last_light"], PathDef.Stage.TRANSFORMED, _content.paths["last_light"].transformed_kit])
	assert_eq(maren.id, "maren", "the fight still calls her maren")
	for hero: UnitSetup in fight.heroes:
		assert_eq(hero.deed_paths, _content.heroes[hero.def.id].paths, "%s counts all its paths' deeds, whatever its stage" % hero.id)
	for enemy: UnitSetup in fight.enemies:
		assert_eq([enemy.path, enemy.deed_paths.size()], [null, 0])


func test_unknown_paths_and_missing_heroes_are_refused() -> void:
	var errors: Array[String] = []
	assert_null(Encounters.setup(_content, "witch_circle", GUARDED, 1, errors, {}, {"maren": "nowhere"} as Dictionary[String, String]))
	assert_eq(errors, ["unknown path \"nowhere\""] as Array[String])
	errors.clear()
	var two: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0)}
	assert_null(Encounters.setup(_content, "witch_circle", two, 1, errors, {}, {"vell": "last_light"} as Dictionary[String, String]))
	assert_eq(errors, ["a vow for \"vell\", who isn't in the fight"] as Array[String])
	errors.clear()
	assert_null(Encounters.setup(_content, "witch_circle", GUARDED, 1, errors, {}, {}, ["maren"] as Array[String]))
	assert_eq(errors, ["\"maren\" transforms without a vow"] as Array[String])


func test_the_setup_checks_whose_path_it_is() -> void:
	var errors: Array[String] = []
	var fight: FightSetup = Encounters.setup(_content, "witch_circle", GUARDED, 1, errors, {}, {"brannoc": "sharpshot"} as Dictionary[String, String])
	assert_eq(errors, [] as Array[String], "Encounters only checks it exists")
	assert_eq(fight.heroes[0].def, _content.heroes["brannoc"].kit, "no kit built from another hero's path")
	assert_eq(fight.validate(_content), ["brannoc at (3, 2) can't take the path Sharpshot"] as Array[String])
	fight = Encounters.setup(_content, "witch_circle", GUARDED, 1, errors)
	fight.enemies[0].path = _content.paths["sharpshot"]
	fight.enemies[0].stage = PathDef.Stage.VOWED
	assert_eq(fight.validate(_content), ["rift_worn_sentinel at (3, 4) can't take the path Sharpshot"] as Array[String], "enemies take no paths")
	fight = Encounters.setup(_content, "witch_circle", GUARDED, 1, errors)
	fight.heroes[1].stage = PathDef.Stage.TRANSFORMED
	assert_eq(fight.validate(_content), ["maren at (3, 0) is transformed without a path"] as Array[String])
	fight.heroes[1].stage = PathDef.Stage.BASE
	fight.heroes[1].path = _content.paths["sharpshot"]
	assert_eq(fight.validate(_content), ["maren at (3, 0) has the path Sharpshot but no stage"] as Array[String])
	fight = Encounters.setup(_content, "witch_circle", GUARDED, 1, errors)
	fight.heroes[0].deed_paths = [_content.paths["sharpshot"]] as Array[PathDef]
	assert_eq(fight.validate(_content), ["brannoc at (3, 2) can't count Sharpshot's deed"] as Array[String])
	fight = Encounters.setup(_content, "witch_circle", GUARDED, 1, errors)
	fight.enemies[0].deed_paths = [_content.paths["sharpshot"]] as Array[PathDef]
	assert_eq(fight.validate(_content), ["rift_worn_sentinel at (3, 4) can't count Sharpshot's deed"] as Array[String], "enemies count no deeds")
	# Even a hero's kit fighting on the enemies' side (a made-up setup).
	fight = Encounters.setup(_content, "witch_circle", GUARDED, 1, errors)
	var turned: UnitSetup = UnitSetup.make(_content.heroes["maren"].kit, EffectSource.Team.ENEMIES, 1, 6, "turncoat")
	turned.deed_paths = [_content.paths["sharpshot"]] as Array[PathDef]
	fight.enemies.append(turned)
	assert_eq(fight.validate(_content), ["turncoat at (1, 6) can't count Sharpshot's deed"] as Array[String])
	turned.deed_paths.clear()
	turned.path = _content.paths["sharpshot"]
	turned.stage = PathDef.Stage.VOWED
	assert_eq(fight.validate(_content), ["turncoat at (1, 6) can't take the path Sharpshot"] as Array[String])


func test_paths_that_no_one_takes_change_nothing() -> void:
	var plain: ContentDb = ContentDb.load_dir("res://data")
	var errors: Array[String] = []
	var without: FightResult = CombatSim.run(Encounters.setup(plain, "witch_circle", GUARDED, 3, errors), plain)
	var with_paths: FightResult = CombatSim.run(Encounters.setup(_content, "witch_circle", GUARDED, 3, errors), _content)
	assert_eq(errors, [] as Array[String])
	assert_eq(with_paths.combat_log.to_text(), without.combat_log.to_text(), "counting deeds doesn't change the fight")
	assert_eq(without.deeds.size(), 9, "the real data's nine paths: three deeds for each hero")
	assert_eq(with_paths.deeds.size(), 2, "Maren's and Vell's one test path each")
