class_name HeroPanel
extends Control
## A hero's panel (docs/plans/rebuild-phase4-paths.md, section 6), laid out
## and colored after the playtester's mock (docs/mockups/hero-panel-layout.pdf,
## page 1). It opens over the screen above the hero bar when a hero's card in
## the bar is clicked; it reads the Practice session and asks ArenaScreen for
## every change (path_chosen, tactic_chosen), then shows the hero again.
##   - The left side: the hero's figure large on a circle (the path's once
##     transformed), its form in a tag over it ("Base form"), then name,
##     title and role, the HP bar, and HP and wounds under it (Practice has
##     no wounds); the stats under those.
##   - Along the top of the right side: the Path, Kit, and Loadout tabs (the
##     open one gold), and back, forward, and close. Escape or a click beside
##     the panel closes it too.
##   - The Path tab (it opens on this one): the track (Base, Vow, Transform,
##     Upgrades, Apex: done steps teal, the current one a gold ring, later
##     ones grey), the vowed path's card (teal rim: its figure, name, VOWED
##     or TRANSFORMED, title; the taste and cost, or the transformation and
##     its cost; where it wants the hero; the deed and what the last fight
##     put into it; Transform or Back to vow, and Base), a card for each other
##     path (figure, name, short line, deed; Vow and Transform), then the
##     upgrades taken and the duo bond, which come with the run.
##   - The Kit tab: UnitInfo's lines for the kit at the hero's stage.
##   - The Loadout tab: the slots (Tactic filled when one is taken) and the
##     tactic (TacticPicker). Charms and sigils come with the run (phase 5).
##   - In a fight (editable false) nothing can be changed: it's for reading.
##   - In a run (RunSession): the deed toward its threshold; another path's
##     card has Switch vow (until the hero transforms), and nothing else
##     changes a path; the upgrades taken, the duo bond (found, or stirring),
##     wounds, and the loadout's items (changed before each fight).

## A path and stage were picked for a hero (stage BASE: no path).
signal path_chosen(hero_id: String, path_id: String, stage: PathDef.Stage)
## A tactic was picked for a hero ("": none).
signal tactic_chosen(hero_id: String, tactic_id: String)
## The panel closed (the hero bar unmarks its card).
signal closed

enum Tab { PATH, KIT, LOADOUT }

const TAB_NAMES: Array[String] = ["Path", "Kit", "Loadout"]
## The mock's panel at 1920 x 1080, shrunk to fit a smaller screen.
const SIZE := Vector2(1537, 745)
const LEFT_WIDTH: float = 482.0
const SCRIM := Color(0.03, 0.04, 0.07, 0.62)
const VOWED_TEXT := "VOWED"
const TRANSFORMED_TEXT := "TRANSFORMED"

var session: PracticeSession
## The hero shown ("": closed), and the tab.
var showing: String = ""
var tab: Tab = Tab.PATH
## False in a fight: the panel is for reading.
var editable: bool = true
var frame: PanelContainer
var form_tag: Label
var portrait_box: Control
var hero_name: Label
var role: Label
var hp_bar: UiStyle.Meter
var hp_text: Label
var wounds_text: Label
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
	var rim: StyleBoxFlat = UiStyle.box(UiStyle.NAVY_800, UiStyle.LINE_500, 1, 14)
	rim.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", rim)
	center.add_child(frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	frame.add_child(row)
	row.add_child(_build_left())
	var divider := ColorRect.new()
	divider.color = UiStyle.LINE_500
	divider.custom_minimum_size = Vector2(1, 0)
	row.add_child(divider)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 0)
	row.add_child(right)
	var top_margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		top_margin.add_theme_constant_override("margin_" + side, 28)
	top_margin.add_theme_constant_override("margin_top", 12)
	top_margin.add_theme_constant_override("margin_bottom", 12)
	right.add_child(top_margin)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top_margin.add_child(top)
	for i: int in TAB_NAMES.size():
		var button: Button = UiStyle.button(TAB_NAMES[i], show_tab.bind(i))
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 52)
		button.add_theme_font_size_override("font_size", 20)
		tab_buttons.append(button)
		top.add_child(button)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	top.add_child(UiStyle.square(UiStyle.button("<", step.bind(-1))))
	top.add_child(UiStyle.square(UiStyle.button(">", step.bind(1))))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(8, 0)
	top.add_child(spacer)
	var close_button: Button = UiStyle.square(UiStyle.button("Close", close))
	close_button.custom_minimum_size = Vector2(52, 52)
	close_button.text = "✕"
	close_button.tooltip_text = "Close"
	close_button.set_meta("close", true)
	top.add_child(close_button)
	var line := ColorRect.new()
	line.color = UiStyle.LINE_500
	line.custom_minimum_size = Vector2(0, 1)
	right.add_child(line)
	var page_margin := MarginContainer.new()
	page_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right"]:
		page_margin.add_theme_constant_override("margin_" + side, 32)
	page_margin.add_theme_constant_override("margin_top", 22)
	page_margin.add_theme_constant_override("margin_bottom", 18)
	right.add_child(page_margin)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_margin.add_child(_scroll)
	page = VBoxContainer.new()
	_scroll.add_child(page)


