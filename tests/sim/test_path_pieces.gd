extends GutTest
## The sim pieces phase 4's paths need (docs/plans/rebuild-phase4-paths.md,
## section 5), one rule at a time: an ability's own "every", the targets
## near the target and lowest_hp_ally, gain_mana and far-shot mana, heals
## and hits worth a share of the hit, overheal that comes back as Shield,
## per-side effects in an area, zones, conditional auras (planted,
## below_hp, per fallen ally), the range and healing_taken auras, the plant
## delay, firing on the move, Unyielding (on_would_fall), and Warded.
## The board runs in the plan's terms: heroes in rows 0-2, enemies in rows
## 4-6, a row a hex (1000) apart.

const K = preload("res://tests/sim/sim_test_kit.gd")


## A unit that stands still: speed 0, lots of HP, no DEF, and an attack
## that's `effects` every `cooldown_ms` (melee-landing unless `shot`).
static func still(unit_id: String, effects: Array = [{"type": "damage", "amount": 0, "target": "target"}], extra: Dictionary = {}, cooldown_ms: int = 60000, shot: bool = false) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 5000, "atk": 10, "speed": 0, "range": 3},
		"basic_attack": {"cooldown_ms": cooldown_ms, "shot": shot, "effects": effects}}
	for key: String in extra:
		if key == "stats":
			(data["stats"] as Dictionary).merge(extra["stats"], true)
		else:
			data[key] = extra[key]
	return K.kit(unit_id, data)


static func effect(data: Dictionary) -> EffectDef:
	var errors: Array[String] = []
	var def: EffectDef = EffectDef.read(DataReader.new(data, "effect", errors))
	assert(errors.is_empty(), str(errors))
	return def


static func read_errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	EffectDef.read(DataReader.new(data, "effect", errors))
	return errors


static func damage_to(fight: CombatSim, source_id: String, target_id: String) -> Array[int]:
	var found: Array[int] = []
	for entry: LogEntry in K.entries(fight, LogEntry.Kind.DAMAGE, source_id):
		if entry.target == target_id:
			found.append(entry.amount)
	return found


# --- reading -------------------------------------------------------------------------

func test_reading_the_new_effect_fields() -> void:
	var split: EffectDef = effect({"type": "damage", "amount": 4, "target": "enemy_near_target", "within_hexes": 1, "every": 4})
	assert_eq([split.target, split.near_range, split.every], [EffectDef.Target.ENEMY_NEAR_TARGET, 1000, 4])
	assert_eq(effect({"type": "damage", "amount": 4, "target": "enemy_near_target"}).near_range, 0, "any distance")
	assert_eq(effect({"type": "gain_mana", "amount": 5, "target": "self"}).type, EffectDef.Type.GAIN_MANA)
	var steal: EffectDef = effect({"trigger": "on_hit", "type": "heal", "amount_bp_of_damage": 500, "target": "self"})
	assert_eq(steal.amount_bp_of_damage, 500)
	var cleave: EffectDef = effect({"trigger": "on_hit", "type": "damage", "amount_bp_of_damage": 3000, "target": "enemy_near_target", "within_hexes": 1})
	assert_eq([cleave.amount, cleave.amount_bp_of_damage], [0, 3000])
	assert_eq(effect({"type": "heal", "amount": 10, "overheal_shield_bp": 1000, "target": "target"}).overheal_shield_bp, 1000)
	var zone: EffectDef = effect({"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "all", "duration_ms": 3000, "every_ms": 500,
		"effects": [{"type": "damage", "amount": 3, "target": "target", "side": "enemies"}, {"type": "heal", "amount": 2, "target": "target", "side": "allies"}]})
	assert_eq([zone.zone_ticks, zone.pulse_ticks], [60, 10])
	assert_eq([zone.area_effects[0].side, zone.area_effects[1].side], [EffectDef.AreaSide.ENEMIES, EffectDef.AreaSide.ALLIES])
	assert_eq(effect({"type": "heal", "amount": 3, "target": "lowest_hp_ally", "within_hexes": 3}).near_range, 3000)


