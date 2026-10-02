extends GutTest
## The heroes' rules (docs/plans/rebuild-phase5c-combos.md, step 5c, section
## 12.2; SideRules), each in a small fight and each shown changing nothing
## without its rule: Crown of Stars, Shared Pain, The Hungering Rift,
## Overcharge, Second Dawn, Chain of Echoes, Crown of the Hollow King,
## Everflame, The Unbending, Riftwalker's Soles, and The Long Watch. And the
## rules fight: the real heroes against Old Mother Ash with every rule on,
## for the determinism tests and the log audit (it rises, and resists).

const K = preload("res://tests/sim/sim_test_kit.gd")

## Every rule, with the relics' numbers (The Long Watch's sooner, so a short
## fight sees it).
const ALL_RULES: Dictionary = {"marks_stack": true, "crit_chain": {"steps": 10, "fade_bp": 500}, "echo_keywords": {"share_bp": 9000, "steps": 3},
	"carry_overkill": {"steps": 8}, "overcharge": {"power_bp": 2500, "steps": 8}, "second_dawn": {"after_ms": 3000, "hp_bp": 5000},
	"deeper_chains": {"steps": 4, "grow_bp": 1500}, "keywords_twice": true, "keywords_last": true, "unbending": {"def_bp": 100, "max_hp_bp": 100},
	"collapse": {"immune": true, "enemy_max_hp_bp": 500}, "long_watch": {"from_ms": 4000, "every_ms": 2000, "tie_ms": 300000}}


## The rules fight: the three heroes at three tenths of their max HP against
## Old Mother Ash with every rule on (seed 6: a hero falls and rises, and
## The Unbending blocks a status; a fifth until phase 6 made her stronger).
static func rules_setup(fight_seed: int = 6) -> FightSetup:
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}
	var setup: FightSetup = Encounters.setup(K.content(), "old_mother_ash", formation, fight_seed, errors)
	setup.hero_rules = rules(ALL_RULES)
	for hero: UnitSetup in setup.heroes:
		hero.max_hp_bp = 3000
	return setup


static func rules(data: Dictionary) -> SideRules:
	var errors: Array[String] = []
	return SideRules.read(DataReader.new(data, "rules", errors))


func _hero(passives: Array = [], attack: Dictionary = {}, stats: Dictionary = {}, hero_id: String = "hero", extra: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 1000, "atk": 10, "speed": 0, "range": 2}
	all_stats.merge(stats, true)
	var basic: Dictionary = {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}
	basic.merge(attack, true)
	var kit: Dictionary = {"stats": all_stats, "basic_attack": basic, "passives": passives}
	kit.merge(extra, true)
	return K.kit(hero_id, kit)


func _dummy(dummy_id: String = "dummy", hp: int = 100000, attack: Dictionary = {}) -> UnitDef:
	var basic: Dictionary = {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}
	basic.merge(attack, true)
	return K.kit(dummy_id, {"stats": {"hp": hp, "speed": 0, "range": 2}, "basic_attack": basic})


func _fight(heroes: Array[UnitSetup], enemies: Array[UnitSetup], data: Dictionary = {}) -> CombatSim:
	var setup: FightSetup = K.fight(heroes, enemies)
	setup.hero_rules = rules(data)
	return K.sim(setup)


func _duel(hero: UnitDef, data: Dictionary = {}, enemy: UnitDef = null) -> CombatSim:
	return _fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(enemy if enemy != null else _dummy(), 3, 4)] as Array[UnitSetup], data)


func _from(unit_id: String) -> EffectSource:
	return EffectSource.make(unit_id, unit_id + "_attack", "Strike")


func _noted(fight: CombatSim, note: String) -> Array[LogEntry]:
	return K.entries(fight, LogEntry.Kind.DAMAGE).filter(func(entry: LogEntry) -> bool: return entry.note == note)


# --- reading ---------------------------------------------------------------------------

