extends RefCounted

const S_CURSOR: Script = preload("res://addons/toml_parser/util/string_cursor.gd")
const S_READER: Script = preload("res://addons/toml_parser/util/string_reader.gd")
const S_REGEX: Script = preload("res://addons/toml_parser/util/regex_patterns.gd")
const S_FLAGS: Script = preload("res://addons/toml_parser/core/toml_flags.gd")
const S_ERROR: Script = preload("res://addons/toml_parser/core/toml_error.gd")

const ILLEGAL_BASIC: String = (
	"\"\u005c\u0001\u0002\u0003\u0004\u0005\u0006\u0007\u0008"
	+ "\u000b\u000c\u000e\u000f\u0010\u0011\u0012\u0013\u0014"
	+ "\u0015\u0016\u0017\u0018\u0019\u001a\u001b\u001c\u001d"
	+ "\u001e\u001f\u007f"
)
const ILLEGAL_ML_BASIC: String = (
	"\"\u005c\u0001\u0002\u0003\u0004\u0005\u0006\u0007\u0008"
	+ "\u0009\u000b\u000c\u000e\u000f\u0010\u0011\u0012\u0013"
	+ "\u0014\u0015\u0016\u0017\u0018\u0019\u001a\u001b\u001c"
	+ "\u001d\u001e\u001f\u007f"
)
const ILLEGAL_LITERAL: String = (
	"'\u0001\u0002\u0003\u0004\u0005\u0006\u0007\u0008"
	+ "\u000b\u000c\u000e\u000f\u0010\u0011\u0012\u0013\u0014"
	+ "\u0015\u0016\u0017\u0018\u0019\u001a\u001b\u001c\u001d"
	+ "\u001e\u001f\u007f"
)
const ILLEGAL_ML_LITERAL: String = (
	"'\u0001\u0002\u0003\u0004\u0005\u0006\u0007\u0008"
	+ "\u0009\u000b\u000c\u000e\u000f\u0010\u0011\u0012\u0013"
	+ "\u0014\u0015\u0016\u0017\u0018\u0019\u001a\u001b\u001c"
	+ "\u001d\u001e\u001f\u007f"
)
const ILLEGAL_COMMENT: String = (
	"\u0001\u0002\u0003\u0004\u0005\u0006\u0007\u0008"
	+ "\u000b\u000c\u000e\u000f\u0010\u0011\u0012\u0013\u0014"
	+ "\u0015\u0016\u0017\u0018\u0019\u001a\u001b\u001c\u001d"
	+ "\u001e\u001f\u007f"
)
const BARE_KEY: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
const BARE_KEY_SPECIAL: String = "=\t\n []{}#,.\"'-"
const KEY_INIT: String = BARE_KEY + "\"'"
const WS: String = " \t"
const WS_NL: String = " \t\n\r"
const HEXDIG: String = "0123456789abcdefABCDEF"
const ESCAPES: Dictionary = {
	"\\b": "\u0008", "\\t": "\u0009", "\\n": "\u000a",
	"\\f": "\u000c", "\\r": "\u000d", "\\e": "\u001b",
	'\\"': "\u0022", "\\\\": "\u005c",
}

var _flags: RefCounted
var has_error: bool = false
var silent: bool = false


func parse(src: String) -> Dictionary:
	S_REGEX._ensure_init()
	var normalized: String = src.replace("\r\n", "\n")
	var reader: RefCounted = S_READER.new(S_CURSOR.new(normalized))
	_flags = S_FLAGS.new()
	var out: Dictionary = {}
	var header: Array = []

	while not reader.is_eof():
		reader.skip_chars(WS)
		if reader.is_eof():
			break
		var ch: String = reader.peek_char()
		if ch == "\n":
			reader.read_char()
			continue
		if ch == "#":
			_skip_comment(reader)
			if not reader.is_eof():
				reader.read_char()
			continue
		if ch in KEY_INIT or (ch not in BARE_KEY_SPECIAL and ch != "\n" and ch != "\r"):
			_parse_kv(reader, out, header)
			reader.skip_chars(WS)
		elif ch == "[":
			var next_ch: String = reader.cursor().peek(1)
			_flags.finalize_pending()
			if next_ch == "[":
				header = _parse_aot_header(reader, out)
			else:
				header = _parse_table_header(reader)
			if not has_error:
				_get_nest(out, header)
			reader.skip_chars(WS)
		else:
			_error("Invalid statement", normalized, reader.cursor().pos())

		if reader.is_eof():
			break
		ch = reader.peek_char()
		if ch == "#":
			_skip_comment(reader)
			if reader.is_eof():
				break
			ch = reader.peek_char()
		if ch != "\n" and not reader.is_eof():
			_error("Expected newline or EOF", normalized, reader.cursor().pos())
		if not reader.is_eof():
			reader.read_char()
	return out