func test_bad_new_fields_are_reported() -> void:
	assert_string_contains("\n".join(read_errors({"type": "damage", "amount": 4, "target": "enemies_near_target"})), "missing required key \"within_hexes\"")
	assert_string_contains("\n".join(read_errors({"type": "damage", "amount": 4, "target": "target", "within_hexes": 1})), "within_hexes is only for")
	assert_string_contains("\n".join(read_errors({"type": "damage", "amount": 4, "target": "target", "side": "enemies"})), "only an area's own effects")
	assert_string_contains("\n".join(read_errors({"type": "damage", "amount": 4, "amount_bp_of_damage": 10, "target": "target", "trigger": "on_hit"})), "exactly one")
	assert_string_contains("\n".join(read_errors({"type": "heal", "amount": 4, "amount_bp_of_max_hp": 10, "target": "target"})), "exactly one")
	assert_string_contains("\n".join(read_errors({"type": "heal", "amount_bp_of_damage": 500, "target": "self"})), "needs a hit")
	assert_string_contains("\n".join(read_errors({"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "all", "duration_ms": 500, "every_ms": 1000,
		"effects": [{"type": "damage", "amount": 3, "target": "target"}]})), "can't be longer")
	assert_string_contains("\n".join(read_errors({"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "all", "duration_ms": 1000, "every_ms": 500, "warning_ms": 500,
		"effects": [{"type": "damage", "amount": 3, "target": "target"}]})), "takes no warning_ms")
	assert_string_contains("\n".join(read_errors({"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "all",
		"effects": [{"type": "damage", "amount": 3, "target": "target", "every": 2}]})), "unknown key \"every\"")
	assert_eq(read_errors({"trigger": "on_fall", "type": "damage", "amount": 3, "target": "enemy_near_target"}).size(), 1, "on_fall can't aim near a target")


# --- every, and the targets near the target ------------------------------------------------

func test_an_on_fire_effect_runs_every_nth_fire() -> void:
	var hero: UnitDef = still("striker", [{"type": "damage", "amount": 1, "target": "target"}, {"type": "damage", "amount": 5, "target": "target", "every": 3}], {}, 250)
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)], [K.foe(still("dummy"), 3, 4)]))
	K.step(fight, 200)
	var fires: int = K.entries(fight, LogEntry.Kind.FIRE, "striker").size()
	var hits: Array[int] = damage_to(fight, "striker", "dummy")
	assert_gt(fires, 9)
	assert_eq(hits.count(1), fires)
	assert_eq(hits.count(5), fires / 3, "every third fire")


func test_the_targets_near_the_target() -> void:
	# The dummy A is the target; B stands 1 hex behind it, C 2 hexes.
	var hero: UnitDef = still("striker", [{"type": "damage", "amount": 1, "target": "target"},
		{"type": "damage", "amount": 2, "target": "enemy_near_target", "within_hexes": 1},
		{"type": "damage", "amount": 3, "target": "enemies_near_target", "within_hexes": 2},
		{"type": "damage", "amount": 4, "target": "enemy_near_target", "within_hexes": 1}], {}, 60000)
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)], [K.foe(still("a"), 3, 4), K.foe(still("b"), 3, 5), K.foe(still("c"), 3, 6)]))
	K.step(fight, 1300)
	assert_eq(damage_to(fight, "striker", "a"), [1] as Array[int], "the target itself is never near itself")
	assert_eq(damage_to(fight, "striker", "b"), [2, 3, 4] as Array[int])
	assert_eq(damage_to(fight, "striker", "c"), [3] as Array[int], "2 hexes away: only the plural one reaches it")
	# With no one close enough, nothing lands; without a limit, the nearest anyway.
	var alone: CombatSim = K.sim(K.fight([K.at(still("striker", [{"type": "damage", "amount": 1, "target": "target"},
		{"type": "damage", "amount": 2, "target": "enemy_near_target", "within_hexes": 1},
		{"type": "damage", "amount": 9, "target": "enemy_near_target"}]), 3, 2)], [K.foe(still("a"), 3, 4), K.foe(still("c"), 3, 6)]))
	K.step(alone, 1300)
	assert_eq(damage_to(alone, "striker", "c"), [9] as Array[int])


func test_allies_near_the_target_and_the_lowest_ally() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(still("mender"), 3, 1), K.at(still("x"), 3, 2), K.at(still("y"), 2, 0)], [K.foe(still("foe"), 3, 5)]))
	var mender: UnitState = fight.unit_by_id("mender")
	var x: UnitState = fight.unit_by_id("x")
	var y: UnitState = fight.unit_by_id("y")
	var one: EffectDef = effect({"type": "heal", "amount": 1, "target": "ally_near_target", "within_hexes": 1})
	assert_eq(EffectRunner.near(fight, mender, one, mender), [x] as Array[UnitState], "x is 1 hex from the mender; y about 1.7")
	var two: EffectDef = effect({"type": "heal", "amount": 1, "target": "allies_near_target", "within_hexes": 2})
	assert_eq(EffectRunner.near(fight, mender, two, mender), [x, y] as Array[UnitState])
	assert_eq(EffectRunner.near(fight, mender, one, y), [] as Array[UnitState], "no one within 1 hex of y")
	var any: EffectDef = effect({"type": "heal", "amount": 1, "target": "ally_near_target"})
	assert_eq(EffectRunner.near(fight, mender, any, y), [mender] as Array[UnitState], "with no limit, the mender is nearest y")
	var lowest: EffectDef = effect({"type": "heal", "amount": 1, "target": "lowest_hp_ally"})
	y.hp = 1000
	x.hp = 2000
	assert_eq(EffectRunner.near(fight, mender, lowest, null), [y] as Array[UnitState], "the lowest share, wherever")
	var within: EffectDef = effect({"type": "heal", "amount": 1, "target": "lowest_hp_ally", "within_hexes": 1})
	assert_eq(EffectRunner.near(fight, mender, within, null), [x] as Array[UnitState], "y is out of reach")
	assert_eq(EffectRunner.near(fight, mender, one, null), [] as Array[UnitState], "no center, no one")


