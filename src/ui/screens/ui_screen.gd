class_name UiScreen
extends VBoxContainer
## A screen of the game. Screens read the run through their RunSession and
## change it only through its actions; Main rebuilds the screen after each
## change.

var session: RunSession


func setup(run_session: RunSession) -> UiScreen:
	session = run_session
	add_theme_constant_override("separation", 12)
	build()
	return self


## Fills the screen from the session. Screens override this.
func build() -> void:
	pass


func heading(text: String) -> void:
	add_child(UiStyle.label(text, 24, UiStyle.EMBER))


## A row of offers (indexes into state.offers) as clickable views.
func offer_row(indexes: Array[int], action: Callable, lit: Callable = Callable()) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i: int in indexes:
		var glow: bool = lit.is_valid() and lit.call(i)
		row.add_child(OfferView.make(session, session.state.offers[i], action.bind(i), glow))
	return row
