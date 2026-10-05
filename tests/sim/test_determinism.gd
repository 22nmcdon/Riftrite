extends GutTest
## CLAUDE.md rule 1: same seed, same inputs, same fight, every time
## (docs/plans/rebuild-phase1-arena-sim.md, section 13). The chaos fight
## (chaos_fight.gd) uses every piece of the arena sim, and a test here checks
## it still does.

const K = preload("res://tests/sim/sim_test_kit.gd")
const Chaos = preload("res://tests/sim/chaos_fight.gd")
const TacticFights = preload("res://tests/sim/test_tactics.gd")
const PathFights = preload("res://tests/sim/path_fights.gd")
const RuleFights = preload("res://tests/sim/test_hero_rules.gd")
const ArenaLogTest = preload("res://tests/sim/arena/test_arena_log.gd")
const IslandsTest = preload("res://tests/sim/test_islands.gd")

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


## Tactics (phase 3b) change fights, so a fight with all three repeats
## exactly too (the chaos fight has none, so its seed keeps every piece).
func test_a_fight_with_tactics_repeats_exactly() -> void:
	var first: FightResult = K.run(TacticFights.tactics_setup())
	assert_eq(K.run(TacticFights.tactics_setup()).combat_log.to_text(), first.combat_log.to_text())
	assert_true(first.combat_log.entries.any(func(entry: LogEntry) -> bool: return entry.kind == LogEntry.Kind.TACTIC))


## The paths (phase 4) change fights, so the paths fights repeat exactly
## too, and between them use the log kinds and status the chaos fight
## leaves to them.
func test_the_paths_fights_repeat_exactly_and_use_the_path_pieces() -> void:
	var content: ContentDb = K.content()
	var kinds: Dictionary[LogEntry.Kind, bool] = {}
	var statuses: Dictionary[String, bool] = {}
	var fights: Array[FightSetup] = PathFights.all(content)
	var again: Array[FightSetup] = PathFights.all(content)
	for i: int in fights.size():
		var first: FightResult = CombatSim.run(fights[i], content)
		assert_eq(first.errors, [] as Array[String])
		assert_eq(CombatSim.run(again[i], content).combat_log.to_text(), first.combat_log.to_text(), "paths fight %d repeats" % i)
		for entry: LogEntry in first.combat_log.entries:
			kinds[entry.kind] = true
			if entry.kind == LogEntry.Kind.STATUS_APPLIED:
				statuses[entry.status] = true
	for kind: LogEntry.Kind in [LogEntry.Kind.ZONE, LogEntry.Kind.SNARE, LogEntry.Kind.WALL, LogEntry.Kind.GUARD, LogEntry.Kind.SAVED]:
		assert_true(kinds.has(kind), "a paths fight has a %s" % LogEntry.Kind.keys()[kind])
	for status_id: String in PATH_STATUSES:
		assert_true(statuses.has(status_id), "a paths fight applies %s" % status_id)


## The heroes' rules (phase 5c step 5c) change fights, so the rules fight
## repeats exactly too, and has the log kinds and statuses the chaos fight
## leaves to it (a rise and a block; The Unbending's and The Long Watch's
## stacks).
func test_the_rules_fight_repeats_exactly() -> void:
	var first: FightResult = K.run(RuleFights.rules_setup())
	assert_eq(K.run(RuleFights.rules_setup()).combat_log.to_text(), first.combat_log.to_text())
	for kind: LogEntry.Kind in [LogEntry.Kind.RISE, LogEntry.Kind.RESISTED]:
		assert_false(first.combat_log.of_kind(kind).is_empty(), "the rules fight has a %s" % LogEntry.Kind.keys()[kind])
	var statuses: Array = first.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).map(func(entry: LogEntry) -> String: return entry.status)
	for status_id: String in RULE_STATUSES:
		assert_true(statuses.has(status_id), "the rules fight applies %s" % status_id)


## Shallow water (phase 8 part 3) repeats exactly too, and changes the fight.
func test_a_fight_on_water_repeats_exactly() -> void:
	var first: FightResult = K.run(ArenaLogTest.water_setup())
	assert_eq(K.run(ArenaLogTest.water_setup()).combat_log.to_text(), first.combat_log.to_text())
	assert_ne(first.combat_log.to_text(), K.run(ArenaLogTest.busy_setup()).combat_log.to_text(), "the water changes the fight")


