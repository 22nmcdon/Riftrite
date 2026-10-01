extends "res://tools/bots/good_bot.gd"
## The expert (docs/plans/rebuild-phase6-bot-tuning.md, section 2.4): the
## good bot, except that it tries its candidate formations in the real fight
## (the same setup and seed) and keeps the one worth most. The ceiling: what
## perfect knowledge of each fight would add.


func _init() -> void:
	label = "expert"


func formation(flow: RunFlow) -> Dictionary[String, Vector2i]:
	var found: Array[Dictionary] = candidates(flow)
	if found.is_empty():
		return super.formation(flow)
	var best: Dictionary[String, Vector2i] = {}
	best.assign(found[0])
	var best_worth: float = -INF
	for placed: Dictionary in found:
		var hexes: Dictionary[String, Vector2i] = {}
		hexes.assign(placed)
		var errors: Array[String] = []
		var value: float = Practice.worth(flow.fight_setup(hexes, errors, markers(flow, hexes)), flow.run.content)
		if value > best_worth:
			best_worth = value
			best = hexes
	return best
