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
## statuses after the gut; phase 2 adds heroes, enemies, and encounters
## (docs/plans/rebuild-phase2-heroes-enemies.md, section 2), and later phases
## add theirs (paths in phase 4; relics, bonds, and the run's data in phase 5).
## Heroes and enemies share one space of ids, since a fight names its units by
## them. Phase 3b adds tactics (docs/plans/rebuild-phase3b-tactics.md), each
## naming the heroes who can take it. Phase 4 adds paths
## (docs/plans/rebuild-phase4-paths.md): up to three per hero, each with its
## vowed and transformed kits built from the hero's base kit.

const TUNING_FILE: String = "tuning.json"
const STATUSES_FILE: String = "statuses.json"
const HEROES_FILE: String = "heroes.json"
const ENEMIES_FILE: String = "enemies.json"
const ENCOUNTERS_FILE: String = "encounters.json"
const TACTICS_FILE: String = "tactics.json"
const PATHS_FILE: String = "paths.json"
const ENEMY_UPGRADES_FILE: String = "enemy_upgrades.json"
const FILES: Array[String] = [TUNING_FILE, STATUSES_FILE, HEROES_FILE, ENEMIES_FILE, ENCOUNTERS_FILE, TACTICS_FILE, PATHS_FILE, ENEMY_UPGRADES_FILE]
## How many paths a hero has (rebuild-heroes.md).
const PATHS_PER_HERO: int = 3

var errors: Array[String] = []
var tuning: TuningDef
var statuses: Dictionary[String, StatusDef] = {}
var status_ids: Array[String] = []
## The status the Engage trait sets (the one of kind engaged).
var engaged_status: StatusDef = null
## The status a push stopped early stuns with (the first of kind stun).
var stun_status: StatusDef = null
var heroes: Dictionary[String, HeroDef] = {}
var hero_ids: Array[String] = []
var enemies: Dictionary[String, EnemyDef] = {}
var enemy_ids: Array[String] = []
var encounters: Dictionary[String, EncounterDef] = {}
var encounter_ids: Array[String] = []
var tactics: Dictionary[String, TacticDef] = {}
var tactic_ids: Array[String] = []
var paths: Dictionary[String, PathDef] = {}
var path_ids: Array[String] = []
## Every path's apexes (phase 8 part 2), by id; their ids share one space
## with the paths' (a hero's deeds are keyed by both).
var apexes: Dictionary[String, ApexDef] = {}
var apex_ids: Array[String] = []
## Every enemy's specializations (phase 8 part 3), by id: one space of ids
## across enemies.
var specializations: Dictionary[String, SpecializationDef] = {}
var specialization_ids: Array[String] = []
## Enemy upgrades (phase 8 part 3, rebuild-phase8-act3.md section 2), by id:
## any enemy can carry any of them, so they're apart from the enemies.
var enemy_upgrades: Dictionary[String, EnemyUpgradeDef] = {}
var enemy_upgrade_ids: Array[String] = []

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
	for id: String in db.status_ids:
		if db.statuses[id].kind == StatusDef.Kind.STUN:
			db.stun_status = db.statuses[id]
			break
	if db.stun_status == null and texts.has(STATUSES_FILE):
		db.errors.append("%s: needs a status of kind \"stun\" (a push stopped early stuns with the first)" % STATUSES_FILE)
	for reader: DataReader in db._entries(db._parse(texts, HEROES_FILE), HEROES_FILE):
		var hero: HeroDef = HeroDef.read(reader)
		if db._claim_id(hero.id, reader, db.hero_ids):
			db.heroes[hero.id] = hero
	for reader: DataReader in db._entries(db._parse(texts, ENEMIES_FILE), ENEMIES_FILE):
		var enemy: EnemyDef = EnemyDef.read(reader)
		if db.heroes.has(enemy.id):
			reader.error("\"%s\" is already a hero's id" % enemy.id)
		elif db._claim_id(enemy.id, reader, db.enemy_ids):
			db.enemies[enemy.id] = enemy
			for spec: SpecializationDef in enemy.specializations:
				if db._claim_id(spec.id, reader, db.specialization_ids):
					db.specializations[spec.id] = spec
	for reader: DataReader in db._entries(db._parse(texts, ENCOUNTERS_FILE), ENCOUNTERS_FILE):
		var encounter: EncounterDef = EncounterDef.read(reader)
		if db._claim_id(encounter.id, reader, db.encounter_ids):
			db.encounters[encounter.id] = encounter
	for reader: DataReader in db._entries(db._parse(texts, TACTICS_FILE), TACTICS_FILE):
		var tactic: TacticDef = TacticDef.read(reader)
		if db._claim_id(tactic.id, reader, db.tactic_ids):
			db.tactics[tactic.id] = tactic
	for reader: DataReader in db._entries(db._parse(texts, PATHS_FILE), PATHS_FILE):
		var path: PathDef = PathDef.read(reader)
		if db._claim_id(path.id, reader, db.path_ids):
			db.paths[path.id] = path
		if path.apexes.size() > PathDef.APEXES_PER_PATH:
			reader.error("a path has at most %d apexes" % PathDef.APEXES_PER_PATH)
		for apex: ApexDef in path.apexes:
			if db._claim_id(apex.id, reader, db.apex_ids):
				db.apexes[apex.id] = apex
	for reader: DataReader in db._entries(db._parse(texts, ENEMY_UPGRADES_FILE), ENEMY_UPGRADES_FILE):
		var upgrade: EnemyUpgradeDef = EnemyUpgradeDef.read(reader)
		if db._claim_id(upgrade.id, reader, db.enemy_upgrade_ids):
			db.enemy_upgrades[upgrade.id] = upgrade
	db._check_links()
	return db


