extends RefCounted


var _src: String
var _pos: int
var _len: int


func _init(source: String) -> void:
	_src = source
	_len = source.length()
	_pos = 0


func is_eof() -> bool:
	return _pos >= _len


func pos() -> int:
	return _pos


func peek(offset: int = 0) -> String:
	var idx: int = _pos + offset
	if idx < 0 or idx >= _len:
		return ""
	return _src[idx]


func peek_slice(start_offset: int, end_offset: int) -> String:
	var s: int = _pos + start_offset
	var e: int = _pos + end_offset
	if s < 0:
		s = 0
	if e > _len:
		e = _len
	if s >= e:
		return ""
	return _src.substr(s, e - s)


func advance(count: int = 1) -> void:
	_pos += count
	if _pos > _len:
		_pos = _len


func set_pos(new_pos: int) -> void:
	_pos = new_pos
	if _pos > _len:
		_pos = _len


func remaining() -> String:
	if _pos >= _len:
		return ""
	return _src.substr(_pos)


func source() -> String:
	return _src


func length() -> int:
	return _len


func get_line_col() -> Array:
	var line: int = 1
	var col: int = 1
	for i in range(_pos):
		if _src[i] == "\n":
			line += 1
			col = 1
		else:
			col += 1
	return [line, col]


func starts_with(text: String) -> bool:
	if _pos + text.length() > _len:
		return false
	return _src.substr(_pos, text.length()) == text
