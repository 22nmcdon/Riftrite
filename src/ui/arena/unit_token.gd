class_name UnitToken
extends Control
## One unit on the board (docs/plans/rebuild-phase3-fight-sandbox.md, sections
## 2 and 8): a placeholder circle of the unit's own radius, warm for heroes
## and cold for enemies, with a short label. A flier sits over a shadow.
## `ArenaView` places it. In a fight, show_state() gives it the unit's bars
## (section 5): HP with any Shield after it, mana under that (only for a unit
## with a mana signature), a cast bar under the circle while it casts, and
## a tag per status (with stacks for damage over time).
## While placing, a hero's token can be dragged (drops on a token go to the
## view, as if on the hex under it).

const HERO_FILL := UiStyle.BRASS_500
const HERO_TEXT := UiStyle.INK_900
const ENEMY_FILL := UiStyle.RIFT_500
const ENEMY_TEXT := UiStyle.PARCHMENT_100
const LINE := UiStyle.INK_900
const SHADOW := Color(0.0, 0.0, 0.0, 0.45)
const BAR_BACK := Color(0.08, 0.06, 0.1, 0.85)
const HERO_HP := UiStyle.GOOD
const ENEMY_HP := UiStyle.BAD
const MANA := Color("7aa7ff")
const CAST := UiStyle.BRASS_300
## Tags for the statuses that aren't damage over time (by StatusDef.Kind).
const STATUS_TAGS: Dictionary = {
	StatusDef.Kind.ROOT: "ROOT", StatusDef.Kind.STUN: "STUN", StatusDef.Kind.SLOW: "SLOW", StatusDef.Kind.TAUNT: "TAUNT",
	StatusDef.Kind.SILENCE: "SIL", StatusDef.Kind.MARKED: "MARK", StatusDef.Kind.UNDYING: "UNDY", StatusDef.Kind.ENGAGED: "ENG",
}
const STATUS_COLORS: Dictionary = {
	StatusDef.Kind.ROOT: Color("8fbf5a"), StatusDef.Kind.STUN: Color("f0d060"), StatusDef.Kind.SLOW: Color("7fb8d8"),
	StatusDef.Kind.TAUNT: Color("e07050"), StatusDef.Kind.SILENCE: Color("b79cf0"), StatusDef.Kind.MARKED: Color("ff8a80"),
	StatusDef.Kind.UNDYING: Color("f1e6cc"), StatusDef.Kind.ENGAGED: Color("c9993b"),
}
## How far above its shadow a flier is drawn, in its own radii.
const FLIGHT_LIFT: float = 0.35

var unit_id: String
var label_text: String
var side: EffectSource.Team
## Its radius on the plane, and where it stands there.
var radius: int
var flying: bool = false
var plane_pos: Vector2i
## Its radius on screen (set by place()).
var radius_px: float = 0.0
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


static func make(id: String, text: String, team: EffectSource.Team, unit_radius: int, flies: bool = false) -> UnitToken:
	var token := UnitToken.new()
	token.unit_id = id
	token.label_text = text
	token.side = team
	token.radius = unit_radius
	token.flying = flies
	token.name = id.replace("#", "_")
	token.mouse_filter = Control.MOUSE_FILTER_PASS
	return token


func is_hero() -> bool:
	return side == EffectSource.Team.HEROES


## The screen point its circle is centered on.
func center() -> Vector2:
	return position + Vector2(radius_px, radius_px)


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
	size = Vector2(radius_px, radius_px) * 2.0
	position = view.to_pixel_f(point) - Vector2(radius_px, radius_px)
	queue_redraw()


## Reads the unit's bars and statuses (a fight's `tick` for the cast bar).
func show_state(unit: UnitState, tick: int) -> void:
	in_fight = true
	hp_share = float(unit.hp) / maxf(unit.max_hp, 1.0)
	shield_share = float(unit.shield) / maxf(unit.max_hp, 1.0)
	mana_share = float(unit.mana) / unit.mana_cap if unit.mana_cap > 0 else -1.0
	cast_share = -1.0
	var signature: AbilityState = unit.signature
	if signature != null and signature.casting() and signature.def.cast_ticks > 0:
		cast_share = clampf(1.0 - float(signature.cast_ends_at - tick) / signature.def.cast_ticks, 0.0, 1.0)
	status_tags.clear()
	for state: StatusState in unit.statuses:
		status_tags.append(status_tag(state))
	queue_redraw()


