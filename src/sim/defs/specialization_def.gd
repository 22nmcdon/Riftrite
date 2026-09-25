class_name SpecializationDef
extends RefCounted
## A hero's rank-B specialization from data/specializations.json
## (docs/plans/specializations-in-sim.md). Each hero has three of their own.
## It is a set of parts by rank: "b" parts apply from rank B, "a" parts unlock
## at A, "s" parts at S (locked potential). A later part with the same "key"
## replaces the earlier one; a new key adds.
##
## Part kinds ("kind"):
##   aura:           an AuraDef from the hero (targets below)
##   grant:          a GrantDef on the hero's items, numbered from the hero's
##                   stats (not flat like a relic's)
##   ability:        {"name"?, "cooldown_ms"?, "effects": [...]}: a slotless
##                   effect scaled from the hero's stats, firing on its
##                   cooldown (on_fire) or a relic trigger (on_fight_start,
##                   at_time, on_ally_below_hp)
##   basic_attack:   {"basic_attack": {...}} replaces the hero's own. Needs an
##                   auto_attack part (an aura or grant filtered to
##                   {"auto_attack": true}) at the same or an earlier rank, so
##                   an auto-attack item doesn't blank the specialization
##   backup:         {"backup": {...}} adds to the hero's Backup effect
##   replace_status: {"from": "burn", "to": "golden_flame"}: the hero's items
##                   apply one status as another, like an alloy special
## "when": fielded (default), benched, or always. basic_attack is fielded
## only; backup is benched only.

enum Kind { AURA, GRANT, ABILITY, BASIC_ATTACK, BACKUP, REPLACE_STATUS }
enum When { FIELDED, BENCHED, ALWAYS }

const KIND_NAMES: Array[String] = ["aura", "grant", "ability", "basic_attack", "backup", "replace_status"]
const WHEN_NAMES: Array[String] = ["fielded", "benched", "always"]
## Rank letters in unlock order, and the hero rank each unlocks at.
const RANK_KEYS: Array[String] = ["b", "a", "s"]
const AURA_TARGETS: Array[AuraDef.Target] = [
	AuraDef.Target.HOLDER, AuraDef.Target.HOLDER_ITEMS, AuraDef.Target.LINKED_ALLY, AuraDef.Target.LINKED_LEFT_ALLY,
	AuraDef.Target.LINKED_RIGHT_ALLY, AuraDef.Target.LINKED_ALLIES, AuraDef.Target.ROW_ALLIES,
	AuraDef.Target.ALL_ALLIES, AuraDef.Target.ALL_ITEMS,
]
## Aura targets that need the hero standing in a row (not from backup).
const FIELD_AURA_TARGETS: Array[AuraDef.Target] = [
	AuraDef.Target.LINKED_ALLY, AuraDef.Target.LINKED_LEFT_ALLY, AuraDef.Target.LINKED_RIGHT_ALLY,
	AuraDef.Target.LINKED_ALLIES, AuraDef.Target.ROW_ALLIES,
]


class Part:
	var key: String
	var kind: Kind
	var when: When = When.FIELDED
	## "B", "A", or "S": the rank it unlocks at.
	var rank_label: String
	## "Hearthwall A", for the log.
	var label: String
	var aura: AuraDef = null
	var grant: GrantDef = null
	## ability or basic_attack: the item it becomes.
	var item: ItemDef = null
	var backup: BackupDef = null
	var replace_from: String = ""
	var replace_to: String = ""

	func applies(benched: bool) -> bool:
		return when == When.ALWAYS or (when == When.BENCHED) == benched

	## True for an aura or grant aimed at the auto-attack.
	func covers_auto_attack() -> bool:
		if aura != null:
			return aura.filter != null and aura.filter.auto_attack
		if grant != null:
			return grant.filter != null and grant.filter.auto_attack
		return false


var id: String
var hero: String
var name: String
## Parts by rank: [b parts, a parts, s parts].
var ranks: Array[Array] = [[], [], []]


static func read(reader: DataReader) -> SpecializationDef:
	var def := SpecializationDef.new()
	def.id = reader.req_string("id")
	def.hero = reader.req_string("hero")
	def.name = reader.req_string("name")
	var ranks_reader: DataReader = reader.req_object("ranks")
	if ranks_reader != null:
		for key: String in ranks_reader.map_keys():
			if not RANK_KEYS.has(key):
				ranks_reader.error("unknown rank \"%s\" (expected b, a, or s)" % key)
		for r: int in RANK_KEYS.size():
			if not ranks_reader.has(RANK_KEYS[r]):
				continue
			var keys: Array[String] = []
			for part_reader: DataReader in ranks_reader.opt_object_array(RANK_KEYS[r]):
				var part: Part = _read_part(def, part_reader, r)
				if keys.has(part.key):
					part_reader.error("key \"%s\" is used twice in rank %s" % [part.key, RANK_KEYS[r]])
				keys.append(part.key)
				def.ranks[r].append(part)
		ranks_reader.finish()
		if def.ranks[0].is_empty():
			reader.error("a specialization needs rank b parts")
	_check_auto_attack(def, reader)
	reader.finish()
	return def


