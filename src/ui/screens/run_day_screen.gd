class_name RunDayScreen
extends UiScreen
## A day of the run between fights (docs/plans/rebuild-phase5-run.md,
## section 11; part 6, section 9, the playtester's mock): the top bar (the
## day, the act and place, shards, and relics), the day's step in the middle,
## and the hero bar along the bottom (a hero's card opens its panel, where
## its vow can be switched until it transforms). Every button is a RunFlow
## action through the session, which saves; the screen then shows the run
## again. What's waiting comes first, wherever the day is:
##   - a transformation ("Maren transforms: Deadeye");
##   - an upgrade pick (a card per upgrade: who it's for, its kind and
##     source, its name and rule; Take), or "Take 3 shards instead";
##   - a relic choice (each relic's flavor, boon, and cost; Take), or neither.
## Then the day's step (phase 5c step 8: route, loadout, fight, after it,
## the shop, a node):
##   - the route: the act map (ActMap; phase 5b), and beside it the card of
##     today's fight selected on it (tier and pay, what it tests, its
##     enemies and their threat lines, and where they stand once Scouted);
##   - the loadout: each hero's slots (click a filled one to take it off) and
##     the stash (equip each item to a hero; "no effect" where it does
##     nothing); then To the fight;
##   - after the fight: how it went, then To the Pedlar;
##   - the shop: the Pedlar's wares, a relic, treating wounds, selling, a
##     reroll; then Leave the Pedlar (after the boss, the boss shop, and
##     leaving it is the run's end);
##   - the nodes: a card each (Camp, Rift Tear, the Magpie; Go to);
##   - a node: camp (the place, its options (Choose), then what one opened:
##     Map the Rift's swap, or the Hunt (Fight the Hunt)), the Magpie's
##     stall, or the Rift Tear taken; then On to day N;
##   - the run's end: won or lost, and every fight fought.

## To the arena for the waiting fight (the day's, or a Hunt).
signal fight_requested
## The run is over and the player is done with it.
signal finished

## An item's, relic's, or upgrade's icon at the head of its card.
## Each relic tier's color on its card (phase 5c step 5a; the frames per tier
## are the UI redesign's).
const TIER_COLORS: Array[Color] = [UiStyle.TEXT_DIM, UiStyle.TEAL_400, UiStyle.RIFT_300, UiStyle.GOLD_500, UiStyle.HIGHLIGHT, UiStyle.GOOD]
const CARD_ICON: float = 60.0
## A camp option's icon, and the place's node beside the camp's heading.
const OPTION_ICON: float = 56.0
const PLACE_ICON: float = 64.0
## A ware's card over the shop's scene.
const WARE_WIDTH: float = 300.0
## The selected fight's card beside the act map.
const ROUTE_CARD_WIDTH: float = 420.0

var session: RunSession
## The route's act map (null off the route).
var act_map: ActMap = null
var hero_bar: HeroBar
var hero_panel: HeroPanel
var body: VBoxContainer
var message: Label
var _top: HBoxContainer


static func make(run_session: RunSession) -> RunDayScreen:
	var screen := RunDayScreen.new()
	screen.session = run_session
	screen.full_bleed = true
	return screen


func build() -> void:
	shows_backdrop = false
	add_theme_constant_override("separation", 0)
	var upper := Control.new()
	upper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(upper)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	upper.add_child(column)
	var bar: PanelContainer = RunDayScreen.top_bar()
	_top = bar.get_child(0) as HBoxContainer
	column.add_child(bar)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	scroll.add_child(margin)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	margin.add_child(body)
	hero_panel = HeroPanel.make(session)
	hero_panel.z_index = 5
	upper.add_child(hero_panel)
	hero_bar = HeroBar.make(session)
	add_child(hero_bar)
	hero_bar.card_clicked.connect(open_panel)
	hero_panel.closed.connect(func() -> void: hero_bar.select(""))
	hero_panel.path_chosen.connect(_switch_vow, CONNECT_DEFERRED)
	hero_panel.apex_chosen.connect(_vow_apex, CONNECT_DEFERRED)
	refresh()


## The top bar, as in the mock: the day in gold, the act and place, and (on
## the right) shards and relics. fill_top_bar fills it.
static func top_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	var style: StyleBoxFlat = UiStyle.box(UiStyle.NAVY_900, UiStyle.NAVY_900, 0, 0)
	style.border_color = Color("121a21")
	style.border_width_bottom = 2
	style.content_margin_left = 38
	style.content_margin_right = 38
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	bar.add_child(row)
	return bar


## Fills `row` (a top bar's) for the run: "Day 3 of 7", "Act 1 · Waystone",
## then shards and the relics' names.
static func fill_top_bar(row: HBoxContainer, run_session: RunSession, where: String = "") -> void:
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()
	var state: RunState = run_session.state()
	var floor_now: int = run_session.flow.floor_number()
	var title: String = "Floor %d" % floor_now if floor_now > 0 else "Day %d of %d" % [state.day, run_session.flow.act.days.size()]
	row.add_child(UiStyle.heading(title, 34, UiStyle.HIGHLIGHT))
	var place: String = where
	if place.is_empty():
		place = RunDayScreen.place_name(run_session)
	var at: Label = UiStyle.label("%s · %s" % ["Endless" if floor_now > 0 else "Act %d" % state.act, place], 20, UiStyle.TEXT_DIM)
	at.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(at)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	for id: String in state.relics:
		var relic: RelicDef = run_session.run.relics[id]
		var chip: PanelContainer = UiStyle.chip(relic.name, UiStyle.RIFT_300, true, 15, ItemIcon.for_relic(relic, 24.0))
		chip.tooltip_text = "%s · %s\n%s\n%s\n%s" % [relic.name, RelicDef.TIER_LABELS[relic.tier], relic.flavor, relic.text, ModInfo.relic_numbers(relic, run_session.content)]
		if relic.grows != null:
			chip.tooltip_text += "\n" + ModInfo.growth_now(relic.grows, state.growth.get(id, 0), null, run_session.content)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
	var shards: Label = UiStyle.strong("%d shards" % state.shards, 20, UiStyle.HIGHLIGHT)
	shards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(shards)


