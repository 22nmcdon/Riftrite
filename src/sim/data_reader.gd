class_name DataReader
extends RefCounted
## Reads one JSON object with typed accessors. Every problem is appended to a
## shared error list with the full path (for example
## `essences.json[1] (frost).effects[0].stacks`), and accessors return a safe
## default so loading keeps going and reports every problem in one pass.
##
## Keys that are never read are reported as unknown by finish(), which catches
## typos. Keys starting with "_" are notes for designers and are ignored.

## Largest integer a JSON number (a 64-bit float) can hold exactly.
const MAX_SAFE_INT: int = 9007199254740991

var path: String
var _data: Dictionary
var _errors: Array[String]
var _read_keys: Dictionary[String, bool] = {}


func _init(data: Dictionary, data_path: String, errors: Array[String]) -> void:
	_data = data
	path = data_path
	_errors = errors


## Wraps a parsed JSON value that should be an object. Returns null (and
## records an error) if it is not.
static func from_value(value: Variant, data_path: String, errors: Array[String]) -> DataReader:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("%s: expected an object, got %s" % [data_path, _describe(value)])
		return null
	return DataReader.new(value, data_path, errors)


## Converts a parsed JSON number to int. Godot parses every JSON number as a
## float, so this is the one place src/sim handles floats: it only accepts
## whole numbers that a float can represent exactly.
static func to_int(value: Variant, data_path: String, errors: Array[String]) -> int:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if number == floorf(number) and absf(number) <= float(MAX_SAFE_INT):
			return int(number)
	errors.append("%s: expected a whole number, got %s" % [data_path, _describe(value)])
	return 0


static func _describe(value: Variant) -> String:
	if value == null:
		return "nothing"
	return JSON.stringify(value)


func error(message: String) -> void:
	_errors.append("%s: %s" % [path, message])


func has(key: String) -> bool:
	return _data.has(key)


func key_path(key: String) -> String:
	return "%s.%s" % [path, key]


func req_int(key: String, min_value: int = -MAX_SAFE_INT, max_value: int = MAX_SAFE_INT) -> int:
	if not _require(key):
		return 0
	return _check_range(key, to_int(_data[key], key_path(key), _errors), min_value, max_value)


func opt_int(key: String, default: int, min_value: int = -MAX_SAFE_INT, max_value: int = MAX_SAFE_INT) -> int:
	_read_keys[key] = true
	if not _data.has(key):
		return default
	return _check_range(key, to_int(_data[key], key_path(key), _errors), min_value, max_value)


## Reads a duration given in milliseconds and returns it in ticks. The value
## must be a whole number of ticks so conversion never rounds.
func req_ticks(key: String, min_ms: int = 0) -> int:
	var ms: int = req_int(key, min_ms)
	return _ms_to_ticks(key, ms)


func opt_ticks(key: String, default_ms: int, min_ms: int = 0) -> int:
	var ms: int = opt_int(key, default_ms, min_ms)
	return _ms_to_ticks(key, ms)


func req_string(key: String) -> String:
	if not _require(key):
		return ""
	var value: Variant = _data[key]
	if typeof(value) != TYPE_STRING or (value as String).is_empty():
		_errors.append("%s: expected a non-empty string, got %s" % [key_path(key), _describe(value)])
		return ""
	return value


## Reads an optional string (empty allowed).
func opt_string(key: String, default: String) -> String:
	_read_keys[key] = true
	if not _data.has(key):
		return default
	var value: Variant = _data[key]
	if typeof(value) != TYPE_STRING:
		_errors.append("%s: expected a string, got %s" % [key_path(key), _describe(value)])
		return default
	return value


func opt_bool(key: String, default: bool) -> bool:
	_read_keys[key] = true
	if not _data.has(key):
		return default
	var value: Variant = _data[key]
	if typeof(value) != TYPE_BOOL:
		_errors.append("%s: expected true or false, got %s" % [key_path(key), _describe(value)])
		return default
	return value


## Reads a string that must be one of `allowed` (listed in the error message).
func req_choice(key: String, allowed: Array[String]) -> String:
	var value: String = req_string(key)
	if not value.is_empty() and not allowed.has(value):
		_errors.append("%s: unknown value \"%s\" (expected one of: %s)" % [key_path(key), value, ", ".join(allowed)])
		return ""
	return value


## Like req_choice, but returns `default` when the key is missing.
func opt_string_choice(key: String, default: String, allowed: Array[String]) -> String:
	_read_keys[key] = true
	if not _data.has(key):
		return default
	return req_choice(key, allowed)