func test_on_hit_near_the_unit_hit_for_a_share_of_the_hit() -> void:
	# A shot at A; on its hit, 30% of what it dealt lands on B next to A.
	var hero: UnitDef = still("archer", [{"type": "damage", "amount": 40, "target": "target"},
		{"trigger": "on_hit", "type": "damage", "amount_bp_of_damage": 3000, "target": "enemy_near_target", "within_hexes": 1}], {}, 60000, true)
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)], [K.foe(still("a"), 3, 4), K.foe(still("b"), 3, 5)]))
	K.step(fight, 1300)
	var on_a: Array[int] = damage_to(fight, "archer", "a")
	assert_eq(on_a.size(), 1)
	assert_eq(damage_to(fight, "archer", "b"), [on_a[0] * 3 / 10] as Array[int])


# --- mana ------------------------------------------------------------------------------------

func test_gain_mana_fills_the_bar_unless_silenced() -> void:
	var mana: Dictionary = {"max": 100, "per_attack": 0}
	var signature: Dictionary = {"id": "big", "name": "Big", "trigger": {"kind": "mana"}, "targeting": "nearest", "effects": [{"type": "damage", "amount": 1, "target": "target"}]}
	var hero: UnitDef = still("caster", [{"type": "damage", "amount": 1, "target": "target"}, {"type": "gain_mana", "amount": 7, "target": "self"}],
		{"mana": mana, "signature": signature}, 1000)
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)], [K.foe(still("dummy"), 3, 4)]))
	var unit: UnitState = fight.unit_by_id("caster")
	K.step(fight, 20)
	assert_eq(unit.mana, 7 * Mana.SCALE)
	Statuses.apply(fight, unit, "silence", 1, 200, EffectSource.make("dummy", "hush", "Hush"))
	K.step(fight, 20)
	assert_eq(unit.mana, 7 * Mana.SCALE, "Silence stops it")


func test_a_far_attack_gives_more_mana() -> void:
	for row: int in [5, 4]:
		var mana: Dictionary = {"max": 100, "per_attack": 5, "far_hexes": 3, "per_far_attack": 20}
		var signature: Dictionary = {"id": "big", "name": "Big", "trigger": {"kind": "mana"}, "targeting": "nearest", "effects": [{"type": "damage", "amount": 1, "target": "target"}]}
		var hero: UnitDef = still("archer", [{"type": "damage", "amount": 1, "target": "target"}], {"mana": mana, "signature": signature, "stats": {"range": 4}}, 1000, true)
		var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)], [K.foe(still("dummy"), 3, row)]))
		K.step(fight, 20)
		assert_eq(fight.unit_by_id("archer").mana, (20 if row == 5 else 5) * Mana.SCALE, "a target %d hexes away" % (row - 2))


# --- heals -----------------------------------------------------------------------------------

func test_lifesteal_heals_a_share_of_the_hit() -> void:
	var hero: UnitDef = still("reaver", [{"type": "damage", "amount": 40, "target": "target"},
		{"trigger": "on_hit", "type": "heal", "amount_bp_of_damage": 5000, "target": "self"}], {}, 1000)
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)], [K.foe(still("dummy", [{"type": "damage", "amount": 0, "target": "target"}], {"stats": {"def": 20}}), 3, 4)]))
	fight.unit_by_id("reaver").hp = 100
	K.step(fight, 20)
	var dealt: Array[int] = damage_to(fight, "reaver", "dummy")
	assert_eq(dealt.size(), 1)
	assert_lt(dealt[0], 40, "through the dummy's DEF")
	var heals: Array[LogEntry] = K.entries(fight, LogEntry.Kind.HEAL, "reaver")
	assert_eq(heals.map(func(entry: LogEntry) -> int: return entry.amount), [FixedMath.apply_bp(dealt[0], 5000)], "half of what got through")


