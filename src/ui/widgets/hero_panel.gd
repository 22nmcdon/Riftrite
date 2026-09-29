class_name HeroPanel
extends Control
## A hero's panel (docs/plans/rebuild-phase4-paths.md, section 6, from the
## playtester's mock, docs/mockups/hero-panel-layout.pdf): opened over the
## screen by clicking a hero while placing. It reads the Practice session and
## asks ArenaScreen for every change (path_chosen, tactic_chosen), then shows
## the hero again.
##   - The left side: the hero's figure (its path's once transformed) with
##     its form named over it, name, title and role, HP, and stats.
##   - Back and forward move between the heroes (heroes.json's order); close,
##     Escape, or a click beside the panel shut it.
##   - The Path tab (it opens on this one): the track (Base, Vow,
##     Transform, Upgrades, Apex, with the hero's place on it; the last two
##     come with the run), the vowed path's card (its taste and cost, or
##     what the transformation brings and its cost, where the path wants the
##     hero, and its deed), and a card for each other path. Practice has no
##     thresholds, so each deed shows what the last fight put into it. Each
##     card's buttons vow it, transform it, or go back to base.
##   - The Kit tab: UnitInfo's lines for the kit at the hero's stage.
##   - The Loadout tab: the tactic (TacticPicker). Charms and sigils come with
##     the run (phase 5).

## A path and stage were picked for a hero (stage BASE: no path).
signal path_chosen(hero_id: String, path_id: String, stage: PathDef.Stage)
## A tactic was picked for a hero ("": none).
signal tactic_chosen(hero_id: String, tactic_id: String)

enum Tab { PATH, KIT, LOADOUT }

const TAB_NAMES: Array[String] = ["Path", "Kit", "Loadout"]
const SIZE := Vector2(1180, 660)
const LEFT_WIDTH: float = 360.0
const SCRIM := Color(0.03, 0.02, 0.05, 0.6)
const DONE := Color("5fc9b4")
const LATER := Color("4a4458")
const VOWED_TEXT := "VOWED"
const TRANSFORMED_TEXT := "TRANSFORMED"

var session: PracticeSession
## The hero shown ("": closed), and the tab.
var showing: String = ""
var tab: Tab = Tab.PATH
var frame: PanelContainer
var form_tag: Label
var portrait_box: CenterContainer
var hero_name: Label
var role: Label
var hp_bar: ProgressBar
var hp_text: Label
var stats: Label
var tab_buttons: Array[Button] = []
## The shown tab's page.
var page: VBoxContainer
## The Loadout tab's tactic row (null on the other tabs).
var tactic_picker: TacticPicker = null
var _scroll: ScrollContainer


static func make(practice: PracticeSession) -> HeroPanel:
	var panel := HeroPanel.new()
	panel.session = practice
	# Over the whole screen, outside its parent's layout.
	panel.top_level = true
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	panel._build()
	return panel


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	frame = PanelContainer.new()
	frame.custom_minimum_size = SIZE
	frame.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.INK_700, UiStyle.BRASS_500, 2))
	center.add_child(frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	frame.add_child(row)
	row.add_child(_build_left())
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	right.add_child(top)
	for i: int in TAB_NAMES.size():
		var button: Button = UiStyle.button(TAB_NAMES[i], show_tab.bind(i))
		button.toggle_mode = true
		tab_buttons.append(button)
		top.add_child(button)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	top.add_child(UiStyle.button("<", step.bind(-1)))
	top.add_child(UiStyle.button(">", step.bind(1)))
	top.add_child(UiStyle.button("Close", close))
	right.add_child(HSeparator.new())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_scroll)
	page = VBoxContainer.new()
	_scroll.add_child(page)