func _build_left() -> Control:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LEFT_WIDTH, 0)
	left.add_theme_constant_override("separation", 0)
	portrait_box = Control.new()
	portrait_box.custom_minimum_size = Vector2(LEFT_WIDTH, 300)
	portrait_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_box.clip_contents = true
	left.add_child(portrait_box)
	var info := PanelContainer.new()
	var info_style: StyleBoxFlat = UiStyle.box(UiStyle.NAVY_700, UiStyle.NAVY_700, 0, 0)
	info_style.corner_radius_bottom_left = 14
	info_style.content_margin_left = 30
	info_style.content_margin_right = 30
	info_style.content_margin_top = 22
	info_style.content_margin_bottom = 26
	info.add_theme_stylebox_override("panel", info_style)
	left.add_child(info)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	info.add_child(column)
	hero_name = UiStyle.heading("", 40, UiStyle.TEXT)
	column.add_child(hero_name)
	role = UiStyle.label("", 19, UiStyle.TEXT_DIM)
	column.add_child(role)
	var bar_gap := Control.new()
	bar_gap.custom_minimum_size = Vector2(0, 14)
	column.add_child(bar_gap)
	hp_bar = UiStyle.bar(1.0, UiStyle.GOOD, 16) as UiStyle.Meter
	column.add_child(hp_bar)
	var hp_row := HBoxContainer.new()
	column.add_child(hp_row)
	hp_text = UiStyle.label("", 17, UiStyle.TEXT_DIM)
	hp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(hp_text)
	wounds_text = UiStyle.label("No wounds", 17, UiStyle.TEXT_DIM)
	hp_row.add_child(wounds_text)
	stats = UiStyle.label("", 15, UiStyle.TEXT_DIM)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(stats)
	form_tag = UiStyle.strong("", 16, UiStyle.INK_TEXT, true)
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
	var transformed: bool = stage == PathDef.Stage.TRANSFORMED
	form_tag.text = "%s form" % path.name if transformed else "Base form"
	if form_tag.get_parent() != null:
		form_tag.get_parent().remove_child(form_tag)
	for child: Node in portrait_box.get_children():
		portrait_box.remove_child(child)
		child.free()
	var figure: Portrait = Portrait.make(FigureArt.key_for(hero_id, true, path.id if transformed else "base"), Vector2.ZERO, 0.62, true)
	figure.radius = 0
	figure.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_box.add_child(figure)
	var tag := PanelContainer.new()
	var tag_style: StyleBoxFlat = UiStyle.box(Color("f8eed1"), Color("f8eed1"), 0, 5)
	tag_style.content_margin_left = 10
	tag_style.content_margin_right = 10
	tag_style.content_margin_top = 3
	tag_style.content_margin_bottom = 3
	tag.add_theme_stylebox_override("panel", tag_style)
	tag.position = Vector2(20, 20)
	tag.add_child(form_tag)
	portrait_box.add_child(tag)
	hero_name.text = hero.name
	role.text = role_text(hero, kit)
	var hp: int = kit.stats.get_stat(UnitStats.Stat.HP)
	hp_bar.set_share(1.0)
	var run_session := session as RunSession
	if run_session != null:
		hp_bar.lost = run_session.wound_share(hero_id)
		hp = FixedMath.apply_bp(hp, FixedMath.BP_ONE - int(round(hp_bar.lost * FixedMath.BP_ONE)))
		var wounds: int = run_session.state().hero(hero_id).wounds
		wounds_text.text = "No wounds" if wounds == 0 else ("1 wound" if wounds == 1 else "%d wounds" % wounds)
	hp_text.text = "HP %d / %d" % [hp, hp]
	stats.text = UnitInfo.stats_text(kit.stats)
	visible = true
	show_tab(tab)


## "The ranger · Ranged damage": the hero's title, then its role (a damage
## dealer says whether it's ranged or melee).
static func role_text(hero: HeroDef, kit: UnitDef) -> String:
	var role_name: String = HeroDef.ROLE_NAMES[hero.role].capitalize()
	if hero.role == HeroDef.Role.DAMAGE:
		role_name = "%s damage" % ("Ranged" if kit.stats.get_stat(UnitStats.Stat.RANGE) >= 2 else "Melee")
	return "%s · %s" % [hero.title.capitalize(), role_name]


