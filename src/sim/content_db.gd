class_name ContentDb
extends RefCounted
## All game content loaded from data/, validated, and converted to typed defs
## (durations in ticks, percentages in basis points).
##
## Loading never stops at the first problem: every error found is collected in
## `errors`, so one validator run reports everything. Only use a ContentDb
## whose is_valid() is true.
##
## Lookups by id use the dictionaries. Anything that loops over content must
## use the *_ids arrays (file order), never the dictionaries (CLAUDE.md rule 1).

const TUNING_FILE: String = "tuning.json"
const STATUSES_FILE: String = "statuses.json"
const ESSENCES_FILE: String = "essences.json"
const ALLOYS_FILE: String = "alloys.json"
const ITEMS_FILE: String = "items.json"
const HEROES_FILE: String = "heroes.json"
const ENEMIES_FILE: String = "enemies.json"
const ENCOUNTERS_FILE: String = "encounters.json"
const RELICS_FILE: String = "relics.json"
const SYNERGIES_FILE: String = "synergies.json"
const SPECIALIZATIONS_FILE: String = "specializations.json"
const FILES: Array[String] = [TUNING_FILE, STATUSES_FILE, ESSENCES_FILE, ALLOYS_FILE, ITEMS_FILE, HEROES_FILE, ENEMIES_FILE, ENCOUNTERS_FILE, RELICS_FILE, SYNERGIES_FILE, SPECIALIZATIONS_FILE]

var errors: Array[String] = []
var tuning: TuningDef
var statuses: Dictionary[String, StatusDef] = {}
var status_ids: Array[String] = []
var essences: Dictionary[String, EssenceDef] = {}
var essence_ids: Array[String] = []
var alloys: Dictionary[String, AlloyDef] = {}
var alloy_ids: Array[String] = []
var items: Dictionary[String, ItemDef] = {}
var item_ids: Array[String] = []
var heroes: Dictionary[String, HeroDef] = {}
var hero_ids: Array[String] = []
var enemies: Dictionary[String, EnemyDef] = {}
var enemy_ids: Array[String] = []
var encounters: Dictionary[String, EncounterDef] = {}
var encounter_ids: Array[String] = []
var relics: Dictionary[String, RelicDef] = {}
var relic_ids: Array[String] = []
var synergies: Dictionary[String, SynergyDef] = {}
var synergy_ids: Array[String] = []
var specializations: Dictionary[String, SpecializationDef] = {}
var specialization_ids: Array[String] = []
## Recipe key (AlloyDef.recipe_key) -> alloy. Two essences with no entry
## here still work as an alloy, just without a named special.
var _alloys_by_recipe: Dictionary[String, AlloyDef] = {}

var _id_pattern: RegEx = RegEx.create_from_string("^[a-z][a-z0-9_]*$")


## Loads every content file from a directory such as "res://data".
static func load_dir(dir: String) -> ContentDb:
	var texts: Dictionary[String, String] = {}
	var missing: Array[String] = []
	for file_name: String in FILES:
		var file_path: String = dir.path_join(file_name)
		if FileAccess.file_exists(file_path):
			texts[file_name] = FileAccess.get_file_as_string(file_path)
		else:
			missing.append("%s: file not found" % file_path)
	var db: ContentDb = load_texts(texts)
	# Missing-file errors go first, before whatever they caused.
	missing.append_array(db.errors)
	db.errors = missing
	return db