## Checks what entries name across files: the statuses and summons in every
## kit, each encounter's enemies, hexes, rocks, water, and act, and each tactic's
## heroes.
func _check_links() -> void:
	var grid: HexGrid = tuning.make_grid() if tuning != null else HexGrid.make()
	for id: String in hero_ids:
		_check_kit(heroes[id].kit, "%s (%s)" % [HEROES_FILE, id], grid)
	for id: String in enemy_ids:
		_check_kit(enemies[id].kit, "%s (%s)" % [ENEMIES_FILE, id], grid)
	for id: String in specialization_ids:
		var spec: SpecializationDef = specializations[id]
		var spec_where: String = "%s (%s: %s)" % [ENEMIES_FILE, spec.enemy, id]
		if spec.mod == null or not spec.mod.changes_anything():
			errors.append("%s: a specialization changes something" % spec_where)
			continue
		var problems: Array[String] = []
		var specialized: UnitDef = spec.apply(enemies[spec.enemy].kit, problems)
		for problem: String in problems:
			errors.append("%s: %s" % [spec_where, problem])
		_check_kit(specialized, spec_where, grid)
	for id: String in enemy_upgrade_ids:
		_check_upgrade(enemy_upgrades[id], "%s (%s)" % [ENEMY_UPGRADES_FILE, id], grid)
	for id: String in encounter_ids:
		var encounter: EncounterDef = encounters[id]
		var where: String = "%s (%s)" % [ENCOUNTERS_FILE, id]
		if tuning != null and tuning.collapse_for_act(encounter.act) == null:
			errors.append("%s: tuning has no Rift Collapse numbers for act %d" % [where, encounter.act])
		var taken: Dictionary[int, String] = {}
		for rock: Vector2i in encounter.rocks:
			if not grid.has(rock.x, rock.y):
				errors.append("%s: a rock at (%d, %d) is off the board" % [where, rock.x, rock.y])
			else:
				taken[grid.index(rock.x, rock.y)] = "a rock"
		for i: int in encounter.water.size():
			var wet: Vector2i = encounter.water[i]
			if not grid.has(wet.x, wet.y):
				errors.append("%s: water at (%d, %d) is off the board" % [where, wet.x, wet.y])
			elif encounter.rocks.has(wet):
				errors.append("%s: water at (%d, %d) is on a rock" % [where, wet.x, wet.y])
			elif encounter.water.find(wet) < i:
				errors.append("%s: water at (%d, %d) is listed twice" % [where, wet.x, wet.y])
		var enemy_hexes: Array[Vector2i] = []
		for placed: EncounterDef.Placed in encounter.enemies:
			enemy_hexes.append(placed.hex)
		errors.append_array(Islands.problems(grid, encounter.void_hexes, encounter.rocks, encounter.water, enemy_hexes, "%s: " % where))
		for placed: EncounterDef.Placed in encounter.enemies:
			var at: String = "%s at (%d, %d)" % [placed.enemy, placed.hex.x, placed.hex.y]
			if not enemies.has(placed.enemy):
				errors.append("%s: unknown enemy \"%s\"" % [where, placed.enemy])
			if not grid.has(placed.hex.x, placed.hex.y):
				errors.append("%s: %s is off the board" % [where, at])
				continue
			if grid.zone(placed.hex.y) != HexGrid.Zone.ENEMIES:
				errors.append("%s: %s is outside the enemies' zone" % [where, at])
			var hex: int = grid.index(placed.hex.x, placed.hex.y)
			if taken.has(hex):
				errors.append("%s: %s shares its hex with %s" % [where, at, taken[hex]])
			else:
				taken[hex] = placed.enemy
	for id: String in tactic_ids:
		_check_tactic(tactics[id], "%s (%s)" % [TACTICS_FILE, id])
	for id: String in path_ids:
		_check_path(paths[id], "%s (%s)" % [PATHS_FILE, id], grid)


