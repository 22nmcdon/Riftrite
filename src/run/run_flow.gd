class_name RunFlow
extends RefCounted
## The run's rules (docs/plans/rebuild-phase5-run.md, sections 1 and 3): the
## only thing that changes a RunState, one action at a time. Each action
## checks it's legal now and returns "" if it happened, or why it didn't
## (the state is then untouched). The UI and the run bot both drive it.
## A day (phase 5c step 8, docs/plans/days-and-nodes.md): the route (choose
## one of today's two fights), the loadout and placement, the fight (fight()
## runs it, CombatSim.run on fight_setup()'s setup), after it (the pick, a
## relic choice), the shop (the Pedlar), then a node (Camp, Rift Tear at a
## depth, the Magpie, an Event's scene, or a Bloodied Oath; step 8c), whose
## setup for tomorrow's fight holds through that fight's replays (Decision
## 42). A win or a tie pays shards by the fight's tier and
## moves on to after the fight; a loss replays the day from the route, and
## the act's losses_to_end-th ends the run. The boss's day ends with the
## fight and its relic choice.
## Deeds and wounds count from every fight, won or lost; a won fight (a tie,
## or a Hunt won, too) first heals one wound on each hero (the playtester,
## after gate 3: wounds should hurt a bad streak, not a run of wins).
## Winning the boss ends the run won.
## Growth (section 4 and 5): a hero whose vowed deed reaches its threshold
## transforms after that fight, won or lost, for good. Until then its vow can
## be switched between fights. A win offers a pick (Offers.pick): take one
## upgrade, or the act's pick_shards instead; the day can't move on while it
## waits.
## The economy (section 6): items owned wait in the stash; any hero equips
## any item in a free slot between fights (one tactic and one gambit each).
## A shop opens after the fight (the Pedlar) or as a node (the Magpie): buy
## its wares, treat a wound, or (the Pedlar only) reroll or sell an item
## back, or (the Magpie only) sell or swap a relic; leaving closes it. Phase 5c step 6: a run owns one of each item, at a rank; a
## bought copy is a rank up, and fights rank items up by their kind. A fight's kit is the path's,
## then its upgrades, then its loadout in slot order.

## Where a relic choice happens (its stream's visit).
const RELIC_SHRINE: int = 0
const RELIC_AFTER_FIGHT: int = 1
const RELIC_SHOP: int = 2

var run: RunContent
var state: RunState
## The act the run is in (phase 8 part 3).
var act: ActDef:
	get:
		return run.act_of(state)
## The last fight fight() ran, its setup and result (not saved; the run
## report's engines read them, phase 5c step 9b).
var last_setup: FightSetup = null
var last_result: FightResult = null


## A new run from `run_seed`: its team is `vows`' heroes (hero id -> path
## id, one of its own: the team draft, phase 8 part 4, HeroTeam), each vowed to
## a path. Null with the reasons in `errors` if the team or the vows aren't
## right. A `testing` run is offered Act 1's endless (phase 8 part 3,
## Decision 15).
static func start(run_content: RunContent, run_seed: int, vows: Dictionary[String, String], errors: Array[String], testing: bool = false) -> RunFlow:
	var content: ContentDb = run_content.content
	var team: Array[String] = []
	team.assign(vows.keys())
	var refused: String = HeroTeam.problem(content, team)
	if not refused.is_empty():
		errors.append(refused)
		return null
	team = HeroTeam.ordered(content, team)
	for hero_id: String in team:
		if not content.paths.has(vows[hero_id]) or content.paths[vows[hero_id]].hero != hero_id:
			errors.append("%s can't vow to \"%s\"" % [hero_id, vows[hero_id]])
	if not errors.is_empty():
		return null
	var state := RunState.new()
	state.seed_value = run_seed
	state.testing = testing
	state.act = run_content.acts[0].act
	state.shards = run_content.acts[0].start_shards
	for hero_id: String in team:
		var hero := RunState.Hero.new()
		hero.id = hero_id
		hero.path = vows[hero_id]
		for path: PathDef in content.heroes[hero_id].paths:
			hero.deeds[path.id] = 0
		for i: int in run_content.acts[0].slots:
			hero.slots.append("")
		state.heroes.append(hero)
	state.options = ActDraw.draw(run_content, run_seed)
	var flow: RunFlow = resume(run_content, state)
	flow._start_day()
	return flow


## A flow over a state already made (a loaded save).
static func resume(run_content: RunContent, run_state: RunState) -> RunFlow:
	var flow := RunFlow.new()
	flow.run = run_content
	flow.state = run_state
	return flow


# --- the day's start, the shop, and the nodes --------------------------------------

## A day begins (a new one, or one replayed after a loss): the route. An
## endless floor (phase 8 part 1) first draws its fight (and the next two
## floors', for Scout, Map the Rift, and a Bleeding Tear), and every
## modifier_every-th floor gathers a rift modifier for good.
func _start_day() -> void:
	state.phase = RunState.Phase.ROUTE
	state.chosen = ""
	if state.endless:
		_draw_floors()
		var endless: ActDef.Endless = act.endless
		@warning_ignore("integer_division")
		var due: int = run.floor_of(state, state.day) / endless.modifier_every
		while state.endless_mods.size() < due:
			var modifier: String = Offers.endless_modifier(run, state, state.day)
			if modifier.is_empty():
				break
			state.endless_mods.append(modifier)
	_draw_specializations()
	if state.sealed:
		_skip_sealed()


## Today's fights' specializations and upgrades (phase 8 part 3), drawn
## afresh each time the day starts (Decision 6 of act2-glassmere.md), then
## what the rift learned put on a boss's adds in their place (RiftLearns).
func _draw_specializations() -> void:
	state.today_specs.clear()
	state.today_upgrades.clear()
	state.today_learned.clear()
	var today: Array[String] = state.today()
	for i: int in today.size():
		var specs: Array[String] = Offers.specializations(run, state, i, today[i])
		var learned: Array[Dictionary] = RiftLearns.picks(run, state, i, today[i])
		for pick: Dictionary in learned:
			specs[int(pick["enemy"])] = str(pick.get("specialization", ""))
		state.today_specs.append(specs)
		state.today_upgrades.append(Offers.enemy_upgrades(run, state, i, today[i]))
		state.today_learned.append(learned)


## Today's chosen fight's specializations: enemy index -> specialization id
## (none for a Hunt, or a fight not among today's).
func chosen_specs() -> Dictionary[int, String]:
	var specs: Dictionary[int, String] = {}
	var index: int = state.today().find(state.chosen)
	if index < 0 or index >= state.today_specs.size() or fight_encounter() != state.chosen:
		return specs
	var drawn: Array = state.today_specs[index]
	for i: int in drawn.size():
		if not str(drawn[i]).is_empty():
			specs[i] = str(drawn[i])
	return specs


## Today's chosen fight's upgrades: enemy index -> the drawn upgrades that
## change that enemy (none for a Hunt, or a fight not among today's).
func chosen_upgrades() -> Dictionary[int, PackedStringArray]:
	var upgrades: Dictionary[int, PackedStringArray] = {}
	var index: int = state.today().find(state.chosen)
	if index < 0 or index >= state.today_upgrades.size() or fight_encounter() != state.chosen:
		return upgrades
	var drawn: Array = state.today_upgrades[index]
	var encounter: EncounterDef = run.content.encounters[state.chosen]
	for i: int in encounter.enemies.size():
		var kit: UnitDef = run.content.enemies[encounter.enemies[i].enemy].kit
		var carried: PackedStringArray = []
		for id: Variant in drawn:
			var upgrade: EnemyUpgradeDef = run.content.enemy_upgrades.get(str(id))
			if upgrade != null and upgrade.changes(kit):
				carried.append(upgrade.id)
		if not carried.is_empty():
			upgrades[i] = carried
	# What the rift learned (phase 8 part 3): an add's learned upgrade.
	if index < state.today_learned.size():
		for pick: Variant in state.today_learned[index]:
			var upgrade_id: String = str((pick as Dictionary).get("upgrade", ""))
			if not upgrade_id.is_empty() and run.content.enemy_upgrades.has(upgrade_id):
				var enemy: int = int((pick as Dictionary)["enemy"])
				var carried: PackedStringArray = upgrades.get(enemy, PackedStringArray())
				carried.append(upgrade_id)
				upgrades[enemy] = carried
	return upgrades


## Draws the endless floors' fights up to two days ahead.
func _draw_floors() -> void:
	while state.options.size() < state.day + 2:
		state.options.append(Offers.endless_floor(run, state, state.options.size() + 1))


# --- endless (phase 8 part 1) -----------------------------------------------------

## The floor the run is on (0 before endless).
func floor_number() -> int:
	return run.floor_of(state, state.day)


## At the choice after an act's boss shop, when there's a next act and the
## run may also go deeper (the testing option): on to the next act.
func next_act() -> String:
	if state.phase != RunState.Phase.CHOICE:
		return _not_now("go on to the next act")
	if run.next_act(state) == null:
		return "this is the last act"
	_next_act()
	return ""


## After the act's boss shop: ends the run won.
func end_run() -> String:
	if state.phase != RunState.Phase.CHOICE:
		return _not_now("end the run")
	_end(RunState.Outcome.WON)
	return ""


