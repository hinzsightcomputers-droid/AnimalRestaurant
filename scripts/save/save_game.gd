# SaveGame: reads and writes the save file (user://save.json). Only handles the
# file; GameState decides what goes in it (to_save_data / apply_save_data).
# Written and read through SafeFile: a crash mid-save can't lose the
# restaurant, and a damaged file is put aside and the last good copy used.
class_name SaveGame
extends RefCounted

const SAVE_PATH := "user://save.json"  # Slot 1 (and every save from before there were slots).
const SLOTS := 4

static var restored_note := ""  # Set when the save was damaged and a backup was loaded instead (said once in game).


static func has_save() -> bool:
	if ReelSandbox.active():
		return false
	# The file, or a copy left by a save that didn't finish. (Daily backups alone
	# don't count: that's a restaurant someone started over.)
	return FileAccess.file_exists(path()) or FileAccess.file_exists(path() + ".tmp") or FileAccess.file_exists(path() + ".bak")


static func save_game() -> bool:
	if ReelSandbox.active():
		return true  # A reel's state stays in memory.
	if not SafeFile.write_json(path(), GameState.to_save_data()):
		return false
	print("Saved to %s" % ProjectSettings.globalize_path(path()))
	return true


# Loads the save into GameState. Returns false (and leaves a fresh game) if there
# is no save, or nothing good to read anywhere.
static func load_game() -> bool:
	if not has_save():
		return false
	var parsed := SafeFile.read_json(path())
	if parsed.is_empty():
		push_warning("Save file is damaged and there's no good copy, starting a new game.")
		return false
	GameState.apply_save_data(parsed)
	if SafeFile.restored_from.has(path()):
		restored_note = "Your save couldn't be read, so the restaurant was loaded from the last good copy (%s)." % _copy_name(SafeFile.restored_from[path()])
	print("Loaded save: %s day %d, %s, $%d" % [GameState.date, GameState.day_number, DayCycle.phase_name().to_lower(), GameState.money])
	return true


# Starting over: the save goes into the backups folder (so a slip can still be
# undone by hand), and its in-progress copies go.
static func delete_save() -> void:
	if FileAccess.file_exists(path()):
		DirAccess.make_dir_recursive_absolute(SafeFile.BACKUP_DIR)
		DirAccess.rename_absolute(path(), "%s%s_started_over_%s.json" % [SafeFile.BACKUP_DIR, path().get_file().get_basename(), Time.get_datetime_string_from_system().replace(":", "-")])
	for copy in [path() + ".tmp", path() + ".bak"]:
		if FileAccess.file_exists(copy):
			DirAccess.remove_absolute(copy)


# "the backup from 2026-11-18", "the save before last"...
static func _copy_name(copy: String) -> String:
	if copy.ends_with(".bak"):
		return "the save before last"
	if copy.ends_with(".tmp"):
		return "a save that was being written"
	var stem := copy.get_file().get_basename()
	return "the backup from %s" % stem.get_slice("_", stem.get_slice_count("_") - 1)


# The save file of `slot` (the one being played if not given).
static func path(slot := 0) -> String:
	var which := slot if slot > 0 else Settings.save_slot
	return SAVE_PATH if which <= 1 else "user://save_%d.json" % which


# What's in a slot, for the restaurant picker: { name, day, money, stars, date }
# or {} if it's empty. Doesn't change anything.
static func peek(slot: int) -> Dictionary:
	var file := path(slot)
	for copy in [file, file + ".tmp", file + ".bak"]:
		if FileAccess.file_exists(copy):
			var json := JSON.new()
			if json.parse(FileAccess.get_file_as_string(copy)) == OK and json.data is Dictionary:
				var data: Dictionary = json.data
				return {
					"name": String(data.get("restaurant_name", "")),
					"day": int(data.get("day_number", 1)),
					"money": int(data.get("money", 0)),
					"stars": int(data.get("stars", 0)),
					"date": String(data.get("date", "")),
				}
	return {}
