extends RefCounted
## The good bot's placement (docs/plans/rebuild-phase6-bot-tuning.md,
## section 2.2): it reads a fight's setup (the enemies' hexes and kits, the
## rocks, its heroes' kits) and scores a formation by features of it, never
## by fighting it. The weights (WEIGHTS) were fitted once, in step 6b, on
## practice fights of every Act 1 encounter (tools/bots/placement_data.gd
## and tools/bots/fit_placement.py), then frozen.
##
## Phase 8 part 3 (Act 2's water) adds two features: how many heroes start
## on water (they start slow), and how much water lies between the far and
## mid heroes and their nearest enemies (a slow walk for melee to reach them,
## and for them to close); both are 0 in a fight without water.
##
## Roles come from the kits, not the heroes' names: the tank is the hero
## with the most HP times DEF, the far one has the longest reach of the
## others, and the third is the middle. Distances are in hexes.

const FEATURE_NAMES: Array[String] = [
	"bias",
	"tank_row", "far_row", "mid_row",
	"tank_not_nearest",
	"far_enemy_dist", "mid_enemy_dist", "tank_enemy_dist",
	"tank_lateral", "far_lateral", "mid_lateral",
	"min_pair", "mean_pair",
	"tank_mid", "far_mid",
	"flank_cover",
	"area_bunch", "swarm_spread",
	"cover", "far_edge",
	"far_behind_tank", "mid_behind_tank",
	"on_water", "water_ahead",
]
## What the fight holds, the same for every formation in it: the score's
## weights for each feature move with these (each feature times each
## context is a term), so the same reading serves a swarm and a sniper nest.
## "water" is 1 in a fight with water (Act 2 on), so a later act's fights can
## weigh every feature apart from Act 1's.
const CONTEXT_NAMES: Array[String] = ["one", "flankers", "areas", "swarm", "ranged", "rocks", "enemies", "water"]


const WEIGHTS_FILE: String = "res://tools/bots/placement_weights.json"

static var _weights: PackedFloat64Array = PackedFloat64Array()
## Where the weights are read from (placement_check's --weights compares
## another fit).
static var weights_file: String = WEIGHTS_FILE


## The fitted weights, one per feature times context, context-major.
static func weights() -> PackedFloat64Array:
	if _weights.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(weights_file))
		_weights = PackedFloat64Array(data["weights"])
		assert(_weights.size() == FEATURE_NAMES.size() * CONTEXT_NAMES.size(), "placement_weights.json doesn't match the features")
	return _weights


## A formation's score: each feature times each context, weighted.
static func score(f: PackedFloat64Array, context: PackedFloat64Array) -> float:
	var w: PackedFloat64Array = weights()
	var total: float = 0.0
	var n: int = FEATURE_NAMES.size()
	for c: int in context.size():
		if context[c] == 0.0:
			continue
		var sum: float = 0.0
		for i: int in n:
			sum += w[c * n + i] * f[i]
		total += sum * context[c]
	return total


## The `count` best-scored formations for `setup`'s heroes (hero id -> hex),
## best first: every way to put them on different hexes of the heroes' zone
## off the rocks. Each hex's distances are worked out once, so a formation's
## score is lookups; it equals score(features(...)) for that formation
## (test_bots.gd checks). Each role tries only its SHORTLIST best hexes by
## the terms that are its alone (its row, reach to the enemies, lateral
## place, edge, rocks), then every way to combine them.
const SHORTLIST: int = 12