## After the act's boss shop: goes deeper, into endless's floor 1, keeping
## everything the run holds. From here the first loss ends the run.
func go_deeper() -> String:
	if state.phase != RunState.Phase.CHOICE:
		return _not_now("go deeper")
	if not can_go_deeper():
		return "this act has no endless to go deeper into"
	state.endless = true
	state.magpie_visits = 0
	while state.taken_nodes.size() < state.day:
		state.taken_nodes.append("")
	state.day += 1
	state.attempt = 0
	_start_day()
	return ""


## An endless floor's enemies' growth: HP and ATK times growth_bp per floor,
## compounded (null before endless).
func _floor_growth_mod() -> KitMod:
	var floor_now: int = floor_number()
	if floor_now <= 0:
		return null
	var mod: KitMod = KitMod.make()
	var bp: int = ActDef.Endless.compound(act.endless.growth_bp, floor_now)
	mod.stats_bp[UnitStats.Stat.HP] = bp
	mod.stats_bp[UnitStats.Stat.ATK] = bp
	return mod


## An endless floor's Rift Collapse: collapse_step_ms earlier a floor, never
## before collapse_floor_ms (the earlier of it and Early Collapse), and its
## crumbled ground crumble_growth_bp harder a floor, compounded.
func _endless_rules(setup: FightSetup) -> void:
	var floor_now: int = floor_number()
	if floor_now <= 0:
		return
	var endless: ActDef.Endless = act.endless
	@warning_ignore("integer_division")
	var start_ms: int = maxi(run.content.tuning.collapse_start_ticks * 1000 / FixedMath.TICKS_PER_SECOND - endless.collapse_step_ms * floor_now, endless.collapse_floor_ms)
	var start: int = FixedMath.ms_to_ticks(start_ms)
	setup.collapse_start_ticks = start if setup.collapse_start_ticks == 0 else mini(setup.collapse_start_ticks, start)
	setup.crumble_bp = ActDef.Endless.compound(endless.crumble_growth_bp, floor_now)


## A Bleeding Tear sealed (phase 5c step 8c): today's fight is won without
## fighting: the first option, recorded as won in 0s, half its pay, and its
## pick; no deeds, ranks, wounds, or oath fights.
func _skip_sealed() -> void:
	state.sealed = false
	var encounter_id: String = state.today()[0]
	var fought := RunState.Fought.new()
	fought.act = state.act
	fought.day = state.day
	fought.attempt = state.attempt
	fought.encounter = encounter_id
	fought.outcome = FightResult.Outcome.VICTORY
	state.fought.append(fought)
	@warning_ignore("integer_division")
	state.shards += act.pay[run.content.encounters[encounter_id].tier] / 2
	state.chosen = encounter_id
	state.phase = RunState.Phase.AFTER
	state.pick = _pick_cards(0)


## Moves on from after the fight once nothing there is waiting: to the shop
## (the Pedlar; on the boss's day, the boss shop, after its relic choice), or
## on an endless floor, which has no shops, to the nodes.
func finish_day() -> String:
	if state.phase != RunState.Phase.AFTER:
		return _not_now("move on from the fight")
	if not state.pick.is_empty():
		return "choose an upgrade or take the shards first"
	if not state.relic_choice.is_empty():
		return "choose a relic or neither first"
	state.just_transformed.clear()
	state.just_apexed.clear()
	state.grew.clear()
	if state.endless:
		# No shops on endless floors (rebuild-phase8-apexes.md, Decision
		# 11): straight to the nodes; a boss floor counts the Magpie's
		# visits afresh.
		if run.day_kind(state, state.day) == "boss":
			state.magpie_visits = 0
		_to_nodes()
		return ""
	state.phase = RunState.Phase.SHOP
	open_shop("pedlar")
	return ""


## Leaves the shop for the day's nodes, or, from the boss shop, for the
## run's end.
func leave_shop() -> String:
	if state.phase != RunState.Phase.SHOP:
		return _not_now("leave the shop")
	var boss: bool = boss_shop()
	close_shop()
	if boss and not state.endless:
		_end_of_act()
		return ""
	_to_nodes()
	return ""


## The act's boss shop is left (phase 8 part 3): the apex vow opens (after
## Act 1's boss: rebuild-phase8-acts.md, Decision 2), then the next act
## starts, or, where the run may go deeper (endless after the last act, or
## the testing option after Act 1: Decision 15), the choice waits; with
## neither, the run ends won.
func _end_of_act() -> void:
	state.apex_open = true
	for hero: RunState.Hero in state.heroes:
		_open_apex(hero)
	if can_go_deeper():
		state.phase = RunState.Phase.CHOICE
	elif run.next_act(state) != null:
		_next_act()
	else:
		_end(RunState.Outcome.WON)


## Whether this act's end may lead into endless: it has endless, and it's
## not the testing option or the run is a testing one.
func can_go_deeper() -> bool:
	return not state.endless and act.endless != null and (not act.endless.testing or state.testing)


## Starts the next act at its day 1 route: its fights drawn, and what lasts
## an act (each day's node and Scout, the Magpie's visits, The Old Well's
## cut) begun afresh. Everything else carries on, the run's losses too
## (Decision 11).
func _next_act() -> void:
	var next: ActDef = run.next_act(state)
	state.act = next.act
	state.day = 1
	state.attempt = 0
	state.options = ActDraw.draw(run, state.seed_value, next)
	state.taken_nodes.clear()
	state.scouted.clear()
	state.nodes.clear()
	state.node = ""
	state.magpie_visits = 0
	for hero: RunState.Hero in state.heroes:
		hero.weakened = 0
	_start_day()


func _to_nodes() -> void:
	state.nodes = Offers.nodes(run, state)
	state.node = ""
	state.phase = RunState.Phase.NODES


## Takes the day's node `index`: Camp (a place and its options), Rift Tear
## (tomorrow's fight comes through a tear, at a depth: choose_depth), or the
## Magpie (his stall).
func choose_node(index: int) -> String:
	if state.phase != RunState.Phase.NODES:
		return _not_now("choose a node")
	if index < 0 or index >= state.nodes.size():
		return "there's no node %d" % index
	state.node = state.nodes[index]
	state.phase = RunState.Phase.NODE
	match state.node:
		"camp":
			state.camp_used = ""
			state.hunt = ""
			state.mapping = false
			var drawn: Array = Offers.camp(run, state)
			state.place = drawn[0]
			state.camp.assign(drawn[1])
		"magpie":
			state.magpie_visits += 1
			open_shop("magpie")
		"oath":
			state.oath_offer = Offers.oaths(run, state)
	state.event_done = false
	return ""


# --- events (phase 5c step 8c) ---------------------------------------------------

## The scene of the event node the day is in, or null.
func event_scene() -> EventDef.Scene:
	if state.phase != RunState.Phase.NODE or not state.node.begins_with("event:"):
		return null
	return run.events.scene(state.node.trim_prefix("event:"))


## Why the event's choice `index` can't be made with `target` (a hero id, an
## item id, or "<hero id>:<path id>" for the mirror; "" when it needs none),
## or "". A choice that needs a target, asked with none, says whether any
## target would do.
func event_problem(index: int, target: String = "") -> String:
	var scene: EventDef.Scene = event_scene()
	if scene == null:
		return _not_now("choose in an event")
	if state.event_done:
		return "the choice is made"
	if index < 0 or index >= scene.choices.size():
		return "there's no choice %d" % index
	var choice: EventDef.Choice = scene.choices[index]
	var needs: EventDef.Needs = choice.needs()
	if needs != EventDef.Needs.NOTHING and target.is_empty():
		for candidate: String in event_targets(choice):
			if _choice_problem(choice, candidate).is_empty():
				return ""
		return "no one it fits" if needs != EventDef.Needs.ITEM else "no item it fits"
	return _choice_problem(choice, target)


## Every target a choice could take (the heroes, the run's items, or each
## hero's other paths), fitting or not.
func event_targets(choice: EventDef.Choice) -> Array[String]:
	var targets: Array[String] = []
	match choice.needs():
		EventDef.Needs.HERO:
			for hero: RunState.Hero in state.heroes:
				targets.append(hero.id)
		EventDef.Needs.ITEM:
			for id: String in run.item_ids:
				if state.item_ranks.has(id):
					targets.append(id)
		EventDef.Needs.PATH:
			for hero: RunState.Hero in state.heroes:
				for path: PathDef in run.content.heroes[hero.id].paths:
					if path.id != hero.path:
						targets.append("%s:%s" % [hero.id, path.id])
	return targets


func _choice_problem(choice: EventDef.Choice, target: String) -> String:
	var shards: int = state.shards
	for result: EventDef.Result in choice.results:
		match result.kind:
			"pay":
				if shards < result.shards:
					return "it costs %d shards; there are %d" % [result.shards, shards]
				shards -= result.shards
			"item":
				if _item_pool(result.kinds).is_empty():
					return "there's no item left to find"
			"wound":
				var hero: RunState.Hero = state.hero(target)
				if hero == null:
					return "unknown hero \"%s\"" % target
				if hero.wounds >= run.content.tuning.max_wounds:
					return "%s can't take another wound" % target
			"deed":
				var hero: RunState.Hero = state.hero(target)
				if hero == null:
					return "unknown hero \"%s\"" % target
				if hero.transformed:
					return "%s has transformed" % target
			"next_fight":
				if not result.team and state.hero(target) == null:
					return "unknown hero \"%s\"" % target
			"seal":
				if run.day_kind(state, state.day + 1) != "normal":
					return "not before an elite or the boss"
			"rank_up_random":
				if _rankable().is_empty():
					return "no item of yours can go a rank up"
			"rank_up_chosen":
				if not _rankable().has(target):
					return "%s can't go a rank up" % target
			"hunt":
				if Offers.hunt(run, state).is_empty():
					return "there's nothing to drive off today"
			"mirror":
				var hero: RunState.Hero = state.hero(target.get_slice(":", 0))
				var path_id: String = target.get_slice(":", 1)
				if hero == null:
					return "unknown hero \"%s\"" % target.get_slice(":", 0)
				if hero.transformed:
					return "%s has transformed" % hero.id
				if not run.content.paths.has(path_id) or run.content.paths[path_id].hero != hero.id or path_id == hero.path:
					return "%s can't take \"%s\"" % [hero.id, path_id]
	return ""


