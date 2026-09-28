extends GutTest
## FightTally: the fight chart's and the sim runner's numbers, added up from
## the log (docs/plans/rebuild-phase3-fight-sandbox.md, section 6).

const K = preload("res://tests/sim/sim_test_kit.gd")
const Chaos = preload("res://tests/sim/chaos_fight.gd")
const ArenaLog = preload("res://tests/sim/arena/test_arena_log.gd")


func _setup() -> FightSetup:
	var warden: UnitDef = K.kit("warden", {"basic_attack": {"id": "bash", "name": "Bash"},
		"phases": [{"id": "wrath", "name": "Wrath", "below_hp_bp": 5000, "basic_attack": {"id": "maul", "name": "Maul", "cooldown_ms": 1000,
			"effects": [{"type": "damage", "amount": 10, "target": "target"}]}}]})
	var ranger: UnitDef = K.kit("ranger", {"basic_attack": {"id": "shot", "name": "Shot"}})
	return K.fight([K.at(warden, 3, 2), K.at(ranger, 3, 0)] as Array[UnitSetup], [K.foe(K.kit("hound"), 3, 4)] as Array[UnitSetup])


func _entry(kind: LogEntry.Kind, source: String, ability: String, target: String, amount: int, extra: Dictionary = {}) -> LogEntry:
	var entry := LogEntry.new()
	entry.kind = kind
	entry.source_unit = source
	entry.source_ability = ability
	entry.source_ability_name = ability.capitalize()
	entry.target = target
	entry.amount = amount
	for key: String in extra:
		entry.set(key, extra[key])
	return entry


func test_damage_splits_basic_attacks_abilities_and_statuses() -> void:
	var tally: FightTally = FightTally.make(_setup(), {"warden": "The Warden"})
	var D := LogEntry.Kind.DAMAGE
	for entry: LogEntry in [
		_entry(D, "warden", "bash", "hound", 10),
		_entry(D, "warden", "maul", "hound", 12),
		_entry(D, "warden", "bash", "hound", 4, {"from_event": true}),
		_entry(D, "warden", "stand", "hound", 7),
		_entry(LogEntry.Kind.STATUS_DAMAGE, "warden", "stand", "hound", 3, {"status": "bleed", "status_name": "Bleed"}),
		_entry(LogEntry.Kind.STATUS_DAMAGE, "warden", "", "hound", 2, {"status": "burn", "status_name": "Burn"}),
		_entry(LogEntry.Kind.STATUS_DAMAGE, "warden", "stand", "hound", 1, {"status": "rot", "status_name": "Rot"}),
		_entry(D, "warden", "slam", "hound", 0),
		_entry(D, "hound", "bite", "warden", 9),
		_entry(D, "ranger", "shot", "hound", 5)]:
		tally.add(entry)
	var warden: FightTally.Bar = tally.bar(FightTally.Tab.DAMAGE, "warden")
	assert_eq(warden.name, "The Warden")
	assert_eq(warden.by_type, [22, 12, 2, 0, 3], "bash and maul (a phase's) are basic; from an event, a signature, and an unknown status are abilities; nothing hit for 0")
	assert_eq(warden.breakdown(), [["Bash", 14], ["Maul", 12], ["Stand", 7], ["Bleed (Stand)", 3], ["Burn", 2], ["Rot (Stand)", 1]])
	assert_eq(tally.bar(FightTally.Tab.DAMAGE, "ranger").name, "ranger", "ids stand in for missing names")
	assert_null(tally.bar(FightTally.Tab.DAMAGE, "hound"), "enemies get no bar")
	assert_eq(tally.sorted(FightTally.Tab.DAMAGE).map(func(bar: FightTally.Bar) -> String: return bar.id), ["warden", "ranger"])


