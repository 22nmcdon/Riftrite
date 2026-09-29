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
##   AREA_WARNING     the shape on the ground, filling up until it lands
##   AREA_LANDED      a flash of the shape
##   PUSH, LEAP, CHARGE, HOP   the moved unit slides from where it was to
##                    where it went (the sim moves it at once; moved_position)
##   DEATH            a fading ghost where it fell
##   SUMMON           a pulse where the summon appears
##   PHASE            the phase's name over the unit
##   TACTIC           what a hero's tactic did, over it ("Holds its ground")
##   AURA             a faint ring round the holder while the aura holds
##   COLLAPSE_RING    the ring about to crumble striped, crumbled ground dark
##   GUARD            a brass number on the guard: what it took for an ally
## Zones, snares, and walls (phase 4) are drawn on the ground straight from
## the sim's state (CombatSim.zones, snares, walls) for as long as they last,
## so a skip or seek never loses them.
## Target lines (for a hovered unit, or all with a toggle; brighter for a
## Taunt) and Engage links come from the sim's state. The ground things are
## drawn under the tokens by ArenaView (draw_ground); the rest over them.
## Each lasts a set number of ticks of fight time (FightPlayer.drawn_time),
## so it pauses and changes speed with the fight. It only reads.

## How long each kind lasts, in ticks.
const NUMBER_TICKS: int = 16
const SWIPE_TICKS: int = 4
const POPUP_TICKS: int = 24
const PHASE_TICKS: int = 40
const LANDED_TICKS: int = 6
const MOVE_TICKS: int = 5
const GHOST_TICKS: int = 12
const PULSE_TICKS: int = 8
## A swipe is drawn when the target is within the attacker's melee reach,
## plus this much slack (plane units): hits from melee distance, not areas or
## shots.
const MELEE_SLACK: int = 100
## A batch this big (a skip or seek) isn't animated.
const MAX_ANIMATED: int = 60
const DAMAGE_COLOR := Color("f1e6cc")
const CRIT_COLOR := Color("ffd166")
const HEAL_COLOR := UiStyle.GOOD
const COLLAPSE_COLOR := UiStyle.EMBER
## Areas by the caster's side: enemies' hostile, heroes' their own brass.
const ENEMY_AREA := Color(0.88, 0.36, 0.23)
const HERO_AREA := Color(0.91, 0.78, 0.47)
const CRUMBLED := Color(0.02, 0.01, 0.03, 0.72)
const WARNED := Color(0.88, 0.44, 0.23, 0.22)
const TARGET_LINE := Color(1, 1, 1, 0.28)
const TAUNT_LINE := Color(0.88, 0.44, 0.23, 0.8)
const ENGAGE_LINK := UiStyle.GOLD_300

enum Kind { SHOT, SWIPE, NUMBER, POPUP, AREA, LANDED, GHOST, PULSE }
## Where on a unit an effect is drawn (_lift).
enum Lift { BODY, OVER_BARS }


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
	## Areas: the shape's kind and size (hexes), and where an aimed one ends.
	var shape: String = ""
	var size: int = 0
	var to: Vector2 = Vector2.ZERO


var effects: Array[Fx] = []
## Units sliding after a push, leap, charge, or hop, by id.
var moves: Dictionary[String, Fx] = {}
## Auras holding now: "holder:ability" -> holder id (a lookup; drawn in the
## fight's order).
var auras: Dictionary[String, String] = {}
## The ground left after the ring being warned crumbles (none: size 0).
var warned_safe: Rect2i = Rect2i()
## Target lines for every unit (a toggle), or only the hovered one.
var all_targets: bool = false
var hovered: String = ""
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
	moves.clear()
	auras.clear()
	warned_safe = Rect2i()
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
	for unit_id: String in moves.keys():
		if now >= moves[unit_id].end:
			moves.erase(unit_id)
	if warned_safe.size != Vector2i.ZERO and player.sim.safe == warned_safe:
		warned_safe = Rect2i()
	queue_redraw()