## `fixed_rows`: hero id -> the only row that hero may stand on (a
## Bloodied Oath's front row).
static func best_formations(setup: FightSetup, grid: HexGrid, count: int = 6, scores: Array[float] = [], fixed_rows: Dictionary = {}) -> Array[Dictionary]:
	var roles: Array[UnitSetup] = roles_of(setup)
	if roles.size() != 3:
		return []
	var zone: Array[Vector2i] = []
	for row: int in grid.height:
		if grid.zone(row) == HexGrid.Zone.HEROES:
			for col: int in grid.width:
				if not setup.rocks.has(Vector2i(col, row)):
					zone.append(Vector2i(col, row))
	var info: Dictionary = read_enemies(setup, grid)
	var context: PackedFloat64Array = info["context"]
	var n_f: int = FEATURE_NAMES.size()
	var w: PackedFloat64Array = weights()
	var eff: PackedFloat64Array = PackedFloat64Array()
	eff.resize(n_f)
	for c: int in context.size():
		for i: int in n_f:
			eff[i] += w[c * n_f + i] * context[c]
	var n: int = zone.size()
	var at: Array[Vector2] = []
	var near: PackedFloat64Array = PackedFloat64Array()
	var lateral: PackedFloat64Array = PackedFloat64Array()
	var rows: PackedFloat64Array = PackedFloat64Array()
	var edge: PackedFloat64Array = PackedFloat64Array()
	var rocky: PackedFloat64Array = PackedFloat64Array()
	var wet: PackedFloat64Array = PackedFloat64Array()
	var wade: PackedFloat64Array = PackedFloat64Array()
	var centroid: Vector2 = info["centroid"]
	for hex: Vector2i in zone:
		var c: Vector2i = grid.center(hex.x, hex.y)
		var p: Vector2 = Vector2(c.x, c.y) / float(HexGrid.HEX)
		at.append(p)
		var best_d: float = 99.0
		for q: Vector2 in info["at"]:
			best_d = minf(best_d, p.distance_to(q))
		near.append(best_d)
		lateral.append(absf(p.x - centroid.x))
		rows.append(hex.y)
		edge.append(minf(hex.x, grid.width - 1 - hex.x))
		var rocks_near: int = 0
		for other: Vector2i in grid.neighbors(hex.x, hex.y):
			if setup.rocks.has(other):
				rocks_near += 1
		rocky.append(rocks_near)
		wet.append(1.0 if setup.water.has(hex) else 0.0)
		wade.append(water_ahead(setup, grid, p, info["at"]))
	var pair: PackedFloat64Array = PackedFloat64Array()
	pair.resize(n * n)
	for i: int in n:
		for j: int in n:
			pair[i * n + j] = at[i].distance_to(at[j])
	var flankers: Array = info["flankers"]
	var flank: PackedFloat64Array = PackedFloat64Array()
	flank.resize(flankers.size() * n)
	for q: int in flankers.size():
		for i: int in n:
			flank[q * n + i] = (flankers[q] as Vector2).distance_to(at[i])
	var areas: float = info["areas"]
	var swarm: float = info["swarm"]
	# Each role's own terms, for its shortlist.
	var own: Array = [[], [], []]
	for i: int in n:
		own[0].append([eff[1] * rows[i] + eff[7] * near[i] + eff[8] * lateral[i] + eff[20] * rows[i] + eff[21] * rows[i] + eff[22] * wet[i], i])
		own[1].append([eff[2] * rows[i] + eff[5] * near[i] + eff[9] * lateral[i] + eff[18] * rocky[i] + eff[19] * edge[i] - eff[20] * rows[i] + eff[22] * wet[i] + eff[23] * wade[i], i])
		own[2].append([eff[3] * rows[i] + eff[6] * near[i] + eff[10] * lateral[i] + eff[18] * rocky[i] - eff[21] * rows[i] + eff[22] * wet[i] + eff[23] * wade[i], i])
	var lists: Array[PackedInt32Array] = []
	for role: int in 3:
		var ranked: Array = own[role]
		if fixed_rows.has(roles[role].id):
			var wanted: int = fixed_rows[roles[role].id]
			ranked = ranked.filter(func(entry: Array) -> bool: return zone[entry[1]].y == wanted)
		ranked.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0] if x[0] != y[0] else x[1] < y[1])
		var picked: PackedInt32Array = PackedInt32Array()
		for entry: Array in ranked.slice(0, mini(SHORTLIST, n)):
			picked.append(entry[1])
		lists.append(picked)
	var best: Array = []
	var floor_value: float = -INF
	for t: int in lists[0]:
		for a: int in lists[1]:
			if a == t:
				continue
			for m: int in lists[2]:
				if m == t or m == a:
					continue
				var p0: float = pair[t * n + a]
				var p1: float = pair[t * n + m]
				var p2: float = pair[a * n + m]
				var smallest: float = minf(p0, minf(p1, p2))
				var mean: float = (p0 + p1 + p2) / 3.0
				var cover: float = 0.0
				for q: int in flankers.size():
					cover += minf(flank[q * n + a], flank[q * n + m]) - flank[q * n + t]
				var value: float = eff[0] + eff[1] * rows[t] + eff[2] * rows[a] + eff[3] * rows[m] \
					+ eff[4] * (1.0 if near[t] > minf(near[a], near[m]) else 0.0) \
					+ eff[5] * near[a] + eff[6] * near[m] + eff[7] * near[t] \
					+ eff[8] * lateral[t] + eff[9] * lateral[a] + eff[10] * lateral[m] \
					+ eff[11] * smallest + eff[12] * mean + eff[13] * p1 + eff[14] * p2 \
					+ eff[15] * cover + eff[16] * areas / (1.0 + smallest) + eff[17] * swarm * mean \
					+ eff[18] * (rocky[a] + rocky[m]) + eff[19] * edge[a] \
					+ eff[20] * (rows[t] - rows[a]) + eff[21] * (rows[t] - rows[m]) \
					+ eff[22] * (wet[t] + wet[a] + wet[m]) + eff[23] * (wade[a] + wade[m])
				if best.size() < count or value > floor_value:
					best.append([value, t, a, m])
					best.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0] if x[0] != y[0] else (x[1] * 10000 + x[2] * 100 + x[3]) < (y[1] * 10000 + y[2] * 100 + y[3]))
					if best.size() > count:
						best.pop_back()
					floor_value = best.back()[0] if best.size() >= count else -INF
	var found: Array[Dictionary] = []
	for entry: Array in best:
		var formation: Dictionary[String, Vector2i] = {}
		formation[roles[0].id] = zone[entry[1]]
		formation[roles[1].id] = zone[entry[2]]
		formation[roles[2].id] = zone[entry[3]]
		found.append(formation)
		scores.append(entry[0])
	return found


