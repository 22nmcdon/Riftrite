class_name ComboTally
extends RefCounted
## The combo readout's counts (docs/plans/rebuild-phase5c-combos.md, step 9a,
## section 17.4; part 7, section 7): what each engine did in a fight, read
## only from the combat log, like FightTally, so it can't disagree with it.
## The sim never uses it, and players never see it: it shows only behind
## the testing toggle, and the run report's --engines reads it.
##   - An engine is a source: a unit and its ability or passive, a relic, a
##     bond relic, or the rift (EffectSource.describe() names it).
##   - fires: its signature's FIRE lines, and each time a passive of it
##     fired and wrote something (LogEntry.starts_fire).
##   - from chains: of the passive fires, those set off by another event
##     effect (chain 2 or more; chain 1 is set off by what a unit did on its
##     own).
##   - deepest: the deepest chain among its entries.
##   - what it added: damage (hits and damage over time), healing, Shield.
## A fight's chains at the limit are its entries at chain_limit.


class EngineRow:
	## EffectSource.describe() of the source.
	var name: String
	## The unit it belongs to ("" for a relic, a bond relic, or the rift).
	var unit_id: String
	## The side that holds it (EffectSource.Team).
	var side: int
	var fires: int = 0
	var from_chains: int = 0
	var deepest: int = 0
	var damage: int = 0
	var healing: int = 0
	var shield: int = 0

	## What it added, all kinds.
	func total() -> int:
		return damage + healing + shield


## Engines in the order first seen.
var engines: Array[EngineRow] = []
var _by_name: Dictionary[String, EngineRow] = {}
## Entries at the chain limit (they set off nothing).
var at_limit: int = 0
var chain_limit: int = 8
## Each hero side's units (to sort engines by side).
var _heroes: Dictionary[String, bool] = {}


## A tally over a fight's whole log.
static func of_log(combat_log: CombatLog, limit: int, hero_ids: Array[String] = []) -> ComboTally:
	var tally := ComboTally.new()
	tally.chain_limit = limit
	for id: String in hero_ids:
		tally._heroes[id] = true
	tally.add_all(combat_log.entries)
	return tally


func add_all(entries: Array[LogEntry]) -> void:
	for entry: LogEntry in entries:
		add(entry)


## Adds one log entry.
func add(entry: LogEntry) -> void:
	if entry.chain >= chain_limit:
		at_limit += 1
	var counts: bool = entry.kind == LogEntry.Kind.FIRE or entry.starts_fire or entry.from_event \
		or entry.kind in [LogEntry.Kind.DAMAGE, LogEntry.Kind.STATUS_DAMAGE, LogEntry.Kind.HEAL, LogEntry.Kind.SHIELD]
	if not counts or (entry.source_unit.is_empty() and entry.source_relic_side < 0):
		return
	var engine: EngineRow = _engine(entry)
	if entry.kind == LogEntry.Kind.FIRE:
		engine.fires += 1
	if entry.starts_fire:
		engine.fires += 1
		if entry.chain >= 2:
			engine.from_chains += 1
	engine.deepest = maxi(engine.deepest, entry.chain)
	match entry.kind:
		LogEntry.Kind.DAMAGE, LogEntry.Kind.STATUS_DAMAGE:
			engine.damage += entry.amount
		LogEntry.Kind.HEAL:
			engine.healing += entry.amount
		LogEntry.Kind.SHIELD:
			engine.shield += entry.amount


func _engine(entry: LogEntry) -> EngineRow:
	var source: EffectSource = entry.source()
	var name: String = source.describe()
	var engine: EngineRow = _by_name.get(name)
	if engine == null:
		engine = EngineRow.new()
		engine.name = name
		engine.unit_id = entry.source_unit
		if source.relic_side >= 0:
			engine.side = source.relic_side
		else:
			engine.side = EffectSource.Team.HEROES if _heroes.has(entry.source_unit) else EffectSource.Team.ENEMIES
		_by_name[name] = engine
		engines.append(engine)
	return engine


## The engine named `name`, or null.
func engine(name: String) -> EngineRow:
	return _by_name.get(name)


## The heroes' side's engines that fired at least once (passives and
## signatures, relics, bond relics), most added first.
func hero_engines() -> Array[EngineRow]:
	var found: Array[EngineRow] = []
	for found_engine: EngineRow in engines:
		if found_engine.side == EffectSource.Team.HEROES and found_engine.fires > 0:
			found.append(found_engine)
	found.sort_custom(func(a: EngineRow, b: EngineRow) -> bool: return a.total() > b.total() if a.total() != b.total() else a.fires > b.fires)
	return found


## The damage rule's note on a number (`LogEntry.rule_base` and the kinds'
## bonuses): "40 · power +35% · crit +50% · Marked +20%" ("" without one).
## DEF's cut is the entry's `mitigated`, added by the caller.
static func rule_note(entry: LogEntry) -> String:
	if entry.rule_base < 0:
		return ""
	var parts: Array[String] = [str(entry.rule_base)]
	var bonuses: Array[int] = [entry.rule_power, entry.rule_crit, entry.rule_vulnerability, entry.rule_relic]
	var names: Array[String] = ["power", "crit", "healing taken" if entry.kind == LogEntry.Kind.HEAL else "vulnerability", "relic"]
	for i: int in 4:
		if bonuses[i] != 0:
			parts.append("%s %s" % [names[i], _percent(bonuses[i])])
	if parts.size() == 1:
		parts.append("no bonuses")
	return " · ".join(parts)


static func _percent(bp: int) -> String:
	var sign: String = "+" if bp >= 0 else "−"
	var value: int = absi(bp)
	@warning_ignore("integer_division")
	var whole: int = value / 100
	var part: int = value % 100
	if part == 0:
		return "%s%d%%" % [sign, whole]
	@warning_ignore("integer_division")
	return "%s%d.%d%%" % [sign, whole, part / 10] if part % 10 == 0 else "%s%d.%02d%%" % [sign, whole, part]