func _parse_kv(reader: RefCounted, out: Dictionary, header: Array) -> void:
	var src: String = reader.cursor().source()
	var pos: int = reader.cursor().pos()
	var key: Array = _parse_key(reader)[0]
	reader.skip_chars(WS)
	if reader.is_eof() or reader.peek_char() != "=":
		_error("Expected '='", src, reader.cursor().pos())
	reader.read_char()
	reader.skip_chars(WS)
	var value: Variant = _parse_value(reader)

	var full_key: Array = header + key
	for i in range(1, key.size()):
		var ck: Array = header + key.slice(0, i)
		if _flags.is_set(ck, S_FLAGS.EXPLICIT_NEST):
			_error("Cannot redefine namespace", src, pos)
		_flags.add_pending(ck, S_FLAGS.EXPLICIT_NEST)

	var parent_key: Array = full_key.slice(0, full_key.size() - 1)
	var stem: String = full_key[-1]
	if _flags.is_set(parent_key, S_FLAGS.FROZEN):
		_error("Cannot mutate immutable", src, pos)
	var nest: Dictionary = _get_nest(out, parent_key)
	if stem in nest:
		_error("Cannot overwrite value", src, pos)
	if value is Dictionary or value is Array:
		_flags.set_flag(full_key, S_FLAGS.FROZEN, true)
	nest[stem] = value


func _parse_key(reader: RefCounted) -> Array:
	var parts: Array = []
	reader.skip_chars(WS)
	parts.append(_parse_key_part(reader)[0])
	reader.skip_chars(WS)
	while not reader.is_eof() and reader.peek_char() == ".":
		reader.read_char()
		reader.skip_chars(WS)
		parts.append(_parse_key_part(reader)[0])
		reader.skip_chars(WS)
	return [parts]


func _parse_key_part(reader: RefCounted) -> Array:
	var src: String = reader.cursor().source()
	if reader.is_eof():
		_error("Expected key", src, reader.cursor().pos())
	var ch: String = reader.peek_char()
	if ch in BARE_KEY:
		var start: int = reader.cursor().pos()
		reader.skip_chars(BARE_KEY)
		return [src.substr(start, reader.cursor().pos() - start)]
	if ch not in BARE_KEY_SPECIAL and ch != "\n" and ch != "\r":
		var start: int = reader.cursor().pos()
		while not reader.is_eof():
			var c: String = reader.peek_char()
			if c in BARE_KEY_SPECIAL or c == "\n" or c == "\r":
				break
			reader.read_char()
		return [src.substr(start, reader.cursor().pos() - start)]
	if ch == "'":
		return _parse_lit_str(reader)
	if ch == '"':
		return _parse_basic_str_1(reader)
	_error("Invalid key char", src, reader.cursor().pos())
	return [""]


func _parse_value(reader: RefCounted) -> Variant:
	var src: String = reader.cursor().source()
	if reader.is_eof():
		_error("Expected value", src, reader.cursor().pos())
		return null
	var ch: String = reader.peek_char()
	var result: Variant = _match_value(reader, ch, src)
	if result == null and not has_error:
		_error("Invalid value", src, reader.cursor().pos())
	return result


func _match_value(reader: RefCounted, ch: String, src: String) -> Variant:
	if ch == '"':
		if reader.cursor().starts_with('"""'):
			return _parse_ml_basic(reader)
		return _parse_basic_str_1(reader)[0]
	if ch == "'":
		if reader.cursor().starts_with("'''"):
			return _parse_ml_literal(reader)
		return _parse_lit_str(reader)[0]
	if ch == "t" and reader.cursor().starts_with("true"):
		reader.advance(4)
		return true
	if ch == "f" and reader.cursor().starts_with("false"):
		reader.advance(5)
		return false
	if ch == "[":
		return _parse_array(reader)
	if ch == "{":
		return _parse_inline_table(reader)
	var dt: Variant = _try_datetime(reader)
	if dt != null:
		return dt
	return _try_number(reader)


func _parse_basic_str_1(reader: RefCounted) -> Array:
	reader.read_char()
	return [_parse_basic_content(reader, false)]