## Where a sliding unit is drawn (after a push, leap, charge, or hop), or
## `otherwise` if it isn't sliding.
func moved_position(unit_id: String, otherwise: Vector2, now: float) -> Vector2:
	if not moves.has(unit_id):
		return otherwise
	var move: Fx = moves[unit_id]
	# Over (a frame can outlast a slide): where it stands now, not where it
	# landed.
	if now >= move.end:
		return otherwise
	return move.from.lerp(move.to, clampf((now - move.start) / float(move.end - move.start), 0.0, 1.0))


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
		LogEntry.Kind.GUARD:
			var guard: UnitState = sim.unit_by_id(entry.source_unit)
			if guard != null and entry.amount > 0:
				var took: Fx = _new(Kind.NUMBER, entry.tick, entry.tick + NUMBER_TICKS, Vector2(guard.pos), guard.id)
				took.text = str(entry.amount)
				took.color = UiStyle.GOLD_300
		LogEntry.Kind.SHIELD:
			_number(entry, sim, "+%d" % entry.amount, UiStyle.SHIELD, false)
		LogEntry.Kind.FIRE:
			var unit: UnitState = sim.unit_by_id(entry.source_unit)
			if unit != null and unit.def.signature != null and unit.def.signature.id == entry.source_ability:
				var popup: Fx = _new(Kind.POPUP, entry.tick, entry.tick + POPUP_TICKS, Vector2(unit.pos), unit.id)
				popup.text = entry.source_ability_name
				popup.color = UiStyle.HIGHLIGHT
		LogEntry.Kind.TACTIC:
			var holder: UnitState = sim.unit_by_id(entry.source_unit)
			if holder != null:
				var said: Fx = _new(Kind.POPUP, entry.tick, entry.tick + POPUP_TICKS, Vector2(holder.pos), holder.id)
				said.text = tactic_popup(entry)
				said.color = UiStyle.GOLD_300
		LogEntry.Kind.AREA_WARNING, LogEntry.Kind.AREA_LANDED:
			var warning: bool = entry.kind == LogEntry.Kind.AREA_WARNING
			var area: Fx = _new(Kind.AREA if warning else Kind.LANDED, entry.tick, entry.end_tick if warning else entry.tick + LANDED_TICKS, Vector2(entry.from_pos), "")
			var parts: PackedStringArray = entry.shape.split(" ")
			area.shape = parts[0]
			area.size = parts[1].to_int() if parts.size() > 1 else 1
			area.to = Vector2(entry.to_pos)
			var caster: UnitState = sim.unit_by_id(entry.source_unit)
			area.color = HERO_AREA if caster != null and caster.side == EffectSource.Team.HEROES else ENEMY_AREA
		LogEntry.Kind.PUSH, LogEntry.Kind.LEAP, LogEntry.Kind.CHARGE, LogEntry.Kind.HOP:
			if entry.from_pos != entry.to_pos:
				var mover: String = entry.target if entry.kind == LogEntry.Kind.PUSH else entry.source_unit
				var move := Fx.new()
				move.start = entry.tick
				move.end = entry.tick + MOVE_TICKS
				move.from = Vector2(entry.from_pos)
				move.to = Vector2(entry.to_pos)
				move.unit_id = mover
				moves[mover] = move
		LogEntry.Kind.DEATH:
			var ghost: Fx = _new(Kind.GHOST, entry.tick, entry.tick + GHOST_TICKS, Vector2(entry.to_pos), entry.target)
			ghost.color = _side_color(sim, entry.target)
		LogEntry.Kind.SUMMON:
			if entry.note.is_empty():
				var pulse: Fx = _new(Kind.PULSE, entry.tick, entry.tick + PULSE_TICKS, Vector2(entry.to_pos), entry.target)
				pulse.color = _side_color(sim, entry.target)
		LogEntry.Kind.PHASE:
			var target: UnitState = sim.unit_by_id(entry.target)
			if target != null:
				var phase: Fx = _new(Kind.POPUP, entry.tick, entry.tick + PHASE_TICKS, Vector2(target.pos), target.id)
				phase.text = entry.note
				phase.color = UiStyle.EMBER
				phase.big = true
		LogEntry.Kind.AURA:
			var key: String = "%s:%s" % [entry.source_unit, entry.source_ability]
			if entry.note.begins_with("starts"):
				auras[key] = entry.source_unit
			else:
				auras.erase(key)
		LogEntry.Kind.COLLAPSE_RING:
			if entry.note == "warned":
				warned_safe = Rect2i(entry.from_pos, entry.to_pos - entry.from_pos)