## Makes the event's choice `index` (with `target`, as event_problem says):
## its results in order. One choice an event; leaving without one is
## walking away.
func choose_event(index: int, target: String = "") -> String:
	var problem: String = event_problem(index, target)
	if problem.is_empty() and event_scene().choices[index].needs() != EventDef.Needs.NOTHING and target.is_empty():
		problem = "choose who or what it's for"
	if not problem.is_empty():
		return problem
	var choice: EventDef.Choice = event_scene().choices[index]
	for r: int in choice.results.size():
		_event_result(choice.results[r], target, r)
	state.event_done = true
	return ""


func _event_result(result: EventDef.Result, target: String, what: int) -> void:
	match result.kind:
		"item":
			for id: String in Offers.event_picks(state, _item_pool(result.kinds), result.count, what):
				_gain_item(id, result.rank)
		"wound":
			var hero: RunState.Hero = state.hero(target)
			hero.wounds = mini(hero.wounds + 1, run.content.tuning.max_wounds)
		"clear_wounds":
			for hero: RunState.Hero in state.heroes:
				hero.wounds = 0
		"relic":
			var relic: String = Offers.event_relic(run, state, result.tier)
			if not relic.is_empty():
				_gain_relic(relic)
		"dear_shop":
			state.dear_shop_bp = result.bp
		"pay":
			state.shards -= result.shards
		"gain":
			state.shards += result.shards
		"deed":
			var hero: RunState.Hero = state.hero(target)
			var threshold: int = run.content.paths[hero.path].deed.threshold
			hero.deeds[hero.path] = mini(hero.deeds.get(hero.path, 0) + FixedMath.apply_bp(threshold, result.bp), maxi(threshold, hero.deeds.get(hero.path, 0)))
		"next_fight":
			for hero: RunState.Hero in state.heroes:
				if result.team or hero.id == target:
					hero.next_fight.append(result.mod)
		"seal":
			state.sealed = true
		"rank_up_random":
			for id: String in Offers.event_picks(state, _rankable(), 1, what):
				_gain_item(id)
		"rank_up_chosen":
			_gain_item(target)
		"weaken":
			var ids: Array[String] = []
			for hero: RunState.Hero in state.heroes:
				ids.append(hero.id)
			for id: String in Offers.event_picks(state, ids, 1, what):
				state.hero(id).weakened += 1
		"hunt":
			state.hunt = Offers.hunt(run, state)
		"mirror":
			var hero: RunState.Hero = state.hero(target.get_slice(":", 0))
			var old: PathDef = run.content.paths[hero.path]
			var new: PathDef = run.content.paths[target.get_slice(":", 1)]
			# Half its share of the old path's threshold, as a share of the new one's.
			@warning_ignore("integer_division")
			var carried: int = hero.deeds.get(old.id, 0) * new.deed.threshold / maxi(old.deed.threshold, 1) / 2
			hero.deeds[new.id] = hero.deeds.get(new.id, 0) + carried
			hero.path = new.id


## The items an event may give of `kinds`: not held at rank III.
func _item_pool(kinds: Array[String]) -> Array[String]:
	var pool: Array[String] = []
	for id: String in run.item_ids:
		if kinds.has(ItemDef.KIND_NAMES[run.items[id].kind]) and state.item_ranks.get(id, 0) < ItemDef.RANKS:
			pool.append(id)
	return pool


## The run's items below rank III.
func _rankable() -> Array[String]:
	var found: Array[String] = []
	for id: String in run.item_ids:
		if state.item_ranks.has(id) and state.item_ranks[id] < ItemDef.RANKS:
			found.append(id)
	return found


## Takes the Bloodied Oath's oath `index` (phase 5c step 8c): its hero bears
## it for its next oath_fights day fights. Passing is leaving the node.
func take_oath(index: int) -> String:
	if state.phase != RunState.Phase.NODE or state.node != "oath":
		return _not_now("take an oath")
	if state.event_done:
		return "an oath is taken"
	if index < 0 or index >= state.oath_offer.size():
		return "there's no oath %d" % index
	var hero: RunState.Hero = state.hero(state.oath_offer[index].get_slice(":", 1))
	if not hero.oath.is_empty():
		return "%s is already sworn" % hero.id
	hero.oath = state.oath_offer[index].get_slice(":", 0)
	hero.oath_fights = run.events.oath_fights
	state.event_done = true
	return ""


## The oath `hero` bears, or null.
func oath_of(hero: RunState.Hero) -> EventDef.Oath:
	return run.events.oath(hero.oath) if not hero.oath.is_empty() else null


## The heroes' front row (the Oath of the Vanguard's).
func front_row() -> int:
	var grid: HexGrid = run.content.tuning.make_grid()
	var front: int = 0
	for row: int in grid.height:
		if grid.zone(row) == HexGrid.Zone.HEROES:
			front = maxi(front, row)
	return front


## A Rift Tear's depth `index` (phase 5c step 8b): tomorrow's enemies take
## rift_tear_mod and the depth's share of the day's rift modifiers
## (Offers.rift_modifiers), and winning that fight offers its relics.
func choose_depth(index: int) -> String:
	if state.phase != RunState.Phase.NODE or state.node != "rift_tear":
		return _not_now("choose a depth")
	if not state.rift_depth.is_empty():
		return "the depth is chosen (%s)" % state.rift_depth
	if index < 0 or index >= run.camps.depths.size():
		return "there's no depth %d" % index
	var depth: CampsDef.Depth = run.camps.depths[index]
	state.rift_depth = depth.id
	state.rift_mods.assign(Offers.rift_modifiers(run, state).slice(0, depth.modifiers))
	return ""


## Leaves the node, once nothing there is waiting, for the next day.
func leave_node() -> String:
	if state.phase != RunState.Phase.NODE:
		return _not_now("leave the node")
	var waiting: String = _node_waiting()
	if not waiting.is_empty():
		return waiting
	close_shop()
	state.shrine = ""
	state.event_done = false
	state.oath_offer.clear()
	while state.taken_nodes.size() < state.day - 1:
		state.taken_nodes.append("")
	state.taken_nodes.append("camp:" + state.place if state.node == "camp" else state.node)
	state.node = ""
	state.nodes.clear()
	state.place = ""
	state.camp.clear()
	state.camp_used = ""
	state.day += 1
	state.attempt = 0
	_start_day()
	return ""


## Takes camp option `index` (in a Camp node). What it does is its one job:
## train (a pick), hunt (a pack to fight now), rest (clears wounds), scout
## (the next 2 days), map_the_rift (then swap_fight), fortify, dig_in (then
## place_rock), shrine (an offering for a relic: shrine_offer); scout,
## map_the_rift, fortify, and dig_in are for tomorrow's fight.
func choose_camp(index: int) -> String:
	if state.phase != RunState.Phase.NODE or state.node != "camp":
		return _not_now("choose a camp option")
	if not state.camp_used.is_empty():
		return "camp's option is already taken today (%s)" % state.camp_used
	if index < 0 or index >= state.camp.size():
		return "there's no camp option %d" % index
	var option: String = state.camp[index]
	match option:
		"train":
			state.pick = _pick_cards(1)
		"hunt":
			state.hunt = Offers.hunt(run, state)
			if state.hunt.is_empty():
				return "there's no pack to hunt today"
		"rest":
			for hero: RunState.Hero in state.heroes:
				hero.wounds = 0
			state.rested = true
		"scout":
			for day: int in [state.day + 1, state.day + 2]:
				if not run.day_kind(state, day).is_empty() and not state.scouted.has(day):
					state.scouted.append(day)
		"map_the_rift":
			if ["", "boss"].has(run.day_kind(state, state.day + 1)):
				return "there's no fight tomorrow to swap"
			state.mapping = true
		"fortify":
			state.fortify = true
		"dig_in":
			state.dig_in = true
		"shrine":
			state.shrine = "open"
	state.camp_used = option
	return ""


## Map the Rift: swaps tomorrow's fight `index` for another of its tier.
func swap_fight(index: int) -> String:
	if not state.mapping:
		return "Map the Rift isn't waiting"
	var tomorrow: Array = state.options[state.day]
	if index < 0 or index >= tomorrow.size():
		return "there's no fight %d tomorrow" % index
	var swapped: String = Offers.swap(run, state, index)
	if swapped.is_empty():
		return "there's no other fight to swap in"
	tomorrow[index] = swapped
	state.mapping = false
	return ""