## Loads content from file name -> JSON text. Used by load_dir and by tests.
static func load_texts(texts: Dictionary[String, String]) -> ContentDb:
	var db := ContentDb.new()
	db._load_tuning(db._parse(texts, TUNING_FILE))
	db._load_statuses(db._parse(texts, STATUSES_FILE))
	db._load_essences(db._parse(texts, ESSENCES_FILE))
	db._load_alloys(db._parse(texts, ALLOYS_FILE))
	for reader: DataReader in db._entries(db._parse(texts, ITEMS_FILE), ITEMS_FILE):
		var item: ItemDef = ItemDef.read(reader)
		if db._claim_id(item.id, reader, db.item_ids):
			db.items[item.id] = item
	for reader: DataReader in db._entries(db._parse(texts, HEROES_FILE), HEROES_FILE):
		var hero: HeroDef = HeroDef.read(reader)
		if db._claim_id(hero.id, reader, db.hero_ids):
			db.heroes[hero.id] = hero
	for reader: DataReader in db._entries(db._parse(texts, ENEMIES_FILE), ENEMIES_FILE):
		var enemy: EnemyDef = EnemyDef.read(reader)
		if db._claim_id(enemy.id, reader, db.enemy_ids):
			db.enemies[enemy.id] = enemy
	for reader: DataReader in db._entries(db._parse(texts, ENCOUNTERS_FILE), ENCOUNTERS_FILE):
		var encounter: EncounterDef = EncounterDef.read(reader)
		if db._claim_id(encounter.id, reader, db.encounter_ids):
			db.encounters[encounter.id] = encounter
	for reader: DataReader in db._entries(db._parse(texts, RELICS_FILE), RELICS_FILE):
		var relic: RelicDef = RelicDef.read(reader)
		if db._claim_id(relic.id, reader, db.relic_ids):
			db.relics[relic.id] = relic
	for reader: DataReader in db._entries(db._parse(texts, SYNERGIES_FILE), SYNERGIES_FILE):
		var synergy: SynergyDef = SynergyDef.read(reader)
		if db._claim_id(synergy.id, reader, db.synergy_ids):
			db.synergies[synergy.id] = synergy
	for reader: DataReader in db._entries(db._parse(texts, SPECIALIZATIONS_FILE), SPECIALIZATIONS_FILE):
		var specialization: SpecializationDef = SpecializationDef.read(reader)
		if db._claim_id(specialization.id, reader, db.specialization_ids):
			db.specializations[specialization.id] = specialization
	db._check_references()
	return db


func is_valid() -> bool:
	return errors.is_empty()


