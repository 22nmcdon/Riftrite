class_name FightFx
extends Control
## The momentary things on the board during a fight
## (docs/plans/rebuild-phase3-fight-sandbox.md, section 5), made from the log
## entries the FightPlayer hands out and drawn over the tokens:
##   SHOT             a dot flying from the shooter to its target, landing at
##                    the shot's landing tick; SHOT_FIZZLED removes it
##   DAMAGE           a swipe from attacker to target when they're in melee
##                    reach (a shot or an area shows its own), and a number
##   STATUS_DAMAGE, COLLAPSE, HEAL, SHIELD   a number
##   FIRE             a signature's name over the unit that fired it
## Each lasts a set number of ticks of fight time (FightPlayer.drawn_time),
## so it pauses and changes speed with the fight. It only reads.

## How long each kind lasts, in ticks.
const NUMBER_TICKS: int = 16
const SWIPE_TICKS: int = 4
const POPUP_TICKS: int = 24
## A swipe is drawn when attacker and target are this close (plane units),
## measured between their edges.
const MELEE_GAP: int = 600
## A batch this big (a skip or seek) isn't animated.
const MAX_ANIMATED: int = 60
const DAMAGE_COLOR := Color("f1e6cc")
const CRIT_COLOR := Color("ffd166")
const HEAL_COLOR := UiStyle.GOOD
const COLLAPSE_COLOR := UiStyle.EMBER

enum Kind { SHOT, SWIPE, NUMBER, POPUP }


## One effect on the board.
class Fx:
	var kind: Kind
	var start: int
	var end: int
	## Where it starts on the plane (a shooter, an attacker, a hit unit).
	var from: Vector2
	## The unit it follows or aims at (a shot's target, a number's unit).
	var unit_id: String = ""
	var source_id: String = ""
	var text: String = ""
	var color: Color = Color.WHITE
	var big: bool = false


var effects: Array[Fx] = []
var _view: ArenaView
var _player: FightPlayer = null


static func make(view: ArenaView) -> FightFx:
	var fx := FightFx.new()
	fx._view = view
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.z_index = 1
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return fx


func clear() -> void:
	effects.clear()
	queue_redraw()


## Turns new log entries into effects (a big batch from a skip or seek clears
## them instead).
func add_entries(entries: Array[LogEntry], player: FightPlayer) -> void:
	_player = player
	if entries.size() > MAX_ANIMATED:
		clear()
		return
	for entry: LogEntry in entries:
		_add(entry, player.sim)


## Drops the effects that are over and redraws the rest.
func update(player: FightPlayer) -> void:
	_player = player
	var now: float = player.drawn_time()
	effects = effects.filter(func(fx: Fx) -> bool: return now < fx.end)
	queue_redraw()


func _add(entry: LogEntry, sim: CombatSim) -> void:
	match entry.kind:
		LogEntry.Kind.SHOT:
			var shot: Fx = _new(Kind.SHOT, entry.tick, entry.end_tick, Vector2(entry.from_pos), entry.target)
			shot.source_id = entry.source_unit
			shot.color = _side_color(sim, entry.source_unit)
		LogEntry.Kind.SHOT_FIZZLED:
			for fx: Fx in effects:
				if fx.kind == Kind.SHOT and fx.source_id == entry.source_unit and fx.unit_id == entry.target:
					effects.erase(fx)
					break
		LogEntry.Kind.DAMAGE:
			var source: UnitState = sim.unit_by_id(entry.source_unit)
			var target: UnitState = sim.unit_by_id(entry.target)
			if source != null and target != null and _in_melee(source, target):
				var swipe: Fx = _new(Kind.SWIPE, entry.tick, entry.tick + SWIPE_TICKS, Vector2(source.pos), entry.target)
				swipe.color = _side_color(sim, entry.source_unit)
			_number(entry, sim, str(entry.amount) + ("!" if entry.crit else ""), CRIT_COLOR if entry.crit else DAMAGE_COLOR, entry.crit)
		LogEntry.Kind.STATUS_DAMAGE:
			_number(entry, sim, str(entry.amount), UiStyle.STATUS_COLORS.get(entry.status, UiStyle.EMBER), false)
		LogEntry.Kind.COLLAPSE:
			_number(entry, sim, str(entry.amount), COLLAPSE_COLOR, false)
		LogEntry.Kind.HEAL:
			_number(entry, sim, "+%d" % entry.amount, HEAL_COLOR, false)
		LogEntry.Kind.SHIELD:
			_number(entry, sim, "+%d" % entry.amount, UiStyle.SHIELD, false)
		LogEntry.Kind.FIRE:
			var unit: UnitState = sim.unit_by_id(entry.source_unit)
			if unit != null and unit.def.signature != null and unit.def.signature.id == entry.source_ability:
				var popup: Fx = _new(Kind.POPUP, entry.tick, entry.tick + POPUP_TICKS, Vector2(unit.pos), unit.id)
				popup.text = entry.source_ability_name
				popup.color = UiStyle.HIGHLIGHT