## Dig In: the rock's hex for the next fight, in the heroes' zone; once the
## fight is chosen, not on its water or void (a rock placed there before can
## be placed again).
func place_rock(hex: Vector2i) -> String:
	if not state.dig_in:
		return "Dig In wasn't taken"
	if state.phase == RunState.Phase.ENDED:
		return _not_now("place a rock")
	var grid: HexGrid = run.content.tuning.make_grid()
	if not grid.has(hex.x, hex.y) or grid.zone(hex.y) != HexGrid.Zone.HEROES:
		return "a rock goes on a hex in your zone"
	if not state.chosen.is_empty() and rock_on_ground(state.chosen, hex) != "":
		return "a rock can't go on %s" % rock_on_ground(state.chosen, hex)
	state.rock.assign([hex.x, hex.y])
	return ""


## "water" or "the void" if `hex` is that in `encounter_id`, else "".
func rock_on_ground(encounter_id: String, hex: Vector2i) -> String:
	var encounter: EncounterDef = run.content.encounters[encounter_id]
	if encounter.water.has(hex):
		return "water"
	if encounter.void_hexes.has(hex):
		return "the void"
	return ""


func _node_waiting() -> String:
	if state.node == "rift_tear" and state.rift_depth.is_empty():
		return "choose a depth first"
	if not state.pick.is_empty():
		return "choose an upgrade or take the shards first"
	if not state.relic_choice.is_empty():
		return "choose a relic or neither first"
	if not state.hunt.is_empty():
		return "fight the Hunt first"
	if state.mapping:
		return "choose which fight to swap first"
	return ""


# --- the day ---------------------------------------------------------------------

## Chooses today's fight: `index` into today's options.
func choose_fight(index: int) -> String:
	if state.phase != RunState.Phase.ROUTE:
		return _not_now("choose a fight")
	var options: Array[String] = state.today()
	if index < 0 or index >= options.size():
		return "there's no fight %d today" % index
	state.chosen = options[index]
	state.phase = RunState.Phase.LOADOUT
	return ""


## The fight waiting now: a Hunt's pack at camp, or the day's chosen fight
## at the loadout ("" if neither).
func fight_encounter() -> String:
	if state.phase == RunState.Phase.NODE and not state.hunt.is_empty():
		return state.hunt
	if state.phase == RunState.Phase.LOADOUT:
		return state.chosen
	return ""


## The waiting fight from `formation` (hero id -> hex), with every hero as the
## run has it, or null with the reasons in `errors`. A hero's kit is its
## path's at its stage, then its upgrades, its loadout (slot order), the
## relics, the day's camp modifiers (Fortify, a steadying Rest), and its duo
## bonds. Enemies take the relics' enemy mods and a Rift Tear's; Dig In's
## rock joins the encounter's. A Hunt takes no camp modifiers. `snares`:
## hero id -> the hexes of the snares it places (a transformed Trapper), or
## of its lantern (First Lantern, phase 5c step 7d).
func fight_setup(formation: Dictionary[String, Vector2i], errors: Array[String], snares: Dictionary[String, Array] = {}) -> FightSetup:
	var encounter_id: String = fight_encounter()
	if encounter_id.is_empty():
		errors.append(_not_now("fight"))
		return null
	var hunting: bool = encounter_id == state.hunt
	var content: ContentDb = run.content
	var vows: Dictionary[String, String] = {}
	var transformed: Array[String] = []
	var apex_vows: Dictionary[String, String] = {}
	var apexed: Array[String] = []
	var extras: Dictionary[String, HeroExtras] = {}
	var tactics: Dictionary[String, String] = {}
	var ranked_tactics: Dictionary[String, TacticDef] = {}
	var wound_bp: int = content.tuning.wound_bp
	# Stand Together (phase 5c step 6d): the hero sharing its holder's hex
	# gets its gambit's mod too.
	var shared_mods: Dictionary[String, KitMod] = {}
	# Only the run's team fights (phase 8 part 4).
	var outsiders: Array[String] = []
	for hero_id: String in formation:
		if state.hero(hero_id) == null:
			outsiders.append(hero_id)
	if not outsiders.is_empty():
		for hero_id: String in outsiders:
			errors.append("%s isn't on the team" % hero_id)
		return null
	for hero: RunState.Hero in state.heroes:
		var gambit: KitMod = run.loadout_gambit(hero, state)
		if gambit == null or gambit.place_rule != "share" or not formation.has(hero.id):
			continue
		for other: RunState.Hero in state.heroes:
			if other != hero and formation.has(other.id) and formation[other.id] == formation[hero.id]:
				shared_mods[other.id] = gambit
	for hero: RunState.Hero in state.heroes:
		if not formation.has(hero.id):
			continue
		vows[hero.id] = hero.path
		if hero.transformed:
			transformed.append(hero.id)
		if not hero.apex.is_empty():
			apex_vows[hero.id] = hero.apex
			if hero.apex_earned:
				apexed.append(hero.id)
		var mods: Array[KitMod] = run.upgrade_mods(hero)
		mods.append_array(run.loadout_mods(state, hero))
		mods.append_array(run.relic_mods(state, run.hero_kit(hero)))
		if shared_mods.has(hero.id):
			mods.append(shared_mods[hero.id])
		if not hunting and state.fortify:
			mods.append(run.camps.fortify_mod)
		if not hunting:
			for modifier: CampsDef.Modifier in _rift_modifiers():
				if modifier.hero_mod != null:
					mods.append(modifier.hero_mod)
		var covenant: KitMod = _covenant_mod(hero, formation)
		if covenant != null:
			mods.append(covenant)
		# Events (phase 5c step 8c), last, since dropping the signature must
		# come after any mod that changes it.
		var oath: EventDef.Oath = oath_of(hero) if not hunting else null
		if not hunting:
			for key: String in hero.next_fight:
				mods.append(run.events.next_fight_mods[key])
		for i: int in hero.weakened:
			mods.append(_weaken_mod())
		if oath != null and oath.mod != null:
			mods.append(oath.mod)
		if oath != null and oath.front_row and formation[hero.id].y != front_row():
			errors.append("%s is sworn to the front row (%s)" % [hero.id, oath.name])
		extras[hero.id] = HeroExtras.make(mods, hero.wounds, wound_bp)
		var tallies: Array = run.growth_tallies(state, hero)
		extras[hero.id].tally_keys.assign(tallies[0])
		extras[hero.id].tally_counts.assign(tallies[1])
		var tactic: TacticDef = run.loadout_tactic(hero, state)
		if oath != null and oath.no_tactic:
			tactic = null
		if tactic != null:
			tactics[hero.id] = tactic.id
			ranked_tactics[hero.id] = tactic
	var setup: FightSetup = Encounters.setup(content, encounter_id, formation, fight_seed(), errors, tactics, vows, transformed, extras, apex_vows, apexed, {} as Dictionary[int, String] if hunting else chosen_specs(),
		{} as Dictionary[int, PackedStringArray] if hunting else chosen_upgrades())
	if setup != null:
		for hero: UnitSetup in setup.heroes:
			if hero.def.placed_lantern and not snares.get(hero.id, []).is_empty():
				# First Lantern (phase 5c step 7d): its one marker.
				hero.lantern = snares[hero.id][0]
			elif hero.def.placed_snares > 0 and snares.has(hero.id):
				hero.snares.assign(snares[hero.id])
			# A tactic at its item's rank (phase 5c step 6c).
			if ranked_tactics.has(hero.id):
				hero.tactic = ranked_tactics[hero.id]
			# One its kit can't follow now (a signature dropped by an event or
			# an oath, phase 5c step 8c) does nothing, as an item can.
			if hero.tactic != null and not Tactics.can_follow(hero.tactic, hero.def):
				hero.tactic = null
			# Switch Places at the moment the player chose (phase 5c step 6d).
			var chosen: int = state.hero(hero.id).gambit_at if state.hero(hero.id) != null else 0
			if chosen > 0 and hero.def.swap_choice:
				hero.swap_at = chosen * FixedMath.TICKS_PER_SECOND
		if not hunting and (not state.rift_depth.is_empty() or not state.endless_mods.is_empty()):
			_rift_rules(setup, encounter_id)
		if not hunting:
			_endless_rules(setup)
		_modify_enemies(setup, hunting, errors)
		_relic_rules(setup)
		if not hunting and state.dig_in and state.rock.size() == 2:
			setup.rocks.append(Vector2i(state.rock[0], state.rock[1]))
		errors.append_array(setup.validate(content))
		for hero: RunState.Hero in state.heroes:
			if not formation.has(hero.id):
				errors.append("%s isn't placed" % hero.id)
	return setup if errors.is_empty() else null


## The relics' effects at the fight's start and Salt Circle (phase 5c step
## 5b), for the sim to run.
func _relic_rules(setup: FightSetup) -> void:
	for start: Array in run.relic_starts(state):
		var relic: RelicDef = start[0]
		setup.relic_effects.append(start[1])
		setup.relic_sources.append(EffectSource.relic(relic.id, relic.name, EffectSource.Team.HEROES))
		setup.relic_scales.append(start[2])
	for id: String in state.relics:
		if run.relics.has(id) and run.relics[id].salt_circle:
			setup.salt_circles += 2 if run.counts_twice(state, run.relics[id]) else 1
	setup.hero_rules = run.hero_rules(state)