func test_overheal_comes_back_as_shield() -> void:
	var hero: UnitDef = still("warder", [{"type": "damage", "amount": 0, "target": "target"}, {"type": "heal", "amount": 30, "overheal_shield_bp": 1000, "target": "self"}], {}, 1000)
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)], [K.foe(still("dummy"), 3, 4)]))
	var unit: UnitState = fight.unit_by_id("warder")
	K.step(fight, 20)
	assert_eq(unit.shield, 3, "at full HP: 10% of the whole heal")
	unit.hp = unit.max_hp - 10
	K.step(fight, 20)
	assert_eq(unit.hp, unit.max_hp)
	assert_eq(unit.shield, 5, "10 healed, 20 over: 2 more Shield")
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD, "warder").map(func(entry: LogEntry) -> int: return entry.amount), [3, 2])


func test_healing_taken_scales_heals_on_the_holder() -> void:
	var hero: UnitDef = still("martyr", [{"type": "damage", "amount": 0, "target": "target"}, {"type": "heal", "amount": 100, "target": "self"}],
		{"passives": [{"id": "scarred", "name": "Scarred", "kind": "aura", "aura": {"target": "holder", "stat": "healing_taken_bp", "value": 7000}}]}, 1000)
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)], [K.foe(still("dummy"), 3, 4)]))
	fight.unit_by_id("martyr").hp = 1000
	K.step(fight, 20)
	assert_eq(K.entries(fight, LogEntry.Kind.HEAL, "martyr").map(func(entry: LogEntry) -> int: return entry.amount), [70])


# --- areas -----------------------------------------------------------------------------------

func test_an_area_treats_each_side_its_own_way() -> void:
	var sunfall: Dictionary = {"id": "sunfall", "name": "Sunfall", "trigger": {"kind": "fight_start"}, "targeting": "self",
		"effects": [{"type": "area", "shape": {"kind": "circle", "radius": 4}, "anchor": "self", "hits": "all",
			"effects": [{"type": "damage", "amount": 10, "target": "target", "side": "enemies"}, {"type": "heal", "amount": 10, "target": "target", "side": "allies"}]}]}
	var fight: CombatSim = K.sim(K.fight([K.at(still("cleric", [{"type": "damage", "amount": 0, "target": "target"}], {"signature": sunfall}), 3, 2), K.at(still("ally"), 3, 1)],
		[K.foe(still("foe"), 3, 4)]))
	K.step(fight, 2)
	var damaged: Array = K.entries(fight, LogEntry.Kind.DAMAGE, "cleric").map(func(entry: LogEntry) -> String: return entry.target)
	var healed: Array = K.entries(fight, LogEntry.Kind.HEAL, "cleric").map(func(entry: LogEntry) -> String: return entry.target)
	assert_eq(damaged, ["foe"])
	assert_eq(healed, ["cleric", "ally"])


func test_a_zone_lands_every_pulse_until_it_ends() -> void:
	var storm: Dictionary = {"id": "storm", "name": "Storm", "trigger": {"kind": "fight_start"}, "targeting": "nearest",
		"effects": [{"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "enemies", "duration_ms": 1000, "every_ms": 250,
			"effects": [{"type": "damage", "amount": 3, "target": "target"}]}]}
	var fight: CombatSim = K.sim(K.fight([K.at(still("volley", [{"type": "damage", "amount": 0, "target": "target"}], {"signature": storm}), 3, 2)],
		[K.foe(still("a"), 3, 4), K.foe(still("far"), 3, 6)]))
	K.step(fight, 60)
	var zones: Array[LogEntry] = K.entries(fight, LogEntry.Kind.ZONE, "volley")
	assert_eq(zones.size(), 1)
	var start: int = zones[0].tick
	assert_eq(zones[0].end_tick, start + 20)
	assert_eq(zones[0].shape, "circle 1")
	var landed: Array = K.entries(fight, LogEntry.Kind.AREA_LANDED, "volley").map(func(entry: LogEntry) -> int: return entry.tick)
	assert_eq(landed, [start, start + 5, start + 10, start + 15], "at once, then every 250 ms, and not at its end")
	assert_eq(damage_to(fight, "volley", "a"), [3, 3, 3, 3] as Array[int])
	assert_eq(damage_to(fight, "volley", "far"), [] as Array[int], "2 hexes off: outside it")
	assert_eq(fight.zones.size(), 0, "gone once it ends")


# --- auras -----------------------------------------------------------------------------------

