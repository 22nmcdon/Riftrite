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


## A dim line under a heading saying what to do here.
func hint(text: String) -> void:
	var line: Label = UiStyle.label(text, 16, UiStyle.TEXT_DIM)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(line)


## A row of offers (indexes into state.offers) as clickable views.
func offer_row(indexes: Array[int], action: Callable, lit: Callable = Callable()) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	for i: int in indexes:
		var glow: bool = lit.is_valid() and lit.call(i)
		row.add_child(OfferView.make(session, session.state.offers[i], action.bind(i), glow))
	return row