static func _read_part(def: SpecializationDef, reader: DataReader, rank: int) -> Part:
	var part := Part.new()
	part.key = reader.req_string("key")
	var kind_name: String = reader.req_choice("kind", KIND_NAMES)
	part.kind = maxi(KIND_NAMES.find(kind_name), 0) as Kind
	part.when = maxi(WHEN_NAMES.find(reader.opt_string_choice("when", "fielded", WHEN_NAMES)), 0) as When
	part.rank_label = RANK_KEYS[rank].to_upper()
	part.label = "%s %s" % [def.name, part.rank_label]
	if kind_name.is_empty():
		reader.finish()
		return part
	match part.kind:
		Kind.AURA:
			part.aura = AuraDef.read(reader)
			if not AURA_TARGETS.has(part.aura.target):
				reader.error("a specialization aura can't target %s" % AuraDef.TARGET_NAMES[part.aura.target])
			elif part.when != When.FIELDED and FIELD_AURA_TARGETS.has(part.aura.target):
				reader.error("\"%s\" needs the hero on the field, so it can't work from backup" % AuraDef.TARGET_NAMES[part.aura.target])
			return part
		Kind.GRANT:
			part.grant = GrantDef.read(reader, true)
			return part
		Kind.ABILITY:
			part.item = _read_ability(def, part, reader)
		Kind.BASIC_ATTACK:
			var attack_reader: DataReader = reader.req_object("basic_attack")
			if attack_reader != null:
				part.item = ItemDef.read_basic_attack(attack_reader)
			if part.when != When.FIELDED:
				reader.error("a new basic attack only works on the field")
		Kind.BACKUP:
			var backup_reader: DataReader = reader.req_object("backup")
			if backup_reader != null:
				part.backup = BackupDef.read(backup_reader, true)
				if part.backup.name.is_empty():
					part.backup.name = part.label
			part.when = When.BENCHED
		Kind.REPLACE_STATUS:
			part.replace_from = reader.req_string("from")
			part.replace_to = reader.req_string("to")
	reader.finish()
	return part


## An ability as a slotless item that fires from the hero.
static func _read_ability(def: SpecializationDef, part: Part, reader: DataReader) -> ItemDef:
	var item := ItemDef.new()
	item.id = "%s_%s" % [def.id, part.key]
	# The log names the specialization: "Catch (Hearthwall A)", or just
	# "Hearthwall A" for an unnamed ability.
	item.name = "%s (%s)" % [reader.req_string("name"), part.label] if reader.has("name") else part.label
	item.is_ability = true
	var fires: bool = false
	for effect_reader: DataReader in reader.opt_object_array("effects"):
		var effect: EffectDef = EffectDef.read(effect_reader, false, true)
		fires = fires or effect.trigger == EffectDef.Trigger.ON_FIRE
		item.effects.append(effect)
	if item.effects.is_empty():
		reader.error("an ability needs effects")
	if fires:
		item.cooldown_ticks = reader.req_ticks("cooldown_ms", FixedMath.MS_PER_TICK)
	else:
		item.triggered_only = true
		item.cooldown_ticks = 1
		if reader.has("cooldown_ms"):
			reader.error("cooldown_ms only matters for on_fire effects")
			reader.req_ticks("cooldown_ms")
	return item


## A basic_attack part needs an auto_attack part at its rank or before.
static func _check_auto_attack(def: SpecializationDef, reader: DataReader) -> void:
	var covered: bool = false
	for r: int in RANK_KEYS.size():
		for part: Part in def.ranks[r]:
			covered = covered or part.covers_auto_attack()
		for part: Part in def.ranks[r]:
			if part.kind == Kind.BASIC_ATTACK and not covered:
				reader.error("rank %s replaces the basic attack, so it needs a part for auto-attack items too (an aura or grant with {\"auto_attack\": true})" % RANK_KEYS[r])


## The parts that apply at a hero rank (1 = B, 2 = A, 3 = S). A later part
## replaces an earlier one with the same key, in its place.
func parts_at(rank: int) -> Array[Part]:
	var result: Array[Part] = []
	for r: int in mini(rank, RANK_KEYS.size()):
		for part: Part in ranks[r]:
			var replaced: bool = false
			for i: int in result.size():
				if result[i].key == part.key:
					result[i] = part
					replaced = true
			if not replaced:
				result.append(part)
	return result


## Every part at every rank, for content checks.
func all_parts() -> Array[Part]:
	var result: Array[Part] = []
	for rank_parts: Array in ranks:
		for part: Part in rank_parts:
			result.append(part)
	return result
