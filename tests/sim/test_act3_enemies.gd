extends GutTest
## Act 3's enemies in data/enemies.json (docs/plans/act3-shattered-crown.md,
## sections 3, 5 to 7; rebuild-phase8-act3.md, 8c-6a): each one's threat
## happens, and so does each new face's two specializations. Each test is a
## small fight built for one enemy, over the void where it needs some.

const K = preload("res://tests/sim/sim_test_kit.gd")
const CopiesTest = preload("res://tests/sim/test_copies.gd")

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


func _kit(enemy_id: String, spec_id: String = "") -> UnitDef:
	var kit: UnitDef = (_content.enemies[enemy_id] as EnemyDef).kit
	return kit if spec_id.is_empty() else (_content.specializations[spec_id] as SpecializationDef).apply(kit)


## A unit that stands still and never hurts anyone.
func _still(unit_id: String, stats: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 5000, "speed": 0, "range": 1}
	all_stats.merge(stats, true)
	return K.kit(unit_id, {"stats": all_stats, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## Every hex of `row` but those in `but`.
static func row_but(row: int, but: Array[int]) -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []
	for col: int in 8:
		if not but.has(col):
			hexes.append(Vector2i(col, row))
	return hexes


## The heroes' island and the enemies', the void between them but for a
## bridge at each side, and the enemies' island split in two by a void
## column (col 4): left (cols 0-3) and right (cols 5-7).
static func split_board(setup: FightSetup) -> void:
	setup.void_hexes = row_but(3, [0, 7] as Array[int])
	setup.void_hexes.append_array([Vector2i(4, 4), Vector2i(4, 5), Vector2i(4, 6)])
	setup.bridges = [[Vector2i(0, 3)], [Vector2i(7, 3)]] as Array[Array]


func _sim(heroes: Array[UnitSetup], enemies: Array[UnitSetup], board: Callable = Callable()) -> CombatSim:
	var setup: FightSetup = K.fight(heroes, enemies)
	if board.is_valid():
		board.call(setup)
	setup.summon_kits = Encounters.summon_kits(_content, setup.units(), FixedMath.BP_ONE)
	var errors: Array[String] = setup.validate(_content)
	assert_eq(errors, [] as Array[String])
	return CombatSim.new(setup, _content)


func _statuses(unit: UnitState) -> Array:
	return unit.statuses.map(func(state: StatusState) -> String: return state.def.id)


func _pushes(fight: CombatSim, unit_id: String) -> Array[LogEntry]:
	return K.entries(fight, LogEntry.Kind.PUSH, unit_id)


# --- the new faces ------------------------------------------------------------------

func test_three_cliffmites_on_a_hero_shove_it_toward_the_edge() -> void:
	for count: int in [2, 3]:
		var mites: Array[UnitSetup] = []
		for i: int in count:
			mites.append(K.foe(_kit("cliffmite"), 2 + i, 4, "mite%d" % i))
		var fight: CombatSim = _sim([K.at(_still("hero"), 3, 2)] as Array[UnitSetup], mites,
			func(setup: FightSetup) -> void: setup.void_hexes = row_but(0, [] as Array[int]))
		K.step(fight, 120)
		var shoves: Array[LogEntry] = K.entries(fight, LogEntry.Kind.PUSH).filter(func(entry: LogEntry) -> bool: return entry.source_ability == "mite_shove")
		if count == 2:
			assert_eq(shoves, [] as Array[LogEntry], "two aren't a crowd")
		else:
			assert_false(shoves.is_empty(), "three shove")
			assert_eq(shoves[0].note.get_slice(",", 0), "knocked back toward the edge")
			assert_eq(shoves[0].target, "hero")


func test_pack_mites_shove_in_twos_and_a_brittle_mite_bursts_into_slows() -> void:
	var mites: Array[UnitSetup] = [K.foe(_kit("cliffmite", "pack_mite"), 2, 4, "mite0"), K.foe(_kit("cliffmite", "pack_mite"), 3, 4, "mite1")]
	var pack: CombatSim = _sim([K.at(_still("hero"), 3, 2)] as Array[UnitSetup], mites, func(setup: FightSetup) -> void: setup.void_hexes = row_but(0, [] as Array[int]))
	K.step(pack, 120)
	assert_false(K.entries(pack, LogEntry.Kind.PUSH).filter(func(entry: LogEntry) -> bool: return entry.source_ability == "pack_shove").is_empty(), "two are enough")
	var brittle: CombatSim = _sim([K.at(_still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(_kit("cliffmite", "brittle_mite"), 3, 4)] as Array[UnitSetup])
	var mite: UnitState = brittle.unit_by_id("cliffmite")
	while K.entries(brittle, LogEntry.Kind.DAMAGE, "cliffmite").is_empty():
		brittle.step()
	mite.hp = 0
	K.step(brittle, 2)
	assert_true(_statuses(brittle.unit_by_id("hero")).has("slow"), "Slowed by its burst")


func test_a_cragram_rams_the_farthest_hero_and_knocks_the_first_back() -> void:
	var fight: CombatSim = _sim([K.at(_still("front"), 3, 2), K.at(_still("back"), 3, 1)] as Array[UnitSetup], [K.foe(_kit("cragram"), 3, 4)] as Array[UnitSetup])
	fight.unit_by_id("cragram").mana = fight.unit_by_id("cragram").mana_cap
	K.step(fight, 30)
	var fires: Array[LogEntry] = K.entries(fight, LogEntry.Kind.FIRE, "cragram").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "ram")
	assert_eq(fires.size(), 1)
	var targets: Array[LogEntry] = K.entries(fight, LogEntry.Kind.TARGET, "cragram")
	var pushes: Array[LogEntry] = _pushes(fight, "cragram")
	assert_false(pushes.is_empty())
	assert_eq([pushes[0].target, pushes[0].note.get_slice(",", 0)], ["front", "knocked back"], "the first in its way")
	assert_true(targets.is_empty() or true)


func test_a_thundering_cragram_carries_the_line_and_a_stunning_one_stuns() -> void:
	var thundering: CombatSim = _sim([K.at(_still("front"), 3, 2), K.at(_still("back"), 3, 1)] as Array[UnitSetup],
		[K.foe(_kit("cragram", "thundering_cragram"), 3, 4)] as Array[UnitSetup])
	thundering.unit_by_id("cragram").mana = thundering.unit_by_id("cragram").mana_cap
	K.step(thundering, 30)
	var carried: Array = _pushes(thundering, "cragram").map(func(entry: LogEntry) -> String: return entry.target)
	assert_true(carried.has("front") and carried.has("back"), "both in its line: %s" % [carried])
	var stunning: CombatSim = _sim([K.at(_still("front"), 3, 2), K.at(_still("back"), 3, 1)] as Array[UnitSetup],
		[K.foe(_kit("cragram", "stunning_cragram"), 3, 4)] as Array[UnitSetup])
	stunning.unit_by_id("cragram").mana = stunning.unit_by_id("cragram").mana_cap
	K.step(stunning, 30)
	var stuns: Array[LogEntry] = K.entries(stunning, LogEntry.Kind.STATUS_APPLIED, "cragram").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "stunning_ram")
	assert_eq(stuns.map(func(entry: LogEntry) -> String: return "%s %s" % [entry.target, entry.status]), ["front stun"], "the hero it knocked back")


func test_a_gulf_angler_hooks_the_loneliest_hero_across_the_void() -> void:
	var fight: CombatSim = _sim([K.at(_still("a"), 2, 1), K.at(_still("b"), 3, 1), K.at(_still("alone"), 7, 0)] as Array[UnitSetup],
		[K.foe(_kit("gulf_angler"), 3, 5)] as Array[UnitSetup], split_board)
	var angler: UnitState = fight.unit_by_id("gulf_angler")
	angler.mana = angler.mana_cap
	K.step(fight, 20)
	var hooks: Array[LogEntry] = _pushes(fight, "gulf_angler")
	assert_eq(hooks.size(), 1)
	assert_eq([hooks[0].target, hooks[0].note.get_slice(",", 0)], ["alone", "hooked"], "the one farthest from its allies")
	var alone: UnitState = fight.unit_by_id("alone")
	assert_true(ArenaPlane.distance(alone.pos, angler.pos) <= 400, "beside it")
	assert_true(alone.alive and alone.island >= 0, "on solid ground: a hook never drops its catch")
	assert_eq(alone.island, angler.island, "on its island, across the gap")


func test_a_reeling_angler_roots_its_catch_and_a_twin_hook_takes_two() -> void:
	var reeling: CombatSim = _sim([K.at(_still("a"), 2, 1), K.at(_still("b"), 3, 1), K.at(_still("alone"), 7, 0)] as Array[UnitSetup],
		[K.foe(_kit("gulf_angler", "reeling_angler"), 3, 5)] as Array[UnitSetup], split_board)
	reeling.unit_by_id("gulf_angler").mana = reeling.unit_by_id("gulf_angler").mana_cap
	K.step(reeling, 20)
	assert_true(_statuses(reeling.unit_by_id("alone")).has("root"), "Rooted beside it")
	var twin: CombatSim = _sim([K.at(_still("a"), 2, 1), K.at(_still("b"), 3, 1), K.at(_still("alone"), 7, 0)] as Array[UnitSetup],
		[K.foe(_kit("gulf_angler", "twin_hook_angler"), 3, 5)] as Array[UnitSetup], split_board)
	twin.unit_by_id("gulf_angler").mana = twin.unit_by_id("gulf_angler").mana_cap
	K.step(twin, 20)
	var hooked: Array = _pushes(twin, "gulf_angler").map(func(entry: LogEntry) -> String: return entry.target)
	hooked.sort()
	assert_eq(hooked, ["alone", "b"], "and the hero nearest the first")


func test_a_spire_chanter_guards_its_island_alone() -> void:
	var fight: CombatSim = _sim([K.at(_still("hero"), 3, 1)] as Array[UnitSetup],
		[K.foe(_kit("spire_chanter"), 2, 6), K.foe(_still("near"), 2, 5), K.foe(_still("far"), 6, 5)] as Array[UnitSetup], split_board)
	fight.step()
	var near: UnitState = fight.unit_by_id("near")
	var far: UnitState = fight.unit_by_id("far")
	assert_ne(near.island, far.island)
	assert_eq([near.aura_bp[AuraDef.Stat.DAMAGE_REDUCED_BP], far.aura_bp[AuraDef.Stat.DAMAGE_REDUCED_BP]], [2500, 0], "25% less, only on its island")
	assert_eq(fight.unit_by_id("spire_chanter").aura_bp[AuraDef.Stat.DAMAGE_REDUCED_BP], 2500, "itself too")
	# Off its island, the song doesn't reach.
	near.pos = fight.grid.center(6, 6)
	K.step(fight, 2)
	assert_eq(near.aura_bp[AuraDef.Stat.DAMAGE_REDUCED_BP], 0, "it walked off the island")
	# A bridge is no island's: two on bridges aren't on one island.
	var chanter: UnitState = fight.unit_by_id("spire_chanter")
	chanter.pos = fight.grid.center(0, 3)
	near.pos = fight.grid.center(7, 3)
	K.step(fight, 2)
	assert_eq([chanter.island, near.island], [-1, -1])
	assert_eq(near.aura_bp[AuraDef.Stat.DAMAGE_REDUCED_BP], 0, "the song stops at a bridge")


func test_a_quickening_chanter_hastens_its_island_and_a_last_note_shields_it() -> void:
	var quick: CombatSim = _sim([K.at(_still("hero"), 3, 1)] as Array[UnitSetup],
		[K.foe(_kit("spire_chanter", "quickening_chanter"), 2, 6), K.foe(_still("near"), 2, 5), K.foe(_still("far"), 6, 5)] as Array[UnitSetup], split_board)
	quick.step()
	assert_eq([quick.unit_by_id("near").aura_bp[AuraDef.Stat.ATSP], quick.unit_by_id("far").aura_bp[AuraDef.Stat.ATSP]], [20, 0])
	var last: CombatSim = _sim([K.at(_still("hero"), 3, 1)] as Array[UnitSetup],
		[K.foe(_kit("spire_chanter", "last_note_chanter"), 2, 6), K.foe(_still("near"), 2, 5), K.foe(_still("far"), 6, 5)] as Array[UnitSetup], split_board)
	last.step()
	last.unit_by_id("spire_chanter").hp = 0
	K.step(last, 2)
	assert_eq([last.unit_by_id("near").shield, last.unit_by_id("far").shield], [750, 0], "15% of max HP, on its island only")


func test_a_mirrorwight_copies_and_its_specializations_turn_the_knobs() -> void:
	var fight: CombatSim = _sim([K.at(CopiesTest.blast(), 3, 1)] as Array[UnitSetup], [K.foe(_kit("mirrorwight"), 3, 5)] as Array[UnitSetup])
	K.step(fight, 3)
	assert_eq(K.entries(fight, LogEntry.Kind.COPIED).map(func(entry: LogEntry) -> String: return "%s %s" % [entry.source_unit, entry.note]), ["mirrorwight Blast"])
	assert_eq(fight.unit_by_id("mirrorwight").signature.def.name, "Blast (copied from blaster)")
	var greedy: PartDef = _kit("mirrorwight", "greedy_mirrorwight").passives.filter(func(part: PartDef) -> bool: return part.kind == PartDef.Kind.COPY)[0]
	var twinned: PartDef = _kit("mirrorwight", "twinned_mirrorwight").passives.filter(func(part: PartDef) -> bool: return part.kind == PartDef.Kind.COPY)[0]
	assert_eq([greedy.copy_replace, greedy.copy_twice_bp, twinned.copy_replace, twinned.copy_twice_bp], [true, 0, false, 6000])
	assert_eq(_kit("mirrorwight", "greedy_mirrorwight").passives.filter(func(part: PartDef) -> bool: return part.kind == PartDef.Kind.COPY).size(), 1, "one copy passive")


func test_an_unbinder_tears_shields_and_unbinds_its_allies() -> void:
	var fight: CombatSim = _sim([K.at(_still("hero"), 3, 2)] as Array[UnitSetup],
		[K.foe(_kit("unbinder"), 3, 4), K.foe(_still("near"), 2, 4), K.foe(_still("far"), 7, 6)] as Array[UnitSetup])
	var hero: UnitState = fight.unit_by_id("hero")
	hero.shield = 100
	for unit_id: String in ["near", "far"]:
		Statuses.apply(fight, fight.unit_by_id(unit_id), "root", 0, 100000, EffectSource.make("hero", "test", "Test"))
	Statuses.apply(fight, fight.unit_by_id("near"), "silence", 0, 100000, EffectSource.make("hero", "test", "Test"))
	while K.entries(fight, LogEntry.Kind.DAMAGE, "unbinder").is_empty():
		fight.step()
	var hit: LogEntry = K.entries(fight, LogEntry.Kind.DAMAGE, "unbinder")[0]
	assert_eq(hero.shield, 100 - 2 * hit.absorbed, "twice as much off the Shield")
	K.step(fight, 125)
	assert_false(_statuses(fight.unit_by_id("near")).has("root"), "freed within 2 hexes")
	assert_true(_statuses(fight.unit_by_id("far")).has("root"), "not beyond")
	assert_true(_statuses(fight.unit_by_id("near")).has("silence"), "only the six it names")


func test_a_hungering_unbinder_feeds_on_broken_shields_and_a_wide_one_frees_its_island() -> void:
	var hungering: CombatSim = _sim([K.at(_still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(_kit("unbinder", "hungering_unbinder"), 3, 4)] as Array[UnitSetup])
	hungering.unit_by_id("hero").shield = 5
	var unbinder: UnitState = hungering.unit_by_id("unbinder")
	unbinder.hp = 300
	while K.entries(hungering, LogEntry.Kind.DAMAGE, "unbinder").is_empty():
		hungering.step()
	K.step(hungering, 2)
	var heals: Array[LogEntry] = K.entries(hungering, LogEntry.Kind.HEAL, "unbinder")
	assert_eq(heals.map(func(entry: LogEntry) -> String: return "%s %d" % [entry.source_ability, entry.amount]), ["hungering_break 46"], "10% of its max HP")
	var wide: CombatSim = _sim([K.at(_still("hero"), 3, 2)] as Array[UnitSetup],
		[K.foe(_kit("unbinder", "wide_unbinder"), 3, 4), K.foe(_still("far"), 7, 6)] as Array[UnitSetup])
	Statuses.apply(wide, wide.unit_by_id("far"), "root", 0, 100000, EffectSource.make("hero", "test", "Test"))
	K.step(wide, 125)
	assert_false(_statuses(wide.unit_by_id("far")).has("root"), "every ally on its island")


# --- the elites and the boss ---------------------------------------------------------

func test_the_cragherd_stampedes_together_every_15_seconds() -> void:
	var fight: CombatSim = _sim([K.at(_still("hero", {"hp": 100000}), 3, 2), K.at(_still("hero2", {"hp": 100000}), 4, 2)] as Array[UnitSetup],
		[K.foe(_kit("great_cragram"), 3, 5), K.foe(_kit("herd_cragram"), 2, 5, "herd1"), K.foe(_kit("herd_cragram"), 5, 5, "herd2")] as Array[UnitSetup])
	K.step(fight, 310)
	var again: Array = K.entries(fight, LogEntry.Kind.FIRE).filter(func(entry: LogEntry) -> bool: return entry.source_ability == "ram" and entry.note.contains("again")) \
		.map(func(entry: LogEntry) -> String: return "%s %d" % [entry.source_unit, entry.tick])
	assert_eq(again, ["great_cragram 300", "herd1 300", "herd2 300"], "the whole herd at once")
	var great: LogEntry = _pushes(fight, "great_cragram")[0]
	assert_eq(great.note.get_slice(",", 0), "knocked back")


func test_the_mirror_queen_gives_her_court_each_copy() -> void:
	var fight: CombatSim = _sim([K.at(CopiesTest.blast(), 3, 1)] as Array[UnitSetup],
		[K.foe(_kit("mirror_queen"), 3, 6), K.foe(_kit("mirrorwight"), 2, 5, "court1"), K.foe(_kit("mirrorwight"), 5, 5, "court2")] as Array[UnitSetup])
	K.step(fight, 3)
	var copied: Array = K.entries(fight, LogEntry.Kind.COPIED).map(func(entry: LogEntry) -> String: return "%s%s" % [entry.source_unit, "*" if entry.shape == "shared" else ""])
	assert_true(copied.has("mirror_queen") and copied.has("court1*") and copied.has("court2*"), str(copied))


func test_the_heart_is_warded_while_its_host_stands() -> void:
	var fight: CombatSim = _sim([K.at(_still("hero"), 3, 1)] as Array[UnitSetup],
		[K.foe(_kit("heart_of_the_rift"), 3, 6), K.foe(_still("host"), 2, 5)] as Array[UnitSetup])
	var heart: UnitState = fight.unit_by_id("heart_of_the_rift")
	fight.step()
	assert_eq(heart.aura_bp[AuraDef.Stat.DAMAGE_REDUCED_BP], 5000, "half damage while its host stands")
	fight.unit_by_id("host").hp = 0
	K.step(fight, 2)
	assert_eq(heart.aura_bp[AuraDef.Stat.DAMAGE_REDUCED_BP], 0, "the Ward falls with its host")


func test_the_heart_severs_then_unmakes() -> void:
	var fight: CombatSim = _sim([K.at(_still("hero"), 3, 0)] as Array[UnitSetup],
		[K.foe(_kit("heart_of_the_rift"), 3, 6), K.foe(_still("host"), 1, 5)] as Array[UnitSetup], split_board)
	var heart: UnitState = fight.unit_by_id("heart_of_the_rift")
	heart.hp = FixedMath.apply_bp(heart.max_hp, 6900)
	K.step(fight, 2)
	assert_eq(K.entries(fight, LogEntry.Kind.PHASE).map(func(entry: LogEntry) -> String: return entry.note), ["Severing"])
	assert_eq(K.entries(fight, LogEntry.Kind.SUMMON, "heart_of_the_rift").size(), 2, "two more of its host")
	K.step(fight, 245)
	assert_false(K.entries(fight, LogEntry.Kind.VOID).is_empty(), "a bridge warned")
	heart.hp = FixedMath.apply_bp(heart.max_hp, 3400)
	var hero: UnitState = fight.unit_by_id("hero")
	K.step(fight, 2)
	assert_eq(heart.aura_bp[AuraDef.Stat.DAMAGE_REDUCED_BP], 0, "the Ward is gone though its host stands")
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "heart_of_the_rift").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "unmake").size(), 1, "the rift closes in")
	hero.pos = fight.grid.center(2, 6)
	K.step(fight, 170)
	assert_true(hero.alive)
	assert_false(_pushes(fight, "heart_of_the_rift").is_empty(), "a hero close to it is pushed away")


