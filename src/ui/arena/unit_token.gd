class_name UnitToken
extends Control
## One unit on the board (docs/plans/rebuild-phase3-fight-sandbox.md, sections
## 2 and 8): a placeholder circle of the unit's own radius, warm for heroes
## and cold for enemies, with a short label. A flier sits over a shadow.
## `ArenaView` places it; bars, statuses, and effects come in later steps.
## While placing, a hero's token can be dragged (drops on a token go to the
## view, as if on the hex under it).

const HERO_FILL := UiStyle.BRASS_500
const HERO_TEXT := UiStyle.INK_900
const ENEMY_FILL := UiStyle.RIFT_500
const ENEMY_TEXT := UiStyle.PARCHMENT_100
const LINE := UiStyle.INK_900
const SHADOW := Color(0.0, 0.0, 0.0, 0.45)
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
