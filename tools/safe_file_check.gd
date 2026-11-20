extends SceneTree

# Checks SafeFile (the save's crash safety) on a scratch file in user://. Run
# with APPDATA pointed at a test folder so the real save is never near it:
#   APPDATA=<test folder> godot --headless --path . -s res://tools/safe_file_check.gd
# Prints PASS/FAIL per case and "SAFE FILE CHECK: n failed".

const PATH := "user://safe_check.json"
var failed := 0


func _init() -> void:
	if not OS.get_environment("APPDATA").to_lower().contains("test") and not OS.get_environment("APPDATA").to_lower().contains("temp"):
		print("Refusing to run: point APPDATA at a test folder first.")
		quit(1)
		return
	_clean()
	_check("a write reads back", func():
		SafeFile.write_json(PATH, { "money": 1 })
		return SafeFile.read_json(PATH).get("money") == 1)
	_check("the write before is kept as .bak", func():
		SafeFile.write_json(PATH, { "money": 2 })
		return JSON.parse_string(FileAccess.get_file_as_string(PATH + ".bak")).get("money") == 1)
	_check("a daily backup is made", func():
		return SafeFile.candidates(PATH).any(func(c): return c.begins_with(SafeFile.BACKUP_DIR)))
	_check("no .tmp left behind", func():
		return not FileAccess.file_exists(PATH + ".tmp"))
	_check("a damaged file falls back to .bak and is set aside", func():
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string("{ \"money\": 3, \"half wri")  # A crash mid-write.
		f.close()
		var read: Dictionary = SafeFile.read_json(PATH)
		var aside := Array(DirAccess.get_files_at("user://")).filter(func(n): return n.begins_with("safe_check.json.damaged-"))
		return read.get("money") == 1 and SafeFile.restored_from.has(PATH) and not aside.is_empty())
	_check("an empty file falls back too", func():
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.close()
		return not SafeFile.read_json(PATH).is_empty())
	_check("a write that never got swapped in (only .tmp) is found", func():
		_clean()
		var f := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
		f.store_string(JSON.stringify({ "money": 7 }))
		f.close()
		return SafeFile.exists(PATH) and SafeFile.read_json(PATH).get("money") == 7)
	_check("a damaged file never replaces a good .bak", func():
		_clean()
		SafeFile.write_json(PATH, { "money": 10 })
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string("garbage")
		f.close()
		SafeFile.write_json(PATH, { "money": 11 })
		return JSON.parse_string(FileAccess.get_file_as_string(PATH + ".bak")) == null or JSON.parse_string(FileAccess.get_file_as_string(PATH + ".bak")).get("money") == 10)
	_check("nothing at all reads as {}", func():
		_clean()
		return SafeFile.read_json(PATH).is_empty() and not SafeFile.exists(PATH))
	_check("only BACKUP_DAYS daily backups are kept", func():
		_clean()
		DirAccess.make_dir_recursive_absolute(SafeFile.BACKUP_DIR)
		for day in 10:
			var f := FileAccess.open("%ssafe_check_2020-01-%02d.json" % [SafeFile.BACKUP_DIR, day + 1], FileAccess.WRITE)
			f.store_string("{}")
			f.close()
		SafeFile.write_json(PATH, { "money": 1 })
		SafeFile.write_json(PATH, { "money": 2 })  # The second write makes today's backup.
		return SafeFile._backups_of(PATH).size() == SafeFile.BACKUP_DAYS)
	_clean()
	print("SAFE FILE CHECK: %d failed" % failed)
	quit(1 if failed > 0 else 0)


func _check(what: String, test: Callable) -> void:
	var ok: bool = test.call() == true
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failed += 1


func _clean() -> void:
	for file in DirAccess.get_files_at("user://"):
		if file.begins_with("safe_check.json"):
			DirAccess.remove_absolute("user://" + file)
	if DirAccess.dir_exists_absolute(SafeFile.BACKUP_DIR):
		for file in DirAccess.get_files_at(SafeFile.BACKUP_DIR):
			if file.begins_with("safe_check_"):
				DirAccess.remove_absolute(SafeFile.BACKUP_DIR + file)
