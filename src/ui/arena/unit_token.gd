class_name UnitToken
extends Control
## One unit on the board (docs/plans/rebuild-phase3-fight-sandbox.md, sections
## 2 and 8): its figure (FigureArt), standing where the unit is on the plane,
## over a small ring (gold for heroes, red for enemies; phase 5b), with its
## short name under it.
## Figures face right; a unit faces the side its target is on (enemies
## face left until they have one; ArenaView.faces_left). A kit without art
## is drawn as a circle of the unit's own radius instead, warm for heroes
## and cold for enemies.
## A figure is FIGURE_HEXES tall (its whole canvas), so a pup is small and
## a sentinel big. Units are small on the plane (0.2 hex wide since
## playtest gate 1), so the ring is never drawn under MIN_BODY_PX, the bars
## keep a fixed width, and the token's own rect (what hovers, clicks, and
## drags) covers the figure and at least HIT_PX around the unit's point.
## `ArenaView` places it. In a fight, show_state() gives it the unit's bars
## (section 5): HP with any Shield after it and mana under that (only for a
## unit with a mana signature), over the figure's head; a cast bar under
## its feet while it casts; and a tag per status (with stacks for damage
## over time) under its name. A stealthed unit is drawn see-through.
## While placing, a hero's token can be dragged (drops on a token go to the
## view, as if on the hex it stands on), and a hero's tactic is named under
## its name (phase 3b).

const HERO_FILL := UiStyle.TEAL_400
const HERO_TEXT := UiStyle.NAVY_900
const ENEMY_FILL := UiStyle.RIFT_500
const ENEMY_TEXT := UiStyle.CREAM_100
const LINE := UiStyle.NAVY_900
const SHADOW := Color(0.0, 0.0, 0.0, 0.45)
const BAR_BACK := Color(0.04, 0.06, 0.09, 0.85)
const HERO_HP := UiStyle.GOOD
const ENEMY_HP := UiStyle.BAD
const MANA := Color("7aa7ff")
## The ring under a figure's feet, as in the arena look test: gold for
## heroes, red for enemies, over a soft shadow.
const HERO_RING := Color("ffd66e")
const ENEMY_RING := Color("e0503c")
const RING_SHADOW := Color(0.16, 0.12, 0.06, 0.35)
const CAST := UiStyle.GOLD_300
## Tags for the statuses that aren't damage over time (by StatusDef.Kind).
const STATUS_TAGS: Dictionary = {
	StatusDef.Kind.ROOT: "ROOT", StatusDef.Kind.STUN: "STUN", StatusDef.Kind.SLOW: "SLOW", StatusDef.Kind.TAUNT: "TAUNT",
	StatusDef.Kind.SILENCE: "SIL", StatusDef.Kind.MARKED: "MARK", StatusDef.Kind.UNDYING: "UNDY", StatusDef.Kind.ENGAGED: "ENG",
	StatusDef.Kind.STEALTH: "HID", StatusDef.Kind.WARDED: "WARD", StatusDef.Kind.BOOST: "UP", StatusDef.Kind.GROUNDED: "GRND",
}
const STATUS_COLORS: Dictionary = {
	StatusDef.Kind.ROOT: Color("8fbf5a"), StatusDef.Kind.STUN: Color("f0d060"), StatusDef.Kind.SLOW: Color("7fb8d8"),
	StatusDef.Kind.TAUNT: Color("e07050"), StatusDef.Kind.SILENCE: Color("b79cf0"), StatusDef.Kind.MARKED: Color("ff8a80"),
	StatusDef.Kind.UNDYING: Color("f1e6cc"), StatusDef.Kind.ENGAGED: Color("c9993b"),
	StatusDef.Kind.STEALTH: Color("9aa7b8"), StatusDef.Kind.WARDED: Color("8fd0c8"), StatusDef.Kind.BOOST: Color("ffd27f"),
	StatusDef.Kind.GROUNDED: Color("b08a5a"),
}
## How see-through a stealthed unit is drawn.
const STEALTH_ALPHA: float = 0.4
## How far above its shadow a flier without art is drawn, in its own radii
## (a flier's figure is drawn in the air already).
const FLIGHT_LIFT: float = 0.35
## A figure's canvas height, in hexes.
const FIGURE_HEXES: float = 1.35
## The ring under a figure's feet: how much flatter than wide it is.
const RING_FLAT: float = 0.4
## The smallest circle drawn, the smallest half-width to hover or grab, and
## the bars' and text's sizes, in pixels.
const MIN_BODY_PX: float = 8.0
const HIT_PX: float = 16.0
const BAR_WIDTH: float = 36.0
const BAR_HEIGHT: float = 4.0
const LABEL_SIZE: int = 14
const TAG_SIZE: int = 10