func test_a_planted_aura_waits_for_the_unit_to_stand_still() -> void:
	# A unit that hasn't moved since it was placed starts planted: range 2
	# plus 1 reaches the dummy 3 hexes away at once.
	var steady: Dictionary = {"id": "steady", "name": "Steady", "kind": "aura", "aura": {"target": "holder", "stat": "range", "value": 1, "while": "planted", "after_ms": 1000}}
	var hero: UnitDef = still("sniper", [{"type": "damage", "amount": 1, "target": "target"}], {"passives": [steady], "stats": {"range": 2}}, 250, true)
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 1)], [K.foe(still("dummy"), 3, 4)]))
	var unit: UnitState = fight.unit_by_id("sniper")
	assert_eq(unit.moved_at, UnitState.NEVER_MOVED)
	assert_eq(unit.stats.get_stat(UnitStats.Stat.RANGE), 3, "planted from the start")
	var auras: Array[LogEntry] = K.entries(fight, LogEntry.Kind.AURA, "sniper")
	assert_eq(auras.size(), 1)
	assert_string_contains(auras[0].note, "+1 range for its holder once it hasn't moved for 1s")
	K.step(fight, 10)
	assert_gt(K.entries(fight, LogEntry.Kind.FIRE, "sniper").size(), 0, "it reaches")
	# Moving ends it (a push counts), and 1s of standing still brings it back.
	Displacement.knockback(fight, unit, Vector2i(3098, 5000), 1, 1, EffectSource.make("dummy", "shove", "Shove"))
	var pushed: int = fight.tick
	K.step(fight, 1)
	assert_eq(unit.stats.get_stat(UnitStats.Stat.RANGE), 2)
	assert_eq(K.entries(fight, LogEntry.Kind.AURA, "sniper").back().note, "ends")
	K.step(fight, 20)
	assert_eq(unit.stats.get_stat(UnitStats.Stat.RANGE), 3)
	assert_eq(K.entries(fight, LogEntry.Kind.AURA, "sniper").back().tick, pushed + 20, "planted again 1s after the push")


func test_a_below_hp_aura_holds_while_hurt() -> void:
	var last_stand: Dictionary = {"id": "last_stand", "name": "Last Stand", "kind": "aura", "aura": {"target": "holder", "stat": "def_bp", "value": 20000, "while": "below_hp", "below_pct": 30}}
	var fight: CombatSim = K.sim(K.fight([K.at(still("martyr", [{"type": "damage", "amount": 0, "target": "target"}], {"passives": [last_stand], "stats": {"def": 10}}), 3, 2)],
		[K.foe(still("dummy"), 3, 4)]))
	var unit: UnitState = fight.unit_by_id("martyr")
	K.step(fight, 1)
	assert_eq(unit.defense(), 10)
	unit.hp = unit.max_hp * 29 / 100
	K.step(fight, 1)
	assert_eq(unit.defense(), 20)
	unit.hp = unit.max_hp / 2
	K.step(fight, 1)
	assert_eq(unit.defense(), 10)


func test_a_per_fallen_ally_aura_counts_the_fallen() -> void:
	var grief: Dictionary = {"id": "grief", "name": "Grief", "kind": "aura", "aura": {"target": "holder", "stat": "atk_bp", "value": 11000, "per": "fallen_ally"}}
	var fight: CombatSim = K.sim(K.fight([K.at(still("martyr", [{"type": "damage", "amount": 0, "target": "target"}], {"passives": [grief], "stats": {"atk": 100}}), 3, 1),
		K.at(still("x"), 2, 0), K.at(still("y"), 4, 0)], [K.foe(still("dummy"), 3, 4)]))
	var unit: UnitState = fight.unit_by_id("martyr")
	K.step(fight, 1)
	assert_eq(unit.stats.get_stat(UnitStats.Stat.ATK), 100)
	fight.unit_by_id("x").hp = 0
	K.step(fight, 1)
	assert_eq(unit.stats.get_stat(UnitStats.Stat.ATK), 110)
	fight.unit_by_id("y").hp = 0
	K.step(fight, 1)
	assert_eq(unit.stats.get_stat(UnitStats.Stat.ATK), 121, "x1.1 twice")


# --- attacking -------------------------------------------------------------------------------

func test_the_plant_delay_waits_after_moving() -> void:
	for plant_ms: int in [0, 1000]:
		var hero: UnitDef = K.kit("sniper", {"stats": {"hp": 5000, "speed": 2, "range": 2}, "plant_ms": plant_ms,
			"basic_attack": {"cooldown_ms": 250, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}})
		var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 0)], [K.foe(still("dummy"), 3, 5)]))
		K.step(fight, 120)
		var unit: UnitState = fight.unit_by_id("sniper")
		var first: int = K.entries(fight, LogEntry.Kind.FIRE, "sniper")[0].tick
		assert_gt(unit.moved_at, 0)
		if plant_ms == 0:
			assert_lte(first, unit.moved_at + 1, "fires as soon as it's in reach")
		else:
			assert_eq(first, unit.moved_at + 20, "waits 1s after its last step")


