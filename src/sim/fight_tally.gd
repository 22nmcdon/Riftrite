class_name FightTally
extends RefCounted
## What each hero has done in a fight, added up from the combat log
## (docs/plans/rebuild-phase3-fight-sandbox.md, section 6): the fight chart's
## numbers and the sim runner's. Both count here, so they can't disagree, and
## since it only reads log entries, the chart can't disagree with the log
## either. It only reads; the sim never uses it.
##   Three tabs: damage dealt, healing and Shield given, and damage taken.
##   Each hero gets a bar per tab, split by type, plus a breakdown by source.
##   - Damage: "Basic attack" is the hero's own basic attack (not what a
##     passive does on an event); signatures, passives, and the rest are
##     "Abilities"; damage over time counts for whoever applied it, by
##     family.
##   - Damage taken: all of it, from enemies, statuses, and Rift Collapse,
##     and what a guard took in an ally's place (Guard, phase 4), split into
##     what reached HP and what a Shield absorbed.
## (The old game's tally, from git history, adapted: no items, and no relics
## until phase 5.)

enum Tab { DAMAGE, SUPPORT, TAKEN }

const TAB_NAMES: Array[String] = ["Damage", "Healing and Shield", "Damage taken"]
## Each tab's types, in the order the bar stacks them (and the legend lists
## them).
const TYPES: Array[Array] = [
	["Basic attack", "Abilities", "Burn", "Poison", "Bleed"],
	["Healing", "Shield"],
	["To HP", "Absorbed by Shield"],
]
## Which damage type each damage-over-time status counts as. A test checks
## every such status in the data has one, so none is left out of the chart.
const STATUS_TYPES: Dictionary[String, String] = {"burn": "Burn", "poison": "Poison", "bleed": "Bleed", "sunder": "Sunder", "briar_torn": "Bleed"}
const COLLAPSE_SOURCE: String = "Rift Collapse"


## One hero's bar on one tab.
class Bar:
	var id: String
	var name: String
	## By type, in TYPES order.
	var by_type: Array[int] = []
	## Amount by source ("Shield Bash", "Burn (Cinder Burst)").
	var sources: Dictionary[String, int] = {}

	func total() -> int:
		var sum: int = 0
		for amount: int in by_type:
			sum += amount
		return sum

	## [source, amount] pairs, largest first (ties in first-seen order).
	func breakdown() -> Array[Array]:
		var pairs: Array[Array] = []
		for source: String in sources:
			pairs.append([source, sources[source], pairs.size()])
		pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1] or (a[1] == b[1] and a[2] < b[2]))
		var result: Array[Array] = []
		for pair: Array in pairs:
			result.append([pair[0], pair[1]])
		return result


## Per tab: the heroes' bars, in the fight's order.
var bars: Array[Array] = []
var _names: Dictionary[String, String] = {}
## Each hero's basic attack ids (its kit's, and its phases').
var _basic: Dictionary[String, Array] = {}


## A tally for `setup`'s heroes. `names`: display names by unit id (ids are
## used for any not given).
static func make(setup: FightSetup, names: Dictionary[String, String] = {}) -> FightTally:
	var tally := FightTally.new()
	tally._names = names
	for tab: int in TYPES.size():
		var list: Array[Bar] = []
		for hero: UnitSetup in setup.heroes:
			list.append(tally._bar(tab, hero.id, names.get(hero.id, hero.id)))
		tally.bars.append(list)
	for hero: UnitSetup in setup.heroes:
		var ids: Array[String] = [hero.def.basic_attack.id]
		for phase: PhaseDef in hero.def.phases:
			if not ids.has(phase.kit.basic_attack.id):
				ids.append(phase.kit.basic_attack.id)
		tally._basic[hero.id] = ids
	return tally


## A tally of a whole fight's log.
static func of_fight(setup: FightSetup, combat_log: CombatLog, names: Dictionary[String, String] = {}) -> FightTally:
	var tally: FightTally = make(setup, names)
	for entry: LogEntry in combat_log.entries:
		tally.add(entry)
	return tally


