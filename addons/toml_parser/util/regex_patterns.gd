extends RefCounted


static var re_integer: RegEx
static var re_hex_integer: RegEx
static var re_oct_integer: RegEx
static var re_bin_integer: RegEx
static var re_float: RegEx
static var re_special_float: RegEx
static var re_offset_datetime: RegEx
static var re_local_datetime: RegEx
static var re_local_date: RegEx
static var re_local_time: RegEx
static var re_hex_escape: RegEx
static var re_unicode_escape: RegEx
static var re_unicode8_escape: RegEx

static var _initialized: bool = false


static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true

	re_integer = RegEx.new()
	re_integer.compile("^[+-]?[0-9][0-9_]*")

	re_hex_integer = RegEx.new()
	re_hex_integer.compile("^0x[0-9a-fA-F][0-9a-fA-F_]*")

	re_oct_integer = RegEx.new()
	re_oct_integer.compile("^0o[0-7][0-7_]*")

	re_bin_integer = RegEx.new()
	re_bin_integer.compile("^0b[01][01_]*")

	re_float = RegEx.new()
	re_float.compile("^[+-]?[0-9][0-9_]*(\\.[0-9][0-9_]*)?([eE][+-]?[0-9][0-9_]*)?")

	re_special_float = RegEx.new()
	re_special_float.compile("^[+-]?(inf|nan)")

	re_offset_datetime = RegEx.new()
	re_offset_datetime.compile(
		"^\\d{4}-\\d{2}-\\d{2}[T ]\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?(Z|[+-]\\d{2}:\\d{2})"
	)

	re_local_datetime = RegEx.new()
	re_local_datetime.compile(
		"^\\d{4}-\\d{2}-\\d{2}[T ]\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?"
	)

	re_local_date = RegEx.new()
	re_local_date.compile("^\\d{4}-\\d{2}-\\d{2}(?![T ])")

	re_local_time = RegEx.new()
	re_local_time.compile("^\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?")

	re_hex_escape = RegEx.new()
	re_hex_escape.compile("^\\\\x([0-9a-fA-F]{2})")

	re_unicode_escape = RegEx.new()
	re_unicode_escape.compile("^\\\\u([0-9a-fA-F]{4})")

	re_unicode8_escape = RegEx.new()
	re_unicode8_escape.compile("^\\\\U([0-9a-fA-F]{8})")