func _parse_basic_content(reader: RefCounted, ml: bool) -> String:
	var src: String = reader.cursor().source()
	var result: String = ""
	var start: int = reader.cursor().pos()
	while not reader.is_eof():
		var ch: String = reader.peek_char()
		if ch == '"':
			if not ml:
				result += src.substr(start, reader.cursor().pos() - start)
				reader.read_char()
				return result
			if reader.cursor().starts_with('"""'):
				result += src.substr(start, reader.cursor().pos() - start)
				reader.advance(3)
				return result
			reader.read_char()
			continue
		if ch == "\\":
			result += src.substr(start, reader.cursor().pos() - start)
			var esc: String = _parse_escape(reader, ml)
			result += esc
			start = reader.cursor().pos()
			continue
		if ch in (ILLEGAL_ML_BASIC if ml else ILLEGAL_BASIC):
			_error("Illegal char in string", src, reader.cursor().pos())
		reader.read_char()
	_error("Unterminated string", src, reader.cursor().pos())
	return ""


func _parse_ml_basic(reader: RefCounted) -> String:
	reader.advance(3)
	if not reader.is_eof() and reader.peek_char() == "\n":
		reader.read_char()
	return _parse_basic_content(reader, true)


func _parse_lit_str(reader: RefCounted) -> Array:
	var src: String = reader.cursor().source()
	reader.read_char()
	var start: int = reader.cursor().pos()
	while not reader.is_eof():
		var ch: String = reader.peek_char()
		if ch == "'":
			var r: String = src.substr(start, reader.cursor().pos() - start)
			reader.read_char()
			return [r]
		if ch in ILLEGAL_LITERAL:
			_error("Illegal char in literal", src, reader.cursor().pos())
		reader.read_char()
	_error("Unterminated literal", src, reader.cursor().pos())
	return [""]


func _parse_ml_literal(reader: RefCounted) -> String:
	var src: String = reader.cursor().source()
	reader.advance(3)
	if not reader.is_eof() and reader.peek_char() == "\n":
		reader.read_char()
	var start: int = reader.cursor().pos()
	while not reader.is_eof():
		var ch: String = reader.peek_char()
		if ch == "'":
			if reader.cursor().starts_with("'''"):
				var r: String = src.substr(start, reader.cursor().pos() - start)
				reader.advance(3)
				if not reader.is_eof() and reader.peek_char() == "'":
					r += "'"
					reader.read_char()
					if not reader.is_eof() and reader.peek_char() == "'":
						r += "'"
						reader.read_char()
				return r
			reader.read_char()
			continue
		if ch in ILLEGAL_ML_LITERAL:
			_error("Illegal char in ml literal", src, reader.cursor().pos())
		reader.read_char()
	_error("Unterminated ml literal", src, reader.cursor().pos())
	return ""


func _parse_escape(reader: RefCounted, ml: bool) -> String:
	var src: String = reader.cursor().source()
	reader.read_char()
	if reader.is_eof():
		_error("Unterminated escape", src, reader.cursor().pos())
	var ch: String = reader.peek_char()
	if ml and (ch == " " or ch == "\t" or ch == "\n"):
		if ch != "\n":
			reader.skip_chars(WS)
			if not reader.is_eof() and reader.peek_char() == "\n":
				reader.read_char()
			else:
				_error("Invalid escape", src, reader.cursor().pos())
		reader.skip_chars(WS_NL)
		return ""
	if ch == "x":
		return _hex_char(reader, 2)
	if ch == "u":
		return _hex_char(reader, 4)
	if ch == "U":
		return _hex_char(reader, 8)
	var seq: String = "\\" + ch
	reader.read_char()
	if seq in ESCAPES:
		return ESCAPES[seq]
	_error("Invalid escape: " + seq, src, reader.cursor().pos() - 2)
	return ""


func _hex_char(reader: RefCounted, hex_len: int) -> String:
	var src: String = reader.cursor().source()
	reader.advance(1)
	var hex_str: String = src.substr(reader.cursor().pos(), hex_len)
	if hex_str.length() != hex_len:
		_error("Invalid hex", src, reader.cursor().pos())
	for c in hex_str:
		if c not in HEXDIG:
			_error("Invalid hex", src, reader.cursor().pos())
	reader.advance(hex_len)
	var code: int = hex_str.hex_to_int()
	if (code >= 0 and code <= 0xD7FF) or (code >= 0xE000 and code <= 0x10FFFF):
		return char(code)
	_error("Invalid Unicode scalar", src, reader.cursor().pos())
	return ""