## A formation's score the slow way: features() of `setup` with its heroes
## moved to `formation` (and put back).
static func formation_score(setup: FightSetup, grid: HexGrid, formation: Dictionary) -> float:
	var kept: Array[Vector2i] = []
	for unit: UnitSetup in setup.heroes:
		kept.append(Vector2i(unit.col, unit.row))
		unit.col = formation[unit.id].x
		unit.row = formation[unit.id].y
	var info: Dictionary = read_enemies(setup, grid)
	var value: float = score(features(setup, grid, info), info["context"])
	for i: int in setup.heroes.size():
		setup.heroes[i].col = kept[i].x
		setup.heroes[i].row = kept[i].y
	return value


## A formation's features (FEATURE_NAMES) for `setup` as it stands (its
## heroes' hexes). `info` is read_enemies(setup, grid), computed once a fight.
static func features(setup: FightSetup, grid: HexGrid, info: Dictionary) -> PackedFloat64Array:
	var f: PackedFloat64Array = PackedFloat64Array()
	f.resize(FEATURE_NAMES.size())
	f[0] = 1.0
	var roles: Array[UnitSetup] = roles_of(setup)
	if roles.size() < 3:
		return f
	var tank: UnitSetup = roles[0]
	var far: UnitSetup = roles[1]
	var mid: UnitSetup = roles[2]
	var at: Array[Vector2] = [_pos(grid, tank), _pos(grid, far), _pos(grid, mid)]
	var enemies: Array = info["at"]
	var centroid: Vector2 = info["centroid"]
	var near: Array[float] = []
	for p: Vector2 in at:
		var best: float = 99.0
		for q: Vector2 in enemies:
			best = minf(best, p.distance_to(q))
		near.append(best)
	f[1] = tank.row
	f[2] = far.row
	f[3] = mid.row
	f[4] = 1.0 if near[0] > minf(near[1], near[2]) else 0.0
	f[5] = near[1]
	f[6] = near[2]
	f[7] = near[0]
	f[8] = absf(at[0].x - centroid.x)
	f[9] = absf(at[1].x - centroid.x)
	f[10] = absf(at[2].x - centroid.x)
	var pairs: Array[float] = [at[0].distance_to(at[1]), at[0].distance_to(at[2]), at[1].distance_to(at[2])]
	f[11] = pairs.min()
	f[12] = (pairs[0] + pairs[1] + pairs[2]) / 3.0
	f[13] = pairs[1]
	f[14] = pairs[2]
	# Flankers and chargers: how much nearer the tank is to them than the
	# nearer of the other two (positive: the tank is in their way).
	var cover: float = 0.0
	for q: Vector2 in info["flankers"]:
		cover += minf(q.distance_to(at[1]), q.distance_to(at[2])) - q.distance_to(at[0])
	f[15] = cover
	f[16] = float(info["areas"]) / (1.0 + pairs.min())
	f[17] = float(info["swarm"]) * f[12]
	var rocks_near: int = 0
	for unit: UnitSetup in [far, mid]:
		for hex: Vector2i in grid.neighbors(unit.col, unit.row):
			if setup.rocks.has(hex):
				rocks_near += 1
	f[18] = rocks_near
	f[19] = minf(far.col, grid.width - 1 - far.col)
	f[20] = tank.row - far.row
	f[21] = tank.row - mid.row
	for unit: UnitSetup in [tank, far, mid]:
		if setup.water.has(Vector2i(unit.col, unit.row)):
			f[22] += 1.0
	f[23] = water_ahead(setup, grid, at[1], enemies) + water_ahead(setup, grid, at[2], enemies)
	return f


