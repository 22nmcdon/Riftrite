class_name DamageMeter
extends RefCounted
## Per-item totals for one fight, built from the combat log (never counted
## separately, so the meter and the log can't disagree). Damage includes
## damage over time credited to the item; Rift Collapse isn't credited to
## anyone. A relic gets its own row (unit_id ""), and so does each relic
## grant on an item ("Rust Hook (Cinder Crown)"), so relics can be judged.


class Row:
	var side: UnitSetup.Side
	var unit_id: String
	var item_id: String
	var item_name: String
	var damage: int = 0
	var healing: int = 0
	var shielding: int = 0

	func output() -> int:
		return damage + healing + shielding


## In order of first appearance in the log.
var rows: Array[Row] = []
var _index: Dictionary[String, int] = {}


static func from_log(combat_log: CombatLog, heroes: Array[String]) -> DamageMeter:
	var meter := DamageMeter.new()
	for entry: LogEntry in combat_log.entries:
		match entry.kind:
			LogEntry.Kind.DAMAGE, LogEntry.Kind.STATUS_DAMAGE:
				meter._row(entry, heroes).damage += entry.amount
			LogEntry.Kind.HEAL:
				meter._row(entry, heroes).healing += entry.amount
			LogEntry.Kind.SHIELD:
				meter._row(entry, heroes).shielding += entry.amount
	return meter


func _row(entry: LogEntry, heroes: Array[String]) -> Row:
	var key: String = "%s/%s/%s/%d" % [entry.source_unit, entry.source_item, entry.source_granted_by, entry.source_relic_side]
	if _index.has(key):
		return rows[_index[key]]
	var row := Row.new()
	if entry.source_relic_side >= 0:
		row.side = entry.source_relic_side as UnitSetup.Side
	else:
		row.side = UnitSetup.Side.HEROES if heroes.has(entry.source_unit) else UnitSetup.Side.ENEMIES
	row.unit_id = entry.source_unit
	row.item_id = entry.source_item
	row.item_name = entry.source_item_name
	if not entry.source_granted_by.is_empty():
		row.item_name += " (%s)" % entry.source_granted_by
	_index[key] = rows.size()
	rows.append(row)
	return row


func total_damage(side: UnitSetup.Side) -> int:
	var total: int = 0
	for row: Row in rows:
		if row.side == side:
			total += row.damage
	return total
