class_name FightFx
extends RefCounted
## The fight's animations (docs/plans/ui-overhaul.md, 4, Level 1), played
## from combat log entries on the fighters' Figures. Presentation only: it
## reads the log and never touches the sim (CLAUDE.md rule 2). How an attack
## looks comes from its item's tags, so new items animate with no extra work:
## melee lunges and swings, ranged shoots an arrow, magic throws an orb.
## Every duration shrinks with the playback speed.

enum Style { MELEE, RANGED, MAGIC }

## Seconds at 1x speed.
const LUNGE: float = 0.22
const FLIGHT: float = 0.28
const HIT: float = 0.18


## The attack style for an item's tags.
static func style_for(tags: Array[String]) -> Style:
	if tags.has("ranged"):
		return Style.RANGED
	if tags.has("magic") or tags.has("tome"):
		return Style.MAGIC
	return Style.MELEE


static func _center(figure: Figure) -> Vector2:
	return figure.get_global_rect().get_center()


## The attacker lunges toward the target (melee) or rears back and lets fly
## (ranged, magic); `on_contact` runs when the blow lands or the shot
## arrives.
static func attack(attacker: Figure, target: Figure, style: Style, layer: Control, speed: float, color: Color, on_contact: Callable) -> void:
	var pace: float = 1.0 / maxf(speed, 1.0)
	if attacker == null or not attacker.is_inside_tree():
		on_contact.call()
		return
	var toward: Vector2 = (_center(target) - _center(attacker)) if target != null and target.is_inside_tree() else Vector2(0, -1)
	var reach: Vector2 = toward.normalized() * minf(40.0, toward.length() * 0.3)
	if attacker.has_meta("attack_tween"):
		var old: Tween = attacker.get_meta("attack_tween")
		if old != null and old.is_valid():
			old.kill()
	var tween: Tween = attacker.create_tween()
	attacker.set_meta("attack_tween", tween)
	if style == Style.MELEE:
		tween.tween_method(func(t: float) -> void: _pose(attacker, reach * t, -0.9 * (1.0 - t) + 0.7 * t), 0.0, 1.0, LUNGE * pace).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_callback(on_contact)
		tween.tween_method(func(t: float) -> void: _pose(attacker, reach * (1.0 - t), 0.7 * (1.0 - t)), 0.0, 1.0, LUNGE * pace)
		return
	# Ranged and magic: a small recoil, then the shot flies.
	tween.tween_method(func(t: float) -> void: _pose(attacker, -reach * 0.25 * t, -0.35 * t), 0.0, 1.0, LUNGE * 0.5 * pace)
	tween.tween_callback(func() -> void:
		if target != null and target.is_inside_tree() and layer.is_inside_tree():
			shoot(layer, _center(attacker), _center(target), style, color, FLIGHT * pace, on_contact)
		else:
			on_contact.call())
	tween.tween_method(func(t: float) -> void: _pose(attacker, -reach * 0.25 * (1.0 - t), -0.35 * (1.0 - t)), 0.0, 1.0, LUNGE * 0.6 * pace)


static func _pose(figure: Figure, offset: Vector2, swing: float) -> void:
	if is_instance_valid(figure):
		figure.offset = offset
		figure.swing = swing
		figure.queue_redraw()