## How many water hexes the straight line from `p` (in hexes) to the nearest
## of `enemies` crosses (its own hex aside; sampled every quarter hex).
static func water_ahead(setup: FightSetup, grid: HexGrid, p: Vector2, enemies: Array) -> float:
	if setup.water.is_empty() or enemies.is_empty():
		return 0.0
	var target: Vector2 = enemies[0]
	for q: Vector2 in enemies:
		if p.distance_to(q) < p.distance_to(target):
			target = q
	var start: int = grid.hex_at(Vector2i(roundi(p.x * HexGrid.HEX), roundi(p.y * HexGrid.HEX)))
	var seen: Dictionary[int, bool] = {}
	var steps: int = maxi(ceili(p.distance_to(target) * 4.0), 1)
	for s: int in range(1, steps + 1):
		var point: Vector2 = p.lerp(target, float(s) / steps)
		var hex: int = grid.hex_at(Vector2i(roundi(point.x * HexGrid.HEX), roundi(point.y * HexGrid.HEX)))
		if hex != start and setup.water.has(Vector2i(grid.col_of(hex), grid.row_of(hex))):
			seen[hex] = true
	return float(seen.size())


## What a fight's enemies are, for features(): their points, their weighted
## middle (by HP), the flankers' and chargers' points, and counts of area
## throwers and swarm units.
static func read_enemies(setup: FightSetup, grid: HexGrid) -> Dictionary:
	var at: Array[Vector2] = []
	var flankers: Array[Vector2] = []
	var weight: float = 0.0
	var centroid: Vector2 = Vector2.ZERO
	var areas: int = 0
	var swarm: int = 0
	for unit: UnitSetup in setup.enemies:
		var p: Vector2 = _pos(grid, unit)
		at.append(p)
		var hp: float = unit.def.stats.get_stat(UnitStats.Stat.HP)
		centroid += p * hp
		weight += hp
		match unit.def.archetype:
			"flanker", "charger":
				flankers.append(p)
			"swarm":
				swarm += 1
		if unit.def.archetype == "caster" or _throws_areas(unit.def):
			areas += 1
	var ranged: int = setup.enemies.filter(func(unit: UnitSetup) -> bool: return unit.def.stats.get_stat(UnitStats.Stat.RANGE) >= 3).size()
	var context: PackedFloat64Array = PackedFloat64Array([1.0, flankers.size(), areas, swarm, ranged, setup.rocks.size(), setup.enemies.size(), 0.0 if setup.water.is_empty() else 1.0])
	return {"at": at, "flankers": flankers, "centroid": centroid / maxf(weight, 1.0), "areas": areas, "swarm": swarm, "context": context}


## The heroes by role: [tank, far, mid] (see the header).
static func roles_of(setup: FightSetup) -> Array[UnitSetup]:
	var heroes: Array[UnitSetup] = setup.heroes.duplicate()
	if heroes.size() < 3:
		return heroes
	heroes.sort_custom(func(a: UnitSetup, b: UnitSetup) -> bool:
		var ta: int = _toughness(a.def)
		var tb: int = _toughness(b.def)
		return ta > tb if ta != tb else a.id < b.id)
	var tank: UnitSetup = heroes[0]
	var others: Array[UnitSetup] = [heroes[1], heroes[2]]
	others.sort_custom(func(a: UnitSetup, b: UnitSetup) -> bool:
		var ra: int = a.def.stats.get_stat(UnitStats.Stat.RANGE)
		var rb: int = b.def.stats.get_stat(UnitStats.Stat.RANGE)
		return ra > rb if ra != rb else a.id < b.id)
	return [tank, others[0], others[1]]


static func _toughness(def: UnitDef) -> int:
	return def.stats.get_stat(UnitStats.Stat.HP) * (100 + def.stats.get_stat(UnitStats.Stat.DEF))


static func _throws_areas(def: UnitDef) -> bool:
	var abilities: Array[AbilityDef] = [def.basic_attack]
	if def.signature != null:
		abilities.append(def.signature)
	for ability: AbilityDef in abilities:
		for effect: EffectDef in ability.effects:
			if effect.shape != null:
				return true
	return false


## A unit's hex center, in hexes.
static func _pos(grid: HexGrid, unit: UnitSetup) -> Vector2:
	var c: Vector2i = grid.center(unit.col, unit.row)
	return Vector2(c.x, c.y) / float(HexGrid.HEX)
