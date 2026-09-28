extends GutTest
## CLAUDE.md rule 1: same seed, same inputs, same fight, every time
## (docs/plans/rebuild-phase1-arena-sim.md, section 13). The chaos fight
## (chaos_fight.gd) uses every piece of the arena sim, and a test here checks
## it still does.

const K = preload("res://tests/sim/sim_test_kit.gd")
const Chaos = preload("res://tests/sim/chaos_fight.gd")

## The chaos fight, run once for every test here (it takes a couple of
## seconds).
var chaos: FightResult


func before_all() -> void:
	chaos = K.run(Chaos.setup())


func test_the_chaos_fight_repeats_exactly() -> void:
	# Stepped tick by tick this time, rather than run() to the end.
	assert_true(chaos.errors.is_empty(), str(chaos.errors))
	var fight: CombatSim = K.sim(Chaos.setup())
	while not fight.finished:
		fight.step()
	assert_eq(fight.combat_log.to_text(), chaos.combat_log.to_text())
	assert_eq([fight.outcome, fight.tick], [chaos.outcome, chaos.end_tick])


func test_the_seed_matters() -> void:
	assert_ne(K.run(Chaos.setup(22)).combat_log.to_text(), chaos.combat_log.to_text())


func test_the_fight_order_matters() -> void:
	# The same units listed in another order act in another order.
	var reordered: FightSetup = Chaos.setup()
	reordered.heroes.reverse()
	assert_ne(K.run(reordered).combat_log.to_text(), chaos.combat_log.to_text())


## Log kinds the arena sim doesn't make (deeds come in phase 4, duo bonds in
## phase 5).
const NOT_YET: Array[LogEntry.Kind] = [LogEntry.Kind.SYNERGY, LogEntry.Kind.DEED_LEVEL]


func test_the_chaos_fight_uses_everything() -> void:
	var log: CombatLog = chaos.combat_log
	for kind: int in LogEntry.Kind.size():
		if not NOT_YET.has(kind):
			assert_false(log.of_kind(kind).is_empty(), "the log has a %s" % LogEntry.Kind.keys()[kind])
	var statuses: Array = log.of_kind(LogEntry.Kind.STATUS_APPLIED).map(func(entry: LogEntry) -> String: return entry.status)
	for status_id: String in K.content().status_ids:
		assert_true(statuses.has(status_id), "%s is applied" % status_id)
	var shapes: Array = log.of_kind(LogEntry.Kind.AREA_LANDED).map(func(entry: LogEntry) -> String: return entry.shape.get_slice(" ", 0))
	for shape: String in ShapeDef.KIND_NAMES:
		assert_true(shapes.has(shape), "a %s lands" % shape)
	var fired: Array = log.of_kind(LogEntry.Kind.FIRE).map(func(entry: LogEntry) -> String: return entry.source_ability)
	# One signature for each trigger: fight_start, at_time, hp_below, mana
	# (with a cast), count (two), and would_fall (SAVED, above).
	for ability: String in ["pounce", "drag", "hold", "mend", "hush", "rush", "brood", "last_rites", "call", "ember_breath"]:
		assert_true(fired.has(ability), "%s fires" % ability)
	var pushes: Array = log.of_kind(LogEntry.Kind.PUSH).map(func(entry: LogEntry) -> String: return entry.note)
	assert_true(pushes.any(func(note: String) -> bool: return note.begins_with("knocked back,")), "a knockback is stopped (and stuns)")
	assert_true(pushes.any(func(note: String) -> bool: return note.begins_with("pulled")), "a pull")
	assert_true(log.of_kind(LogEntry.Kind.DAMAGE).any(func(entry: LogEntry) -> bool: return entry.crit), "crits roll the seeded RNG")
	var summons: Array = log.of_kind(LogEntry.Kind.SUMMON).map(func(entry: LogEntry) -> String: return entry.source_ability)
	assert_true(summons.has("brood") and summons.has("call"), "summons on hexes and on the edges")
	assert_eq(log.of_kind(LogEntry.Kind.PHASE).map(func(entry: LogEntry) -> String: return entry.note), ["Molt", "Last Ember"])
	assert_eq(log.of_kind(LogEntry.Kind.COLLAPSE_RING)[0].source_text(), "brute · Call the Brood", "the collapse starts early")
	assert_true(log.of_kind(LogEntry.Kind.AURA).any(func(entry: LogEntry) -> bool: return entry.note == "ends"), "an aura's window closes")
	assert_true(log.of_kind(LogEntry.Kind.TARGET).any(func(entry: LogEntry) -> bool: return entry.note == "hook is stealthed"), "an enemy loses its target to Stealth")
	assert_true(log.of_kind(LogEntry.Kind.MOVE).any(func(entry: LogEntry) -> bool: return entry.tick > log.of_kind(LogEntry.Kind.COLLAPSE_RING)[1].tick), "units walk on the crumbling arena")