## A picture from art/ui/ (camp's icons and the map's nodes), `side` pixels
## square.
static func art_icon(path: String, side: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = ArenaView.art(RunContent.ART_UI + path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(side, side)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## A node's picture (phase 5c step 8): "camp:<place>" is its place's;
## "rift_tear" and "magpie" their nodes' ("" for none).
static func node_icon(run: RunContent, id: String) -> String:
	if id.begins_with("camp:"):
		for place: CampsDef.Place in run.camps.places:
			if place.id == id.trim_prefix("camp:"):
				return place.icon
		return run.camps.nodes["camp"].icon
	if id.begins_with("event:"):
		return run.camps.nodes["event"].icon
	return run.camps.nodes[id].icon if run.camps.nodes.has(id) else ""


## A node's name: a camp's place's, or the node's.
static func node_name(run: RunContent, id: String) -> String:
	if id.begins_with("camp:"):
		for place: CampsDef.Place in run.camps.places:
			if place.id == id.trim_prefix("camp:"):
				return place.name
		return run.camps.nodes["camp"].name
	if id.begins_with("event:"):
		var scene: EventDef.Scene = run.events.scene(id.trim_prefix("event:"))
		return scene.name if scene != null else run.camps.nodes["event"].name
	return run.camps.nodes[id].name if run.camps.nodes.has(id) else ""


## A node's line on its card: an event's scene, or the node's.
static func node_text(run: RunContent, id: String) -> String:
	if id.begins_with("event:"):
		var scene: EventDef.Scene = run.events.scene(id.trim_prefix("event:"))
		return scene.text if scene != null else ""
	return run.camps.nodes[id].text if run.camps.nodes.has(id) else ""


## Today's camp's picture (its place's).
static func place_icon(run_session: RunSession) -> String:
	return RunDayScreen.node_icon(run_session.run, "camp:" + run_session.state().place)


## Where the run is: the node it's in (its camp's place), or "The rift".
static func place_name(run_session: RunSession) -> String:
	var state: RunState = run_session.state()
	if state.phase == RunState.Phase.SHOP:
		return "The Pedlar"
	if state.phase == RunState.Phase.NODE:
		return RunDayScreen.node_name(run_session.run, "camp:" + state.place if state.node == "camp" else state.node)
	return "The rift"


## Shows the run as it stands.
func refresh() -> void:
	session.sync()
	RunDayScreen.fill_top_bar(_top, session)
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	act_map = null
	message = UiStyle.label("", 17, UiStyle.BAD)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var state: RunState = session.state()
	if state.phase == RunState.Phase.ENDED:
		_fill_end()
	else:
		_fill_waiting()
		match state.phase:
			RunState.Phase.ROUTE:
				_fill_route()
			RunState.Phase.LOADOUT:
				_fill_loadout()
			RunState.Phase.AFTER:
				_fill_after()
			RunState.Phase.SHOP:
				_fill_shop()
				var label: String = "Leave the Pedlar"
				if session.flow.boss_shop() and not state.endless:
					var next: ActDef = session.run.next_act(state)
					if session.flow.can_go_deeper():
						label = "Leave the Pedlar: on to Act %d, or go deeper" % next.act if next != null else "Leave the Pedlar: end the run, or go deeper"
					else:
						label = "Leave the Pedlar: on to Act %d" % next.act if next != null else "Leave the Pedlar: the run's end"
				body.add_child(UiStyle.primary(UiStyle.button(label, _do.bind(session.flow.leave_shop))))
			RunState.Phase.NODES:
				_fill_nodes()
			RunState.Phase.NODE:
				_fill_node()
			RunState.Phase.CHOICE:
				_fill_choice()
	body.add_child(message)
	hero_bar.refresh()


## Opens a hero's panel from its card (again: closes it).
func open_panel(hero_id: String) -> void:
	if hero_panel.visible and hero_panel.showing == hero_id:
		hero_panel.close()
		return
	var hero: RunState.Hero = session.state().hero(hero_id)
	hero_panel.editable = not hero.transformed
	hero_panel.apex_editable = session.state().apex_open and hero.transformed and not hero.apex_earned
	hero_panel.open(hero_id)
	hero_bar.select(hero_id)


## The apex vow, from the hero panel or the day's apex section (phase 8
## part 2).
func _vow_apex(hero_id: String, apex_id: String, _stage: PathDef.Stage) -> void:
	_do(session.flow.vow_apex.bind(hero_id, apex_id))
	if hero_panel.visible:
		hero_panel.show_hero(hero_id)


func _switch_vow(hero_id: String, path_id: String, stage: PathDef.Stage) -> void:
	if stage != PathDef.Stage.VOWED:
		return
	_do(session.flow.switch_vow.bind(hero_id, path_id))
	if hero_panel.visible:
		hero_panel.show_hero(hero_id)


## Runs a RunFlow action through the session; shows why if it's refused.
func _do(action: Callable) -> void:
	var said: String = session.act(action)
	refresh()
	if not said.is_empty():
		message.text = said.capitalize() if said.length() < 3 else said[0].to_upper() + said.substr(1)


# --- pieces ------------------------------------------------------------------------

func _section(title: String, line: String = "") -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 12)
	section.add_child(UiStyle.heading(title, 30, UiStyle.TEXT))
	if not line.is_empty():
		section.add_child(_wrapped(line, 17, UiStyle.TEXT_DIM))
	body.add_child(section)
	return section


## A card (the mock's rounded navy box) in `row`, holding a column.
static func _card(row: Container, width: int = 0, rim: Color = UiStyle.LINE_500) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style: StyleBoxFlat = UiStyle.box(UiStyle.NAVY_750, rim, 1 if rim == UiStyle.LINE_500 else 2, 12)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(width, 0)
	if width == 0:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	return column


## A card's head: its icon (ItemIcon; phase 5b) beside its kind and name.
static func _card_head(card: VBoxContainer, icon: Control, kind: Control, title: Control) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	card.add_child(head)
	head.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 2)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(words)
	words.add_child(kind)
	words.add_child(title)


static func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	return row


static func _wrapped(text: String, size: int, color: Color) -> Label:
	var label: Label = UiStyle.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


## A line for each growing card the last fight stepped up (phase 5c step 4):
## "Notched Bow (Maren): now +3% ATK".
static func grew_lines(run_session: RunSession) -> Array[String]:
	var state: RunState = run_session.state()
	var lines: Array[String] = []
	for key: String in state.grew:
		var hero_id: String = key.get_slice(":", 0)
		var card_id: String = key.get_slice(":", 1)
		if hero_id.is_empty():
			var relic: RelicDef = run_session.run.relics[card_id]
			lines.append("%s: %s" % [relic.name, ModInfo.growth_now(relic.grows, state.growth.get(card_id, 0), null, run_session.content)])
		else:
			var upgrade: UpgradeDef = run_session.run.upgrades[card_id]
			var hero: RunState.Hero = state.hero(hero_id)
			var name: String = ArenaView.label_for(run_session.content.heroes[hero_id].kit, run_session.content)
			lines.append("%s (%s): %s" % [upgrade.name, name, ModInfo.growth_now(upgrade.grows, hero.growth.get(card_id, 0), run_session.run.hero_kit(hero), run_session.content)])
	return lines


## A hero's short name ("Vell"), as the board and the hero bar call them.
func _hero_name(hero_id: String) -> String:
	return ArenaView.label_for(session.content.heroes[hero_id].kit, session.content)


# --- what's waiting ----------------------------------------------------------------

