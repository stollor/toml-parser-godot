extends RefCounted


var message: String
var doc: String
var pos: int
var line: int
var column: int


func _init(msg: String = "", source: String = "", position: int = 0) -> void:
	message = msg
	doc = source
	pos = position
	if doc.length() > 0:
		line = 1
		column = 1
		for i in range(min(pos, doc.length())):
			if doc[i] == "\n":
				line += 1
				column = 1
			else:
				column += 1
	else:
		line = 1
		column = 1


func get_message() -> String:
	var coord: String = ""
	if doc.length() > 0:
		if pos >= doc.length():
			coord = " (at end of document)"
		else:
			coord = " (at line %d, column %d)" % [line, column]
	return "TOML decode error: %s%s" % [message, coord]
