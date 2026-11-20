# SafeFile: writes and reads the game's JSON files (the save, the accounts) so
# that a crash, a power cut or a full disk partway through never costs a
# restaurant:
#   - A write goes to <file>.tmp first, is read back to check it's whole, and
#     only then replaces the file. The file it replaces is kept as <file>.bak.
#   - Once a day the file is also copied to backups/<name>_<date>.json; the
#     newest BACKUP_DAYS of them are kept.
#   - A read that finds the file missing or damaged falls back to the newest
#     good copy (.tmp, .bak, then the daily backups, newest first) and says so
#     (restored_from). A damaged file is set aside as <file>.damaged-<time>, never
#     written over, so nothing is lost even then.
class_name SafeFile
extends RefCounted

const BACKUP_DIR := "user://backups/"
const BACKUP_DAYS := 7

static var restored_from := {}  # Path -> which copy it was read from, when it wasn't the file itself.


# Write `data` to `path` as JSON. False if it couldn't be written (the old file is untouched then).
static func write_json(path: String, data: Variant) -> bool:
	var text := JSON.stringify(data, "\t")
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_error("Couldn't write %s: %s" % [temp, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(text)
	file.close()
	if FileAccess.get_file_as_string(temp) != text:  # Short write (a full disk): keep the old file.
		push_error("Writing %s came out short; the last good copy is kept." % path)
		DirAccess.remove_absolute(temp)
		return false
	if FileAccess.file_exists(path):
		_daily_backup(path)
		if _parses(path):  # Only a good file becomes the .bak (not a damaged one over a good .bak).
			DirAccess.remove_absolute(path + ".bak")
			DirAccess.rename_absolute(path, path + ".bak")
	if DirAccess.rename_absolute(temp, path) != OK:
		# Couldn't swap it in: copy instead, so the new data is there either way.
		if DirAccess.copy_absolute(temp, path) != OK:
			push_error("Couldn't put %s in place; it's in %s" % [path, temp])
			return false
		DirAccess.remove_absolute(temp)
	return true


# The JSON in `path` as a Dictionary, or from its newest good copy if it's
# missing or damaged; {} if there's nothing good anywhere (or no file at all).
static func read_json(path: String) -> Dictionary:
	restored_from.erase(path)
	var own: Variant = _read(path)
	if own is Dictionary:
		return own
	if FileAccess.file_exists(path):  # Damaged: set it aside, never overwrite it.
		var aside := "%s.damaged-%s" % [path, Time.get_datetime_string_from_system().replace(":", "-")]
		DirAccess.rename_absolute(path, aside)
		push_warning("%s was damaged; kept as %s" % [path, aside])
	for copy in candidates(path):
		var parsed: Variant = _read(copy)
		if parsed is Dictionary:
			restored_from[path] = copy
			push_warning("Read %s from %s" % [path, copy])
			return parsed
	return {}


# Whether there's anything to read for `path` (the file or any copy of it).
static func exists(path: String) -> bool:
	return FileAccess.file_exists(path) or not candidates(path).is_empty()


# The copies of `path` to fall back on, best first: the unfinished write, the
# one before the last write, then the daily backups, newest first.
static func candidates(path: String) -> Array[String]:
	var found: Array[String] = []
	for copy in [path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(copy):
			found.append(copy)
	found.append_array(_backups_of(path))
	return found


# Delete `path` and every copy of it (a restaurant being started over on purpose).
static func delete_all(path: String) -> void:
	for copy in [path, path + ".tmp", path + ".bak"] + Array(_backups_of(path)):
		if FileAccess.file_exists(copy):
			DirAccess.remove_absolute(copy)


static func _daily_backup(path: String) -> void:
	var today := Time.get_date_string_from_system()
	var backup := "%s%s_%s.json" % [BACKUP_DIR, _stem(path), today]
	if FileAccess.file_exists(backup) or not _parses(path):
		return
	DirAccess.make_dir_recursive_absolute(BACKUP_DIR)
	DirAccess.copy_absolute(path, backup)
	var old := _backups_of(path)
	for i in range(BACKUP_DAYS, old.size()):
		DirAccess.remove_absolute(old[i])


# Daily backups of `path`, newest first.
static func _backups_of(path: String) -> Array[String]:
	var found: Array[String] = []
	if not DirAccess.dir_exists_absolute(BACKUP_DIR):
		return found
	var prefix := _stem(path) + "_"
	for file in DirAccess.get_files_at(BACKUP_DIR):
		if file.begins_with(prefix) and file.ends_with(".json"):
			found.append(BACKUP_DIR + file)
	found.sort()
	found.reverse()
	return found


# "user://slot2/save.json" -> "slot2_save", so slots' backups don't mix.
static func _stem(path: String) -> String:
	return path.trim_prefix("user://").get_basename().replace("/", "_")


static func _parses(path: String) -> bool:
	return _read(path) is Dictionary


static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return null
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null