func _fill_waiting() -> void:
	var state: RunState = session.state()
	if not state.grew.is_empty():
		var section: VBoxContainer = _section("What grew", "Growing cards step up with what the heroes do, for the rest of the run.")
		for line: String in grew_lines(session):
			section.add_child(_wrapped(line, 17, UiStyle.HIGHLIGHT))
	if not state.ranked.is_empty():
		var section: VBoxContainer = _section("Ranked up", "Items rank up with use, for the rest of the run.")
		for id: String in state.ranked:
			var item: ItemDef = session.run.items[id]
			var rank: int = state.item_ranks.get(id, 1)
			section.add_child(_wrapped("%s: rank %s · %s" % [item.name, ItemDef.RANK_NAMES[rank - 1], ModInfo.item_numbers(item, null, session.content, rank)], 17, UiStyle.HIGHLIGHT))
	for hero_id: String in state.just_transformed:
		var path: PathDef = session.path_of(hero_id)
		var section: VBoxContainer = _section("%s transforms: %s" % [_hero_name(hero_id), path.name], path.transformed_text)
		section.add_child(_wrapped("Cost: " + path.transformed_cost, 17, UiStyle.BAD))
	for hero_id: String in state.just_apexed:
		var apex: ApexDef = session.apex_of(hero_id)
		_section("%s reaches the apex: %s" % [_hero_name(hero_id), apex.name], apex.text)
	_fill_apex_vows()
	if not state.pick.is_empty():
		_fill_pick()
	if not state.relic_choice.is_empty():
		_fill_relic_choice()


## The apex vow, while any hero waits on it (phase 8 part 2): each waiting
## hero's apexes as cards, Vow on one. It can wait: the hero panel offers it
## too, and the run goes on without it.
func _fill_apex_vows() -> void:
	var waiting: Array[String] = session.flow.apex_waiting()
	if waiting.is_empty():
		return
	var section: VBoxContainer = _section("The apex vow is open", "A transformed hero can vow to one of its path's two apexes: the taste comes at once, and when the apex deed fills, the hero transforms again. The vow can be switched for free until then.")
	for hero_id: String in waiting:
		var path: PathDef = session.path_of(hero_id)
		section.add_child(UiStyle.strong("%s (%s)" % [_hero_name(hero_id), path.name], 20, UiStyle.TEXT))
		var row: HBoxContainer = _row()
		section.add_child(row)
		for apex: ApexDef in path.apexes:
			var card: VBoxContainer = _card(row, 0, UiStyle.GOLD_500)
			card.add_child(UiStyle.heading(apex.name, 26, UiStyle.TEXT))
			card.add_child(_wrapped(apex.fantasy, 16, UiStyle.TEXT_DIM))
			card.add_child(_wrapped("Taste: " + apex.taste, 17, UiStyle.HIGHLIGHT))
			card.add_child(_wrapped("Apex: " + apex.text, 17, UiStyle.ACCENT_TEXT))
			card.add_child(_wrapped("Deed: %s (%s)" % [apex.deed.text, UnitInfo.deed_amount_text(apex.deed, apex.deed.threshold)], 16, UiStyle.TEXT_DIM))
			card.add_child(UiStyle.primary(UiStyle.button("Vow to %s" % apex.name, _vow_apex.bind(hero_id, apex.id, PathDef.Stage.APEX_VOWED))))


func _fill_pick() -> void:
	var state: RunState = session.state()
	var section: VBoxContainer = _section("Choose an upgrade", "Upgrades are permanent. Each card names the hero it's for.")
	var row: HBoxContainer = _row()
	section.add_child(row)
	for i: int in state.pick.size():
		var upgrade: UpgradeDef = session.run.upgrades[state.pick[i]]
		var card: VBoxContainer = _card(row, 0, UiStyle.GOLD_500)
		_card_head(card, ItemIcon.for_upgrade(upgrade, CARD_ICON), UiStyle.caps(RunDayScreen.upgrade_source(upgrade, session.content), 14, UiStyle.HIGHLIGHT),
			UiStyle.heading(upgrade.name, 26, UiStyle.TEXT))
		card.add_child(UiStyle.label("for %s" % _hero_name(upgrade.hero), 16, UiStyle.TEXT_DIM))
		card.add_child(_wrapped(upgrade.text, 17, UiStyle.TEXT))
		var numbers: String = ModInfo.upgrade_numbers(upgrade, session.run.hero_kit(state.hero(upgrade.hero)), session.content)
		if upgrade.stacks():
			numbers = ModInfo.stack_now(upgrade, session.run.stack_amount(state.hero(upgrade.hero), upgrade))
		_add_numbers(card, numbers)
		card.add_child(UiStyle.primary(UiStyle.button("Take", _do.bind(session.flow.take_pick.bind(i)))))
	section.add_child(UiStyle.button("Take %d shards instead" % session.flow.act.pick_shards, _do.bind(session.flow.take_shards)))


## "HERO · MAREN", "TASTE · DEADEYE", or "PATH · DEADEYE" (the mock's;
## phase 5c step 7's layers).
static func upgrade_source(upgrade: UpgradeDef, content: ContentDb) -> String:
	if upgrade.layer == UpgradeDef.Layer.HERO:
		return "HERO · %s" % ArenaView.label_for(content.heroes[upgrade.hero].kit, content).to_upper()
	if upgrade.layer == UpgradeDef.Layer.APEX:
		return "APEX · %s" % content.apexes[upgrade.apex].name.to_upper()
	return "%s · %s" % [UpgradeDef.LAYER_NAMES[upgrade.layer].to_upper(), content.paths[upgrade.path].name.to_upper()]


func _fill_relic_choice() -> void:
	var state: RunState = session.state()
	var price: int = state.relic_choice_price
	var section: VBoxContainer = _section("Choose a relic, or neither", "Once taken, a relic stays for the run (%d so far)." % state.relics.size())
	var row: HBoxContainer = _row()
	section.add_child(row)
	for i: int in state.relic_choice.size():
		var relic: RelicDef = session.run.relics[state.relic_choice[i]]
		var label: String = "Take · %d shards" % price if price > 0 else "Take"
		if state.shrine.begins_with("wound:"):
			label = "Take · a wound on %s" % _hero_name(state.shrine.trim_prefix("wound:"))
		elif state.shrine.begins_with("relic:"):
			label = "Take · give up %s" % session.run.relics[state.shrine.trim_prefix("relic:")].name
		_relic_card(row, relic).add_child(UiStyle.primary(UiStyle.button(label, _do.bind(session.flow.take_relic.bind(i)))))
	section.add_child(UiStyle.button("Take neither", _do.bind(session.flow.decline_relic)))


func _relic_card(row: Container, relic: RelicDef) -> VBoxContainer:
	var card: VBoxContainer = _card(row, 0, UiStyle.RIFT_300)
	_card_head(card, ItemIcon.for_relic(relic, CARD_ICON), UiStyle.caps("%s RELIC" % RelicDef.TIER_LABELS[relic.tier].to_upper(), 14, TIER_COLORS[relic.tier]),
		UiStyle.heading(relic.name, 26, UiStyle.TEXT))
	card.add_child(_wrapped(relic.flavor, 16, UiStyle.TEXT_DIM))
	card.add_child(_wrapped(relic.text, 17, UiStyle.TEXT))
	_add_numbers(card, ModInfo.relic_numbers(relic, session.content))
	return card


# --- the nodes (phase 5c step 8) ---------------------------------------------------