func req_object(key: String) -> DataReader:
	if not _require(key):
		return null
	return from_value(_data[key], key_path(key), _errors)


## Reads an optional array of objects. Returns an empty array if the key is
## missing. Elements that are not objects are reported and skipped.
func opt_object_array(key: String) -> Array[DataReader]:
	_read_keys[key] = true
	var readers: Array[DataReader] = []
	if not _data.has(key):
		return readers
	var value: Variant = _data[key]
	if typeof(value) != TYPE_ARRAY:
		_errors.append("%s: expected a list, got %s" % [key_path(key), _describe(value)])
		return readers
	var items: Array = value
	for i: int in items.size():
		var reader: DataReader = from_value(items[i], "%s[%d]" % [key_path(key), i], _errors)
		if reader != null:
			readers.append(reader)
	return readers


## Reads a required list of non-empty strings.
func req_string_array(key: String) -> Array[String]:
	var result: Array[String] = []
	if not _require(key):
		return result
	var value: Variant = _data[key]
	if typeof(value) != TYPE_ARRAY:
		_errors.append("%s: expected a list, got %s" % [key_path(key), _describe(value)])
		return result
	var items: Array = value
	for i: int in items.size():
		if typeof(items[i]) != TYPE_STRING or (items[i] as String).is_empty():
			_errors.append("%s[%d]: expected a non-empty string, got %s" % [key_path(key), i, _describe(items[i])])
		else:
			result.append(items[i])
	return result


## Reads a required list of whole numbers.
func req_int_array(key: String) -> Array[int]:
	var result: Array[int] = []
	if not _require(key):
		return result
	var value: Variant = _data[key]
	if typeof(value) != TYPE_ARRAY:
		_errors.append("%s: expected a list, got %s" % [key_path(key), _describe(value)])
		return result
	var items: Array = value
	for i: int in items.size():
		result.append(to_int(items[i], "%s[%d]" % [key_path(key), i], _errors))
	return result


## Reads an optional list of strings, each of which must be in `allowed`.
func opt_choice_array(key: String, allowed: Array[String]) -> Array[String]:
	_read_keys[key] = true
	var result: Array[String] = []
	if not _data.has(key):
		return result
	var value: Variant = _data[key]
	if typeof(value) != TYPE_ARRAY:
		_errors.append("%s: expected a list, got %s" % [key_path(key), _describe(value)])
		return result
	var items: Array = value
	for i: int in items.size():
		var element: Variant = items[i]
		var element_path: String = "%s[%d]" % [key_path(key), i]
		if typeof(element) != TYPE_STRING or not allowed.has(element):
			_errors.append("%s: unknown value %s (expected one of: %s)" % [element_path, _describe(element), ", ".join(allowed)])
		elif result.has(element):
			_errors.append("%s: \"%s\" is listed twice" % [element_path, element])
		else:
			result.append(element)
	return result


## Returns the object's keys, sorted, for objects used as maps (like
## collapse_by_act). Marks them all as read.
func map_keys() -> Array[String]:
	var keys: Array[String] = []
	for key: Variant in _data.keys():
		var name: String = key
		if not name.begins_with("_"):
			keys.append(name)
			_read_keys[name] = true
	keys.sort()
	return keys


## Reports any keys that were never read. Call once after reading an object.
func finish() -> void:
	var unknown: Array[String] = []
	for key: Variant in _data.keys():
		var name: String = key
		if not name.begins_with("_") and not _read_keys.has(name):
			unknown.append(name)
	unknown.sort()
	for name: String in unknown:
		_errors.append("%s: unknown key \"%s\"" % [path, name])


func _require(key: String) -> bool:
	_read_keys[key] = true
	if not _data.has(key):
		_errors.append("%s: missing required key \"%s\"" % [path, key])
		return false
	return true


func _check_range(key: String, value: int, min_value: int, max_value: int) -> int:
	if value < min_value or value > max_value:
		_errors.append("%s: %d is out of range (%d to %d)" % [key_path(key), value, min_value, max_value])
	return value


func _ms_to_ticks(key: String, ms: int) -> int:
	if not FixedMath.is_whole_ticks(ms):
		_errors.append("%s: %d ms is not a whole number of ticks (use a multiple of %d ms)" % [key_path(key), ms, FixedMath.MS_PER_TICK])
	return FixedMath.ms_to_ticks(ms)