func test_reading_and_merging_rules() -> void:
	var errors: Array[String] = []
	var all: SideRules = SideRules.read(DataReader.new(ALL_RULES, "rules", errors))
	assert_eq(errors, [] as Array[String])
	assert_true(all.any())
	assert_eq([all.crit_steps, all.echo_steps, all.carry_steps, all.overcharge_steps, all.rise_ticks, all.deeper_steps, all.watch_tie_ticks], [10, 3, 8, 8, 60, 4, 6000])
	var merged: SideRules = rules({"keywords_twice": true}).merged(rules({"carry_overkill": {"steps": 2}}))
	assert_true(merged.keywords_twice and merged.carry_steps == 2)
	assert_false(SideRules.new().any())
	assert_eq([all.growth_bp(0), all.growth_bp(1), all.growth_bp(2)], [10000, 11500, 13225], "x1.15 a step, compounded")
	for bad: Dictionary in [{"crit_chain": {"steps": 10}}, {"unknown": true}, {"second_dawn": {"after_ms": 1000}}]:
		var bad_errors: Array[String] = []
		SideRules.read(DataReader.new(bad, "rules", bad_errors))
		assert_false(bad_errors.is_empty(), "refused: %s" % bad)


# --- Crown of Stars --------------------------------------------------------------------

func test_a_crit_rolls_again_and_fades() -> void:
	var data: Dictionary = {"crit_chain": {"steps": 10, "fade_bp": 500}}
	var sure: CombatSim = _duel(_hero([], {}, {"crit": 300}), data)
	EffectRunner.deal_hit(sure, _from("hero"), sure.unit_by_id("dummy"), 10, true)
	var hit: LogEntry = K.entries(sure, LogEntry.Kind.DAMAGE)[0]
	assert_eq(hit.crits, 11, "a 300% chance never misses, up to 10 more")
	assert_eq(hit.amount, DamageRule.apply(10, 0, 5000 + FixedMath.apply_bp(5000, 72500)), "the crit bonus x(95% + 90% + ... + 50%) more")
	assert_string_contains(hit.to_text(), "crit x11")
	var plain: CombatSim = _duel(_hero([], {}, {"crit": 300}))
	EffectRunner.deal_hit(plain, _from("hero"), plain.unit_by_id("dummy"), 10, true)
	assert_eq([K.entries(plain, LogEntry.Kind.DAMAGE)[0].crits, K.entries(plain, LogEntry.Kind.DAMAGE)[0].amount], [1, 15], "without it, one crit")
	var low: CombatSim = _duel(_hero([], {}, {"crit": 0}), data)
	EffectRunner.deal_hit(low, _from("hero"), low.unit_by_id("dummy"), 10, true)
	assert_eq(K.entries(low, LogEntry.Kind.DAMAGE)[0].crits, 1, "no chance, no more crits")


# --- Shared Pain -------------------------------------------------------------------------

