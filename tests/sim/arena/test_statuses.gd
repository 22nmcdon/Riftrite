extends GutTest
## Statuses (docs/plans/rebuild-phase1-arena-sim.md, section 8).

const K = preload("res://tests/sim/sim_test_kit.gd")


func _dummy(hp: int = 10000, extra: Dictionary = {}) -> UnitDef:
	var stats: Dictionary = {"hp": hp, "speed": 0, "range": 1}
	stats.merge(extra, true)
	return K.kit("dummy", {"stats": stats, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## A unit that stands and swings at anything within 2 hexes, landing at once.
func _swinger(effects: Array, stats: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 10000, "speed": 0, "range": 2}
	all_stats.merge(stats, true)
	return K.kit("swinger", {"stats": all_stats, "basic_attack": {"shot": false, "effects": effects}})


func _duel(hero: UnitDef, enemy: UnitDef = _dummy()) -> CombatSim:
	return K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(enemy, 3, 4)] as Array[UnitSetup]))


func _source(unit_id: String = "tester") -> EffectSource:
	return EffectSource.make(unit_id, "test", "Test")


## Adds a made-up status to the fight's content, after the real ones.
func _add_status(fight: CombatSim, def: StatusDef) -> void:
	fight.content.statuses[def.id] = def
	fight.content.status_ids.append(def.id)


func _status(id: String, kind: StatusDef.Kind) -> StatusDef:
	var def := StatusDef.new()
	def.id = id
	def.name = id
	def.kind = kind
	return def


# --- damage over time ----------------------------------------------------------

func test_burn_ticks_fades_and_is_credited() -> void:
	var fight: CombatSim = _duel(_swinger([{"type": "apply_status", "status": "burn", "stacks": 20, "target": "target"}]))
	K.step(fight, 20)
	var applied: LogEntry = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "swinger")[0]
	assert_eq([applied.amount, applied.stacks, applied.status], [20, 20, "burn"])
	K.step(fight, 10)
	var burns: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_DAMAGE, "swinger")
	assert_eq(burns.size(), 1, "Burn ticks every 0.5s")
	assert_eq([burns[0].amount, burns[0].source_ability_name], [20, "Strike"], "20 stacks x 1, credited to the attack")
	assert_eq(Statuses.find(fight.units[1], "burn").total_stacks(), 19, "then loses 5% of its stacks, rounded up")


func test_a_fall_to_damage_over_time_names_it() -> void:
	var fight: CombatSim = _duel(_dummy())
	var target: UnitState = fight.units[1]
	target.hp = 3
	Statuses.apply(fight, target, "poison", 5, 0, _source())
	K.step(fight, 20)
	assert_eq(K.entries(fight, LogEntry.Kind.DEATH)[0].note, "last hit: Poison from tester · Test")


func test_poison_skips_shield_and_bleed_shreds_def() -> void:
	var fight: CombatSim = _duel(_dummy(), _dummy(10000, {"def": 10}))
	var target: UnitState = fight.units[1]
	target.shield = 100
	Statuses.apply(fight, target, "poison", 5, 0, _source())
	Statuses.apply(fight, target, "bleed", 4, 0, _source())
	assert_eq(target.defense(), 6, "each Bleed stack lowers DEF by 1")
	K.step(fight, 20)
	assert_eq(target.hp, 10000 - 5, "Poison went straight to HP")
	assert_eq(target.shield, 100 - 4, "Bleed hit the Shield")


func test_heals_weaken_damage_over_time_less_each_time() -> void:
	var fight: CombatSim = _duel(_dummy())
	var target: UnitState = fight.units[1]
	target.hp = 5000
	Statuses.apply(fight, target, "poison", 100, 0, _source())
	EffectRunner.heal(fight, target, 10, _source())
	assert_eq(Statuses.find(target, "poison").total_stacks(), 90, "a heal strips 10%")
	EffectRunner.heal(fight, target, 10, _source())
	assert_eq(Statuses.find(target, "poison").total_stacks(), 85, "a second heal within 1s strips half as much (5% of 90, rounded)")
	var cleanse: CombatSim = _duel(_swinger([{"type": "damage", "amount": 0, "target": "target"}, {"type": "cleanse", "amount_bp": 5000, "target": "target"}]))
	Statuses.apply(cleanse, cleanse.units[1], "burn", 40, 0, _source())
	K.step(cleanse, 20)
	var reduced: LogEntry = K.entries(cleanse, LogEntry.Kind.STATUS_REDUCED)[0]
	assert_eq(reduced.note, "cleansed by swinger · Strike")
	assert_lt(Statuses.find(cleanse.units[1], "burn").total_stacks(), 21)


