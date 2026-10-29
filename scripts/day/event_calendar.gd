# EventCalendar: which special days fall on a date (design/calendar/calendar.json):
# holidays (fixed dates, and Easter worked out for the year), the chefs'
# birthdays (GameState.birthdays) and the regulars' (their "birthday" field).
# Dates are "YYYY-MM-DD"; birthdays and fixed holidays are "MM-DD".
class_name EventCalendar
extends RefCounted

const PATH := "res://design/calendar/calendar.json"
const MONTHS := ["January", "February", "March", "April", "May", "June", "July",
	"August", "September", "October", "November", "December"]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else { "holidays": [] }
	return _data


# Everything on `date`: [{ id, kind ("holiday", "chef_birthday" or
# "regular_birthday"), banner }].
static func events_on(date: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var month_day := date.substr(5)
	for holiday in data().get("holidays", []):
		var on: String = holiday.get("date", "")
		if on == "easter":
			on = easter(int(date.left(4)))
		if on == month_day:
			events.append({ "id": holiday["id"], "kind": "holiday", "banner": holiday.get("banner", holiday.get("name", "")) })
	for account_id in GameState.birthdays:
		if GameState.birthdays[account_id] == month_day:
			var player: String = Accounts.get_account(account_id).get("name", "Chef")
			events.append({ "id": account_id, "kind": "chef_birthday",
				"banner": String(data().get("chef_birthday", {}).get("banner", "Happy birthday, {player}!")).format({ "player": player }) })
	for regular_id in GameState.regulars:
		var record: Dictionary = GameState.regulars[regular_id]
		if record.get("birthday", "") == month_day:
			events.append({ "id": regular_id, "kind": "regular_birthday",
				"banner": String(data().get("regular_birthday", {}).get("banner", "It's {name}'s birthday today!")).format({ "name": record["name"] }) })
	return events


# The first date after `date` with anything on it, within a year and a bit ("" if none).
static func next_event_after(date: String) -> String:
	var unix := Time.get_unix_time_from_datetime_string(date + "T12:00:00")
	for i in range(1, 400):
		var next := Time.get_date_string_from_unix_time(unix + i * 86400)
		if not events_on(next).is_empty():
			return next
	return ""


# Easter Sunday in `year` as "MM-DD" (the anonymous Gregorian algorithm).
@warning_ignore("integer_division")
static func easter(year: int) -> String:
	var a := year % 19
	var b := year / 100
	var c := year % 100
	var d := b / 4
	var e := b % 4
	var f := (b + 8) / 25
	var g := (b - f + 1) / 3
	var h := (19 * a + b - d - g + 15) % 30
	var i := c / 4
	var k := c % 4
	var l := (32 + 2 * e + 2 * i - h - k) % 7
	var m := (a + 11 * h + 22 * l) / 451
	var month := (h + l - 7 * m + 114) / 31
	var day := (h + l - 7 * m + 114) % 31 + 1
	return "%02d-%02d" % [month, day]


# "October 31" for "10-31".
static func describe(month_day: String) -> String:
	var month := int(month_day.left(2))
	return "%s %d" % [MONTHS[month - 1], int(month_day.substr(3))] if month >= 1 and month <= 12 else month_day


static func days_in_month(month: int) -> int:
	return [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]  # Feb 29 birthdays allowed.