func test_fires_moving_shoots_what_it_passes() -> void:
	# It walks at the farthest dummy, and shoots the near one on the way.
	var hero: UnitDef = K.kit("skirmisher", {"stats": {"hp": 5000, "speed": 1, "range": 2}, "targeting": "farthest", "traits": ["fires_moving"],
		"basic_attack": {"cooldown_ms": 500, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 0)], [K.foe(still("near"), 2, 4), K.foe(still("far"), 3, 6)]))
	K.step(fight, 60)
	var unit: UnitState = fight.unit_by_id("skirmisher")
	assert_eq(unit.target.id, "far")
	var fires: Array = K.entries(fight, LogEntry.Kind.FIRE, "skirmisher").map(func(entry: LogEntry) -> String: return entry.target)
	assert_gt(fires.size(), 0)
	assert_eq(fires.count("near"), fires.size(), "at what it passes, not its target")
	assert_eq(unit.moved_at, fight.tick, "still walking")
	var plain: CombatSim = K.sim(K.fight([K.at(K.kit("walker", {"stats": {"hp": 5000, "speed": 1, "range": 2}, "targeting": "farthest",
		"basic_attack": {"cooldown_ms": 500, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}}), 3, 0)],
		[K.foe(still("near"), 2, 4), K.foe(still("far"), 3, 6)]))
	K.step(plain, 60)
	assert_eq(K.entries(plain, LogEntry.Kind.FIRE, "walker").size(), 0, "without the trait it only walks")


# --- falling ----------------------------------------------------------------------------------

func test_unyielding_saves_once() -> void:
	var unyielding: Dictionary = {"id": "unyielding", "name": "Unyielding", "kind": "ability",
		"effects": [{"trigger": "on_would_fall", "type": "apply_status", "status": "undying", "duration_ms": 500, "target": "self"}]}
	var hero: UnitDef = still("watch", [{"type": "damage", "amount": 0, "target": "target"}], {"passives": [unyielding], "stats": {"hp": 30}})
	var brute: UnitDef = still("brute", [{"type": "damage", "amount": 40, "target": "target"}], {}, 1000)
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)], [K.foe(brute, 3, 4)]))
	var unit: UnitState = fight.unit_by_id("watch")
	K.step(fight, 21)
	assert_true(unit.alive)
	assert_eq(unit.hp, 1)
	var saves: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SAVED, "watch")
	assert_eq(saves.size(), 1)
	assert_eq([saves[0].source_ability, saves[0].target, saves[0].note], ["unyielding", "watch", "would fall"])
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "watch").map(func(entry: LogEntry) -> String: return entry.status), ["undying"])
	K.step(fight, 60)
	assert_false(unit.alive, "only once a fight")
	assert_eq(K.entries(fight, LogEntry.Kind.SAVED, "watch").size(), 1)


func test_a_ward_takes_off_damage_and_adds_to_a_mark() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(still("striker", [{"type": "damage", "amount": 100, "target": "target"}], {}, 1000), 3, 2)], [K.foe(still("dummy"), 3, 4)]))
	var dummy: UnitState = fight.unit_by_id("dummy")
	var source: EffectSource = EffectSource.make("striker", "test", "Test")
	Statuses.apply(fight, dummy, "warded", 1, 400, source)
	assert_eq(Statuses.damage_taken_bp(dummy), -1500)
	K.step(fight, 20)
	assert_eq(damage_to(fight, "striker", "dummy"), [85] as Array[int], "15% less")
	Statuses.apply(fight, dummy, "marked", 1, 400, source)
	assert_eq(Statuses.damage_taken_bp(dummy), 0, "a Mark (+15%) and a Ward (-15%) add up")


# --- snares, walls, and Guard (wave 3) ----------------------------------------------------------

static func snare_effect(extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {"type": "snare", "effects": [{"type": "apply_status", "status": "root", "target": "target"}]}
	data.merge(extra, true)
	return data


func test_a_snare_springs_on_the_first_enemy_to_walk_in() -> void:
	var lay: Dictionary = {"id": "lay", "name": "Lay Snare", "trigger": {"kind": "fight_start"}, "targeting": "nearest", "effects": [snare_effect()]}
	var walker: UnitDef = K.kit("walker", {"stats": {"hp": 5000, "speed": 2}})
	var fight: CombatSim = K.sim(K.fight([K.at(still("trapper", [{"type": "damage", "amount": 0, "target": "target"}], {"signature": lay, "stats": {"range": 6}}), 3, 0)], [K.foe(walker, 3, 5)]))
	K.step(fight, 1)
	var set: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SNARE, "trapper")
	assert_eq(set.size(), 1)
	assert_eq([set[0].note, set[0].from_pos], ["set", Vector2i(3098, 5000)], "1 hex ahead of the walker, toward the trapper")
	K.step(fight, 40)
	var sprung: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SNARE, "trapper")
	assert_eq(sprung.size(), 2)
	assert_eq([sprung[1].note, sprung[1].target], ["sprung", "walker"])
	var roots: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "trapper")
	assert_eq(roots.map(func(entry: LogEntry) -> Array: return [entry.target, entry.status, entry.source_ability, entry.tick]), [["walker", "root", "lay", sprung[1].tick]])
	assert_eq(fight.snares.size(), 0, "gone once sprung")


