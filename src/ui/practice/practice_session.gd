class_name PracticeSession
extends RefCounted
## Practice's state while the game is open (docs/plans/rebuild-phase3-fight-sandbox.md,
## sections 1 and 3, and Decisions 2 and 4). Nothing is saved to disk.
##   - One remembered formation for every encounter: the last one fought
##     with (Brannoc guarding the other two until then), the fight speed
##     last chosen, and whether the log panel was left open.
##   - The fight's seed: 1 to begin with; Rematch moves to the next one.
##     Seeds only change crits (the sim runner's finding).
##   - What's legal comes from the sim: a formation is legal when
##     `Encounters.setup` builds it and `FightSetup.validate` finds nothing
##     wrong. The UI keeps no rules of its own.
##   - Each hero's tactic (docs/plans/rebuild-phase3b-tactics.md, section 4),
##     kept for every encounter until changed; every setup here carries the
##     tactics of the heroes in its formation.
##   - Each hero's path and stage (docs/plans/rebuild-phase4-paths.md,
##     section 6): vowed or transformed, chosen in the hero panel and kept
##     like tactics; a transformed Trapper's snares, placed like heroes; and
##     what the last fight put into each hero's deeds (Practice has no
##     thresholds, so the panel shows that instead).

## The first formation, before any fight: Brannoc in front of the other two
## (the sim runner's "guarded").
const DEFAULT_FORMATION: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}
## Where placed snares go first, in the middle row (then the nearest legal
## hexes).
const DEFAULT_SNARES: Array[Vector2i] = [Vector2i(2, 3), Vector2i(5, 3), Vector2i(3, 3), Vector2i(4, 3)]

var content: ContentDb
## The last formation fought with.
var formation: Dictionary[String, Vector2i] = {}
## The fight speed last chosen (Decision 2).
var speed: float = 1.0
## Whether the combat log's popup is open (closed at first: the board
## comes first).
var log_open: bool = false
## The seed fights are set up with.
var seed_value: int = 1
## Hero id -> tactic id, for the heroes who have one.
var tactics: Dictionary[String, String] = {}
## Hero id -> path id, for the heroes who've vowed one.
var vows: Dictionary[String, String] = {}
## The vowed heroes who've transformed.
var transformed: Array[String] = []
## Hero id -> the hexes (Vector2i) of the snares it places before a fight.
var snares: Dictionary[String, Array] = {}
## Hero id -> path id -> what the last fight put into that deed (empty
## before the first fight).
var last_deeds: Dictionary[String, Dictionary] = {}


static func make(content_db: ContentDb) -> PracticeSession:
	var session := PracticeSession.new()
	session.content = content_db
	session.formation = DEFAULT_FORMATION.duplicate()
	return session


## The fight for `encounter_id` from `hero_hexes`, or null (see errors()).
func setup(encounter_id: String, hero_hexes: Dictionary[String, Vector2i], fight_seed: int = 1) -> FightSetup:
	var errors: Array[String] = []
	return _build(encounter_id, hero_hexes, fight_seed, errors)


## What's wrong with `hero_hexes` in `encounter_id` (nothing: it's legal).
func errors(encounter_id: String, hero_hexes: Dictionary[String, Vector2i]) -> Array[String]:
	var found: Array[String] = []
	var fight: FightSetup = _build(encounter_id, hero_hexes, 1, found)
	if fight != null:
		found.append_array(fight.validate(content))
	return found


## The fight with the heroes' tactics, paths, and snares.
func _build(encounter_id: String, hero_hexes: Dictionary[String, Vector2i], fight_seed: int, errors_out: Array[String]) -> FightSetup:
	var hero_vows: Dictionary[String, String] = {}
	var hero_transformed: Array[String] = []
	for hero_id: String in content.hero_ids:
		if hero_hexes.has(hero_id) and vows.has(hero_id):
			hero_vows[hero_id] = vows[hero_id]
			if transformed.has(hero_id):
				hero_transformed.append(hero_id)
	var fight: FightSetup = Encounters.setup(content, encounter_id, hero_hexes, fight_seed, errors_out, tactics_in(hero_hexes), hero_vows, hero_transformed)
	if fight != null:
		for hero: UnitSetup in fight.heroes:
			if hero.def.placed_snares > 0:
				hero.snares.assign(snares.get(hero.id, []))
	return fight