## An upgrade must change something, and leave every enemy kit it changes
## sound.
func _check_upgrade(upgrade: EnemyUpgradeDef, where: String, grid: HexGrid) -> void:
	if upgrade.mod == null or not upgrade.mod.changes_anything():
		errors.append("%s: an upgrade changes something" % where)
		return
	for enemy_id: String in enemy_ids:
		var kit: UnitDef = enemies[enemy_id].kit
		if not upgrade.changes(kit):
			continue
		var problems: Array[String] = []
		var upgraded: UnitDef = upgrade.apply(kit, problems)
		for problem: String in problems:
			errors.append("%s on %s: %s" % [where, enemy_id, problem])
		_check_kit(upgraded, "%s on %s" % [where, enemy_id], grid)


## A path's hero must exist and have room for it (up to three, in the file's
## order); its vowed and transformed kits are built here and checked like
## any kit; its deed's abilities must be in one of the hero's kits.
func _check_path(path: PathDef, where: String, grid: HexGrid) -> void:
	if not heroes.has(path.hero):
		errors.append("%s: unknown hero \"%s\"" % [where, path.hero])
		return
	var hero: HeroDef = heroes[path.hero]
	if hero.paths.size() >= PATHS_PER_HERO:
		errors.append("%s: %s already has %d paths" % [where, path.hero, PATHS_PER_HERO])
		return
	hero.paths.append(path)
	if hero.kit == null:
		return
	var problems: Array[String] = []
	path.vowed_kit = path.vowed_patch.apply(hero.kit, problems)
	for problem: String in problems:
		errors.append("%s: vowed: %s" % [where, problem])
	problems.clear()
	path.transformed_kit = path.transformed_patch.apply(hero.kit, problems)
	for problem: String in problems:
		errors.append("%s: transformed: %s" % [where, problem])
	_check_kit(path.vowed_kit, "%s: vowed" % where, grid)
	_check_kit(path.transformed_kit, "%s: transformed" % where, grid)
	var known: Array[String] = []
	for kit: UnitDef in [hero.kit, path.vowed_kit, path.transformed_kit]:
		known.append_array(kit.ability_ids())
	for ability_id: String in path.deed.from_ability:
		if not known.has(ability_id):
			errors.append("%s: the deed counts \"%s\", which isn't in %s's kits on this path" % [where, ability_id, path.hero])
	for apex: ApexDef in path.apexes:
		_check_apex(apex, path, "%s: apex %s" % [where, apex.id], grid)