# --- timed statuses ------------------------------------------------------------------

func test_timed_statuses_last_their_duration_and_refresh() -> void:
	var fight: CombatSim = _duel(_dummy())
	var target: UnitState = fight.units[1]
	Statuses.apply(fight, target, "silence", 1, 0, _source())
	assert_eq(Statuses.find(target, "silence").ends_at, 60, "3s from now")
	K.step(fight, 30)
	Statuses.apply(fight, target, "silence", 1, 0, _source())
	assert_eq(Statuses.find(target, "silence").ends_at, 90, "a new one refreshes it")
	Statuses.apply(fight, target, "silence", 1, 10, _source())
	assert_eq(Statuses.find(target, "silence").ends_at, 40, "an effect can give its own duration (in ticks)")
	K.step(fight, 9)
	assert_true(Statuses.has_kind(target, StatusDef.Kind.SILENCE))
	fight.step()
	assert_false(Statuses.has_kind(target, StatusDef.Kind.SILENCE))
	var ended: LogEntry = K.entries(fight, LogEntry.Kind.STATUS_ENDED)[0]
	assert_string_contains(ended.to_text(), "Silence on dummy#2 ends")
	var applied: LogEntry = K.entries(fight, LogEntry.Kind.STATUS_APPLIED)[0]
	assert_string_contains(applied.to_text(), "tester · Test applies Silence to dummy#2 until 3.00s")


func test_root_holds_still_but_lets_it_attack() -> void:
	var walker: UnitDef = K.kit("walker", {"stats": {"hp": 10000, "speed": 2, "range": 1}})
	var fight: CombatSim = K.sim(K.fight([K.at(walker, 3, 0)] as Array[UnitSetup], [K.foe(_dummy(), 3, 6)] as Array[UnitSetup]))
	K.step(fight, 5)
	var at: Vector2i = fight.units[0].pos
	Statuses.apply(fight, fight.units[0], "root", 1, 0, _source())
	K.step(fight, 20)
	assert_eq(fight.units[0].pos, at, "rooted for 1.5s")
	assert_eq(K.entries(fight, LogEntry.Kind.STOP, "walker")[0].note, "rooted")
	K.step(fight, 20)
	assert_ne(fight.units[0].pos, at, "walking again")
	var stunner: CombatSim = _duel(_swinger([{"type": "apply_status", "status": "stun", "duration_ms": 500, "target": "target"}]))
	K.step(stunner, 20)
	var stun: LogEntry = K.entries(stunner, LogEntry.Kind.STATUS_APPLIED, "swinger")[0]
	assert_eq(stun.end_tick, stun.tick + 10, "the effect's own 0.5s, not Stun's 1s")
	var rooted_swinger: CombatSim = _duel(_swinger([{"type": "damage", "amount": 10, "target": "target"}]))
	Statuses.apply(rooted_swinger, rooted_swinger.units[0], "root", 1, 1000, _source())
	K.step(rooted_swinger, 20)
	assert_eq(K.entries(rooted_swinger, LogEntry.Kind.DAMAGE, "swinger").size(), 1, "a rooted unit still attacks")


func test_stun_stops_everything_and_its_cooldown_waits() -> void:
	var fight: CombatSim = _duel(_swinger([{"type": "damage", "amount": 10, "target": "target"}]))
	K.step(fight, 10)
	Statuses.apply(fight, fight.units[0], "stun", 1, 0, _source())
	K.step(fight, 20)
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "swinger").size(), 0, "no attack while stunned")
	K.step(fight, 8)
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "swinger").size(), 0, "its cooldown was paused, not running")
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "swinger")[0].tick, 39, "10 ticks of cooldown before the stun (ticks 1-10), 10 after it ends (ticks 30-39)")
	var walker: UnitDef = K.kit("walker", {"stats": {"hp": 10000, "speed": 2, "range": 1}})
	var walking: CombatSim = K.sim(K.fight([K.at(walker, 3, 0)] as Array[UnitSetup], [K.foe(_dummy(), 3, 6)] as Array[UnitSetup]))
	K.step(walking, 3)
	Statuses.apply(walking, walking.units[0], "stun", 1, 0, _source())
	var at: Vector2i = walking.units[0].pos
	K.step(walking, 10)
	assert_eq(walking.units[0].pos, at)
	assert_eq(K.entries(walking, LogEntry.Kind.STOP, "walker")[0].note, "stunned")