func test_damage_echoes_through_the_most_shared_keyword() -> void:
	var data: Dictionary = {"echo_keywords": {"share_bp": 9000, "steps": 3}}
	var fight: CombatSim = _fight([K.at(_hero(), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy("a"), 3, 4, "a"), K.foe(_dummy("b"), 2, 5, "b"), K.foe(_dummy("c"), 4, 5, "c"), K.foe(_dummy("d"), 5, 6, "d")] as Array[UnitSetup], data)
	for id: String in ["a", "b", "c"]:
		Statuses.apply(fight, fight.unit_by_id(id), "marked", 0, 2000, _from("dummy"))
	for id: String in ["a", "d"]:
		Statuses.apply(fight, fight.unit_by_id(id), "root", 0, 2000, _from("dummy"))
	EffectRunner.deal_hit(fight, _from("hero"), fight.unit_by_id("a"), 100, false)
	var echoes: Array[LogEntry] = _noted(fight, "Shared Pain")
	var marked: int = DamageRule.apply(100, 0, 0, 1500)
	assert_eq(echoes.map(func(entry: LogEntry) -> Array: return [entry.target, entry.amount, entry.chain]), [
		["b", DamageRule.apply(FixedMath.apply_bp(marked, 9000), 0, 0, 1500), 1], ["c", DamageRule.apply(FixedMath.apply_bp(marked, 9000), 0, 0, 1500), 1],
		["a", DamageRule.apply(FixedMath.apply_bp(marked, 8100), 0, 0, 1500), 2], ["b", DamageRule.apply(FixedMath.apply_bp(marked, 8100), 0, 0, 1500), 2],
		["c", DamageRule.apply(FixedMath.apply_bp(marked, 8100), 0, 0, 1500), 2],
		["a", DamageRule.apply(FixedMath.apply_bp(marked, 7290), 0, 0, 1500), 3], ["b", DamageRule.apply(FixedMath.apply_bp(marked, 7290), 0, 0, 1500), 3],
		["c", DamageRule.apply(FixedMath.apply_bp(marked, 7290), 0, 0, 1500), 3]],
		"Marked (shared by 2) over Rooted (by 1): 90%, 81%, 73% of the hit, each Marked enemy once a step, never d")
	var plain: CombatSim = _fight([K.at(_hero(), 3, 2)] as Array[UnitSetup], [K.foe(_dummy("a"), 3, 4, "a"), K.foe(_dummy("b"), 2, 5, "b")] as Array[UnitSetup])
	for id: String in ["a", "b"]:
		Statuses.apply(plain, plain.unit_by_id(id), "marked", 0, 2000, _from("dummy"))
	EffectRunner.deal_hit(plain, _from("hero"), plain.unit_by_id("a"), 100, false)
	assert_eq(K.entries(plain, LogEntry.Kind.DAMAGE).size(), 1, "without it, no echo")


# --- The Hungering Rift ------------------------------------------------------------------

func test_overkill_carries_to_the_nearest_until_it_runs_out() -> void:
	var fight: CombatSim = _fight([K.at(_hero(), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy("a", 10), 3, 4, "a"), K.foe(_dummy("b", 30), 3, 5, "b"), K.foe(_dummy("c", 1000), 3, 6, "c"), K.foe(_dummy("far", 1000), 7, 6, "far")] as Array[UnitSetup],
		{"carry_overkill": {"steps": 8}})
	EffectRunner.deal_hit(fight, _from("hero"), fight.unit_by_id("a"), 100, false)
	assert_eq(_noted(fight, "carried (The Hungering Rift)").map(func(entry: LogEntry) -> Array: return [entry.target, entry.amount]), [["b", 90], ["c", 60]],
		"90 past a's 10 HP, then 60 past b's 30")
	assert_eq(fight.unit_by_id("far").hp, 1000, "it ran out at c")


# --- Overcharge --------------------------------------------------------------------------

func _caster() -> UnitDef:
	return _hero([], {}, {}, "hero", {"mana": {"max": 10, "regen_per_s": 0},
		"signature": {"id": "bolt", "name": "Bolt", "trigger": {"kind": "mana"}, "targeting": "nearest", "max_range": 6,
			"effects": [{"type": "damage", "amount": 100, "target": "target"}]}})


