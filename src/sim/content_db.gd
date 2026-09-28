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
##
## The rebuild (docs/plans/rebuild-build-order.md) left only tuning and
## statuses after the gut; each later phase adds its files here (units and
## encounters in phase 2, paths in phase 4, relics, bonds, and the run's data
## in phase 5).

const TUNING_FILE: String = "tuning.json"
const STATUSES_FILE: String = "statuses.json"
const FILES: Array[String] = [TUNING_FILE, STATUSES_FILE]

var errors: Array[String] = []
var tuning: TuningDef
var statuses: Dictionary[String, StatusDef] = {}
var status_ids: Array[String] = []
## The status the Engage trait sets (the one of kind engaged).
var engaged_status: StatusDef = null

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
	var tuning_data: Variant = db._parse(texts, TUNING_FILE)
	if tuning_data != null:
		var reader: DataReader = DataReader.from_value(tuning_data, TUNING_FILE, db.errors)
		if reader != null:
			db.tuning = TuningDef.read(reader)
	for reader: DataReader in db._entries(db._parse(texts, STATUSES_FILE), STATUSES_FILE):
		var status: StatusDef = StatusDef.read(reader)
		if db._claim_id(status.id, reader, db.status_ids):
			db.statuses[status.id] = status
	var engaged: Array[String] = db.status_ids.filter(func(id: String) -> bool: return db.statuses[id].kind == StatusDef.Kind.ENGAGED)
	if engaged.size() == 1:
		db.engaged_status = db.statuses[engaged[0]]
	elif texts.has(STATUSES_FILE):
		db.errors.append("%s: needs exactly one status of kind \"engaged\" (the Engage trait sets it), found %d" % [STATUSES_FILE, engaged.size()])
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


## Wraps each element of a top-level list. Paths look like
## `statuses.json[1] (poison)` so errors name the entry.
func _entries(data: Variant, file_name: String) -> Array[DataReader]:
	var readers: Array[DataReader] = []
	if data == null:
		return readers
	if typeof(data) != TYPE_ARRAY:
		errors.append("%s: expected a list of entries" % file_name)
		return readers
	var entries: Array = data
	for i: int in entries.size():
		var label: String = "%s[%d]" % [file_name, i]
		if typeof(entries[i]) == TYPE_DICTIONARY and typeof(entries[i].get("id")) == TYPE_STRING:
			label += " (%s)" % entries[i]["id"]
		var reader: DataReader = DataReader.from_value(entries[i], label, errors)
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