func show_tab(which: Tab) -> void:
	tab = which
	for i: int in tab_buttons.size():
		tab_buttons[i].set_pressed_no_signal(i == tab)
		if i == tab:
			UiStyle.primary(tab_buttons[i])
		else:
			UiStyle.plain(tab_buttons[i])
	_scroll.remove_child(page)
	page.free()
	page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 18)
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
	var was: bool = visible
	showing = ""
	visible = false
	if was:
		closed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and frame != null:
		frame.custom_minimum_size = Vector2(minf(SIZE.x, size.x - 40.0), minf(SIZE.y, size.y - 32.0))


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
		page.add_child(_wrapped("No vow yet: %s fights with the base kit. Vow a path below, or transform straight into one to try it." % ArenaView.label_for(session.content.heroes[showing].kit, session.content), 17, UiStyle.TEXT_DIM))
	var others := HBoxContainer.new()
	others.add_theme_constant_override("separation", 18)
	page.add_child(others)
	for other: PathDef in session.content.heroes[showing].paths:
		if other != path:
			others.add_child(_path_card(other))
	var extras := HBoxContainer.new()
	extras.add_theme_constant_override("separation", 40)
	page.add_child(extras)
	var run_session := session as RunSession
	if run_session != null:
		extras.add_child(_extra("Upgrades taken", _run_upgrades(run_session), "upgrade"))
		extras.add_child(_extra("Duo bond", _run_bond(run_session), "bond"))
		return
	extras.add_child(_extra("Upgrades taken", "None yet: upgrades come after won fights in the run.", "upgrade"))
	extras.add_child(_extra("Duo bond", "None yet: bonds are found in the run.", "bond"))


## The upgrades the hero has taken, by name (a path's that waits off its
## path says so).
func _run_upgrades(run_session: RunSession) -> String:
	var hero: RunState.Hero = run_session.state().hero(showing)
	var names: Array[String] = []
	for id: String in hero.upgrades:
		var upgrade: UpgradeDef = run_session.run.upgrades[id]
		var waiting: bool = upgrade.layer == UpgradeDef.Layer.PATH and upgrade.path != hero.path
		var numbers: String = ModInfo.upgrade_numbers(upgrade, run_session.run.hero_kit(hero), run_session.content)
		if upgrade.grows != null:
			numbers += " · " + ModInfo.growth_now(upgrade.grows, hero.growth.get(upgrade.id, 0), run_session.run.hero_kit(hero), run_session.content)
		names.append("%s%s: %s%s" % [upgrade.name, " (waits for %s)" % run_session.content.paths[upgrade.path].name if waiting else "", upgrade.text,
			"" if numbers.is_empty() else " (%s)" % numbers])
	return "None yet: a pick comes after each won fight." if names.is_empty() else "\n".join(names)


## The hero's duo bond: on (and what it gives), stirring, or none.
func _run_bond(run_session: RunSession) -> String:
	var path_id: String = run_session.state().hero(showing).path
	for bond: BondDef in run_session.run.active_bonds(run_session.state()):
		if bond.paths.has(path_id):
			var numbers: String = ModInfo.bond_numbers(bond, path_id, run_session.run.hero_kit(run_session.state().hero(showing)), run_session.content)
			return "%s: %s%s" % [bond.name, bond.texts[path_id], "" if numbers.is_empty() else " (%s)" % numbers]
	for bond: BondDef in run_session.run.stirring_bonds(run_session.state()):
		if bond.paths.has(path_id):
			return "A bond stirs with %s: it wakes when both have transformed." % run_session.content.paths[bond.partner(path_id)].name
	return "None: no bond links this path with another hero's vow."


