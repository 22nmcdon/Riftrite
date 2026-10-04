extends GutTest
## Act 2's enemies in data/enemies.json (docs/plans/act2-glassmere.md,
## sections 3 and 5 to 7; rebuild-phase8-act2.md, 8c-4a): each one's threat
## happens, and so does each new face's two specializations. Each test is a
## small fight built for one enemy, with water where it needs some.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


func _kit(enemy_id: String, spec_id: String = "") -> UnitDef:
	var kit: UnitDef = (_content.enemies[enemy_id] as EnemyDef).kit
	return kit if spec_id.is_empty() else (_content.specializations[spec_id] as SpecializationDef).apply(kit)


## A hero that stands still and never hurts anyone.
func _still(hero_id: String, stats: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 5000, "speed": 0, "range": 1}
	all_stats.merge(stats, true)
	return K.kit(hero_id, {"stats": all_stats, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## A fight on `water`, with every kit the enemies may summon or rise as.
func _sim(heroes: Array[UnitSetup], enemies: Array[UnitSetup], water: Array[Vector2i] = []) -> CombatSim:
	var setup: FightSetup = K.fight(heroes, enemies)
	setup.water = water
	setup.summon_kits = Encounters.summon_kits(_content, setup.units(), FixedMath.BP_ONE)
	return CombatSim.new(setup, _content)


func _root(fight: CombatSim, units: Array[UnitState]) -> void:
	for unit: UnitState in units:
		Statuses.apply(fight, unit, "root", 0, 100000, EffectSource.make("", "test", "Test"))


func _fill_mana(unit: UnitState) -> void:
	unit.mana = unit.mana_cap


func _summoned(fight: CombatSim) -> Array:
	return fight.combat_log.of_kind(LogEntry.Kind.SUMMON).filter(func(entry: LogEntry) -> bool: return entry.note.is_empty()) \
		.map(func(entry: LogEntry) -> String: return entry.target)


static func lake() -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []
	for row: int in 7:
		for col: int in 8:
			hexes.append(Vector2i(col, row))
	return hexes


# --- the new faces ------------------------------------------------------------------

func test_a_mire_eel_swims_under_and_surfaces_at_the_back_line() -> void:
	var fight: CombatSim = _sim([K.at(_still("front"), 3, 2), K.at(_still("back", {"hp": 400}), 5, 0)] as Array[UnitSetup],
		[K.foe(_kit("mire_eel"), 3, 5)] as Array[UnitSetup], lake())
	var eel: UnitState = fight.unit_by_id("mire_eel")
	K.step(fight, 1)
	assert_true(eel.submerged, "under the water")
	K.step(fight, 120)
	var bites: Array = K.entries(fight, LogEntry.Kind.DAMAGE, "mire_eel").map(func(entry: LogEntry) -> String: return entry.target)
	assert_false(bites.is_empty())
	assert_eq(bites[0], "back", "its weakest back-liner")


func test_an_ambush_eel_stuns_with_its_first_bite_and_a_coiling_eel_drags_toward_water() -> void:
	var water: Array[Vector2i] = [Vector2i(3, 4), Vector2i(3, 5), Vector2i(3, 6)]
	var ambush: CombatSim = _sim([K.at(_still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(_kit("mire_eel", "ambush_eel"), 3, 4)] as Array[UnitSetup], water)
	K.step(ambush, 100)
	var stuns: Array[LogEntry] = K.entries(ambush, LogEntry.Kind.STATUS_APPLIED, "mire_eel").filter(func(entry: LogEntry) -> bool: return entry.status == "stun")
	assert_eq(stuns.size(), 1, "its first bite only")
	assert_eq(stuns[0].source_ability, "ambush")
	var coiling: CombatSim = _sim([K.at(_still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(_kit("mire_eel", "coiling_eel"), 3, 4)] as Array[UnitSetup], water)
	K.step(coiling, 60)
	var pulls: Array[LogEntry] = K.entries(coiling, LogEntry.Kind.PUSH, "mire_eel")
	assert_false(pulls.is_empty(), "its bite drags")
	assert_lt(ArenaPlane.distance(pulls[0].to_pos, coiling.grid.center(3, 4)), ArenaPlane.distance(pulls[0].from_pos, coiling.grid.center(3, 4)), "toward the water")


func test_a_reedline_slinger_lobs_a_stone_onto_everyone_within_a_hex() -> void:
	var fight: CombatSim = _sim([K.at(_still("a"), 3, 1), K.at(_still("b"), 4, 1), K.at(_still("far"), 7, 0)] as Array[UnitSetup],
		[K.foe(_kit("reedline_slinger"), 3, 4)] as Array[UnitSetup])
	_root(fight, fight.units)
	K.step(fight, 50)
	assert_false(K.entries(fight, LogEntry.Kind.AREA_WARNING, "reedline_slinger").is_empty(), "the stone is warned")
	var hit: Array = K.entries(fight, LogEntry.Kind.DAMAGE, "reedline_slinger").map(func(entry: LogEntry) -> String: return entry.target)
	assert_true(hit.has("a") and hit.has("b"), "both heroes standing together")
	assert_false(hit.has("far"))


func test_the_slingers_specializations_skip_and_leave_mud() -> void:
	var heroes: Array[UnitSetup] = [K.at(_still("a"), 3, 1), K.at(_still("b"), 5, 1)]
	var skipping: CombatSim = _sim(heroes, [K.foe(_kit("reedline_slinger", "skipping_slinger"), 3, 4)] as Array[UnitSetup])
	_root(skipping, skipping.units)
	K.step(skipping, 50)
	assert_true(K.entries(skipping, LogEntry.Kind.DAMAGE, "reedline_slinger").any(func(entry: LogEntry) -> bool: return entry.target == "b"), "the stone skips on to the other hero")
	var mud: CombatSim = _sim([K.at(_still("a"), 3, 1)] as Array[UnitSetup], [K.foe(_kit("reedline_slinger", "mudslinger"), 3, 4)] as Array[UnitSetup])
	_root(mud, mud.units)
	K.step(mud, 60)
	assert_true(K.entries(mud, LogEntry.Kind.STATUS_APPLIED, "reedline_slinger").any(func(entry: LogEntry) -> bool: return entry.status == "slow"), "the mud slows")


func test_a_tidecaller_floods_your_largest_group_and_hits_harder_in_water() -> void:
	var fight: CombatSim = _sim([K.at(_still("a"), 2, 1), K.at(_still("b"), 3, 1), K.at(_still("c"), 7, 0)] as Array[UnitSetup],
		[K.foe(_kit("tidecaller"), 3, 5)] as Array[UnitSetup])
	_root(fight, fight.units)
	_fill_mana(fight.unit_by_id("tidecaller"))
	K.step(fight, 2)
	var floods: Array[LogEntry] = fight.combat_log.of_kind(LogEntry.Kind.WATER)
	assert_eq(floods.size(), 1)
	assert_eq(floods[0].note, "floods %d hexes for 6s" % fight.water.hexes.size())
	assert_true(fight.unit_by_id("a").on_water and fight.unit_by_id("b").on_water, "the largest group stands in it")
	assert_false(fight.unit_by_id("c").on_water)
	# Its bolt, at a hero on water and one on dry ground.
	var bolts: Array[int] = []
	for water: Array[Vector2i] in [[Vector2i(3, 1)] as Array[Vector2i], [] as Array[Vector2i]]:
		var bolt: CombatSim = _sim([K.at(_still("hero"), 3, 1)] as Array[UnitSetup], [K.foe(_kit("tidecaller"), 3, 5)] as Array[UnitSetup], water)
		_root(bolt, bolt.units)
		K.step(bolt, 40)
		bolts.append(K.entries(bolt, LogEntry.Kind.DAMAGE, "tidecaller")[0].amount)
	assert_eq(bolts, [FixedMath.apply_bp(18, 13000), 18], "30% more at a hero standing in water")


func test_the_tidecallers_specializations_pull_in_and_still_mana() -> void:
	var heroes: Array[UnitSetup] = [K.at(_still("a"), 2, 1), K.at(_still("b"), 4, 1)]
	var undertow: CombatSim = _sim(heroes, [K.foe(_kit("tidecaller", "undertow_tidecaller"), 3, 5)] as Array[UnitSetup])
	_fill_mana(undertow.unit_by_id("tidecaller"))
	K.step(undertow, 2)
	var target: String = K.entries(undertow, LogEntry.Kind.FIRE, "tidecaller")[0].target
	var pulled: Array = K.entries(undertow, LogEntry.Kind.PUSH, "tidecaller").map(func(entry: LogEntry) -> String: return entry.target)
	assert_eq(pulled, ["b" if target == "a" else "a"], "the other hero in the flood is pulled toward its middle (its target stands there)")
	var stilling: CombatSim = _sim([K.at(_still("a"), 2, 1), K.at(_still("b"), 4, 1)] as Array[UnitSetup], [K.foe(_kit("tidecaller", "stilling_tidecaller"), 3, 5)] as Array[UnitSetup])
	_root(stilling, stilling.units)
	_fill_mana(stilling.unit_by_id("tidecaller"))
	K.step(stilling, 4)
	assert_true(K.entries(stilling, LogEntry.Kind.STATUS_APPLIED, "tidecaller").any(func(entry: LogEntry) -> bool: return entry.status == "silence"), "no mana in the flood")


func test_a_drowned_warden_mends_and_hardens_in_water() -> void:
	var wet: CombatSim = _sim([K.at(_still("hero", {"atk": 0}), 3, 2)] as Array[UnitSetup], [K.foe(_kit("drowned_warden"), 3, 4)] as Array[UnitSetup], [Vector2i(3, 4)] as Array[Vector2i])
	var warden: UnitState = wet.unit_by_id("drowned_warden")
	_root(wet, wet.units)
	warden.hp = 100
	K.step(wet, 41)
	assert_eq(warden.hp, 100 + 2 * FixedMath.apply_bp(620, 200), "2% of its max HP a second")
	assert_eq(Statuses.damage_taken_bp(warden), -2000, "20% less damage in water")
	var dry: CombatSim = _sim([K.at(_still("hero", {"atk": 0}), 3, 2)] as Array[UnitSetup], [K.foe(_kit("drowned_warden"), 3, 4)] as Array[UnitSetup])
	_root(dry, dry.units)
	dry.unit_by_id("drowned_warden").hp = 100
	K.step(dry, 41)
	assert_eq(dry.unit_by_id("drowned_warden").hp, 100, "nothing on dry ground")
	assert_eq(Statuses.damage_taken_bp(dry.unit_by_id("drowned_warden")), 0)


func test_the_wardens_specializations_reach_further_and_silt_the_ground() -> void:
	var tidebound: UnitDef = _kit("drowned_warden", "tidebound_warden")
	assert_eq(tidebound.signature.effects[0].shape.size, 3, "its taunt reaches 3 hexes")
	var silted: CombatSim = _sim([K.at(_still("hero"), 3, 0)] as Array[UnitSetup], [K.foe(_kit("drowned_warden", "silted_warden"), 3, 5)] as Array[UnitSetup])
	K.step(silted, 200)
	assert_true(silted.has_water, "it leaves water where it walks")
	assert_true(silted.unit_by_id("drowned_warden").on_water, "and stands in its own pool")


# --- the new archetypes -------------------------------------------------------------

func test_a_drowned_bellringer_rings_thralls_from_the_water_four_at_most() -> void:
	var fight: CombatSim = _sim([K.at(_still("hero", {"atk": 0}), 3, 1)] as Array[UnitSetup], [K.foe(_kit("drowned_bellringer"), 3, 6)] as Array[UnitSetup],
		[Vector2i(0, 3), Vector2i(3, 3), Vector2i(7, 3)] as Array[Vector2i])
	K.step(fight, 321)
	var thralls: Array = _summoned(fight)
	assert_eq(thralls, ["drowned_thrall", "drowned_thrall#2"], "one each 8s")
	var first: LogEntry = fight.combat_log.of_kind(LogEntry.Kind.SUMMON)[0]
	assert_lt(ArenaPlane.distance(first.to_pos, fight.grid.center(3, 3)), 500, "out of the water nearest the hero")
	K.step(fight, 800)
	var standing: int = fight.units.filter(func(unit: UnitState) -> bool: return unit.alive and unit.def.id == "drowned_thrall").size()
	assert_lte(standing, 4, "no more than four stand at once")
	assert_true(fight.combat_log.of_kind(LogEntry.Kind.SUMMON).any(func(entry: LogEntry) -> bool: return entry.note == "enough stand"))


func test_the_bellringers_specializations_heal_its_thralls_or_ring_two() -> void:
	var tolling: UnitDef = _kit("drowned_bellringer", "tolling_bellringer")
	assert_eq(tolling.passives.map(func(part: PartDef) -> String: return part.id), ["tolling_ring"])
	var fight: CombatSim = _sim([K.at(_still("hero", {"atk": 0}), 3, 1)] as Array[UnitSetup], [K.foe(tolling, 3, 6)] as Array[UnitSetup], [Vector2i(3, 3)] as Array[Vector2i])
	K.step(fight, 161)
	assert_true(K.entries(fight, LogEntry.Kind.HEAL, "drowned_bellringer").all(func(entry: LogEntry) -> bool: return entry.target.begins_with("drowned_thrall")), "heals only its thralls")
	var deep: CombatSim = _sim([K.at(_still("hero", {"atk": 0}), 3, 1)] as Array[UnitSetup], [K.foe(_kit("drowned_bellringer", "deep_bell"), 3, 6)] as Array[UnitSetup], [Vector2i(3, 3)] as Array[Vector2i])
	K.step(deep, 241)
	assert_eq(_summoned(deep).size(), 2, "two at once, at 12s")


func test_a_glass_shambler_breaks_into_two_shards() -> void:
	var fight: CombatSim = _sim([K.at(_still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(_kit("glass_shambler"), 3, 4)] as Array[UnitSetup])
	K.step(fight, 2)
	fight.unit_by_id("glass_shambler").hp = 0
	K.step(fight, 2)
	assert_eq(_summoned(fight), ["glass_shard", "glass_shard#2"])
	assert_eq(fight.unit_by_id("glass_shard").max_hp, 224, "40% of its max HP")
	assert_false(fight.finished, "the shards fight on")


func test_jagged_shards_hit_harder_and_clouded_ones_are_born_hidden() -> void:
	assert_eq(_kit("jagged_shard").stats.get_stat(UnitStats.Stat.ATK), 23, "30% more than a Glass Shard's 18")
	var fight: CombatSim = _sim([K.at(_still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(_kit("glass_shambler", "clouded_glass"), 3, 4)] as Array[UnitSetup])
	K.step(fight, 2)
	fight.unit_by_id("glass_shambler").hp = 0
	K.step(fight, 3)
	assert_eq(_summoned(fight), ["clouded_shard", "clouded_shard#2"])
	assert_true(Statuses.is_stealthed(fight.unit_by_id("clouded_shard")), "Stealthed as it's born")
	K.step(fight, 60)
	assert_false(Statuses.is_stealthed(fight.unit_by_id("clouded_shard")), "for a moment only")
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "clouded_shard").size(), 1, "once")


# --- the elites and the boss ----------------------------------------------------------

func test_a_matrons_shard_reforms_on_water_and_stays_broken_on_dry_ground() -> void:
	for wet: bool in [true, false]:
		var water: Array[Vector2i] = []
		if wet:
			water = lake()
		var fight: CombatSim = _sim([K.at(_still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(_kit("brood_shambler"), 3, 4)] as Array[UnitSetup], water)
		K.step(fight, 2)
		fight.unit_by_id("brood_shambler").hp = 0
		K.step(fight, 2)
		assert_eq(_summoned(fight), ["matron_shard", "matron_shard#2"])
		fight.unit_by_id("matron_shard").hp = 0
		K.step(fight, 82)
		assert_eq(_summoned(fight).has("glass_shambler"), wet, "on water it reforms" if wet else "on dry ground it stays broken")


func test_the_choir_tidecaller_raises_the_water() -> void:
	var fight: CombatSim = _sim([K.at(_still("hero", {"atk": 0}), 3, 0)] as Array[UnitSetup], [K.foe(_kit("choir_tidecaller"), 3, 6)] as Array[UnitSetup], [Vector2i(3, 3)] as Array[Vector2i])
	_root(fight, fight.units)
	K.step(fight, 301)
	var spreads: Array[LogEntry] = fight.combat_log.of_kind(LogEntry.Kind.WATER).filter(func(entry: LogEntry) -> bool: return entry.source_ability == "rising_tide")
	assert_eq(spreads.size(), 1, "every 15s")
	assert_true(spreads[0].note.begins_with("spreads to"))
	assert_true(fight.water.has_hex(fight.grid, 3, 2), "the first pool is a hex wider")


func test_the_mournwater_pulls_drains_and_floods() -> void:
	var fight: CombatSim = _sim([K.at(_still("wet", {"atk": 0}), 3, 1), K.at(_still("dry", {"atk": 0}), 6, 0)] as Array[UnitSetup],
		[K.foe(_kit("mournwater"), 3, 6)] as Array[UnitSetup], [Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4), Vector2i(3, 5), Vector2i(3, 6)] as Array[Vector2i])
	var boss: UnitState = fight.unit_by_id("mournwater")
	K.step(fight, 161)
	var pulled: Array = K.entries(fight, LogEntry.Kind.PUSH, "mournwater").map(func(entry: LogEntry) -> String: return entry.target)
	assert_eq(pulled, ["wet"], "Undertow at 8s: only the hero on water")
	boss.hp = boss.max_hp / 2
	K.step(fight, 2)
	assert_eq(fight.combat_log.of_kind(LogEntry.Kind.PHASE).map(func(entry: LogEntry) -> String: return entry.note), ["The Mere Drains"])
	assert_true(fight.combat_log.of_kind(LogEntry.Kind.WATER).any(func(entry: LogEntry) -> bool: return entry.note.begins_with("drains")), "the water drains")
	for hex: Vector2i in fight.water.hexes:
		assert_lte(ArenaPlane.distance(fight.grid.center(hex.x, hex.y), boss.pos), 1000, "back round her")
	K.step(fight, 220)
	assert_true(_summoned(fight).has("glass_shambler"), "Glass Shamblers crawl from the drained ground")
	boss.hp = boss.max_hp / 5
	K.step(fight, 2)
	assert_true(fight.combat_log.of_kind(LogEntry.Kind.WATER).any(func(entry: LogEntry) -> bool: return entry.note == "floods the whole board"), "the Flood")
	assert_true(fight.collapse_warned > 0, "and the rift closes early")
	assert_true(fight.unit_by_id("dry").on_water, "nowhere stays dry")
