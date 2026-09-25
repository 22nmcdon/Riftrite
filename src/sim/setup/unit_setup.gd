class_name UnitSetup
extends RefCounted
## One hero or enemy as it enters a fight. Units in the same row stand left
## to right in the order they are listed in FightSetup.

enum Row { FRONT, BACK }
enum Side { HEROES, ENEMIES }

## Unique within the fight; used in the combat log.
var id: String
var name: String
var max_hp: int
var row: Row = Row.FRONT
## Item slots available. Item sizes must fit.
var slots: int
## Fires when the unit has no auto-attack item. Takes no slot.
var basic_attack: ItemDef
## In row order, left to right.
var items: Array[ItemDef] = []


static func make(unit_id: String, unit_name: String, hp: int, unit_row: Row, unit_slots: int, basic: ItemDef, row_items: Array[ItemDef] = []) -> UnitSetup:
	var setup := UnitSetup.new()
	setup.id = unit_id
	setup.name = unit_name
	setup.max_hp = hp
	setup.row = unit_row
	setup.slots = unit_slots
	setup.basic_attack = basic
	setup.items = row_items
	return setup


func validate(errors: Array[String]) -> void:
	if max_hp < 1:
		errors.append("%s: max_hp must be at least 1" % id)
	if basic_attack == null or not basic_attack.is_basic_attack:
		errors.append("%s: needs a basic auto-attack" % id)
	else:
		_validate_effects(basic_attack, errors)
	var used_slots: int = 0
	var auto_attacks: int = 0
	for item: ItemDef in items:
		if item.is_basic_attack:
			errors.append("%s: basic auto-attack \"%s\" can't sit in an item slot" % [id, item.id])
		used_slots += item.size
		if item.auto_attack:
			auto_attacks += 1
		_validate_effects(item, errors)
	if used_slots > slots:
		errors.append("%s: items take %d slots but the unit has %d" % [id, used_slots, slots])
	if auto_attacks > 1:
		errors.append("%s: has %d auto-attack items; the limit is one" % [id, auto_attacks])


## Rejects effects the sim can't run yet, so nothing is silently skipped.
## (Statuses arrive in build step 4 and Linked in step 7.)
func _validate_effects(item: ItemDef, errors: Array[String]) -> void:
	for effect: EffectDef in item.effects:
		if effect.type == EffectDef.Type.APPLY_STATUS:
			errors.append("%s: item \"%s\" applies a status, which the sim doesn't support yet" % [id, item.id])
		if effect.target == EffectDef.Target.LINKED_ALLY:
			errors.append("%s: item \"%s\" targets linked_ally, which the sim doesn't support yet" % [id, item.id])