## So does a fight with void (phase 8 part 3), and the void changes it.
func test_a_fight_with_void_repeats_exactly() -> void:
	var first: FightResult = K.run(IslandsTest.void_setup())
	assert_eq(K.run(IslandsTest.void_setup()).combat_log.to_text(), first.combat_log.to_text())
	var flat: FightSetup = IslandsTest.void_setup()
	flat.void_hexes.clear()
	assert_ne(first.combat_log.to_text(), K.run(flat).combat_log.to_text(), "the void changes the fight")


func test_the_seed_matters() -> void:
	assert_ne(K.run(Chaos.setup(22)).combat_log.to_text(), chaos.combat_log.to_text())


func test_the_fight_order_matters() -> void:
	# The same units listed in another order act in another order.
	var reordered: FightSetup = Chaos.setup()
	reordered.heroes.reverse()
	assert_ne(K.run(reordered).combat_log.to_text(), chaos.combat_log.to_text())


## Log kinds the chaos fight doesn't make: the arena sim doesn't yet (duo
## bonds in phase 5; deeds count without logging), or another fight covers
## them (TACTIC: test_a_fight_with_tactics_repeats_exactly, since tactics
## would change the chaos fight's seed; phase 4's path pieces: the paths
## fight, once the paths are data).
## The heroes' rules (RISE, RESISTED): the rules fight. A charm's miss
## (DODGED, phase 5c step 6b): tests/sim/test_loadout_pieces.gd. A gambit's
## arrival (ARRIVE, step 6d): tests/sim/test_gambits.gd. Water changing
## (WATER, phase 8 part 3): tests/sim/test_water.gd. A fall into the void
## (FELL, phase 8 part 3) and bridges breaking (VOID): tests/sim/test_islands.gd.
## A copied signature (COPIED): tests/sim/test_copies.gd.
const NOT_YET: Array[LogEntry.Kind] = [LogEntry.Kind.SYNERGY, LogEntry.Kind.DEED_LEVEL, LogEntry.Kind.TACTIC,
	LogEntry.Kind.ZONE, LogEntry.Kind.SNARE, LogEntry.Kind.WALL, LogEntry.Kind.GUARD, LogEntry.Kind.RISE, LogEntry.Kind.RESISTED,
	LogEntry.Kind.DODGED, LogEntry.Kind.ARRIVE, LogEntry.Kind.SHARED, LogEntry.Kind.WALL_HIT, LogEntry.Kind.MAX_HP_UP, LogEntry.Kind.WATER, LogEntry.Kind.FELL, LogEntry.Kind.VOID, LogEntry.Kind.COPIED]
## Statuses only the paths use (phase 4), and only relics (phase 5c step 5a;
## Sunder, covered by tests/run/test_relics.gd).
const PATH_STATUSES: Array[String] = ["warded"]
const RELIC_STATUSES: Array[String] = ["sunder", "quickened", "unbending", "long_watch"]
## Boosts only loadout items apply (phase 5c step 6; tests/run/test_loadout.gd).
const ITEM_STATUSES: Array[String] = ["surge", "surge_2", "last_breath", "purified",
	"grounded", "shadow_step", "shadow_step_2", "shadow_step_3", "bloodhound", "scavenged", "watched_over",
	"ambush", "ambush_2", "rear_guard", "late_surge"]
## Statuses only upgrades apply (phase 5c step 7; tests/run/test_upgrade_pools.gd).
const UPGRADE_STATUSES: Array[String] = ["hobbled", "cowed", "parting_shot", "first_blood", "scarred"]
## Statuses only rift modifiers apply (phase 5c step 8b; tests/run/test_rift_tear.gd),
## and enemy upgrades and specializations (phase 8 part 3, 8c-5a and 8c-5c;
## tests/sim/test_enemy_growth_pieces.gd).
const RIFT_STATUSES: Array[String] = ["blood_frenzy", "vengeance", "ember_blind", "festering"]
## Statuses only apexes apply (phase 8 part 2; tests/sim/test_apex_kits.gd).
## The apex cards' are with them (phase 8 part 2, 8b-4; tests/run/test_apex_cards.gd).
const APEX_STATUSES: Array[String] = ["hailstorm", "tailwind", "zeal", "morning_haste", "dawnlight", "first_light", "glare", "dazzled", "woven_thorns", "iron_loom", "briar_torn", "gatekeeper", "brand", "war_call", "rally", "oathbound",
	"gale", "first_light_more", "zeal_more", "shield_wall", "dawn_ward"]
