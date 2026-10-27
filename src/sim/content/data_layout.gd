class_name DataLayout
extends RefCounted
## Where each kind of content lives under data/ (docs/plans/phases/cleanup-and-layout.md,
## section 3), and the reading both loaders share (ContentDb, RunContent).
## A kind is named as its old single file was ("paths.json"), and the loaders
## and the tests that build content from text still speak those names; here
## each name maps to the files that hold its entries, joined in a set order:
##   core/            tuning.json, tactics.json, statuses.json (the shared ones)
##   heroes/          roster.json (the heroes, in the order they act), then a
##                    folder per hero: hero.json (its base kit), paths.json,
##                    upgrades.json, statuses.json (those only its content sets)
##   acts/            enemy_upgrades.json, rift_learns.json, and a folder per
##                    act: act.json, enemies.json (the enemies it brings in),
##                    encounters.json
##   run/             bonds.json, camps.json, events.json, relics/<tier>.json,
##                    items/<kind>s.json
## Each joined entry carries "_from" (its file and place in it) until
## `entries` reads it, so an error names the file the entry came from.

const ROSTER: String = "heroes/roster.json"
const ITEM_KINDS: Array[String] = ["charms", "tactics", "sigils", "gambits"]
## The key a joined entry carries its file in.
const FROM: String = "_from"


## The files, relative to `dir`, that hold `kind`'s entries, in load order
## ("act1.json" and so on name one act's shape).
static func files(dir: String, kind: String) -> Array[String]:
	var found: Array[String] = []
	match kind:
		"tuning.json", "tactics.json":
			found.append("core/" + kind)
		"statuses.json":
			found.append("core/statuses.json")
			found.append_array(_per_hero(dir, kind))
		"heroes.json":
			found.append_array(_per_hero(dir, "hero.json"))
		"paths.json", "upgrades.json":
			found.append_array(_per_hero(dir, kind))
		"enemies.json", "encounters.json":
			for act: int in acts(dir):
				found.append("acts/act%d/%s" % [act, kind])
		"enemy_upgrades.json", "rift_learns.json":
			found.append("acts/" + kind)
		"relics.json":
			for tier: String in RelicDef.TIER_NAMES:
				found.append("run/relics/%s.json" % tier)
		"items.json":
			for item_kind: String in ITEM_KINDS:
				found.append("run/items/%s.json" % item_kind)
		"bonds.json", "camps.json", "events.json":
			found.append("run/" + kind)
		_:
			var act: RegExMatch = RegEx.create_from_string("^act(\\d+)\\.json$").search(kind)
			if act != null:
				found.append("acts/act%s/act.json" % act.get_string(1))
	var present: Array[String] = []
	for file: String in found:
		if FileAccess.file_exists(dir.path_join(file)):
			present.append(file)
	return present


## The heroes, in the order they act (roster.json).
static func roster(dir: String) -> Array[String]:
	var heroes: Array[String] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(ROSTER))) if FileAccess.file_exists(dir.path_join(ROSTER)) else null
	if parsed is Array:
		for hero: Variant in parsed:
			if hero is String:
				heroes.append(hero)
	return heroes


## The acts with a folder, from 1 up to the first missing.
static func acts(dir: String) -> Array[int]:
	var numbers: Array[int] = []
	while DirAccess.dir_exists_absolute(dir.path_join("acts/act%d" % (numbers.size() + 1))):
		numbers.append(numbers.size() + 1)
	return numbers


## Every file under `dir` the loaders read, for the test that no data file is
## left out.
static func all_files(dir: String) -> Array[String]:
	var every: Array[String] = [ROSTER]
	for kind: String in ["tuning.json", "tactics.json", "statuses.json", "heroes.json", "paths.json", "upgrades.json", "enemies.json",
			"encounters.json", "enemy_upgrades.json", "rift_learns.json", "relics.json", "items.json", "bonds.json", "camps.json", "events.json"]:
		every.append_array(files(dir, kind))
	for act: int in acts(dir):
		every.append_array(files(dir, "act%d.json" % act))
	return every


## `kind`'s text: its one file as it is, or its files' entries joined into one
## list, each marked with the file it came from. "" if no file holds it;
## a file that isn't valid JSON is reported in `errors` and left out.
static func read(dir: String, kind: String, errors: Array[String] = []) -> String:
	var found: Array[String] = files(dir, kind)
	if found.is_empty():
		return ""
	if found.size() == 1 and kind != "heroes.json":
		return FileAccess.get_file_as_string(dir.path_join(found[0]))
	var joined: Array = []
	for file: String in found:
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(dir.path_join(file))) != OK:
			errors.append("%s: invalid JSON on line %d: %s" % [file, json.get_error_line(), json.get_error_message()])
			continue
		var entries: Array = json.data if json.data is Array else [json.data]
		for i: int in entries.size():
			if entries[i] is Dictionary:
				entries[i][FROM] = "%s[%d]" % [file, i] if json.data is Array else file
			joined.append(entries[i])
	return JSON.stringify(joined)


## Parses `kind`'s text from `texts` (null, after reporting why, if it's
## missing and `required`, or isn't valid JSON).
static func parse(texts: Dictionary[String, String], kind: String, errors: Array[String], required: bool = true) -> Variant:
	if not texts.has(kind):
		if required:
			errors.append("%s: missing" % kind)
		return null
	var json := JSON.new()
	if json.parse(texts[kind]) != OK:
		errors.append("%s: invalid JSON on line %d: %s" % [kind, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## Wraps each element of a top-level list. Paths look like
## `statuses.json[1] (poison)`, or the entry's own file once joined
## (`heroes/maren/statuses.json[0] (volley_mark)`), so errors name the entry.
static func entries(data: Variant, kind: String, errors: Array[String]) -> Array[DataReader]:
	var readers: Array[DataReader] = []
	if data == null:
		return readers
	if typeof(data) != TYPE_ARRAY:
		errors.append("%s: expected a list of entries" % kind)
		return readers
	var list: Array = data
	for i: int in list.size():
		var label: String = "%s[%d]" % [kind, i]
		if typeof(list[i]) == TYPE_DICTIONARY:
			var entry: Dictionary = list[i]
			if entry.has(FROM):
				label = str(entry[FROM])
				entry.erase(FROM)
			if typeof(entry.get("id")) == TYPE_STRING:
				label += " (%s)" % entry["id"]
		var reader: DataReader = DataReader.from_value(list[i], label, errors)
		if reader != null:
			readers.append(reader)
	return readers


static func _per_hero(dir: String, file: String) -> Array[String]:
	var found: Array[String] = []
	for hero: String in roster(dir):
		found.append("heroes/%s/%s" % [hero, file])
	return found