## The day's nodes: a card each (Camp, Rift Tear, the Magpie), one taken.
func _fill_nodes() -> void:
	var state: RunState = session.state()
	var section: VBoxContainer = _section("Where to, before day %d" % (state.day + 1), "Take one. Camp's options and the Magpie happen now; a Rift Tear is for tomorrow's fight.")
	var row: HBoxContainer = _row()
	section.add_child(row)
	for i: int in state.nodes.size():
		var id: String = state.nodes[i]
		var node_name: String = RunDayScreen.node_name(session.run, id)
		var card: VBoxContainer = _card(row)
		var title := HBoxContainer.new()
		title.add_theme_constant_override("separation", 12)
		card.add_child(title)
		title.add_child(RunDayScreen.art_icon(RunDayScreen.node_icon(session.run, id), OPTION_ICON))
		var name_label: Label = UiStyle.heading(node_name, 26, UiStyle.TEXT)
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title.add_child(name_label)
		if id.begins_with("event:"):
			card.add_child(UiStyle.caps("EVENT", 14, UiStyle.HIGHLIGHT))
		card.add_child(_wrapped(RunDayScreen.node_text(session.run, id), 17, UiStyle.TEXT))
		card.add_child(UiStyle.primary(UiStyle.button("Go to %s" % node_name, _do.bind(session.flow.choose_node.bind(i)))))


## In a node: camp's options, the Magpie's stall, or a Rift Tear taken;
## then on to the next day.
func _fill_node() -> void:
	var state: RunState = session.state()
	match state.node:
		"camp":
			_fill_camp()
		"magpie":
			_fill_shop()
		"rift_tear":
			_fill_depths()
		"oath":
			_fill_oath()
		_:
			if state.node.begins_with("event:"):
				_fill_event()
	var walking_away: bool = (state.node.begins_with("event:") or state.node == "oath") and not state.event_done
	var leave: String = ("Walk away · on to day %d" if walking_away else "On to day %d") % (state.day + 1)
	body.add_child(UiStyle.primary(UiStyle.button(leave, _do.bind(session.flow.leave_node))))


## An event's scene (phase 5c step 8c): its text, then a card per choice
## (its label, what it does, and a button, or one per hero, item, or path
## it can be for; greyed where it can't be done). Walking away is the
## node's leave button.
func _fill_event() -> void:
	var state: RunState = session.state()
	var flow: RunFlow = session.flow
	var scene: EventDef.Scene = flow.event_scene()
	var section: VBoxContainer = _section(scene.name, scene.text)
	if state.event_done:
		section.add_child(UiStyle.label("Chosen.", 17, UiStyle.ACCENT_TEXT))
		if not state.hunt.is_empty():
			_fill_hunt()
		return
	var row: HBoxContainer = _row()
	section.add_child(row)
	for i: int in scene.choices.size():
		var choice: EventDef.Choice = scene.choices[i]
		var card: VBoxContainer = _card(row)
		card.add_child(UiStyle.heading(choice.label, 24, UiStyle.TEXT))
		card.add_child(_wrapped(choice.text, 16, UiStyle.TEXT))
		if choice.needs() == EventDef.Needs.NOTHING:
			var button: Button = UiStyle.primary(UiStyle.button(choice.label, _do.bind(flow.choose_event.bind(i, ""))))
			var why: String = flow.event_problem(i)
			button.disabled = not why.is_empty()
			button.tooltip_text = why
			card.add_child(button)
			continue
		for target: String in flow.event_targets(choice):
			var why: String = flow.event_problem(i, target)
			var button: Button = UiStyle.button("%s · %s" % [choice.label, _target_name(target)], _do.bind(flow.choose_event.bind(i, target)))
			button.disabled = not why.is_empty()
			button.tooltip_text = why
			card.add_child(button)


## A choice's target as the player reads it: a hero's name, an item's, or
## "Maren to Trapper".
func _target_name(target: String) -> String:
	if target.contains(":"):
		return "%s to %s" % [_hero_name(target.get_slice(":", 0)), session.content.paths[target.get_slice(":", 1)].name]
	if session.run.items.has(target):
		return session.run.items[target].name
	return _hero_name(target)


## A Bloodied Oath (phase 5c step 8c): its two oaths, each on its hero
## (burden and reward); take one, or walk away.
func _fill_oath() -> void:
	var state: RunState = session.state()
	var events: EventDef = session.run.events
	var section: VBoxContainer = _section("A Bloodied Oath", "Each oath binds the hero named on it for their next %d fights. Take one, or pass." % events.oath_fights)
	if state.event_done:
		section.add_child(UiStyle.label("Sworn.", 17, UiStyle.ACCENT_TEXT))
		return
	var row: HBoxContainer = _row()
	section.add_child(row)
	for i: int in state.oath_offer.size():
		var oath: EventDef.Oath = events.oath(state.oath_offer[i].get_slice(":", 0))
		var hero_id: String = state.oath_offer[i].get_slice(":", 1)
		var card: VBoxContainer = _card(row, 0, UiStyle.RIFT_300)
		card.add_child(UiStyle.caps(_hero_name(hero_id).to_upper(), 14, UiStyle.HIGHLIGHT))
		card.add_child(UiStyle.heading(oath.name, 24, UiStyle.TEXT))
		card.add_child(_wrapped("Burden: " + oath.burden, 16, UiStyle.TEXT))
		card.add_child(_wrapped("Reward: " + oath.reward, 16, UiStyle.ACCENT_TEXT))
		card.add_child(UiStyle.primary(UiStyle.button("Swear %s to it" % _hero_name(hero_id), _do.bind(session.flow.take_oath.bind(i)))))


## A Rift Tear's depths (phase 5c step 8b): a card each, with the rift
## modifiers it adds (the day's, shown before one's chosen); then the one
## chosen.
func _fill_depths() -> void:
	var state: RunState = session.state()
	var run: RunContent = session.run
	if not state.rift_depth.is_empty():
		_section("Rift Tear: %s" % run.camps.depth(state.rift_depth).name, RunDayScreen.rift_line(run, state))
		return
	var section: VBoxContainer = _section("Rift Tear: how deep?", "Tomorrow's fight comes through the tear. The deeper, the harder, and the better the relics for winning it.")
	var row: HBoxContainer = _row()
	section.add_child(row)
	var drawn: Array[String] = Offers.rift_modifiers(run, state)
	for i: int in run.camps.depths.size():
		var depth: CampsDef.Depth = run.camps.depths[i]
		var card: VBoxContainer = _card(row, 0, UiStyle.RIFT_300)
		card.add_child(UiStyle.heading(depth.name, 26, UiStyle.TEXT))
		card.add_child(_wrapped(depth.text, 17, UiStyle.TEXT))
		for id: String in drawn.slice(0, depth.modifiers):
			var modifier: CampsDef.Modifier = run.camps.modifiers[id]
			card.add_child(_wrapped("%s: %s" % [modifier.name, modifier.text], 16, UiStyle.RIFT_300))
		card.add_child(UiStyle.primary(UiStyle.button("Go %s" % depth.name.to_lower(), _do.bind(session.flow.choose_depth.bind(i)))))