## The statuses the heroes' rules apply (phase 5c step 5c).
const RULE_STATUSES: Array[String] = ["unbending", "long_watch"]


func test_the_chaos_fight_uses_everything() -> void:
	var log: CombatLog = chaos.combat_log
	for kind: int in LogEntry.Kind.size():
		if not NOT_YET.has(kind):
			assert_false(log.of_kind(kind).is_empty(), "the log has a %s" % LogEntry.Kind.keys()[kind])
	var statuses: Array = log.of_kind(LogEntry.Kind.STATUS_APPLIED).map(func(entry: LogEntry) -> String: return entry.status)
	for status_id: String in K.content().status_ids:
		assert_true(statuses.has(status_id) or PATH_STATUSES.has(status_id) or RELIC_STATUSES.has(status_id) or ITEM_STATUSES.has(status_id) or UPGRADE_STATUSES.has(status_id) or RIFT_STATUSES.has(status_id) \
			or APEX_STATUSES.has(status_id), "%s is applied" % status_id)
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
	# Phase 5c step 3: each new trigger, a keyword filter, a vs aura, a state
	# aura, and a chain more than one link deep.
	var passive_sources: Array = log.entries.filter(func(entry: LogEntry) -> bool: return entry.from_event).map(func(entry: LogEntry) -> String: return entry.source_ability)
	for part: String in ["kindle", "coven", "spite"]:
		assert_true(passive_sources.has(part), "%s answers its trigger" % part)
	var auras: Array = log.of_kind(LogEntry.Kind.AURA).map(func(entry: LogEntry) -> String: return entry.source_ability)
	assert_true(auras.has("hunt") and auras.has("shade"), "a vs aura and a state aura start")
	assert_true(log.of_kind(LogEntry.Kind.AURA).any(func(entry: LogEntry) -> bool: return entry.source_ability == "shade" and entry.note == "ends"), "the state aura ends with the Stealth")
	assert_true(log.entries.any(func(entry: LogEntry) -> bool: return entry.chain >= 2), "a chain two links deep")
	# Phase 5c step 5b: the pieces relics share.
	assert_true(log.of_kind(LogEntry.Kind.SHIELD).any(func(entry: LogEntry) -> bool: return entry.tick == 0 and entry.source_ability == "tithe"), "a relic's Shield as the fight starts")
	assert_eq(log.of_kind(LogEntry.Kind.AREA_LANDED).filter(func(entry: LogEntry) -> bool: return entry.note == "broken by Salt Circle").size(), 1, "Salt Circle breaks one area")
	assert_true(passive_sources.has("pyre") and passive_sources.has("veil") and passive_sources.has("toll"), "on_kill's Burn spreads, a status ending, a signature's boost")
	assert_true(passive_sources.has("anvil"), "a knockback Roots (phase 5c step 5d)")
	assert_true(log.of_kind(LogEntry.Kind.DAMAGE).any(func(entry: LogEntry) -> bool: return entry.overkill > 0), "a hit's overkill")
	# Phase 5c step 5c: the engines.
	var applied: Array[LogEntry] = log.of_kind(LogEntry.Kind.STATUS_APPLIED)
	assert_true(applied.any(func(entry: LogEntry) -> bool: return entry.status == "frenzy" and entry.stacks >= 2), "a stacking boost, two stacks at once")
	assert_true(applied.any(func(entry: LogEntry) -> bool: return entry.status == "marked" and entry.stacks >= 2), "the heroes' Marks stack")
	assert_true(auras.has("bulwark") and auras.has("still"), "an aura per Shield, and a planted one")