var unit_id: String
var label_text: String
## While placing: the hero's tactic's name ("": none).
var tactic_label: String = ""
## While placing: the hero's path, as ArenaView.path_tag names it ("": none).
var path_label: String = ""
var side: EffectSource.Team
## Its radius on the plane, and where it stands there.
var radius: int
var flying: bool = false
var plane_pos: Vector2i
## Its figure (FigureArt's key; null texture without art), what the figure
## covers of its canvas, and which way it faces.
var art_key: String = ""
var figure: Texture2D = null
var figure_bounds: Rect2 = Rect2(Vector2.ZERO, FigureArt.CANVAS)
var facing_left: bool = false
## Its radius on screen, the figure's pixels per canvas pixel, and where
## the unit's point is in the token's rect (set by place()).
var radius_px: float = 0.0
var figure_scale: float = 0.0
var feet: Vector2 = Vector2.ZERO
## In a fight (show_state): shares of the bars, 0 to 1; mana and cast are -1
## when there's no bar to show.
var in_fight: bool = false
var hp_share: float = 1.0
var shield_share: float = 0.0
var mana_share: float = -1.0
var cast_share: float = -1.0
## [text, color] per status, in the unit's status order.
var status_tags: Array[Array] = []
var _view: ArenaView = null


static func make(id: String, text: String, team: EffectSource.Team, unit_radius: int, flies: bool = false, figure_key: String = "") -> UnitToken:
	var token := UnitToken.new()
	token.unit_id = id
	token.label_text = text
	token.side = team
	token.radius = unit_radius
	token.flying = flies
	token.art_key = figure_key
	token.figure = FigureArt.texture(figure_key)
	token.figure_bounds = FigureArt.bounds(figure_key)
	token.facing_left = team != EffectSource.Team.HEROES
	token.name = id.replace("#", "_")
	token.mouse_filter = Control.MOUSE_FILTER_PASS
	token.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return token


func is_hero() -> bool:
	return side == EffectSource.Team.HEROES


func has_figure() -> bool:
	return figure != null


## The screen point the unit stands on (its point on the plane).
func center() -> Vector2:
	return position + feet


## The radius its circle (or the ring under its figure) is drawn at.
func body_px() -> float:
	return maxf(radius_px, MIN_BODY_PX)


## Where it was last drawn on the plane (between whole units mid-step).
var drawn_at: Vector2 = Vector2.ZERO


## Puts it where `view` draws its plane position, at the view's scale.
func place(view: ArenaView) -> void:
	place_at(view, Vector2(plane_pos))


## Puts it where `view` draws `point` on the plane.
func place_at(view: ArenaView, point: Vector2) -> void:
	_view = view
	drawn_at = point
	radius_px = radius * view.scale_px
	figure_scale = FIGURE_HEXES * view.hex_px() / FigureArt.CANVAS.y
	var at: Vector2 = view.to_pixel_f(point)
	var half: float = maxf(radius_px, HIT_PX)
	var rect := Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0)
	if has_figure():
		var drawn: Rect2 = figure_rect()
		rect = rect.merge(Rect2(drawn.position + at, drawn.size))
	position = rect.position
	size = rect.size
	feet = at - rect.position
	queue_redraw()


## What the figure covers, relative to the unit's point.
func figure_rect() -> Rect2:
	var left: float = FigureArt.FEET.x - figure_bounds.end.x if facing_left else figure_bounds.position.x - FigureArt.FEET.x
	return Rect2(Vector2(left, figure_bounds.position.y - FigureArt.FEET.y) * figure_scale, figure_bounds.size * figure_scale)


## Where the top of its head is (the top of the circle without art),
## relative to the unit's point.
func head_offset() -> Vector2:
	if has_figure():
		return Vector2(0.0, figure_rect().position.y)
	return Vector2(0.0, -body_px() * ((1.0 + FLIGHT_LIFT) if flying else 1.0))