## `kind`'s frame (ItemIcon; phase 5b) goes before the title.
func _extra(title: String, body: String, kind: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(ItemIcon.make(kind, ItemIcon.UPGRADE_GLYPH if kind == "upgrade" else "", 28.0))
	var caps: Label = UiStyle.caps(title, 14)
	caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(caps)
	column.add_child(head)
	column.add_child(_wrapped(body, 16, UiStyle.TEXT_DIM))
	return column


## Base → Vow → Transform → Upgrades → Apex, with the hero's place on it.
func _track(path: PathDef, stage: PathDef.Stage) -> HBoxContainer:
	var track := HBoxContainer.new()
	track.add_theme_constant_override("separation", 0)
	var steps: Array[Array] = [
		["Base", "Start of the run"],
		["Vow", path.name if path != null else "Not vowed"],
		["Transform", "Transformed" if stage == PathDef.Stage.TRANSFORMED else "When the deed fills"],
		["Upgrades", "Opens on transforming"],
		["Apex", "Later in the run"],
	]
	# Done: base, the vow once vowed, the transformation once transformed.
	var done: int = int(stage) + 1
	var current: int = done if done <= 2 else -1
	for i: int in steps.size():
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 4)
		var dot := TrackDot.new()
		dot.state = 0 if i < done else (1 if i == current else 2)
		dot.line_state = -1 if i == steps.size() - 1 else (0 if i + 1 < done or i + 1 == current else 2)
		dot.custom_minimum_size = Vector2(0, 26)
		column.add_child(dot)
		column.add_child(UiStyle.strong(steps[i][0], 17, UiStyle.TEXT if i < done or i == current else UiStyle.TEXT_DIM))
		column.add_child(UiStyle.label(steps[i][1], 15, UiStyle.TEXT_DIM))
		track.add_child(column)
	return track


## One step's dot on the track, and the line to the next step.
class TrackDot:
	extends Control
	## 0 done (teal), 1 current (gold ring), 2 later (grey).
	var state: int = 2
	## The line to the next dot: 0 teal, 2 grey, -1 none.
	var line_state: int = 2

	func _draw() -> void:
		var at := Vector2(10, size.y / 2.0)
		if line_state >= 0:
			draw_line(at + Vector2(14, 0), Vector2(size.x - 4, at.y), UiStyle.TEAL_400 if line_state == 0 else Color("3a5566"), 3.0, true)
		match state:
			0:
				draw_circle(at, 9.0, UiStyle.TEAL_400)
			1:
				draw_circle(at, 7.5, UiStyle.NAVY_800)
				draw_arc(at, 8.0, 0.0, TAU, 24, UiStyle.GOLD_300, 3.0, true)
			_:
				draw_circle(at, 8.0, Color("3a5566"))


## The vowed path: taste and cost (or the transformation and its cost),
## where it wants the hero, the deed, and buttons for the other stages.
func _vowed_card(path: PathDef, stage: PathDef.Stage) -> PanelContainer:
	var transformed: bool = stage == PathDef.Stage.TRANSFORMED
	var card := PanelContainer.new()
	var style: StyleBoxFlat = UiStyle.box(UiStyle.NAVY_700, UiStyle.TEAL_400, 2, 12)
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	card.add_child(row)
	row.add_child(Portrait.make(FigureArt.key_for(showing, true, path.id), Vector2(145, 180), 0.8))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 5)
	row.add_child(column)
	# The name comes first among the card's labels (tests find cards by it).
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 14)
	heading.add_child(UiStyle.heading(path.name, 34, UiStyle.TEXT))
	var stage_label: Label = UiStyle.caps(TRANSFORMED_TEXT if transformed else VOWED_TEXT, 16, UiStyle.ACCENT_TEXT)
	stage_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(stage_label)
	var title_label: Label = UiStyle.label(path.title, 18, UiStyle.TEXT_DIM)
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(title_label)
	column.add_child(heading)
	if transformed:
		column.add_child(_rule("Transformed:", path.transformed_text, UiStyle.HIGHLIGHT))
		column.add_child(_rule("Cost:", path.transformed_cost, UiStyle.BAD))
	else:
		column.add_child(_rule("Taste:", path.taste, UiStyle.HIGHLIGHT))
		column.add_child(_rule("Cost:", path.vowed_cost, UiStyle.BAD))
	column.add_child(_wrapped("Where: " + path.placement, 16, UiStyle.TEXT_DIM))
	column.add_child(_deed_row(path, 17))
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	row.add_child(buttons)
	if session is RunSession:
		return card
	if transformed:
		buttons.add_child(_choice("Back to vow", path.id, PathDef.Stage.VOWED))
	else:
		buttons.add_child(_choice("Transform", path.id, PathDef.Stage.TRANSFORMED))
	buttons.add_child(_choice("Base (no path)", "", PathDef.Stage.BASE))
	return card


## "Taste: after 2s without moving, she gets +1 range.", its first word in
## the color and bold.
func _rule(lead: String, text: String, color: Color) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich.add_theme_font_size_override("normal_font_size", 18)
	rich.add_theme_font_size_override("bold_font_size", 18)
	rich.text = "[b][color=#%s]%s[/color][/b] %s" % [color.to_html(false), lead, text]
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rich


