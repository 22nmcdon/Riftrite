extends RefCounted
## Shared helpers for the UI tests: finding controls by their type or text.
## (The old game's kit, from git history, without its run sessions.)


## Every descendant of `root` that is a `type` (a class, e.g. Button).
static func find_all(root: Node, type: Variant) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in root.get_children():
		if is_instance_of(child, type):
			found.append(child)
		found.append_array(find_all(child, type))
	return found


## The first button under `root` whose text contains `text`, or null.
static func button(root: Node, text: String) -> Button:
	for node: Node in find_all(root, Button):
		if (node as Button).text.contains(text):
			return node
	return null


## Presses the button under `root` whose text contains `text`. False if
## there's no such button, or it's disabled.
static func press(root: Node, text: String) -> bool:
	var found: Button = button(root, text)
	if found == null or found.disabled:
		return false
	found.pressed.emit()
	return true


## All the label text under `root`, one per line (rich text as it reads,
## without its tags).
static func text_of(root: Node) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for node: Node in find_all(root, Control):
		if node is Label:
			lines.append((node as Label).text)
		elif node is RichTextLabel:
			lines.append((node as RichTextLabel).get_parsed_text())
	return "\n".join(lines)
