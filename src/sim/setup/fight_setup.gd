class_name FightSetup
extends RefCounted
## Everything a fight needs besides content: who is fighting, the seed, and
## the act (which picks the Rift Collapse numbers). Same setup + same tuning
## = same fight.

var seed_value: int = 1
var act: int = 1
var heroes: Array[UnitSetup] = []
var enemies: Array[UnitSetup] = []


static func make(fight_heroes: Array[UnitSetup], fight_enemies: Array[UnitSetup], fight_seed: int = 1, fight_act: int = 1) -> FightSetup:
	var setup := FightSetup.new()
	setup.heroes = fight_heroes
	setup.enemies = fight_enemies
	setup.seed_value = fight_seed
	setup.act = fight_act
	return setup


func validate() -> Array[String]:
	var errors: Array[String] = []
	if heroes.is_empty():
		errors.append("fight has no heroes")
	if enemies.is_empty():
		errors.append("fight has no enemies")
	var ids: Array[String] = []
	for unit: UnitSetup in heroes + enemies:
		if ids.has(unit.id):
			errors.append("unit id \"%s\" is used twice" % unit.id)
		ids.append(unit.id)
		unit.validate(errors)
	return errors