## The deed's line: "Deed: <what it counts>" on the left, and what the last
## fight put into it on the right, in teal (Practice has no thresholds, so
## there's no bar to fill yet).
func _deed_row(path: PathDef, font_size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_wrapped("Deed: " + path.deed.text, font_size - 1, UiStyle.TEXT_DIM))
	var amount: int = session.last_deed(showing, path.id)
	var said: String = "no fight yet" if amount < 0 else "last fight: %s" % UnitInfo.deed_amount_text(path.deed, amount)
	if session is RunSession:
		said = "%s / %s" % [UnitInfo.deed_amount_text(path.deed, amount), UnitInfo.deed_amount_text(path.deed, path.deed.threshold)]
	var last: Label = UiStyle.strong(said, font_size - 1, UiStyle.ACCENT_TEXT)
	last.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(last)
	return row


func _choice(text: String, path_id: String, stage: PathDef.Stage) -> Button:
	var button: Button = UiStyle.button(text, func() -> void: path_chosen.emit(showing, path_id, stage))
	button.size_flags_horizontal = Control.SIZE_FILL
	button.disabled = not editable
	return button


## Another path: figure, name, its short line, its deed, and buttons to vow
## or transform into it.
func _path_card(path: PathDef) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = UiStyle.box(UiStyle.NAVY_750, UiStyle.LINE_500, 1, 12)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	row.add_child(Portrait.make(FigureArt.key_for(showing, true, path.id), Vector2(78, 100), 0.7))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
	column.add_child(UiStyle.heading(path.name, 26, UiStyle.TEXT))
	column.add_child(_wrapped(path.fantasy, 16, UiStyle.TEXT))
	column.add_child(_deed_row(path, 15))
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var choices: Array = [["Vow", PathDef.Stage.VOWED], ["Transform", PathDef.Stage.TRANSFORMED]]
	if session is RunSession:
		choices = [["Switch vow", PathDef.Stage.VOWED]]
	for pair: Array in choices:
		var button: Button = _choice(pair[0], path.id, pair[1])
		button.add_theme_font_size_override("font_size", 15)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var small: StyleBoxFlat = (button.get_theme_stylebox(state) as StyleBoxFlat).duplicate()
			small.content_margin_top = 4
			small.content_margin_bottom = 4
			small.content_margin_left = 12
			small.content_margin_right = 12
			button.add_theme_stylebox_override(state, small)
		buttons.add_child(button)
	row.add_child(buttons)
	return card


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
	var run_session := session as RunSession
	if run_session != null:
		_fill_run_loadout(run_session)
		return
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 10)
	page.add_child(slots)
	var tactic_id: String = session.tactics.get(showing, "")
	slots.add_child(UiStyle.chip("Charm", UiStyle.CHARM, false, 16))
	slots.add_child(UiStyle.chip(session.content.tactics[tactic_id].name if not tactic_id.is_empty() else "Tactic", UiStyle.TACTIC, not tactic_id.is_empty(), 16))
	slots.add_child(UiStyle.chip("Sigil", UiStyle.SIGIL, false, 16))
	tactic_picker = TacticPicker.make()
	tactic_picker.chosen.connect(func(picked: String) -> void: tactic_chosen.emit(showing, picked), CONNECT_DEFERRED)
	page.add_child(tactic_picker)
	tactic_picker.show_tactics(session.tactics_for(showing), tactic_id, editable)
	page.add_child(_wrapped("Charm and sigil slots come with the run.", 16, UiStyle.TEXT_DIM))



## A run's loadout: each slot's item (its kind, name, and rule), and a line
## on where to change it.
func _fill_run_loadout(run_session: RunSession) -> void:
	var hero: RunState.Hero = run_session.state().hero(showing)
	var colors: Array[Color] = [UiStyle.CHARM, UiStyle.TACTIC, UiStyle.SIGIL, UiStyle.EMBER]
	for id: String in hero.slots:
		var item: ItemDef = run_session.run.items.get(id, null)
		if item == null:
			page.add_child(UiStyle.chip("Empty slot", UiStyle.LINE_500, false, 16))
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(UiStyle.chip("%s · %s" % [ItemDef.KIND_NAMES[item.kind].capitalize(), item.name], colors[item.kind], true, 16))
		var works: bool = item.works_on(run_session.run.hero_kit(hero), hero.id)
		var numbers: String = ModInfo.item_numbers(item, run_session.run.hero_kit(hero), run_session.content)
		row.add_child(_wrapped(item.text + ("" if numbers.is_empty() else " (%s)" % numbers) + ("" if works else " (no effect on this hero)"), 16, UiStyle.TEXT if works else UiStyle.BAD))
		page.add_child(row)
	page.add_child(_wrapped("Change the loadout before each fight, from the stash.", 16, UiStyle.TEXT_DIM))
