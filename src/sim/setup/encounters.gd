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
## `vows` puts heroes on paths: hero id -> path id, at the vowed stage, or
## transformed for the heroes `transformed` lists (phase 4). Every hero
## counts the deeds of all its paths. `apex_vows` (phase 8 part 2) puts
## transformed heroes on one of their path's apexes: hero id -> apex id, at
## the apex vowed stage, or the apex for the heroes `apexed` lists; a
## transformed hero counts its path's apexes' deeds. `enemy_specs` (phase 8
## part 3) specializes enemies: the encounter's enemy index -> one of that
## enemy's specialization ids, applied after the scaling. `enemy_upgrades`
## (phase 8 part 3, rebuild-phase8-act3.md section 2) gives enemies
## upgrades: the encounter's enemy index -> up to two upgrade ids, applied
## after the specialization.
## Returns null, with the reasons in `errors`, for an unknown encounter,
## hero, tactic, or path; FightSetup.validate checks the rest (zones, shared
## hexes, who can take which tactic, whose path it is).


static func setup(content: ContentDb, encounter_id: String, formation: Dictionary[String, Vector2i], fight_seed: int, errors: Array[String],
		tactics: Dictionary[String, String] = {}, vows: Dictionary[String, String] = {}, transformed: Array[String] = [],
		extras: Dictionary[String, HeroExtras] = {}, apex_vows: Dictionary[String, String] = {}, apexed: Array[String] = [],
		enemy_specs: Dictionary[int, String] = {}, enemy_upgrades: Dictionary[int, PackedStringArray] = {}) -> FightSetup:
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
	for hero_id: String in vows.keys():
		if not formation.has(hero_id):
			errors.append("a vow for \"%s\", who isn't in the fight" % hero_id)
		elif not content.paths.has(vows[hero_id]):
			errors.append("unknown path \"%s\"" % vows[hero_id])
	for hero_id: String in transformed:
		if not vows.has(hero_id):
			errors.append("\"%s\" transforms without a vow" % hero_id)
	for hero_id: String in apex_vows.keys():
		if not transformed.has(hero_id):
			errors.append("\"%s\" takes an apex without transforming" % hero_id)
		elif not content.apexes.has(apex_vows[hero_id]):
			errors.append("unknown apex \"%s\"" % apex_vows[hero_id])
		elif content.apexes[apex_vows[hero_id]].path != vows[hero_id]:
			errors.append("%s's apex \"%s\" isn't its path's" % [hero_id, apex_vows[hero_id]])
	for hero_id: String in apexed:
		if not apex_vows.has(hero_id):
			errors.append("\"%s\" earns an apex without its vow" % hero_id)
	for hero_id: String in extras.keys():
		if not formation.has(hero_id):
			errors.append("extras for \"%s\", who isn't in the fight" % hero_id)
		elif extras[hero_id].wounds < 0 or extras[hero_id].wounds > content.tuning.max_wounds:
			errors.append("%s can't have %d wounds" % [hero_id, extras[hero_id].wounds])
	if not errors.is_empty():
		return null
	var encounter: EncounterDef = content.encounters[encounter_id]
	var heroes: Array[UnitSetup] = []
	for hero_id: String in content.hero_ids:
		if formation.has(hero_id):
			var hex: Vector2i = formation[hero_id]
			var hero_def: HeroDef = content.heroes[hero_id]
			var path: PathDef = content.paths[vows[hero_id]] if vows.has(hero_id) else null
			var stage: PathDef.Stage = PathDef.Stage.BASE
			if path != null:
				stage = PathDef.Stage.TRANSFORMED if transformed.has(hero_id) else PathDef.Stage.VOWED
			var apex_id: String = apex_vows.get(hero_id, "")
			if not apex_id.is_empty():
				stage = PathDef.Stage.APEX if apexed.has(hero_id) else PathDef.Stage.APEX_VOWED
			# Another hero's path is refused by validate, so fall back to the
			# base kit rather than build a kit from the wrong hero.
			var kit: UnitDef = path.kit(stage, hero_def.kit, apex_id) if path != null and path.hero == hero_id else hero_def.kit
			if extras.has(hero_id):
				for mod: KitMod in extras[hero_id].mods:
					var problems: Array[String] = []
					kit = mod.apply(kit, problems)
					for problem: String in problems:
						errors.append("%s: a modifier leaves it unsound: %s" % [hero_id, problem])
			var hero: UnitSetup = UnitSetup.make(kit, EffectSource.Team.HEROES, hex.x, hex.y)
			if extras.has(hero_id):
				hero.mods = extras[hero_id].mods.duplicate()
				var each_wound: int = extras[hero_id].wound_bp if extras[hero_id].wound_bp > 0 else content.tuning.wound_bp
				hero.max_hp_bp = FixedMath.BP_ONE - extras[hero_id].wounds * each_wound
				hero.tally_keys = extras[hero_id].tally_keys.duplicate()
				hero.tally_counts = extras[hero_id].tally_counts.duplicate()
			hero.path = path
			hero.stage = stage
			hero.deed_paths = hero_def.paths.duplicate()
			if path != null and stage >= PathDef.Stage.TRANSFORMED:
				hero.deed_apexes = path.apexes.duplicate()
				hero.apex = path.apex(apex_id)
			if tactics.has(hero_id):
				hero.tactic = content.tactics[tactics[hero_id]]
			heroes.append(hero)
	var enemies: Array[UnitSetup] = []
	for i: int in encounter.enemies.size():
		var placed: EncounterDef.Placed = encounter.enemies[i]
		var kit: UnitDef = scaled(content.enemies[placed.enemy].kit, encounter.scale_bp)
		# A specialization (phase 8 part 3), after the scaling.
		var spec_id: String = enemy_specs.get(i, "")
		if not spec_id.is_empty():
			var spec: SpecializationDef = content.specializations.get(spec_id)
			if spec == null or spec.enemy != placed.enemy:
				errors.append("%s can't be specialized as \"%s\"" % [placed.enemy, spec_id])
			else:
				kit = spec.apply(kit)
		# Its upgrades (phase 8 part 3), after the specialization.
		var upgrade_ids: PackedStringArray = enemy_upgrades.get(i, PackedStringArray())
		if upgrade_ids.size() > EnemyUpgradeDef.PER_ENEMY:
			errors.append("%s can carry at most %d upgrades" % [placed.enemy, EnemyUpgradeDef.PER_ENEMY])
		for upgrade_id: String in upgrade_ids:
			var upgrade: EnemyUpgradeDef = content.enemy_upgrades.get(upgrade_id)
			if upgrade == null or kit.upgrades.has(upgrade_id):
				errors.append("%s can't carry the upgrade \"%s\"" % [placed.enemy, upgrade_id])
			else:
				var problems: Array[String] = []
				kit = upgrade.apply(kit, problems)
				for problem: String in problems:
					errors.append("%s: the upgrade \"%s\" leaves it unsound: %s" % [placed.enemy, upgrade_id, problem])
		enemies.append(UnitSetup.make(kit, EffectSource.Team.ENEMIES, placed.hex.x, placed.hex.y))
	if not errors.is_empty():
		return null
	var fight: FightSetup = FightSetup.make(heroes, enemies, encounter.rocks.duplicate(), fight_seed, encounter.act)
	fight.water = encounter.water.duplicate()
	fight.void_hexes = encounter.void_hexes.duplicate()
	fight.bridges = encounter.bridges.duplicate(true)
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
