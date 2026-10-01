class_name HeroBar
extends PanelContainer
## The hero bar along the bottom of the screen, from the playtester's mock
## (docs/mockups/hero-panel-layout.pdf, page 1): one card per hero, in
## heroes.json's order. Clicking a card opens that hero's panel (card_clicked);
## the open hero's card has a gold rim. Each card shows:
##   - the hero's figure, head and shoulders (its path's once transformed);
##   - its name, and its path in gold ("Deadeye · vowed") or teal once
##     transformed ("Hearthwall");
##   - the HP bar (live in a fight), "HP 270 / 270", and its wounds (none in
##     Practice);
##   - its vowed deed: what the last fight put into it, or in a fight what
##     this one has so far (Practice has no thresholds, so no bar yet);
##   - its three slots as chips: Charm, Tactic, Sigil. A filled slot is
##     outlined in its kind's color (the tactic it took, by name on hover);
##     charms and sigils come with the run, so theirs are empty.
## In a run (RunSession): wounds (a greyed chunk of the HP bar, and a count),
## the deed toward its threshold ("Deadeye 1,240 / 2,000"), and each slot's
## item by name.

signal card_clicked(hero_id: String)

const CARD_SIZE := Vector2(525, 162)
## An item's icon on a slot's chip (ItemIcon; phase 5b): the item's own, or
## in Practice the slot's bare frame.
const CHIP_ICON: float = 22.0

var session: PracticeSession
var cards: Dictionary[String, Card] = {}
var _row: HBoxContainer


## One hero's card.
class Card:
	extends PanelContainer
	var hero_id: String
	var portrait_holder: Control
	var name_label: Label
	var path_label: Label
	var hp_bar: UiStyle.Meter
	var hp_text: Label
	var wounds_text: Label
	var deed_text: Label
	var chips: HBoxContainer
	var selected: bool = false
	var _hovered: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void:
			_hovered = true
			restyle())
		mouse_exited.connect(func() -> void:
			_hovered = false
			restyle())

	func restyle() -> void:
		var rim: Color = UiStyle.GOLD_300 if selected else (UiStyle.LINE_400 if _hovered else UiStyle.LINE_500)
		var style: StyleBoxFlat = UiStyle.box(Color("212d43"), rim, 2 if selected else 1, 12)
		style.set_content_margin_all(10)
		add_theme_stylebox_override("panel", style)


static func make(practice: PracticeSession) -> HeroBar:
	var bar := HeroBar.new()
	bar.session = practice
	var style: StyleBoxFlat = UiStyle.box(UiStyle.NAVY_800, UiStyle.NAVY_800, 0, 0)
	style.border_color = Color("16212e")
	style.border_width_top = 2
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	bar.add_theme_stylebox_override("panel", style)
	bar._row = HBoxContainer.new()
	bar._row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar._row.add_theme_constant_override("separation", 26)
	bar.add_child(bar._row)
	for hero_id: String in practice.content.hero_ids:
		var card := Card.new()
		card.hero_id = hero_id
		card.custom_minimum_size = CARD_SIZE
		card.gui_input.connect(bar._on_card_input.bind(hero_id))
		bar._row.add_child(card)
		bar.cards[hero_id] = card
		bar._build_card(card)
	bar.refresh()
	return bar


func _build_card(card: Card) -> void:
	card.restyle()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	card.portrait_holder = Control.new()
	card.portrait_holder.custom_minimum_size = Vector2(118, 142)
	card.portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(card.portrait_holder)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 12)
	column.add_child(title)
	card.name_label = UiStyle.heading("", 28, UiStyle.TEXT)
	title.add_child(card.name_label)
	card.path_label = UiStyle.strong("", 16, UiStyle.HIGHLIGHT)
	card.path_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(card.path_label)
	card.hp_bar = UiStyle.bar(1.0, UiStyle.GOOD, 14) as UiStyle.Meter
	column.add_child(card.hp_bar)
	var hp_row := HBoxContainer.new()
	column.add_child(hp_row)
	card.hp_text = UiStyle.label("", 15, UiStyle.TEXT_DIM)
	card.hp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(card.hp_text)
	card.wounds_text = UiStyle.label("No wounds", 15, UiStyle.TEXT_DIM)
	hp_row.add_child(card.wounds_text)
	card.deed_text = UiStyle.label("", 15, UiStyle.ACCENT_TEXT)
	card.deed_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.deed_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(card.deed_text)
	card.chips = HBoxContainer.new()
	card.chips.add_theme_constant_override("separation", 8)
	column.add_child(card.chips)
	for node: Node in column.find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_card_input(event: InputEvent, hero_id: String) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
		card_clicked.emit(hero_id)