func test_support_and_damage_taken() -> void:
	var tally: FightTally = FightTally.make(_setup())
	for entry: LogEntry in [
		_entry(LogEntry.Kind.HEAL, "ranger", "mend", "warden", 30),
		_entry(LogEntry.Kind.SHIELD, "ranger", "ward", "warden", 20),
		_entry(LogEntry.Kind.HEAL, "hound", "lick", "hound", 50),
		_entry(LogEntry.Kind.DAMAGE, "hound", "bite", "warden", 9, {"absorbed": 4}),
		_entry(LogEntry.Kind.STATUS_DAMAGE, "hound", "bite", "warden", 2, {"status": "poison", "status_name": "Poison"}),
		_entry(LogEntry.Kind.COLLAPSE, "", LogEntry.COLLAPSE_SOURCE, "warden", 10),
		_entry(LogEntry.Kind.DAMAGE, "hound", "gnaw", "warden", 0),
		_entry(LogEntry.Kind.DAMAGE, "warden", "bash", "hound", 8)]:
		tally.add(entry)
	var support: FightTally.Bar = tally.bar(FightTally.Tab.SUPPORT, "ranger")
	assert_eq([support.by_type, support.breakdown()], [[30, 20], [["Mend", 30], ["Ward", 20]]])
	assert_eq(tally.bar(FightTally.Tab.SUPPORT, "warden").total(), 0)
	var taken: FightTally.Bar = tally.bar(FightTally.Tab.TAKEN, "warden")
	assert_eq(taken.by_type, [17, 4], "to HP, and absorbed by Shield")
	assert_eq(taken.breakdown(), [["Rift Collapse", 10], ["hound: Bite", 9], ["Poison", 2]])
	assert_eq(tally.sorted(FightTally.Tab.TAKEN).map(func(bar: FightTally.Bar) -> String: return bar.id), ["warden", "ranger"])
	assert_eq(tally.sorted(FightTally.Tab.SUPPORT).map(func(bar: FightTally.Bar) -> String: return bar.id), ["ranger", "warden"], "largest first")


func test_every_damage_over_time_status_has_a_family() -> void:
	var content: ContentDb = K.content()
	for status_id: String in content.status_ids:
		if (content.statuses[status_id] as StatusDef).kind == StatusDef.Kind.DAMAGE_OVER_TIME:
			assert_true(FightTally.STATUS_TYPES.has(status_id), "%s needs a family in the chart" % status_id)


## The tally's totals are the log's own sums, in real fights.
func test_a_whole_fight_adds_up() -> void:
	for setup: FightSetup in [Chaos.setup(), ArenaLog.content_setup()]:
		var result: FightResult = K.run(setup)
		var tally: FightTally = FightTally.of_fight(setup, result.combat_log)
		for hero: UnitSetup in setup.heroes:
			var dealt: int = 0
			var given: int = 0
			var taken: int = 0
			var absorbed: int = 0
			for entry: LogEntry in result.combat_log.entries:
				if entry.kind in [LogEntry.Kind.DAMAGE, LogEntry.Kind.STATUS_DAMAGE] and entry.source_unit == hero.id:
					dealt += entry.amount
				if entry.kind in [LogEntry.Kind.HEAL, LogEntry.Kind.SHIELD] and entry.source_unit == hero.id:
					given += entry.amount
				if entry.kind in [LogEntry.Kind.DAMAGE, LogEntry.Kind.STATUS_DAMAGE, LogEntry.Kind.COLLAPSE] and entry.target == hero.id:
					taken += entry.amount
					absorbed += entry.absorbed
			assert_eq(tally.bar(FightTally.Tab.DAMAGE, hero.id).total(), dealt, hero.id)
			assert_eq(tally.bar(FightTally.Tab.SUPPORT, hero.id).total(), given, hero.id)
			assert_eq(tally.bar(FightTally.Tab.TAKEN, hero.id).by_type, [taken - absorbed, absorbed], hero.id)
		var totals: Array = setup.heroes.map(func(hero: UnitSetup) -> int: return tally.bar(FightTally.Tab.DAMAGE, hero.id).by_type[0])
		assert_true(totals.any(func(amount: int) -> bool: return amount > 0), "basic attacks are counted as such")