## The Hollow Covenant (phase 5c step 5a): what `hero` needs added to reach
## the team's highest HP, ATK, MGK, DEF, CRIT, and attack speed (among the
## heroes placed), worked out from each kit as it stands between fights.
## Null without the relic, or with nothing to add.
func _covenant_mod(hero: RunState.Hero, formation: Dictionary[String, Vector2i]) -> KitMod:
	if not run.relic_rule(state, "covenant"):
		return null
	var mine: UnitStats = _kit_without_covenant(hero.id).stats
	var mod: KitMod = KitMod.make()
	for other: RunState.Hero in state.heroes:
		if not formation.has(other.id) or other == hero:
			continue
		var theirs: UnitStats = _kit_without_covenant(other.id).stats
		for stat: UnitStats.Stat in COVENANT_STATS:
			mod.stats_add[stat] = maxi(mod.stats_add[stat], theirs.get_stat(stat) - mine.get_stat(stat))
	return mod if mod.changes_anything() else null


const COVENANT_STATS: Array[UnitStats.Stat] = [UnitStats.Stat.HP, UnitStats.Stat.ATK, UnitStats.Stat.MGK, UnitStats.Stat.DEF, UnitStats.Stat.CRIT, UnitStats.Stat.ATSP]


func _kit_without_covenant(hero_id: String) -> UnitDef:
	return kit_of(hero_id, false)


## The kit `hero_id` fights with as things stand between fights: its path's
## at its stage, then its upgrades, loadout, relics, and bonds (camp's
## modifiers for the next fight aside). For showing, not for fights.
func kit_of(hero_id: String, with_covenant: bool = true) -> UnitDef:
	var hero: RunState.Hero = state.hero(hero_id)
	var kit: UnitDef = run.hero_kit(hero)
	var mods: Array[KitMod] = run.upgrade_mods(hero)
	mods.append_array(run.loadout_mods(state, hero))
	mods.append_array(run.relic_mods(state, kit))
	if with_covenant:
		var formation: Dictionary[String, Vector2i] = {}
		for other: RunState.Hero in state.heroes:
			formation[other.id] = Vector2i.ZERO
		var covenant: KitMod = _covenant_mod(hero, formation)
		if covenant != null:
			mods.append(covenant)
	for mod: KitMod in mods:
		kit = mod.apply(kit)
	return kit


## Every enemy and summon kit takes the relics' enemy mods, and a Rift
## Tear's upgrade (not on a Hunt).
func _modify_enemies(setup: FightSetup, hunting: bool, errors: Array[String]) -> void:
	var mods: Array[KitMod] = []
	for id: String in state.relics:
		if run.relics[id].enemy_mod != null:
			mods.append(run.relics[id].enemy_mod)
	if not hunting:
		if not state.rift_depth.is_empty():
			mods.append(run.camps.rift_tear_mod)
		for modifier: CampsDef.Modifier in _rift_modifiers():
			if modifier.mod != null:
				mods.append(modifier.mod)
		var growth: KitMod = _floor_growth_mod()
		if growth != null:
			mods.append(growth)
	if mods.is_empty():
		return
	var problems: Array[String] = []
	for enemy: UnitSetup in setup.enemies:
		for mod: KitMod in mods:
			enemy.def = mod.apply(enemy.def, problems)
	for i: int in setup.summon_kits.size():
		for mod: KitMod in mods:
			setup.summon_kits[i] = mod.apply(setup.summon_kits[i], problems)
	for problem: String in problems:
		errors.append("an enemy upgrade leaves a kit unsound: %s" % problem)


## The Old Well's cut (phase 5c step 8c): max HP times the weaken result's
## bp, once for each drink this act.
func _weaken_mod() -> KitMod:
	var mod: KitMod = KitMod.make()
	mod.stats_bp[UnitStats.Stat.HP] = run.events.weaken_bp()
	return mod


## The rift modifiers on the next day fight (phase 5c step 8b).
func _rift_modifiers() -> Array[CampsDef.Modifier]:
	var found: Array[CampsDef.Modifier] = []
	for id: String in state.endless_mods + state.rift_mods:
		if run.camps.modifiers.has(id) and not found.has(run.camps.modifiers[id]):
			found.append(run.camps.modifiers[id])
	return found


## A Rift Tear's rules for the sim (phase 5c step 8b): Early Collapse's
## start, and Reinforcements: that many of the encounter's first enemy that
## isn't its elite or boss (the first listed, or the second in an elite or
## boss fight), summoned from the edge as the rift's own effect, its kit
## added to the summon kits (scaled like the encounter's, and modified with
## them).
func _rift_rules(setup: FightSetup, encounter_id: String) -> void:
	var encounter: EncounterDef = run.content.encounters[encounter_id]
	for modifier: CampsDef.Modifier in _rift_modifiers():
		if modifier.collapse_from_ticks > 0:
			setup.collapse_start_ticks = modifier.collapse_from_ticks if setup.collapse_start_ticks == 0 else mini(setup.collapse_start_ticks, modifier.collapse_from_ticks)
		if modifier.reinforce_count <= 0:
			continue
		var first: int = 1 if encounter.tier == "elite" or encounter.tier == "boss" else 0
		if first >= encounter.enemies.size():
			continue
		var kind: String = encounter.enemies[first].enemy
		if setup.summon_kit(kind) == null:
			setup.summon_kits.append(Encounters.scaled(run.content.enemies[kind].kit, encounter.scale_bp))
		var errors: Array[String] = []
		var effect: EffectDef = EffectDef.read(DataReader.new({"type": "summon", "kit": kind, "count": modifier.reinforce_count, "placement": "edges"}, "reinforcements", errors))
		setup.rift_effects.append(effect)
		setup.rift_sources.append(EffectSource.rift_effect(modifier.id, modifier.name))
		setup.rift_ticks.append(modifier.reinforce_ticks)


## The seed of the waiting fight (this attempt's; a Hunt has its own).
func fight_seed() -> int:
	var what: int = RunRandom.HUNT if fight_encounter() == state.hunt and not state.hunt.is_empty() else RunRandom.FIGHT
	return RunRandom.stream(state.seed_value, [what, state.act, state.day, state.attempt]).range_int(1 << 30) + 1


## Fights the waiting fight from `formation` and records it. Returns the
## result, or null with the reasons in `errors`.
func fight(formation: Dictionary[String, Vector2i], errors: Array[String], snares: Dictionary[String, Array] = {}) -> FightResult:
	var setup: FightSetup = fight_setup(formation, errors, snares)
	if setup == null:
		return null
	var result: FightResult = CombatSim.run(setup, run.content)
	last_setup = setup
	last_result = result
	record(formation, result)
	return result


## Records a fought fight: the formation, deeds, wounds (a win heals one
## on each hero first, then each hero who fell takes one), transformations
## (and bonds found), then the outcome. A Hunt pays its shards on a win and
## is done, won or lost (its loss isn't a loss). The day's fight: a win pays
## by its tier (plus relics), offers the pick, and (an elite, or a Rift
## Tear) a relic choice; a loss replays the day, or ends the run. Either way
## the day's camp modifiers are spent. fight() calls it; tests call it with
## a result of their own.
func record(formation: Dictionary[String, Vector2i], result: FightResult) -> void:
	var hunting: bool = fight_encounter() == state.hunt and not state.hunt.is_empty()
	var encounter_id: String = state.hunt if hunting else state.chosen
	var won: bool = result.outcome != FightResult.Outcome.DEFEAT
	state.formation = formation.duplicate()
	state.just_transformed.clear()
	state.just_apexed.clear()
	var fought := RunState.Fought.new()
	fought.act = state.act
	fought.day = state.day
	fought.attempt = state.attempt
	fought.encounter = encounter_id
	fought.outcome = result.outcome
	@warning_ignore("integer_division")
	fought.seconds = result.end_tick / FixedMath.TICKS_PER_SECOND
	fought.habits = RiftLearns.summary(run, state, formation, result)
	state.fought.append(fought)
	for hero: RunState.Hero in state.heroes:
		# An oath doubles what the fight puts into its hero's deeds (step 8c).
		var oath: EventDef.Oath = oath_of(hero) if not hunting else null
		for path_id: String in hero.deeds:
			var amount: int = result.deed_amount(hero.id, path_id)
			hero.deeds[path_id] += FixedMath.apply_bp(amount, oath.deed_bp) if oath != null else amount
	_grow(result)
	_rank_items(formation, result, won)
	if won:
		for hero: RunState.Hero in state.heroes:
			hero.wounds = maxi(hero.wounds - 1, 0)
	# A wound for each hero down at the fight's end (Decision 23: one Second
	# Dawn raised, standing at the end, takes none).
	for hero_id: String in result.down_at_end():
		var fallen: RunState.Hero = state.hero(hero_id)
		if fallen != null:
			var oath: EventDef.Oath = oath_of(fallen) if not hunting else null
			fallen.wounds = mini(fallen.wounds + (oath.fall_wounds if oath != null else 1), run.content.tuning.max_wounds)
	for hero: RunState.Hero in state.heroes:
		if not hero.transformed and hero.deeds.get(hero.path, 0) >= run.content.paths[hero.path].deed.threshold:
			hero.transformed = true
			state.just_transformed.append(hero.id)
			_open_apex(hero)
		elif not hero.apex.is_empty() and not hero.apex_earned and hero.deeds.get(hero.apex, 0) >= run.content.apexes[hero.apex].deed.threshold:
			hero.apex_earned = true
			state.just_apexed.append(hero.id)
	for bond: BondDef in run.active_bonds(state):
		if not state.bonds_found.has(bond.id):
			state.bonds_found.append(bond.id)
	if hunting:
		state.hunt = ""
		if won:
			state.shards += act.pay["hunt"]
		return
	# An oath lasts its hero's next day fights, won or lost.
	for hero: RunState.Hero in state.heroes:
		if not hero.oath.is_empty():
			hero.oath_fights -= 1
			if hero.oath_fights <= 0:
				hero.oath = ""
				hero.oath_fights = 0
	if not won:
		# What the last node set up for this fight holds for its replay
		# (Decision 42).
		state.streak = 0
		state.losses += 1
		state.chosen = ""
		# Endless (phase 8 part 1): the first loss ends the run; the act was won.
		if state.endless:
			_end(RunState.Outcome.WON)
		elif state.losses >= act.losses_to_end:
			_end(RunState.Outcome.LOST)
		else:
			state.attempt += 1
			_start_day()
		return
	var depth: CampsDef.Depth = run.camps.depth(state.rift_depth)
	state.fortify = false
	state.dig_in = false
	state.rock.clear()
	state.rift_depth = ""
	state.rift_mods.clear()
	for hero: RunState.Hero in state.heroes:
		hero.next_fight.clear()
	state.rested = false
	var tier: String = run.content.encounters[state.chosen].tier
	state.shards += act.pay[tier] + run.relic_sum(state, "pay_add") + (run.relic_sum(state, "elite_pay_add") if tier == "elite" else 0)
	_streak(result)
	if tier == "elite":
		_grow_by_run("elite_wins")
	state.phase = RunState.Phase.AFTER
	state.relic_choice_price = 0
	if run.day_kind(state, state.day) == "boss":
		# The boss relic choice (Decision 18), then the boss shop (finish_day;
		# Decision 48), then the run's end or the endless choice (leave_shop).
		# Once every boss relic is held, legendaries (endless.md).
		var boss_tier: String = "boss" if _boss_relic_left() else "legendary"
		state.relic_choice = Offers.relics(run, state, RELIC_AFTER_FIGHT, act.boss_relics, boss_tier)
		return
	state.pick = _pick_cards(0)
	if tier == "elite":
		state.relic_choice = Offers.relics(run, state, RELIC_AFTER_FIGHT, 2, "rare", act.elite_epic_pct)
	elif depth != null:
		state.relic_choice = Offers.relics_of_tiers(run, state, RELIC_AFTER_FIGHT, depth.relics)


