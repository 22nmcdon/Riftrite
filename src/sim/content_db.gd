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
const FILES: Array[String] = [TUNING_FILE, STATUSES_FILE, ESSENCES_FILE]

var errors: Array[String] = []
var tuning: TuningDef
var statuses: Dictionary[String, StatusDef] = {}
var status_ids: Array[String] = []
var essences: Dictionary[String, EssenceDef] = {}
var essence_ids: Array[String] = []

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


## Output kinds are "damage", "shield", "heal", and damage-over-time statuses.
func is_output_kind(kind: String) -> bool:
	if EssenceDef.DIRECT_KINDS.has(kind):
		return true
	return statuses.has(kind) and statuses[kind].kind == StatusDef.Kind.DAMAGE_OVER_TIME


func _check_effects(effects: Array[EffectDef], where: String) -> void:
	for i: int in effects.size():
		var effect: EffectDef = effects[i]
		if effect.type == EffectDef.Type.APPLY_STATUS and not effect.status_id.is_empty() and not statuses.has(effect.status_id):
			errors.append("%s.effects[%d]: unknown status \"%s\"" % [where, i, effect.status_id])
