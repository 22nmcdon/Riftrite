class_name Encounters
extends RefCounted
## Builds a fight from content (docs/plans/rebuild-phase2-heroes-enemies.md,
## section 2): the heroes on a formation's hexes, and an encounter's enemies
## and rocks.
##   A formation is hero id -> (col, row), for example
##   {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}.
## The heroes go in the fight's order as heroes.json lists them (never the
## formation's own order, which is a Dictionary's), then the enemies as the
## encounter lists them. The encounter's scale_bp multiplies each enemy's HP
## and ATK. Every enemy a unit may summon (and every enemy those may summon)
## becomes a summon kit.
## `tactics` gives heroes their tactics: hero id -> tactic id (phase 3b).
## Returns null, with the reasons in `errors`, for an unknown encounter,
## hero, or tactic; FightSetup.validate checks the rest (zones, shared hexes,
## who can take which tactic).


static func setup(content: ContentDb, encounter_id: String, formation: Dictionary[String, Vector2i], fight_seed: int, errors: Array[String],
		tactics: Dictionary[String, String] = {}) -> FightSetup:
	if not content.encounters.has(encounter_id):
		errors.append("unknown encounter \"%s\"" % encounter_id)
		return null
	for hero_id: String in formation.keys():
		if not content.heroes.has(hero_id):
			errors.append("unknown hero \"%s\"" % hero_id)
	for hero_id: String in tactics.keys():
		if not formation.has(hero_id):
			errors.append("a tactic for \"%s\", who isn't in the fight" % hero_id)
		elif not content.tactics.has(tactics[hero_id]):
			errors.append("unknown tactic \"%s\"" % tactics[hero_id])
	if not errors.is_empty():
		return null
	var encounter: EncounterDef = content.encounters[encounter_id]
	var heroes: Array[UnitSetup] = []
	for hero_id: String in content.hero_ids:
		if formation.has(hero_id):
			var hex: Vector2i = formation[hero_id]
			var hero: UnitSetup = UnitSetup.make(content.heroes[hero_id].kit, EffectSource.Team.HEROES, hex.x, hex.y)
			if tactics.has(hero_id):
				hero.tactic = content.tactics[tactics[hero_id]]
			heroes.append(hero)
	var enemies: Array[UnitSetup] = []
	for placed: EncounterDef.Placed in encounter.enemies:
		var kit: UnitDef = scaled(content.enemies[placed.enemy].kit, encounter.scale_bp)
		enemies.append(UnitSetup.make(kit, EffectSource.Team.ENEMIES, placed.hex.x, placed.hex.y))
	var fight: FightSetup = FightSetup.make(heroes, enemies, encounter.rocks.duplicate(), fight_seed, encounter.act)
	fight.summon_kits = summon_kits(content, heroes + enemies, encounter.scale_bp)
	return fight


## `kit` with its HP and ATK multiplied by `scale_bp` (the kit itself when
## it's 10000). Its phases stay as they are: they never change stats.
static func scaled(kit: UnitDef, scale_bp: int) -> UnitDef:
	if scale_bp == FixedMath.BP_ONE:
		return kit
	var copy: UnitDef = kit.copy()
	copy.phases = kit.phases
	copy.stats = kit.stats.copy()
	for stat: UnitStats.Stat in [UnitStats.Stat.HP, UnitStats.Stat.ATK]:
		copy.stats.values[stat] = FixedMath.apply_bp(kit.stats.values[stat], scale_bp)
	return copy


## Every enemy the units can summon, and every enemy those can summon, in the
## order they're first named; scaled like the encounter's enemies.
static func summon_kits(content: ContentDb, units: Array[UnitSetup], scale_bp: int) -> Array[UnitDef]:
	var kits: Array[UnitDef] = []
	var names: Array[String] = []
	var to_check: Array[UnitDef] = []
	for unit: UnitSetup in units:
		to_check.append(unit.def)
	var next: int = 0
	while next < to_check.size():
		for kit_id: String in to_check[next].summon_ids():
			if names.has(kit_id) or not content.enemies.has(kit_id):
				continue
			names.append(kit_id)
			var kit: UnitDef = scaled(content.enemies[kit_id].kit, scale_bp)
			kits.append(kit)
			to_check.append(kit)
		next += 1
	return kits
