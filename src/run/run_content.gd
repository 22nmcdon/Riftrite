class_name RunContent
extends RefCounted
## The run layer's data: the economy, the acts, and the events (data/
## economy.json, acts.json, events.json), loaded and checked against the
## sim's content. Like ContentDb, loading reports every problem at once.

const ECONOMY_FILE: String = "economy.json"
const ACTS_FILE: String = "acts.json"
const EVENTS_FILE: String = "events.json"
const FILES: Array[String] = [ECONOMY_FILE, ACTS_FILE, EVENTS_FILE]

var errors: Array[String] = []
var economy: EconomyDef
## In file order.
var acts: Array[ActDef] = []
var events: Dictionary[String, EventDef] = {}
var event_ids: Array[String] = []


static func load_dir(dir: String, content: ContentDb) -> RunContent:
	var texts: Dictionary[String, String] = {}
	for file_name: String in FILES:
		var path: String = dir.path_join(file_name)
		if FileAccess.file_exists(path):
			texts[file_name] = FileAccess.get_file_as_string(path)
	return load_texts(texts, content)


static func load_texts(texts: Dictionary[String, String], content: ContentDb) -> RunContent:
	var run := RunContent.new()
	var economy_reader: DataReader = run._object(texts, ECONOMY_FILE)
	if economy_reader != null:
		run.economy = EconomyDef.read(economy_reader)
	for reader: DataReader in run._list(texts, ACTS_FILE):
		run.acts.append(ActDef.read(reader))
	for reader: DataReader in run._list(texts, EVENTS_FILE):
		var event: EventDef = EventDef.read(reader)
		if run.events.has(event.id):
			reader.error("duplicate id \"%s\"" % event.id)
		elif not event.id.is_empty():
			run.events[event.id] = event
			run.event_ids.append(event.id)
	run._check(content)
	return run


func is_valid() -> bool:
	return errors.is_empty()


func act(number: int) -> ActDef:
	for candidate: ActDef in acts:
		if candidate.act == number:
			return candidate
	return null


func _check(content: ContentDb) -> void:
	if acts.is_empty():
		errors.append("%s: needs at least one act" % ACTS_FILE)
	for def: ActDef in acts:
		var where: String = "%s (act %d)" % [ACTS_FILE, def.act]
		for pair: Array in def.all_encounters():
			for encounter_id: String in pair[0]:
				var encounter: EncounterDef = content.encounters.get(encounter_id, null)
				if encounter == null:
					errors.append("%s: unknown encounter \"%s\"" % [where, encounter_id])
				elif encounter.kind != pair[1]:
					errors.append("%s: \"%s\" is a %s encounter, not %s" % [where, encounter_id, encounter.kind, pair[1]])
				elif encounter.act != def.act:
					errors.append("%s: \"%s\" belongs to act %d" % [where, encounter_id, encounter.act])
	if event_ids.is_empty():
		errors.append("%s: needs at least one event" % EVENTS_FILE)


func _parse(texts: Dictionary[String, String], file_name: String) -> Variant:
	if not texts.has(file_name):
		errors.append("%s: file not found" % file_name)
		return null
	var json := JSON.new()
	if json.parse(texts[file_name]) != OK:
		errors.append("%s: invalid JSON on line %d: %s" % [file_name, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func _object(texts: Dictionary[String, String], file_name: String) -> DataReader:
	var data: Variant = _parse(texts, file_name)
	return DataReader.from_value(data, file_name, errors) if data != null else null


func _list(texts: Dictionary[String, String], file_name: String) -> Array[DataReader]:
	var readers: Array[DataReader] = []
	var data: Variant = _parse(texts, file_name)
	if data == null:
		return readers
	if typeof(data) != TYPE_ARRAY:
		errors.append("%s: expected a list of entries" % file_name)
		return readers
	var entries: Array = data
	for i: int in entries.size():
		var reader: DataReader = DataReader.from_value(entries[i], "%s[%d]" % [file_name, i], errors)
		if reader != null:
			readers.append(reader)
	return readers
