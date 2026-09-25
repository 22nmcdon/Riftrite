class_name FightSetup
extends RefCounted
## Everything a fight needs besides content: who is fighting, the seed, and
## the act (which picks the Rift Collapse numbers). Same setup + same tuning
## = same fight.

## Roster rules (docs/design.md): 1-5 fielded, 6 in the roster.
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
## Relic ids the guild holds, and the enemy team's (see RelicDef). The sim
## accepts enemy-only relics on either side; the run layer decides who gets
## them.
var relics: Array[String] = []
var enemy_relics: Array[String] = []


static func make(fight_heroes: Array[UnitSetup], fight_enemies: Array[UnitSetup], fight_seed: int = 1, fight_act: int = 1, fight_bench: Array[UnitSetup] = [], fight_relics: Array[String] = [], fight_enemy_relics: Array[String] = []) -> FightSetup:
	var setup := FightSetup.new()
	setup.relics = fight_relics
	setup.enemy_relics = fight_enemy_relics
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
	for side_index: int in 2:
		var list: Array[String] = relics if side_index == 0 else enemy_relics
		var side: String = "guild" if side_index == 0 else "enemy"
		for i: int in list.size():
			if not content.relics.has(list[i]):
				errors.append("%s relic \"%s\" doesn't exist" % [side, list[i]])
			elif list.find(list[i]) < i:
				errors.append("%s relic \"%s\" is held twice" % [side, list[i]])
	return errors
