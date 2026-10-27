class_name RunFlow
extends RefCounted
## The run's rules (docs/plans/phases/rebuild-phase5-run.md, sections 1 and 3): the
## only thing that changes a RunState, one action at a time. Each action
## checks it's legal now and returns "" if it happened, or why it didn't
## (the state is then untouched). The UI and the run bot both drive it.
## A day (phase 5c step 8, docs/plans/design/days-and-nodes.md): the route (choose
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
## The rules are split by concern (the clean-up, docs/plans/phases/cleanup-and-layout.md):
## RunEvents (the Event node and oaths), RunShop (the shops and relics bought and
## sold), RunFightSetup (each fight's kits and enemies), and RunRecord (what a
## fight leaves behind). RunFlow keeps every action's name and delegates to
## them; each takes the flow and changes only its state, so RunFlow is still the
## one way a run changes.

## Where a relic choice happens (its stream's visit).
const RELIC_SHRINE: int = 0
const RELIC_AFTER_FIGHT: int = 1
## A won day fight that started with this many shards held or more is
## "won_holding" (phase 8 part 6: Old Coins, Dragon's Hoard).
const WON_HOLDING_SHARDS: int = 30

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


# --- the day's start --------------------------------------------------------------

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


# --- the day's end, the acts, and endless (phase 8 part 1) ------------------------

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
	state.pick = RunRecord._pick_cards(self, 0)


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
	state.transmuted_act = 0
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


# --- events (RunEvents) and the nodes ---------------------------------------------

## The scene of the event node the day is in, or null (RunEvents).
func event_scene() -> EventDef.Scene:
	return RunEvents.event_scene(self)


## Why the event's choice `index` can't be made with `target` (a hero id, an
## item id, or "<hero id>:<path id>" for the mirror; "" when it needs none), or
## "" (RunEvents).
func event_problem(index: int, target: String = "") -> String:
	return RunEvents.event_problem(self, index, target)


## Every target a choice could take (the heroes, the run's items, or each
## hero's other paths), fitting or not (RunEvents).
func event_targets(choice: EventDef.Choice) -> Array[String]:
	return RunEvents.event_targets(self, choice)


## Makes the event's choice `index` (with `target`, as event_problem says): its
## results in order (RunEvents).
func choose_event(index: int, target: String = "") -> String:
	return RunEvents.choose_event(self, index, target)


## Takes the Bloodied Oath's oath `index` (phase 5c step 8c): its hero bears it
## for its next oath_fights day fights (RunEvents).
func take_oath(index: int) -> String:
	return RunEvents.take_oath(self, index)


## The oath `hero` bears, or null (RunEvents).
func oath_of(hero: RunState.Hero) -> EventDef.Oath:
	return RunEvents.oath_of(self, hero)


## The heroes' front row (the Oath of the Vanguard's; RunEvents).
func front_row() -> int:
	return RunEvents.front_row(self)


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
			state.pick = RunRecord._pick_cards(self, 1)
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
			if Offers.swappable(run, state).is_empty():
				return "there's no other fight to swap in"
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


# --- the fight (RunFightSetup, RunRecord) -----------------------------------------

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
## run has it, or null with the reasons in `errors` (RunFightSetup).
func fight_setup(formation: Dictionary[String, Vector2i], errors: Array[String], snares: Dictionary[String, Array] = {}) -> FightSetup:
	return RunFightSetup.fight_setup(self, formation, errors, snares)


## The kit `hero_id` fights with as things stand between fights: its path's at
## its stage, then its upgrades, loadout, relics, and bonds (camp's modifiers
## for the next fight aside; RunFightSetup).
func kit_of(hero_id: String, with_covenant: bool = true) -> UnitDef:
	return RunFightSetup.kit_of(self, hero_id, with_covenant)


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


## Records a fought fight: the formation, deeds, wounds (a win heals one on
## each hero first, then each hero who fell takes one), transformations (and
## bonds found), then the outcome (RunRecord).
func record(formation: Dictionary[String, Vector2i], result: FightResult) -> void:
	RunRecord.record(self, formation, result)


# --- relic choices, the Shrine, the pick, and vows --------------------------------

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
		RunShop._lose_relic(self, state.shrine.trim_prefix("relic:"))
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


## Buys the open shop's relic `index` (RunShop).
func buy_relic(index: int = 0) -> String:
	return RunShop.buy_relic(self, index)


## What the open shop's relic `index` costs: its tier's price (the Magpie's at
## his discount, rounded down), with the Pedlar's price_add and (phase 8 part
## 6) the team's shop rules (`full`: without them; RunShop).
func relic_price(index: int = 0, full: bool = false) -> int:
	return RunShop.relic_price(self, index, full)


## What the Magpie pays for `relic_id` (its tier's relic_sell; RunShop).
func relic_sell_price(relic_id: String) -> int:
	return RunShop.relic_sell_price(self, relic_id)


## Sells a relic the run holds to the Magpie, the only one who buys them (phase
## 5c step 6e, magpie.md; RunShop).
func sell_relic(relic_id: String) -> String:
	return RunShop.sell_relic(self, relic_id)


## The Magpie's swap, once a visit: `relic_id` for a relic of its tier the run
## doesn't hold, free (RunShop).
func swap_relic(relic_id: String) -> String:
	return RunShop.swap_relic(self, relic_id)


