class_name TitleScreen
extends UiScreen
## Start a new run, or continue the saved one.


func build() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(UiStyle.label("Riftrite", 64, UiStyle.EMBER))
	add_child(UiStyle.label("A guild, a pouch of essences, and the rifts below the Hollow.", 18, UiStyle.TEXT_DIM))
	add_child(UiStyle.button("New run", _new_run))
	if session.has_save():
		add_child(UiStyle.button("Continue", _continue))
	for child: Control in get_children():
		child.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _new_run() -> void:
	session.new_run(session.next_seed())


func _continue() -> void:
	var problem: String = session.continue_run()
	if not problem.is_empty():
		session.changed.emit(RunActions._fail("couldn't load the run: " + problem))