## Bounty Board (phase 5c step 5a): a won day fight with no hero falling adds
## to the streak, anything else ends it; a streak relic pays once.
func _streak(result: FightResult) -> void:
	var fell: bool = result.combat_log.entries.any(func(entry: LogEntry) -> bool: return entry.kind == LogEntry.Kind.DEATH and state.hero(entry.target) != null)
	state.streak = 0 if fell else state.streak + 1
	for id: String in state.relics:
		var relic: RelicDef = run.relics.get(id)
		if relic != null and relic.streak_wins > 0 and state.streak >= relic.streak_wins and not state.streaks_paid.has(id):
			state.shards += relic.streak_shards
			state.streaks_paid.append(id)


## Adds one to every held relic that grows with what the run counts as
## `what` (Tally of the Dead: "elite_wins").
func _grow_by_run(what: String) -> void:
	for id: String in state.relics:
		var relic: RelicDef = run.relics.get(id)
		if relic == null or relic.grows == null or relic.grows.run_counts != what:
			continue
		var before: int = state.growth.get(id, 0)
		state.growth[id] = before + 1
		if relic.grows.steps(state.growth[id]) > relic.grows.steps(before) and not state.grew.has(":" + id):
			state.grew.append(":" + id)


## A pick's cards at `visit` (Widened Offering adds some), and how many of
## them to take (The Hollow Throne: 2).
func _pick_cards(visit: int) -> Array[String]:
	state.picks_left = 1 + run.relic_sum(state, "take_picks_add")
	return Offers.pick(run, state, visit, run.relic_sum(state, "pick_cards_add"))


# --- relics -----------------------------------------------------------------------

## Takes relic `index` of the waiting choice: it's the run's for good.
func take_relic(index: int) -> String:
	if state.relic_choice.is_empty():
		return "there's no relic choice waiting"
	if index < 0 or index >= state.relic_choice.size():
		return "there's no relic %d" % index
	if state.shards < state.relic_choice_price:
		return "it costs %d shards; there are %d" % [state.relic_choice_price, state.shards]
	state.shards -= state.relic_choice_price
	# The Shrine's offering is spent only now (phase 5c step 8b).
	if state.shrine.begins_with("wound:"):
		var hero: RunState.Hero = state.hero(state.shrine.trim_prefix("wound:"))
		hero.wounds = mini(hero.wounds + 1, run.content.tuning.max_wounds)
	elif state.shrine.begins_with("relic:"):
		_lose_relic(state.shrine.trim_prefix("relic:"))
	_gain_relic(state.relic_choice[index])
	state.relic_choice.clear()
	state.relic_choice_price = 0
	if not state.shrine.is_empty() and state.shrine != "open":
		state.shrine = ""
	return ""


## Turns down the waiting relic choice.
func decline_relic() -> String:
	if state.relic_choice.is_empty():
		return "there's no relic choice waiting"
	state.relic_choice.clear()
	state.relic_choice_price = 0
	if not state.shrine.is_empty() and state.shrine != "open":
		state.shrine = ""
	return ""


## The Shrine's offering (phase 5c step 8b): "shards" (the act's
## shrine_price) or "wound" (on hero `what`, not one at the most wounds)
## for a rare relic; "relic" (relic `what`, not a boss, bond, or legendary
## one) for a relic a tier higher. It draws the relic now; the offering is
## spent only if it's taken (take_relic), and either way the Shrine is done.
func shrine_offer(kind: String, what: String = "") -> String:
	if state.shrine != "open":
		return "the Shrine isn't waiting for an offering"
	var tier: String = "rare"
	match kind:
		"shards":
			if state.shards < act.shrine_price:
				return "it asks %d shards; there are %d" % [act.shrine_price, state.shards]
		"wound":
			var hero: RunState.Hero = state.hero(what)
			if hero == null:
				return "unknown hero \"%s\"" % what
			if hero.wounds >= run.content.tuning.max_wounds:
				return "%s can't take another wound" % what
		"relic":
			if not state.relics.has(what):
				return "the run doesn't hold \"%s\"" % what
			tier = shrine_tier(what)
			if tier.is_empty():
				return "the Shrine has nothing higher for %s" % what
		_:
			return "there's no offering \"%s\"" % kind
	var drawn: Array[String] = Offers.relics_of_tiers(run, state, RELIC_SHRINE, [tier] as Array[String])
	if drawn.is_empty():
		return "the Shrine has no relic left to give"
	state.relic_choice = drawn
	state.relic_choice_price = act.shrine_price if kind == "shards" else 0
	state.shrine = kind if kind == "shards" else "%s:%s" % [kind, what]
	return ""


## The tier the Shrine gives for relic `relic_id` ("": none; a boss, bond,
## or legendary relic has nothing above it to give).
func shrine_tier(relic_id: String) -> String:
	var tier: RelicDef.Tier = run.relics[relic_id].tier
	if tier >= RelicDef.Tier.LEGENDARY:
		return ""
	return RelicDef.TIER_NAMES[tier + 1]


## Buys the open shop's relic `index`.
func buy_relic(index: int = 0) -> String:
	if state.shop.is_empty() or index < 0 or index >= state.shop_relics.size() or state.shop_relics[index].is_empty():
		return "there's no relic for sale"
	var price: int = relic_price(index)
	if state.shards < price:
		return "it costs %d shards; there are %d" % [price, state.shards]
	state.shards -= price
	_gain_relic(state.shop_relics[index])
	state.shop_relics[index] = ""
	return ""


## What the open shop's relic `index` costs: its tier's price (the Magpie's
## at his discount, rounded down), with the Pedlar's price_add.
func relic_price(index: int = 0) -> int:
	if index < 0 or index >= state.shop_relics.size() or state.shop_relics[index].is_empty():
		return 0
	var price: int = act.relic_prices[RelicDef.TIER_NAMES[run.relics[state.shop_relics[index]].tier]]
	if state.shop == "magpie":
		@warning_ignore("integer_division")
		return price * act.magpie_relic_pct / 100
	# A bond relic is free (phase 5c step 5d), whatever the prices.
	return 0 if price == 0 else _marked_up(price)


## What the Magpie pays for `relic_id` (its tier's relic_sell).
func relic_sell_price(relic_id: String) -> int:
	return act.relic_sell.get(RelicDef.TIER_NAMES[run.relics[relic_id].tier], 0)


## Sells a relic the run holds to the Magpie, the only one who buys them
## (phase 5c step 6e, magpie.md). What it counted is lost with it.
func sell_relic(relic_id: String) -> String:
	if state.shop != "magpie":
		return "only the Magpie buys relics"
	if not state.relics.has(relic_id):
		return "the run doesn't hold \"%s\"" % relic_id
	_lose_relic(relic_id)
	state.shards += relic_sell_price(relic_id)
	return ""