## A projectile from `from` to `to` (global positions) over `seconds`.
static func shoot(layer: Control, from: Vector2, to: Vector2, style: Style, color: Color, seconds: float, on_arrival: Callable) -> void:
	var shot := Projectile.new()
	shot.style = style
	shot.color = color
	shot.direction = (to - from).normalized()
	layer.add_child(shot)
	shot.global_position = from
	var tween: Tween = shot.create_tween()
	tween.tween_property(shot, "global_position", to, seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(on_arrival)
	tween.tween_callback(shot.queue_free)


## The target takes a hit: a white flash, a shake, and a squash (bigger on a
## crit).
static func hit(target: Figure, speed: float, crit: bool = false) -> void:
	if target == null or not target.is_inside_tree():
		return
	var pace: float = 1.0 / maxf(speed, 1.0)
	var push: float = 10.0 if crit else 6.0
	if target.has_meta("hit_tween"):
		var old: Tween = target.get_meta("hit_tween")
		if old != null and old.is_valid():
			old.kill()
	var tween: Tween = target.create_tween()
	target.set_meta("hit_tween", tween)
	tween.tween_method(func(t: float) -> void:
		if is_instance_valid(target):
			target.flash = 1.0 - t
			target.squash = 1.0 - (0.12 if crit else 0.07) * sin(t * PI)
			target.offset.x = sin(t * PI * 4.0) * push * (1.0 - t)
			target.queue_redraw(), 0.0, 1.0, HIT * 2.0 * pace)


## A heal: the target brightens green and hops.
static func heal(target: Figure, layer: Control, speed: float) -> void:
	_burst(target, layer, speed, UiStyle.GOOD, "+")


## A shield: a pale blue ring around the target.
static func shield(target: Figure, layer: Control, speed: float) -> void:
	_burst(target, layer, speed, UiStyle.SHIELD, "ring")


static func _burst(target: Figure, layer: Control, speed: float, color: Color, shape: String) -> void:
	if target == null or not target.is_inside_tree() or not layer.is_inside_tree():
		return
	var pace: float = 1.0 / maxf(speed, 1.0)
	var burst := Burst.new()
	burst.color = color
	burst.shape = shape
	layer.add_child(burst)
	burst.global_position = _center(target)
	var tween: Tween = burst.create_tween()
	tween.tween_property(burst, "grow", 1.0, 0.45 * pace)
	tween.tween_callback(burst.queue_free)


## The unit falls: tips over and greys out.
static func fall(target: Figure) -> void:
	if target != null:
		target.fallen = true
		target.offset = Vector2.ZERO
		target.swing = 0.0
		target.queue_redraw()


## A flying shot: an arrow (ranged) or a glowing orb (magic).
class Projectile:
	extends Control
	var style: Style = Style.RANGED
	var color: Color = Color.WHITE
	var direction := Vector2.RIGHT

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_level = true
		z_index = 50

	func _draw() -> void:
		if style == Style.RANGED:
			var tail: Vector2 = -direction * 30.0
			draw_line(tail, Vector2.ZERO, UiStyle.INK_900, 6.0)
			draw_line(tail, Vector2.ZERO, UiStyle.PARCHMENT_300, 3.0)
			var side: Vector2 = direction.orthogonal() * 6.0
			draw_colored_polygon(PackedVector2Array([direction * 10.0, side, -side]), UiStyle.PARCHMENT_100)
		else:
			draw_circle(Vector2.ZERO, 15.0, Color(color, 0.35))
			draw_circle(Vector2.ZERO, 9.0, color)
			draw_circle(Vector2(-2, -2), 3.0, Color(1, 1, 1, 0.8))


## A heal sparkle or shield ring that grows and fades.
class Burst:
	extends Control
	var color: Color = Color.WHITE
	var shape: String = "+"
	var grow: float = 0.0:
		set(value):
			grow = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_level = true
		z_index = 50

	func _draw() -> void:
		var fade := Color(color, 1.0 - grow)
		if shape == "ring":
			draw_arc(Vector2.ZERO, 20.0 + grow * 34.0, 0.0, TAU, 32, fade, 4.0)
			return
		for i: int in 5:
			var at: Vector2 = Vector2.from_angle(TAU * i / 5.0 - PI / 2.0) * (14.0 + grow * 24.0) + Vector2(0, -grow * 18.0)
			draw_line(at - Vector2(5, 0), at + Vector2(5, 0), fade, 3.0)
			draw_line(at - Vector2(0, 5), at + Vector2(0, 5), fade, 3.0)