## The Shrine's offerings (phase 5c step 8b): shards, a wound on a hero, or a
## relic for one a tier higher.
func _fill_shrine() -> void:
	var state: RunState = session.state()
	var run: RunContent = session.run
	var section: VBoxContainer = _section("The Shrine asks an offering", "Offer something for a relic. Nothing is given up unless you take the relic.")
	var row: HBoxContainer = _row()
	section.add_child(row)
	var shards: VBoxContainer = _card(row)
	shards.add_child(UiStyle.heading("Shards", 24, UiStyle.TEXT))
	shards.add_child(_wrapped("For a rare relic.", 16, UiStyle.TEXT_DIM))
	var pay: Button = UiStyle.button("Offer %d shards" % session.flow.act.shrine_price, _do.bind(session.flow.shrine_offer.bind("shards", "")))
	pay.disabled = state.shards < session.flow.act.shrine_price
	shards.add_child(pay)
	var blood: VBoxContainer = _card(row)
	blood.add_child(UiStyle.heading("Blood", 24, UiStyle.TEXT))
	blood.add_child(_wrapped("A wound on a hero, for a rare relic.", 16, UiStyle.TEXT_DIM))
	for hero: RunState.Hero in state.heroes:
		if hero.wounds < session.content.tuning.max_wounds:
			blood.add_child(UiStyle.button("Offer a wound on %s" % _hero_name(hero.id), _do.bind(session.flow.shrine_offer.bind("wound", hero.id))))
	var relics: VBoxContainer = _card(row)
	relics.add_child(UiStyle.heading("A relic", 24, UiStyle.TEXT))
	relics.add_child(_wrapped("One you hold, for a relic a tier higher.", 16, UiStyle.TEXT_DIM))
	for id: String in state.relics:
		var tier: String = session.flow.shrine_tier(id)
		if not tier.is_empty():
			relics.add_child(UiStyle.button("Offer %s (for %s)" % [run.relics[id].name, "an " + tier if tier == "epic" else "a " + tier], _do.bind(session.flow.shrine_offer.bind("relic", id))))


# --- camp -------------------------------------------------------------------------