## What a TACTIC line shows over its unit: the note's first part, without
## any payoff in brackets ("Holds its ground", "Moves out", "Mend waits").
static func tactic_popup(entry: LogEntry) -> String:
	var said: String = entry.note.get_slice(":", 0).get_slice(" (", 0)
	return said.left(1).to_upper() + said.substr(1)


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
	var reach: int = source.melee_reach + MELEE_SLACK
	return ArenaPlane.length_sq(source.pos - target.pos) <= reach * reach


static func _side_color(sim: CombatSim, unit_id: String) -> Color:
	var unit: UnitState = sim.unit_by_id(unit_id)
	return UnitToken.HERO_FILL if unit == null or unit.side == EffectSource.Team.HEROES else UnitToken.ENEMY_FILL


## Where a unit is drawn now, or `fallback` if it's gone.
func _unit_point(unit_id: String, fallback: Vector2) -> Vector2:
	var unit: UnitState = _player.sim.unit_by_id(unit_id) if _player != null else null
	return _player.drawn_position(unit) if unit != null else fallback


## How far above a unit's point its body, or the top of its bars, is drawn
## (its token's figure), in pixels; nothing if it has no token.
func _lift(unit_id: String, lift: Lift) -> Vector2:
	var unit_token: UnitToken = _view.token(unit_id)
	if unit_token == null:
		return Vector2.ZERO
	return unit_token.body_offset() if lift == Lift.BODY else unit_token.over_bars_offset()


