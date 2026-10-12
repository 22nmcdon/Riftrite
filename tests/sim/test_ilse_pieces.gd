extends GutTest
## The fight pieces Ilse's paths added (phase 8 part 6, docs/plans/
## rebuild-phase8-last-heroes.md section 4, 8f-1), each in a small fight:
## the trigger on_status_tick (Heat: mana from Burn ticks near her, whoever's
## Burn it is), the aura stat over_time_loss_bp (Furnace's slower decay),
## damage's amount_per_stack and an on_fire stacks_of (Immolate and its
## splash), a zone that grows (Wildfire), an area at the largest groups
## (Firestorm), on_ally_hit's spends (Blessing's next attacks), and
## allies_near_self's nearest.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _dummy(dummy_id: String, hp: int = 5000, passives: Array = []) -> UnitDef:
	return K.kit(dummy_id, {"stats": {"hp": hp, "speed": 0, "range": 1, "def": 0},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}, "passives": passives})


func _effect(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	EffectDef.read(DataReader.new(data, "effect", errors))
	return errors


func _relic_burn(fight: CombatSim, unit_id: String, stacks: int) -> void:
	Statuses.apply(fight, fight.unit_by_id(unit_id), "burn", stacks, 0, EffectSource.relic("ember", "Ember", EffectSource.Team.HEROES))


func test_reading_the_pieces() -> void:
	assert_eq(_effect({"trigger": "on_status_tick", "statuses": ["burn"], "near_hexes": 3, "type": "gain_mana", "amount": 1, "target": "self"}), [] as Array[String])
	assert_eq(_effect({"type": "damage", "amount": 0, "amount_per_stack": {"status": "burn", "per": 5}, "target": "target"}), [] as Array[String])
	assert_false(_effect({"type": "heal", "amount": 0, "amount_per_stack": {"status": "burn", "per": 5}, "target": "target"}).is_empty(), "damage only")
	assert_eq(_effect({"type": "apply_status", "status": "burn", "stacks_of": "burn", "stacks_share_bp": 5000, "target": "enemies_near_target", "within_hexes": 1}), [] as Array[String])
	var zone: Dictionary = {"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "enemies", "duration_ms": 6000, "every_ms": 500,
		"grows": {"every_ms": 2000, "max_radius": 3}, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}
	assert_eq(_effect(zone), [] as Array[String])
	var still: Dictionary = zone.duplicate(true)
	still.erase("duration_ms")
	still.erase("every_ms")
	assert_false(_effect(still).is_empty(), "only a zone grows")
	var groups: Dictionary = zone.duplicate(true)
	groups.erase("grows")
	groups["at_largest_groups"] = 3
	assert_eq(_effect(groups), [] as Array[String])
	groups["anchor"] = "self"
	assert_false(_effect(groups).is_empty(), "anchored on each group")
	assert_eq(_effect({"trigger": "on_ally_hit", "spends": "quickened", "type": "apply_status", "status": "burn", "stacks": 1, "target": "hit_target"}), [] as Array[String])
	assert_eq(_effect({"trigger": "on_interval", "interval_ms": 8000, "type": "apply_status", "status": "quickened", "stacks": 3, "target": "allies_near_self", "within_hexes": 8, "nearest": 1}), [] as Array[String])
	assert_false(_effect({"trigger": "on_interval", "interval_ms": 8000, "type": "apply_status", "status": "quickened", "stacks": 3, "target": "all_allies", "nearest": 1}).is_empty(), "nearest is allies_near_self's")


func test_heat_gains_mana_from_burn_ticks_near_her() -> void:
	var caster: UnitDef = K.kit("caster", {"stats": {"hp": 1000, "speed": 0, "range": 1}, "mana": {"max": 100, "per_attack": 0},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"signature": {"id": "nothing", "name": "Nothing", "trigger": {"kind": "mana"}, "targeting": "self", "effects": [{"type": "shield", "amount": 1, "target": "self"}]},
		"passives": [{"id": "heat", "name": "Heat", "kind": "ability", "effects": [
			{"trigger": "on_status_tick", "statuses": ["burn"], "near_hexes": 3, "type": "gain_mana", "amount": 1, "target": "self"}]}]})
	var fight: CombatSim = K.sim(K.fight([K.at(caster, 0, 0)] as Array[UnitSetup], [K.foe(_dummy("near"), 3, 4), K.foe(_dummy("far"), 7, 6)] as Array[UnitSetup]))
	var unit: UnitState = fight.unit_by_id("caster")
	fight.unit_by_id("near").pos = unit.pos + Vector2i(0, 2000)
	_relic_burn(fight, "near", 20)
	_relic_burn(fight, "far", 20)
	K.step(fight, 21)
	var ticks_near: int = K.entries(fight, LogEntry.Kind.STATUS_DAMAGE).filter(func(entry: LogEntry) -> bool: return entry.target == "near").size()
	assert_gt(ticks_near, 0, "Burn ticked on the near enemy")
	assert_gt(K.entries(fight, LogEntry.Kind.STATUS_DAMAGE).filter(func(entry: LogEntry) -> bool: return entry.target == "far").size(), 0, "and the far one")
	assert_eq(unit.mana, ticks_near * Mana.SCALE, "1 mana for each tick near her, a relic's Burn too; none from the far one")
	Statuses.apply(fight, unit, "silence", 1, 200, EffectSource.make("near", "hush", "Hush"))
	var before: int = unit.mana
	K.step(fight, 20)
	assert_eq(unit.mana, before, "Silence stops it, as it stops all mana")


func test_over_time_loss_slows_the_burn_fading() -> void:
	var slowed: UnitDef = _dummy("slowed", 5000, [{"id": "coals", "name": "Coals", "kind": "aura", "aura": {"target": "holder", "stat": "over_time_loss_bp", "value": -5000}}])
	var fight: CombatSim = K.sim(K.fight([K.at(_dummy("hero"), 0, 0)] as Array[UnitSetup], [K.foe(_dummy("plain"), 1, 5), K.foe(slowed, 5, 5)] as Array[UnitSetup]))
	_relic_burn(fight, "plain", 100)
	_relic_burn(fight, "slowed", 100)
	K.step(fight, 21)
	assert_eq([Statuses.stacks_on(fight.unit_by_id("plain"), "burn"), Statuses.stacks_on(fight.unit_by_id("slowed"), "burn")], [90, 95],
		"two ticks: 5 and 5 lost, against 2 and 3 (half, the rest carried)")


func test_immolate_sets_off_the_burn_and_splashes_half() -> void:
	var caster: UnitDef = K.kit("caster", {"stats": {"hp": 1000, "speed": 0, "range": 1}, "mana": {"max": 50, "start": 50, "per_attack": 0},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"signature": {"id": "immolate", "name": "Immolate", "trigger": {"kind": "mana"}, "effects": [
			{"type": "apply_status", "status": "burn", "stacks_of": "burn", "stacks_share_bp": 5000, "target": "enemies_near_target", "within_hexes": 1},
			{"type": "damage", "amount": 0, "amount_per_stack": {"status": "burn", "per": 5}, "target": "target"},
			{"type": "cleanse", "amount_bp": 10000, "statuses": ["burn"], "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(caster, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("victim"), 3, 4), K.foe(_dummy("beside"), 4, 4)] as Array[UnitSetup]))
	var unit: UnitState = fight.unit_by_id("caster")
	fight.unit_by_id("victim").pos = unit.pos + Vector2i(0, 400)
	fight.unit_by_id("beside").pos = unit.pos + Vector2i(700, 600)
	_relic_burn(fight, "victim", 40)
	K.step(fight, 3)
	var hit: LogEntry = K.entries(fight, LogEntry.Kind.DAMAGE, "caster").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "immolate")[0]
	assert_eq([hit.target, hit.amount], ["victim", 200], "5 for each of its 40 stacks")
	assert_eq(Statuses.stacks_on(fight.unit_by_id("victim"), "burn"), 0, "the Burn it set off is gone")
	assert_eq(Statuses.stacks_on(fight.unit_by_id("beside"), "burn"), 20, "the enemy beside it catches half")


func test_a_zone_that_grows() -> void:
	var caster: UnitDef = K.kit("caster", {"stats": {"hp": 1000, "speed": 0, "range": 4}, "mana": {"max": 50, "start": 50, "per_attack": 0},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"signature": {"id": "kindling", "name": "Kindling", "trigger": {"kind": "mana"}, "effects": [
			{"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "enemies", "duration_ms": 6000, "every_ms": 500,
				"grows": {"every_ms": 2000, "max_radius": 3}, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(caster, 3, 1)] as Array[UnitSetup], [K.foe(_dummy("victim"), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 2)
	assert_eq(fight.zones.size(), 1)
	var zone: Areas.Pending = fight.zones[0]
	assert_eq(zone.shape.size, 1)
	K.step(fight, 100)
	assert_eq(zone.shape.size, 3, "1 hex wider every 2s, up to 3")
	var notes: Array = K.entries(fight, LogEntry.Kind.AREA_LANDED, "caster").map(func(entry: LogEntry) -> String: return entry.note).filter(func(note: String) -> bool: return not note.is_empty())
	assert_eq(notes, ["spread to 2", "spread to 3"])
	var kit_zone: EffectDef = fight.unit_by_id("caster").def.signature.effects[0]
	assert_eq(kit_zone.shape.size, 1, "the kit's own shape doesn't change")


func test_the_largest_groups() -> void:
	var caster: UnitDef = K.kit("caster", {"stats": {"hp": 1000, "speed": 0, "range": 8}, "mana": {"max": 50, "start": 50, "per_attack": 0},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"signature": {"id": "firestorm", "name": "Firestorm", "trigger": {"kind": "mana"}, "effects": [
			{"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "enemies", "at_largest_groups": 3,
				"effects": [{"type": "damage", "amount": 1, "target": "target"}]}]}})
	var foes: Array[UnitSetup] = []
	for foe_id: String in ["a1", "a2", "a3", "b1", "b2", "c1"]:
		foes.append(K.foe(_dummy(foe_id), foes.size(), 6))
	var fight: CombatSim = K.sim(K.fight([K.at(caster, 3, 0)] as Array[UnitSetup], foes))
	var spots: Dictionary[String, Vector2i] = {"a1": Vector2i(1000, 6000), "a2": Vector2i(1500, 6000), "a3": Vector2i(1200, 6600),
		"b1": Vector2i(5000, 6000), "b2": Vector2i(5600, 6000), "c1": Vector2i(7000, 3500)}
	for foe_id: String in spots:
		fight.unit_by_id(foe_id).pos = spots[foe_id]
	var middles: Array[UnitState] = Targeting.largest_groups(fight, fight.unit_by_id("caster"), 3)
	assert_eq(middles.map(func(unit: UnitState) -> String: return unit.id), ["a1", "b1", "c1"], "the three, biggest first, each apart from the others")
	K.step(fight, 2)
	var landed: Array[LogEntry] = K.entries(fight, LogEntry.Kind.AREA_LANDED, "caster")
	assert_eq(landed.size(), 3, "a fire under each")
	assert_eq(landed.map(func(entry: LogEntry) -> int: return entry.amount), [3, 2, 1])


func test_blessed_attacks_spend_a_stack_each() -> void:
	var singer: UnitDef = _dummy("singer", 1000, [{"id": "blessing", "name": "Blessing", "kind": "ability", "effects": [
		{"trigger": "on_ally_hit", "spends": "quickened", "type": "apply_status", "status": "burn", "stacks": 3, "target": "hit_target"}]}])
	var fighter: UnitDef = K.kit("fighter", {"stats": {"hp": 1000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(singer, 0, 0), K.at(fighter, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("victim"), 3, 4)] as Array[UnitSetup]))
	fight.unit_by_id("victim").pos = fight.unit_by_id("fighter").pos + Vector2i(0, 400)
	Statuses.apply(fight, fight.unit_by_id("fighter"), "quickened", 2, 0, EffectSource.make("singer", "blessing", "Blessing"))
	K.step(fight, 100)
	var burns: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "singer").filter(func(entry: LogEntry) -> bool: return entry.status == "burn")
	assert_gt(K.entries(fight, LogEntry.Kind.DAMAGE, "fighter").size(), 3, "it hit more than twice")
	assert_eq(burns.size(), 2, "only its 2 blessed attacks carried Burn")
	assert_null(Statuses.find(fight.unit_by_id("fighter"), "quickened"), "both stacks spent")


func test_the_nearest_ally() -> void:
	var singer: UnitDef = _dummy("singer", 1000, [{"id": "blessing", "name": "Blessing", "kind": "ability", "effects": [
		{"trigger": "on_interval", "interval_ms": 1000, "type": "apply_status", "status": "quickened", "stacks": 1, "target": "allies_near_self", "within_hexes": 8, "nearest": 1}]}])
	var fight: CombatSim = K.sim(K.fight([K.at(singer, 0, 0), K.at(_dummy("far"), 6, 2), K.at(_dummy("close"), 1, 0)] as Array[UnitSetup],
		[K.foe(_dummy("victim"), 3, 5)] as Array[UnitSetup]))
	K.step(fight, 21)
	var given: Array = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "singer").map(func(entry: LogEntry) -> String: return entry.target)
	assert_eq(given, ["close"], "only the nearest, though the farther one comes first in the fight's order")
