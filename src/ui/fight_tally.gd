class_name FightTally
extends RefCounted
## The fight chart's numbers (docs/plans/fight-questions-and-readability.md,
## section 5): what each hero has done so far, added up from the combat log
## entries as they play back (so the chart and the log can't disagree).
## Three tabs: damage dealt, healing and Shield given, and damage taken. Each
## hero gets a bar split by type, plus a breakdown by source. Status damage
## counts for whoever applied it; relics get their own bar. UI only: the sim
## never reads this.

enum Tab { DAMAGE, SUPPORT, TAKEN }

const TAB_NAMES: Array[String] = ["Damage", "Healing and Shield", "Damage taken"]
## Each tab's types, in the order the bar stacks them (and the legend lists
## them).
const TYPES: Array[Array] = [
	["Basic attack", "Abilities", "Burn", "Poison", "Bleed"],
	["Healing", "Shield"],
	["To HP", "Absorbed by Shield"],
]
## Which damage type a status's damage counts as: each damage-over-time
## status belongs to the Burn, Poison, or Bleed family.
const STATUS_TYPES: Dictionary[String, String] = {
	"burn": "Burn", "golden_flame": "Burn", "plasma": "Burn", "searfire": "Burn",
	"poison": "Poison", "deathcap": "Poison", "caustic": "Poison", "nightshade": "Poison",
	"bleed": "Bleed", "hemorrhage": "Bleed", "blight": "Bleed",
}
## The relics' bar (they belong to the team, not a hero).
const RELICS: String = "relics"


## One bar: a hero (or the relics) on one tab.
class Bar:
	var id: String
	var name: String
	## By type, in TYPES order.
	var by_type: Array[int] = []
	## Amount by source ("Hatchet · Wrath", "Burn (Tallow Torch)").
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


## Per tab: the heroes' bars (in team order), then the relics' bar.
var bars: Array[Array] = []
var _names: Dictionary[String, String] = {}
## Each hero's basic attack (its item id), to tell basic attacks from
## abilities.
var _basic: Dictionary[String, String] = {}


## `names`: display names by unit id (FightNames).
static func make(sim: CombatSim, names: Dictionary[String, String]) -> FightTally:
	var tally := FightTally.new()
	tally._names = names
	for tab: int in TYPES.size():
		var list: Array[Bar] = []
		for unit: UnitState in sim.heroes:
			list.append(tally._bar(tab, unit.id, names.get(unit.id, unit.id)))
		list.append(tally._bar(tab, RELICS, "Relics"))
		tally.bars.append(list)
	for unit: UnitState in sim.heroes:
		for item: ItemState in unit.items:
			if item.is_auto_attack:
				tally._basic[unit.id] = item.def.id
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
			var dealer: Bar = _dealer(Tab.DAMAGE, entry)
			if dealer != null:
				var type: String = _damage_type(entry)
				if not type.is_empty():
					_count(dealer, TYPES[Tab.DAMAGE].find(type), _source(entry), entry.amount)
			_count_taken(entry)
		LogEntry.Kind.COLLAPSE:
			_count_taken(entry)
		LogEntry.Kind.HEAL, LogEntry.Kind.SHIELD:
			var giver: Bar = _dealer(Tab.SUPPORT, entry)
			if giver != null:
				_count(giver, 0 if entry.kind == LogEntry.Kind.HEAL else 1, _source(entry), entry.amount)


## The bars on a tab to show: heroes largest first (ties in team order),
## then the relics if they did anything.
func sorted(tab: Tab) -> Array[Bar]:
	var heroes: Array[Bar] = []
	var relics: Bar = null
	for bar: Bar in bars[tab]:
		if bar.id == RELICS:
			relics = bar
		else:
			heroes.append(bar)
	var order: Dictionary[String, int] = {}
	for i: int in heroes.size():
		order[heroes[i].id] = i
	heroes.sort_custom(func(a: Bar, b: Bar) -> bool: return a.total() > b.total() or (a.total() == b.total() and order[a.id] < order[b.id]))
	if relics != null and relics.total() > 0:
		heroes.append(relics)
	return heroes


func bar(tab: Tab, id: String) -> Bar:
	for found: Bar in bars[tab]:
		if found.id == id:
			return found
	return null


## The bar that did this (a hero, or the guild's relics), or null for the
## enemies' side.
func _dealer(tab: Tab, entry: LogEntry) -> Bar:
	if entry.source_relic_side >= 0:
		return bar(tab, RELICS) if entry.source_relic_side == UnitSetup.Side.HEROES else null
	if entry.source_unit.is_empty() or entry.source_unit == RELICS:
		return null
	return bar(tab, entry.source_unit)


## Basic attack, Abilities, or a status family ("" for a status outside
## them, which no content deals yet).
func _damage_type(entry: LogEntry) -> String:
	if entry.kind == LogEntry.Kind.STATUS_DAMAGE:
		return STATUS_TYPES.get(entry.status, "")
	if _basic.get(entry.source_unit, "") == entry.source_item and entry.source_granted_by.is_empty() and not entry.from_event:
		return "Basic attack"
	return "Abilities"


## Damage a hero took: to HP, and absorbed by Shield, by where it came from.
func _count_taken(entry: LogEntry) -> void:
	var taker: Bar = bar(Tab.TAKEN, entry.target)
	if taker == null:
		return
	var source: String
	if entry.kind == LogEntry.Kind.COLLAPSE:
		source = "Rift Collapse"
	elif entry.kind == LogEntry.Kind.STATUS_DAMAGE:
		source = entry.status_name
	elif entry.source_relic_side >= 0:
		source = "%s (relic)" % entry.source_item_name
	else:
		source = "%s: %s" % [_names.get(entry.source_unit, entry.source_unit), entry.source_item_name]
	if entry.amount <= 0:
		return
	taker.by_type[0] += entry.amount - entry.absorbed
	taker.by_type[1] += entry.absorbed
	taker.sources[source] = taker.sources.get(source, 0) + entry.amount


func _count(target: Bar, type: int, source: String, amount: int) -> void:
	if amount <= 0 or type < 0:
		return
	target.by_type[type] += amount
	target.sources[source] = target.sources.get(source, 0) + amount


## Where an amount came from: the item and its infusion, what granted it,
## or the status and the item that applied it.
func _source(entry: LogEntry) -> String:
	if entry.kind == LogEntry.Kind.STATUS_DAMAGE:
		return entry.status_name if entry.source_item_name.is_empty() else "%s (%s)" % [entry.status_name, entry.source_item_name]
	var label: String = entry.source_item_name
	if not entry.source_infusion_name.is_empty():
		label += " · %s" % entry.source_infusion_name
	if not entry.source_granted_by.is_empty():
		label += " (from %s)" % entry.source_granted_by
	return label
