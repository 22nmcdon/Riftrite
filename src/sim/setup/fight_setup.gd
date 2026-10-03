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
## The heroes' relics' effects at the fight's start (phase 5c step 5b), each
## with its relic as source and a scale (Reliquary's 20000), in the order
## the relics were taken; and how many enemy areas Salt Circle breaks.
var relic_effects: Array[EffectDef] = []
var relic_sources: Array[EffectSource] = []
var relic_scales: Array[int] = []
var salt_circles: int = 0
## The rules the heroes' side plays by (phase 5c step 5c; their relics').
var hero_rules: SideRules = SideRules.new()
## A Rift Tear's (phase 5c step 8b): when Rift Collapse starts (ticks; 0 is
## tuning's), and the rift's own effects at a time (Reinforcements: a summon
## on the enemies' side), each with its source and tick.
var collapse_start_ticks: int = 0
## Endless (phase 8 part 1): crumbled ground's damage times this (basis
## points; 0 leaves it as the act's).
var crumble_bp: int = 0
var rift_effects: Array[EffectDef] = []
var rift_sources: Array[EffectSource] = []
var rift_ticks: Array[int] = []


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
	if PathDef.is_apex(unit.stage) and (unit.apex == null or unit.path == null or unit.path.apex(unit.apex.id) == null):
		problems.append("%s is %s without one of its path's apexes" % [where, PathDef.STAGE_NAMES[unit.stage]])
	if unit.apex != null and not PathDef.is_apex(unit.stage):
		problems.append("%s has the apex %s but isn't at an apex stage" % [where, unit.apex.name])
	for apex: ApexDef in unit.deed_apexes:
		if unit.path == null or unit.path.apex(apex.id) == null:
			problems.append("%s can't count %s's deed" % [where, apex.name])
	if unit.tally_keys.size() != unit.tally_counts.size():
		problems.append("%s has %d tally keys for %d counts" % [where, unit.tally_keys.size(), unit.tally_counts.size()])
	return problems


## What's wrong with the snares placed for a unit (phase 4): no more than its
## kit's placed_snares, each on its own hex, on the board, in its side's zone
## or the middle row, and not on a rock.
static func _snare_problems(unit: UnitSetup, where: String, grid: HexGrid, rock_hexes: Array[Vector2i]) -> Array[String]:
	var problems: Array[String] = []
	if unit.lantern.x >= 0:
		# First Lantern (phase 5c step 7d): by the snares' rules.
		var lantern: Vector2i = unit.lantern
		var own_zone: HexGrid.Zone = HexGrid.Zone.HEROES if unit.side == EffectSource.Team.HEROES else HexGrid.Zone.ENEMIES
		if not unit.def.placed_lantern:
			problems.append("%s can't place a lantern" % where)
		elif not grid.has(lantern.x, lantern.y):
			problems.append("%s's lantern is off the board" % where)
		elif grid.zone(lantern.y) != own_zone and grid.zone(lantern.y) != HexGrid.Zone.NEUTRAL:
			problems.append("%s's lantern is in the enemies' half" % where)
		elif rock_hexes.has(lantern):
			problems.append("%s's lantern is on a rock" % where)
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
	if relic_sources.size() != relic_effects.size() or relic_scales.size() != relic_effects.size():
		errors.append("each relic effect at the start needs its source and scale")
	for effect: EffectDef in relic_effects:
		if effect.type == EffectDef.Type.APPLY_STATUS and not content.statuses.has(effect.status_id):
			errors.append("a relic's effect at the start names an unknown status \"%s\"" % effect.status_id)
	if collapse_start_ticks < 0:
		errors.append("Rift Collapse can't start before the fight")
	if crumble_bp < 0:
		errors.append("crumbled ground's damage can't be scaled below nothing")
	if rift_sources.size() != rift_effects.size() or rift_ticks.size() != rift_effects.size():
		errors.append("each rift effect needs its source and tick")
	for effect: EffectDef in rift_effects:
		if effect.type != EffectDef.Type.SUMMON:
			errors.append("a rift effect is a summon")
		elif summon_kit(effect.summon_kit) == null:
			errors.append("a rift effect summons \"%s\", which isn't among the fight's summon kits" % effect.summon_kit)
	var taken: Dictionary[int, String] = {}
	for rock: Vector2i in rocks:
		if not grid.has(rock.x, rock.y):
			errors.append("a rock at (%d, %d) is off the board" % [rock.x, rock.y])
		else:
			taken[grid.index(rock.x, rock.y)] = "a rock"
	var ids: Array[String] = []
	var by_hex: Dictionary[int, UnitSetup] = {}
	var shared: Dictionary[int, bool] = {}
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
					or not Tactics.can_follow(unit.tactic, unit.def)):
				errors.append("%s can't take the tactic %s" % [where, unit.tactic.name])
			errors.append_array(_path_problems(unit, where))
			if unit.max_hp_bp < 1000 or unit.max_hp_bp > FixedMath.BP_ONE:
				errors.append("%s has max HP at %s of its kit's (10%% to 100%%)" % [where, ValueBreakdown._percent(unit.max_hp_bp)])
			errors.append_array(_snare_problems(unit, where, grid, rocks))
		if not grid.has(unit.col, unit.row):
			errors.append("%s is off the board" % where)
			continue
		var zone: HexGrid.Zone = grid.zone(unit.row)
		var own: HexGrid.Zone = HexGrid.Zone.HEROES if unit.side == EffectSource.Team.HEROES else HexGrid.Zone.ENEMIES
		# A hero's gambit may let it start elsewhere too (phase 5c step 6d).
		var placed_by_gambit: bool = unit.side == EffectSource.Team.HEROES and unit.def != null and Gambits.may_place(grid, unit.def.place_rule, unit.col, unit.row)
		if zone != own and not placed_by_gambit:
			errors.append("%s is outside its side's zone" % where)
		var hex: int = grid.index(unit.col, unit.row)
		if taken.has(hex):
			# Stand Together: two heroes, one of them holding it, share a hex.
			var other: UnitSetup = by_hex.get(hex, null)
			var sharing: bool = other != null and other.side == EffectSource.Team.HEROES and unit.side == EffectSource.Team.HEROES \
				and not shared.has(hex) and (other.def.place_rule == "share" or (unit.def != null and unit.def.place_rule == "share"))
			if sharing:
				shared[hex] = true
			else:
				errors.append("%s shares its hex with %s" % [where, taken[hex]])
		else:
			taken[hex] = unit.id
			by_hex[hex] = unit
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
	for status_id: String in kit.condition_status_ids():
		if not content.statuses.has(status_id):
			errors.append("%s names an unknown status \"%s\"" % [where, status_id])
	for effect: EffectDef in kit.all_effects():
		if effect.type != EffectDef.Type.SUMMON:
			continue
		if summon_kit(effect.summon_kit) == null:
			errors.append("%s summons \"%s\", which isn't among the fight's summon kits" % [where, effect.summon_kit])
		for hex: Vector2i in effect.summon_hexes:
			if not grid.has(hex.x, hex.y):
				errors.append("%s summons onto (%d, %d), off the board" % [where, hex.x, hex.y])
