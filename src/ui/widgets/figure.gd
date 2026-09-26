class_name Figure
extends Control
## A character's standing figure (CharacterArt): the body, and what it
## holds drawn on top, turned around the hand. Enemies face left (flipped).
## Fights animate it through a few plain values, all presentation only:
## `offset` (a lunge or knockback, in pixels), `swing` (the held layer's
## turn, in radians), `squash` (1 = none), `flash` (0..1 white hit flash),
## and `fallen` (greyed and tipped over). Without art it draws nothing.

var char_id: String = ""
var flip: bool = false
var offset := Vector2.ZERO
var swing: float = 0.0
var squash: float = 1.0
var flash: float = 0.0
var fallen: bool = false
## The idle bob's phase, so figures don't bob in step.
var bob_phase: float = 0.0
var bob: bool = false
var _time: float = 0.0
var _body: Texture2D
var _held: Texture2D


static func make(id: String, height: int = 160, facing_left: bool = false) -> Figure:
	var figure := Figure.new()
	figure.char_id = id
	figure.flip = facing_left
	figure._body = CharacterArt.body(id)
	figure._held = CharacterArt.held(id)
	figure.custom_minimum_size = Vector2(height * CharacterArt.CANVAS.x / CharacterArt.CANVAS.y, height)
	figure.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return figure


func has_art() -> bool:
	return _body != null


func _process(delta: float) -> void:
	if bob and not fallen:
		_time += delta
		queue_redraw()


func _draw() -> void:
	if _body == null:
		return
	var scale_to: float = size.y / CharacterArt.CANVAS.y
	var lift: float = sin(_time * 3.0 + bob_phase) * 2.0 if bob and not fallen else 0.0
	var feet := Vector2(size.x / 2.0, size.y) + offset + Vector2(0, lift)
	# Tip over around the feet when fallen (away from the enemy).
	var turn: float = (-1.0 if flip else 1.0) * -PI / 2.0 * 0.85 if fallen else 0.0
	var tint := Color(0.55, 0.55, 0.6, 0.6) if fallen else Color.WHITE
	if flash > 0.0 and not fallen:
		# Over-bright modulate reads as a white hit flash.
		tint = Color(1.0 + flash * 2.5, 1.0 + flash * 2.5, 1.0 + flash * 2.5)
	# Canvas space (feet at the origin) -> the control: flip, squash, scale.
	var body_xform: Transform2D = Transform2D(turn, feet).scaled_local(Vector2((-1.0 if flip else 1.0) * scale_to / squash, scale_to * squash))
	var origin := Vector2(-CharacterArt.CANVAS.x / 2.0, -CharacterArt.CANVAS.y)
	var rect := Rect2(origin, CharacterArt.CANVAS)
	draw_set_transform_matrix(body_xform)
	draw_texture_rect(_body, rect, false, tint)
	if _held != null:
		# The held layer turns around the hand.
		var hand: Vector2 = origin + CharacterArt.hand(char_id)
		draw_set_transform_matrix(body_xform.translated_local(hand).rotated_local(swing).translated_local(-hand))
		draw_texture_rect(_held, rect, false, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)
