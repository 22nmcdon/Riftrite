extends "res://tools/bots/bot.gd"
## The good bot (docs/plans/rebuild-phase6-bot-tuning.md, sections 2.2 and
## 2.3): it places by reading the fight (tools/bots/placement.gd), never by
## fighting it, and judges its choices by practice fights (step 6c).

const Placement = preload("res://tools/bots/placement.gd")
const Practice = preload("res://tools/bots/practice.gd")

## How many of the best-scored formations it keeps (the first legal one is
## placed; the expert tries them all).
const CANDIDATES: int = 6


func _init() -> void:
	label = "good"


func formation(flow: RunFlow) -> Dictionary[String, Vector2i]:
	var found: Array[Dictionary] = candidates(flow)
	if found.is_empty():
		return super.formation(flow)
	var hexes: Dictionary[String, Vector2i] = {}
	hexes.assign(found[0])
	return hexes


## The best-scored legal formations for the waiting fight, best first.
func candidates(flow: RunFlow) -> Array[Dictionary]:
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Simple.formation(), errors)
	var legal: Array[Dictionary] = []
	if setup == null:
		return legal
	var grid: HexGrid = flow.run.content.tuning.make_grid()
	for placed: Dictionary in Placement.best_formations(setup, grid, CANDIDATES):
		var hexes: Dictionary[String, Vector2i] = {}
		hexes.assign(placed)
		var problems: Array[String] = []
		if flow.fight_setup(hexes, problems, markers(flow, hexes)) != null:
			legal.append(hexes)
	return legal