func test_overcharge_stores_mana_and_fires_again_stronger() -> void:
	var fight: CombatSim = _duel(_caster(), {"overcharge": {"power_bp": 2500, "steps": 8}})
	var hero: UnitState = fight.unit_by_id("hero")
	Mana.gain(fight, hero, 35 * Mana.SCALE)
	assert_eq(hero.mana, 35 * Mana.SCALE, "mana keeps filling past a full bar")
	fight.step()
	var fires: Array[LogEntry] = K.entries(fight, LogEntry.Kind.FIRE, "hero").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "bolt")
	assert_eq(fires.map(func(entry: LogEntry) -> String: return entry.note), ["", "Overcharge 1", "Overcharge 2"], "three full bars: three fires")
	assert_eq(hero.mana, 5 * Mana.SCALE, "what's left of a bar stays")
	K.step(fight, 5)
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "hero").map(func(entry: LogEntry) -> int: return entry.amount), [100, 125, 150], "+25% power each time")
	var plain: CombatSim = _duel(_caster())
	Mana.gain(plain, plain.unit_by_id("hero"), 35 * Mana.SCALE)
	assert_eq(plain.unit_by_id("hero").mana, 10 * Mana.SCALE, "without it, a bar stops full")


# --- Second Dawn -------------------------------------------------------------------------

func test_a_hero_rises_once_and_every_hero_down_is_still_a_defeat() -> void:
	var data: Dictionary = {"second_dawn": {"after_ms": 1000, "hp_bp": 5000}}
	var fight: CombatSim = _fight([K.at(_hero([], {}, {}, "hero"), 3, 2), K.at(_hero([], {}, {}, "friend"), 1, 2, "friend")] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 4)] as Array[UnitSetup], data)
	var hero: UnitState = fight.unit_by_id("hero")
	EffectRunner.deal_hit(fight, _from("dummy"), hero, 5000, false)
	fight.step()
	assert_false(hero.alive)
	K.step(fight, 19)
	assert_false(hero.alive, "not yet: 1s")
	fight.step()
	assert_true(hero.alive, "it rises")
	assert_eq(hero.hp, 500, "at half its max HP")
	var rise: LogEntry = K.entries(fight, LogEntry.Kind.RISE)[0]
	assert_eq([rise.target, rise.source_ability_name, rise.amount], ["hero", "Second Dawn", 500])
	EffectRunner.deal_hit(fight, _from("dummy"), hero, 5000, false)
	K.step(fight, 40)
	assert_false(hero.alive, "only the first fall rises")
	assert_eq(K.entries(fight, LogEntry.Kind.RISE).size(), 1)
	assert_eq(CombatSim.result_of(fight).down_at_end(), ["hero"] as Array[String])
	var both: CombatSim = _fight([K.at(_hero([], {}, {}, "hero"), 3, 2), K.at(_hero([], {}, {}, "friend"), 1, 2, "friend")] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 4)] as Array[UnitSetup], data)
	EffectRunner.deal_hit(both, _from("dummy"), both.unit_by_id("hero"), 5000, false)
	EffectRunner.deal_hit(both, _from("dummy"), both.unit_by_id("friend"), 5000, false)
	both.step()
	assert_true(both.finished)
	assert_eq(both.outcome, FightResult.Outcome.DEFEAT, "every hero down at once, rises waiting or not")


func test_a_hero_who_rose_and_stands_isnt_down_at_the_end() -> void:
	var fight: CombatSim = _fight([K.at(_hero([], {}, {}, "hero"), 3, 2), K.at(_hero([], {}, {}, "friend"), 1, 2, "friend")] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 4)] as Array[UnitSetup], {"second_dawn": {"after_ms": 1000, "hp_bp": 5000}})
	EffectRunner.deal_hit(fight, _from("dummy"), fight.unit_by_id("hero"), 5000, false)
	K.step(fight, 25)
	assert_eq(CombatSim.result_of(fight).down_at_end(), [] as Array[String], "risen: no wound (Decision 23)")


# --- Chain of Echoes ---------------------------------------------------------------------

