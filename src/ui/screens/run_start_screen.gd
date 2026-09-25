class_name RunStartScreen
extends UiScreen
## Pick your first hero, then a starting package.


func build() -> void:
	var state: RunState = session.state
	var all: Array[int] = []
	for i: int in state.offers.size():
		all.append(i)
	if state.phase == "start_hero":
		heading("Choose your first hero")
		add_child(offer_row(all, _pick_hero))
	else:
		heading("Choose a starting package")
		var row := HBoxContainer.new()
		for i: int in all:
			row.add_child(UiStyle.button(_package_text(state.offers[i]), _pick_package.bind(i)))
		add_child(row)
		add_child(UiStyle.label("You also start with %d gold." % session.run.economy.base_gold, 14, UiStyle.TEXT_DIM))


func _package_text(offer: Dictionary) -> String:
	match offer["package"]:
		"gold":
			return "+%d gold" % session.run.economy.package_gold
		"relic":
			return "A relic: %s" % session.content.relics[offer["relic"]].name
	return "An item: %s" % session.content.items[offer["item"]].name


func _pick_hero(index: int) -> void:
	session.pick_start_hero(index)


func _pick_package(index: int) -> void:
	session.pick_package(index)
