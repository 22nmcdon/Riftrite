extends GutTest
## The pieces Severine's apexes added (phase 8 part 5, docs/plans/
## rebuild-phase8-severine-edric.md section 4, 8e-2c), each in a small fight:
## an aura that counts per share of max HP Engorge added (Leviathan) or per
## stack of a status on its holder (Blood Tide); damage from the max HP
## Engorge added and giving it up (Sanguine Nova; MAX_HP_DOWN); the trigger
## on_hp_spent (Blood Rite); a raise, a fallen enemy standing up on the
## raiser's side as a thrall for a while (Gravecaller; Decision 2: never a
## summon, an elite or boss, or the void's fallen; a thrall keeps no side up
## and is nobody's fallen ally), and the condition raised; an enemy's rank;
## and the deed filter statuses on allies' hits.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _dummy(dummy_id: String, hp: int = 1000) -> UnitDef:
	return K.kit(dummy_id, {"stats": {"hp": hp, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _effect(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	EffectDef.read(DataReader.new(data, "effect", errors))
	return errors


func _aura(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	AuraDef.read(DataReader.new(data, "aura", errors))
	return errors


func _tally(setup: UnitSetup, key: String, data: Dictionary) -> void:
	var errors: Array[String] = []
	data["text"] = "x"
	setup.tally_keys.append(key)
	setup.tally_counts.append(DeedDef.read(DataReader.new(data, "count", errors)))
	assert_eq(errors, [] as Array[String])


func test_reading_the_pieces() -> void:
	assert_eq(_aura({"target": "holder", "stat": "lifesteal_bp", "value": 500, "per_engorged_pct": 10}), [] as Array[String])
	assert_eq(_aura({"target": "holder", "stat": "lifesteal_bp", "value": 300, "from_basic": true, "per_holder_stacks": "blood_tide"}), [] as Array[String])
	assert_false(_aura({"target": "holder", "stat": "atk_bp", "value": 11000, "per_holder_stacks": "blood_tide"}).is_empty(), "only a stat worked out per hit")
	assert_eq(_effect({"type": "damage", "amount_bp_of_engorged": 5000, "target": "target"}), [] as Array[String])
	assert_false(_effect({"type": "damage", "amount": 1, "amount_bp_of_engorged": 5000, "target": "target"}).is_empty(), "one amount")
	assert_eq(_effect({"type": "spend_engorged", "target": "self"}), [] as Array[String])
	assert_false(_effect({"type": "spend_engorged", "target": "target"}).is_empty(), "its own")
	assert_eq(_effect({"trigger": "on_enemy_fell", "type": "raise", "hp_pct": 30, "duration_ms": 8000, "max_standing": 3}), [] as Array[String])
	assert_false(_effect({"trigger": "on_hit_taken", "type": "raise", "hp_pct": 30, "duration_ms": 8000}).is_empty(), "a raise needs a fallen enemy")
	assert_eq(_effect({"trigger": "on_hp_spent", "type": "apply_status", "status": "sacred_blood", "target": "all_allies", "per_damage": 100}), [] as Array[String])
	var content: ContentDb = K.content()
	assert_eq([content.enemies["hound_alpha"].kit.rank, content.enemies["old_mother_ash"].kit.rank, content.enemies["rift_hound"].kit.rank], ["elite", "boss", ""])


## A striker hitting for 100 a second with 20% lifesteal of its own, beside a
## dummy, with `passives`.
func _striker(passives: Array) -> CombatSim:
	var striker: UnitDef = K.kit("striker", {"stats": {"hp": 1000, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 1000,
		"effects": [{"type": "damage", "amount": 100, "target": "target", "lifesteal_pct": 20}]}, "passives": passives})
	var fight: CombatSim = K.sim(K.fight([K.at(striker, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	fight.unit_by_id("mark").pos = fight.unit_by_id("striker").pos + Vector2i(0, 400)
	return fight


func test_an_aura_counts_per_share_of_max_hp_engorge_added() -> void:
	var fight: CombatSim = _striker([{"id": "leviathan", "name": "Leviathan", "kind": "aura", "aura": {"target": "holder", "stat": "lifesteal_bp", "value": 500, "per_engorged_pct": 10}}])
	var striker: UnitState = fight.unit_by_id("striker")
	K.step(fight, 1)
	assert_eq(striker.aura_bp[AuraDef.Stat.LIFESTEAL_BP], 0, "none added: off")
	for grown: int in [99, 100, 250]:
		striker.engorged = grown
		striker.base_max_hp = 1000 + grown
		striker.max_hp = 1000 + grown
		K.step(fight, 1)
		@warning_ignore("integer_division")
		assert_eq(striker.aura_bp[AuraDef.Stat.LIFESTEAL_BP], 500 * (grown / 100), "a step for every 10%% of its 1,000 (%d added)" % grown)


func test_an_aura_per_hit_counts_per_stack_on_its_holder() -> void:
	var fight: CombatSim = _striker([{"id": "tidal_thirst", "name": "Tidal Thirst", "kind": "aura", "aura": {"target": "holder", "stat": "lifesteal_bp", "value": 300, "from_basic": true, "per_holder_stacks": "blood_tide"}}])
	var striker: UnitState = fight.unit_by_id("striker")
	striker.hp = 100
	K.step(fight, 22)
	Statuses.apply(fight, striker, "blood_tide", 1, 0, striker.own_source)
	Statuses.apply(fight, striker, "blood_tide", 1, 0, striker.own_source)
	K.step(fight, 20)
	assert_eq(K.entries(fight, LogEntry.Kind.LIFESTEAL, "striker").map(func(entry: LogEntry) -> int: return entry.amount), [20, 26], "20%, then 3% more for each of 2 stacks")


func test_damage_from_engorged_max_hp_then_giving_it_up() -> void:
	var nova: UnitDef = K.kit("nova", {"stats": {"hp": 1000, "speed": 0, "range": 1}, "mana": {"max": 10, "start": 10, "per_attack": 0},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"signature": {"id": "sanguine_nova", "name": "Sanguine Nova", "trigger": {"kind": "mana"}, "targeting": "self",
			"effects": [{"type": "area", "shape": {"kind": "circle", "radius": 2}, "anchor": "self", "hits": "enemies",
				"effects": [{"type": "damage", "amount_bp_of_engorged": 5000, "target": "target"}]}, {"type": "spend_engorged", "target": "self"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(nova, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	var caster: UnitState = fight.unit_by_id("nova")
	fight.unit_by_id("mark").pos = caster.pos + Vector2i(0, 400)
	caster.engorged = 200
	caster.base_max_hp = 1200
	caster.max_hp = 1200
	caster.hp = 1150
	K.step(fight, 3)
	var mark: UnitState = fight.unit_by_id("mark")
	assert_eq(mark.max_hp - mark.hp, 100, "half the 200 Engorge added")
	var down: Array[LogEntry] = K.entries(fight, LogEntry.Kind.MAX_HP_DOWN, "nova")
	assert_eq(down.map(func(entry: LogEntry) -> int: return entry.amount), [200], "gives it up")
	assert_string_contains(down[0].to_text(), "gives up 200 max HP")
	assert_eq([caster.engorged, caster.max_hp, caster.hp], [0, 1000, 1000], "back to its own max HP, its HP down to it")


func test_hp_spent_raises_its_event_with_the_amount() -> void:
	var caster: UnitDef = K.kit("caster", {"stats": {"hp": 1000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"signature": {"id": "bleed_out", "name": "Bleed Out", "trigger": {"kind": "hp_above", "threshold_bp": 5000}, "hp_cost_bp": 1500,
			"effects": [{"type": "damage", "amount": 1, "target": "target"}]},
		"passives": [{"id": "sacred_blood", "name": "Sacred Blood", "kind": "ability",
			"effects": [{"trigger": "on_hp_spent", "type": "apply_status", "status": "sacred_blood", "target": "self", "per_damage": 100}]}]})
	var fight: CombatSim = K.sim(K.fight([K.at(caster, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	fight.unit_by_id("mark").pos = fight.unit_by_id("caster").pos + Vector2i(0, 400)
	K.step(fight, 6)
	assert_eq(K.entries(fight, LogEntry.Kind.HP_SPENT, "caster").size(), 4, "100%, 85%, 70%, 55%: four casts of 150")
	assert_eq(Statuses.stacks_on(fight.unit_by_id("caster"), "sacred_blood"), 6, "a stack for every 100 of the 600 spent")


## A raiser beside a Poisoned victim of `victim_hp` (its kit `victim`), which
## its next hit fells, and a mark far off that keeps the fight going. Its
## raise stands the victim up for 1s at 30%.
func _raise_fight(victim: UnitDef, raise: Dictionary = {}, passives: Array = []) -> CombatSim:
	var effect: Dictionary = {"trigger": "on_enemy_fell", "vs": {"statuses": ["poison"]}, "type": "raise", "hp_pct": 30, "duration_ms": 1000}
	effect.merge(raise, true)
	var raiser: UnitDef = K.kit("raiser", {"stats": {"hp": 1000, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 1000,
		"effects": [{"type": "damage", "amount": 500, "target": "target"}]},
		"passives": [{"id": "gravecaller", "name": "Gravecaller", "kind": "ability", "effects": [effect]}] + passives})
	var fight: CombatSim = K.sim(K.fight([K.at(raiser, 3, 2)] as Array[UnitSetup], [K.foe(victim, 3, 4, "victim"), K.foe(_dummy("far"), 7, 6)] as Array[UnitSetup]))
	var target: UnitState = fight.unit_by_id("victim")
	target.pos = fight.unit_by_id("raiser").pos + Vector2i(0, 400)
	Statuses.apply(fight, target, "poison", 1, 0, fight.unit_by_id("raiser").own_source)
	return fight


func _thralls(fight: CombatSim) -> Array[UnitState]:
	var found: Array[UnitState] = []
	for unit: UnitState in fight.units:
		if unit.raised:
			found.append(unit)
	return found


func test_a_poisoned_enemy_that_falls_rises_as_a_thrall_for_a_while() -> void:
	var fight: CombatSim = _raise_fight(_dummy("victim", 200))
	K.step(fight, 22)
	var thralls: Array[UnitState] = _thralls(fight)
	assert_eq(thralls.size(), 1, "it rises")
	var thrall: UnitState = thralls[0]
	assert_eq([thrall.side, thrall.def.id, thrall.max_hp, thrall.hp, thrall.summoned], [EffectSource.Team.HEROES, "victim", 60, 60, true], "on the raiser's side, its own kit, 30% of its HP")
	var raised: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SUMMON, "raiser")
	assert_eq(raised.size(), 1)
	assert_eq([raised[0].source_ability, raised[0].target], ["gravecaller", thrall.id], "sourced to the raise")
	assert_eq(Passives.fallen_allies(fight, fight.unit_by_id("raiser")), 0)
	K.step(fight, 22)
	assert_false(thrall.alive, "its time runs out")
	var gone: Array = fight.combat_log.of_kind(LogEntry.Kind.DEATH).filter(func(entry: LogEntry) -> bool: return entry.target == thrall.id)
	assert_eq(gone.size(), 1)
	assert_string_contains((gone[0] as LogEntry).note, "its time is up")
	assert_eq(Passives.fallen_allies(fight, fight.unit_by_id("raiser")), 0, "a thrall is nobody's fallen ally")
	assert_false(fight.finished)


func test_no_poison_no_thrall() -> void:
	var fight: CombatSim = _raise_fight(_dummy("victim", 200))
	Statuses.cleanse_over_time(fight, fight.unit_by_id("victim"), FixedMath.BP_ONE, fight.unit_by_id("raiser").own_source, false)
	K.step(fight, 22)
	assert_false(fight.unit_by_id("victim").alive)
	assert_eq(_thralls(fight).size(), 0, "it needs the vs")


func test_never_an_elite_a_boss_or_a_summon() -> void:
	var elite: UnitDef = _dummy("victim", 200)
	elite.rank = "elite"
	var fight: CombatSim = _raise_fight(elite)
	K.step(fight, 22)
	assert_eq(_thralls(fight).size(), 0, "an elite stays down")
	var summoned: CombatSim = _raise_fight(_dummy("victim", 200))
	summoned.unit_by_id("victim").summoned = true
	K.step(summoned, 22)
	assert_eq(_thralls(summoned).size(), 0, "a summon stays down")


func test_thralls_grow_with_each_raise_and_stop_at_the_most_standing() -> void:
	var fight: CombatSim = _raise_fight(_dummy("victim", 200), {"max_standing": 1, "grow_hp_pct": 10, "grow_ms": 500, "duration_ms": 8000})
	K.step(fight, 22)
	var first: UnitState = _thralls(fight)[0]
	assert_eq([first.max_hp, first.expires_at - first.joined_at], [60, 160], "the first: 30%, 8s")
	# Another poisoned enemy down while the first stands: enough stand.
	var raiser: UnitState = fight.unit_by_id("raiser")
	var far: UnitState = fight.unit_by_id("far")
	far.alive = false
	var part: PartDef = raiser.def.passives[0]
	Summons.raise(fight, raiser, EffectSource.make(raiser.id, part.id, part.name), part.ability.effects[0], far)
	assert_eq(_thralls(fight).size(), 1)
	assert_eq(K.entries(fight, LogEntry.Kind.SUMMON, "raiser").filter(func(entry: LogEntry) -> bool: return entry.note == "enough stand").size(), 1, "dropped: enough stand")
	# Each raise before makes the next bigger and longer-lived.
	var grown: CombatSim = _raise_fight(_dummy("victim", 200), {"grow_hp_pct": 10, "grow_ms": 500, "duration_ms": 8000})
	grown.unit_by_id("raiser").raises = 2
	K.step(grown, 22)
	var later: UnitState = _thralls(grown)[0]
	assert_eq([later.max_hp, later.expires_at - later.joined_at], [100, 180], "two raised before: 50%, 9s")


func test_a_thrall_keeps_no_side_up() -> void:
	var fight: CombatSim = _raise_fight(_dummy("victim", 200), {"duration_ms": 8000})
	K.step(fight, 22)
	assert_eq(_thralls(fight).size(), 1)
	fight.unit_by_id("raiser").hp = 0
	K.step(fight, 1)
	assert_true(fight.finished, "the raiser down, the thrall standing: the fight is over")
	assert_eq(fight.outcome, FightResult.Outcome.DEFEAT)


func test_raised_names_a_thrall() -> void:
	var striker: UnitDef = K.kit("victim", {"stats": {"hp": 200, "speed": 0, "range": 4}, "basic_attack": {"cooldown_ms": 500, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}})
	var fight: CombatSim = _raise_fight(striker, {"duration_ms": 8000}, [{"id": "plague_thralls", "name": "Plague Thralls", "kind": "ability",
		"effects": [{"trigger": "on_ally_hit", "by": {"raised": true}, "type": "apply_status", "status": "poison", "stacks": 3, "target": "hit_target"}]}])
	K.step(fight, 22)
	var thrall: UnitState = _thralls(fight)[0]
	var far: UnitState = fight.unit_by_id("far")
	thrall.pos = far.pos + Vector2i(0, -2000)
	K.step(fight, 40)
	var poisoned: Array = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "raiser").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "plague_thralls")
	assert_gt(poisoned.size(), 0, "its thrall's hits set it off")
	var cond := UnitCondition.new()
	cond.raised = true
	assert_true(cond.holds(thrall))
	assert_false(cond.holds(fight.unit_by_id("raiser")))


func test_a_deed_counts_allies_hits_while_they_hold_a_status() -> void:
	var striker: UnitDef = K.kit("striker", {"stats": {"hp": 1000, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}})
	var counter: UnitSetup = K.at(_dummy("counter"), 0, 0)
	_tally(counter, "lifted", {"counts": "hits", "by_allies": true, "statuses": ["blood_offering"]})
	var fight: CombatSim = K.sim(K.fight([counter, K.at(striker, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	fight.unit_by_id("mark").pos = fight.unit_by_id("striker").pos + Vector2i(0, 400)
	K.step(fight, 22)
	assert_eq(CombatSim.result_of(fight).tally_amount("counter", "lifted"), 0, "not lifted yet")
	Statuses.apply(fight, fight.unit_by_id("striker"), "blood_offering", 1, 0, fight.unit_by_id("counter").own_source)
	K.step(fight, 20)
	assert_eq(CombatSim.result_of(fight).tally_amount("counter", "lifted"), 1, "a hit while it holds Blood Offering")
	var errors: Array[String] = []
	DeedDef.read(DataReader.new({"text": "x", "counts": "damage", "statuses": ["blood_offering"]}, "count", errors))
	assert_false(errors.is_empty(), "statuses filter applied or allies' hits only")


## The Iron Maw's pieces (8e-2e): a thorns unit beside a drinker at 100 of
## 1,000 HP, and an attacker hitting the thorns unit for 100 a second.
func _maw(drinker_passives: Array = []) -> CombatSim:
	var thorn: UnitDef = K.kit("thorn", {"stats": {"hp": 1000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"passives": [{"id": "spikes", "name": "Spikes", "kind": "ability", "effects": [{"trigger": "on_hit_taken", "type": "damage", "amount_bp_of_damage": 5000, "target": "hit_target"}]},
			{"id": "the_iron_maw", "name": "The Iron Maw", "kind": "ability", "effects": [{"trigger": "on_holder_hit", "from_ability": ["spikes"], "type": "heal", "as_lifesteal": true,
				"amount_bp_of_damage": 10000, "target": "allies_near_self", "within_hexes": 2, "only": {"kits": ["drinker"]}}]}]})
	var drinker: UnitDef = K.kit("drinker", {"stats": {"hp": 1000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}, "passives": drinker_passives})
	var attacker: UnitDef = K.kit("attacker", {"stats": {"hp": 5000, "speed": 0, "range": 1, "def": 0},
		"basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 100, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(thorn, 3, 2), K.at(drinker, 2, 2)] as Array[UnitSetup], [K.foe(attacker, 3, 4)] as Array[UnitSetup]))
	fight.unit_by_id("attacker").pos = fight.unit_by_id("thorn").pos + Vector2i(0, 400)
	fight.unit_by_id("drinker").hp = 100
	return fight


func test_a_heal_as_lifesteal_lands_as_its_targets_own_lifesteal() -> void:
	var fight: CombatSim = _maw()
	K.step(fight, 22)
	var sent: int = K.entries(fight, LogEntry.Kind.DAMAGE, "thorn").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "spikes")[0].amount
	var drunk: Array[LogEntry] = K.entries(fight, LogEntry.Kind.LIFESTEAL, "thorn")
	assert_eq(drunk.size(), 1)
	assert_eq([drunk[0].target, drunk[0].amount, drunk[0].source_ability], ["drinker", sent, "the_iron_maw"], "what it sent back, as the drinker's lifesteal")
	assert_eq(K.entries(fight, LogEntry.Kind.HEAL, "thorn").size(), 0, "never healing")
	var far: CombatSim = _maw()
	far.unit_by_id("drinker").pos += Vector2i(-3000, 0)
	K.step(far, 22)
	assert_eq(K.entries(far, LogEntry.Kind.LIFESTEAL, "thorn").size(), 0, "only within 2 hexes")


func test_max_hp_gained_raises_its_event_and_can_be_shared() -> void:
	var fight: CombatSim = _maw([{"id": "engorge", "name": "Engorge", "kind": "aura", "aura": {"target": "holder", "stat": "lifesteal_max_hp_bp", "value": 10000}},
		{"id": "the_iron_maw", "name": "The Iron Maw", "kind": "ability", "effects": [{"trigger": "on_max_hp_up", "from_ability": ["engorge"], "type": "gain_max_hp",
			"amount_bp_of_damage": 10000, "target": "all_allies", "only": {"kits": ["thorn"]}}]}])
	var drinker: UnitState = fight.unit_by_id("drinker")
	drinker.hp = drinker.max_hp
	K.step(fight, 22)
	var grew: Array[LogEntry] = K.entries(fight, LogEntry.Kind.MAX_HP_UP, "drinker")
	assert_eq(grew.map(func(entry: LogEntry) -> String: return "%s %s" % [entry.source_ability, entry.target]), ["engorge drinker", "the_iron_maw thorn"], "Engorge, then the same for the thorns unit")
	assert_eq(grew[0].amount, grew[1].amount)
	assert_eq(fight.unit_by_id("thorn").max_hp, 1000 + grew[1].amount)
	var errors: Array[String] = []
	EffectDef.read(DataReader.new({"type": "heal", "as_lifesteal": true, "amount_bp_of_max_hp": 500, "target": "self"}, "effect", errors))
	assert_false(errors.is_empty(), "a heal as lifesteal is only its amount")
