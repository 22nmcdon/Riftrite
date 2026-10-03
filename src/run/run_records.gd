class_name RunRecords
extends RefCounted
## The player's records (docs/plans/rebuild-phase8-endless.md, section 1):
## the deepest endless floor reached, with the run's seed and vows, in
## user://records.json beside the run's save, one for each act an endless
## follows (phase 8 part 3, Decision 15: the testing option after Act 1 and
## real endless after Act 3 never compare). The file is {"<act>": record};
## an older file, one record, is Act 1's. A record is never a stat
## (CLAUDE.md, rule 5); until the Codex exists, it's this file.

const PATH: String = "user://records.json"


## The best endless run after act `act` so far: {"floor": int, "seed": int,
## "vows": {hero id: path id}}, or {} if there's none (or the file won't
## parse).
static func best(path: String = PATH, act: int = 1) -> Dictionary:
	var record: Variant = _all(path).get(str(act), {})
	return record if typeof(record) == TYPE_DICTIONARY and (record as Dictionary).has("floor") else {}


## Notes an endless run that reached `floor_reached` (after its act); true
## if it's a new best (and writes it).
static func note(state: RunState, floor_reached: int, path: String = PATH) -> bool:
	if floor_reached <= int(best(path, state.act).get("floor", 0)):
		return false
	var vows: Dictionary = {}
	for hero: RunState.Hero in state.heroes:
		vows[hero.id] = hero.path
	var records: Dictionary = _all(path)
	records[str(state.act)] = {"floor": floor_reached, "seed": state.seed_value, "vows": vows}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(records, "\t"))
	return true


## Every record in the file, by act ({} if there's none or it won't parse).
static func _all(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	if (data as Dictionary).has("floor"):
		return {"1": data}
	return data