func test_chain_of_echoes_goes_deeper_and_grows() -> void:
	var data: Dictionary = {"deeper_chains": {"steps": 4, "grow_bp": 1500}}
	var fight: CombatSim = _duel(_hero([{"id": "echo", "name": "Echo", "kind": "ability",
		"effects": [{"trigger": "on_basic_attack", "type": "damage", "amount": 100, "target": "target"}]}], {"cooldown_ms": 50}), data)
	assert_eq([fight.chain_limit_of("hero", -1), fight.chain_limit_of("dummy", -1)], [12, 8], "the heroes' chains 4 deeper; the enemies' as they were")
	K.step(fight, 1)
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "hero").map(func(entry: LogEntry) -> int: return entry.amount), [10, 115], "an event effect one step deep: x1.15")
	var crowned: CombatSim = _duel(_hero([], {}, {"crit": 300}), {"crit_chain": {"steps": 10, "fade_bp": 500}, "deeper_chains": {"steps": 4, "grow_bp": 1500}})
	EffectRunner.deal_hit(crowned, _from("hero"), crowned.unit_by_id("dummy"), 10, true)
	assert_eq(K.entries(crowned, LogEntry.Kind.DAMAGE)[0].crits, 15, "Crown of Stars 4 steps deeper, growing instead of fading")


# --- keywords: twice, and lasting ----------------------------------------------------------

func test_keywords_heroes_apply_go_on_twice() -> void:
	var fight: CombatSim = _duel(_hero(), {"keywords_twice": true})
	var dummy: UnitState = fight.unit_by_id("dummy")
	Statuses.apply(fight, dummy, "burn", 3, 0, _from("hero"))
	Statuses.apply(fight, dummy, "marked", 0, 0, _from("hero"))
	Statuses.apply(fight, dummy, "slow", 0, 0, _from("hero"))
	assert_eq(Statuses.stacks_on(dummy, "burn"), 6, "double stacks")
	assert_eq(Statuses.find(dummy, "marked").ends_at, 2 * K.content().statuses["marked"].duration_ticks, "double duration")
	assert_eq(Statuses.find(dummy, "slow").ends_at, K.content().statuses["slow"].duration_ticks, "Slow has no keyword")
	var hero: UnitState = fight.unit_by_id("hero")
	Statuses.apply(fight, hero, "burn", 3, 0, _from("dummy"))
	assert_eq(Statuses.stacks_on(hero, "burn"), 3, "an enemy's keywords aren't doubled")


func test_keywords_heroes_put_on_enemies_never_end() -> void:
	var fight: CombatSim = _duel(_hero(), {"keywords_last": true})
	var dummy: UnitState = fight.unit_by_id("dummy")
	var hero: UnitState = fight.unit_by_id("hero")
	Statuses.apply(fight, dummy, "marked", 0, 20, _from("hero"))
	Statuses.apply(fight, dummy, "burn", 20, 0, _from("hero"))
	Statuses.apply(fight, hero, "stealth", 0, 20, _from("hero"))
	K.step(fight, 100)
	assert_not_null(Statuses.find(dummy, "marked"), "the Mark never runs out")
	assert_eq(Statuses.stacks_on(dummy, "burn"), 20, "Burn never fades")
	Statuses.cleanse_over_time(fight, dummy, FixedMath.BP_ONE, _from("dummy"))
	assert_eq(Statuses.stacks_on(dummy, "burn"), 20, "and the enemies can't cleanse it")
	assert_null(Statuses.find(hero, "stealth"), "Stealth on a hero still ends (Decision 24)")
	var plain: CombatSim = _duel(_hero())
	Statuses.apply(plain, plain.unit_by_id("dummy"), "marked", 0, 20, _from("hero"))
	K.step(plain, 21)
	assert_null(Statuses.find(plain.unit_by_id("dummy"), "marked"), "without it, a Mark runs out")


# --- The Unbending -------------------------------------------------------------------------