## Marks the card of the hero whose panel is open ("": none).
func select(hero_id: String) -> void:
	for id: String in cards:
		cards[id].selected = id == hero_id
		cards[id].restyle()


## Shows each hero as the session has it (placing), or as `sim` has it now
## (in a fight: HP and this fight's deed so far).
func refresh(sim: CombatSim = null) -> void:
	var amounts: Array[FightResult.Deed] = []
	if sim != null:
		amounts = sim.deed_amounts()
	for hero_id: String in cards:
		var card: Card = cards[hero_id]
		var hero: HeroDef = session.content.heroes[hero_id]
		var path: PathDef = session.path_of(hero_id)
		var stage: PathDef.Stage = session.stage_of(hero_id)
		var transformed: bool = stage == PathDef.Stage.TRANSFORMED
		var kit: UnitDef = session.kit_of(hero_id)
		var key: String = FigureArt.key_for(hero_id, true, path.id if transformed else "base")
		var existing: Portrait = card.portrait_holder.get_child(0) as Portrait if card.portrait_holder.get_child_count() > 0 else null
		if existing == null or existing.get_meta("key", "") != key:
			for child: Node in card.portrait_holder.get_children():
				card.portrait_holder.remove_child(child)
				child.free()
			var portrait: Portrait = Portrait.make(key, Vector2(118, 142), 0.5)
			portrait.headroom = 0.36
			portrait.fill = UiStyle.NAVY_700
			portrait.set_meta("key", key)
			portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			card.portrait_holder.add_child(portrait)
		card.name_label.text = ArenaView.label_for(hero.kit, session.content)
		card.path_label.text = "" if path == null else (path.name if transformed else "%s · vowed" % path.name)
		card.path_label.add_theme_color_override("font_color", UiStyle.ACCENT_TEXT if transformed else UiStyle.HIGHLIGHT)
		var max_hp: int = kit.stats.get_stat(UnitStats.Stat.HP)
		var hp: int = max_hp
		var unit: UnitState = sim.unit_by_id(hero_id) if sim != null else null
		if unit != null:
			hp = unit.hp if unit.alive else 0
			max_hp = unit.max_hp
		var run_session := session as RunSession
		if run_session != null and unit == null:
			var wounds: int = run_session.state().hero(hero_id).wounds
			card.hp_bar.lost = run_session.wound_share(hero_id)
			max_hp = FixedMath.apply_bp(max_hp, FixedMath.BP_ONE - int(round(card.hp_bar.lost * FixedMath.BP_ONE)))
			hp = max_hp
			card.wounds_text.text = "No wounds" if wounds == 0 else ("1 wound" if wounds == 1 else "%d wounds" % wounds)
			# An oath's burden and the fights it has left (phase 5c step 8c).
			var run_hero: RunState.Hero = run_session.state().hero(hero_id)
			var oath: EventDef.Oath = run_session.flow.oath_of(run_hero)
			if oath != null:
				card.wounds_text.text += " · %s (%d fight%s)" % [oath.name, run_hero.oath_fights, "" if run_hero.oath_fights == 1 else "s"]
				card.wounds_text.tooltip_text = "%s %s" % [oath.burden, oath.reward]
		card.hp_bar.set_share(float(hp) / maxf(max_hp, 1))
		card.portrait_holder.modulate = Color(0.45, 0.45, 0.5) if hp <= 0 else Color.WHITE
		card.hp_text.text = "HP %d / %d" % [hp, max_hp]
		card.deed_text.text = _deed_text(hero_id, path, sim, amounts)
		_fill_chips(card, hero_id)


