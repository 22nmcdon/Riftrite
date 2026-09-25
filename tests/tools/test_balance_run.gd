extends GutTest
## The headless balance runner: party parsing, running, and the report.

const K = preload("res://tests/sim/sim_test_kit.gd")


func test_sim_parties_file_is_valid() -> void:
	var parties: BalanceRun.Parties = BalanceRun.load_parties(K.content())
	assert_eq(parties.errors, [] as Array[String])
	assert_eq(parties.list.size(), 6)


func test_every_party_runs_against_every_encounter() -> void:
	var db: ContentDb = K.content()
	for party: BalanceRun.Party in BalanceRun.load_parties(db).list:
		for encounter_id: String in db.encounter_ids:
			var stats: BalanceRun.Stats = BalanceRun.run(db, party, encounter_id, 2, 1)
			assert_eq(stats.errors, [] as Array[String], "%s vs %s" % [party.id, encounter_id])
			assert_eq(stats.wins + stats.ties + stats.losses, 2)


func test_report_lines() -> void:
	var db: ContentDb = K.content()
	var stats: BalanceRun.Stats = BalanceRun.run(db, BalanceRun.load_parties(db).list[0], "hound_pack", 3, 5)
	var lines: PackedStringArray = BalanceRun.report(stats)
	assert_eq(lines[0], "== hearth_starter vs hound_pack (3 fights, seeds 5-7) ==")
	assert_true(lines[1].begins_with("Guild wins: "), lines[1])
	assert_true(Array(lines).any(func(line: String) -> bool: return line.contains("wren · First-Light Dagger")))
	assert_true(Array(lines).has("Synergy: Warden's Oath: brannoc · Oak Buckler (100% of fights)"), "\n".join(lines))


func test_party_errors() -> void:
	var data: Array = [
		{"id": "bad", "name": "Bad", "heroes": [
			{"hero": "nobody"},
			{"hero": "wren", "items": [{"item": "rift_claw"}, {"item": "hearth_knife", "tier": "z"}]},
		]},
	]
	var errors: Array[String] = BalanceRun.parse_parties(K.content(), data, "parties").errors
	for expected: String in ["unknown hero \"nobody\"", "\"rift_claw\" is enemy-only", "tier: unknown value \"z\""]:
		assert_true(errors.any(func(e: String) -> bool: return e.contains(expected)), "%s in %s" % [expected, errors])


func test_party_relics() -> void:
	var data: Array = [
		{"id": "relicky", "name": "Relicky", "relics": ["gloam_totem", "nope"], "heroes": [{"hero": "wren"}]},
	]
	var errors: Array[String] = BalanceRun.parse_parties(K.content(), data, "parties").errors
	for expected: String in ["\"gloam_totem\" is enemy-only", "unknown relic \"nope\""]:
		assert_true(errors.any(func(e: String) -> bool: return e.contains(expected)), "%s in %s" % [expected, errors])


func test_report_credits_relics_and_grants() -> void:
	var db: ContentDb = K.content()
	var party: BalanceRun.Party = null
	for candidate: BalanceRun.Party in BalanceRun.load_parties(db).list:
		if candidate.id == "hearth_relics":
			party = candidate
	assert_not_null(party)
	var lines: PackedStringArray = BalanceRun.report(BalanceRun.run(db, party, "hound_pack", 3, 1))
	assert_true(Array(lines).any(func(line: String) -> bool: return line.contains("brannoc · Rusted Cleaver (Cinder Crown)")), "\n".join(lines))
