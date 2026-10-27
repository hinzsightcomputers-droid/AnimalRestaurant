# GameState (autoload): the restaurant's progress. Money, the current day, what
# each regular remembers, and a record of every customer served today (for the
# end-of-day summary). Loads the save file on startup and saves after each day.
extends Node

signal money_changed(money: int)

const SAVE_VERSION := 2
# Fields of a regular that change during play. Everything else (name, tastes...)
# always comes from data/regulars.json, so editing that file still takes effect.
# known_players and served_by use account ids (see Accounts).
const REGULAR_MEMORY_FIELDS := ["relationship", "times_visited", "last_seen", "known_players", "served_by", "last_service_quality"]

var money := 0
var day := 1
# One entry per served customer today:
# { species, regular, dish, price, quality, wait_seconds, satisfaction, reaction, payment }
var services_today: Array[Dictionary] = []
# Regular id -> that regular's current record (same fields as data/regulars.json).
var regulars: Dictionary = {}


func _ready() -> void:
	reset_regulars()
	SaveGame.load_game()


# Back to the starting regulars from data/regulars.json.
func reset_regulars() -> void:
	regulars.clear()
	for record in GameData.regulars:
		regulars[record["id"]] = record.duplicate(true)
		_whole_number_counters(regulars[record["id"]])


# The day is over: move on to the next one and save, so quitting from the
# summary screen keeps today's progress.
func finish_day() -> void:
	day += 1
	services_today.clear()
	SaveGame.save_game()


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func record_service(service: Dictionary) -> void:
	services_today.append(service)


func earnings_today() -> int:
	var total := 0
	for service in services_today:
		total += service["payment"]
	return total


# Everything that needs saving, as plain JSON-friendly data.
func to_save_data() -> Dictionary:
	var regular_memory := {}
	for id in regulars:
		var memory := {}
		for field in REGULAR_MEMORY_FIELDS:
			memory[field] = regulars[id][field]
		regular_memory[id] = memory
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"money": money,
		"day": day,
		"regulars": regular_memory,
	}


# Restore from to_save_data(). Missing values keep their defaults, and regulars
# that are no longer in data/regulars.json are ignored.
func apply_save_data(data: Dictionary) -> void:
	money = int(data.get("money", money))
	day = int(data.get("day", day))
	var legacy_account_id := _account_from_old_save(data)
	var saved_regulars: Dictionary = data.get("regulars", {})
	for id in saved_regulars:
		if not regulars.has(id):
			continue
		for field in REGULAR_MEMORY_FIELDS:
			if saved_regulars[id].has(field):
				regulars[id][field] = saved_regulars[id][field]
		# Old saves only knew one chef: "knows_player_name" meant that chef.
		if saved_regulars[id].get("knows_player_name", false) and not legacy_account_id.is_empty():
			if not legacy_account_id in regulars[id]["known_players"]:
				regulars[id]["known_players"].append(legacy_account_id)
		_whole_number_counters(regulars[id])
	money_changed.emit(money)


# Saves from before accounts had one "player_name". Turn it into an account
# (once) so regulars who knew that name still do. Returns its id, or "".
func _account_from_old_save(data: Dictionary) -> String:
	if not data.get("has_chosen_name", false):
		return ""
	var old_name: String = data.get("player_name", "")
	if old_name.is_empty():
		return ""
	var account := Accounts.find_by_name(old_name)
	if account.is_empty():
		account = Accounts.create(old_name)
	return account["id"]


# JSON stores every number as a float; keep a regular's counters whole.
func _whole_number_counters(record: Dictionary) -> void:
	record["relationship"] = int(record["relationship"])
	record["times_visited"] = int(record["times_visited"])
	for account_id in record["served_by"]:
		record["served_by"][account_id] = int(record["served_by"][account_id])
