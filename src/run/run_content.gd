class_name RunContent
extends RefCounted
## The run's data, apart from the sim's (docs/plans/rebuild-phase5-run.md):
## the act, the upgrades, and (as later steps add them) items, relics, duo
## bonds, and camps. It sits over the sim's ContentDb, which it cross-checks
## against: every encounter a day can draw, every path and hero named.

const ACT_FILE: String = "act1.json"
const UPGRADES_FILE: String = "upgrades.json"
const FILES: Array[String] = [ACT_FILE, UPGRADES_FILE]

var content: ContentDb
var act: ActDef = null
var upgrades: Dictionary[String, UpgradeDef] = {}
## In the file's order (offers draw in this order).
var upgrade_ids: Array[String] = []
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
	run._read_upgrades(run._parse(texts, UPGRADES_FILE))
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


## The upgrades `hero` can be offered now: its hero layer, its vowed path's
## vow picks, and once transformed the rest of that path's; none it has taken.
func upgrades_for(hero: RunState.Hero) -> Array[String]:
	var found: Array[String] = []
	for id: String in upgrade_ids:
		var upgrade: UpgradeDef = upgrades[id]
		if upgrade.hero != hero.id or hero.upgrades.has(id):
			continue
		if upgrade.layer == UpgradeDef.Layer.PATH and (upgrade.path != hero.path or not (upgrade.vow or hero.transformed)):
			continue
		found.append(id)
	return found


## The kit mods `hero`'s upgrades give it now, in the order taken (a path's
## upgrade only while the hero is on that path).
func upgrade_mods(hero: RunState.Hero) -> Array[KitMod]:
	var mods: Array[KitMod] = []
	for id: String in hero.upgrades:
		var upgrade: UpgradeDef = upgrades.get(id)
		if upgrade == null or (upgrade.layer == UpgradeDef.Layer.PATH and upgrade.path != hero.path):
			continue
		mods.append(upgrade.mod_for(hero.transformed))
	return mods


func _read_upgrades(data: Variant) -> void:
	if data == null:
		return
	if typeof(data) != TYPE_ARRAY:
		errors.append("%s: expected a list of entries" % UPGRADES_FILE)
		return
	var entries: Array = data
	for i: int in entries.size():
		var label: String = "%s[%d]" % [UPGRADES_FILE, i]
		if typeof(entries[i]) == TYPE_DICTIONARY and typeof(entries[i].get("id")) == TYPE_STRING:
			label += " (%s)" % entries[i]["id"]
		var reader: DataReader = DataReader.from_value(entries[i], label, errors)
		if reader == null:
			continue
		var upgrade: UpgradeDef = UpgradeDef.read(reader)
		if upgrade.id.is_empty():
			continue
		if upgrades.has(upgrade.id):
			reader.error("duplicate id \"%s\"" % upgrade.id)
			continue
		upgrades[upgrade.id] = upgrade
		upgrade_ids.append(upgrade.id)


func _check() -> void:
	if content == null:
		return
	if act != null:
		for day: int in range(1, act.days.size() + 1):
			if act.days[day - 1] == "normal" and encounters_for("easier", day).size() + encounters_for("harder", day).size() < 2:
				errors.append("%s: day %d needs at least two fights to offer" % [ACT_FILE, day])
	for path_id: String in content.path_ids:
		if content.paths[path_id].deed.threshold <= 0:
			errors.append("paths.json (%s): a run needs the deed's threshold" % path_id)
	for id: String in upgrade_ids:
		_check_upgrade(upgrades[id], "%s (%s)" % [UPGRADES_FILE, id])
	for hero_id: String in content.hero_ids:
		_check_all_upgrades(hero_id)


## An upgrade's hero or path must exist, and its mod must change, soundly,
## every kit it can meet: a hero's, the vowed and transformed kits of every
## path; a path's, the transformed kit (a vow pick's, the vowed one too).
func _check_upgrade(upgrade: UpgradeDef, where: String) -> void:
	if upgrade.mod == null:
		return
	var meets: Array[Array] = []
	if upgrade.layer == UpgradeDef.Layer.HERO:
		if not content.heroes.has(upgrade.hero):
			errors.append("%s: unknown hero \"%s\"" % [where, upgrade.hero])
			return
		for path: PathDef in content.heroes[upgrade.hero].paths:
			meets.append([path.id + " vowed", path.vowed_kit, upgrade.mod])
			meets.append([path.id + " transformed", path.transformed_kit, upgrade.mod])
	else:
		if not content.paths.has(upgrade.path):
			errors.append("%s: unknown path \"%s\"" % [where, upgrade.path])
			return
		var path: PathDef = content.paths[upgrade.path]
		upgrade.hero = path.hero
		if upgrade.vow:
			meets.append([path.id + " vowed", path.vowed_kit, upgrade.mod_for(false)])
		meets.append([path.id + " transformed", path.transformed_kit, upgrade.mod_for(true)])
	for meet: Array in meets:
		var kit: UnitDef = meet[1]
		var mod: KitMod = meet[2]
		if kit == null:
			continue
		var problems: Array[String] = []
		mod.apply(kit, problems)
		for problem: String in problems:
			errors.append("%s: on %s, %s" % [where, meet[0], problem])
		if not mod.affects(kit):
			errors.append("%s: does nothing on %s" % [where, meet[0]])


## Every upgrade a hero could hold at once, on each path and stage, together.
func _check_all_upgrades(hero_id: String) -> void:
	for path: PathDef in content.heroes[hero_id].paths:
		for transformed: bool in [false, true]:
			var hero := RunState.Hero.new()
			hero.id = hero_id
			hero.path = path.id
			hero.transformed = transformed
			hero.upgrades = upgrades_for(hero)
			var kit: UnitDef = path.transformed_kit if transformed else path.vowed_kit
			if kit == null:
				continue
			var problems: Array[String] = []
			for mod: KitMod in upgrade_mods(hero):
				kit = mod.apply(kit, problems)
			for problem: String in problems:
				errors.append("%s: %s's upgrades together on %s %s: %s" % [UPGRADES_FILE, hero_id, path.id, "transformed" if transformed else "vowed", problem])


func _parse(texts: Dictionary[String, String], file_name: String) -> Variant:
	if not texts.has(file_name):
		return null
	var json := JSON.new()
	if json.parse(texts[file_name]) != OK:
		errors.append("%s: invalid JSON at line %d: %s" % [file_name, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