func _build_left() -> Control:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LEFT_WIDTH, 0)
	left.add_theme_constant_override("separation", 8)
	form_tag = UiStyle.label("", 15, UiStyle.FROST_400)
	left.add_child(form_tag)
	portrait_box = CenterContainer.new()
	portrait_box.custom_minimum_size = Vector2(LEFT_WIDTH, 330)
	left.add_child(portrait_box)
	hero_name = UiStyle.heading("", 32, UiStyle.HIGHLIGHT)
	left.add_child(hero_name)
	role = UiStyle.label("", 16, UiStyle.TEXT_DIM)
	left.add_child(role)
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(0, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiStyle.GOOD
	hp_bar.add_theme_stylebox_override("fill", fill)
	left.add_child(hp_bar)
	hp_text = UiStyle.label("", 14, UiStyle.TEXT_DIM)
	left.add_child(hp_text)
	stats = UiStyle.label("", 14, UiStyle.TEXT_DIM)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(stats)
	return left


## Opens on `hero_id`'s Path tab.
func open(hero_id: String) -> void:
	tab = Tab.PATH
	show_hero(hero_id)


## Shows `hero_id` as the session has it now, on the current tab.
func show_hero(hero_id: String) -> void:
	showing = hero_id
	var hero: HeroDef = session.content.heroes[hero_id]
	var path: PathDef = session.path_of(hero_id)
	var stage: PathDef.Stage = session.stage_of(hero_id)
	var kit: UnitDef = session.kit_of(hero_id)
	form_tag.text = "Base form" if path == null else "%s · %s" % [path.name, PathDef.STAGE_NAMES[stage]]
	for child: Node in portrait_box.get_children():
		portrait_box.remove_child(child)
		child.free()
	portrait_box.add_child(FigureArt.portrait(FigureArt.key_for(hero_id, true, path.id if stage == PathDef.Stage.TRANSFORMED else "base"), 330.0, LEFT_WIDTH))
	hero_name.text = hero.name
	role.text = "%s · %s" % [hero.title.capitalize(), HeroDef.ROLE_NAMES[hero.role].capitalize()]
	var hp: int = kit.stats.get_stat(UnitStats.Stat.HP)
	hp_bar.max_value = hp
	hp_bar.value = hp
	hp_text.text = "HP %d / %d" % [hp, hp]
	stats.text = UnitInfo.stats_text(kit.stats)
	visible = true
	show_tab(tab)


func show_tab(which: Tab) -> void:
	tab = which
	for i: int in tab_buttons.size():
		tab_buttons[i].set_pressed_no_signal(i == tab)
		if i == tab:
			UiStyle.primary(tab_buttons[i])
		else:
			for style: String in ["normal", "hover", "pressed"]:
				tab_buttons[i].remove_theme_stylebox_override(style)
	_scroll.remove_child(page)
	page.free()
	page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 12)
	_scroll.add_child(page)
	tactic_picker = null
	match tab:
		Tab.PATH:
			_fill_path()
		Tab.KIT:
			_fill_kit()
		Tab.LOADOUT:
			_fill_loadout()


## Back (-1) or forward (1) to the next hero, wrapping round.
func step(by: int) -> void:
	var ids: Array[String] = session.content.hero_ids
	show_hero(ids[posmod(ids.find(showing) + by, ids.size())])


func close() -> void:
	showing = ""
	visible = false


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and not frame.get_global_rect().has_point(click.global_position):
		close()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


# --- the Path tab ----------------------------------------------------------------

func _fill_path() -> void:
	var path: PathDef = session.path_of(showing)
	var stage: PathDef.Stage = session.stage_of(showing)
	page.add_child(_track(path, stage))
	if path != null:
		page.add_child(_vowed_card(path, stage))
	else:
		var none: Label = UiStyle.label("No vow: %s fights with the base kit. Vow a path below, or transform straight into one to try it." % ArenaView.label_for(session.content.heroes[showing].kit, session.content), 15, UiStyle.TEXT_DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(none)
	var others := HBoxContainer.new()
	others.add_theme_constant_override("separation", 10)
	page.add_child(others)
	for other: PathDef in session.content.heroes[showing].paths:
		if other != path:
			others.add_child(_path_card(other))
	var later: Label = UiStyle.label("In the run, a hero vows at the start and transforms when the deed fills; upgrades and the apex come later (phase 5).", 13, UiStyle.TEXT_DIM)
	later.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(later)


## Base → Vow → Transform → Upgrades → Apex, with the hero's place on it.
func _track(path: PathDef, stage: PathDef.Stage) -> HBoxContainer:
	var track := HBoxContainer.new()
	track.add_theme_constant_override("separation", 8)
	var steps: Array[Array] = [
		["Base", "Where every hero starts", true],
		["Vow", path.name if path != null else "Not vowed", stage != PathDef.Stage.BASE],
		["Transform", "Transformed" if stage == PathDef.Stage.TRANSFORMED else "When the deed fills", stage == PathDef.Stage.TRANSFORMED],
		["Upgrades", "Opens on transforming", false],
		["Apex", "Later in the run", false],
	]
	var current: int = stage + 1
	for i: int in steps.size():
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 2)
		var done: bool = steps[i][2]
		var dot: Label = UiStyle.label("●" if done else "○", 18, DONE if done else (UiStyle.BRASS_300 if i == current else LATER))
		column.add_child(dot)
		column.add_child(UiStyle.label(steps[i][0], 15, UiStyle.TEXT if done or i == current else UiStyle.TEXT_DIM))
		column.add_child(UiStyle.label(steps[i][1], 13, UiStyle.TEXT_DIM))
		track.add_child(column)
	return track


