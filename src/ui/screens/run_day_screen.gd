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
## Then the day's step:
##   - camp: the place, then its options (Choose); once one is taken, what it
##     opened: a shop (wares, a relic, treating wounds, a reroll), Map the
##     Rift's swap, or the Hunt (Fight the Hunt); then Break camp;
##   - the route: the act map (ActMap; phase 5b), and beside it the card of
##     today's fight selected on it (tier and pay, what it tests, its
##     enemies and their threat lines, and where they stand once Scouted);
##   - the loadout: each hero's slots (click a filled one to take it off) and
##     the stash (equip each item to a hero; "no effect" where it does
##     nothing); then To the fight;
##   - after the fight: how it went, then Next day;
##   - the run's end: won or lost, and every fight fought.

## To the arena for the waiting fight (the day's, or a Hunt).
signal fight_requested
## The run is over and the player is done with it.
signal finished

## An item's, relic's, or upgrade's icon at the head of its card.
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
	row.add_child(UiStyle.heading("Day %d of %d" % [state.day, run_session.run.act.days.size()], 34, UiStyle.HIGHLIGHT))
	var place: String = where
	if place.is_empty():
		place = RunDayScreen.place_name(run_session)
	var at: Label = UiStyle.label("Act %d · %s" % [state.act, place], 20, UiStyle.TEXT_DIM)
	at.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(at)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	for id: String in state.relics:
		var relic: RelicDef = run_session.run.relics[id]
		var chip: PanelContainer = UiStyle.chip(relic.name, UiStyle.RIFT_300, true, 15, ItemIcon.for_relic(relic, 24.0))
		chip.tooltip_text = "%s\nBoon: %s\nCost: %s\n%s" % [relic.flavor, relic.boon, relic.cost, ModInfo.relic_numbers(relic, run_session.content)]
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


## Today's camp's node: its place's, or the Magpie's on his day.
static func place_icon(run_session: RunSession) -> String:
	var state: RunState = run_session.state()
	for place: CampsDef.Place in run_session.run.camps.places:
		if place.id == state.place:
			return place.icon
	return run_session.run.camps.options["magpie"].icon


## Where the run's camp is ("the Magpie's camp" on his day).
static func place_name(run_session: RunSession) -> String:
	var state: RunState = run_session.state()
	for place: CampsDef.Place in run_session.run.camps.places:
		if place.id == state.place:
			return place.name
	return "The Magpie's camp" if state.camp.has("magpie") else "The rift"


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
			RunState.Phase.CAMP:
				_fill_camp()
			RunState.Phase.ROUTE:
				_fill_route()
			RunState.Phase.LOADOUT:
				_fill_loadout()
			RunState.Phase.AFTER:
				_fill_after()
	body.add_child(message)
	hero_bar.refresh()


## Opens a hero's panel from its card (again: closes it).
func open_panel(hero_id: String) -> void:
	if hero_panel.visible and hero_panel.showing == hero_id:
		hero_panel.close()
		return
	hero_panel.editable = not session.state().hero(hero_id).transformed
	hero_panel.open(hero_id)
	hero_bar.select(hero_id)


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
	for hero_id: String in state.just_transformed:
		var path: PathDef = session.path_of(hero_id)
		var section: VBoxContainer = _section("%s transforms: %s" % [_hero_name(hero_id), path.name], path.transformed_text)
		section.add_child(_wrapped("Cost: " + path.transformed_cost, 17, UiStyle.BAD))
	if not state.pick.is_empty():
		_fill_pick()
	if not state.relic_choice.is_empty():
		_fill_relic_choice()


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
		_add_numbers(card, ModInfo.upgrade_numbers(upgrade, session.run.hero_kit(state.hero(upgrade.hero)), session.content))
		card.add_child(UiStyle.primary(UiStyle.button("Take", _do.bind(session.flow.take_pick.bind(i)))))
	section.add_child(UiStyle.button("Take %d shards instead" % session.run.act.pick_shards, _do.bind(session.flow.take_shards)))


## "HERO · MAREN", "VOW · DEADEYE", or "PATH · DEADEYE" (the mock's).
static func upgrade_source(upgrade: UpgradeDef, content: ContentDb) -> String:
	if upgrade.layer == UpgradeDef.Layer.HERO:
		return "HERO · %s" % ArenaView.label_for(content.heroes[upgrade.hero].kit, content).to_upper()
	return "%s · %s" % ["VOW" if upgrade.vow else "PATH", content.paths[upgrade.path].name.to_upper()]


func _fill_relic_choice() -> void:
	var state: RunState = session.state()
	var section: VBoxContainer = _section("Choose a relic, or neither", "Every relic has a cost, and once taken it stays (%d so far; about 3 to 5 a run)." % state.relics.size())
	var row: HBoxContainer = _row()
	section.add_child(row)
	for i: int in state.relic_choice.size():
		var relic: RelicDef = session.run.relics[state.relic_choice[i]]
		_relic_card(row, relic).add_child(UiStyle.primary(UiStyle.button("Take", _do.bind(session.flow.take_relic.bind(i)))))
	section.add_child(UiStyle.button("Take neither", _do.bind(session.flow.decline_relic)))