func _bar(tab: int, id: String, bar_name: String) -> Bar:
	var bar := Bar.new()
	bar.id = id
	bar.name = bar_name
	for type: String in TYPES[tab]:
		bar.by_type.append(0)
	return bar


## Adds one log entry.
func add(entry: LogEntry) -> void:
	match entry.kind:
		LogEntry.Kind.DAMAGE, LogEntry.Kind.STATUS_DAMAGE:
			var dealer: Bar = bar(Tab.DAMAGE, entry.source_unit)
			if dealer != null:
				_count(dealer, TYPES[Tab.DAMAGE].find(_damage_type(entry)), _source(entry), entry.amount)
			_count_taken(entry)
		LogEntry.Kind.COLLAPSE:
			_count_taken(entry)
		LogEntry.Kind.GUARD:
			_count_guarded(entry)
		LogEntry.Kind.HEAL, LogEntry.Kind.SHIELD:
			var giver: Bar = bar(Tab.SUPPORT, entry.source_unit)
			if giver != null:
				_count(giver, 0 if entry.kind == LogEntry.Kind.HEAL else 1, _source(entry), entry.amount)


## The bars on a tab, largest first (ties in the fight's order).
func sorted(tab: Tab) -> Array[Bar]:
	var list: Array[Bar] = []
	list.assign(bars[tab])
	var order: Dictionary[String, int] = {}
	for i: int in list.size():
		order[list[i].id] = i
	list.sort_custom(func(a: Bar, b: Bar) -> bool: return a.total() > b.total() or (a.total() == b.total() and order[a.id] < order[b.id]))
	return list


## A hero's bar on a tab, or null if `id` isn't a hero of this fight.
func bar(tab: Tab, id: String) -> Bar:
	for found: Bar in bars[tab]:
		if found.id == id:
			return found
	return null


## "Basic attack", "Abilities", or a status family.
func _damage_type(entry: LogEntry) -> String:
	if entry.kind == LogEntry.Kind.STATUS_DAMAGE:
		return STATUS_TYPES.get(entry.status, "Abilities")
	var basic: Array = _basic.get(entry.source_unit, [])
	return "Basic attack" if basic.has(entry.source_ability) and not entry.from_event else "Abilities"


## Damage a hero took: to HP, and absorbed by Shield, by where it came from.
func _count_taken(entry: LogEntry) -> void:
	var taker: Bar = bar(Tab.TAKEN, entry.target)
	if taker == null or entry.amount <= 0:
		return
	var source: String
	if entry.kind == LogEntry.Kind.COLLAPSE:
		source = COLLAPSE_SOURCE
	elif entry.kind == LogEntry.Kind.STATUS_DAMAGE:
		source = entry.status_name
	else:
		source = "%s: %s" % [_names.get(entry.source_unit, entry.source_unit), entry.source_ability_name]
	taker.by_type[0] += entry.amount - entry.absorbed
	taker.by_type[1] += entry.absorbed
	taker.sources[source] = taker.sources.get(source, 0) + entry.amount


## Damage a hero took in place of an ally (Guard; phase 4): the guard's,
## by the ally it covered.
func _count_guarded(entry: LogEntry) -> void:
	var taker: Bar = bar(Tab.TAKEN, entry.source_unit)
	if taker == null or entry.amount <= 0:
		return
	taker.by_type[0] += entry.amount - entry.absorbed
	taker.by_type[1] += entry.absorbed
	var source: String = "%s for %s" % [entry.source_ability_name, _names.get(entry.target, entry.target)]
	taker.sources[source] = taker.sources.get(source, 0) + entry.amount


func _count(target: Bar, type: int, source: String, amount: int) -> void:
	if amount <= 0 or type < 0:
		return
	target.by_type[type] += amount
	target.sources[source] = target.sources.get(source, 0) + amount


## Where an amount came from: the ability, or the status and the ability
## that applied it.
func _source(entry: LogEntry) -> String:
	if entry.kind == LogEntry.Kind.STATUS_DAMAGE:
		return entry.status_name if entry.source_ability_name.is_empty() else "%s (%s)" % [entry.status_name, entry.source_ability_name]
	return entry.source_ability_name
