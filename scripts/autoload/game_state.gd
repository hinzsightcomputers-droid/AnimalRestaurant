# GameState (autoload): the restaurant's progress. Money, the current day, the
# upgrades bought, what each regular remembers, and a record of every customer
# served today (for the end-of-day summary). Loads the save file on startup and
# saves after each day.
extends Node

signal money_changed(money: int)

const SAVE_VERSION := 2
# Fields of a regular that change during play. Everything else (name, tastes...)
# always comes from data/regulars.json, so editing that file still takes effect.
# known_players and served_by use account ids (see Accounts).
const REGULAR_MEMORY_FIELDS := ["relationship", "times_visited", "last_seen", "known_players", "served_by", "last_service_quality"]

var money := 0
var day := 1
# Ids of upgrades bought (see data/upgrades.json), in the order they were bought.
var upgrades: Array[String] = []
# One entry per served customer today:
# { species, regular, dish, price, quality, wait_seconds, satisfaction, reaction, payment }
var services_today: Array[Dictionary] = []
# What each chef did today, for the summary: account id -> { chopped, cooked, served, cleaned }.
var chef_actions_today: Dictionary = {}
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
	chef_actions_today.clear()
	SaveGame.save_game()


# Count one thing a player did today, e.g. record_chef_action(1, "cooked").
func record_chef_action(player_index: int, action: String) -> void:
	var account_id := Accounts.id_of(player_index)
	if account_id.is_empty():
		return
	var actions: Dictionary = chef_actions_today.get_or_add(account_id, {})
	actions[action] = actions.get(action, 0) + 1


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func has_upgrade(upgrade_id: String) -> bool:
	return upgrade_id in upgrades


# Spend money on an upgrade and save. Returns false if it's owned or too pricey.
func buy_upgrade(upgrade_id: String) -> bool:
	var upgrade := GameData.get_upgrade(upgrade_id)
	if upgrade.is_empty() or has_upgrade(upgrade_id) or money < upgrade["price"]:
		return false
	upgrades.append(upgrade_id)
	add_money(-int(upgrade["price"]))
	SaveGame.save_game()
	return true


# What owned upgrades add to a number, e.g. upgrade_bonus("patient_seconds").
# Keys: chops, patient_seconds, tip_percent.
func upgrade_bonus(key: String) -> float:
	var total := 0.0
	for upgrade_id in upgrades:
		total += GameData.get_upgrade(upgrade_id).get("bonus", {}).get(key, 0.0)
	return total


# What owned upgrades scale a number by, e.g. upgrade_multiplier("stir_speed").
# Keys: stir_speed, arrival_interval.
func upgrade_multiplier(key: String) -> float:
	var factor := 1.0
	for upgrade_id in upgrades:
		factor *= GameData.get_upgrade(upgrade_id).get("multiplier", {}).get(key, 1.0)
	return factor


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
		"upgrades": upgrades,
		"regulars": regular_memory,
	}


# Restore from to_save_data(). Missing values keep their defaults, and regulars
# that are no longer in data/regulars.json are ignored.
func apply_save_data(data: Dictionary) -> void:
	money = int(data.get("money", money))
	day = int(data.get("day", day))
	# Ignore upgrades that were removed from data/upgrades.json.
	upgrades.assign(data.get("upgrades", []).filter(func(id): return GameData.upgrades.any(func(u): return u["id"] == id)))
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