func _relic_card(row: Container, relic: RelicDef) -> VBoxContainer:
	var card: VBoxContainer = _card(row, 0, UiStyle.RIFT_300)
	_card_head(card, ItemIcon.for_relic(relic, CARD_ICON), UiStyle.caps("RELIC", 14, UiStyle.RIFT_300), UiStyle.heading(relic.name, 26, UiStyle.TEXT))
	card.add_child(_wrapped(relic.flavor, 16, UiStyle.TEXT_DIM))
	card.add_child(_wrapped("Boon: " + relic.boon, 17, UiStyle.GOOD))
	card.add_child(_wrapped("Cost: " + relic.cost, 17, UiStyle.BAD))
	_add_numbers(card, ModInfo.relic_numbers(relic, session.content))
	return card


# --- camp -------------------------------------------------------------------------

func _fill_camp() -> void:
	var state: RunState = session.state()
	var camps: CampsDef = session.run.camps
	var place_line: String = ""
	for place: CampsDef.Place in camps.places:
		if place.id == state.place:
			place_line = place.text
	if state.attempt > 0 and state.camp_used.is_empty():
		place_line += " The day begins again: %d of %d losses." % [state.losses, session.run.act.losses_to_end]
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
		var hunt: EncounterDef = session.content.encounters[state.hunt]
		var hunt_section: VBoxContainer = _section("The Hunt: %s" % hunt.name, "A small pack, fought now for %d shards. Losing it isn't a loss." % session.run.act.pay["hunt"])
		hunt_section.add_child(_enemies_line(hunt))
		hunt_section.add_child(UiStyle.primary(UiStyle.button("Fight the Hunt", func() -> void: fight_requested.emit())))
	if state.mapping:
		_fill_mapping()
	if not state.shop.is_empty():
		_fill_shop()
	if state.dig_in and state.rock.is_empty():
		body.add_child(_wrapped("Dig In: you'll set your rock on the board before the fight (click a hex of your zone).", 17, UiStyle.TEXT_DIM))
	body.add_child(UiStyle.primary(UiStyle.button("Break camp", _do.bind(session.flow.leave_camp))))


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
		"What he took from bands who fell in the rift. One look, and dear." if magpie else "Charms, tactics, and sigils for what your heroes can use.")
	# The keeper's scene behind the wares (phase 5b).
	var stage: ShopStage = ShopStage.make(state.shop)
	section.add_child(stage)
	var row: HFlowContainer = stage.wares
	for i: int in state.wares.size():
		if state.wares[i].is_empty():
			continue
		var item: ItemDef = session.run.items[state.wares[i]]
		var card: VBoxContainer = _item_card(row, item)
		(card.get_parent() as Control).custom_minimum_size = Vector2(WARE_WIDTH, 0)
		card.add_child(UiStyle.primary(UiStyle.button("Buy · %d shards" % session.flow.price_of(item.id), _do.bind(session.flow.buy.bind(i)))))
	if not state.shop_relic.is_empty():
		var card: VBoxContainer = _relic_card(row, session.run.relics[state.shop_relic])
		(card.get_parent() as Control).custom_minimum_size = Vector2(WARE_WIDTH, 0)
		card.add_child(UiStyle.primary(UiStyle.button("Buy · %d shards" % session.flow.relic_price(), _do.bind(session.flow.buy_relic))))
	var more: HBoxContainer = _row()
	section.add_child(more)
	for hero: RunState.Hero in state.heroes:
		if hero.wounds > 0:
			more.add_child(UiStyle.button("Treat a wound on %s · %d shards" % [_hero_name(hero.id), session.run.act.wound_price], _do.bind(session.flow.treat_wound.bind(hero.id))))
	if not magpie:
		more.add_child(UiStyle.button("Reroll · %d shard" % session.run.act.reroll_price, _do.bind(session.flow.reroll)))


## A card's numbers line (ModInfo; phase 5c, step 2: every stat change says
## its amount), under its sentence.
static func _add_numbers(card: Container, numbers: String) -> void:
	if not numbers.is_empty():
		card.add_child(_wrapped(numbers, 16, UiStyle.HIGHLIGHT))


## An item's card: its kind, name, rule, its numbers, what it answers, and
## who it does nothing on.
func _item_card(row: Container, item: ItemDef) -> VBoxContainer:
	var colors: Array[Color] = [UiStyle.CHARM, UiStyle.TACTIC, UiStyle.SIGIL, UiStyle.EMBER]
	var card: VBoxContainer = _card(row, 0, colors[item.kind])
	_card_head(card, ItemIcon.for_item(item, CARD_ICON), UiStyle.caps(ItemDef.KIND_NAMES[item.kind].to_upper(), 14, colors[item.kind]),
		UiStyle.heading(item.name, 24, UiStyle.TEXT))
	card.add_child(_wrapped(item.text, 17, UiStyle.TEXT))
	_add_numbers(card, ModInfo.item_numbers(item, null, session.content))
	card.add_child(_wrapped(item.answers, 15, UiStyle.TEXT_DIM))
	var idle: Array[String] = []
	for hero: RunState.Hero in session.state().heroes:
		if not item.works_on(session.run.hero_kit(hero), hero.id):
			idle.append(_hero_name(hero.id))
	if not idle.is_empty():
		card.add_child(_wrapped("No effect on %s" % ", ".join(idle), 15, UiStyle.BAD))
	return card


