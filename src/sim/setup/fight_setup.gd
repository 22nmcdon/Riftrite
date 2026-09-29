class_name FightSetup
extends RefCounted
## Everything a fight starts from: both sides placed on the board, the rocks,
## the seed, and the act (docs/plans/rebuild-phase1-arena-sim.md, section 1).
## The fight's order is the heroes in this order, then the enemies, then
## summons as they join. The kits summons use are listed in summon_kits.

var heroes: Array[UnitSetup] = []
var enemies: Array[UnitSetup] = []
## Rocks, by board hex (col, row).
var rocks: Array[Vector2i] = []
var seed_value: int = 1
var act: int = 1
## The kits summon effects may use (looked up by id; each id once).
var summon_kits: Array[UnitDef] = []


static func make(hero_setups: Array[UnitSetup], enemy_setups: Array[UnitSetup], rock_hexes: Array[Vector2i] = [], fight_seed: int = 1, fight_act: int = 1) -> FightSetup:
	var setup := FightSetup.new()
	setup.heroes = hero_setups
	setup.enemies = enemy_setups
	setup.rocks = rock_hexes
	setup.seed_value = fight_seed
	setup.act = fight_act
	setup.name_copies()
	return setup


## Every unit, in the fight's order.
func units() -> Array[UnitSetup]:
	return heroes + enemies


## Gives each unit without its own id its kit's id, and later copies of the
## same kit "#2", "#3", and so on.
func name_copies() -> void:
	var seen: Dictionary[String, int] = {}
	for unit: UnitSetup in units():
		var count: int = seen.get(unit.id, 0) + 1
		seen[unit.id] = count
		if count > 1:
			unit.id = "%s#%d" % [unit.id, count]


## The summon kit with this id, or null.
func summon_kit(kit_id: String) -> UnitDef:
	for kit: UnitDef in summon_kits:
		if kit.id == kit_id:
			return kit
	return null


## What's wrong with a unit's path, stage, and deeds: only heroes have
## them, a path is its own hero's, and a stage past base needs a path.
static func _path_problems(unit: UnitSetup, where: String) -> Array[String]:
	var problems: Array[String] = []
	var hero: bool = unit.side == EffectSource.Team.HEROES
	if unit.path != null and (not hero or unit.path.hero != unit.def.id):
		problems.append("%s can't take the path %s" % [where, unit.path.name])
	if unit.path == null and unit.stage != PathDef.Stage.BASE:
		problems.append("%s is %s without a path" % [where, PathDef.STAGE_NAMES[unit.stage]])
	if unit.path != null and unit.stage == PathDef.Stage.BASE:
		problems.append("%s has the path %s but no stage" % [where, unit.path.name])
	for path: PathDef in unit.deed_paths:
		if not hero or path.hero != unit.def.id:
			problems.append("%s can't count %s's deed" % [where, path.name])
	return problems


## What's wrong with the snares placed for a unit (phase 4): no more than its
## kit's placed_snares, each on its own hex, on the board, in its side's zone
## or the middle row, and not on a rock.
static func _snare_problems(unit: UnitSetup, where: String, grid: HexGrid, rock_hexes: Array[Vector2i]) -> Array[String]:
	var problems: Array[String] = []
	if unit.snares.is_empty():
		return problems
	if unit.snares.size() > unit.def.placed_snares:
		problems.append("%s places %d snares, but can place %d" % [where, unit.snares.size(), unit.def.placed_snares])
	var own: HexGrid.Zone = HexGrid.Zone.HEROES if unit.side == EffectSource.Team.HEROES else HexGrid.Zone.ENEMIES
	for i: int in unit.snares.size():
		var hex: Vector2i = unit.snares[i]
		var at: String = "%s's snare at (%d, %d)" % [unit.id, hex.x, hex.y]
		if unit.snares.find(hex) < i:
			problems.append("%s is placed twice" % at)
		elif not grid.has(hex.x, hex.y):
			problems.append("%s is off the board" % at)
		elif grid.zone(hex.y) != own and grid.zone(hex.y) != HexGrid.Zone.NEUTRAL:
			problems.append("%s is in the enemies' half" % at)
		elif rock_hexes.has(hex):
			problems.append("%s is on a rock" % at)
	return problems


