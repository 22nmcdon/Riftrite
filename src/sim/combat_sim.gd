class_name CombatSim
extends RefCounted
## Runs one fight, tick by tick (20 ticks per second). Pure logic: no nodes,
## no rendering (CLAUDE.md rule 2). Same FightSetup + same content = same log.
##
## Each tick:
##   1. Rift Collapse damage, once per second from collapse start.
##   2. Statuses tick (damage over time, timers running out).
##   3. Every living unit's items advance their cooldowns (a Slowed item runs
##      slower, a Frozen unit's items stop, ATSP speeds the auto-attack);
##      collect the ones that fire.
##   4. Resolve those firings in resolution order: heroes then enemies, front
##      row then back, left to right, and each unit's items in row order.
##   5. Units at 0 HP die. They still fired whatever was ready this tick,
##      so resolution order gives neither side an edge.
##   6. Check for victory, defeat, or a tie.

var content: ContentDb
var tuning: TuningDef
var setup: FightSetup
var collapse: CollapseDef
var rng: SimRng
var combat_log: CombatLog = CombatLog.new()
var tick: int = 0
## Fielded heroes.
var heroes: Array[UnitState] = []
## Heroes in backup (never targeted; see UnitState.benched).
var bench: Array[UnitState] = []
var enemies: Array[UnitState] = []
## Every unit, in resolution order.
var units: Array[UnitState] = []
var finished: bool = false
## Ticks where some aura's window opens or closes (lookup only).
var _aura_boundaries: Dictionary[int, bool] = {}
## Auras active after the last rederive_all, as "unit:item:aura" keys, for
## logging when they start and end.
var _active_auras: Array[String] = []
var outcome: FightResult.Outcome = FightResult.Outcome.TIE


## Validates the setup and runs the whole fight.
static func run(fight_setup: FightSetup, fight_content: ContentDb) -> FightResult:
	var result := FightResult.new()
	result.errors = fight_setup.validate(fight_content)
	if fight_content.tuning.collapse_for_act(fight_setup.act) == null:
		result.errors.append("tuning has no Rift Collapse numbers for act %d" % fight_setup.act)
	if not result.errors.is_empty():
		return result
	var sim := CombatSim.new(fight_setup, fight_content)
	while not sim.finished:
		sim.step()
	result.outcome = sim.outcome
	result.end_tick = sim.tick
	result.combat_log = sim.combat_log
	for unit: UnitState in sim.units:
		for item: ItemState in unit.items:
			if item.essences.is_empty():
				continue
			var infusion := FightResult.InfusionResult.new()
			infusion.unit_id = unit.id
			infusion.item_id = item.def.id
			infusion.slot = item.slot
			infusion.xp_before = item.start_xp
			infusion.xp_after = item.infusion_xp
			infusion.level_before = item.start_level
			infusion.level_after = item.infusion_level
			result.infusions.append(infusion)
	return result


## Builds a fight ready to step. Call run() instead unless you need to step
## tick by tick (for example, to play a fight back). The setup must be valid.
func _init(fight_setup: FightSetup, fight_content: ContentDb) -> void:
	setup = fight_setup
	content = fight_content
	tuning = content.tuning
	collapse = tuning.collapse_for_act(setup.act)
	rng = SimRng.new(setup.seed_value)
	heroes = _build_side(setup.heroes, UnitSetup.Side.HEROES, content)
	enemies = _build_side(setup.enemies, UnitSetup.Side.ENEMIES, content)
	for unit_setup: UnitSetup in setup.bench:
		bench.append(UnitState.from_setup(unit_setup, UnitSetup.Side.HEROES, 0, content, true))
	# Resolution order: fielded heroes, then the bench, then enemies.
	units.append_array(heroes)
	units.append_array(bench)
	units.append_array(enemies)
	for i: int in units.size():
		for item: ItemState in units[i].items:
			item.owner_index = i

	var start := LogEntry.new()
	start.kind = LogEntry.Kind.FIGHT_START
	start.note = "seed %d, act %d" % [setup.seed_value, setup.act]
	combat_log.add(start)

	for unit: UnitState in units:
		for item: ItemState in unit.items:
			for aura: AuraDef in item.def.auras:
				if aura.window_from_ticks > 0:
					_aura_boundaries[aura.window_from_ticks] = true
				if aura.window_until_ticks > 0:
					_aura_boundaries[aura.window_until_ticks] = true
	rederive_all()