func _try_number(reader: RefCounted) -> Variant:
	var remaining: String = reader.cursor().remaining()
	var sm: RegExMatch = S_REGEX.re_special_float.search(remaining)
	if sm and sm.get_start() == 0:
		var s: String = sm.get_string()
		reader.advance(s.length())
		if "inf" in s:
			return INF if not s.begins_with("-") else -INF
		return NAN

	if reader.peek_char() == "0" and not reader.is_eof():
		var nc: String = reader.cursor().peek(1)
		if nc == "x" or nc == "X":
			return _hex_int(reader)
		if nc == "o" or nc == "O":
			return _oct_int(reader)
		if nc == "b" or nc == "B":
			return _bin_int(reader)

	if (reader.peek_char() == "+" or reader.peek_char() == "-") and not reader.is_eof():
		var next_ch: String = reader.cursor().peek(1)
		if next_ch == "0":
			var nc: String = reader.cursor().peek(2)
			if nc == "x" or nc == "X" or nc == "o" or nc == "O" or nc == "b" or nc == "B":
				_error("Positive sign not allowed with prefix", remaining, 0)
				return null

	var fm: RegExMatch = S_REGEX.re_float.search(remaining)
	if fm and fm.get_string().length() > 0:
		var m: String = fm.get_string()
		if "." in m or "e" in m or "E" in m:
			reader.advance(m.length())
			return float(m.replace("_", ""))

	var im: RegExMatch = S_REGEX.re_integer.search(remaining)
	if im and im.get_string().length() > 0:
		var m: String = im.get_string()
		if m == "+" or m == "-":
			return null
		var digits: String = m.lstrip("+-")
		if digits.length() > 1 and digits.begins_with("0"):
			_error("Leading zeros not allowed", remaining, 0)
			return null
		if digits.begins_with("_") or digits.ends_with("_") or "__" in digits:
			_error("Invalid underscore placement", remaining, 0)
			return null
		reader.advance(m.length())
		return int(m.replace("_", ""))
	return null


func _hex_int(reader: RefCounted) -> int:
	reader.advance(2)
	var start: int = reader.cursor().pos()
	reader.skip_chars("0123456789abcdefABCDEF_")
	var s: String = reader.cursor().source().substr(start, reader.cursor().pos() - start).replace("_", "")
	return s.hex_to_int()


func _oct_int(reader: RefCounted) -> int:
	reader.advance(2)
	var start: int = reader.cursor().pos()
	reader.skip_chars("01234567_")
	var s: String = reader.cursor().source().substr(start, reader.cursor().pos() - start).replace("_", "")
	var r: int = 0
	for c in s:
		r = r * 8 + int(c)
	return r


func _bin_int(reader: RefCounted) -> int:
	reader.advance(2)
	var start: int = reader.cursor().pos()
	reader.skip_chars("01_")
	var s: String = reader.cursor().source().substr(start, reader.cursor().pos() - start).replace("_", "")
	var r: int = 0
	for c in s:
		r = (r << 1) | int(c)
	return r


func _try_datetime(reader: RefCounted) -> Variant:
	var rem: String = reader.cursor().remaining()
	var m: RegExMatch = S_REGEX.re_offset_datetime.search(rem)
	if m and m.get_start() == 0:
		reader.advance(m.get_string().length())
		return m.get_string()
	m = S_REGEX.re_local_datetime.search(rem)
	if m and m.get_start() == 0:
		reader.advance(m.get_string().length())
		return m.get_string()
	m = S_REGEX.re_local_date.search(rem)
	if m and m.get_start() == 0:
		reader.advance(m.get_string().length())
		return m.get_string()
	m = S_REGEX.re_local_time.search(rem)
	if m and m.get_start() == 0:
		reader.advance(m.get_string().length())
		return m.get_string()
	return null


func _parse_array(reader: RefCounted) -> Array:
	var src: String = reader.cursor().source()
	reader.read_char()
	var arr: Array = []
	_skip_ws_comment(reader)
	if not reader.is_eof() and reader.peek_char() == "]":
		reader.read_char()
		return arr
	while not has_error:
		_skip_ws_comment(reader)
		if reader.is_eof():
			_error("Unclosed array", src, reader.cursor().pos())
			return arr
		if reader.peek_char() == "]":
			reader.read_char()
			return arr
		arr.append(_parse_value(reader))
		if has_error:
			return arr
		_skip_ws_comment(reader)
		if reader.is_eof():
			_error("Unclosed array", src, reader.cursor().pos())
			return arr
		if reader.peek_char() == "]":
			reader.read_char()
			return arr
		if reader.peek_char() == ",":
			reader.read_char()
		else:
			_error("Expected ',' or ']'", src, reader.cursor().pos())
			return arr
	return arr


