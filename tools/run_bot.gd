extends RefCounted
## The simple run bot (docs/plans/rebuild-phase5-run.md, section 12, Decision
## 14): plays whole runs through RunFlow, for tests and pacing, not for a win
## rate (the good bot is phase 6). It vows each hero to its first path unless
## told otherwise, takes a camp option by a fixed order (Rest when someone has
## 2 wounds), buys what it can use and equips it, takes today's first fight,
## places the sim runner's "guarded" formation, and takes the first card of
## any pick or relic choice.

const Report = preload("res://tools/sim_report.gd")
const FORMATIONS_FILE: String = "res://tools/sim_formations.json"
const FORMATION: String = "guarded"
## A run is at most 7 days of at most 2 attempts, a few actions each;
## anything past this is a bug.
const MAX_STEPS: int = 400
## Camp options, first the bot likes best (Rest only when someone's hurt).
const CAMP_ORDER: Array[String] = ["magpie", "train", "pedlar", "shrine", "fortify", "hunt", "scout", "dig_in", "map_the_rift", "rift_tear", "rest"]
## Where Dig In's rock goes: a corner of the heroes' zone, out of the way.
const ROCK: Vector2i = Vector2i(0, 0)


## The formation the bot places.
static func formation() -> Dictionary[String, Vector2i]:
	var errors: Array[String] = []
	var named: Dictionary[String, Dictionary] = Report.read_formations(FileAccess.get_file_as_string(FORMATIONS_FILE), errors)
	var hexes: Dictionary[String, Vector2i] = {}
	hexes.assign(named[FORMATION])
	return hexes


## Each hero's first path.
static func first_vows(content: ContentDb) -> Dictionary[String, String]:
	var vows: Dictionary[String, String] = {}
	for hero_id: String in content.hero_ids:
		vows[hero_id] = content.heroes[hero_id].paths[0].id
	return vows


## Plays a run from `run_seed` to its end. Errors (a refused action) go in
## `errors` and stop it.
static func play(run: RunContent, run_seed: int, errors: Array[String], vows: Dictionary[String, String] = {}) -> RunFlow:
	var flow: RunFlow = RunFlow.start(run, run_seed, vows if not vows.is_empty() else first_vows(run.content), errors)
	if flow == null:
		return null
	var hexes: Dictionary[String, Vector2i] = formation()
	for step: int in MAX_STEPS:
		if flow.state.phase == RunState.Phase.ENDED:
			return flow
		var refused: String = step_once(flow, hexes, errors)
		if not refused.is_empty():
			errors.append("day %d (%s): %s" % [flow.state.day, RunState.PHASE_NAMES[flow.state.phase], refused])
			return flow
	errors.append("the run didn't end in %d steps" % MAX_STEPS)
	return flow


## One action for wherever the day is. Returns why it was refused ("": done).
static func step_once(flow: RunFlow, hexes: Dictionary[String, Vector2i], errors: Array[String]) -> String:
	var state: RunState = flow.state
	if not state.pick.is_empty():
		return flow.take_pick(0)
	if not state.relic_choice.is_empty():
		return flow.take_relic(0)
	match state.phase:
		RunState.Phase.CAMP:
			if state.camp_used.is_empty():
				return flow.choose_camp(camp_choice(state))
			if not state.hunt.is_empty():
				var hunt_errors: Array[String] = []
				if flow.fight(hexes, hunt_errors) == null:
					return ", ".join(hunt_errors)
				return ""
			if state.mapping:
				return flow.swap_fight(0)
			if not state.shop.is_empty() and shop_once(flow):
				return ""
			if state.dig_in and state.rock.is_empty():
				return flow.place_rock(ROCK)
			return flow.leave_camp()
		RunState.Phase.ROUTE:
			return flow.choose_fight(0)
		RunState.Phase.LOADOUT:
			var fight_errors: Array[String] = []
			if flow.fight(hexes, fight_errors) == null:
				return ", ".join(fight_errors)
			return ""
		RunState.Phase.AFTER:
			return flow.finish_day()
	return "nothing to do"


## The camp option the bot takes: Rest if someone has 2 wounds or more,
## else the first of CAMP_ORDER offered.
static func camp_choice(state: RunState) -> int:
	if state.camp.has("rest") and state.heroes.any(func(hero: RunState.Hero) -> bool: return hero.wounds >= 2):
		return state.camp.find("rest")
	for option: String in CAMP_ORDER:
		if state.camp.has(option):
			return state.camp.find(option)
	return 0


## One purchase at the open shop: the first ware it can afford that suits a
## hero with a free slot (equipped there), else the relic, else a wound.
## False if there's nothing left to do.
static func shop_once(flow: RunFlow) -> bool:
	var state: RunState = flow.state
	for i: int in state.wares.size():
		var id: String = state.wares[i]
		if id.is_empty() or flow.price_of(id) > state.shards:
			continue
		for hero: RunState.Hero in state.heroes:
			if hero.slots.has("") and flow.run.items[id].works_on(flow.run.hero_kit(hero), hero.id):
				# A second tactic can't be equipped; it waits in the stash.
				if flow.buy(i) == "":
					flow.equip(hero.id, hero.slots.find(""), id)
				return true
	if not state.shop_relic.is_empty() and flow.relic_price() <= state.shards:
		return flow.buy_relic() == ""
	for hero: RunState.Hero in state.heroes:
		if hero.wounds > 0 and state.shards >= flow.run.act.wound_price:
			return flow.treat_wound(hero.id) == ""
	return false