## Advances one tick. Does nothing once the fight is over.
func step() -> void:
	if finished:
		return
	tick += 1
	if _aura_boundaries.has(tick):
		rederive_all()
	_apply_collapse()
	Statuses.tick_all(self)

	var ready: Array[ItemState] = []
	for unit: UnitState in units:
		if not unit.alive:
			continue
		var unit_rate_bp: int = unit.cooldown_rate_bp()
		var atsp_bp: int = FixedMath.BP_ONE + unit.stats.get_stat(UnitStats.Stat.ATSP) * tuning.atsp_bp_per_point
		for item: ItemState in unit.items:
			if item.def.effects.is_empty():
				continue
			var rate_bp: int = FixedMath.apply_bp(unit_rate_bp, FixedMath.BP_ONE - item.slow_bp())
			if item.is_auto_attack:
				rate_bp = FixedMath.apply_bp(rate_bp, atsp_bp)
			if item.advance(rate_bp):
				ready.append(item)
	for item: ItemState in ready:
		EffectRunner.fire(self, item)

	_process_deaths()
	_check_end()


## Recomputes every unit's stats and every item's derived values from the
## auras active right now (standing holders, open windows), plus infusions
## and spills. Runs at fight start, when an aura window opens or closes,
## after deaths, and after an infusion levels up.
func rederive_all() -> void:
	var item_auras: Array[Array] = []
	var unit_boosts: Array[Array] = []
	for unit: UnitState in units:
		var per_item: Array[ItemAura] = []
		for item: ItemState in unit.items:
			per_item.append(ItemAura.new())
		item_auras.append(per_item)
		unit_boosts.append([FixedMath.BP_ONE, FixedMath.BP_ONE, FixedMath.BP_ONE, FixedMath.BP_ONE, FixedMath.BP_ONE, FixedMath.BP_ONE])

	var now_active: Array[String] = []
	for u: int in units.size():
		var holder: UnitState = units[u]
		if not holder.is_standing():
			continue
		for i: int in holder.items.size():
			var item: ItemState = holder.items[i]
			for a: int in item.def.auras.size():
				var aura: AuraDef = item.def.auras[a]
				if not aura.active_at(tick):
					continue
				now_active.append("%d:%d:%d" % [u, i, a])
				var label: String = item.def.name if aura.label.is_empty() else "%s (%s)" % [aura.label, item.def.name]
				if aura.targets_items():
					for target_item: ItemState in _aura_item_targets(holder, item, aura.target):
						(item_auras[u][holder.items.find(target_item)] as ItemAura).add(aura, label)
					continue
				for target_unit: UnitState in _aura_unit_targets(holder, aura.target):
					var t: int = units.find(target_unit)
					if aura.is_unit_stat():
						var stat: int = AuraDef.UNIT_STAT_FOR[aura.stat]
						unit_boosts[t][stat] = FixedMath.apply_bp(unit_boosts[t][stat], aura.value)
					else:
						for per_item: ItemAura in item_auras[t]:
							per_item.add(aura, label)
	_log_aura_changes(now_active)

	for u: int in units.size():
		var unit: UnitState = units[u]
		var stats := UnitStats.new()
		for stat: int in stats.values.size():
			stats.values[stat] = FixedMath.apply_bp(unit.base_stats.values[stat], unit_boosts[u][stat])
		unit.stats = stats
		var per_item: Array[ItemAura] = []
		per_item.assign(item_auras[u])
		unit.rederive_items(content, per_item)


func _aura_item_targets(holder: UnitState, item: ItemState, target: AuraDef.Target) -> Array[ItemState]:
	var row: Array[ItemState] = holder.row_items()
	var index: int = row.find(item)
	var result: Array[ItemState] = []
	match target:
		AuraDef.Target.SELF_ITEM:
			result.append(item)
		AuraDef.Target.LEFT_ITEM:
			if index > 0:
				result.append(row[index - 1])
		AuraDef.Target.RIGHT_ITEM:
			if index >= 0 and index < row.size() - 1:
				result.append(row[index + 1])
		AuraDef.Target.ADJACENT_ITEMS:
			if index > 0:
				result.append(row[index - 1])
			if index >= 0 and index < row.size() - 1:
				result.append(row[index + 1])
		AuraDef.Target.ROW_ITEMS:
			for other: ItemState in row:
				if other != item:
					result.append(other)
	return result


