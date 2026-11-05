# GameClock: the real-world date and time the game believes it is. The game runs
# on the real calendar: one restaurant day per real day, like Animal Crossing.
# A day starts at DAY_STARTS_AT_HOUR (5 AM local), not midnight, so a late-night
# session still counts as the day before (see today()). Normally
# the system clock, but the debug panel can push it forward by whole days to
# test "you've been gone" lines. The offset is kept in user://debug.json (not
# the save), so it survives restarts until it's reset.
class_name GameClock
extends RefCounted

const DEBUG_PATH := "user://debug.json"
const SECONDS_PER_DAY := 86400
const DAY_STARTS_AT_HOUR := 5
const WEEKDAYS := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

static var _offset_days := -1  # -1 = not loaded from DEBUG_PATH yet.


static func now_unix() -> int:
	return int(Time.get_unix_time_from_system()) + offset_days() * SECONDS_PER_DAY


# e.g. "2026-10-27T18:30:00", in UTC like the system version.
static func now_string() -> String:
	return Time.get_datetime_string_from_unix_time(now_unix())


# The player's local date and time (with the debug offset): year, month, day,
# weekday, hour, minute, second.
static func now_local() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(_to_local(now_unix()))


# Today's restaurant day, e.g. "2026-10-27": the local date, except that
# before 5 AM it's still yesterday.
static func today() -> String:
	return _day_of(now_unix())


# The real local calendar date, e.g. "2026-10-28" at 2 AM (for showing the date).
static func calendar_date() -> String:
	return _date_string(now_local())


# The restaurant day of a saved UTC time like now_string() gives, or "" if empty.
static func local_date_of(utc_string: String) -> String:
	if utc_string.is_empty():
		return ""
	return _day_of(Time.get_unix_time_from_datetime_string(utc_string))


# Seconds until the next restaurant day starts (the next 5 AM, local).
static func seconds_until_next_day() -> int:
	var local := _to_local(now_unix()) - DAY_STARTS_AT_HOUR * 3600
	return SECONDS_PER_DAY - posmod(local, SECONDS_PER_DAY)


# e.g. "7h 12m" or "45m".
static func describe_duration(seconds: int) -> String:
	var minutes := ceili(seconds / 60.0)
	return "%dh %02dm" % [minutes / 60, minutes % 60] if minutes >= 60 else "%dm" % minutes


# e.g. "Tuesday, Oct 27" for "2026-10-27" (short: "Tue, Oct 27").
static func describe_date(date: String, short := false) -> String:
	if date.is_empty():
		return "?"
	var parts := Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_string(date))
	var weekday: String = WEEKDAYS[parts["weekday"]]
	return "%s, %s %d" % [weekday.left(3) if short else weekday, MONTHS[parts["month"] - 1], parts["day"]]


# Which block of the day an hour (0-23) is in, from data/time.json: e.g.
# "early_morning" for 6, "late_night" for 2. Now's, if no hour is given.
static func hour_block(hour := -1) -> String:
	if hour < 0:
		hour = now_local()["hour"]
	for block in GameData.time_settings.get("hour_blocks", []):
		var from := int(block["from"])
		var to := int(block["to"])
		if (hour >= from and hour < to) if from < to else (hour >= from or hour < to):
			return block["id"]
	return ""


# The restaurant day's weekday as data/time.json names it, e.g. "tue" (before
# 5 AM it's still the day before). Today's, if no date is given.
static func weekday_id(date := "") -> String:
	if date.is_empty():
		date = today()
	var weekday: int = Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_string(date))["weekday"]
	var names: Array = GameData.time_settings.get("weekdays", ["sun", "mon", "tue", "wed", "thu", "fri", "sat"])
	return names[weekday]


# The season of a restaurant day ("spring", "summer", "autumn" or "winter";
# today's if no date is given), from data/time.json and the hemisphere setting.
# The debug panel can pretend it's another (GameState.debug_season).
static func season(date := "") -> String:
	if not GameState.debug_season.is_empty():
		return GameState.debug_season
	if date.is_empty():
		date = today()
	var month_day := date.right(5)  # "MM-DD"
	var seasons: Array = GameData.time_settings.get("seasons", [])
	if seasons.is_empty():
		return ""
	var found: String = seasons[-1]["id"]  # Before the first "from", it's still the last one (winter into the new year).
	for entry in seasons:
		if month_day >= String(entry["from"]):
			found = entry["id"]
	if GameState.hemisphere == "south":
		found = GameData.time_settings.get("southern_season", {}).get(found, found)
	return found


static func is_weekend(date := "") -> bool:
	return weekday_id(date) in GameData.time_settings.get("weekend", ["sat", "sun"])


# Whole restaurant days from `from` to `to` (both like "2026-10-27"); 0 if either is empty.
static func days_between(from: String, to: String) -> int:
	if from.is_empty() or to.is_empty():
		return 0
	return roundi((Time.get_unix_time_from_datetime_string(to) - Time.get_unix_time_from_datetime_string(from)) / float(SECONDS_PER_DAY))


# e.g. "8:42 PM" for now_local().
static func describe_time(local: Dictionary) -> String:
	var hour: int = local["hour"]
	return "%d:%02d %s" % [(hour + 11) % 12 + 1, local["minute"], "PM" if hour >= 12 else "AM"]


static func offset_days() -> int:
	if _offset_days < 0:
		_offset_days = 0
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DEBUG_PATH)) if FileAccess.file_exists(DEBUG_PATH) and not ReelSandbox.active() else null
		if parsed is Dictionary:
			_offset_days = maxi(0, int(parsed.get("clock_offset_days", 0)))
	return _offset_days


# Only forward: going back in time would make last visits look like the future.
static func set_offset_days(days: int) -> void:
	_offset_days = maxi(0, days)
	if ReelSandbox.active():
		return
	var file := FileAccess.open(DEBUG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({ "clock_offset_days": _offset_days }, "\t"))


# UTC seconds -> the same moment in local time (the system's time zone offset).
static func _to_local(unix: int) -> int:
	return unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60


static func _day_of(unix: int) -> String:
	return _date_string(Time.get_datetime_dict_from_unix_time(_to_local(unix) - DAY_STARTS_AT_HOUR * 3600))


static func _date_string(parts: Dictionary) -> String:
	return "%04d-%02d-%02d" % [parts["year"], parts["month"], parts["day"]]