func _deed_text(hero_id: String, path: PathDef, sim: CombatSim, amounts: Array[FightResult.Deed]) -> String:
	if path == null:
		return "No vow"
	var run_session := session as RunSession
	if run_session != null:
		var progress: Array = run_session.deed_progress(hero_id)
		var so_far: String = ""
		if sim != null:
			for deed: FightResult.Deed in amounts:
				if deed.hero == hero_id and deed.path == path.id:
					so_far = " · +%s now" % UnitInfo.deed_amount_text(path.deed, deed.amount)
		return "%s deed %s / %s%s" % [path.name, UnitInfo.deed_amount_text(path.deed, progress[0]), UnitInfo.deed_amount_text(path.deed, progress[1]), so_far]
	if sim != null:
		for deed: FightResult.Deed in amounts:
			if deed.hero == hero_id and deed.path == path.id:
				return "%s deed · this fight %s" % [path.name, UnitInfo.deed_amount_text(path.deed, deed.amount)]
	var last: int = session.last_deed(hero_id, path.id)
	return "%s deed · %s" % [path.name, "no fight yet" if last < 0 else "last fight %s" % UnitInfo.deed_amount_text(path.deed, last)]


func _fill_chips(card: Card, hero_id: String) -> void:
	var run_session := session as RunSession
	if run_session != null:
		_fill_run_chips(card, run_session, hero_id)
		return
	var tactic_id: String = session.tactics.get(hero_id, "")
	if card.chips.get_child_count() > 0 and card.chips.get_meta("tactic", "") == tactic_id:
		return
	card.chips.set_meta("tactic", tactic_id)
	for child: Node in card.chips.get_children():
		card.chips.remove_child(child)
		child.free()
	var tactic: TacticDef = session.content.tactics.get(tactic_id, null)
	var slots: Array[Array] = [["Charm", UiStyle.CHARM, false, "No charm (charms come with the run)"],
		["Tactic", UiStyle.TACTIC, tactic != null, tactic.name if tactic != null else "No tactic"],
		["Sigil", UiStyle.SIGIL, false, "No sigil (sigils come with the run)"]]
	for slot: Array in slots:
		var chip: PanelContainer = UiStyle.chip(slot[0], slot[1], slot[2], 14, ItemIcon.make(String(slot[0]).to_lower(), "", CHIP_ICON))
		chip.tooltip_text = slot[3]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		card.chips.add_child(chip)


## A run's slots: each item by name in its kind's color, or "Empty".
func _fill_run_chips(card: Card, run_session: RunSession, hero_id: String) -> void:
	var slots: Array[String] = run_session.state().hero(hero_id).slots
	var key: String = ",".join(slots.map(func(id: String) -> String: return "%s%d" % [id, run_session.state().item_ranks.get(id, 0)]))
	if card.chips.get_child_count() > 0 and card.chips.get_meta("slots", "") == key:
		return
	card.chips.set_meta("slots", key)
	for child: Node in card.chips.get_children():
		card.chips.remove_child(child)
		child.free()
	var colors: Array[Color] = [UiStyle.CHARM, UiStyle.TACTIC, UiStyle.SIGIL, UiStyle.EMBER]
	for id: String in slots:
		var item: ItemDef = run_session.run.items.get(id, null)
		var chip: PanelContainer = UiStyle.chip(item.name if item != null else "Empty", colors[item.kind] if item != null else UiStyle.LINE_500, item != null, 14,
			ItemIcon.for_item(item, CHIP_ICON) if item != null else null)
		var rank: int = run_session.state().item_ranks.get(id, 1)
		chip.tooltip_text = ("%s · rank %s\n%s\n%s" % [item.name, ItemDef.RANK_NAMES[rank - 1], item.text, ModInfo.item_numbers(item, null, run_session.content, rank)]).strip_edges() if item != null else "An empty slot"
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		card.chips.add_child(chip)
