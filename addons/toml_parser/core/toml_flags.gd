extends RefCounted


const FROZEN: int = 0
const EXPLICIT_NEST: int = 1


var _flags: Dictionary = {}
var _pending: Array = []


func add_pending(key: Array, flag: int) -> void:
	_pending.append([key, flag])


func finalize_pending() -> void:
	for entry in _pending:
		set_flag(entry[0], entry[1], false)
	_pending.clear()


func unset_all(key: Array) -> void:
	var cont: Dictionary = _flags
	for i in range(key.size() - 1):
		var k: String = key[i]
		if k not in cont:
			return
		cont = cont[k]["nested"]
	cont.erase(key[-1])


func set_flag(key: Array, flag: int, recursive: bool) -> void:
	var cont: Dictionary = _flags
	var parent: Array = key.slice(0, key.size() - 1)
	var stem: String = key[-1]
	for k in parent:
		if k not in cont:
			cont[k] = {"flags": [], "recursive_flags": [], "nested": {}}
		cont = cont[k]["nested"]
	if stem not in cont:
		cont[stem] = {"flags": [], "recursive_flags": [], "nested": {}}
	if recursive:
		if flag not in cont[stem]["recursive_flags"]:
			cont[stem]["recursive_flags"].append(flag)
	else:
		if flag not in cont[stem]["flags"]:
			cont[stem]["flags"].append(flag)


func is_set(key: Array, flag: int) -> bool:
	if key.is_empty():
		return false
	var cont: Dictionary = _flags
	for i in range(key.size() - 1):
		var k: String = key[i]
		if k not in cont:
			return false
		if flag in cont[k]["recursive_flags"]:
			return true
		cont = cont[k]["nested"]
	var stem: String = key[-1]
	if stem in cont:
		var inner: Dictionary = cont[stem]
		return flag in inner["flags"] or flag in inner["recursive_flags"]
	return false
