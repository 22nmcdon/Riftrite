class_name HeroToken
extends PanelContainer
## A hero in the guild bar (docs/plans/ui-overhaul.md, 3.1): portrait, name,
## rank and class, and where they stand (front, back, or backup; backup
## heroes are dimmed). Click it to open or close the hero's sheet. Drop an
## item on it to give it to that hero (outlined green or red while dragging,
## by the game's own rules). Hover it to read about the hero.

const WIDTH: int = 112

var session: RunSession
var hero_id: String
var _style: StyleBoxFlat
## Drop checks already made this drag: payload key -> would it work.
var _checks: Dictionary[String, bool] = {}


static func make(run_session: RunSession, hero: RunHero) -> HeroToken:
	var token := HeroToken.new()
	token.session = run_session
	token.hero_id = hero.hero_id
	token._build(hero)
	return token


func _build(hero: RunHero) -> void:
	var content: ContentDb = session.content
	var def: HeroDef = content.heroes[hero.hero_id]
	var open: bool = session.open_hero_id == hero.hero_id
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var fill: Color = UiStyle.PANEL_WARM if open else (UiStyle.BACKGROUND if hero.benched else UiStyle.PANEL)
	_style = UiStyle.box(fill, UiStyle.HIGHLIGHT if open else UiStyle.BORDER, 3 if open else 2)
	add_theme_stylebox_override("panel", _style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var portrait: Glyph = Glyph.portrait(def.name, Glyph.CLASS_COLORS.get(def.hero_class, UiStyle.EMBER), 56, hero.hero_id)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if hero.benched:
		portrait.modulate = Color(1, 1, 1, 0.55)
	box.add_child(portrait)
	var name_label: Label = _centered(first_name(def.name), 15, UiStyle.TEXT_DIM if hero.benched else UiStyle.TEXT)
	name_label.clip_text = true
	box.add_child(name_label)
	box.add_child(_centered("%s · %s" % [TuningDef.TIER_LABELS[hero.rank], def.hero_class.capitalize()], 12, UiStyle.EMBER))
	var where: String = "Backup" if hero.benched else ("Front row" if hero.row == UnitSetup.Row.FRONT else "Back row")
	box.add_child(_centered(where, 12, UiStyle.TEXT_DIM))
	if hero.needs_specialization:
		box.add_child(_centered("★ Choose a path", 12, UiStyle.HIGHLIGHT))
	Inspector.hover_text(self, ItemInfo.hero_text(content, hero.hero_id, hero.rank)
		+ "\n\nClick to open their sheet. Drop an item here to give it to them.")


static func first_name(full_name: String) -> String:
	return full_name.split(" of ")[0].split(" ")[0]


func _centered(text: String, font_size: int, color: Color) -> Label:
	var node: Label = UiStyle.label(text, font_size, color)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
		session.open_hero(hero_id)


func _outline(color: Color) -> void:
	if color == Color():
		add_theme_stylebox_override("panel", _style)
		return
	var style: StyleBoxFlat = _style.duplicate()
	style.border_color = color
	style.set_border_width_all(4)
	add_theme_stylebox_override("panel", style)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_checks.clear()
		_outline(Color())
	elif what == NOTIFICATION_MOUSE_EXIT:
		_outline(Color())


## Would giving the dragged item to this hero work? Checked once per drag on
## a copy of the run.
func would_accept(payload: Dictionary) -> bool:
	var key: String = str(payload)
	if not _checks.has(key):
		var uid: int = payload["uid"]
		_checks[key] = session.would_succeed(func(state: RunState) -> RunActions.Result: return RunActions.move_item(state, session.content, uid, hero_id, 99))
	return _checks[key]


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("uid"):
		return false
	var ok: bool = would_accept(data)
	_outline(UiStyle.GOOD if ok else UiStyle.BAD)
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_outline(Color())
	session.move_item((data as Dictionary)["uid"], hero_id, 99)