func _draw() -> void:
	if _player == null:
		return
	var now: float = _player.drawn_time()
	for key: String in auras:
		var holder: UnitState = _player.sim.unit_by_id(auras[key])
		if holder != null and holder.alive:
			var ring: Color = _side_color(_player.sim, holder.id)
			ring.a = 0.45
			draw_arc(_view.to_pixel_f(_unit_point(holder.id, Vector2(holder.pos))), maxf(holder.radius * _view.scale_px, UnitToken.MIN_BODY_PX) * 1.6, 0.0, TAU, 40, ring, 2.0, true)
	var font: Font = get_theme_default_font()
	var hex: float = _view.hex_px()
	var stacked: Dictionary[String, int] = {}
	for fx: Fx in effects:
		var t: float = clampf((now - fx.start) / float(fx.end - fx.start), 0.0, 1.0)
		match fx.kind:
			Kind.SHOT:
				var at: Vector2 = fx.from.lerp(_unit_point(fx.unit_id, fx.from), t)
				draw_circle(_view.to_pixel_f(at) + _lift(fx.unit_id, Lift.BODY), maxf(hex * 0.05, 3.0), fx.color)
			Kind.SWIPE:
				var lift: Vector2 = _lift(fx.unit_id, Lift.BODY)
				var target: Vector2 = _view.to_pixel_f(_unit_point(fx.unit_id, fx.from)) + lift
				var color: Color = fx.color
				color.a = 1.0 - t
				draw_line(_view.to_pixel_f(fx.from) + lift, target, color, maxf(hex * 0.04, 2.0), true)
			Kind.NUMBER:
				var slot: int = stacked.get(fx.unit_id, 0)
				stacked[fx.unit_id] = slot + 1
				var base: Vector2 = _view.to_pixel_f(_unit_point(fx.unit_id, fx.from)) + _lift(fx.unit_id, Lift.OVER_BARS)
				var size: int = int(hex * (0.26 if fx.big else 0.2))
				# Numbers on the same unit spread sideways, three abreast.
				var point: Vector2 = base + Vector2(hex * 0.3 + (slot % 3) * size * 1.4, -hex * 0.35 * t - (slot / 3) * size * 1.05)
				var color: Color = fx.color
				color.a = 1.0 - t * t
				draw_string_outline(font, point, fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, color.a))
				draw_string(font, point, fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
			Kind.GHOST:
				var color: Color = fx.color
				color.a = 0.6 * (1.0 - t)
				draw_arc(_view.to_pixel_f(fx.from), hex * 0.4 * (1.0 + 0.3 * t), 0.0, TAU, 32, color, 3.0, true)
			Kind.PULSE:
				var color: Color = fx.color
				color.a = 1.0 - t
				draw_arc(_view.to_pixel_f(fx.from), hex * (0.4 + 0.4 * t), 0.0, TAU, 32, color, 3.0, true)
			Kind.POPUP:
				var base: Vector2 = _view.to_pixel_f(_unit_point(fx.unit_id, fx.from)) + _lift(fx.unit_id, Lift.OVER_BARS)
				var size: int = int(hex * (0.26 if fx.big else 0.2))
				var width: float = font.get_string_size(fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				var point: Vector2 = base + Vector2(-width / 2.0, -hex * (0.45 + 0.15 * t))
				var color: Color = fx.color
				color.a = 1.0 - t * t
				draw_string_outline(font, point, fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, color.a))
				draw_string(font, point, fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# --- the ground (drawn under the tokens by ArenaView) ------------------------------

## Crumbled and warned ground, area warnings and flashes, target lines, and
## Engage links, on `canvas` (the ArenaView, from its _draw).
func draw_ground(canvas: CanvasItem) -> void:
	if _player == null:
		return
	var sim: CombatSim = _player.sim
	var now: float = _player.drawn_time()
	_draw_outside(canvas, sim.safe, CRUMBLED)
	if warned_safe.size != Vector2i.ZERO:
		_draw_between(canvas, sim.safe, warned_safe, WARNED)
	_draw_placed(canvas, sim)
	for fx: Fx in effects:
		if fx.kind == Kind.AREA or fx.kind == Kind.LANDED:
			var t: float = clampf((now - fx.start) / float(fx.end - fx.start), 0.0, 1.0)
			var fill: Color = fx.color
			fill.a = 0.06 + 0.2 * t if fx.kind == Kind.AREA else 0.35 * (1.0 - t)
			var line: Color = fx.color
			line.a = 0.9 if fx.kind == Kind.AREA else 0.5 * (1.0 - t)
			_draw_shape(canvas, fx, fill, line)
	for unit: UnitState in sim.units:
		if not unit.alive:
			continue
		var from: Vector2 = _view.to_pixel_f(_unit_point(unit.id, Vector2(unit.pos)))
		var taunter: UnitState = Statuses.taunter(sim, unit)
		if taunter != null:
			canvas.draw_line(from, _view.to_pixel_f(_unit_point(taunter.id, Vector2(taunter.pos))), TAUNT_LINE, 2.0, true)
		elif unit.target != null and unit.target.alive and (all_targets or unit.id == hovered):
			canvas.draw_line(from, _view.to_pixel_f(_unit_point(unit.target.id, Vector2(unit.target.pos))), TARGET_LINE, 1.5, true)
		for state: StatusState in unit.statuses:
			if state.def.kind == StatusDef.Kind.ENGAGED and state.source != null:
				var engager: UnitState = sim.unit_by_id(state.source.unit_id)
				if engager != null and engager.alive:
					canvas.draw_line(from, _view.to_pixel_f(_unit_point(engager.id, Vector2(engager.pos))), ENGAGE_LINK, 4.0, true)


## Zones, snares, and walls on the ground now (phase 4), from the sim.
func _draw_placed(canvas: CanvasItem, sim: CombatSim) -> void:
	for zone: Areas.Pending in sim.zones:
		if sim.tick >= zone.until_tick:
			continue
		var fx := Fx.new()
		fx.shape = ShapeDef.KIND_NAMES[zone.effect.shape.kind]
		fx.size = zone.effect.shape.size
		fx.from = Vector2(zone.origin)
		fx.to = Vector2(ArenaPlane.along(zone.origin, zone.dir, zone.effect.shape.size * HexGrid.HEX))
		var color: Color = _side_color(sim, zone.unit.id)
		var fill: Color = color
		fill.a = 0.14
		var line: Color = color
		line.a = 0.7
		_draw_shape(canvas, fx, fill, line)
	for snare: Snares.Snare in sim.snares:
		var at: Vector2 = _view.to_pixel_f(Vector2(snare.pos))
		var reach: float = maxf(Snares.RADIUS * _view.scale_px, 6.0)
		ArenaView.draw_snare(canvas, at, reach, _side_color(sim, snare.unit.id))
	for wall: Walls.Wall in sim.walls:
		if sim.tick >= wall.until_tick:
			continue
		var color: Color = HERO_AREA if wall.side == EffectSource.Team.HEROES else ENEMY_AREA
		canvas.draw_line(_view.to_pixel_f(Vector2(wall.a)), _view.to_pixel_f(Vector2(wall.b)), color, 6.0, true)


func _draw_shape(canvas: CanvasItem, fx: Fx, fill: Color, line: Color) -> void:
	var hex: float = HexGrid.HEX
	match fx.shape:
		"circle":
			var center: Vector2 = _view.to_pixel_f(fx.from)
			var radius: float = fx.size * hex * _view.scale_px
			canvas.draw_circle(center, radius, fill)
			canvas.draw_arc(center, radius, 0.0, TAU, 48, line, 2.0, true)
		"ring":
			var center: Vector2 = _view.to_pixel_f(fx.from)
			var outer: float = (fx.size * hex + HexGrid.HALF_HEX) * _view.scale_px
			var inner: float = maxf(fx.size * hex - HexGrid.HALF_HEX, 0.0) * _view.scale_px
			canvas.draw_arc(center, (outer + inner) / 2.0, 0.0, TAU, 48, fill, outer - inner, true)
			canvas.draw_arc(center, outer, 0.0, TAU, 48, line, 2.0, true)
			canvas.draw_arc(center, inner, 0.0, TAU, 48, line, 2.0, true)
		_:
			var along: Vector2 = (fx.to - fx.from).normalized()
			var across := Vector2(-along.y, along.x)
			var far_half: float = (HexGrid.HALF_HEX if fx.shape == "line" else 3.0 * HexGrid.HALF_HEX)
			var corners := PackedVector2Array([
				_view.to_pixel_f(fx.from + across * HexGrid.HALF_HEX), _view.to_pixel_f(fx.to + across * far_half),
				_view.to_pixel_f(fx.to - across * far_half), _view.to_pixel_f(fx.from - across * HexGrid.HALF_HEX)])
			canvas.draw_colored_polygon(corners, fill)
			var outline: PackedVector2Array = corners.duplicate()
			outline.append(corners[0])
			canvas.draw_polyline(outline, line, 2.0, true)


## Fills the board outside `inside` (crumbled ground).
func _draw_outside(canvas: CanvasItem, inside: Rect2i, color: Color) -> void:
	_draw_between(canvas, _view.drawn_rect, inside, color)


## Fills what's in `outer` but not in `inner` (both on the plane).
func _draw_between(canvas: CanvasItem, outer: Rect2i, inner: Rect2i, color: Color) -> void:
	if inner.encloses(outer):
		return
	var bands: Array[Rect2i] = [
		Rect2i(outer.position.x, outer.position.y, outer.size.x, inner.position.y - outer.position.y),
		Rect2i(outer.position.x, inner.end.y, outer.size.x, outer.end.y - inner.end.y),
		Rect2i(outer.position.x, inner.position.y, inner.position.x - outer.position.x, inner.size.y),
		Rect2i(inner.end.x, inner.position.y, outer.end.x - inner.end.x, inner.size.y)]
	for band: Rect2i in bands:
		if band.size.x <= 0 or band.size.y <= 0:
			continue
		canvas.draw_rect(_view.rect_to_pixels(band), color)