## The middle of its body, relative to the unit's point (where shots and
## swipes land).
func body_offset() -> Vector2:
	if has_figure():
		var drawn: Rect2 = figure_rect()
		return Vector2(0.0, (drawn.position.y + minf(drawn.end.y, 0.0)) / 2.0)
	return Vector2(0.0, -body_px() * FLIGHT_LIFT if flying else 0.0)


## Where the top of its bars is, relative to the unit's point (numbers and
## names pop up over it).
func over_bars_offset() -> Vector2:
	return head_offset() - Vector2(0.0, 3.0 + BAR_HEIGHT * (2.0 if mana_share >= 0.0 else 1.0) + 1.0)


## Reads the unit's bars and statuses (a fight's `tick` for the cast bar).
func show_state(unit: UnitState, tick: int) -> void:
	in_fight = true
	hp_share = float(unit.hp) / maxf(unit.max_hp, 1.0)
	shield_share = float(unit.shield) / maxf(unit.max_hp, 1.0)
	mana_share = minf(float(unit.mana) / unit.mana_cap, 1.0) if unit.mana_cap > 0 else -1.0
	cast_share = -1.0
	var signature: AbilityState = unit.signature
	if signature != null and signature.casting() and signature.def.cast_ticks > 0:
		cast_share = clampf(1.0 - float(signature.cast_ends_at - tick) / signature.def.cast_ticks, 0.0, 1.0)
	status_tags.clear()
	for state: StatusState in unit.statuses:
		status_tags.append(status_tag(state))
	modulate.a = STEALTH_ALPHA if Statuses.is_stealthed(unit) else 1.0
	queue_redraw()


## A status's short tag and color: "STUN", or "BRN 4" with its stacks.
static func status_tag(state: StatusState) -> Array:
	var tag: String = STATUS_TAGS.get(state.def.kind, state.def.name.left(4).to_upper())
	if state.def.kind == StatusDef.Kind.DAMAGE_OVER_TIME:
		tag = "%s %d" % [UiStyle.STATUS_TAGS.get(state.def.id, state.def.name.left(3).to_upper()), state.total_stacks()]
		return [tag, UiStyle.STATUS_COLORS.get(state.def.id, UiStyle.EMBER)]
	if state.timed_stacks() > 1:
		# A stacking boost, or stacked Marks (phase 5c step 5c): "UP 3".
		tag = "%s %d" % [tag, state.timed_stacks()]
	return [tag, STATUS_COLORS.get(state.def.kind, UiStyle.TEXT)]


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _view == null or not _view.can_drag(self):
		return null
	if get_viewport().gui_is_dragging():
		_set_preview()
	return {"hero": unit_id}


## A see-through copy of the token under the pointer while it's dragged.
func _set_preview() -> void:
	var preview := UnitToken.make(unit_id, label_text, side, radius, flying, art_key)
	preview.radius_px = radius_px
	preview.figure_scale = figure_scale
	preview.facing_left = facing_left
	preview.size = size
	preview.feet = feet
	preview.modulate.a = 0.8
	var holder := Control.new()
	holder.add_child(preview)
	preview.position = -feet
	set_drag_preview(holder)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _view != null and _view._can_drop_data(center(), data)


## A drop anywhere on the token (its figure reaches into the hex behind)
## counts for the hex it stands on.
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_view._drop_data(center(), data)