func test_a_snare_past_max_standing_replaces_the_oldest() -> void:
	var hero: UnitDef = still("trapper", [{"type": "damage", "amount": 0, "target": "target"}, snare_effect({"max_standing": 2})], {}, 250)
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 1)], [K.foe(still("dummy"), 3, 4)]))
	K.step(fight, 16)
	var notes: Array = K.entries(fight, LogEntry.Kind.SNARE, "trapper").map(func(entry: LogEntry) -> String: return entry.note)
	assert_eq(notes, ["set", "set", "gone", "set"], "the third replaces the first")
	assert_eq(fight.snares.size(), 2)


func test_placed_snares_are_set_at_the_start_and_checked() -> void:
	var lay: Dictionary = {"id": "lay", "name": "Lay Snare", "trigger": {"kind": "fight_start"}, "targeting": "nearest", "effects": [snare_effect()]}
	var kit: UnitDef = still("trapper", [{"type": "damage", "amount": 0, "target": "target"}], {"signature": lay, "placed_snares": 2})
	var hero: UnitSetup = K.at(kit, 3, 0)
	hero.snares = [Vector2i(2, 3), Vector2i(4, 2)] as Array[Vector2i]
	var setup: FightSetup = K.fight([hero], [K.foe(still("dummy"), 3, 5)])
	var fight: CombatSim = K.sim(setup)
	var placed: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SNARE, "trapper")
	assert_eq(placed.map(func(entry: LogEntry) -> Array: return [entry.tick, entry.note, entry.from_pos, entry.source_ability]),
		[[0, "set", Vector2i(2232, 3500), "lay"], [0, "set", Vector2i(3964, 2500), "lay"]])
	var content: ContentDb = K.content()
	hero.snares = [Vector2i(2, 3), Vector2i(4, 2), Vector2i(3, 1)] as Array[Vector2i]
	assert_eq(setup.validate(content), ["trapper at (3, 0) places 3 snares, but can place 2"] as Array[String])
	hero.snares = [Vector2i(2, 3), Vector2i(2, 3)] as Array[Vector2i]
	assert_eq(setup.validate(content), ["trapper's snare at (2, 3) is placed twice"] as Array[String])
	hero.snares = [Vector2i(2, 4)] as Array[Vector2i]
	assert_eq(setup.validate(content), ["trapper's snare at (2, 4) is in the enemies' half"] as Array[String])
	hero.snares = [Vector2i(9, 1)] as Array[Vector2i]
	assert_eq(setup.validate(content), ["trapper's snare at (9, 1) is off the board"] as Array[String])
	setup.rocks = [Vector2i(2, 3)] as Array[Vector2i]
	hero.snares = [Vector2i(2, 3)] as Array[Vector2i]
	assert_eq(setup.validate(content), ["trapper's snare at (2, 3) is on a rock"] as Array[String])
	var plain: UnitSetup = K.at(still("plain"), 3, 0)
	plain.snares = [Vector2i(2, 3)] as Array[Vector2i]
	assert_eq(K.fight([plain], [K.foe(still("dummy"), 3, 5)]).validate(content), ["plain at (3, 0) places 1 snares, but can place 0"] as Array[String])


func test_a_wall_stops_enemy_shots_while_it_stands() -> void:
	var raise: Dictionary = {"id": "raise", "name": "Hearthwall", "trigger": {"kind": "fight_start"}, "targeting": "nearest",
		"effects": [{"type": "wall", "width_hexes": 3, "ahead_hexes": 1, "duration_ms": 1000}]}
	var archer: UnitDef = still("archer", [{"type": "damage", "amount": 5, "target": "target"}], {"stats": {"range": 5}}, 250, true)
	var fight: CombatSim = K.sim(K.fight([K.at(still("warden", [{"type": "damage", "amount": 0, "target": "target"}], {"signature": raise, "stats": {"range": 5}}), 3, 1)], [K.foe(archer, 3, 5)]))
	K.step(fight, 40)
	var walls: Array[LogEntry] = K.entries(fight, LogEntry.Kind.WALL, "warden")
	assert_eq(walls.size(), 1)
	assert_eq([walls[0].from_pos.y, walls[0].to_pos.y, absi(walls[0].from_pos.x - walls[0].to_pos.x)], [3000, 3000, 3000], "3 hexes wide, 1 ahead, square to the archer")
	var stopped: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SHOT_FIZZLED, "archer")
	assert_gt(stopped.size(), 0)
	assert_string_contains(stopped[0].note, "stopped by warden · Hearthwall")
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "archer")
	assert_gt(hits.size(), 0, "after it falls, the shots land")
	assert_gte(hits[0].tick, walls[0].end_tick)
	assert_eq(fight.walls.size(), 0)
	assert_true(Walls.crosses(Vector2i(0, 0), Vector2i(10, 10), Vector2i(0, 10), Vector2i(10, 0)))
	assert_false(Walls.crosses(Vector2i(0, 0), Vector2i(4, 4), Vector2i(6, 0), Vector2i(10, 0)))


