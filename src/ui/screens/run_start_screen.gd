class_name RunStartScreen
extends UiScreen
## A new run (docs/plans/rebuild-phase5-run.md, section 11): the draft
## (phase 8 part 4, Decision 5: three heroes from the roster; a hero whose
## paths aren't built yet is greyed), then each drafted hero vows to one of
## its three paths (the taste, the cost, and the deed that fills it), then
## Into the rift. A bond between two vowed paths shows as "a bond
## stirs". The run's seed is drawn when the screen opens (shown, so a run
## can be played again).

signal run_started(vows: Dictionary[String, String], run_seed: int, testing: bool)
signal back_requested

var run: RunContent
## The drafted heroes' vows (hero id -> path id), in the order drafted.
var vows: Dictionary[String, String] = {}
## Each hero's last chosen path, kept while it's off the team.
var _chosen: Dictionary[String, String] = {}
var draft_buttons: Dictionary[String, Button] = {}
var _draft: HBoxContainer
var _draft_note: Label
var _go: Button
var run_seed: int = 1
## Offer Act 1's endless (phase 8 part 3: a testing option, off by default).
var testing: bool = false
var _cards: VBoxContainer
var _stirring: Label


static func make(run_content: RunContent, seed_value: int) -> RunStartScreen:
	var screen := RunStartScreen.new()
	screen.run = run_content
	screen.run_seed = seed_value
	var content: ContentDb = run_content.content
	for hero_id: String in HeroTeam.draftable(content):
		screen._chosen[hero_id] = content.heroes[hero_id].paths[0].id
	# The first team: the old three if they can all be drafted, else the
	# first three that can.
	var team: Array[String] = HeroTeam.DEFAULT.duplicate() if HeroTeam.problem(content, HeroTeam.DEFAULT).is_empty() else HeroTeam.draftable(content).slice(0, HeroTeam.SIZE)
	for hero_id: String in team:
		screen.vows[hero_id] = screen._chosen[hero_id]
	return screen


func build() -> void:
	shows_backdrop = false
	heading("A new run: draft and vow your heroes")
	hint("Take three heroes into the rift. Each vows to one path: a small taste of it now, and a cost. Fill its deed in fights and the hero transforms. You can switch a vow between fights until then.")
	_draft = HBoxContainer.new()
	_draft.add_theme_constant_override("separation", 12)
	add_child(_draft)
	_draft_note = UiStyle.label("", 16, UiStyle.TEXT_DIM)
	add_child(_draft_note)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 16)
	add_child(_cards)
	_stirring = UiStyle.label("", 17, UiStyle.RIFT_300)
	add_child(_stirring)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_go = primary_button("Into the rift", func() -> void: run_started.emit(vows, run_seed, testing))
	row.add_child(_go)
	row.add_child(UiStyle.button("Back", func() -> void: back_requested.emit()))
	var seed_label: Label = UiStyle.label("Seed %d" % run_seed, 16, UiStyle.TEXT_DIM)
	seed_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(seed_label)
	add_child(row)
	# The testing option (phase 8 part 3, Decision 15): Act 1's endless.
	var check := CheckBox.new()
	check.text = "Endless after Act 1 (for testing)"
	check.button_pressed = testing
	check.toggled.connect(func(on: bool) -> void: testing = on)
	add_child(check)
	_fill()


func choose(hero_id: String, path_id: String) -> void:
	vows[hero_id] = path_id
	_chosen[hero_id] = path_id
	_fill()


## Drafts `hero_id` or sends it back (only a hero whose paths are built; a
## fourth sends back the one drafted first).
func draft_hero(hero_id: String) -> void:
	if vows.has(hero_id):
		vows.erase(hero_id)
	elif HeroTeam.ready(run.content, hero_id):
		if vows.size() >= HeroTeam.SIZE:
			vows.erase(vows.keys()[0])
		vows[hero_id] = _chosen[hero_id]
	_fill()


func _fill() -> void:
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	var content: ContentDb = run.content
	for child: Node in _draft.get_children():
		_draft.remove_child(child)
		child.queue_free()
	draft_buttons.clear()
	for hero_id: String in content.hero_ids:
		_draft_card(hero_id)
	_draft_note.text = "Draft %d more." % (HeroTeam.SIZE - vows.size()) if vows.size() < HeroTeam.SIZE else ""
	_go.disabled = vows.size() != HeroTeam.SIZE
	for hero_id: String in HeroTeam.ordered(content, vows.keys()):
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


## A hero's draft card: its name, title, and role, its paths, and Draft (or
## why it can't be drafted yet).
func _draft_card(hero_id: String) -> void:
	var hero: HeroDef = run.content.heroes[hero_id]
	var drafted: bool = vows.has(hero_id)
	var card: VBoxContainer = RunDayScreen._card(_draft, 0, UiStyle.TEAL_400 if drafted else UiStyle.LINE_500)
	card.add_theme_constant_override("separation", 4)
	card.add_child(UiStyle.heading(hero_id.capitalize(), 24, UiStyle.TEXT))
	card.add_child(UiStyle.label("%s · %s" % [hero.title.capitalize(), HeroDef.ROLE_NAMES[hero.role].capitalize()], 14, UiStyle.TEXT_DIM))
	var paths: Array[String] = []
	for path: PathDef in hero.paths:
		paths.append(path.name)
	var ready: bool = HeroTeam.ready(run.content, hero_id)
	card.add_child(UiStyle.label(", ".join(paths) if ready else "Paths aren't built yet.", 14, UiStyle.HIGHLIGHT if ready else UiStyle.TEXT_DIM))
	var button: Button = UiStyle.button("Drafted" if drafted else "Draft", draft_hero.bind(hero_id))
	button.disabled = not ready
	if drafted:
		UiStyle.primary(button)
	card.add_child(button)
	draft_buttons[hero_id] = button
