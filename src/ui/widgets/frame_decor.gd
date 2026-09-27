class_name FrameDecor
extends Control
## Drawn over a framed panel (docs/ui-asset-design.md): the rarity ladder's
## non-color cues (rivets, a crest, wings), the rift bleed's cracks, and an
## infusion's mark at the bottom right: rays while a Resonant single spills
## (docs/plans/infusion-rework.md), a star once an alloy awakens. Add it as
## the last child of a PanelContainer; it draws out to the panel's edges.

enum Mark { NONE, SPILLS, AWAKENED }

## ItemDef.RARITIES index: 0 none, 1 two rivets, 2 four rivets, 3 plus a
## crest, 4 plus wings.
var ornament: int = 0
var cracks: bool = false
var mark: Mark = Mark.NONE
## The mark's essence color.
var mark_hue: Color = Color.WHITE


static func make(rarity_index: int, rift: bool = false, infusion_mark: Mark = Mark.NONE, hue: Color = Color.WHITE) -> FrameDecor:
	var decor := FrameDecor.new()
	decor.ornament = rarity_index
	decor.cracks = rift
	decor.mark = infusion_mark
	decor.mark_hue = hue
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return decor


## The parent panel's outer rect, in this control's coordinates.
func _outer() -> Rect2:
	var panel: Control = get_parent() as Control
	var style: StyleBox = panel.get_theme_stylebox("panel") if panel != null else null
	if style == null:
		return Rect2(Vector2.ZERO, size)
	var left: float = style.get_margin(SIDE_LEFT)
	var top: float = style.get_margin(SIDE_TOP)
	return Rect2(-left, -top, size.x + left + style.get_margin(SIDE_RIGHT), size.y + top + style.get_margin(SIDE_BOTTOM))


func _draw() -> void:
	var outer: Rect2 = _outer()
	var tl: Vector2 = outer.position
	var br: Vector2 = outer.end
	if cracks:
		_crack(tl + Vector2(2, 2), Vector2(1, 1), outer.size)
		_crack(br - Vector2(2, 2), Vector2(-1, -1), outer.size)
	if ornament >= 1:
		_rivet(tl + Vector2(6, 6))
		_rivet(Vector2(br.x - 6, tl.y + 6))
	if ornament >= 2:
		_rivet(Vector2(tl.x + 6, br.y - 6))
		_rivet(br - Vector2(6, 6))
	if ornament >= 3:
		var top: Vector2 = Vector2(outer.get_center().x, tl.y)
		draw_colored_polygon(PackedVector2Array([top + Vector2(0, -6), top + Vector2(6, 1), top + Vector2(0, 5), top + Vector2(-6, 1)]), UiStyle.BRASS_300)
	if ornament >= 4:
		var y: float = tl.y + outer.size.y * 0.3
		draw_colored_polygon(PackedVector2Array([Vector2(tl.x, y - 6), Vector2(tl.x - 7, y), Vector2(tl.x, y + 6)]), UiStyle.BRASS_300)
		draw_colored_polygon(PackedVector2Array([Vector2(br.x, y - 6), Vector2(br.x + 7, y), Vector2(br.x, y + 6)]), UiStyle.BRASS_300)
	var corner: Vector2 = br - Vector2(13, 13)
	match mark:
		Mark.SPILLS:
			_rays(corner, mark_hue)
		Mark.AWAKENED:
			_star(corner, mark_hue)


## A spilling single: a dot in the essence's color with four short rays.
func _rays(c: Vector2, hue: Color) -> void:
	for direction: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(c + direction * 4.0, c + direction * 9.0, UiStyle.INK_900, 4.0)
		draw_line(c + direction * 4.0, c + direction * 8.0, hue, 2.0)
	draw_circle(c, 4.5, UiStyle.INK_900)
	draw_circle(c, 3.5, hue)


## An awakened alloy: a brass four-pointed star around the essence's color.
func _star(c: Vector2, hue: Color) -> void:
	var outer := PackedVector2Array()
	for i: int in 8:
		var angle: float = PI * 0.25 * i - PI * 0.5
		outer.append(c + Vector2(cos(angle), sin(angle)) * (10.0 if i % 2 == 0 else 4.0))
	draw_colored_polygon(outer, UiStyle.INK_900)
	var inner := PackedVector2Array()
	for point: Vector2 in outer:
		inner.append(c + (point - c) * 0.78)
	draw_colored_polygon(inner, UiStyle.BRASS_300)
	draw_circle(c, 2.5, hue)


func _rivet(at: Vector2) -> void:
	draw_circle(at, 4.0, UiStyle.INK_900)
	draw_circle(at, 3.0, UiStyle.BRASS_300)


## A jagged violet crack running in from a corner.
func _crack(from: Vector2, direction: Vector2, span: Vector2) -> void:
	var step: Vector2 = Vector2(span.x * 0.12 * direction.x, span.y * 0.14 * direction.y)
	var points := PackedVector2Array([from, from + step * Vector2(1.0, 0.4), from + step * Vector2(1.3, 1.4), from + step * Vector2(2.2, 1.7), from + step * Vector2(2.4, 2.8)])
	draw_polyline(points, UiStyle.RIFT_500, 3.0)
	draw_polyline(points, UiStyle.RIFT_300, 1.0)
