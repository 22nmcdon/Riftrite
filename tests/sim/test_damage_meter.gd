extends GutTest
## The damage meter is built from the log, so it must agree with it exactly.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BIG_HP: int = 10000000


func test_meter_matches_the_log() -> void:
	var torch: ItemDef = K.item("torch", {"name": "Torch", "effects": [{"trigger": "on_fire", "type": "apply_status", "status": "burn", "stacks": 3, "target": "enemy_front"}]})
	var mend: ItemDef = K.item("mend", {"name": "Mend", "effects": [{"trigger": "on_fire", "type": "heal", "amount": 4, "target": "self"}]})
	var ward: ItemDef = K.item("ward", {"name": "Ward", "effects": [{"trigger": "on_fire", "type": "shield", "amount": 2, "target": "self"}]})
	var result: FightResult = K.run([K.unit("hero", 2000, FRONT, [torch, mend, ward])], [K.unit("foe", 1500, FRONT)])
	var meter: DamageMeter = DamageMeter.from_log(result.combat_log, ["hero"] as Array[String])

	var burn_total: int = 0
	for entry: LogEntry in result.combat_log.of_kind(LogEntry.Kind.STATUS_DAMAGE):
		if entry.source_item == "torch":
			burn_total += entry.amount
	var totals: Dictionary[String, Array] = {}
	for row: DamageMeter.Row in meter.rows:
		totals["%s/%s" % [row.unit_id, row.item_id]] = [row.side, row.damage, row.healing, row.shielding]
	assert_eq(totals["hero/torch"], [UnitSetup.Side.HEROES, burn_total, 0, 0], "damage over time goes to the item that applied it")
	assert_gt(totals["hero/mend"][2], 0)
	assert_gt(totals["hero/ward"][3], 0)
	assert_eq(totals["foe/basic"][0], UnitSetup.Side.ENEMIES)
	assert_false(totals.has("/rift_collapse"), "collapse damage isn't credited to anyone")


func test_side_totals() -> void:
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [K.item("club", {"effects": K.damage(7)})])], [K.dummy("foe", 50)])
	var meter: DamageMeter = DamageMeter.from_log(result.combat_log, ["hero"] as Array[String])
	var logged: int = 0
	for entry: LogEntry in result.combat_log.of_kind(LogEntry.Kind.DAMAGE):
		if entry.source_unit == "hero":
			logged += entry.amount
	assert_eq(meter.total_damage(UnitSetup.Side.HEROES), logged)
