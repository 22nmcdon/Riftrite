class_name FightSetup
extends RefCounted
## Everything a fight starts from: both sides placed on the board, the rocks,
## the seed, and the act (docs/plans/rebuild-phase1-arena-sim.md, section 1).
## The fight's order is the heroes in this order, then the enemies.

var heroes: Array[UnitSetup] = []
var enemies: Array[UnitSetup] = []
## Rocks, by board hex (col, row).
var rocks: Array[Vector2i] = []
var seed_value: int = 1
var act: int = 1


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


## Every problem with the setup (empty when it can be fought).
func validate(content: ContentDb) -> Array[String]:
	var errors: Array[String] = []
	var grid: HexGrid = content.tuning.make_grid()
	if heroes.is_empty() or enemies.is_empty():
		errors.append("both sides need at least one unit")
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
			for status_id: String in unit.def.status_ids():
				if not content.statuses.has(status_id):
					errors.append("%s names an unknown status \"%s\"" % [where, status_id])
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
	return errors
