# GameClock: the real-world date the game believes it is. Normally the system
# clock, but the debug panel can push it forward by whole days to test "you've
# been gone" lines. The offset is kept in user://debug.json (not the save), so it
# survives restarts until it's reset.
class_name GameClock
extends RefCounted

const DEBUG_PATH := "user://debug.json"
const SECONDS_PER_DAY := 86400

static var _offset_days := -1  # -1 = not loaded from DEBUG_PATH yet.


static func now_unix() -> int:
	return int(Time.get_unix_time_from_system()) + offset_days() * SECONDS_PER_DAY


# e.g. "2026-10-27T18:30:00", in UTC like the system version.
static func now_string() -> String:
	return Time.get_datetime_string_from_unix_time(now_unix())


static func offset_days() -> int:
	if _offset_days < 0:
		_offset_days = 0
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DEBUG_PATH)) if FileAccess.file_exists(DEBUG_PATH) else null
		if parsed is Dictionary:
			_offset_days = maxi(0, int(parsed.get("clock_offset_days", 0)))
	return _offset_days


# Only forward: going back in time would make last visits look like the future.
static func set_offset_days(days: int) -> void:
	_offset_days = maxi(0, days)
	var file := FileAccess.open(DEBUG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({ "clock_offset_days": _offset_days }, "\t"))
