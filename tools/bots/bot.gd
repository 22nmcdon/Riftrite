extends RefCounted
## A run bot (docs/plans/rebuild-phase6-bot-tuning.md, section 2.1): it
## answers each decision tools/bots/run_player.gd asks of it, and never
## changes the run itself (the player does what it answers, through
## RunFlow). This base answers as the simple bot does (tools/run_bot.gd:
## fixed orders, the "guarded" formation); the random and good bots
## override what they decide differently. Every answer is a pure function of
## the run's state (and a bot's own seeded RNG), so a run repeats.

const Simple = preload("res://tools/run_bot.gd")
const PracticeSession = preload("res://src/ui/practice/practice_session.gd")

## Its name in the run report ("simple", "simple-peek", "random", "good",
## "expert").
var label: String = "simple"
## The simple bot's peek (the run report's line until phase 6): it tries the
## named formations in the real fight and keeps the first that doesn't lose.
var peek: bool = false
## Endless (phase 8 part 1): after the act's boss shop, go deeper (the
## runner's --endless) or end the run.
var deeper: bool = false


## Called once, before the run's first decision.
func begin(_flow: RunFlow) -> void:
	pass


## Today's fight on the route: an index into state.today().
## After the act's boss shop: true goes deeper into endless.
func go_deeper(_flow: RunFlow) -> bool:
	return deeper


## The apex `hero_id` vows to once its apex vow is open (phase 8 part 2):
## the base takes its path's first.
func apex(flow: RunFlow, hero_id: String) -> String:
	var hero: RunState.Hero = flow.state.hero(hero_id)
	return flow.run.content.paths[hero.path].apexes[0].id


func route(_flow: RunFlow) -> int:
	return 0


## Changes the loadout before a fight (equip, unequip), through `flow`. The
## base keeps what the shop equipped.
func loadout(_flow: RunFlow) -> void:
	pass


## The formation for the waiting fight (a day's fight, or a Hunt).
func formation(flow: RunFlow) -> Dictionary[String, Vector2i]:
	return Simple.formation_for(flow) if peek else Simple.formation()


## Where each hero that places markers puts them (snares, a lantern): hero
## id -> hexes. The base puts them where Practice starts them, moved to the
## nearest legal hexes.
func markers(flow: RunFlow, hexes: Dictionary[String, Vector2i]) -> Dictionary[String, Array]:
	return default_markers(flow, hexes)


## The pick: an index into state.pick, or -1 for the shards.
func pick(flow: RunFlow) -> int:
	return Simple.pick_choice(flow)


## A relic choice: an index into state.relic_choice, or -1 to decline.
func relic(flow: RunFlow) -> int:
	return 0 if flow.state.shards >= flow.state.relic_choice_price else -1


## One action at the open shop (the Pedlar or the Magpie), done through
## `flow`. False when it's done shopping.
func shop(flow: RunFlow) -> bool:
	return Simple.shop_once(flow)


## The day's node: an index into state.nodes.
func node(flow: RunFlow) -> int:
	return Simple.node_choice(flow)


## A camp option: an index into state.camp.
func camp(flow: RunFlow) -> int:
	return Simple.camp_choice(flow.state)


## A Rift Tear's depth: an index into run.camps.depths.
func depth(_flow: RunFlow) -> int:
	return 0


## An event's choice: [index, target], or [] to walk away.
func event(flow: RunFlow) -> Array:
	return Simple.event_choice(flow)


## A Bloodied Oath: an index into state.oath_offer, or -1 to pass.
func oath(_flow: RunFlow) -> int:
	return -1


## The Shrine's offering: [kind, what] (RunFlow.shrine_offer), or [] for none.
func shrine(flow: RunFlow) -> Array:
	return ["shards", ""] if flow.state.shards >= flow.run.act.shrine_price else []


## Map the Rift: which of tomorrow's fights to swap.
func swap(_flow: RunFlow) -> int:
	return 0


## Dig In's rock.
func rock(_flow: RunFlow) -> Vector2i:
	return Simple.ROCK


## Markers where Practice starts them (PracticeSession.DEFAULT_SNARES), each
## moved to the nearest hex that makes a legal fight.
static func default_markers(flow: RunFlow, hexes: Dictionary[String, Vector2i]) -> Dictionary[String, Array]:
	var placed: Dictionary[String, Array] = {}
	var grid: HexGrid = flow.run.content.tuning.make_grid()
	for hero: RunState.Hero in flow.state.heroes:
		var count: int = flow.kit_of(hero.id).placed_markers()
		if count == 0 or not hexes.has(hero.id):
			continue
		var mine: Array = []
		for start: Vector2i in PracticeSession.DEFAULT_SNARES.slice(0, count):
			for hex: Vector2i in nearest_first(grid, start):
				if mine.has(hex):
					continue
				placed[hero.id] = mine + [hex]
				var errors: Array[String] = []
				if flow.fight_setup(hexes, errors, placed) != null:
					mine.append(hex)
					break
		placed[hero.id] = mine
	return placed


## Every hex of `grid`, nearest `start` first (ties by column, then row).
static func nearest_first(grid: HexGrid, start: Vector2i) -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []
	for row: int in grid.height:
		for col: int in grid.width:
			hexes.append(Vector2i(col, row))
	var from: Vector2i = grid.center(start.x, start.y)
	hexes.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = (grid.center(a.x, a.y) - from).length_squared()
		var db: int = (grid.center(b.x, b.y) - from).length_squared()
		return da < db if da != db else (a.x < b.x if a.x != b.x else a.y < b.y))
	return hexes
