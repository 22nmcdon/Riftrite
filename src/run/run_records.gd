class_name RunRecords
extends RefCounted
## The player's records (docs/plans/rebuild-phase8-endless.md, section 1):
## the deepest endless floor reached, with the run's seed and vows, in
## user://records.json beside the run's save. A record is never a stat
## (CLAUDE.md, rule 5); until the Codex exists, it's this file.

const PATH: String = "user://records.json"


## The best endless run so far: {"floor": int, "seed": int, "vows": {hero
## id: path id}}, or {} if there's none (or the file won't parse).
static func best(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("floor"):
		return {}
	return data


## Notes an endless run that reached `floor_reached`; true if it's a new
## best (and writes it).
static func note(state: RunState, floor_reached: int, path: String = PATH) -> bool:
	if floor_reached <= int(best(path).get("floor", 0)):
		return false
	var vows: Dictionary = {}
	for hero: RunState.Hero in state.heroes:
		vows[hero.id] = hero.path
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"floor": floor_reached, "seed": state.seed_value, "vows": vows}, "\t"))
	return true
