class_name RunContent
extends RefCounted
## The run's data, apart from the sim's (docs/plans/rebuild-phase5-run.md):
## the act, and (as later steps add them) upgrades, items, relics, duo bonds,
## and camps. It sits over the sim's ContentDb, which it cross-checks
## against: every encounter a day can draw, every path and hero named.

const ACT_FILE: String = "act1.json"
const FILES: Array[String] = [ACT_FILE]

var content: ContentDb
var act: ActDef = null
var errors: Array[String] = []


## Loads the run's files from `dir`, over `content_db` (already loaded).
static func load_dir(dir: String, content_db: ContentDb) -> RunContent:
	var texts: Dictionary[String, String] = {}
	var missing: Array[String] = []
	for file_name: String in FILES:
		var file_path: String = dir.path_join(file_name)
		if FileAccess.file_exists(file_path):
			texts[file_name] = FileAccess.get_file_as_string(file_path)
		else:
			missing.append("%s: file not found" % file_path)
	var run: RunContent = load_texts(texts, content_db)
	missing.append_array(run.errors)
	run.errors = missing
	return run


static func load_texts(texts: Dictionary[String, String], content_db: ContentDb) -> RunContent:
	var run := RunContent.new()
	run.content = content_db
	var act_data: Variant = run._parse(texts, ACT_FILE)
	if act_data != null:
		var reader: DataReader = DataReader.from_value(act_data, ACT_FILE, run.errors)
		if reader != null:
			run.act = ActDef.read(reader)
	run._check()
	return run


func is_valid() -> bool:
	return errors.is_empty() and content != null and content.is_valid()


## The encounters of `tier` in this act that day `day` can draw.
func encounters_for(tier: String, day: int) -> Array[String]:
	var found: Array[String] = []
	for id: String in content.encounter_ids:
		var encounter: EncounterDef = content.encounters[id]
		if encounter.act == act.act and encounter.tier == tier and encounter.days.has(day):
			found.append(id)
	return found


## Every easier and harder encounter of this act, whatever its days.
func normal_encounters() -> Array[String]:
	var found: Array[String] = []
	for id: String in content.encounter_ids:
		var encounter: EncounterDef = content.encounters[id]
		if encounter.act == act.act and encounter.tier in ["easier", "harder"]:
			found.append(id)
	return found


func _check() -> void:
	if act == null or content == null:
		return
	for day: int in range(1, act.days.size() + 1):
		if act.days[day - 1] == "normal" and encounters_for("easier", day).size() + encounters_for("harder", day).size() < 2:
			errors.append("%s: day %d needs at least two fights to offer" % [ACT_FILE, day])


func _parse(texts: Dictionary[String, String], file_name: String) -> Variant:
	if not texts.has(file_name):
		return null
	var json := JSON.new()
	if json.parse(texts[file_name]) != OK:
		errors.append("%s: invalid JSON at line %d: %s" % [file_name, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