func _aura_unit_targets(holder: UnitState, target: AuraDef.Target) -> Array[UnitState]:
	match target:
		AuraDef.Target.HOLDER:
			var only: Array[UnitState] = [holder]
			return only
		AuraDef.Target.ALL_ALLIES:
			return Targeting.pick(EffectDef.Target.ALL_ALLIES, holder, null, self)
		AuraDef.Target.LINKED_ALLY:
			return Targeting.linked(EffectDef.Target.LINKED_ALLY, holder, allies_of(holder))
		AuraDef.Target.LINKED_LEFT_ALLY:
			return Targeting.linked(EffectDef.Target.LINKED_LEFT_ALLY, holder, allies_of(holder))
		AuraDef.Target.LINKED_RIGHT_ALLY:
			return Targeting.linked(EffectDef.Target.LINKED_RIGHT_ALLY, holder, allies_of(holder))
		AuraDef.Target.LINKED_ALLIES:
			return Targeting.linked(EffectDef.Target.LINKED_ALLIES, holder, allies_of(holder))
		AuraDef.Target.ROW_ALLIES:
			return Targeting.linked(EffectDef.Target.ROW_ALLIES, holder, allies_of(holder))
	var none: Array[UnitState] = []
	return none


## Logs each aura that started or ended since the last rederive_all.
func _log_aura_changes(now_active: Array[String]) -> void:
	for key: String in now_active:
		if not _active_auras.has(key):
			_log_aura(key, "starts")
	for key: String in _active_auras:
		if not now_active.has(key):
			_log_aura(key, "ends")
	_active_auras = now_active


func _log_aura(key: String, change: String) -> void:
	var parts: PackedStringArray = key.split(":")
	var holder: UnitState = units[parts[0].to_int()]
	var item: ItemState = holder.items[parts[1].to_int()]
	var aura: AuraDef = item.def.auras[parts[2].to_int()]
	var entry: LogEntry = new_entry(LogEntry.Kind.AURA, EffectSource.make(holder.id, item.def.id, item.def.name))
	entry.note = "%s: %s" % [change, aura.describe()]
	combat_log.add(entry)


## A log entry for the current tick, credited to `source`.
func new_entry(kind: LogEntry.Kind, source: EffectSource) -> LogEntry:
	var entry := LogEntry.new()
	entry.tick = tick
	entry.kind = kind
	entry.set_source(source)
	return entry


func unit_by_id(unit_id: String) -> UnitState:
	for unit: UnitState in units:
		if unit.id == unit_id:
			return unit
	return null


func owner_of(item: ItemState) -> UnitState:
	return units[item.owner_index]


func allies_of(unit: UnitState) -> Array[UnitState]:
	return heroes if unit.side == UnitSetup.Side.HEROES else enemies


func enemies_of(unit: UnitState) -> Array[UnitState]:
	return enemies if unit.side == UnitSetup.Side.HEROES else heroes


## Hit damage after the target's DEF: amount x C / (C + DEF).
func mitigate_hit(target: UnitState, amount: int) -> int:
	return FixedMath.mul_div(amount, tuning.defense_constant, tuning.defense_constant + target.defense())


## Shield takes damage first, then HP (HP stops at 0). Returns how much of
## the damage the shield absorbed.
func apply_damage(target: UnitState, amount: int) -> int:
	return apply_damage_vs_shield(target, amount, FixedMath.BP_ONE)


## Like apply_damage, but the damage is only `vs_shield_bp` effective against
## shields (5000: each point of shield soaks 2 damage; 0: skips shields).
## Whatever the shield doesn't soak hits HP at full strength.
func apply_damage_vs_shield(target: UnitState, amount: int, vs_shield_bp: int) -> int:
	if vs_shield_bp <= 0 or target.shield <= 0:
		target.hp = maxi(target.hp - amount, 0)
		return 0
	var shield_cost: int = FixedMath.apply_bp(amount, vs_shield_bp)
	if target.shield >= shield_cost:
		target.shield -= shield_cost
		return amount
	var absorbed: int = mini(FixedMath.mul_div(target.shield, FixedMath.BP_ONE, vs_shield_bp), amount)
	target.shield = 0
	target.hp = maxi(target.hp - (amount - absorbed), 0)
	return absorbed


