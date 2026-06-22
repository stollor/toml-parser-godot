extends RefCounted


func serialize(data: Dictionary) -> String:
	var lines: Array[String] = []
	_write_table(data, "", lines)
	return "\n".join(lines) + "\n"


func _write_table(tbl: Dictionary, prefix: String, lines: Array[String]) -> void:
	var simple: Array = []
	var tables: Array = []
	var aots: Array = []

	for key in tbl:
		var value: Variant = tbl[key]
		if value is Array and value.size() > 0 and value[0] is Dictionary:
			aots.append(key)
		elif value is Dictionary:
			tables.append(key)
		else:
			simple.append(key)

	simple.sort()
	tables.sort()
	aots.sort()

	for key in simple:
		lines.append("%s = %s" % [_fmt_key(key), _fmt_val(tbl[key])])

	for key in tables:
		var fk: String = _fmt_key(key)
		var fp: String = fk if prefix == "" else prefix + "." + fk
		lines.append("")
		lines.append("[%s]" % fp)
		_write_table(tbl[key], fp, lines)

	for key in aots:
		var fk: String = _fmt_key(key)
		var fp: String = fk if prefix == "" else prefix + "." + fk
		for item in tbl[key]:
			lines.append("")
			lines.append("[[%s]]" % fp)
			if item is Dictionary:
				_write_table(item, fp, lines)


func _fmt_key(key: String) -> String:
	if _is_bare(key):
		return key
	return '"%s"' % key.replace("\\", "\\\\").replace('"', '\\"')


func _is_bare(key: String) -> bool:
	if key == "":
		return false
	for c in key:
		if c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_":
			return false
	return true


func _fmt_val(value: Variant) -> String:
	if value is String:
		return _fmt_str(value)
	if value is bool:
		return "true" if value else "false"
	if value is int:
		return str(value)
	if value is float:
		if is_inf(value):
			return "inf" if value > 0 else "-inf"
		if is_nan(value):
			return "nan"
		return str(value)
	if value is Array:
		return _fmt_arr(value)
	if value is Dictionary:
		return _fmt_inline(value)
	return str(value)


func _fmt_str(value: String) -> String:
	var r: String = '"'
	for c in value:
		match c:
			"\\":
				r += "\\\\"
			'"':
				r += '\\"'
			"\n":
				r += "\\n"
			"\r":
				r += "\\r"
			"\t":
				r += "\\t"
			"\b":
				r += "\\b"
			"\f":
				r += "\\f"
			_:
				var code: int = c.unicode_at(0)
				if code < 0x20 or code == 0x7f:
					r += "\\u%04x" % code
				else:
					r += c
	r += '"'
	return r


func _fmt_arr(arr: Array) -> String:
	if arr.is_empty():
		return "[]"
	var items: Array[String] = []
	for item in arr:
		items.append(_fmt_val(item))
	return "[%s]" % ", ".join(items)


func _fmt_inline(tbl: Dictionary) -> String:
	if tbl.is_empty():
		return "{}"
	var items: Array[String] = []
	var keys: Array = tbl.keys()
	keys.sort()
	for key in keys:
		items.append("%s = %s" % [_fmt_key(key), _fmt_val(tbl[key])])
	return "{ %s }" % ", ".join(items)