func test_the_unbending_blocks_enemy_statuses_and_hardens() -> void:
	var fight: CombatSim = _duel(_hero([], {}, {"def": 100}), {"unbending": {"def_bp": 100, "max_hp_bp": 100}})
	var hero: UnitState = fight.unit_by_id("hero")
	hero.hp = 900
	Statuses.apply(fight, hero, "stun", 0, 0, _from("dummy"))
	Statuses.apply(fight, hero, "burn", 5, 0, _from("dummy"))
	assert_null(Statuses.find(hero, "stun"), "no Stun")
	assert_null(Statuses.find(hero, "burn"), "no damage over time")
	var resisted: Array[LogEntry] = K.entries(fight, LogEntry.Kind.RESISTED)
	assert_eq(resisted.map(func(entry: LogEntry) -> String: return entry.status), ["stun", "burn"])
	assert_eq([resisted[0].source_unit, resisted[0].target], ["dummy", "hero"])
	assert_eq(Statuses.stacks_on(hero, "unbending"), 2)
	assert_eq([hero.max_hp, hero.hp, hero.stats.get_stat(UnitStats.Stat.DEF)], [1020, 920, 102], "+1% max HP (and HP with it) and +1% DEF a block")
	Statuses.apply(fight, hero, "marked", 0, 0, _from("hero"))
	assert_not_null(Statuses.find(hero, "marked"), "a hero's own statuses still land")


# --- Riftwalker's Soles, and The Long Watch -------------------------------------------------

func test_crumbled_ground_spares_heroes_and_bites_enemies() -> void:
	var fight: CombatSim = _duel(_hero(), {"collapse": {"immune": true, "enemy_max_hp_bp": 500}})
	fight.safe = Rect2i(0, 0, 10, 10)
	Collapse._damage(fight, 15)
	var lines: Array[LogEntry] = K.entries(fight, LogEntry.Kind.COLLAPSE)
	assert_eq(lines.map(func(entry: LogEntry) -> Array: return [entry.target, entry.amount, entry.note]), [["dummy", 15 + 5000, "Riftwalker's Soles"]],
		"no hero line; 5% of 100000 more on the enemy")
	var plain: CombatSim = _duel(_hero())
	plain.safe = Rect2i(0, 0, 10, 10)
	Collapse._damage(plain, 15)
	assert_eq(K.entries(plain, LogEntry.Kind.COLLAPSE).size(), 2, "without it, both take it")


func test_the_long_watch_grows_heroes_and_moves_the_tie() -> void:
	var fight: CombatSim = _duel(_hero([], {}, {"atk": 100}), {"long_watch": {"from_ms": 2000, "every_ms": 1000, "tie_ms": 9000}})
	var hero: UnitState = fight.unit_by_id("hero")
	K.step(fight, 40)
	assert_eq(Statuses.stacks_on(hero, "long_watch"), 1, "from 2s")
	K.step(fight, 20)
	assert_eq(Statuses.stacks_on(hero, "long_watch"), 2, "every 1s after")
	assert_eq(hero.stats.get_stat(UnitStats.Stat.ATK), 120)
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED)[0].source_ability_name, "The Long Watch")
	while not fight.finished:
		fight.step()
	assert_eq([fight.outcome, fight.tick], [FightResult.Outcome.TIE, 180], "the tie at its own limit")


# --- the rules fight -----------------------------------------------------------------------

func test_the_rules_fight_uses_the_rules() -> void:
	var result: FightResult = K.run(rules_setup())
	assert_eq(result.errors, [] as Array[String])
	var kinds: Array = result.combat_log.entries.map(func(entry: LogEntry) -> LogEntry.Kind: return entry.kind)
	assert_true(kinds.has(LogEntry.Kind.RISE) and kinds.has(LogEntry.Kind.RESISTED), "a rise, and a block")
	var statuses: Array = result.combat_log.entries.filter(func(entry: LogEntry) -> bool: return entry.kind == LogEntry.Kind.STATUS_APPLIED).map(
		func(entry: LogEntry) -> String: return entry.status)
	assert_true(statuses.has("unbending") and statuses.has("long_watch"))
	assert_true(result.combat_log.entries.any(func(entry: LogEntry) -> bool: return entry.note == "carried (The Hungering Rift)"))
