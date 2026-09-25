class_name SimTestKit
extends RefCounted
## Builders for sim tests. Items are written as JSON-shaped dictionaries and
## go through the real loaders, so tests exercise the same parsing as data/.

const DEFAULT_ITEM: Dictionary = {
	"name": "Test Item",
	"size": 1,
	"rarity": "common",
	"xp_per_fire": 0,
	"cooldown_ms": 1000,
	"effects": [{"trigger": "on_fire", "type": "damage", "amount": 10, "target": "enemy_front"}],
}

const DEFAULT_BASIC: Dictionary = {
	"name": "Basic Attack",
	"cooldown_ms": 1000,
	"effects": [{"trigger": "on_fire", "type": "damage", "amount": 5, "target": "enemy_front"}],
}


static var _content: ContentDb
## The real content plus the test relics registered by relic().
static var _relic_content: ContentDb
## Real content with only test synergies (see synergy()).
static var _synergy_content: ContentDb


## The real content from data/, loaded once.
static func content() -> ContentDb:
	if _content == null:
		_content = ContentDb.load_dir("res://data")
		assert(_content.is_valid(), "real data must be valid: %s" % [_content.errors])
	return _content


static func tuning() -> TuningDef:
	return content().tuning


## An item with essences socketed, for a unit's row.
static func equip(def: ItemDef, essences: Array[String] = [], tier: int = 0, xp: int = 0) -> ItemSetup:
	return ItemSetup.make(def, essences, tier, xp)


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


## A backup block (hero Backup effect or item backup mode). Fails loudly on errors.
static func backup(data: Dictionary) -> BackupDef:
	var errors: Array[String] = []
	var def: BackupDef = BackupDef.read(DataReader.new(data, "backup", errors), false)
	assert(errors.is_empty(), "test backup is invalid: %s" % [errors])
	return def


## A relic from `data` (an "id" and "name" are filled in), registered in
## relic_content() so fights can hold it. Fails loudly on errors.
static func relic(relic_id: String, data: Dictionary) -> RelicDef:
	var full: Dictionary = {"id": relic_id, "name": relic_id.capitalize(), "rarity": "rare"}
	full.merge(data, true)
	var errors: Array[String] = []
	var def: RelicDef = RelicDef.read(DataReader.new(full, relic_id, errors))
	assert(errors.is_empty(), "test relic %s is invalid: %s" % [relic_id, errors])
	relic_content().relics[relic_id] = def
	return def


## Real content plus test relics (see relic()).
static func relic_content() -> ContentDb:
	if _relic_content == null:
		_relic_content = ContentDb.load_dir("res://data")
	return _relic_content


static func relic_ids(defs: Array[RelicDef]) -> Array[String]:
	var ids: Array[String] = []
	for def: RelicDef in defs:
		ids.append(def.id)
	return ids


## A fight where the guild holds `relics` and the enemies `enemy_relics`.
static func relic_fight(heroes: Array[UnitSetup], enemies: Array[UnitSetup], relics: Array[RelicDef], enemy_relics: Array[RelicDef] = [], seed_value: int = 1, bench: Array[UnitSetup] = []) -> FightSetup:
	return FightSetup.make(heroes, enemies, seed_value, 1, bench, relic_ids(relics), relic_ids(enemy_relics))


static func run_relics(heroes: Array[UnitSetup], enemies: Array[UnitSetup], relics: Array[RelicDef], enemy_relics: Array[RelicDef] = [], seed_value: int = 1, bench: Array[UnitSetup] = []) -> FightResult:
	return CombatSim.run(relic_fight(heroes, enemies, relics, enemy_relics, seed_value, bench), relic_content())


## A fight built but not stepped, for checking derived values at the start.
static func relic_sim(heroes: Array[UnitSetup], enemies: Array[UnitSetup], relics: Array[RelicDef], enemy_relics: Array[RelicDef] = [], bench: Array[UnitSetup] = []) -> CombatSim:
	return CombatSim.new(relic_fight(heroes, enemies, relics, enemy_relics, 1, bench), relic_content())