func _draw() -> void:
	var below: float
	var body_radius: float = body_px()
	if has_figure():
		# The ring under its feet, then the figure standing on it.
		var ring_radius: float = maxf(body_radius, MIN_BODY_PX * 1.25)
		draw_set_transform(feet, 0.0, Vector2(1.0, RING_FLAT))
		draw_circle(Vector2.ZERO, ring_radius, RING_SHADOW)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 32, HERO_RING if is_hero() else ENEMY_RING, 2.5 / RING_FLAT, true)
		draw_set_transform(feet, 0.0, Vector2(-figure_scale if facing_left else figure_scale, figure_scale))
		draw_texture_rect(figure, Rect2(-FigureArt.FEET, FigureArt.CANVAS), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		below = feet.y + ring_radius * RING_FLAT + 2.0
	else:
		var body: Vector2 = feet
		if flying:
			draw_circle(feet + Vector2(0.0, body_radius * 0.15), body_radius * 0.8, SHADOW)
			body -= Vector2(0.0, body_radius * FLIGHT_LIFT)
		draw_circle(body, body_radius, HERO_FILL if is_hero() else ENEMY_FILL)
		draw_arc(body, body_radius, 0.0, TAU, 32, LINE, 1.5, true)
		below = body.y + body_radius + 2.0
	var font: Font = get_theme_default_font()
	if in_fight and cast_share >= 0.0:
		var left: float = feet.x - BAR_WIDTH / 2.0
		draw_rect(Rect2(left, below, BAR_WIDTH, BAR_HEIGHT * 0.75), BAR_BACK)
		draw_rect(Rect2(left, below, BAR_WIDTH * cast_share, BAR_HEIGHT * 0.75), CAST)
		below += BAR_HEIGHT + 1.0
	var width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	var baseline: Vector2 = Vector2(feet.x - width / 2.0, below + 1.0 + font.get_ascent(LABEL_SIZE))
	# On a dark plate, so it reads over the island's sand.
	var plate := Rect2(baseline.x - 4.0, below, width + 8.0, font.get_height(LABEL_SIZE) + 2.0)
	draw_style_box(_name_plate(), plate)
	draw_string(font, baseline, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, HERO_RING if is_hero() else UiStyle.CREAM_100)
	below = baseline.y + font.get_descent(LABEL_SIZE) + 2.0
	if not in_fight:
		for tag: Array in [[path_label, UiStyle.GOLD_300], [tactic_label, UiStyle.CREAM_300]]:
			var text: String = tag[0]
			if text.is_empty():
				continue
			var tag_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE + 1).x
			var tag_at := Vector2(feet.x - tag_width / 2.0, below + font.get_ascent(TAG_SIZE + 1))
			draw_style_box(_name_plate(), Rect2(tag_at.x - 3.0, below, tag_width + 6.0, font.get_height(TAG_SIZE + 1)))
			draw_string(font, tag_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE + 1, tag[1])
			below = tag_at.y + font.get_descent(TAG_SIZE + 1) + 1.0
	if in_fight:
		_draw_bars(below, font)


static var _plate: StyleBoxFlat = null


static func _name_plate() -> StyleBoxFlat:
	if _plate == null:
		_plate = UiStyle.box(Color(UiStyle.NAVY_900, 0.78), Color(0, 0, 0, 0), 0, 4)
	return _plate


func _draw_bars(below: float, font: Font) -> void:
	var left: float = feet.x - BAR_WIDTH / 2.0
	var y: float = feet.y + over_bars_offset().y + 1.0
	draw_rect(Rect2(left, y, BAR_WIDTH, BAR_HEIGHT), BAR_BACK)
	draw_rect(Rect2(left, y, BAR_WIDTH * clampf(hp_share, 0.0, 1.0), BAR_HEIGHT), HERO_HP if is_hero() else ENEMY_HP)
	if shield_share > 0.0:
		var start: float = clampf(hp_share, 0.0, 1.0)
		var shield_width: float = minf(shield_share, 1.0 - start) if start < 1.0 else minf(shield_share, 1.0)
		var shield_left: float = left + BAR_WIDTH * (start if start < 1.0 else 1.0 - shield_width)
		draw_rect(Rect2(shield_left, y, BAR_WIDTH * shield_width, BAR_HEIGHT), UiStyle.SHIELD)
	if mana_share >= 0.0:
		var mana_y: float = y + BAR_HEIGHT + 1.0
		draw_rect(Rect2(left, mana_y, BAR_WIDTH, BAR_HEIGHT), BAR_BACK)
		draw_rect(Rect2(left, mana_y, BAR_WIDTH * clampf(mana_share, 0.0, 1.0), BAR_HEIGHT), MANA)
	var x: float = left
	for tag: Array in status_tags:
		var text: String = tag[0]
		var tag_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE).x + 4.0
		if x + tag_width > left + BAR_WIDTH * 1.5:
			x = left
			below += TAG_SIZE + 3.0
		draw_rect(Rect2(x, below, tag_width, TAG_SIZE + 2.0), BAR_BACK)
		draw_string(font, Vector2(x + 2.0, below + TAG_SIZE), text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE, tag[1])
		x += tag_width + 2.0
