# SaveGame: reads and writes the save file (user://save.json). Only handles the
# file; GameState decides what goes in it (to_save_data / apply_save_data).
class_name SaveGame
extends RefCounted

const SAVE_PATH := "user://save.json"


static func has_save() -> bool:
	return not ReelSandbox.active() and FileAccess.file_exists(SAVE_PATH)


static func save_game() -> bool:
	if ReelSandbox.active():
		return true  # A reel's state stays in memory.
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save file: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(GameState.to_save_data(), "\t"))
	file.close()
	print("Saved to %s" % ProjectSettings.globalize_path(SAVE_PATH))
	return true


# Loads the save into GameState. Returns false (and leaves a fresh game) if there
# is no save or it can't be read.
static func load_game() -> bool:
	if not has_save():
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		push_warning("Save file is damaged, starting a new game.")
		return false
	GameState.apply_save_data(parsed)
	print("Loaded save: %s day %d, %s, $%d" % [GameState.date, GameState.day_number, DayCycle.phase_name().to_lower(), GameState.money])
	return true


static func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
