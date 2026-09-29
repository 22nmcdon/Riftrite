class_name Portrait
extends Control
## A hero's figure cropped to a box, as the playtester's mock draws them
## (docs/mockups/hero-panel-layout.pdf): on a raised navy box, optionally
## with a soft circle behind, showing the top `shown` share of the figure
## (1.0: all of it; 0.6: head and shoulders), scaled to the box's height and
## centered across it. The figure is FigureArt's; nothing is drawn without
## art.

var texture: Texture2D = null
var bounds: Rect2 = Rect2(Vector2.ZERO, FigureArt.CANVAS)
## The share of the figure's height that fills the box, from its top.
var shown: float = 1.0
## Room over the figure's head, as a share of the box's height.
var headroom: float = 0.06
var fill: Color = UiStyle.NAVY_600
var circle: bool = false
var radius: int = 6


static func make(key: String, min_size: Vector2, shown_share: float = 1.0, with_circle: bool = false) -> Portrait:
	var portrait := Portrait.new()
	portrait.texture = FigureArt.texture(key)
	portrait.bounds = FigureArt.bounds(key)
	portrait.shown = shown_share
	portrait.circle = with_circle
	portrait.custom_minimum_size = min_size
	portrait.clip_contents = true
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return portrait


func _draw() -> void:
	var back: StyleBoxFlat = UiStyle.box(fill, fill, 0, radius)
	draw_style_box(back, Rect2(Vector2.ZERO, size))
	if circle:
		draw_circle(Vector2(size.x * 0.5, size.y * 0.44), minf(size.x, size.y) * 0.36, Color("2f4468"))
	if texture == null:
		return
	var scale_to: float = size.y * (1.0 - headroom) / (bounds.size.y * shown)
	var middle: float = bounds.position.x + bounds.size.x / 2.0
	var at := Vector2(size.x / 2.0 - middle * scale_to, size.y * headroom - bounds.position.y * scale_to)
	draw_texture_rect(texture, Rect2(at, FigureArt.CANVAS * scale_to), false)
