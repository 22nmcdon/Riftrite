class_name RunLegendary
extends RefCounted
## Legendary upgrade paths in a run (docs/plans/legendary-items.md): each
## Legendary gains progress its own way and tiers up when it reaches the
## step's goal (extra progress carries over; at S progress stops). Fights,
## rank-ups, and the feed/devour actions call in here. Every tier-up comes
## back as a plain-words note for the UI.


## The item's path, or null for anything but a Legendary.
static func path_of(content: ContentDb, item: RunItem) -> LegendaryDef:
	var def: ItemDef = content.items.get(item.item_id, null)
	return def.legendary if def != null else null


## Adds `amount` progress, tiering up while goals are reached. Returns a note
## per tier gained.
static func advance(content: ContentDb, item: RunItem, amount: int) -> Array[String]:
	var notes: Array[String] = []
	var path: LegendaryDef = path_of(content, item)
	if path == null or amount <= 0 or item.tier >= 3:
		return notes
	item.progress += amount
	while item.tier < 3 and item.progress >= path.goal_at(item.tier):
		item.progress -= path.goal_at(item.tier)
		item.tier += 1
		notes.append("%s grows to %s" % [content.items[item.item_id].name, TuningDef.TIER_LABELS[item.tier]])
	if item.tier >= 3:
		item.progress = 0
	return notes


## What a finished fight does for the guild's Legendaries: hits (in any
## fight), a holder who fell (in a win), and a boss beaten (every Legendary on
## a hero's row). Returns tier-up notes.
static func after_fight(state: RunState, content: ContentDb, result: FightResult) -> Array[String]:
	var notes: Array[String] = []
	var hero_ids: Array[String] = []
	for hero: RunHero in state.heroes:
		hero_ids.append(hero.hero_id)
	var won: bool = result.guild_won()
	var encounter: EncounterDef = content.encounters.get(state.encounter_id, null)
	var boss: bool = won and encounter != null and encounter.kind == "boss"
	for hero: RunHero in state.heroes:
		for item: RunItem in hero.items:
			var path: LegendaryDef = path_of(content, item)
			if path == null:
				continue
			match path.path:
				"hits":
					notes.append_array(advance(content, item, hits(result.combat_log, hero.hero_id, item.item_id, hero_ids)))
				"martyr":
					if won and fell(result.combat_log, hero.hero_id):
						notes.append_array(advance(content, item, 1))
				"boss":
					if boss:
						notes.append_array(advance(content, item, 1))
	return notes


## A hero ranked up: their Bonded Legendaries grow.
static func on_rank_up(state: RunState, content: ContentDb, hero: RunHero) -> Array[String]:
	var notes: Array[String] = []
	for item: RunItem in hero.items:
		var path: LegendaryDef = path_of(content, item)
		if path != null and path.path == "bonded":
			notes.append_array(advance(content, item, 1))
	return notes


## How many times a hero's item hit an enemy with direct damage (not damage
## over time, not a relic's grant), from the fight's log.
static func hits(combat_log: CombatLog, hero_id: String, item_id: String, hero_ids: Array[String]) -> int:
	var count: int = 0
	for entry: LogEntry in combat_log.entries:
		if entry.kind == LogEntry.Kind.DAMAGE and entry.source_unit == hero_id and entry.source_item == item_id \
				and entry.source_granted_by.is_empty() and entry.source_relic_side < 0 and not hero_ids.has(entry.target):
			count += 1
	return count


## Whether a hero fell during the fight.
static func fell(combat_log: CombatLog, hero_id: String) -> bool:
	for entry: LogEntry in combat_log.entries:
		if entry.kind == LogEntry.Kind.DEATH and entry.target == hero_id:
			return true
	return false


## A meal's worth to a Devourer: the eaten item's tier + 1.
static func meal_value(item: RunItem) -> int:
	return item.tier + 1


## The guild's Devourers (Legendaries on the devour path), in roster order,
## then the stash.
static func devourers(state: RunState, content: ContentDb) -> Array[RunItem]:
	var found: Array[RunItem] = []
	var lists: Array = []
	for hero: RunHero in state.heroes:
		lists.append(hero.items)
	lists.append(state.stash)
	for list: Array in lists:
		for item: RunItem in list:
			var path: LegendaryDef = path_of(content, item)
			if path != null and path.path == "devour":
				found.append(item)
	return found


## The path and its progress in plain words, for the UI:
## "Grows by use: 23/60 hits to B", "Essence-hungry: feed it Ember (1/2 to A)",
## or "... fully grown" at S.
static func describe(content: ContentDb, item: RunItem) -> String:
	var path: LegendaryDef = path_of(content, item)
	if path == null:
		return ""
	var name: String = LegendaryDef.NAMES[path.path]
	if item.tier >= 3:
		return "%s: fully grown (S)" % name
	var next: String = TuningDef.TIER_LABELS[item.tier + 1]
	var goal: int = path.goal_at(item.tier)
	var tally: String = "%d/%d %s to %s" % [item.progress, goal, LegendaryDef.UNITS[path.path], next]
	match path.path:
		"essence":
			return "%s: feed it %s (%s)" % [name, content.essences[path.wanted_at(item.tier)].name, tally]
		"devour":
			return "%s: feed it other items (%s; a meal is worth its tier: C 1, B 2, A 3, S 4)" % [name, tally]
		"bonded":
			return "%s: grows when its holder ranks up (%s)" % [name, tally]
		"martyr":
			return "%s: grows when its holder falls in a fight the guild wins (%s)" % [name, tally]
		"boss":
			return "%s: grows with each boss beaten while it's equipped (%s)" % [name, tally]
	return "%s: %s" % [name, tally]
