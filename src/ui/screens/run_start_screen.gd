class_name RunStartScreen
extends UiScreen
## A new run (docs/plans/rebuild-phase5-run.md, section 11): each hero vows
## to one of its three paths (the taste, the cost, and the deed that fills
## it), then Into the rift. A bond between two vowed paths shows as "a bond
## stirs". The run's seed is drawn when the screen opens (shown, so a run
## can be played again).

signal run_started(vows: Dictionary[String, String], run_seed: int)
signal back_requested

var run: RunContent
var vows: Dictionary[String, String] = {}
var run_seed: int = 1
var _cards: VBoxContainer
var _stirring: Label


static func make(run_content: RunContent, seed_value: int) -> RunStartScreen:
	var screen := RunStartScreen.new()
	screen.run = run_content
	screen.run_seed = seed_value
	for hero_id: String in run_content.content.hero_ids:
		screen.vows[hero_id] = run_content.content.heroes[hero_id].paths[0].id
	return screen


func build() -> void:
	shows_backdrop = false
	heading("A new run: vow your heroes")
	hint("Each hero vows to one path: a small taste of it now, and a cost. Fill its deed in fights and the hero transforms. You can switch a vow between fights until then.")
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 16)
	add_child(_cards)
	_stirring = UiStyle.label("", 17, UiStyle.RIFT_300)
	add_child(_stirring)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(primary_button("Into the rift", func() -> void: run_started.emit(vows, run_seed)))
	row.add_child(UiStyle.button("Back", func() -> void: back_requested.emit()))
	var seed_label: Label = UiStyle.label("Seed %d" % run_seed, 16, UiStyle.TEXT_DIM)
	seed_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(seed_label)
	add_child(row)
	_fill()


func choose(hero_id: String, path_id: String) -> void:
	vows[hero_id] = path_id
	_fill()


func _fill() -> void:
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	var content: ContentDb = run.content
	for hero_id: String in content.hero_ids:
		var hero: HeroDef = content.heroes[hero_id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		_cards.add_child(row)
		var name_column := VBoxContainer.new()
		name_column.custom_minimum_size = Vector2(180, 0)
		name_column.add_child(UiStyle.heading(hero.name, 28, UiStyle.TEXT))
		name_column.add_child(UiStyle.label(hero.title.capitalize(), 15, UiStyle.TEXT_DIM))
		row.add_child(name_column)
		for path: PathDef in hero.paths:
			var chosen: bool = vows[hero_id] == path.id
			var card: VBoxContainer = RunDayScreen._card(row, 0, UiStyle.TEAL_400 if chosen else UiStyle.LINE_500)
			card.add_child(UiStyle.heading(path.name, 24, UiStyle.TEXT))
			card.add_child(RunDayScreen._wrapped("Taste: " + path.taste, 15, UiStyle.HIGHLIGHT))
			card.add_child(RunDayScreen._wrapped("Cost: " + path.vowed_cost, 15, UiStyle.BAD))
			card.add_child(RunDayScreen._wrapped("Deed: %s (%s)" % [path.deed.text, UnitInfo.deed_amount_text(path.deed, path.deed.threshold)], 14, UiStyle.TEXT_DIM))
			var button: Button = UiStyle.button("Vowed" if chosen else "Vow", choose.bind(hero_id, path.id))
			if chosen:
				UiStyle.primary(button)
			card.add_child(button)
	var stirring: Array[String] = []
	for id: String in run.bond_ids:
		var bond: BondDef = run.bonds[id]
		if bond.paths.all(func(path_id: String) -> bool: return vows.values().has(path_id)):
			stirring.append("%s and %s" % [content.paths[bond.paths[0]].name, content.paths[bond.paths[1]].name])
	_stirring.text = "A bond stirs between %s: it wakes when both transform." % " and between ".join(stirring) if not stirring.is_empty() else ""
