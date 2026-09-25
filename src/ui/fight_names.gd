class_name FightNames
extends RefCounted
## Display names for a fight's units (the log uses ids like rift_pup_1):
## heroes by their short name ("Brannoc"), enemies by name, numbered when a
## team has several of the same ("Rift Pup 1"). Formats log lines for the
## fight screen: names instead of ids, colored by side.

## Unit id -> display name.
var names: Dictionary[String, String] = {}
var hero_ids: Array[String] = []
var _patterns: Array[Array] = []


static func make(sim: CombatSim) -> FightNames:
	var made := FightNames.new()
	var counts: Dictionary[String, int] = {}
	for unit: UnitState in sim.enemies:
		counts[unit.name] = counts.get(unit.name, 0) + 1
	var seen: Dictionary[String, int] = {}
	for unit: UnitState in sim.enemies:
		seen[unit.name] = seen.get(unit.name, 0) + 1
		made.names[unit.id] = unit.name if counts[unit.name] == 1 else "%s %d" % [unit.name, seen[unit.name]]
	for unit: UnitState in sim.heroes + sim.bench:
		made.names[unit.id] = unit.name.split(" of ")[0]
		made.hero_ids.append(unit.id)
	# Longest ids first, so rift_pup_10 is replaced before rift_pup_1.
	var ids: Array[String] = made.names.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length() or (a.length() == b.length() and a < b))
	for id: String in ids:
		var pattern := RegEx.new()
		pattern.compile("\\b%s\\b" % id)
		made._patterns.append([pattern, made.names[id]])
	return made


func name_of(unit_id: String) -> String:
	return names.get(unit_id, unit_id)


## The entry's text with names instead of ids.
func text(entry: LogEntry) -> String:
	var line: String = entry.to_text()
	for pair: Array in _patterns:
		line = (pair[0] as RegEx).sub(line, pair[1], true)
	return line


## The entry as a colored BBCode line for the log view.
func bbcode(entry: LogEntry) -> String:
	var line: String = text(entry).replace("[", "[lb]")
	var color: Color = UiStyle.TEXT if hero_ids.has(entry.source_unit) else UiStyle.ENEMY_TEXT
	match entry.kind:
		LogEntry.Kind.DEATH:
			color = UiStyle.BAD
		LogEntry.Kind.PHASE, LogEntry.Kind.SYNERGY, LogEntry.Kind.FIGHT_START, LogEntry.Kind.FIGHT_END:
			return "[b][color=#%s]%s[/color][/b]" % [UiStyle.EMBER.to_html(false), line]
		LogEntry.Kind.HEAL:
			color = UiStyle.GOOD
		LogEntry.Kind.SHIELD:
			color = UiStyle.SHIELD
		LogEntry.Kind.FIRE, LogEntry.Kind.AURA:
			color = UiStyle.TEXT_DIM
	return "[color=#%s]%s[/color]" % [color.to_html(false), line]
