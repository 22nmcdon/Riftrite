class_name SimTestKit
extends RefCounted
## Builders for sim tests. Items are written as JSON-shaped dictionaries and
## go through the real loaders, so tests exercise the same parsing as data/.

const DEFAULT_ITEM: Dictionary = {
	"name": "Test Item",
	"size": 1,
	"rarity": "common",
	"xp_per_fire": 1,
	"cooldown_ms": 1000,
	"effects": [{"trigger": "on_fire", "type": "damage", "amount": 10, "target": "enemy_front"}],
}

const DEFAULT_BASIC: Dictionary = {
	"name": "Basic Attack",
	"cooldown_ms": 1000,
	"effects": [{"trigger": "on_fire", "type": "damage", "amount": 5, "target": "enemy_front"}],
}


static var _content: ContentDb


## The real content from data/, loaded once.
static func content() -> ContentDb:
	if _content == null:
		_content = ContentDb.load_dir("res://data")
		assert(_content.is_valid(), "real data must be valid: %s" % [_content.errors])
	return _content


static func tuning() -> TuningDef:
	return content().tuning


## An item with essences socketed, for a unit's row.
static func equip(def: ItemDef, essences: Array[String] = []) -> ItemSetup:
	return ItemSetup.make(def, essences)


## An item from DEFAULT_ITEM with `overrides` applied. Fails loudly on errors.
static func item(item_id: String, overrides: Dictionary = {}) -> ItemDef:
	var data: Dictionary = DEFAULT_ITEM.duplicate(true)
	data.merge(overrides, true)
	data["id"] = item_id
	var errors: Array[String] = []
	var def: ItemDef = ItemDef.read(DataReader.new(data, item_id, errors))
	assert(errors.is_empty(), "test item %s is invalid: %s" % [item_id, errors])
	return def


static func basic(attack_id: String = "basic", overrides: Dictionary = {}) -> ItemDef:
	var data: Dictionary = DEFAULT_BASIC.duplicate(true)
	data.merge(overrides, true)
	data["id"] = attack_id
	var errors: Array[String] = []
	var def: ItemDef = ItemDef.read_basic_attack(DataReader.new(data, attack_id, errors))
	assert(errors.is_empty(), "test basic attack %s is invalid: %s" % [attack_id, errors])
	return def


## A damage-only effect list, for overrides.
static func damage(amount: int, target: String = "enemy_front") -> Array:
	return [{"trigger": "on_fire", "type": "damage", "amount": amount, "target": target}]


## `items` may mix ItemDefs (no essences) and ItemSetups (from equip()).
static func unit(unit_id: String, hp: int, row: UnitSetup.Row = UnitSetup.Row.FRONT, items: Array = [], basic_attack: ItemDef = null) -> UnitSetup:
	var attack: ItemDef = basic_attack if basic_attack != null else basic()
	var row_items: Array[ItemSetup] = []
	for entry: Variant in items:
		row_items.append(entry if entry is ItemSetup else ItemSetup.make(entry))
	return UnitSetup.make(unit_id, unit_id, hp, row, 7, attack, row_items)


## A unit whose basic attack never matters: 1 damage every 60s.
static func dummy(unit_id: String, hp: int, row: UnitSetup.Row = UnitSetup.Row.FRONT) -> UnitSetup:
	return unit(unit_id, hp, row, [], basic("idle", {"cooldown_ms": 60000, "effects": damage(1)}))


static func fight(heroes: Array[UnitSetup], enemies: Array[UnitSetup], seed_value: int = 1, act: int = 1) -> FightSetup:
	return FightSetup.make(heroes, enemies, seed_value, act)


static func run(heroes: Array[UnitSetup], enemies: Array[UnitSetup], seed_value: int = 1, act: int = 1) -> FightResult:
	return CombatSim.run(fight(heroes, enemies, seed_value, act), content())


## Log entries of one kind whose source item is `item_id`.
static func entries(result: FightResult, kind: LogEntry.Kind, item_id: String = "") -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in result.combat_log.of_kind(kind):
		if item_id.is_empty() or entry.source_item == item_id:
			found.append(entry)
	return found


static func ticks_of(found: Array[LogEntry]) -> Array[int]:
	var ticks: Array[int] = []
	for entry: LogEntry in found:
		ticks.append(entry.tick)
	return ticks


static func targets_of(found: Array[LogEntry]) -> Array[String]:
	var targets: Array[String] = []
	for entry: LogEntry in found:
		targets.append(entry.target)
	return targets