## Every problem with the setup (empty when it can be fought).
func validate(content: ContentDb) -> Array[String]:
	var errors: Array[String] = []
	var grid: HexGrid = content.tuning.make_grid()
	if heroes.is_empty() or enemies.is_empty():
		errors.append("both sides need at least one unit")
	if content.tuning.collapse_for_act(act) == null:
		errors.append("tuning has no Rift Collapse numbers for act %d" % act)
	for side: Array[UnitSetup] in [heroes, enemies]:
		if side.size() > content.tuning.max_units_per_side:
			errors.append("at most %d units per side" % content.tuning.max_units_per_side)
	var taken: Dictionary[int, String] = {}
	for rock: Vector2i in rocks:
		if not grid.has(rock.x, rock.y):
			errors.append("a rock at (%d, %d) is off the board" % [rock.x, rock.y])
		else:
			taken[grid.index(rock.x, rock.y)] = "a rock"
	var ids: Array[String] = []
	for unit: UnitSetup in units():
		var where: String = "%s at (%d, %d)" % [unit.id, unit.col, unit.row]
		if ids.has(unit.id):
			errors.append("two units are called %s" % unit.id)
		ids.append(unit.id)
		if unit.def == null or unit.def.basic_attack == null:
			errors.append("%s has no kit" % where)
		else:
			_check_kit(unit.def, where, content, grid, errors)
			if unit.tactic != null and (unit.side != EffectSource.Team.HEROES or not unit.tactic.allows(unit.def.id)
					or (unit.tactic.kind == TacticDef.Kind.SIGNATURE_THRESHOLD and not Tactics.can_wait(unit.def.signature))):
				errors.append("%s can't take the tactic %s" % [where, unit.tactic.name])
			errors.append_array(_path_problems(unit, where))
			errors.append_array(_snare_problems(unit, where, grid, rocks))
		if not grid.has(unit.col, unit.row):
			errors.append("%s is off the board" % where)
			continue
		var zone: HexGrid.Zone = grid.zone(unit.row)
		var own: HexGrid.Zone = HexGrid.Zone.HEROES if unit.side == EffectSource.Team.HEROES else HexGrid.Zone.ENEMIES
		if zone != own:
			errors.append("%s is outside its side's zone" % where)
		var hex: int = grid.index(unit.col, unit.row)
		if taken.has(hex):
			errors.append("%s shares its hex with %s" % [where, taken[hex]])
		else:
			taken[hex] = unit.id
	var kit_ids: Array[String] = []
	for kit: UnitDef in summon_kits:
		if kit_ids.has(kit.id):
			errors.append("two summon kits are called %s" % kit.id)
		kit_ids.append(kit.id)
		_check_kit(kit, "summon kit %s" % kit.id, content, grid, errors)
	return errors


## The checks every kit gets: the statuses it names, and its summons.
func _check_kit(kit: UnitDef, where: String, content: ContentDb, grid: HexGrid, errors: Array[String]) -> void:
	for status_id: String in kit.status_ids():
		if not content.statuses.has(status_id):
			errors.append("%s names an unknown status \"%s\"" % [where, status_id])
		elif content.statuses[status_id].kind == StatusDef.Kind.ENGAGED:
			errors.append("%s names \"%s\", which only the Engage trait sets" % [where, status_id])
	for effect: EffectDef in kit.all_effects():
		if effect.type != EffectDef.Type.SUMMON:
			continue
		if summon_kit(effect.summon_kit) == null:
			errors.append("%s summons \"%s\", which isn't among the fight's summon kits" % [where, effect.summon_kit])
		for hex: Vector2i in effect.summon_hexes:
			if not grid.has(hex.x, hex.y):
				errors.append("%s summons onto (%d, %d), off the board" % [where, hex.x, hex.y])