## The vowed path: taste and cost (or the transformation and its cost),
## where it wants the hero, the deed, and buttons for the other stages.
func _vowed_card(path: PathDef, stage: PathDef.Stage) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.INK_900, DONE, 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(FigureArt.portrait(FigureArt.key_for(showing, true, path.id), 150.0))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	heading.add_child(UiStyle.heading(path.name, 26, UiStyle.TEXT))
	heading.add_child(UiStyle.label(TRANSFORMED_TEXT if stage == PathDef.Stage.TRANSFORMED else VOWED_TEXT, 14, DONE))
	heading.add_child(UiStyle.label(path.title, 15, UiStyle.TEXT_DIM))
	column.add_child(heading)
	if stage == PathDef.Stage.TRANSFORMED:
		column.add_child(_wrapped("Transformed: " + path.transformed_text, 15, UiStyle.HIGHLIGHT))
		column.add_child(_wrapped("Cost: " + path.transformed_cost, 15, UiStyle.BAD))
	else:
		column.add_child(_wrapped("Taste: " + path.taste, 15, UiStyle.HIGHLIGHT))
		column.add_child(_wrapped("Cost: " + path.vowed_cost, 15, UiStyle.BAD))
	column.add_child(_wrapped("Where: " + path.placement, 14, UiStyle.TEXT_DIM))
	column.add_child(_deed_line(path))
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	row.add_child(buttons)
	if stage == PathDef.Stage.TRANSFORMED:
		buttons.add_child(UiStyle.button("Back to vow", func() -> void: path_chosen.emit(showing, path.id, PathDef.Stage.VOWED)))
	else:
		buttons.add_child(UiStyle.primary(UiStyle.button("Transform", func() -> void: path_chosen.emit(showing, path.id, PathDef.Stage.TRANSFORMED))))
	buttons.add_child(UiStyle.button("Base (no path)", func() -> void: path_chosen.emit(showing, "", PathDef.Stage.BASE)))
	return card


## Another path: figure, name, its short line, its deed, and buttons to vow
## or transform into it.
func _path_card(path: PathDef) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.INK_900, UiStyle.BORDER, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	row.add_child(FigureArt.portrait(FigureArt.key_for(showing, true, path.id), 96.0))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	row.add_child(column)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	heading.add_child(UiStyle.heading(path.name, 22, UiStyle.TEXT))
	heading.add_child(UiStyle.label(path.title, 14, UiStyle.TEXT_DIM))
	column.add_child(heading)
	column.add_child(_wrapped(path.fantasy, 14, UiStyle.TEXT))
	column.add_child(_deed_line(path))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.add_child(UiStyle.button("Vow", func() -> void: path_chosen.emit(showing, path.id, PathDef.Stage.VOWED)))
	buttons.add_child(UiStyle.button("Transform", func() -> void: path_chosen.emit(showing, path.id, PathDef.Stage.TRANSFORMED)))
	column.add_child(buttons)
	return card


## "Deed: Shield she gives · last fight: 1,240" (or "no fight yet").
func _deed_line(path: PathDef) -> Label:
	var amount: int = session.last_deed(showing, path.id)
	var last: String = "no fight yet" if amount < 0 else "last fight: %s" % UnitInfo.deed_amount_text(path.deed, amount)
	return _wrapped("Deed: %s · %s" % [path.deed.text, last], 14, DONE)


static func _wrapped(text: String, font_size: int, color: Color) -> Label:
	var label: Label = UiStyle.label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


# --- the Kit and Loadout tabs ----------------------------------------------------

func _fill_kit() -> void:
	var kit: UnitDef = session.kit_of(showing)
	page.add_child(UnitInfo.column(UnitInfo.lines(kit, ArenaView.label_for(kit, session.content), session.content)))


func _fill_loadout() -> void:
	tactic_picker = TacticPicker.make()
	tactic_picker.chosen.connect(func(tactic_id: String) -> void: tactic_chosen.emit(showing, tactic_id), CONNECT_DEFERRED)
	page.add_child(tactic_picker)
	tactic_picker.show_tactics(session.tactics_for(showing), session.tactics.get(showing, ""), true)
	page.add_child(_wrapped("Charm and sigil slots come with the run.", 14, UiStyle.TEXT_DIM))
