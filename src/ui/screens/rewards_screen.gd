class_name RewardsScreen
extends UiScreen
## After a win: the spoils on a parchment ledger. Take or pass each reward
## (a relic choice takes one of three). After an elite, a rank-up to give to
## one hero (docs/plans/heroes-and-deeds.md, section 3).


func build() -> void:
	add_theme_constant_override("separation", 18)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	add_child(spacer)
	var page: VBoxContainer = card("panel_parchment", 1000)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	page.add_child(top)
	top.add_child(UiStyle.icon("stop_loot", 80))
	var words := VBoxContainer.new()
	top.add_child(words)
	words.add_child(UiStyle.heading("Spoils", 32, UiStyle.OAK_600))
	words.add_child(UiStyle.label("Take what you want; anything left behind is lost when you continue.", 17, UiStyle.INK_TEXT))
	var singles: Array[int] = []
	var relic_choice: Array[int] = []
	var rank_ups: Array[int] = []
	for i: int in session.state.offers.size():
		if session.state.offers[i]["type"] == "rank_up":
			rank_ups.append(i)
		elif session.state.offers[i].get("group", "") == "relic_choice":
			relic_choice.append(i)
		else:
			singles.append(i)
	for i: int in rank_ups:
		page.add_child(_rank_up(i))
	if not singles.is_empty():
		page.add_child(offer_row(singles, _take))
	if not relic_choice.is_empty():
		page.add_child(UiStyle.heading("Choose one relic (or none):", 20, UiStyle.OAK_600))
		page.add_child(offer_row(relic_choice, _take))
	var go: Button = primary_button("Continue", func() -> void: session.done())
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	page.add_child(go)


## A rank-up: a button per hero who can still rank up ("Brannoc: C → B").
func _rank_up(index: int) -> Control:
	var box := VBoxContainer.new()
	var given: bool = session.state.offers[index]["taken"]
	box.add_child(UiStyle.heading("A rank-up: give it to one hero" if not given else "Rank-up given", 20, UiStyle.OAK_600))
	if given:
		return box
	box.add_child(UiStyle.label("Ranks add slots and boost stats; a hero reaching B picks a specialization. You get one per elite, so choose who to carry.", 15, UiStyle.INK_TEXT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for hero: RunHero in session.state.heroes:
		if hero.rank >= 3:
			continue
		var label: String = "%s: %s → %s" % [HeroToken.first_name(session.content.heroes[hero.hero_id].name), TuningDef.TIER_LABELS[hero.rank], TuningDef.TIER_LABELS[hero.rank + 1]]
		row.add_child(UiStyle.button(label, func() -> void: session.give_rank_up(index, hero.hero_id)))
	return box


func _take(index: int) -> void:
	session.take(index)
