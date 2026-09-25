class_name UnitSetup
extends RefCounted
## One hero or enemy as it enters a fight. Units in the same row stand left
## to right in the order they are listed in FightSetup.

enum Row { FRONT, BACK }
enum Side { HEROES, ENEMIES }

## Unique within the fight; used in the combat log.
var id: String
var name: String
## A hero's class (HeroDef.CLASSES), for class filters; "" for enemies.
var unit_class: String = ""
## Stats before the rank boost.
var stats: UnitStats
## 0 = C, 1 = B, 2 = A, 3 = S. Each rank boosts every stat (tuning).
var rank: int = 0
var row: Row = Row.FRONT
## Item slots available. Item sizes must fit.
var slots: int
## Fires when the unit has no auto-attack item. Takes no slot and can't be
## infused.
var basic_attack: ItemDef
## In row order, left to right.
var items: Array[ItemSetup] = []
## The hero's own Backup effect (used when benched), or null.
var backup: BackupDef = null


static func make(unit_id: String, unit_name: String, unit_stats: UnitStats, unit_row: Row, unit_slots: int, basic: ItemDef, row_items: Array[ItemSetup] = [], unit_rank: int = 0) -> UnitSetup:
	var setup := UnitSetup.new()
	setup.id = unit_id
	setup.name = unit_name
	setup.stats = unit_stats
	setup.rank = unit_rank
	setup.row = unit_row
	setup.slots = unit_slots
	setup.basic_attack = basic
	setup.items = row_items
	return setup


func validate(content: ContentDb, errors: Array[String]) -> void:
	if stats == null or stats.get_stat(UnitStats.Stat.HP) < 1:
		errors.append("%s: HP must be at least 1" % id)
	elif stats.values.any(func(value: int) -> bool: return value < 0):
		errors.append("%s: stats can't be negative" % id)
	if rank < 0 or rank >= TuningDef.TIER_NAMES.size():
		errors.append("%s: rank must be 0-3 (C-S)" % id)
	if basic_attack == null or not basic_attack.is_basic_attack:
		errors.append("%s: needs a basic auto-attack" % id)
	else:
		_validate_effects(basic_attack, content, errors)
	var used_slots: int = 0
	var auto_attacks: int = 0
	for item: ItemSetup in items:
		if item.def.is_basic_attack:
			errors.append("%s: basic auto-attack \"%s\" can't sit in an item slot" % [id, item.def.id])
		used_slots += item.def.size
		if item.def.auto_attack:
			auto_attacks += 1
		_validate_effects(item.def, content, errors)
		_validate_essences(item, content, errors)
		if item.infusion_xp < 0 or (item.infusion_xp > 0 and item.essence_ids.is_empty()):
			errors.append("%s: item \"%s\" has %d infusion XP but no infusion" % [id, item.def.id, item.infusion_xp])
		if item.tier < 0 or item.tier >= TuningDef.TIER_NAMES.size():
			errors.append("%s: item \"%s\" tier must be 0-3 (C-S)" % [id, item.def.id])
	if used_slots > slots:
		errors.append("%s: items take %d slots but the unit has %d" % [id, used_slots, slots])
	if auto_attacks > 1:
		errors.append("%s: has %d auto-attack items; the limit is one" % [id, auto_attacks])


## Rejects effects that point at content that doesn't exist.
func _validate_effects(item: ItemDef, content: ContentDb, errors: Array[String]) -> void:
	for effect: EffectDef in item.effects:
		if effect.type == EffectDef.Type.APPLY_STATUS and not content.statuses.has(effect.status_id):
			errors.append("%s: item \"%s\" applies unknown status \"%s\"" % [id, item.id, effect.status_id])


func _validate_essences(item: ItemSetup, content: ContentDb, errors: Array[String]) -> void:
	if item.essence_ids.size() > item.socket_count():
		errors.append("%s: item \"%s\" has %d essences but only %d socket(s)" % [id, item.def.id, item.essence_ids.size(), item.socket_count()])
	for essence_id: String in item.essence_ids:
		if not content.essences.has(essence_id):
			errors.append("%s: item \"%s\" has unknown essence \"%s\"" % [id, item.def.id, essence_id])