func _guard_fight(covers: String, ally_row: int, guard_def: int = 0) -> CombatSim:
	var guard: Dictionary = {"id": "guard", "name": "Guard", "kind": "guard", "share_pct": 30, "within_hexes": 1, "covers": covers}
	var guardian: UnitDef = still("guardian", [{"type": "damage", "amount": 0, "target": "target"}], {"passives": [guard], "stats": {"hp": 5000, "def": guard_def}})
	# The archer shoots the ally: the farther one when it stands behind, the nearer in front.
	var archer: UnitDef = still("archer", [{"type": "damage", "amount": 50, "target": "target"}], {"stats": {"range": 5}, "targeting": "farthest" if ally_row == 1 else "nearest"}, 1000, true)
	# (The ally goes first in the fight's order: with both in the archer's reach, "nearest" is a tie.)
	return K.sim(K.fight([K.at(still("ally", [{"type": "damage", "amount": 0, "target": "target"}], {"stats": {"hp": 400}}), 3, ally_row), K.at(guardian, 3, 1 if ally_row == 2 else 2)],
		[K.foe(archer, 3, 4)]))


func test_guard_takes_a_share_of_hits_on_an_ally_behind() -> void:
	var fight: CombatSim = _guard_fight("behind", 1)
	K.step(fight, 30)
	var on_ally: Array[int] = damage_to(fight, "archer", "ally")
	var guarded: Array[LogEntry] = K.entries(fight, LogEntry.Kind.GUARD, "guardian")
	assert_eq(on_ally, [35] as Array[int], "50 less the 30% the guard took")
	assert_eq(guarded.map(func(entry: LogEntry) -> Array: return [entry.target, entry.amount, entry.source_ability]), [["ally", 15, "guard"]])
	assert_eq(fight.unit_by_id("guardian").hp, 5000 - 15)
	assert_eq(guarded[0].to_text().get_slice("] ", 1), "guardian · Guard takes 15 of the hit on ally")
	# In front of it, a behind-only guard doesn't cover; an all-round one does.
	var front: CombatSim = _guard_fight("behind", 2)
	K.step(front, 30)
	assert_eq(K.entries(front, LogEntry.Kind.GUARD, "guardian").size(), 0)
	assert_eq(damage_to(front, "archer", "ally"), [50] as Array[int])
	var round: CombatSim = _guard_fight("all", 2)
	K.step(round, 30)
	assert_eq(damage_to(round, "archer", "ally"), [35] as Array[int])


func test_a_guard_takes_its_share_against_its_own_def() -> void:
	var fight: CombatSim = _guard_fight("behind", 1, 100)
	K.step(fight, 30)
	assert_eq(damage_to(fight, "archer", "ally"), [35] as Array[int], "the ally's DEF (0) cuts only its own part")
	var guarded: Array[LogEntry] = K.entries(fight, LogEntry.Kind.GUARD, "guardian")
	assert_eq(guarded.map(func(entry: LogEntry) -> int: return entry.amount), [8] as Array[int], "15 of the hit, halved by DEF 100 (constant 100), rounded")
	assert_eq(fight.unit_by_id("guardian").hp, 5000 - 8)


func test_an_on_interval_passive_can_run_once() -> void:
	var once: Dictionary = {"id": "once", "name": "Once", "kind": "ability", "effects": [{"trigger": "on_interval", "interval_ms": 500, "once": true, "type": "shield", "amount": 5, "target": "self"}]}
	var fight: CombatSim = K.sim(K.fight([K.at(still("hero", [{"type": "damage", "amount": 0, "target": "target"}], {"passives": [once]}), 3, 2)], [K.foe(still("dummy"), 3, 4)]))
	K.step(fight, 60)
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD, "hero").map(func(entry: LogEntry) -> int: return entry.tick), [10])