func _new(kind: Kind, start: int, end: int, from: Vector2, unit_id: String) -> Fx:
	var fx := Fx.new()
	fx.kind = kind
	fx.start = start
	fx.end = maxi(end, start + 1)
	fx.from = from
	fx.unit_id = unit_id
	effects.append(fx)
	return fx


func _number(entry: LogEntry, sim: CombatSim, text: String, color: Color, big: bool) -> void:
	var unit: UnitState = sim.unit_by_id(entry.target)
	if unit == null or entry.amount <= 0:
		return
	var number: Fx = _new(Kind.NUMBER, entry.tick, entry.tick + NUMBER_TICKS, Vector2(unit.pos), unit.id)
	number.text = text
	number.color = color
	number.big = big


static func _in_melee(source: UnitState, target: UnitState) -> bool:
	var reach: int = source.radius + target.radius + MELEE_GAP
	return ArenaPlane.length_sq(source.pos - target.pos) <= reach * reach


static func _side_color(sim: CombatSim, unit_id: String) -> Color:
	var unit: UnitState = sim.unit_by_id(unit_id)
	return UnitToken.HERO_FILL if unit == null or unit.side == EffectSource.Team.HEROES else UnitToken.ENEMY_FILL


## Where a unit is drawn now, or `fallback` if it's gone.
func _unit_point(unit_id: String, fallback: Vector2) -> Vector2:
	var unit: UnitState = _player.sim.unit_by_id(unit_id) if _player != null else null
	return _player.drawn_position(unit) if unit != null else fallback


func _draw() -> void:
	if _player == null:
		return
	var now: float = _player.drawn_time()
	var font: Font = get_theme_default_font()
	var hex: float = _view.hex_px()
	var stacked: Dictionary[String, int] = {}
	for fx: Fx in effects:
		var t: float = clampf((now - fx.start) / float(fx.end - fx.start), 0.0, 1.0)
		match fx.kind:
			Kind.SHOT:
				var at: Vector2 = fx.from.lerp(_unit_point(fx.unit_id, fx.from), t)
				draw_circle(_view.to_pixel_f(at), maxf(hex * 0.05, 3.0), fx.color)
			Kind.SWIPE:
				var target: Vector2 = _view.to_pixel_f(_unit_point(fx.unit_id, fx.from))
				var color: Color = fx.color
				color.a = 1.0 - t
				draw_line(_view.to_pixel_f(fx.from), target, color, maxf(hex * 0.04, 2.0), true)
			Kind.NUMBER:
				var slot: int = stacked.get(fx.unit_id, 0)
				stacked[fx.unit_id] = slot + 1
				var base: Vector2 = _view.to_pixel_f(_unit_point(fx.unit_id, fx.from))
				var size: int = int(hex * (0.26 if fx.big else 0.2))
				# Numbers on the same unit spread sideways, three abreast.
				var point: Vector2 = base + Vector2(hex * 0.3 + (slot % 3) * size * 1.4, -hex * (0.3 + 0.35 * t) - (slot / 3) * size * 1.05)
				var color: Color = fx.color
				color.a = 1.0 - t * t
				draw_string_outline(font, point, fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, color.a))
				draw_string(font, point, fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
			Kind.POPUP:
				var base: Vector2 = _view.to_pixel_f(_unit_point(fx.unit_id, fx.from))
				var size: int = int(hex * 0.2)
				var width: float = font.get_string_size(fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				var point: Vector2 = base + Vector2(-width / 2.0, -hex * (0.75 + 0.15 * t))
				var color: Color = fx.color
				color.a = 1.0 - t * t
				draw_string_outline(font, point, fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, color.a))
				draw_string(font, point, fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