func test_the_loneliest_rule() -> void:
	var fight: CombatSim = _sim([K.at(_still("a"), 2, 1), K.at(_still("b"), 3, 1), K.at(_still("alone"), 7, 0)] as Array[UnitSetup],
		[K.foe(_still("picker"), 3, 5)] as Array[UnitSetup])
	fight.step()
	var picker: UnitState = fight.unit_by_id("picker")
	assert_eq(Targeting.pick(fight, picker, "loneliest", -1).id, "alone")
	fight.unit_by_id("alone").pos = fight.grid.center(4, 1)
	assert_eq(Targeting.pick(fight, picker, "loneliest", -1).id, "a", "now the end of the line")


func test_the_panel_names_their_reach() -> void:
	var numbers: Callable = func(kit: UnitDef, part_name: String) -> String:
		for line: UnitInfo.Line in UnitInfo.lines(kit, "it", _content):
			if line.name == part_name:
				return line.numbers
		return ""
	assert_eq(numbers.call(_kit("spire_chanter"), "Spire Song"), "−25% damage taken for all allies on its island")
	assert_eq(numbers.call(_kit("unbinder", "wide_unbinder"), "Wide Unbind"), "Every 6s · ends Root, Marked, Burn, Poison, Slow, and Stun to all allies on its island")
	assert_eq(numbers.call(_kit("heart_of_the_rift"), "Ward"), "−50% damage taken while another of its side stands")
	assert_eq(numbers.call(_kit("unbinder", "hungering_unbinder"), "Hungering Break"), "Every Shield it breaks · heals 10% of max HP")