## Collapse damage for the current tick, or 0 if it doesn't hit this tick.
## Starts at `base` at collapse start, grows by `growth` each second, and from
## the surge time the growth itself rises by `accel` each second.
func collapse_damage_at(at_tick: int) -> int:
	if at_tick < tuning.collapse_start_ticks:
		return 0
	if (at_tick - tuning.collapse_start_ticks) % FixedMath.TICKS_PER_SECOND != 0:
		return 0
	@warning_ignore("integer_division")
	var seconds: int = (at_tick - tuning.collapse_start_ticks) / FixedMath.TICKS_PER_SECOND
	var damage: int = collapse.base + collapse.growth * seconds
	if at_tick > tuning.collapse_surge_ticks:
		@warning_ignore("integer_division")
		var surge_seconds: int = (at_tick - tuning.collapse_surge_ticks) / FixedMath.TICKS_PER_SECOND
		@warning_ignore("integer_division")
		damage += collapse.accel * surge_seconds * (surge_seconds + 1) / 2
	return damage


func _apply_collapse() -> void:
	var damage: int = collapse_damage_at(tick)
	if damage <= 0:
		return
	for unit: UnitState in units:
		if not unit.alive or unit.benched:
			continue
		var entry := LogEntry.new()
		entry.tick = tick
		entry.kind = LogEntry.Kind.COLLAPSE
		entry.source_item = LogEntry.COLLAPSE_SOURCE
		entry.source_item_name = "Rift Collapse"
		entry.target = unit.id
		entry.amount = damage
		entry.absorbed = apply_damage(unit, damage)
		unit.last_hit_by = "Rift Collapse"
		combat_log.add(entry)


func _process_deaths() -> void:
	var anyone_fell: bool = false
	for unit: UnitState in units:
		if unit.alive and unit.hp <= 0 and not unit.benched:
			unit.alive = false
			anyone_fell = true
			var entry := LogEntry.new()
			entry.tick = tick
			entry.kind = LogEntry.Kind.DEATH
			entry.target = unit.id
			entry.note = "last hit: %s" % unit.last_hit_by
			combat_log.add(entry)
	if anyone_fell and not _active_auras.is_empty():
		rederive_all()


func _check_end() -> void:
	var heroes_up: bool = _any_alive(heroes)
	var enemies_up: bool = _any_alive(enemies)
	if heroes_up and enemies_up and tick < tuning.tie_ticks:
		return
	finished = true
	var note: String
	if not heroes_up and not enemies_up:
		outcome = FightResult.Outcome.TIE
		note = "Tie: both sides fell together (counts as a victory)"
	elif not enemies_up:
		outcome = FightResult.Outcome.VICTORY
		note = "Victory"
	elif not heroes_up:
		outcome = FightResult.Outcome.DEFEAT
		note = "Defeat"
	else:
		outcome = FightResult.Outcome.TIE
		note = "Tie: both sides outlasted the rift (counts as a victory)"
	var entry := LogEntry.new()
	entry.tick = tick
	entry.kind = LogEntry.Kind.FIGHT_END
	entry.note = note
	combat_log.add(entry)
	# Every infused item that took part earns the per-battle XP, fallen or not.
	for unit: UnitState in units:
		for item: ItemState in unit.items:
			Infusions.gain_xp(self, item, tuning.xp_per_battle, "after the fight")


static func _any_alive(side_units: Array[UnitState]) -> bool:
	for unit: UnitState in side_units:
		if unit.alive:
			return true
	return false


static func _build_side(setups: Array[UnitSetup], side: UnitSetup.Side, fight_content: ContentDb) -> Array[UnitState]:
	# Resolution order: front row left to right, then back row.
	var result: Array[UnitState] = []
	for row: UnitSetup.Row in [UnitSetup.Row.FRONT, UnitSetup.Row.BACK]:
		var column: int = 0
		for unit_setup: UnitSetup in setups:
			if unit_setup.row == row:
				result.append(UnitState.from_setup(unit_setup, side, column, fight_content))
				column += 1
	return result