## The remembered formation, made legal for `encounter_id`: each hero, in
## heroes.json's order, keeps its hex if it can, or takes the nearest one
## it can have (ties: the lower hex index, which counts column by column).
func formation_for(encounter_id: String) -> Dictionary[String, Vector2i]:
	var grid: HexGrid = content.tuning.make_grid()
	var placed: Dictionary[String, Vector2i] = {}
	for hero_id: String in content.hero_ids:
		var start: Vector2i = formation.get(hero_id, DEFAULT_FORMATION.get(hero_id, Vector2i(0, 0)))
		for hex: Vector2i in _nearest_first(grid, start):
			var trial: Dictionary[String, Vector2i] = placed.duplicate()
			trial[hero_id] = hex
			if errors(encounter_id, trial).is_empty():
				placed = trial
				break
	return placed


## The tactics of the heroes in `hero_hexes`.
func tactics_in(hero_hexes: Dictionary[String, Vector2i]) -> Dictionary[String, String]:
	var found: Dictionary[String, String] = {}
	for hero_id: String in content.hero_ids:
		if hero_hexes.has(hero_id) and tactics.has(hero_id):
			found[hero_id] = tactics[hero_id]
	return found


## The tactics `hero_id` can take with its kit now, in tactics.json's order
## (Wait to heal needs a signature that heals on mana: Decision 7 of
## docs/plans/rebuild-phase4-paths.md).
func tactics_for(hero_id: String) -> Array[TacticDef]:
	var found: Array[TacticDef] = []
	for tactic_id: String in content.tactic_ids:
		if _can_take(hero_id, content.tactics[tactic_id]):
			found.append(content.tactics[tactic_id])
	return found


func _can_take(hero_id: String, tactic: TacticDef) -> bool:
	return tactic.allows(hero_id) and Tactics.can_follow(tactic, kit_of(hero_id))


## Gives `hero_id` a tactic ("": none). Only one it can take.
func set_tactic(hero_id: String, tactic_id: String) -> void:
	if tactic_id.is_empty():
		tactics.erase(hero_id)
	elif content.tactics.has(tactic_id) and _can_take(hero_id, content.tactics[tactic_id]):
		tactics[hero_id] = tactic_id


## The path `hero_id` has vowed, or null.
func path_of(hero_id: String) -> PathDef:
	return content.paths[vows[hero_id]] if vows.has(hero_id) else null


func stage_of(hero_id: String) -> PathDef.Stage:
	if not vows.has(hero_id):
		return PathDef.Stage.BASE
	return PathDef.Stage.TRANSFORMED if transformed.has(hero_id) else PathDef.Stage.VOWED


## The kit `hero_id` fights with at its stage.
func kit_of(hero_id: String) -> UnitDef:
	var hero: HeroDef = content.heroes[hero_id]
	var path: PathDef = path_of(hero_id)
	return path.kit(stage_of(hero_id), hero.kit) if path != null else hero.kit


## Puts `hero_id` on `path_id` at `stage` (base: no path). Only one of its
## own paths. Snares it can no longer place are dropped; ones it now can
## start on DEFAULT_SNARES (fit_snares makes them legal for an encounter).
## A tactic its new kit can't take is dropped.
func set_path(hero_id: String, path_id: String, stage: PathDef.Stage) -> void:
	if stage == PathDef.Stage.BASE:
		vows.erase(hero_id)
		transformed.erase(hero_id)
	elif content.paths.has(path_id) and content.paths[path_id].hero == hero_id:
		vows[hero_id] = path_id
		if stage == PathDef.Stage.TRANSFORMED:
			if not transformed.has(hero_id):
				transformed.append(hero_id)
		else:
			transformed.erase(hero_id)
	if tactics.has(hero_id) and not _can_take(hero_id, content.tactics[tactics[hero_id]]):
		tactics.erase(hero_id)
	var can_place: int = kit_of(hero_id).placed_snares
	if can_place == 0:
		snares.erase(hero_id)
	elif not snares.has(hero_id):
		snares[hero_id] = DEFAULT_SNARES.slice(0, can_place)