# --- the route and the loadout --------------------------------------------------------

func _fill_route() -> void:
	var state: RunState = session.state()
	var kind: String = session.run.act.days[state.day - 1]
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
	act_map.selected = index
	act_map.queue_redraw()
	var encounter: EncounterDef = session.content.encounters[options[index]]
	var card: VBoxContainer = _card(holder)
	var node: String = ActMap.TIER_NODES.get(encounter.tier, "fight")
	_card_head(card, RunDayScreen.art_icon("nodes/%s.svg" % node, CARD_ICON), UiStyle.caps("%s · %d shards" % [encounter.tier.to_upper(), session.run.act.pay[encounter.tier]], 14, UiStyle.HIGHLIGHT),
		UiStyle.heading(encounter.name, 26, UiStyle.TEXT))
	card.add_child(_wrapped("It tests %s." % encounter.tests, 16, UiStyle.TEXT_DIM))
	card.add_child(_enemies_line(encounter))
	if state.scouted.has(state.day) or session.run.relic_rule(state, "always_scout"):
		card.add_child(_wrapped("Scouted: " + RunDayScreen.placements(encounter, session.content), 15, UiStyle.ACCENT_TEXT))
	card.add_child(UiStyle.primary(UiStyle.button("Fight this", _do.bind(session.flow.choose_fight.bind(index)))))


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


## Where a fight's enemies stand: "Rift Hound (1, 4), ...".
static func placements(encounter: EncounterDef, content: ContentDb) -> String:
	var parts: Array[String] = []
	for placed: EncounterDef.Placed in encounter.enemies:
		parts.append("%s (%d, %d)" % [content.enemies[placed.enemy].name, placed.hex.x, placed.hex.y])
	return ", ".join(parts)


func _fill_loadout() -> void:
	var state: RunState = session.state()
	var encounter: EncounterDef = session.content.encounters[state.chosen]
	var section: VBoxContainer = _section("Loadout for %s" % encounter.name, "Any hero can hold any item; one slot holds one thing, and a hero holds one tactic. Click a filled slot to take it off.")
	for hero: RunState.Hero in state.heroes:
		var row: HBoxContainer = _row()
		row.add_child(UiStyle.strong(_hero_name(hero.id), 20, UiStyle.TEXT))
		for i: int in hero.slots.size():
			var id: String = hero.slots[i]
			var text: String = "Empty" if id.is_empty() else session.run.items[id].name
			var slot: Button = UiStyle.button(text, _do.bind(session.flow.unequip.bind(hero.id, i)))
			slot.disabled = id.is_empty()
			if not id.is_empty() and not session.run.items[id].works_on(session.run.hero_kit(hero), hero.id):
				slot.text += " (no effect on this hero)"
			row.add_child(slot)
		section.add_child(row)
	var stash: VBoxContainer = _section("Stash", "" if not state.stash.is_empty() else "Nothing yet: the Pedlar sells charms, tactics, and sigils.")
	var cards: HFlowContainer = HFlowContainer.new()
	cards.add_theme_constant_override("h_separation", 18)
	cards.add_theme_constant_override("v_separation", 18)
	stash.add_child(cards)
	for id: String in state.stash:
		var item: ItemDef = session.run.items[id]
		var card: VBoxContainer = _item_card(cards, item)
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
		_section("%s: %s" % [encounter.name, RunDayScreen.outcome_word(last.outcome)], "In %ds. It paid %d shards." % [last.seconds, session.run.act.pay[encounter.tier] + session.run.relic_sum(state, "pay_add")])
	body.add_child(UiStyle.primary(UiStyle.button("Next day", _do.bind(session.flow.finish_day))))


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
	var section: VBoxContainer = _section("The rift is quiet: the run is won" if won else "The rift keeps them: the run is lost",
		"Day %d of %d, with %d relics and %d duo bonds found." % [state.day, session.run.act.days.size(), state.relics.size(), state.bonds_found.size()])
	var lines: Array[String] = []
	for fought: RunState.Fought in state.fought:
		lines.append("Day %d%s: %s, %s in %ds" % [fought.day, " (again)" if fought.attempt > 0 else "", session.content.encounters[fought.encounter].name,
			RunDayScreen.outcome_word(fought.outcome).to_lower(), fought.seconds])
	section.add_child(_wrapped("\n".join(lines), 16, UiStyle.TEXT))
	body.add_child(UiStyle.primary(UiStyle.button("Back to the title", func() -> void: finished.emit())))