## An apex's kits are its patches on the path's transformed kit, checked
## like any kit; its deed's abilities must be in one of them (or the
## transformed kit).
func _check_apex(apex: ApexDef, path: PathDef, where: String, grid: HexGrid) -> void:
	if paths.has(apex.id):
		errors.append("%s: \"%s\" is already a path's id" % [where, apex.id])
	var problems: Array[String] = []
	apex.vowed_kit = apex.vowed_patch.apply(path.transformed_kit, problems)
	for problem: String in problems:
		errors.append("%s: vowed: %s" % [where, problem])
	problems.clear()
	apex.apex_kit = apex.apex_patch.apply(path.transformed_kit, problems)
	for problem: String in problems:
		errors.append("%s: apex: %s" % [where, problem])
	_check_kit(apex.vowed_kit, "%s: vowed" % where, grid)
	_check_kit(apex.apex_kit, "%s: apex" % where, grid)
	var known: Array[String] = []
	for kit: UnitDef in [path.transformed_kit, apex.vowed_kit, apex.apex_kit]:
		known.append_array(kit.ability_ids())
	for ability_id: String in apex.deed.from_ability:
		if not known.has(ability_id):
			errors.append("%s: the deed counts \"%s\", which isn't in its kits" % [where, ability_id])


## A tactic's heroes (if it names any) must exist; a signature_threshold
## tactic's must have a mana signature that heals (phase 4, Decision 4: any
## healing signature); a first_hit's status must exist, at every rank.
func _check_tactic(tactic: TacticDef, where: String) -> void:
	for rank: int in range(1, 4):
		var ranked: TacticDef = tactic.at_rank(rank)
		if not ranked.first_hit_status.is_empty() and not statuses.has(ranked.first_hit_status):
			errors.append("%s: rank %d's first hit puts on an unknown status \"%s\"" % [where, rank, ranked.first_hit_status])
	for i: int in tactic.heroes.size():
		var hero_id: String = tactic.heroes[i]
		if tactic.heroes.find(hero_id) < i:
			errors.append("%s: lists \"%s\" twice" % [where, hero_id])
			continue
		if not heroes.has(hero_id):
			errors.append("%s: unknown hero \"%s\"" % [where, hero_id])
			continue
		if tactic.kind != TacticDef.Kind.SIGNATURE_THRESHOLD:
			continue
		var signature: AbilityDef = heroes[hero_id].kit.signature if heroes[hero_id].kit != null else null
		if not Tactics.can_wait(signature):
			errors.append("%s: %s's signature doesn't heal on mana, so it can't wait for a hurt ally" % [where, hero_id])


## A kit's statuses must exist (and not be Engaged, which only the trait
## sets), and its summons must be enemies, onto hexes on the board.
func _check_kit(kit: UnitDef, where: String, grid: HexGrid) -> void:
	if kit == null:
		return
	for status_id: String in kit.status_ids():
		if not statuses.has(status_id):
			errors.append("%s: unknown status \"%s\"" % [where, status_id])
		elif statuses[status_id].kind == StatusDef.Kind.ENGAGED:
			errors.append("%s: names \"%s\", which only the Engage trait sets" % [where, status_id])
	for status_id: String in kit.condition_status_ids():
		if not statuses.has(status_id):
			errors.append("%s: unknown status \"%s\"" % [where, status_id])
	for kit_id: String in kit.rise_as_ids():
		if not enemies.has(kit_id):
			errors.append("%s: rises as \"%s\", which isn't an enemy" % [where, kit_id])
	for effect: EffectDef in kit.all_effects():
		if effect.type != EffectDef.Type.SUMMON:
			continue
		if not enemies.has(effect.summon_kit):
			errors.append("%s: summons \"%s\", which isn't an enemy" % [where, effect.summon_kit])
		for hex: Vector2i in effect.summon_hexes:
			if not grid.has(hex.x, hex.y):
				errors.append("%s: summons onto (%d, %d), off the board" % [where, hex.x, hex.y])


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