## A status's short tag and color: "STUN", or "BRN 4" with its stacks.
static func status_tag(state: StatusState) -> Array:
	var tag: String = STATUS_TAGS.get(state.def.kind, state.def.name.left(4).to_upper())
	if state.def.kind == StatusDef.Kind.DAMAGE_OVER_TIME:
		tag = "%s %d" % [UiStyle.STATUS_TAGS.get(state.def.id, state.def.name.left(3).to_upper()), state.total_stacks()]
		return [tag, UiStyle.STATUS_COLORS.get(state.def.id, UiStyle.EMBER)]
	return [tag, STATUS_COLORS.get(state.def.kind, UiStyle.TEXT)]


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _view == null or not _view.can_drag(self):
		return null
	if get_viewport().gui_is_dragging():
		_set_preview()
	return {"hero": unit_id}


## A see-through copy of the token under the pointer while it's dragged.
func _set_preview() -> void:
	var preview := UnitToken.make(unit_id, label_text, side, radius, flying)
	preview.radius_px = radius_px
	preview.size = size
	preview.modulate.a = 0.8
	var holder := Control.new()
	holder.add_child(preview)
	preview.position = -size / 2.0
	set_drag_preview(holder)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return _view != null and _view._can_drop_data(at_position + position, data)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	_view._drop_data(at_position + position, data)


func _draw() -> void:
	var middle: Vector2 = Vector2(radius_px, radius_px)
	var body: Vector2 = middle
	if flying:
		draw_circle(middle + Vector2(0.0, radius_px * 0.15), radius_px * 0.8, SHADOW)
		body -= Vector2(0.0, radius_px * FLIGHT_LIFT)
	draw_circle(body, radius_px, HERO_FILL if is_hero() else ENEMY_FILL)
	draw_arc(body, radius_px, 0.0, TAU, 40, LINE, 2.0, true)
	var font: Font = get_theme_default_font()
	var font_size: int = maxi(int(radius_px * 0.42), 8)
	var width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: Vector2 = body + Vector2(-width / 2.0, font.get_ascent(font_size) / 2.0 - font.get_descent(font_size) / 2.0)
	draw_string(font, baseline, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, HERO_TEXT if is_hero() else ENEMY_TEXT)
	if in_fight:
		_draw_bars(body, font)


func _draw_bars(body: Vector2, font: Font) -> void:
	var width: float = radius_px * 2.0
	var height: float = maxf(radius_px * 0.12, 4.0)
	var left: float = body.x - radius_px
	var y: float = body.y - radius_px - height * (3.4 if mana_share >= 0.0 else 2.0)
	draw_rect(Rect2(left, y, width, height), BAR_BACK)
	draw_rect(Rect2(left, y, width * clampf(hp_share, 0.0, 1.0), height), HERO_HP if is_hero() else ENEMY_HP)
	if shield_share > 0.0:
		var start: float = clampf(hp_share, 0.0, 1.0)
		var shield_width: float = minf(shield_share, 1.0 - start) if start < 1.0 else minf(shield_share, 1.0)
		var shield_left: float = left + width * (start if start < 1.0 else 1.0 - shield_width)
		draw_rect(Rect2(shield_left, y, width * shield_width, height), UiStyle.SHIELD)
	if mana_share >= 0.0:
		var mana_y: float = y + height + 2.0
		draw_rect(Rect2(left, mana_y, width, height * 0.7), BAR_BACK)
		draw_rect(Rect2(left, mana_y, width * clampf(mana_share, 0.0, 1.0), height * 0.7), MANA)
	var below: float = body.y + radius_px + 3.0
	if cast_share >= 0.0:
		draw_rect(Rect2(left, below, width, height * 0.7), BAR_BACK)
		draw_rect(Rect2(left, below, width * cast_share, height * 0.7), CAST)
		below += height + 2.0
	var tag_size: int = maxi(int(radius_px * 0.26), 8)
	var x: float = left
	for tag: Array in status_tags:
		var text: String = tag[0]
		var tag_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x + 6.0
		if x + tag_width > left + width + radius_px:
			x = left
			below += tag_size + 4.0
		draw_rect(Rect2(x, below, tag_width, tag_size + 3.0), BAR_BACK)
		draw_string(font, Vector2(x + 3.0, below + tag_size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size, tag[1])
		x += tag_width + 3.0
