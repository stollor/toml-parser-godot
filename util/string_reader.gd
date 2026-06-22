extends RefCounted

const S_CURSOR: Script = preload("res://addons/toml_parser/util/string_cursor.gd")

var _cursor: RefCounted


func _init(cursor: RefCounted) -> void:
	_cursor = cursor


func skip_chars(chars: String) -> void:
	while not _cursor.is_eof():
		var ch: String = _cursor.peek()
		if ch not in chars:
			break
		_cursor.advance()


func skip_whitespace() -> void:
	skip_chars(" \t")


func skip_whitespace_and_newlines() -> void:
	skip_chars(" \t\n\r")


func skip_until_char(target: String, error_on: String = "") -> bool:
	while not _cursor.is_eof():
		var ch: String = _cursor.peek()
		if ch == target:
			return true
		if error_on != "" and ch in error_on:
			return false
		_cursor.advance()
	return false


func skip_until_string(target: String, error_on: String = "") -> bool:
	var target_len: int = target.length()
	while _cursor.pos() + target_len <= _cursor.length():
		var ch: String = _cursor.peek()
		if error_on != "" and ch in error_on:
			return false
		if _cursor.starts_with(target):
			return true
		_cursor.advance()
	return false


func match_string(text: String) -> bool:
	if _cursor.starts_with(text):
		_cursor.advance(text.length())
		return true
	return false


func read_until_char(target: String) -> String:
	var start: int = _cursor.pos()
	while not _cursor.is_eof():
		if _cursor.peek() == target:
			break
		_cursor.advance()
	return _cursor.source().substr(start, _cursor.pos() - start)


func read_char() -> String:
	if _cursor.is_eof():
		return ""
	var ch: String = _cursor.peek()
	_cursor.advance()
	return ch


func peek_char() -> String:
	return _cursor.peek()


func is_eof() -> bool:
	return _cursor.is_eof()


func advance(count: int = 1) -> void:
	_cursor.advance(count)


func cursor() -> RefCounted:
	return _cursor
