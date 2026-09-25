class_name FightSetup
extends RefCounted
## Everything a fight needs besides content: who is fighting, the seed, and
## the act (which picks the Rift Collapse numbers). Same setup + same tuning
## = same fight.

## Roster rules (docs/design.md). The run layer also enforces at least 3
## fielded; the sim allows fewer so tests can stay small.
const MAX_FIELDED: int = 5
const ROSTER_CAP: int = 6

var seed_value: int = 1
var act: int = 1
## Fielded heroes.
var heroes: Array[UnitSetup] = []
## Heroes in backup: not on the field; their Backup effects and items'
## backup modes act from the bench.
var bench: Array[UnitSetup] = []
var enemies: Array[UnitSetup] = []


static func make(fight_heroes: Array[UnitSetup], fight_enemies: Array[UnitSetup], fight_seed: int = 1, fight_act: int = 1, fight_bench: Array[UnitSetup] = []) -> FightSetup:
	var setup := FightSetup.new()
	setup.heroes = fight_heroes
	setup.bench = fight_bench
	setup.enemies = fight_enemies
	setup.seed_value = fight_seed
	setup.act = fight_act
	return setup


func validate(content: ContentDb) -> Array[String]:
	var errors: Array[String] = []
	if heroes.is_empty():
		errors.append("fight has no heroes")
	if enemies.is_empty():
		errors.append("fight has no enemies")
	if heroes.size() > MAX_FIELDED:
		errors.append("%d heroes fielded; the limit is %d" % [heroes.size(), MAX_FIELDED])
	if heroes.size() + bench.size() > ROSTER_CAP:
		errors.append("%d heroes in the roster; the cap is %d" % [heroes.size() + bench.size(), ROSTER_CAP])
	var ids: Array[String] = []
	for unit: UnitSetup in heroes + bench + enemies:
		if ids.has(unit.id):
			errors.append("unit id \"%s\" is used twice" % unit.id)
		ids.append(unit.id)
		unit.validate(content, errors)
	return errors
