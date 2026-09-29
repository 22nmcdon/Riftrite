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

## The first formation, before any fight: Brannoc in front of the other two
## (the sim runner's "guarded").
const DEFAULT_FORMATION: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}

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


static func make(content_db: ContentDb) -> PracticeSession:
	var session := PracticeSession.new()
	session.content = content_db
	session.formation = DEFAULT_FORMATION.duplicate()
	return session


## The fight for `encounter_id` from `hero_hexes`, or null (see errors()).
func setup(encounter_id: String, hero_hexes: Dictionary[String, Vector2i], fight_seed: int = 1) -> FightSetup:
	var errors: Array[String] = []
	return Encounters.setup(content, encounter_id, hero_hexes, fight_seed, errors)


## What's wrong with `hero_hexes` in `encounter_id` (nothing: it's legal).
func errors(encounter_id: String, hero_hexes: Dictionary[String, Vector2i]) -> Array[String]:
	var found: Array[String] = []
	var fight: FightSetup = Encounters.setup(content, encounter_id, hero_hexes, 1, found)
	if fight != null:
		found.append_array(fight.validate(content))
	return found


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
