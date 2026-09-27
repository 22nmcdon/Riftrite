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
## Fires when the unit has no basic-attack item. Can't be infused.
var basic_attack: ItemDef
## The loadout: a basic-attack item (at most one), abilities, and passives,
## in loadout order. Slot counts are the run layer's rule, not the sim's.
var items: Array[ItemSetup] = []
## The hero's innate parts (HeroDef.innate), credited to `innate_name`.
var innate: Array[SpecializationDef.Part] = []
## The hero's rank-B specialization, or null. Which parts apply depends on
## the rank (locked potential).
var specialization: SpecializationDef = null
## HP-threshold phases (enemies; see PhaseDef).
var phases: Array[PhaseDef] = []


static func make(unit_id: String, unit_name: String, unit_stats: UnitStats, unit_row: Row, basic: ItemDef, loadout: Array[ItemSetup] = [], unit_rank: int = 0) -> UnitSetup:
	var setup := UnitSetup.new()
	setup.id = unit_id
	setup.name = unit_name
	setup.stats = unit_stats
	setup.rank = unit_rank
	setup.row = unit_row
	setup.basic_attack = basic
	setup.items = loadout
	return setup


func validate(content: ContentDb, errors: Array[String]) -> void:
	if stats == null or stats.get_stat(UnitStats.Stat.HP) < 1:
		errors.append("%s: HP must be at least 1" % id)
	elif stats.values.any(func(value: int) -> bool: return value < 0):
		errors.append("%s: stats can't be negative" % id)
	if rank < 0 or rank >= TuningDef.TIER_NAMES.size():
		errors.append("%s: rank must be 0-3 (C-S)" % id)
	if specialization != null:
		if rank < 1:
			errors.append("%s: a rank-C hero has no specialization (\"%s\")" % [id, specialization.id])
		if specialization.hero != id:
			errors.append("%s: specialization \"%s\" belongs to %s" % [id, specialization.id, specialization.hero])
	if basic_attack == null or not basic_attack.is_basic_attack:
		errors.append("%s: needs a basic auto-attack" % id)
	else:
		_validate_effects(basic_attack, content, errors)
	var auto_attacks: int = 0
	for item: ItemSetup in items:
		if item.def.is_basic_attack:
			errors.append("%s: basic auto-attack \"%s\" can't sit in an item slot" % [id, item.def.id])
		if item.def.auto_attack:
			auto_attacks += 1
		_validate_effects(item.def, content, errors)
		_validate_essences(item, content, errors)
		if item.infusion_xp < 0 or (item.infusion_xp > 0 and item.essence_ids.is_empty()):
			errors.append("%s: item \"%s\" has %d infusion XP but no infusion" % [id, item.def.id, item.infusion_xp])
		if item.tier < 0 or item.tier >= TuningDef.TIER_NAMES.size():
			errors.append("%s: item \"%s\" tier must be 0-3 (C-S)" % [id, item.def.id])
	if auto_attacks > 1:
		errors.append("%s: has %d basic-attack items; the limit is one" % [id, auto_attacks])


## Rejects effects that point at content that doesn't exist.
func _validate_effects(item: ItemDef, content: ContentDb, errors: Array[String]) -> void:
	for effect: EffectDef in item.effects:
		if effect.type == EffectDef.Type.APPLY_STATUS and not content.statuses.has(effect.status_id):
			errors.append("%s: item \"%s\" applies unknown status \"%s\"" % [id, item.id, effect.status_id])


func _validate_essences(item: ItemSetup, content: ContentDb, errors: Array[String]) -> void:
	if item.essence_ids.size() > Infusions.MAX_ESSENCES:
		errors.append("%s: item \"%s\" has %d essences; an infusion holds at most %d" % [id, item.def.id, item.essence_ids.size(), Infusions.MAX_ESSENCES])
	for essence_id: String in item.essence_ids:
		if not content.essences.has(essence_id):
			errors.append("%s: item \"%s\" has unknown essence \"%s\"" % [id, item.def.id, essence_id])