func _parse(texts: Dictionary[String, String], file_name: String) -> Variant:
	if not texts.has(file_name):
		errors.append("%s: missing" % file_name)
		return null
	var json := JSON.new()
	if json.parse(texts[file_name]) != OK:
		errors.append("%s: invalid JSON on line %d: %s" % [file_name, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func _load_tuning(data: Variant) -> void:
	if data == null:
		return
	var reader: DataReader = DataReader.from_value(data, TUNING_FILE, errors)
	if reader != null:
		tuning = TuningDef.read(reader)


func _load_statuses(data: Variant) -> void:
	for reader: DataReader in _entries(data, STATUSES_FILE):
		var def: StatusDef = StatusDef.read(reader)
		if _claim_id(def.id, reader, status_ids):
			statuses[def.id] = def


func _load_essences(data: Variant) -> void:
	for reader: DataReader in _entries(data, ESSENCES_FILE):
		var def: EssenceDef = EssenceDef.read(reader)
		if _claim_id(def.id, reader, essence_ids):
			essences[def.id] = def


func _load_alloys(data: Variant) -> void:
	for reader: DataReader in _entries(data, ALLOYS_FILE):
		var def: AlloyDef = AlloyDef.read(reader)
		if _claim_id(def.id, reader, alloy_ids):
			alloys[def.id] = def


## The named alloy for two essences (either order), or null.
func alloy_for(first: String, second: String) -> AlloyDef:
	return _alloys_by_recipe.get(AlloyDef.recipe_key(first, second), null)


## Wraps each element of a top-level list. Paths look like
## `essences.json[1] (frost)` so errors name the entry.
func _entries(data: Variant, file_name: String) -> Array[DataReader]:
	var readers: Array[DataReader] = []
	if data == null:
		return readers
	if typeof(data) != TYPE_ARRAY:
		errors.append("%s: expected a list of entries" % file_name)
		return readers
	var items: Array = data
	for i: int in items.size():
		var label: String = "%s[%d]" % [file_name, i]
		if typeof(items[i]) == TYPE_DICTIONARY and typeof(items[i].get("id")) == TYPE_STRING:
			label += " (%s)" % items[i]["id"]
		var reader: DataReader = DataReader.from_value(items[i], label, errors)
		if reader != null:
			readers.append(reader)
	return readers


## Records an id in `ids` if it is well-formed and not taken. Returns false
## (after reporting why) if the entry should be skipped.
func _claim_id(id: String, reader: DataReader, ids: Array[String]) -> bool:
	if id.is_empty():
		return false
	if _id_pattern.search(id) == null:
		reader.error("id \"%s\" must be lowercase letters, digits, and underscores, starting with a letter" % id)
		return false
	if ids.has(id):
		reader.error("duplicate id \"%s\"" % id)
		return false
	ids.append(id)
	return true


func _check_references() -> void:
	for id: String in essence_ids:
		_check_effects(essences[id].effects, "%s (%s)" % [ESSENCES_FILE, id])
		var adds: String = essences[id].adds
		if not adds.is_empty() and not is_output_kind(adds):
			errors.append("%s (%s): adds \"%s\", which is not damage, shield, heal, or a damage-over-time status" % [ESSENCES_FILE, id, adds])
	for id: String in alloy_ids:
		var alloy: AlloyDef = alloys[id]
		var where: String = "%s (%s)" % [ALLOYS_FILE, id]
		if alloy.recipe.size() != 2:
			continue
		for essence_id: String in alloy.recipe:
			if not essences.has(essence_id):
				errors.append("%s: recipe uses unknown essence \"%s\"" % [where, essence_id])
		var key: String = AlloyDef.recipe_key(alloy.recipe[0], alloy.recipe[1])
		if _alloys_by_recipe.has(key):
			errors.append("%s: recipe %s is already used by \"%s\"" % [where, key, _alloys_by_recipe[key].id])
		else:
			_alloys_by_recipe[key] = alloy
		var replaced: Array = alloy.replaces.keys()
		replaced.sort()
		for from_status: String in replaced:
			var to_status: String = alloy.replaces[from_status]
			for status_id: String in [from_status, to_status]:
				if not statuses.has(status_id):
					errors.append("%s: replaces uses unknown status \"%s\"" % [where, status_id])


	for id: String in item_ids:
		var item_where: String = "%s (%s)" % [ITEMS_FILE, id]
		_check_effects(items[id].effects, item_where)
		_check_auras(items[id].auras, item_where)
		_check_no_partners(items[id].effects, item_where)
		for i: int in items[id].auras.size():
			if items[id].auras[i].target == AuraDef.Target.MATCHED_ITEMS:
				errors.append("%s.auras[%d]: matched_items only works in a synergy" % [item_where, i])
			if items[id].auras[i].target == AuraDef.Target.HOLDER_ITEMS:
				errors.append("%s.auras[%d]: holder_items only works in a specialization" % [item_where, i])
	for id: String in hero_ids:
		if heroes[id].basic_attack != null:
			_check_effects(heroes[id].basic_attack.effects, "%s (%s).basic_attack" % [HEROES_FILE, id])
	for id: String in enemy_ids:
		var enemy: EnemyDef = enemies[id]
		var where: String = "%s (%s)" % [ENEMIES_FILE, id]
		if enemy.basic_attack != null:
			_check_effects(enemy.basic_attack.effects, where + ".basic_attack")
		check_loadout(enemy.items, where, true)
		if not enemy.essence.is_empty() and not essences.has(enemy.essence):
			errors.append("%s: unknown essence \"%s\"" % [where, enemy.essence])
	for id: String in encounter_ids:
		var encounter: EncounterDef = encounters[id]
		for slot: EncounterDef.Slot in encounter.units:
			if not enemies.has(slot.enemy_id):
				errors.append("%s (%s): unknown enemy \"%s\"" % [ENCOUNTERS_FILE, id, slot.enemy_id])
		if tuning != null and tuning.collapse_for_act(encounter.act) == null:
			errors.append("%s (%s): act %d has no Rift Collapse numbers in tuning" % [ENCOUNTERS_FILE, id, encounter.act])
		check_relics(encounter.relics, "%s (%s)" % [ENCOUNTERS_FILE, id], true)
	for id: String in relic_ids:
		var relic: RelicDef = relics[id]
		var where: String = "%s (%s)" % [RELICS_FILE, id]
		_check_effects(relic.effects, where)
		_check_auras(relic.auras, where)
		for i: int in relic.grants.size():
			var grant: GrantDef = relic.grants[i]
			var effect_list: Array[EffectDef] = [grant.effect]
			_check_effects(effect_list, "%s.grants[%d]" % [where, i])
			_check_filter(grant.filter, "%s.grants[%d]" % [where, i])
			_check_no_partners(effect_list, "%s.grants[%d]" % [where, i])
	for id: String in synergy_ids:
		_check_synergy(synergies[id], "%s (%s)" % [SYNERGIES_FILE, id])
	var per_hero: Dictionary[String, int] = {}
	for id: String in specialization_ids:
		var specialization: SpecializationDef = specializations[id]
		_check_specialization(specialization, "%s (%s)" % [SPECIALIZATIONS_FILE, id])
		per_hero[specialization.hero] = per_hero.get(specialization.hero, 0) + 1
	for hero_id: String in hero_ids:
		if per_hero.get(hero_id, 0) > 3:
			errors.append("%s: %s has %d specializations; the limit is 3" % [SPECIALIZATIONS_FILE, hero_id, per_hero[hero_id]])


func _check_specialization(specialization: SpecializationDef, where: String) -> void:
	if not heroes.has(specialization.hero):
		errors.append("%s: unknown hero \"%s\"" % [where, specialization.hero])
	for part: SpecializationDef.Part in specialization.all_parts():
		var at: String = "%s.%s" % [where, part.key]
		if part.aura != null:
			var auras_list: Array[AuraDef] = [part.aura]
			_check_auras(auras_list, at)
		if part.grant != null:
			var grant_effects: Array[EffectDef] = [part.grant.effect]
			_check_effects(grant_effects, at)
			_check_filter(part.grant.filter, at)
			_check_no_partners(grant_effects, at)
		if part.item != null:
			_check_effects(part.item.effects, at)
			_check_no_partners(part.item.effects, at)
		if part.backup != null:
			_check_effects(part.backup.effects, at)
		for status_id: String in [part.replace_from, part.replace_to]:
			if part.kind == SpecializationDef.Kind.REPLACE_STATUS and not statuses.has(status_id):
				errors.append("%s: unknown status \"%s\"" % [at, status_id])


func _check_synergy(synergy: SynergyDef, where: String) -> void:
	for item_id: String in synergy.items:
		if not items.has(item_id):
			errors.append("%s: unknown item \"%s\"" % [where, item_id])
	if not synergy.hero.is_empty() and not heroes.has(synergy.hero):
		errors.append("%s: unknown hero \"%s\"" % [where, synergy.hero])
	if not synergy.essence.is_empty() and not essences.has(synergy.essence):
		errors.append("%s: unknown essence \"%s\"" % [where, synergy.essence])
	_check_effects(synergy.item_effects, where + ".item_effects")
	_check_no_partners(synergy.item_effects, where + ".item_effects")
	for bonus: RelicDef in synergy.all_bonuses():
		_check_effects(bonus.effects, where)
		_check_auras(bonus.auras, where)
		for i: int in bonus.grants.size():
			var grant_effects: Array[EffectDef] = [bonus.grants[i].effect]
			_check_effects(grant_effects, "%s.grants[%d]" % [where, i])
			_check_filter(bonus.grants[i].filter, "%s.grants[%d]" % [where, i])
			if synergy.layer != SynergyDef.Layer.PAIR:
				_check_no_partners(grant_effects, "%s.grants[%d]" % [where, i])


## partner_items (charge) only means something in a pair synergy's grants.
func _check_no_partners(effects: Array[EffectDef], where: String) -> void:
	for i: int in effects.size():
		if effects[i].type == EffectDef.Type.CHARGE and effects[i].item_target == EffectDef.ItemTarget.PARTNER_ITEMS:
			errors.append("%s.effects[%d]: partner_items only works in a pair synergy's grants" % [where, i])


## Checks a list of relic ids: each exists, none twice. Enemy-only relics are
## allowed only when `enemy` is true.
func check_relics(relic_list: Array[String], where: String, enemy: bool) -> void:
	for i: int in relic_list.size():
		var relic_id: String = relic_list[i]
		var at: String = "%s.relics[%d]" % [where, i]
		if not relics.has(relic_id):
			errors.append("%s: unknown relic \"%s\"" % [at, relic_id])
		elif relics[relic_id].enemy_only and not enemy:
			errors.append("%s: \"%s\" is enemy-only" % [at, relic_id])
		if relic_list.find(relic_id) < i:
			errors.append("%s: \"%s\" is listed twice" % [at, relic_id])


## Checks a fixed item layout's references: items, essences, and sockets.
## Enemy-only items are allowed only when `enemy` is true.
func check_loadout(entries: Array[LoadoutEntry], where: String, enemy: bool) -> void:
	for i: int in entries.size():
		var entry: LoadoutEntry = entries[i]
		var at: String = "%s.items[%d]" % [where, i]
		if not items.has(entry.item_id):
			errors.append("%s: unknown item \"%s\"" % [at, entry.item_id])
			continue
		var item: ItemDef = items[entry.item_id]
		if item.enemy_only and not enemy:
			errors.append("%s: \"%s\" is enemy-only" % [at, entry.item_id])
		var sockets: int = tuning.socket_count(item) if tuning != null else 1
		if entry.essence_ids.size() > sockets:
			errors.append("%s: \"%s\" has %d essences but only %d socket(s)" % [at, entry.item_id, entry.essence_ids.size(), sockets])
		for essence_id: String in entry.essence_ids:
			if not essences.has(essence_id):
				errors.append("%s: unknown essence \"%s\"" % [at, essence_id])
		if entry.xp > 0 and entry.essence_ids.is_empty():
			errors.append("%s: has %d infusion XP but no infusion" % [at, entry.xp])


## Output kinds are "damage", "shield", "heal", and damage-over-time statuses.
func is_output_kind(kind: String) -> bool:
	if EssenceDef.DIRECT_KINDS.has(kind):
		return true
	return statuses.has(kind) and statuses[kind].kind == StatusDef.Kind.DAMAGE_OVER_TIME


func _check_auras(auras: Array[AuraDef], where: String) -> void:
	for i: int in auras.size():
		_check_filter(auras[i].filter, "%s.auras[%d]" % [where, i])


## Checks the ids a filter names (item, status, essence).
func _check_filter(filter: AuraFilter, where: String) -> void:
	if filter == null:
		return
	if not filter.item_id.is_empty() and not items.has(filter.item_id):
		errors.append("%s.filter: unknown item \"%s\"" % [where, filter.item_id])
	if not filter.applies.is_empty() and not statuses.has(filter.applies):
		errors.append("%s.filter: unknown status \"%s\"" % [where, filter.applies])
	if not filter.essence.is_empty() and not essences.has(filter.essence):
		errors.append("%s.filter: unknown essence \"%s\"" % [where, filter.essence])


func _check_effects(effects: Array[EffectDef], where: String) -> void:
	for i: int in effects.size():
		var effect: EffectDef = effects[i]
		if effect.type == EffectDef.Type.APPLY_STATUS and not effect.status_id.is_empty() and not statuses.has(effect.status_id):
			errors.append("%s.effects[%d]: unknown status \"%s\"" % [where, i, effect.status_id])