## The Magpie's swap, once a visit: `relic_id` for a relic of its tier the
## run doesn't hold, free.
func swap_relic(relic_id: String) -> String:
	if state.shop != "magpie":
		return "only the Magpie swaps relics"
	if state.magpie_swapped:
		return "he swaps once a visit"
	if not state.relics.has(relic_id):
		return "the run doesn't hold \"%s\"" % relic_id
	var other: String = Offers.magpie_swap(run, state, relic_id)
	if other.is_empty():
		return "he has nothing to swap for %s" % run.relics[relic_id].name
	_lose_relic(relic_id)
	_gain_relic(other)
	state.magpie_swapped = true
	return ""


## The run lets go of a relic: its growth goes, and a loadout slot it gave
## goes from each hero (what was in it back to the stash).
func _lose_relic(relic_id: String) -> void:
	state.relics.erase(relic_id)
	state.growth.erase(relic_id)
	for i: int in run.relics[relic_id].slots_add:
		for hero: RunState.Hero in state.heroes:
			var last: String = hero.slots.pop_back()
			if not last.is_empty():
				state.stash.append(last)


func _gain_relic(relic_id: String) -> void:
	state.relics.append(relic_id)
	if run.relics[relic_id].grows != null:
		state.growth[relic_id] = 0
	for i: int in run.relics[relic_id].slots_add:
		for hero: RunState.Hero in state.heroes:
			hero.slots.append("")


## Adds what a fight counted to the growing cards (phase 5c step 4; won or
## lost, a Hunt too), and notes the ones that stepped up (`grew`).
func _grow(result: FightResult) -> void:
	state.grew.clear()
	for hero: RunState.Hero in state.heroes:
		for upgrade: UpgradeDef in run.held_upgrades(hero):
			if upgrade.grows == null:
				continue
			var before: int = hero.growth.get(upgrade.id, 0)
			hero.growth[upgrade.id] = upgrade.grows.grown(before, _faster(result.tally_amount(hero.id, "upgrade:" + upgrade.id)))
			if upgrade.grows.steps(hero.growth[upgrade.id]) > upgrade.grows.steps(before):
				state.grew.append("%s:%s" % [hero.id, upgrade.id])
	for id: String in state.relics:
		var relic: RelicDef = run.relics.get(id)
		if relic == null or relic.grows == null or not relic.grows.counted_in_fights():
			continue
		var before: int = state.growth.get(id, 0)
		var counted: int = 0
		for hero: RunState.Hero in state.heroes:
			counted += result.tally_amount(hero.id, "relic:" + id)
		state.growth[id] = relic.grows.grown(before, _faster(counted))
		var stepped: int = relic.grows.steps(state.growth[id]) - relic.grows.steps(before)
		if stepped > 0:
			state.grew.append(":" + id)
			state.shards += stepped * relic.grows.each_shards


## The loadout's ranks (phase 5c step 6): each item equipped on a hero who
## fought counts toward its next rank by its kind (ActDef.item_ranks):
## charms won fights, gambits fights, tactics the ms its hero stood, sigils
## its signature's casts (the last two from the fight's tallies). Reaching
## the need ranks it up; the count goes on from what's left over.
func _rank_items(formation: Dictionary[String, Vector2i], result: FightResult, won: bool) -> void:
	state.ranked.clear()
	for hero: RunState.Hero in state.heroes:
		if not formation.has(hero.id):
			continue
		for item_id: String in hero.slots:
			var item: ItemDef = run.items.get(item_id)
			if item == null or state.item_ranks.get(item_id, 1) >= ItemDef.RANKS:
				continue
			var counted: int = 0
			match item.kind:
				ItemDef.Kind.CHARM:
					counted = 1 if won else 0
				ItemDef.Kind.GAMBIT:
					counted = 1
				_:
					counted = result.tally_amount(hero.id, "item:" + item_id)
			if counted > 0:
				_count_item(item, counted)


func _count_item(item: ItemDef, counted: int) -> void:
	var needs: Array = act.item_ranks[ItemDef.KIND_NAMES[item.kind]]
	state.item_counts[item.id] = state.item_counts.get(item.id, 0) + counted
	while state.item_ranks.get(item.id, 1) < ItemDef.RANKS and state.item_counts[item.id] >= int(needs[state.item_ranks.get(item.id, 1) - 1]):
		state.item_counts[item.id] -= int(needs[state.item_ranks[item.id] - 1])
		state.item_ranks[item.id] += 1
		if not state.ranked.has(item.id):
			state.ranked.append(item.id)
	if state.item_ranks[item.id] >= ItemDef.RANKS:
		state.item_counts[item.id] = 0


## What `item_id` has counted toward its next rank, and what that rank needs
## (0 at rank III).
func rank_progress(item_id: String) -> Vector2i:
	var rank: int = state.item_ranks.get(item_id, 1)
	if rank >= ItemDef.RANKS or not run.items.has(item_id):
		return Vector2i(0, 0)
	var needs: Array = act.item_ranks[ItemDef.KIND_NAMES[run.items[item_id].kind]]
	return Vector2i(state.item_counts.get(item_id, 0), int(needs[rank - 1]))


## What's counted, made faster by Rift-Bound Heart's growth_bp while held.
func _faster(counted: int) -> int:
	for id: String in state.relics:
		if run.relics.has(id) and run.relics[id].growth_bp > 0:
			counted = FixedMath.apply_bp(counted, run.relics[id].growth_bp)
	return counted


## Takes card `index` of the waiting pick: the upgrade is its hero's for good
## (a stacking card locks in its amount now).
func take_pick(index: int) -> String:
	if state.pick.is_empty():
		return "there's no pick waiting"
	if index < 0 or index >= state.pick.size():
		return "there's no card %d" % index
	var upgrade: UpgradeDef = run.upgrades[state.pick[index]]
	var hero: RunState.Hero = state.hero(upgrade.hero)
	if upgrade.stacks():
		# Locked in from the hero's stat now (section 15.4).
		var amount: int = run.stack_amount(hero, upgrade)
		if not hero.locked.has(upgrade.id):
			hero.locked[upgrade.id] = []
		hero.locked[upgrade.id].append(amount)
	hero.upgrades.append(upgrade.id)
	if upgrade.grows != null:
		state.hero(upgrade.hero).growth[upgrade.id] = 0
	state.pick.remove_at(index)
	state.picks_left -= 1
	if state.picks_left <= 0:
		state.pick.clear()
	return ""


## Passes on the waiting pick for the act's pick_shards.
func take_shards() -> String:
	if state.pick.is_empty():
		return "there's no pick waiting"
	state.shards += act.pick_shards
	state.pick.clear()
	state.picks_left = 1
	return ""


## Switches `hero_id`'s vow to another of its paths, between fights, until it
## transforms. Every path's deed keeps what it had.
func switch_vow(hero_id: String, path_id: String) -> String:
	if state.phase == RunState.Phase.ENDED:
		return _not_now("switch a vow")
	var hero: RunState.Hero = state.hero(hero_id)
	if hero == null:
		return "unknown hero \"%s\"" % hero_id
	if hero.transformed:
		return "%s has transformed, so the vow is set" % hero_id
	if not hero.deeds.has(path_id):
		return "%s can't vow to \"%s\"" % [hero_id, path_id]
	if hero.path == path_id:
		return "%s is already vowed to %s" % [hero_id, path_id]
	hero.path = path_id
	return ""


# --- apexes (phase 8 part 2) --------------------------------------------------------

## Once the apex vow is open and `hero` has transformed, its path's apexes'
## deeds start counting (rebuild-phase8-apexes.md, section 4).
func _open_apex(hero: RunState.Hero) -> void:
	if not state.apex_open or not hero.transformed:
		return
	for apex: ApexDef in run.content.paths[hero.path].apexes:
		if not hero.deeds.has(apex.id):
			hero.deeds[apex.id] = 0


## The heroes who may vow to an apex and haven't: the vow is open, they've
## transformed, and their path has apexes (the screen offers them, the bots
## answer them).
func apex_waiting() -> Array[String]:
	var waiting: Array[String] = []
	if not state.apex_open or state.phase == RunState.Phase.ENDED:
		return waiting
	for hero: RunState.Hero in state.heroes:
		if hero.transformed and hero.apex.is_empty() and not run.content.paths[hero.path].apexes.is_empty():
			waiting.append(hero.id)
	return waiting


## Vows `hero_id` to `apex_id`, one of its path's apexes: its taste from the
## next fight, and its deed fills toward the apex. Free to switch until the
## apex is earned (apexes.md).
func vow_apex(hero_id: String, apex_id: String) -> String:
	if state.phase == RunState.Phase.ENDED:
		return _not_now("vow to an apex")
	var hero: RunState.Hero = state.hero(hero_id)
	if hero == null:
		return "unknown hero \"%s\"" % hero_id
	if not state.apex_open:
		return "the apex vow opens after the act's boss"
	if not hero.transformed:
		return "%s must transform first" % hero_id
	if hero.apex_earned:
		return "%s has earned its apex, so the vow is set" % hero_id
	if run.content.paths[hero.path].apex(apex_id) == null:
		return "%s can't vow to the apex \"%s\"" % [hero_id, apex_id]
	if hero.apex == apex_id:
		return "%s is already vowed to %s" % [hero_id, apex_id]
	hero.apex = apex_id
	return ""


# --- the loadout ------------------------------------------------------------------