func test_slow_shortens_steps_and_stretches_cooldowns() -> void:
	var walker: UnitDef = K.kit("walker", {"stats": {"hp": 10000, "speed": 2, "range": 1}})
	var fight: CombatSim = K.sim(K.fight([K.at(walker, 3, 0)] as Array[UnitSetup], [K.foe(_dummy(), 3, 6)] as Array[UnitSetup]))
	Statuses.apply(fight, fight.units[0], "slow", 1, 0, _source())
	var at: Vector2i = fight.units[0].pos
	fight.step()
	assert_eq(fight.units[0].pos - at, Vector2i(0, 70), "30% slower: 70 a tick instead of 100")
	var swinging: CombatSim = _duel(_swinger([{"type": "damage", "amount": 10, "target": "target"}]))
	Statuses.apply(swinging, swinging.units[0], "slow", 1, 20, _source())
	K.step(swinging, 40)
	assert_eq(K.entries(swinging, LogEntry.Kind.DAMAGE, "swinger")[0].tick, 26, "7000 bp a tick for 20 ticks, then full speed")


func test_the_strongest_slow_and_mark_win() -> void:
	var fight: CombatSim = _duel(_dummy())
	var deep: StatusDef = _status("deep_slow", StatusDef.Kind.SLOW)
	deep.slow_bp = 6000
	deep.duration_ticks = 40
	_add_status(fight, deep)
	var deep_mark: StatusDef = _status("deep_mark", StatusDef.Kind.MARKED)
	deep_mark.damage_taken_bp = 3000
	deep_mark.duration_ticks = 40
	_add_status(fight, deep_mark)
	Statuses.apply(fight, fight.units[1], "slow", 1, 0, _source())
	Statuses.apply(fight, fight.units[1], "deep_slow", 1, 0, _source())
	assert_eq(Statuses.slow_bp(fight.units[1]), 6000, "no stacking: the strongest")
	Statuses.apply(fight, fight.units[1], "marked", 1, 0, _source())
	assert_eq(Statuses.damage_taken_bp(fight.units[1]), 1500)
	Statuses.apply(fight, fight.units[1], "deep_mark", 1, 0, _source())
	assert_eq(Statuses.damage_taken_bp(fight.units[1]), 3000, "no stacking: the strongest")


func test_marked_takes_more_from_everything() -> void:
	var fight: CombatSim = _duel(_swinger([{"type": "damage", "amount": 100, "target": "target"}]))
	Statuses.apply(fight, fight.units[1], "marked", 1, 0, _source())
	Statuses.apply(fight, fight.units[1], "poison", 20, 0, _source())
	K.step(fight, 20)
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "swinger")[0].amount, 115, "+15% on hits")
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_DAMAGE)[0].amount, 23, "and on damage over time")


