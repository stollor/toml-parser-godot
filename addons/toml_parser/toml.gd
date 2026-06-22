extends Node

const ParserScript: Script = preload("res://addons/toml_parser/core/toml_parser.gd")
const SerializerScript: Script = preload("res://addons/toml_parser/core/toml_serializer.gd")


func parse(src: String) -> Dictionary:
	var result: Dictionary = try_parse(src)
	if not result.ok:
		push_error(result.error)
	return result.data


func load(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open file: " + path)
		return {}
	var content: String = file.get_as_text()
	return parse(content)


func try_parse(src: String) -> Dictionary:
	var parser: RefCounted = ParserScript.new()
	parser.silent = true
	var result: Dictionary = {"ok": true, "data": {}, "error": ""}
	var parsed: Dictionary = parser.parse(src)
	if parser.has_error:
		result.ok = false
		result.error = "Parse error"
	result.data = parsed
	return result


func try_load(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "data": {}, "error": "Cannot open file: " + path}
	var content: String = file.get_as_text()
	return try_parse(content)


func dumps(data: Dictionary) -> String:
	var serializer: RefCounted = SerializerScript.new()
	return serializer.serialize(data)


func dump(path: String, data: Dictionary) -> void:
	var content: String = dumps(data)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write file: " + path)
		return
	file.store_string(content)