## Puts `item_id` from the stash into `hero_id`'s slot `slot`, between fights;
## whatever was there goes back to the stash. A hero holds one tactic and
## one gambit.
func equip(hero_id: String, slot: int, item_id: String) -> String:
	if state.phase == RunState.Phase.ENDED:
		return _not_now("change a loadout")
	var hero: RunState.Hero = state.hero(hero_id)
	if hero == null:
		return "unknown hero \"%s\"" % hero_id
	if slot < 0 or slot >= hero.slots.size():
		return "%s has no slot %d" % [hero_id, slot]
	if not state.stash.has(item_id):
		return "\"%s\" isn't in the stash" % item_id
	var kind: ItemDef.Kind = run.items[item_id].kind
	if kind == ItemDef.Kind.TACTIC or kind == ItemDef.Kind.GAMBIT:
		for i: int in hero.slots.size():
			if i != slot and run.items.has(hero.slots[i]) and run.items[hero.slots[i]].kind == kind:
				return "%s already holds a %s" % [hero_id, ItemDef.KIND_NAMES[kind]]
	state.stash.erase(item_id)
	if not hero.slots[slot].is_empty():
		state.stash.append(hero.slots[slot])
	hero.slots[slot] = item_id
	return ""


## Switch Places at rank II (phase 5c step 6d): when `hero_id` swaps, 5, 10,
## or 15 seconds in.
func set_gambit_at(hero_id: String, seconds: int) -> String:
	var hero: RunState.Hero = state.hero(hero_id)
	if hero == null:
		return "unknown hero \"%s\"" % hero_id
	var gambit: KitMod = run.loadout_gambit(hero, state)
	if gambit == null or not gambit.swap_choice:
		return "%s holds no gambit whose moment it can choose" % hero_id
	if not GAMBIT_MOMENTS.has(seconds):
		return "it swaps at 5, 10, or 15 seconds"
	hero.gambit_at = seconds
	return ""


const GAMBIT_MOMENTS: Array[int] = [5, 10, 15]


## Takes what's in `hero_id`'s slot `slot` back to the stash.
func unequip(hero_id: String, slot: int) -> String:
	if state.phase == RunState.Phase.ENDED:
		return _not_now("change a loadout")
	var hero: RunState.Hero = state.hero(hero_id)
	if hero == null:
		return "unknown hero \"%s\"" % hero_id
	if slot < 0 or slot >= hero.slots.size() or hero.slots[slot].is_empty():
		return "%s has nothing in slot %d" % [hero_id, slot]
	state.stash.append(hero.slots[slot])
	hero.slots[slot] = ""
	return ""


# --- shops ------------------------------------------------------------------------

## Opens a shop ("pedlar" after the fight, "magpie" as his node), its wares
## and relics drawn now (the day opens it; tests open one directly). Phase 5c step 5a:
## every shop shows a relic (more with shop_relics_add); the boss day's
## Pedlar, after the boss, is the boss shop (a legendary first, rerolls from
## boss_reroll; Decision 48); the Magpie's are epic or legendary, one look. As a shop
## opens, the relics' shop_shards and miser pay.
func open_shop(kind: String) -> String:
	if state.phase != RunState.Phase.SHOP and state.phase != RunState.Phase.NODE:
		return _not_now("open a shop")
	match kind:
		"pedlar":
			state.wares = Offers.pedlar(run, state, 0)
		"magpie":
			state.wares = Offers.magpie(run, state)
		_:
			return "there's no shop \"%s\"" % kind
	state.shop = kind
	state.shop_dear_bp = state.dear_shop_bp
	state.dear_shop_bp = 0
	state.rerolls = 0
	state.magpie_swapped = false
	state.shop_relics = _draw_shop_relics()
	state.shards += run.relic_sum(state, "shop_shards")
	if run.relic_rule(state, "miser"):
		@warning_ignore("integer_division")
		state.shards += mini(state.shards / 5, 6)
	return ""


func _draw_shop_relics() -> Array[String]:
	var count: int = 1 + run.relic_sum(state, "shop_relics_add") + (1 if boss_shop() else 0)
	return Offers.shop_relics(run, state, state.rerolls, count, state.shop == "magpie", boss_shop())


## True if the open shop is the boss shop: the Pedlar of the boss's day,
## after the boss fight and its relic choice (Decision 48; it was the day
## before the boss's until then).
func boss_shop() -> bool:
	return state.shop == "pedlar" and run.day_kind(state, state.day) == "boss"


func close_shop() -> void:
	state.shop = ""
	state.shop_dear_bp = 0
	state.wares.clear()
	state.rerolls = 0
	state.shop_relics.clear()


## What ware `item_id` costs at the open shop: its kind's price at the
## Pedlar (with relics' price_add), the Magpie's charm price at his stall.
func price_of(item_id: String) -> int:
	if state.shop == "magpie":
		return act.magpie_charm_price
	return _marked_up(act.item_prices[ItemDef.KIND_NAMES[run.items[item_id].kind]])


## What the Pedlar pays for `item_id`: half its kind's price, rounded down,
## whatever its rank (loadout rule 9).
func sell_price(item_id: String) -> int:
	@warning_ignore("integer_division")
	return act.item_prices[ItemDef.KIND_NAMES[run.items[item_id].kind]] / 2


## Sells an item the run owns to the Pedlar, from the stash or a slot. Its
## rank goes with it.
func sell(item_id: String) -> String:
	if state.shop != "pedlar":
		return "only the Pedlar buys items"
	if not state.item_ranks.has(item_id):
		return "the run doesn't own \"%s\"" % item_id
	if state.stash.has(item_id):
		state.stash.erase(item_id)
	else:
		for hero: RunState.Hero in state.heroes:
			var slot: int = hero.slots.find(item_id)
			if slot >= 0:
				hero.slots[slot] = ""
	state.item_ranks.erase(item_id)
	state.item_counts.erase(item_id)
	state.shards += sell_price(item_id)
	return ""


## Gives the run `item_id` at `rank` (1 to 3): into the stash if it's new,
## else its owned copy a rank up (or to `rank`, if that's higher), its count
## starting again.
func _gain_item(item_id: String, rank: int = 1) -> void:
	if not state.item_ranks.has(item_id):
		state.stash.append(item_id)
		state.item_ranks[item_id] = rank
	else:
		state.item_ranks[item_id] = mini(maxi(state.item_ranks[item_id] + 1, rank), ItemDef.RANKS)
	state.item_counts[item_id] = 0


## A price at the Pedlar, with the relics' price_add (never below 1).
func _marked_up(price: int) -> int:
	var marked: int = maxi(price + run.relic_sum(state, "price_add"), 1)
	# The Rift Merchant's toll on the next shop (phase 5c step 8c).
	return FixedMath.apply_bp(marked, state.shop_dear_bp) if state.shop_dear_bp > 0 else marked


## Buys ware `index` into the stash, or, owned, a rank up (a bought copy
## skips a rank).
func buy(index: int) -> String:
	if state.shop.is_empty():
		return "no shop is open"
	if index < 0 or index >= state.wares.size() or state.wares[index].is_empty():
		return "there's no ware %d" % index
	var price: int = price_of(state.wares[index])
	if state.shards < price:
		return "it costs %d shards; there are %d" % [price, state.shards]
	state.shards -= price
	# The Magpie's charms come at rank II (phase 5c step 6e).
	_gain_item(state.wares[index], 2 if state.shop == "magpie" else 1)
	state.wares[index] = ""
	return ""


## What the open shop's next reroll costs (phase 5c step 5a): the first
## reroll_price (boss_reroll_price in the boss shop), each after it 1
## more (flat_rerolls: never more); free_reroll makes the first free.
func reroll_price() -> int:
	if state.rerolls == 0 and run.relic_rule(state, "free_reroll"):
		return 0
	var base: int = act.boss_reroll_price if boss_shop() else act.reroll_price
	return base + (0 if run.relic_rule(state, "flat_rerolls") else state.rerolls)


## The Pedlar lays out fresh wares and relics (Decision 19), for the next
## reroll's price. The Magpie is one look.
func reroll() -> String:
	if state.shop != "pedlar":
		return "only the Pedlar rerolls"
	var price: int = reroll_price()
	if state.shards < price:
		return "a reroll costs %d shards; there are %d" % [price, state.shards]
	state.shards -= price
	state.rerolls += 1
	state.wares = Offers.pedlar(run, state, state.rerolls)
	state.shop_relics = _draw_shop_relics()
	return ""


## What treating a wound costs (with wound_price_add, never below 0).
func wound_price() -> int:
	return maxi(act.wound_price + run.relic_sum(state, "wound_price_add"), 0)


## Treats one of `hero_id`'s wounds, wherever a shop is open.
func treat_wound(hero_id: String) -> String:
	if state.shop.is_empty():
		return "no shop is open"
	var hero: RunState.Hero = state.hero(hero_id)
	if hero == null:
		return "unknown hero \"%s\"" % hero_id
	if hero.wounds == 0:
		return "%s has no wounds" % hero_id
	if state.shards < wound_price():
		return "treating a wound costs %d shards; there are %d" % [wound_price(), state.shards]
	state.shards -= wound_price()
	hero.wounds -= 1
	return ""


## True while some boss relic isn't held.
func _boss_relic_left() -> bool:
	return run.relic_ids.any(func(id: String) -> bool: return run.relics[id].tier == RelicDef.Tier.BOSS and not state.relics.has(id))


func _end(outcome: RunState.Outcome) -> void:
	state.outcome = outcome
	state.phase = RunState.Phase.ENDED


func _not_now(what: String) -> String:
	return "can't %s now (the day is at %s)" % [what, RunState.PHASE_NAMES[state.phase]]
