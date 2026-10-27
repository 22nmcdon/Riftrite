class_name FightNames
extends RefCounted
## Display names for a fight's units, and the log's lines with them
## (docs/plans/rebuild-phase3-fight-sandbox.md, section 6). The log uses ids
## like rift_hound#2; the screen says "Rift Hound 2".
##   - Heroes go by their token's name ("Brannoc"); other units by their
##     kit's name.
##   - Copies are numbered from their id: rift_hound#2 is "Rift Hound 2".
##     The first copy (plain rift_hound) is "Rift Hound 1" when the fight
##     starts with several; a summon joining later never renames anyone, so
##     lines already written stay true.
##   - Summons get names as they join (learn()).
## (The old game's FightNames, from git history, adapted.)

## Unit id -> display name. FightTally reads this same dictionary, so the
## chart names summons as they join too.
var names: Dictionary[String, String] = {}
var hero_ids: Array[String] = []
var _content: ContentDb
## Kit ids that started the fight with more than one unit.
var _copied: Dictionary[String, bool] = {}
## [RegEx, name] pairs, longest id first.
var _patterns: Array[Array] = []


static func make(sim: CombatSim, content: ContentDb) -> FightNames:
	var made := FightNames.new()
	made._content = content
	var counts: Dictionary[String, int] = {}
	for unit: UnitState in sim.units:
		counts[unit.def.id] = counts.get(unit.def.id, 0) + 1
	for kit_id: String in counts:
		if counts[kit_id] > 1:
			made._copied[kit_id] = true
	made.learn(sim)
	return made


## Names any unit that joined since the last call (summons).
func learn(sim: CombatSim) -> void:
	if names.size() == sim.units.size():
		return
	for unit: UnitState in sim.units:
		if names.has(unit.id):
			continue
		names[unit.id] = _name_for(unit)
		if unit.side == EffectSource.Team.HEROES:
			hero_ids.append(unit.id)
	# Longest ids first, so rift_hound#2 is replaced before rift_hound.
	var ids: Array[String] = names.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length() or (a.length() == b.length() and a < b))
	_patterns.clear()
	for id: String in ids:
		var pattern := RegEx.new()
		pattern.compile("\\b%s\\b" % id)
		_patterns.append([pattern, names[id]])


func _name_for(unit: UnitState) -> String:
	if _content.heroes.has(unit.def.id):
		return ArenaView.label_for(unit.def, _content)
	var parts: PackedStringArray = unit.id.split("#")
	if parts.size() > 1:
		return "%s %s" % [unit.def.name, parts[1]]
	return "%s 1" % unit.def.name if _copied.has(unit.def.id) else unit.def.name


func name_of(unit_id: String) -> String:
	return names.get(unit_id, unit_id)


func is_hero(unit_id: String) -> bool:
	return hero_ids.has(unit_id)


## The entry's text with names instead of ids.
func text(entry: LogEntry) -> String:
	var line: String = entry.to_text()
	for pair: Array in _patterns:
		line = (pair[0] as RegEx).sub(line, pair[1], true)
	return line


## The entry as a BBCode line for the log panel, colored by side: heroes'
## lines in parchment, enemies' in rift violet; deaths red, heals green,
## Shields frost, signatures and auras dim, the collapse ember, and the
## fight's start, end, and phases bold ember.
func bbcode(entry: LogEntry) -> String:
	var line: String = text(entry).replace("[", "[lb]")
	var color: Color = UiStyle.TEXT if is_hero(entry.source_unit) else UiStyle.ENEMY_TEXT
	match entry.kind:
		LogEntry.Kind.FIGHT_START, LogEntry.Kind.FIGHT_END, LogEntry.Kind.PHASE:
			return "[b][color=#%s]%s[/color][/b]" % [UiStyle.EMBER.to_html(false), line]
		LogEntry.Kind.DEATH, LogEntry.Kind.FELL:
			color = UiStyle.BAD
		LogEntry.Kind.HEAL:
			color = UiStyle.GOOD
		LogEntry.Kind.SHIELD, LogEntry.Kind.SHIELD_SPENT:
			color = UiStyle.SHIELD
		LogEntry.Kind.COLLAPSE, LogEntry.Kind.COLLAPSE_RING, LogEntry.Kind.RELEASED:
			color = UiStyle.EMBER
		LogEntry.Kind.FIRE, LogEntry.Kind.AURA:
			color = color.darkened(0.3)
	return "[color=#%s]%s[/color]" % [color.to_html(false), line]