func _fill_camp() -> void:
	var state: RunState = session.state()
	var camps: CampsDef = session.run.camps
	var place_line: String = ""
	for place: CampsDef.Place in camps.places:
		if place.id == state.place:
			place_line = place.text
	var section: VBoxContainer = _section("Camp: %s" % RunDayScreen.place_name(session), place_line)
	# The place's node (the Magpie's on his day) beside the heading (phase 5b).
	var heading: Control = section.get_child(0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	section.add_child(head)
	section.move_child(head, 0)
	head.add_child(RunDayScreen.art_icon(RunDayScreen.place_icon(session), PLACE_ICON))
	heading.reparent(head)
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if state.camp_used.is_empty():
		var row: HBoxContainer = _row()
		section.add_child(row)
		for i: int in state.camp.size():
			var option: CampsDef.Option = camps.options[state.camp[i]]
			var card: VBoxContainer = _card(row)
			var title := HBoxContainer.new()
			title.add_theme_constant_override("separation", 12)
			card.add_child(title)
			title.add_child(RunDayScreen.art_icon(option.icon, OPTION_ICON))
			var name_label: Label = UiStyle.heading(option.name, 26, UiStyle.TEXT)
			name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			title.add_child(name_label)
			card.add_child(_wrapped(option.text, 17, UiStyle.TEXT))
			card.add_child(UiStyle.primary(UiStyle.button("Choose", _do.bind(session.flow.choose_camp.bind(i)))))
	else:
		section.add_child(UiStyle.label("Taken: %s" % camps.options[state.camp_used].name, 17, UiStyle.ACCENT_TEXT))
	if not state.hunt.is_empty():
		_fill_hunt()
	if state.mapping:
		_fill_mapping()
	if state.shrine == "open":
		_fill_shrine()
	if state.dig_in and state.rock.is_empty():
		body.add_child(_wrapped("Dig In: you'll set your rock on the board before the fight (click a hex of your zone).", 17, UiStyle.TEXT_DIM))


## A Hunt's pack waiting (camp's Hunt, or Carrion Birds): Fight the Hunt.
func _fill_hunt() -> void:
	var hunt: EncounterDef = session.content.encounters[session.state().hunt]
	var hunt_section: VBoxContainer = _section("The Hunt: %s" % hunt.name, "A small pack, fought now for %d shards. Losing it isn't a loss." % session.flow.act.pay["hunt"])
	hunt_section.add_child(_enemies_line(hunt))
	hunt_section.add_child(UiStyle.primary(UiStyle.button("Fight the Hunt", func() -> void: fight_requested.emit())))


func _fill_mapping() -> void:
	var state: RunState = session.state()
	var section: VBoxContainer = _section("Map the Rift", "Swap one of tomorrow's fights for another of its kind.")
	var row: HBoxContainer = _row()
	section.add_child(row)
	var tomorrow: Array = state.options[state.day]
	for i: int in tomorrow.size():
		var encounter: EncounterDef = session.content.encounters[tomorrow[i]]
		var card: VBoxContainer = _card(row)
		card.add_child(UiStyle.heading(encounter.name, 24, UiStyle.TEXT))
		card.add_child(_wrapped("It tests %s." % encounter.tests, 16, UiStyle.TEXT_DIM))
		card.add_child(UiStyle.button("Swap it", _do.bind(session.flow.swap_fight.bind(i))))


func _fill_shop() -> void:
	var state: RunState = session.state()
	var magpie: bool = state.shop == "magpie"
	var section: VBoxContainer = _section("The Magpie" if magpie else "The Pedlar",
		"What he took from bands who fell in the rift: charms already at rank II, a relic cheap. One look. He buys relics, and swaps one a visit." if magpie
			else "Charms, tactics, sigils, and gambits; one you own comes a rank up. He buys yours back for half.")
	# The keeper's scene behind the wares (phase 5b).
	var stage: ShopStage = ShopStage.make(state.shop)
	section.add_child(stage)
	var row: HFlowContainer = stage.wares
	for i: int in state.wares.size():
		if state.wares[i].is_empty():
			continue
		var item: ItemDef = session.run.items[state.wares[i]]
		# Owned, buying it is its next rank; the Magpie's are rank II at least.
		var rank: int = mini(state.item_ranks.get(item.id, 0) + 1, ItemDef.RANKS)
		if magpie:
			rank = mini(maxi(rank, 2), ItemDef.RANKS)
		var card: VBoxContainer = _item_card(row, item, rank)
		(card.get_parent() as Control).custom_minimum_size = Vector2(WARE_WIDTH, 0)
		card.add_child(UiStyle.primary(UiStyle.button("Buy · %d shards" % session.flow.price_of(item.id), _do.bind(session.flow.buy.bind(i)))))
	for i: int in state.shop_relics.size():
		if state.shop_relics[i].is_empty():
			continue
		var card: VBoxContainer = _relic_card(row, session.run.relics[state.shop_relics[i]])
		(card.get_parent() as Control).custom_minimum_size = Vector2(WARE_WIDTH, 0)
		var price: int = session.flow.relic_price(i)
		card.add_child(UiStyle.primary(UiStyle.button("Take · free" if price == 0 else "Buy · %d shards" % price, _do.bind(session.flow.buy_relic.bind(i)))))
	var more: HBoxContainer = _row()
	section.add_child(more)
	for hero: RunState.Hero in state.heroes:
		if hero.wounds > 0:
			more.add_child(UiStyle.button("Treat a wound on %s · %d shards" % [_hero_name(hero.id), session.flow.wound_price()], _do.bind(session.flow.treat_wound.bind(hero.id))))
	if not magpie:
		# The Pedlar buys back what the run owns, for half (loadout rule 9).
		for id: String in state.item_ranks:
			more.add_child(UiStyle.button("Sell %s · %d shard%s" % [session.run.items[id].name, session.flow.sell_price(id), "" if session.flow.sell_price(id) == 1 else "s"],
				_do.bind(session.flow.sell.bind(id))))
	if magpie:
		more.add_child(UiStyle.label("One look", 17, UiStyle.TEXT_DIM))
		# He buys relics, and swaps one a visit (phase 5c step 6e).
		var dealing: HFlowContainer = HFlowContainer.new()
		dealing.add_theme_constant_override("h_separation", 12)
		dealing.add_theme_constant_override("v_separation", 8)
		section.add_child(dealing)
		for id: String in state.relics:
			var relic: RelicDef = session.run.relics[id]
			dealing.add_child(UiStyle.button("Sell %s · %d shards" % [relic.name, session.flow.relic_sell_price(id)], _do.bind(session.flow.sell_relic.bind(id))))
			var swap: Button = UiStyle.button("Swap %s" % relic.name, _do.bind(session.flow.swap_relic.bind(id)))
			swap.disabled = state.magpie_swapped or relic.tier == RelicDef.Tier.BOND
			dealing.add_child(swap)
	else:
		var price: int = session.flow.reroll_price()
		more.add_child(UiStyle.button("Reroll · %d shard%s" % [price, "" if price == 1 else "s"], _do.bind(session.flow.reroll)))
		if session.flow.boss_shop():
			more.add_child(UiStyle.label("After the boss: a legendary is on offer.", 17, UiStyle.HIGHLIGHT))


## A card's numbers line (ModInfo; phase 5c, step 2: every stat change says
## its amount), under its sentence.
static func _add_numbers(card: Container, numbers: String) -> void:
	if not numbers.is_empty():
		card.add_child(_wrapped(numbers, 16, UiStyle.HIGHLIGHT))


## An item's card at `rank` (phase 5c step 6): its kind and rank, name,
## rule, that rank's numbers, and the next rank's. Nothing says who it does
## nothing on (loadout rule 2).
func _item_card(row: Container, item: ItemDef, rank: int = 1) -> VBoxContainer:
	var colors: Array[Color] = [UiStyle.CHARM, UiStyle.TACTIC, UiStyle.SIGIL, UiStyle.EMBER]
	var card: VBoxContainer = _card(row, 0, colors[item.kind])
	_card_head(card, ItemIcon.for_item(item, CARD_ICON),
		UiStyle.caps("%s · RANK %s" % [ItemDef.KIND_NAMES[item.kind].to_upper(), ItemDef.RANK_NAMES[rank - 1]], 14, colors[item.kind]),
		UiStyle.heading(item.name, 24, UiStyle.TEXT))
	card.add_child(_wrapped(item.text, 17, UiStyle.TEXT))
	_add_numbers(card, ModInfo.item_numbers(item, null, session.content, rank))
	var next: String = ModInfo.next_rank_line(item, session.content, rank)
	if not next.is_empty():
		card.add_child(_wrapped(next, 15, UiStyle.TEXT_DIM))
	return card


## What an item has counted toward its next rank: "2 of 4 won fights to
## rank II" ("" at rank III).
func _rank_progress(item: ItemDef) -> String:
	var progress: Vector2i = session.flow.rank_progress(item.id)
	if progress.y == 0:
		return ""
	var rank: int = session.state().item_ranks.get(item.id, 1)
	match item.kind:
		ItemDef.Kind.TACTIC:
			return "%ds of %ds fought to rank %s" % [progress.x / 1000, progress.y / 1000, ItemDef.RANK_NAMES[rank]]
		ItemDef.Kind.SIGIL:
			return "%d of %d casts to rank %s" % [progress.x, progress.y, ItemDef.RANK_NAMES[rank]]
		ItemDef.Kind.GAMBIT:
			return "%d of %d fights to rank %s" % [progress.x, progress.y, ItemDef.RANK_NAMES[rank]]
	return "%d of %d won fights to rank %s" % [progress.x, progress.y, ItemDef.RANK_NAMES[rank]]


# --- the route and the loadout --------------------------------------------------------

func _fill_route() -> void:
	var state: RunState = session.state()
	var kind: String = session.run.day_kind(state, state.day)
	if session.flow.floor_number() > 0:
		_fill_floor(kind)
		return
	var line: String = {"normal": "An easier fight and a harder one that pays more.", "elite": "An elite day: two elites, each built around one mechanic.", "boss": "Old Mother Ash waits."}[kind]
	var section: VBoxContainer = _section("Choose today's fight", line + " Click a fight on today's island to read it.")
	# The act map, with the selected fight's card beside it (phase 5b).
	var row: HBoxContainer = _row()
	section.add_child(row)
	act_map = ActMap.make(session)
	row.add_child(act_map)
	var beside := VBoxContainer.new()
	beside.custom_minimum_size = Vector2(ROUTE_CARD_WIDTH, 0)
	row.add_child(beside)
	act_map.node_selected.connect(_show_route_card.bind(beside))
	_show_route_card(0, beside)


## Today's fight `index`'s card: tier and pay, what it tests, its enemies,
## where they stand once Scouted, and Fight this.
func _show_route_card(index: int, holder: VBoxContainer) -> void:
	for child: Node in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	var state: RunState = session.state()
	var options: Array[String] = state.today()
	if index >= options.size():
		return
	if act_map != null:
		act_map.selected = index
		act_map.queue_redraw()
	var encounter: EncounterDef = session.content.encounters[options[index]]
	var card: VBoxContainer = _card(holder)
	var node: String = ActMap.TIER_NODES.get(encounter.tier, "fight")
	_card_head(card, RunDayScreen.art_icon("nodes/%s.svg" % node, CARD_ICON), UiStyle.caps("%s · %d shards" % [encounter.tier.to_upper(), session.flow.act.pay[encounter.tier]], 14, UiStyle.HIGHLIGHT),
		UiStyle.heading(encounter.name, 26, UiStyle.TEXT))
	card.add_child(_wrapped("It tests %s." % encounter.tests, 16, UiStyle.TEXT_DIM))
	card.add_child(_enemies_line(encounter))
	var specialized: String = RunDayScreen.specs_line(session.content, encounter, state.today_specs[index] if index < state.today_specs.size() else [])
	if not specialized.is_empty():
		card.add_child(_wrapped(specialized, 16, UiStyle.HIGHLIGHT))
	if state.scouted.has(state.day) or session.run.relic_rule(state, "always_scout"):
		card.add_child(_wrapped("Scouted: " + RunDayScreen.placements(encounter, session.content), 15, UiStyle.ACCENT_TEXT))
	if not state.rift_depth.is_empty():
		card.add_child(_wrapped(RunDayScreen.rift_line(session.run, state), 15, UiStyle.RIFT_300))
	if session.flow.floor_number() > 0:
		card.add_child(_wrapped(RunDayScreen.floor_line(session.flow), 15, UiStyle.RIFT_300))
	card.add_child(UiStyle.primary(UiStyle.button("Fight this", _do.bind(session.flow.choose_fight.bind(index)))))


## An endless floor's route (phase 8 part 1, Decision 2): its one fight's
## card, after a line on the floor and the rift modifiers gathered so far.
func _fill_floor(kind: String) -> void:
	var line: String = {"normal": "The rift grows deeper.", "elite": "An elite floor.", "boss": "Old Mother Ash waits again, stronger."}[kind]
	var section: VBoxContainer = _section("Floor %d" % session.flow.floor_number(), line + " The first loss ends the run.")
	var gathered: Array[String] = []
	for id: String in session.state().endless_mods:
		var modifier: CampsDef.Modifier = session.run.camps.modifiers[id]
		gathered.append("%s: %s" % [modifier.name, modifier.text])
	if not gathered.is_empty():
		section.add_child(_wrapped("The rift's modifiers, for good:\n" + "\n".join(gathered), 15, UiStyle.RIFT_300))
	var beside := VBoxContainer.new()
	beside.custom_minimum_size = Vector2(ROUTE_CARD_WIDTH, 0)
	section.add_child(beside)
	_show_route_card(0, beside)


## An endless floor's numbers (phase 8 part 1): "Floor 4: enemies ×1.74 HP
## and ATK, Rift Collapse from 41s, crumbled ground ×1.74."
static func floor_line(flow: RunFlow) -> String:
	var floor_now: int = flow.floor_number()
	var endless: ActDef.Endless = flow.act.endless
	@warning_ignore("integer_division")
	var start_s: int = maxi(flow.run.content.tuning.collapse_start_ticks / FixedMath.TICKS_PER_SECOND - endless.collapse_step_ms * floor_now / 1000, endless.collapse_floor_ms / 1000)
	return "Floor %d: enemies ×%s HP and ATK, Rift Collapse from %ds, crumbled ground ×%s." % [floor_now,
		RunDayScreen.times(ActDef.Endless.compound(endless.growth_bp, floor_now)), start_s, RunDayScreen.times(ActDef.Endless.compound(endless.crumble_growth_bp, floor_now))]


## Basis points as a multiplier: 15209 is "1.52", 662118 is "66.2", larger
## shortened ("1.2k").
static func times(bp: int) -> String:
	if bp >= 10000000:
		@warning_ignore("integer_division")
		return UiStyle.short_number(bp / 10000)
	if bp >= 100000:
		@warning_ignore("integer_division")
		return "%d.%d" % [bp / 10000, bp % 10000 / 1000]
	@warning_ignore("integer_division")
	return "%d.%02d" % [bp / 10000, bp % 10000 / 100]


## After the act's boss shop (phase 8 part 1): end the run won, or go
## deeper; after Act 1 in a testing run (phase 8 part 3), on to Act 2 too.
func _fill_choice() -> void:
	var state: RunState = session.state()
	var boss: String = session.content.encounters[state.options.back()[0]].name if not state.options.is_empty() and not (state.options.back() as Array).is_empty() else "The boss"
	var next: ActDef = session.run.next_act(state)
	var testing: bool = session.flow.act.endless != null and session.flow.act.endless.testing
	var section: VBoxContainer = _section("%s is beaten" % boss, "Act %d is won. %sGo deeper into the rift%s: every floor's enemies are stronger, a rift modifier joins every third floor for good, Rift Collapse comes sooner, and the first loss ends the run. Your heroes, relics, loadout, and shards go with you." % [state.act,
		"Go on to Act %d, or " % next.act if next != null else "End the run here, or ", " (a testing option)" if testing else ""])
	var best: Dictionary = RunRecords.best(session.records_path, state.act)
	if not best.is_empty():
		section.add_child(_wrapped("Your deepest after Act %d so far: floor %d." % [state.act, int(best["floor"])], 16, UiStyle.HIGHLIGHT))
	var row: HBoxContainer = _row()
	section.add_child(row)
	row.add_child(UiStyle.button("End the run", _do.bind(session.flow.end_run)))
	if next != null:
		row.add_child(UiStyle.primary(UiStyle.button("On to Act %d" % next.act, _do.bind(session.flow.next_act))))
	var deeper: Button = UiStyle.button("Go deeper (testing)" if testing else "Go deeper", _do.bind(session.flow.go_deeper))
	row.add_child(deeper if next != null else UiStyle.primary(deeper))


## The next day fight's Rift Tear (phase 5c step 8b): "Through a Deep rift
## tear: a Shield of a tenth of their max HP; Hastened: ...".
static func rift_line(run: RunContent, state: RunState) -> String:
	var depth: CampsDef.Depth = run.camps.depth(state.rift_depth)
	if depth == null:
		return ""
	var parts: Array[String] = ["a Shield of a tenth of their max HP"]
	for id: String in state.rift_mods:
		var modifier: CampsDef.Modifier = run.camps.modifiers[id]
		parts.append("%s (%s)" % [modifier.name, modifier.text])
	return "Through a %s rift tear: %s." % [depth.name, "; ".join(parts)]


## "Rift Hound ×2: Pounces on your weakest back-liner", one line each.
func _enemies_line(encounter: EncounterDef) -> Label:
	var counts: Dictionary[String, int] = {}
	var order: Array[String] = []
	for placed: EncounterDef.Placed in encounter.enemies:
		if not counts.has(placed.enemy):
			order.append(placed.enemy)
		counts[placed.enemy] = counts.get(placed.enemy, 0) + 1
	var lines: Array[String] = []
	for id: String in order:
		var enemy: EnemyDef = session.content.enemies[id]
		lines.append("%s%s: %s" % [enemy.name, " ×%d" % counts[id] if counts[id] > 1 else "", enemy.threat])
	return _wrapped("\n".join(lines), 16, UiStyle.TEXT)


## Today's fight's specializations (phase 8 part 3), one line each: "2
## Gnawing Rift Pups: Its bites make you Bleed, and the Bleed stacks."; ""
## if none.
static func specs_line(content: ContentDb, encounter: EncounterDef, drawn: Array) -> String:
	var counts: Dictionary[String, int] = {}
	var order: Array[String] = []
	for spec_id: Variant in drawn:
		var id: String = str(spec_id)
		if id.is_empty() or not content.specializations.has(id):
			continue
		if not counts.has(id):
			order.append(id)
		counts[id] = counts.get(id, 0) + 1
	var lines: Array[String] = []
	for id: String in order:
		var spec: SpecializationDef = content.specializations[id]
		var who: String = "%s %s" % [spec.name, content.enemies[spec.enemy].name]
		lines.append("%s: %s" % [who if counts[id] == 1 else "%d %ss" % [counts[id], who], spec.text])
	return "Specialized: " + "\n".join(lines) if not lines.is_empty() else ""


## Where a fight's enemies stand: "Rift Hound (1, 4), ...".
static func placements(encounter: EncounterDef, content: ContentDb) -> String:
	var parts: Array[String] = []
	for placed: EncounterDef.Placed in encounter.enemies:
		parts.append("%s (%d, %d)" % [content.enemies[placed.enemy].name, placed.hex.x, placed.hex.y])
	return ", ".join(parts)


func _fill_loadout() -> void:
	var state: RunState = session.state()
	var encounter: EncounterDef = session.content.encounters[state.chosen]
	var section: VBoxContainer = _section("Loadout for %s" % encounter.name, "Any hero can hold any item; one slot holds one thing, and a hero holds one tactic and one gambit. Click a filled slot to take it off.")
	for hero: RunState.Hero in state.heroes:
		var row: HBoxContainer = _row()
		row.add_child(UiStyle.strong(_hero_name(hero.id), 20, UiStyle.TEXT))
		for i: int in hero.slots.size():
			var id: String = hero.slots[i]
			var text: String = "Empty" if id.is_empty() else "%s %s" % [session.run.items[id].name, ItemDef.RANK_NAMES[state.item_ranks.get(id, 1) - 1]]
			var slot: Button = UiStyle.button(text, _do.bind(session.flow.unequip.bind(hero.id, i)))
			slot.disabled = id.is_empty()
			if not id.is_empty():
				slot.tooltip_text = _rank_progress(session.run.items[id])
			row.add_child(slot)
		# Switch Places from rank II: the player picks the moment (phase 5c
		# step 6d).
		var gambit: KitMod = session.run.loadout_gambit(hero, state)
		if gambit != null and gambit.swap_choice:
			@warning_ignore("integer_division")
			var moment: int = hero.gambit_at if hero.gambit_at > 0 else gambit.swap_ticks / FixedMath.TICKS_PER_SECOND
			for seconds: int in RunFlow.GAMBIT_MOMENTS:
				var button: Button = UiStyle.button("Switch at %ds" % seconds, _do.bind(session.flow.set_gambit_at.bind(hero.id, seconds)))
				button.disabled = seconds == moment
				row.add_child(button)
		section.add_child(row)
	var stash: VBoxContainer = _section("Stash", "" if not state.stash.is_empty() else "Nothing yet: the Pedlar sells charms, tactics, and sigils.")
	var cards: HFlowContainer = HFlowContainer.new()
	cards.add_theme_constant_override("h_separation", 18)
	cards.add_theme_constant_override("v_separation", 18)
	stash.add_child(cards)
	for id: String in state.stash:
		var item: ItemDef = session.run.items[id]
		var card: VBoxContainer = _item_card(cards, item, state.item_ranks.get(id, 1))
		var progress: String = _rank_progress(item)
		if not progress.is_empty():
			card.add_child(_wrapped(progress, 15, UiStyle.TEXT_DIM))
		(card.get_parent() as Control).custom_minimum_size = Vector2(360, 0)
		var buttons: HBoxContainer = _row()
		card.add_child(buttons)
		for hero: RunState.Hero in state.heroes:
			var free: int = hero.slots.find("")
			var equip: Button = UiStyle.button("To %s" % _hero_name(hero.id), _do.bind(session.flow.equip.bind(hero.id, maxi(free, 0), id)))
			equip.disabled = free < 0
			buttons.add_child(equip)
	body.add_child(UiStyle.primary(UiStyle.button("To the fight", func() -> void: fight_requested.emit())))


# --- after the fight, and the end -------------------------------------------------------

func _fill_after() -> void:
	var state: RunState = session.state()
	if not state.fought.is_empty():
		var last: RunState.Fought = state.fought.back()
		var encounter: EncounterDef = session.content.encounters[last.encounter]
		_section("%s: %s" % [encounter.name, RunDayScreen.outcome_word(last.outcome)], "In %ds. It paid %d shards." % [last.seconds, session.flow.act.pay[encounter.tier] + session.run.relic_sum(state, "pay_add") + (session.run.relic_sum(state, "elite_pay_add") if encounter.tier == "elite" else 0)])
	body.add_child(UiStyle.primary(UiStyle.button("Move on" if state.endless else "To the Pedlar", _do.bind(session.flow.finish_day))))


static func outcome_word(outcome: FightResult.Outcome) -> String:
	match outcome:
		FightResult.Outcome.VICTORY:
			return "Victory"
		FightResult.Outcome.DEFEAT:
			return "Defeat"
	return "A tie (it counts as a win)"


func _fill_end() -> void:
	var state: RunState = session.state()
	var won: bool = state.outcome == RunState.Outcome.WON
	var section: VBoxContainer
	if state.endless:
		# Endless (phase 8 part 1): the floor it fell on is the score.
		var floor_now: int = session.flow.floor_number()
		section = _section("The rift takes them on floor %d" % floor_now, "Act %d won, then %d floors deep, with %d relics and %d duo bonds found." % [state.act, floor_now, state.relics.size(), state.bonds_found.size()])
		var best: Dictionary = RunRecords.best(session.records_path, state.act)
		var said: String = "A new deepest: floor %d." % floor_now if session.new_best else "Your deepest: floor %d." % int(best.get("floor", floor_now))
		section.add_child(_wrapped(said, 20, UiStyle.HIGHLIGHT))
	else:
		section = _section("The rift is quiet: the run is won" if won else "The rift keeps them: the run is lost",
			"Act %d, day %d of %d, with %d relics and %d duo bonds found." % [state.act, state.day, session.flow.act.days.size(), state.relics.size(), state.bonds_found.size()])
	if session.run.acts.size() > 1 and not state.endless:
		var furthest: Dictionary = RunRecords.furthest(session.records_path)
		if session.new_furthest:
			section.add_child(_wrapped("Your furthest yet: Act %d, day %d." % [state.act, state.day], 20, UiStyle.HIGHLIGHT))
		elif not furthest.is_empty():
			section.add_child(_wrapped("Your furthest: Act %d, day %d." % [int(furthest["act"]), int(furthest["day"])], 16, UiStyle.TEXT_DIM))
	var lines: Array[String] = []
	for fought: RunState.Fought in state.fought:
		lines.append("%sDay %d%s: %s, %s in %ds" % ["Act %d, " % fought.act if state.act > 1 else "", fought.day, " (again)" if fought.attempt > 0 else "", session.content.encounters[fought.encounter].name,
			RunDayScreen.outcome_word(fought.outcome).to_lower(), fought.seconds])
	section.add_child(_wrapped("\n".join(lines), 16, UiStyle.TEXT))
	body.add_child(UiStyle.primary(UiStyle.button("Back to the title", func() -> void: finished.emit())))