func test_taunt_turns_a_unit_on_the_taunter() -> void:
	var hunter: UnitDef = K.kit("hunter", {"stats": {"hp": 10000, "speed": 2, "range": 1}, "basic_attack": {"effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(hunter, 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 4, "near"), K.foe(_dummy(), 6, 6, "taunter"), K.foe(_dummy(), 0, 6, "later")] as Array[UnitSetup]))
	fight.step()
	assert_eq(fight.units[0].target.id, "near")
	Statuses.apply(fight, fight.units[0], "taunt", 1, 0, _source("taunter"))
	fight.step()
	assert_eq(fight.units[0].target.id, "taunter")
	var pick: LogEntry = K.entries(fight, LogEntry.Kind.TARGET, "hunter").back()
	assert_eq([pick.target, pick.note], ["taunter", "taunted"])
	Statuses.apply(fight, fight.units[0], "taunt", 1, 0, _source("later"))
	fight.step()
	assert_eq(fight.units[0].target.id, "later", "the newer Taunt wins")
	fight.unit_by_id("later").hp = 0
	fight.step()
	var taunted_before: int = _taunted_picks(fight)
	K.step(fight, 2)
	assert_ne(fight.units[0].target.id, "later", "a fallen taunter lets go")
	assert_eq(_taunted_picks(fight), taunted_before, "and its Taunt no longer pulls")


func _taunted_picks(fight: CombatSim) -> int:
	return K.entries(fight, LogEntry.Kind.TARGET, "hunter").filter(func(entry: LogEntry) -> bool: return entry.note == "taunted").size()


func test_statuses_ride_a_shot() -> void:
	var archer: UnitDef = K.kit("archer", {"stats": {"hp": 10000, "speed": 0, "range": 5}, "basic_attack": {"effects": [
		{"type": "damage", "amount": 1, "target": "target"}, {"type": "apply_status", "status": "marked", "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(archer, 3, 0)] as Array[UnitSetup], [K.foe(_dummy(), 3, 5)] as Array[UnitSetup]))
	K.step(fight, 20)
	assert_false(Statuses.has_kind(fight.units[1], StatusDef.Kind.MARKED), "still in the air")
	K.step(fight, 5)
	assert_true(Statuses.has_kind(fight.units[1], StatusDef.Kind.MARKED), "the Mark lands with the arrow")


func test_damage_over_time_details() -> void:
	var fight: CombatSim = _duel(_dummy())
	var target: UnitState = fight.units[1]
	Statuses.apply(fight, target, "burn", 0, 0, _source())
	assert_null(Statuses.find(target, "burn"), "no stacks, no status")
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED).size(), 0)
	Statuses.apply(fight, target, "poison", 1, 0, _source())
	Statuses.apply(fight, target, "burn", 30, 0, _source())
	assert_eq(target.statuses.map(func(state: StatusState) -> String: return state.def.id), ["burn", "poison"], "kept in statuses.json order")
	K.step(fight, 10)
	assert_eq(Statuses.find(target, "burn").total_stacks(), 28, "5% of 30 is 1.5, rounded up to 2")
	var fading: CombatSim = _duel(_dummy())
	Statuses.apply(fading, fading.units[1], "burn", 1, 0, _source())
	K.step(fading, 10)
	assert_null(Statuses.find(fading.units[1], "burn"), "its last stack fell off")
	var ended: Array[LogEntry] = K.entries(fading, LogEntry.Kind.STATUS_ENDED)
	assert_eq(ended.map(func(entry: LogEntry) -> String: return entry.status), ["burn"])


func test_max_stacks_drops_the_oldest() -> void:
	var fight: CombatSim = _duel(_dummy())
	var capped: StatusDef = _status("capped", StatusDef.Kind.DAMAGE_OVER_TIME)
	capped.interval_ticks = 10
	capped.damage_per_stack = 1
	capped.max_stacks = 5
	_add_status(fight, capped)
	Statuses.apply(fight, fight.units[1], "capped", 4, 0, _source("first"))
	Statuses.apply(fight, fight.units[1], "capped", 3, 0, _source("second"))
	var groups: Array = Statuses.find(fight.units[1], "capped").groups
	assert_eq(groups.map(func(group: StatusState.StackGroup) -> Array: return [group.source.unit_id, group.stacks]), [["first", 2], ["second", 3]])


func test_half_strength_against_shields() -> void:
	var fight: CombatSim = _duel(_dummy())
	var target: UnitState = fight.units[1]
	target.shield = 5
	assert_eq(fight.apply_damage_vs_shield(target, 20, 5000), 10, "5 Shield soaks 10 damage at half strength")
	assert_eq([target.shield, target.hp], [0, 10000 - 10])


func test_heals_that_heal_nothing_cleanse_nothing() -> void:
	var fight: CombatSim = _duel(_dummy())
	var target: UnitState = fight.units[1]
	Statuses.apply(fight, target, "poison", 100, 0, _source())
	EffectRunner.heal(fight, target, 10, _source())
	assert_eq(Statuses.find(target, "poison").total_stacks(), 100, "already at full HP")
	assert_eq(target.recent_heal_ticks, [] as Array[int], "and it doesn't count toward the falloff")


func test_stealth_hides_a_unit_from_enemies_targeting() -> void:
	# Two heroes; the shooter's nearest is "near". Stealthed, "near" can't be
	# picked; a shot already flying still lands (playtest gate 1).
	var shooter: UnitDef = K.kit("shooter", {"stats": {"hp": 10000, "speed": 0, "range": 5}, "basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 5, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(_dummy(), 3, 2, "near"), K.at(_dummy(), 0, 0, "far")] as Array[UnitSetup], [K.foe(shooter, 3, 6)] as Array[UnitSetup]))
	var near: UnitState = fight.unit_by_id("near")
	var far: UnitState = fight.unit_by_id("far")
	var foe: UnitState = fight.unit_by_id("shooter")
	while K.entries(fight, LogEntry.Kind.SHOT, "shooter").is_empty():
		fight.step()
	assert_eq(foe.target, near)
	var shot: LogEntry = K.entries(fight, LogEntry.Kind.SHOT, "shooter")[0]
	Statuses.apply(fight, near, "stealth", 0, 0, _source("near"))
	assert_true(Statuses.is_stealthed(near))
	assert_eq(fight.targetable_enemies_of(foe), [far] as Array[UnitState])
	assert_eq(fight.standing_enemies_of(foe), [near, far] as Array[UnitState], "it still stands")
	assert_eq(Targeting.pick(fight, foe, "nearest", -1), far)
	assert_eq(Targeting.pick(fight, far, "lowest_hp_ally", -1) in [near, far], true, "allies still see it")
	near.hp -= 100
	assert_eq(Targeting.pick(fight, far, "lowest_hp_ally", -1), near, "and can heal it")
	far.target = near
	fight.step()
	assert_eq(foe.target, far, "it picks again at once")
	assert_eq(far.target, near, "an ally that targets it keeps it (only enemies lose it)")
	assert_eq(K.entries(fight, LogEntry.Kind.TARGET, "shooter").back().note, "nearest")
	K.step(fight, shot.end_tick - fight.tick + 1)
	assert_true(K.entries(fight, LogEntry.Kind.DAMAGE, "shooter").any(func(entry: LogEntry) -> bool: return entry.target == "near"), "the shot already flying still lands")
	assert_eq(Statuses.find(near, "stealth").ends_at, shot.tick + 20, "its own 1s")


func test_a_heals_cleanse_names_the_healer() -> void:
	var fight: CombatSim = _duel(_dummy())
	var target: UnitState = fight.units[1]
	target.hp -= 50
	Statuses.apply(fight, target, "poison", 100, 0, _source())
	EffectRunner.heal(fight, target, 10, _source("mender"))
	var reduced: LogEntry = K.entries(fight, LogEntry.Kind.STATUS_REDUCED)[0]
	assert_eq([reduced.source_unit, reduced.target, reduced.amount], ["mender", target.id, 10], "credited to the heal (rule 4)")
	assert_string_contains(reduced.note, "healed by mender")


func test_the_heal_falloff_window_is_1s() -> void:
	var fight: CombatSim = _duel(_dummy())
	var target: UnitState = fight.units[1]
	target.hp = 5000
	Statuses.apply(fight, target, "poison", 100, 0, _source())
	EffectRunner.heal(fight, target, 10, _source())
	fight.tick = 19
	EffectRunner.heal(fight, target, 10, _source())
	assert_eq(Statuses.find(target, "poison").total_stacks(), 85, "0.95s later: half strength")
	fight.tick = 20
	EffectRunner.heal(fight, target, 10, _source())
	assert_eq(Statuses.find(target, "poison").total_stacks(), 81, "the first heal left the window; the one at 0.95s still counts (5% of 85, rounded)")
	fight.tick = 40
	EffectRunner.heal(fight, target, 10, _source())
	assert_eq(Statuses.find(target, "poison").total_stacks(), 73, "all out of the window: 10% of 81, rounded")


func test_undying_holds_at_1_hp() -> void:
	var fight: CombatSim = _duel(_dummy())
	var target: UnitState = fight.units[1]
	Statuses.apply(fight, target, "undying", 1, 0, _source("keeper"))
	target.hp = 0
	fight.step()
	assert_eq([target.alive, target.hp], [true, 1])
	var held: LogEntry = K.entries(fight, LogEntry.Kind.SAVED)[0]
	assert_eq(held.to_text(), "[0.05s] dummy#2 is held at 1 HP by keeper · Test (Undying)")
	K.step(fight, 19)
	target.hp = 0
	fight.step()
	assert_false(target.alive, "after 1s it can fall")
