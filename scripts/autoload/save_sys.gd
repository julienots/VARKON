extends Node
## Versioned local save with atomic writes, checksum validation, backup and migrations.
##
## Security note: this is an offline game. The checksum only detects corruption and
## casual edits; it cannot stop a determined user from editing their own device.
## Any future online mode must validate important actions server-side.

const CURRENT_VERSION := 2
const SALT := "varkon-superessence-v1"

var save_path := "user://varkon_save.json"
var enabled := true
var last_error := ""
var last_load_source := ""  # "main", "backup", "new"


func backup_path() -> String:
	return save_path.get_basename() + ".bak.json"


func tmp_path() -> String:
	return save_path + ".tmp"


func checksum(text: String) -> String:
	return (text + SALT).sha256_text()


func write(data: Dictionary) -> bool:
	if not enabled:
		return true
	data["version"] = CURRENT_VERSION
	data["saved_at"] = int(Time.get_unix_time_from_system())
	var body := JSON.stringify(data)
	var envelope := JSON.stringify({"checksum": checksum(body), "body": body})
	var f := FileAccess.open(tmp_path(), FileAccess.WRITE)
	if f == null:
		last_error = "open tmp failed: %d" % FileAccess.get_open_error()
		push_error(last_error)
		return false
	f.store_string(envelope)
	f.flush()
	f = null
	var dir := DirAccess.open("user://")
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(backup_path()):
			dir.remove(backup_path())
		dir.copy(save_path, backup_path())
		dir.remove(save_path)
	var err := dir.rename(tmp_path(), save_path)
	if err != OK:
		last_error = "rename failed: %d" % err
		push_error(last_error)
		return false
	return true


func _read_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var env = JSON.parse_string(f.get_as_text())
	if typeof(env) != TYPE_DICTIONARY or not env.has("body") or not env.has("checksum"):
		return null
	if checksum(str(env.body)) != str(env.checksum):
		push_warning("Save checksum mismatch: " + path)
		return null
	var data = JSON.parse_string(str(env.body))
	if typeof(data) != TYPE_DICTIONARY:
		return null
	return data


## Returns the stored profile (migrated) or null when none/invalid.
func read() -> Variant:
	var data = _read_file(save_path)
	last_load_source = "main"
	if data == null:
		data = _read_file(backup_path())
		last_load_source = "backup"
	if data == null:
		last_load_source = "new"
		return null
	return migrate(data)


func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 1))
	while v < CURRENT_VERSION:
		match v:
			1:
				# v1 -> v2: introduce king loadouts and claim registry.
				if not data.has("claims"):
					data["claims"] = {}
				var k: Dictionary = data.get("king", {})
				if not k.has("loadouts"):
					k["loadouts"] = []
				data["king"] = k
		v += 1
	data["version"] = CURRENT_VERSION
	return data


func wipe() -> void:
	for p in [save_path, backup_path(), tmp_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