func _skip_ws_comment(reader: RefCounted) -> void:
	while not reader.is_eof():
		reader.skip_chars(WS_NL)
		if not reader.is_eof() and reader.peek_char() == "#":
			_skip_comment(reader)
		else:
			break


func _parse_inline_table(reader: RefCounted) -> Dictionary:
	var src: String = reader.cursor().source()
	reader.read_char()
	var tbl: Dictionary = {}
	reader.skip_chars(WS)
	if not reader.is_eof() and reader.peek_char() == "}":
		reader.read_char()
		return tbl
	while not has_error:
		reader.skip_chars(WS)
		if reader.is_eof():
			_error("Unclosed inline table", src, reader.cursor().pos())
			return tbl
		var key: Array = _parse_key(reader)[0]
		if has_error:
			return tbl
		reader.skip_chars(WS)
		if reader.is_eof() or reader.peek_char() != "=":
			_error("Expected '='", src, reader.cursor().pos())
			return tbl
		reader.read_char()
		reader.skip_chars(WS)
		var value: Variant = _parse_value(reader)
		if has_error:
			return tbl
		var parent: Array = key.slice(0, key.size() - 1)
		var stem: String = key[-1]
		var nest: Dictionary = tbl
		for k in parent:
			if k not in nest:
				nest[k] = {}
			nest = nest[k]
		nest[stem] = value
		reader.skip_chars(WS)
		if reader.is_eof():
			_error("Unclosed inline table", src, reader.cursor().pos())
			return tbl
		if reader.peek_char() == "}":
			reader.read_char()
			return tbl
		if reader.peek_char() == ",":
			reader.read_char()
		else:
			_error("Expected ',' or '}'", src, reader.cursor().pos())
			return tbl
	return tbl


func _parse_table_header(reader: RefCounted) -> Array:
	var src: String = reader.cursor().source()
	reader.advance(1)
	reader.skip_chars(WS)
	var key: Array = _parse_key(reader)[0]
	if _flags.is_set(key, S_FLAGS.EXPLICIT_NEST) or _flags.is_set(key, S_FLAGS.FROZEN):
		_error("Cannot declare table twice", src, reader.cursor().pos())
	_flags.set_flag(key, S_FLAGS.EXPLICIT_NEST, false)
	if reader.is_eof() or reader.peek_char() != "]":
		_error("Expected ']'", src, reader.cursor().pos())
	reader.read_char()
	return key


func _parse_aot_header(reader: RefCounted, out: Dictionary) -> Array:
	var src: String = reader.cursor().source()
	reader.advance(2)
	reader.skip_chars(WS)
	var key: Array = _parse_key(reader)[0]
	if _flags.is_set(key, S_FLAGS.FROZEN):
		_error("Cannot mutate immutable", src, reader.cursor().pos())
	_flags.unset_all(key)
	_flags.set_flag(key, S_FLAGS.EXPLICIT_NEST, false)
	_append_list(out, key)
	if reader.is_eof() or not reader.cursor().starts_with("]]"):
		_error("Expected ']]'", src, reader.cursor().pos())
	reader.advance(2)
	return key


func _get_nest(out: Dictionary, key: Array) -> Dictionary:
	var cont: Variant = out
	for k in key:
		if not cont is Dictionary:
			_error("Cannot overwrite value", "", 0)
			return {}
		if k not in cont:
			cont[k] = {}
		cont = cont[k]
		if cont is Array:
			cont = cont[-1]
	if not cont is Dictionary:
		_error("Cannot overwrite value", "", 0)
		return {}
	return cont


func _append_list(out: Dictionary, key: Array) -> void:
	var parent: Array = key.slice(0, key.size() - 1)
	var stem: String = key[-1]
	var nest: Dictionary = _get_nest(out, parent)
	if stem in nest:
		if nest[stem] is Array:
			nest[stem].append({})
		else:
			_error("Cannot overwrite value", "", 0)
	else:
		nest[stem] = [{}]


func _skip_comment(reader: RefCounted) -> void:
	var src: String = reader.cursor().source()
	if reader.is_eof() or reader.peek_char() != "#":
		return
	reader.read_char()
	while not reader.is_eof():
		var ch: String = reader.peek_char()
		if ch == "\n":
			return
		if ch in ILLEGAL_COMMENT:
			_error("Illegal char in comment", src, reader.cursor().pos())
		reader.read_char()


func _error(msg: String, doc: String, pos: int) -> void:
	has_error = true
	if not silent:
		var err: RefCounted = S_ERROR.new(msg, doc, pos)
		push_error(err.get_message())