func _gain_relic(relic_id: String) -> void:
	state.relics.append(relic_id)
	if run.relics[relic_id].grows != null:
		state.growth[relic_id] = 0
	for i: int in run.relics[relic_id].slots_add:
		for hero: RunState.Hero in state.heroes:
			hero.slots.append("")


## What `item_id` has counted toward its next rank, and what that rank needs (0
## at rank III; RunRecord).
func rank_progress(item_id: String) -> Vector2i:
	return RunRecord.rank_progress(self, item_id)


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


# --- shops (RunShop) --------------------------------------------------------------

## Opens a shop ("pedlar" after the fight, "magpie" as his node), its wares and
## relics drawn now (the day opens it; tests open one directly; RunShop).
func open_shop(kind: String) -> String:
	return RunShop.open_shop(self, kind)


## The black-market slot's free rerolls left in the open shop (RunShop).
func black_market_rerolls_left() -> int:
	return RunShop.black_market_rerolls_left(self)


## Smuggler's Route (phase 8 part 6): the black-market slot alone drawn again,
## free, as many times a shop as the team's shop rules allow (RunShop).
func reroll_black_market() -> String:
	return RunShop.reroll_black_market(self)


## True if the open shop is the boss shop: the Pedlar of the boss's day, after
## the boss fight and its relic choice (Decision 48; it was the day before the
## boss's until then; RunShop).
func boss_shop() -> bool:
	return RunShop.boss_shop(self)


## close_shop (RunShop).
func close_shop() -> void:
	RunShop.close_shop(self)


## What ware `item_id` costs at the open shop: its kind's price at the Pedlar
## (with relics' price_add), the Magpie's charm price at his stall (RunShop).
func price_of(item_id: String) -> int:
	return RunShop.price_of(self, item_id)


## What the Pedlar pays for `item_id`: half its kind's price, rounded down,
## whatever its rank (loadout rule 9); less by the team's shop rules (phase 8
## part 6, Fence: a quarter; RunShop).
func sell_price(item_id: String) -> int:
	return RunShop.sell_price(self, item_id)


## Sells an item the run owns to the Pedlar, from the stash or a slot
## (RunShop).
func sell(item_id: String) -> String:
	return RunShop.sell(self, item_id)


## Items the open shop may still transmute (0: none; only the Pedlar and the
## boss shop, Decision 6; RunShop).
func transmutes_left() -> int:
	return RunShop.transmutes_left(self)


## What transmuting `item_id` pays: its kind's full price (selling pays half),
## and more by the team's transmuting cards (RunShop).
func transmute_price(item_id: String) -> int:
	return RunShop.transmute_price(self, item_id)


## Turns an item the run owns into shards at its full price (phase 8 part 6,
## transformed Transmuter: once a shop, at the Pedlar or the boss shop), from
## the stash or a slot (RunShop).
func transmute(item_id: String) -> String:
	return RunShop.transmute(self, item_id)


## How many items the open shop may still turn into other items (phase 8 part
## 6, Grand Transmutation): its transmutes, if the team's transmuting allows
## items into items there, else what's left of the act's allowance (RunShop).
func transmutes_into_left() -> int:
	return RunShop.transmutes_into_left(self)


## Turns an item the run owns into a random item of the same kind it doesn't
## own (phase 8 part 6, Grand Transmutation: its taste once an act, its apex
## with a shop's transmutes, at rank II), and counts it toward every hero's
## "transmuted" deed (RunShop).
func transmute_into(item_id: String) -> String:
	return RunShop.transmute_into(self, item_id)


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


## Buys ware `index` into the stash, or, owned, a rank up (a bought copy skips
## a rank; RunShop).
func buy(index: int) -> String:
	return RunShop.buy(self, index)


## The rank buying ware `index` gives: an owned item's next, rank II at least
## at the Magpie or for Insider's charms (phase 8 part 6), at most III
## (RunShop).
func ware_rank(index: int) -> int:
	return RunShop.ware_rank(self, index)


## What the open shop's next reroll costs (phase 5c step 5a): the first
## reroll_price (boss_reroll_price in the boss shop), each after it 1 more
## (flat_rerolls: never more); free_reroll makes the first free (RunShop).
func reroll_price(full: bool = false) -> int:
	return RunShop.reroll_price(self, full)


## The Pedlar lays out fresh wares and relics (Decision 19), for the next
## reroll's price (RunShop).
func reroll() -> String:
	return RunShop.reroll(self)


## What treating a wound costs (with wound_price_add, never below 0; RunShop).
func wound_price() -> int:
	return RunShop.wound_price(self)


## Treats one of `hero_id`'s wounds, wherever a shop is open (RunShop).
func treat_wound(hero_id: String) -> String:
	return RunShop.treat_wound(self, hero_id)


## The team's shop rules (phase 8 part 6, ShopRulesDef): its heroes' added
## together (null: none of them has any; RunShop).
func shop_rules() -> ShopRulesDef:
	return RunShop.shop_rules(self)


# --- shared by the modules --------------------------------------------------------

func _end(outcome: RunState.Outcome) -> void:
	state.outcome = outcome
	state.phase = RunState.Phase.ENDED


func _not_now(what: String) -> String:
	return "can't %s now (the day is at %s)" % [what, RunState.PHASE_NAMES[state.phase]]
