class_name CombatLog
extends RefCounted
## Everything that happened in a fight, in order. The UI plays this back, the
## damage meter will be built from it, and determinism tests compare it.

var entries: Array[LogEntry] = []


func add(entry: LogEntry) -> void:
	entries.append(entry)


func to_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for entry: LogEntry in entries:
		lines.append(entry.to_text())
	return lines


func to_text() -> String:
	return "\n".join(to_lines())


func of_kind(kind: LogEntry.Kind) -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in entries:
		if entry.kind == kind:
			found.append(entry)
	return found