## A synergy from `data` (an "id" and "name" are filled in), registered in
## synergy_content(), which holds only test synergies. Fails loudly on errors.
static func synergy(synergy_id: String, data: Dictionary) -> SynergyDef:
	var full: Dictionary = {"id": synergy_id, "name": synergy_id.capitalize()}
	full.merge(data, true)
	var errors: Array[String] = []
	var def: SynergyDef = SynergyDef.read(DataReader.new(full, synergy_id, errors))
	assert(errors.is_empty(), "test synergy %s is invalid: %s" % [synergy_id, errors])
	var db: ContentDb = synergy_content()
	db.synergies[synergy_id] = def
	if not db.synergy_ids.has(synergy_id):
		db.synergy_ids.append(synergy_id)
	return def


## Real content with no synergies but the ones registered by synergy(). Call
## clear_synergies() first so earlier tests' synergies don't match.
static func synergy_content() -> ContentDb:
	if _synergy_content == null:
		_synergy_content = ContentDb.load_dir("res://data")
		clear_synergies()
	return _synergy_content


static func clear_synergies() -> void:
	var db: ContentDb = synergy_content()
	db.synergies.clear()
	db.synergy_ids.clear()


static func synergy_sim(heroes: Array[UnitSetup], enemies: Array[UnitSetup], bench: Array[UnitSetup] = []) -> CombatSim:
	return CombatSim.new(FightSetup.make(heroes, enemies, 1, 1, bench), synergy_content())


static func synergy_run(heroes: Array[UnitSetup], enemies: Array[UnitSetup], bench: Array[UnitSetup] = []) -> FightResult:
	return CombatSim.run(FightSetup.make(heroes, enemies, 1, 1, bench), synergy_content())


## A damage-only effect list, for overrides.
static func damage(amount: int, target: String = "enemy_front") -> Array:
	return [{"trigger": "on_fire", "type": "damage", "amount": amount, "target": target}]


## `items` may mix ItemDefs (no essences) and ItemSetups (from equip()).
static func unit(unit_id: String, hp: int, row: UnitSetup.Row = UnitSetup.Row.FRONT, items: Array = [], basic_attack: ItemDef = null) -> UnitSetup:
	var attack: ItemDef = basic_attack if basic_attack != null else basic()
	var row_items: Array[ItemSetup] = []
	for entry: Variant in items:
		row_items.append(entry if entry is ItemSetup else ItemSetup.make(entry))
	return UnitSetup.make(unit_id, unit_id, UnitStats.make(hp), row, 7, attack, row_items)


## A unit with a full stat block and rank.
static func unit_with(unit_id: String, stats: UnitStats, row: UnitSetup.Row = UnitSetup.Row.FRONT, items: Array = [], basic_attack: ItemDef = null, rank: int = 0) -> UnitSetup:
	var setup: UnitSetup = unit(unit_id, 1, row, items, basic_attack)
	setup.stats = stats
	setup.rank = rank
	return setup


## A unit whose basic attack never matters: 1 damage every 60s.
static func dummy(unit_id: String, hp: int, row: UnitSetup.Row = UnitSetup.Row.FRONT) -> UnitSetup:
	return unit(unit_id, hp, row, [], basic("idle", {"cooldown_ms": 60000, "effects": damage(1)}))


static func fight(heroes: Array[UnitSetup], enemies: Array[UnitSetup], seed_value: int = 1, act: int = 1) -> FightSetup:
	return FightSetup.make(heroes, enemies, seed_value, act)


static func run(heroes: Array[UnitSetup], enemies: Array[UnitSetup], seed_value: int = 1, act: int = 1, bench: Array[UnitSetup] = []) -> FightResult:
	return CombatSim.run(FightSetup.make(heroes, enemies, seed_value, act, bench), content())


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
