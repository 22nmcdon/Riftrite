class_name FrameDecor
extends Control
## Drawn over a framed panel (docs/ui-asset-design.md): the rarity ladder's
## non-color cues (rivets, a crest, wings), the rift bleed's cracks, and an
## infusion's spill arrows on the left and right edges. Add it as the last
## child of a PanelContainer; it draws out to the panel's edges.

## ItemDef.RARITIES index: 0 none, 1 two rivets, 2 four rivets, 3 plus a
## crest, 4 plus wings.
var ornament: int = 0
var cracks: bool = false
## Spill arrow colors, [left, right], or empty.
var spill: Array[Color] = []
## Flat bars instead of arrows (a transformation never spills).
var no_spill: bool = false


static func make(rarity_index: int, rift: bool = false, spill_colors: Array[Color] = [], never_spills: bool = false) -> FrameDecor:
	var decor := FrameDecor.new()
	decor.ornament = rarity_index
	decor.cracks = rift
	decor.spill = spill_colors
	decor.no_spill = never_spills
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
	var mid: float = outer.get_center().y + outer.size.y * 0.15
	if spill.size() == 2:
		# Just inside each edge, pointing out, so neighbors' arrows never overlap.
		_chevron(Vector2(tl.x + 11, mid), -1.0, spill[0])
		_chevron(Vector2(br.x - 11, mid), 1.0, spill[1])
	elif no_spill:
		draw_rect(Rect2(tl.x + 3, mid - 9, 5, 18), UiStyle.INK_900)
		draw_rect(Rect2(tl.x + 4, mid - 8, 3, 16), UiStyle.PARCHMENT_300)
		draw_rect(Rect2(br.x - 8, mid - 9, 5, 18), UiStyle.INK_900)
		draw_rect(Rect2(br.x - 7, mid - 8, 3, 16), UiStyle.PARCHMENT_300)


## A spill arrow pointing out of the frame (`side` -1 left, 1 right).
func _chevron(base: Vector2, side: float, hue: Color) -> void:
	var points := PackedVector2Array([base + Vector2(0, -10), base + Vector2(side * 11, 0), base + Vector2(0, 10)])
	draw_colored_polygon(points, UiStyle.INK_900)
	var inner := PackedVector2Array([base + Vector2(side * 1, -7), base + Vector2(side * 8.5, 0), base + Vector2(side * 1, 7)])
	draw_colored_polygon(inner, hue)


func _rivet(at: Vector2) -> void:
	draw_circle(at, 4.0, UiStyle.INK_900)
	draw_circle(at, 3.0, UiStyle.BRASS_300)


## A jagged violet crack running in from a corner.
func _crack(from: Vector2, direction: Vector2, span: Vector2) -> void:
	var step: Vector2 = Vector2(span.x * 0.12 * direction.x, span.y * 0.14 * direction.y)
	var points := PackedVector2Array([from, from + step * Vector2(1.0, 0.4), from + step * Vector2(1.3, 1.4), from + step * Vector2(2.2, 1.7), from + step * Vector2(2.4, 2.8)])
	draw_polyline(points, UiStyle.RIFT_500, 3.0)
	draw_polyline(points, UiStyle.RIFT_300, 1.0)