## Moves `hero_id`'s snare `index` to `hex` in `encounter_id` with
## `hero_hexes`, if the result is legal. Another of its snares already there
## takes the old hex (a swap). Returns true if it moved.
func move_snare(encounter_id: String, hero_hexes: Dictionary[String, Vector2i], hero_id: String, index: int, hex: Vector2i) -> bool:
	var placed: Array = snares.get(hero_id, [])
	if index < 0 or index >= placed.size() or placed[index] == hex:
		return false
	var trial: Array = placed.duplicate()
	var other: int = trial.find(hex)
	if other >= 0:
		trial[other] = trial[index]
	trial[index] = hex
	snares[hero_id] = trial
	if errors(encounter_id, hero_hexes).is_empty():
		return true
	snares[hero_id] = placed
	return false


## Makes each hero's snares legal in `encounter_id` with `hero_hexes`: each
## keeps its hex if it can, or takes the nearest one it can have.
func fit_snares(encounter_id: String, hero_hexes: Dictionary[String, Vector2i]) -> void:
	var grid: HexGrid = content.tuning.make_grid()
	for hero_id: String in snares.keys():
		var wanted: Array = snares[hero_id]
		var placed: Array = []
		for start: Vector2i in wanted:
			for hex: Vector2i in _nearest_first(grid, start):
				if placed.has(hex):
					continue
				snares[hero_id] = placed + [hex]
				if errors(encounter_id, hero_hexes).is_empty():
					placed.append(hex)
					break
		snares[hero_id] = placed


## Keeps what `sim`'s fight put into each hero's deeds.
func remember_deeds(sim: CombatSim) -> void:
	last_deeds.clear()
	for deed: FightResult.Deed in sim.deed_amounts():
		if not last_deeds.has(deed.hero):
			last_deeds[deed.hero] = {}
		last_deeds[deed.hero][deed.path] = deed.amount


## What the last fight put into `hero_id`'s deed for `path_id` (-1: no
## fight yet, or the hero wasn't in it).
func last_deed(hero_id: String, path_id: String) -> int:
	return last_deeds[hero_id].get(path_id, -1) if last_deeds.has(hero_id) else -1


## Remembers the formation fought with.
func remember(hero_hexes: Dictionary[String, Vector2i]) -> void:
	formation = hero_hexes.duplicate()


## `hero_hexes` with `hero_id` moved to `hex`; a hero already there takes
## the mover's old hex (a swap).
static func moved(hero_hexes: Dictionary[String, Vector2i], hero_id: String, hex: Vector2i) -> Dictionary[String, Vector2i]:
	var result: Dictionary[String, Vector2i] = hero_hexes.duplicate()
	for other: String in hero_hexes:
		if other != hero_id and hero_hexes[other] == hex:
			result[other] = hero_hexes[hero_id]
	result[hero_id] = hex
	return result


## Every hex of the board, nearest `start` first (by the plane distance
## between centers; ties by hex index).
static func _nearest_first(grid: HexGrid, start: Vector2i) -> Array[Vector2i]:
	var from: Vector2i = grid.center(start.x, start.y) if grid.has(start.x, start.y) else Vector2i.ZERO
	var keyed: Array[Array] = []
	for index: int in grid.size():
		var col: int = grid.col_of(index)
		var row: int = grid.row_of(index)
		keyed.append([ArenaPlane.length_sq(grid.center(col, row) - from), index, Vector2i(col, row)])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var hexes: Array[Vector2i] = []
	for item: Array in keyed:
		hexes.append(item[2])
	return hexes
