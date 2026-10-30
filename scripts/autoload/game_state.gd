# GameState (autoload): the restaurant's progress. Money, today's restaurant
# day and how far through it we are (which meal, who's been in), the upgrades
# bought, what each regular remembers, and a record of every customer served
# today (for the end-of-day summary). Loads the save file on startup and saves
# as the day goes, so quitting mid-day carries on where it left off.
extends Node

signal money_changed(money: int)
signal unlocks_changed  # A big moment reward or a dish was unlocked (or the debug panel cleared them).

const SAVE_VERSION := 6
# phase_info(NIGHT) is the night shift's settings. Saves before version 6 kept
# the day's phase here as a meal index, NIGHT or CLOSED (see DayCycle).
const NIGHT := 98
const CLOSED := 99

var money := 0
# What the players named their restaurant and the color it's written in (on the
# sign, and when regulars say it). Empty until named on the start screen.
var restaurant_name := ""
var restaurant_color := "#d1453b"
# The restaurant day of the current (or last) day open, e.g. "2026-10-27" (see
# GameClock.today), and how many days the restaurant has opened (1 = the first).
var date := ""
var day_number := 0
# Today's customers, one list per meal: { regular: id } or { walk_in: true }
# (see DayPlan), and which of this meal's are done (their indexes), so a day
# picked up again doesn't send them twice.
var day_plan := { "date": "", "phases": [] }
var phase_done: Array = []
# Ids of upgrades bought (see data/upgrades.json), in the order they were bought.
var upgrades: Array[String] = []
# One entry per customer served today:
# { species, regular, dish, drink?, price, quality, wait_seconds, satisfaction, reaction, payment }
# (price: the menu price of everything they had, so payment above it is the tip).
var services_today: Array[Dictionary] = []
# What each chef did today, for the summary: account id -> { chopped, cooked, served, cleaned }.
var chef_actions_today: Dictionary = {}
# Regular id -> that regular's current record (see GameData.regulars). Only the
# memory fields (GameData.memory_fields) are saved; the profile (name, tastes...)
# always comes from their character file, so editing it still takes effect.
# known_players and served_by use account ids (see Accounts).
var regulars: Dictionary = {}
# Regular ids the debug panel asked to visit next, in order. Not saved.
var forced_visitors: Array[String] = []
# Debug panel: the next regular who can asks "What do you recommend?" / "Surprise me". Not saved.
var force_pick_for_me := false
# Missed phone calls waiting on the phone, oldest first: { kind, id } (see PhoneCalls).
# Saved, so they keep until someone plays them.
var voicemails: Array = []
# Debug panel: who rings the phone next (a caller or regular id). Not saved.
var forced_caller := ""
# Rewards from big moment scenes, e.g. "patchwork_apron", "mabel_bell" (see
# data/scenes.json), and the ids of dishes bought in the shop or unlocked by a
# scene (see GameData.is_unlocked). Just flags for now. Saved.
var unlocks: Array[String] = []
# Debug panel: a big moment scene to play at closing today, whatever its trigger. Not saved.
var forced_scene := ""
# The phone: a townsfolk asked "Do you deliver?" (on day 3+, see data/service.json),
# so the next morning the phone is on the wall. Until then there are no phone
# orders and no night shift. Saved.
var delivery_asked := false
var phone_unlocked := false
var phone_news := false  # The phone went up this morning: say so once the day starts. Not saved.
# Tonight's night shift: how many calls it gets (picked when it starts) and how
# many have rung so far. Saved, so a night picked up again doesn't start over.
var night_calls_total := 0
var night_calls_used := 0
# Each chef's birthday, by account id: "MM-DD", or "" if they'd rather not say
# (then they aren't asked again). Asked on their first day; see EventCalendar. Saved.
var birthdays: Dictionary = {}
# Debug panel: a dish id that's the only thing on the menu (e.g. to test its recipe). Not saved.
var forced_dish := ""
# Which half of the world the players are in, for the seasons (see
# GameClock.season): "north" or "south". Saved.
var hemisphere := "north"
# The kitchen's pantry: what the chefs caught or gathered after hours, by item
# id (a fish id...) -> how many. Dishes that need them take from it (see
# Pantry). Never sold for money. Saved.
var pantry: Dictionary = {}
# The Fish Log, by fish id: { caught, biggest_cm, biggest_by, first_date,
# first_by, by: { account id: count } } (account ids; dates are restaurant
# days). Saved.
var fish_log: Dictionary = {}
# The Forage Log, by item id: { found, first_date, first_by, by: { account id:
# count } }. Saved.
var forage_log: Dictionary = {}
# Today's foraging: { date (the restaurant day), picked: [spot indexes],
# salt (the debug panel's re-roll) }. A new day starts it fresh. Saved.
var forage_today: Dictionary = {}
# Debug panel: pretend it's this season ("" = the real one) or hour block
# outdoors (for fishing), and the fish that bites on the next cast. Not saved.
var debug_season := ""
var debug_hour_block := ""
var forced_fish := ""


func _ready() -> void:
	reset_regulars()
	SaveGame.load_game()


# Closing the window mid-day keeps everything since the last save: what
# regulars remember (a rude reply, a new friend, a letter on its way),
# voicemails, money, which meal it is and who's been in. A brand-new game that
# was never named doesn't get a save file.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and (SaveGame.has_save() or not restaurant_name.is_empty()):
		SaveGame.save_game()


# Back to the starting regulars from their character files.
func reset_regulars() -> void:
	regulars.clear()
	for record in GameData.regulars:
		reset_regular(record["id"])


# One regular back to how their character file starts them (debug panel).
func reset_regular(regular_id: String) -> void:
	for record in GameData.regulars:
		if record["id"] == regular_id:
			regulars[regular_id] = record.duplicate(true)
			_whole_number_counters(regulars[regular_id])


# The restaurant is opening (or reopening): on a new restaurant day it starts
# again at the first meal with a fresh plan; the same day carries on where it
# was, including after closing (then it's After Hours, see DayCycle).
func begin_day() -> void:
	var today := GameClock.today()
	if today == date:
		return
	date = today
	day_number += 1
	DayCycle.start_day()
	phase_done.clear()
	night_calls_total = 0
	night_calls_used = 0
	if delivery_asked and not phone_unlocked:
		phone_unlocked = true
		phone_news = true
	services_today.clear()
	chef_actions_today.clear()
	replan_today()


# The day's over: on to the summary (built from today's services, and kept by
# DayCycle to reopen after hours). Saves, so quitting from the summary keeps it.
func close_day(summary: Dictionary) -> void:
	services_today.clear()
	chef_actions_today.clear()
	DayCycle.to_summary(summary)


# Customer `index` of this meal's list (see todays_plan) is done, and saved.
func mark_done(index: int) -> void:
	if index >= 0 and not index in phase_done:
		phase_done.append(index)
		SaveGame.save_game()


# How many meals a day has (data/day.json).
static func phase_count() -> int:
	return GameData.day_settings.get("phases", []).size()


# The meal's settings from data/day.json (the night shift's for NIGHT, {} for CLOSED).
static func phase_info(index: int) -> Dictionary:
	if index == NIGHT:
		return GameData.day_settings.get("night", { "name": "Night" })
	var phases: Array = GameData.day_settings.get("phases", [])
	return phases[index] if index >= 0 and index < phases.size() else {}


# Count one thing a player did this shift, e.g. record_chef_action(1, "cooked").
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


# Spend a shop dish's unlock_cost to put it on the menu, and save. Returns
# false if it isn't sold, is already unlocked, or is too pricey.
func buy_dish(dish_id: String) -> bool:
	var dish := GameData.get_dish(dish_id)
	if dish.get("unlock", "") != "upgrade" or GameData.is_unlocked(dish_id) or money < int(dish["unlock_cost"]):
		return false
	unlocks.append(dish_id)
	unlocks_changed.emit()
	add_money(-int(dish["unlock_cost"]))
	SaveGame.save_game()
	return true


# Same for a drink from the shop.
func buy_drink(drink_id: String) -> bool:
	var drink := GameData.get_drink(drink_id)
	if drink.get("unlock", "") != "upgrade" or GameData.is_unlocked(drink_id) or money < int(drink["unlock_cost"]):
		return false
	unlocks.append(drink_id)
	unlocks_changed.emit()
	add_money(-int(drink["unlock_cost"]))
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
# Keys: stir_window (the stirring close-up), stir_speed (the timing minigame), arrival_interval.
func upgrade_multiplier(key: String) -> float:
	var factor := 1.0
	for upgrade_id in upgrades:
		factor *= GameData.get_upgrade(upgrade_id).get("multiplier", {}).get(key, 1.0)
	return factor


# Today's customers, one list per meal, planning (and saving) them on the first ask.
func todays_plan() -> Array:
	if day_plan["date"] != date:
		replan_today()
	return day_plan["phases"]


# A fresh plan for today, e.g. from the debug panel. Regulars already in today
# aren't sent again (CustomerManager skips them).
func replan_today() -> void:
	day_plan = { "date": date, "phases": DayPlan.plan() }
	phase_done.clear()
	SaveGame.save_game()


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
		for field in GameData.memory_fields(id):
			memory[field] = regulars[id][field]
		regular_memory[id] = memory
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"money": money,
		"restaurant_name": restaurant_name,
		"restaurant_color": restaurant_color,
		"date": date,
		"day_number": day_number,
		"day_cycle": DayCycle.to_save_data(),
		"phase_done": phase_done,
		"day_plan": day_plan,
		"services_today": services_today,
		"chef_actions_today": chef_actions_today,
		"upgrades": upgrades,
		"voicemails": voicemails,
		"unlocks": unlocks,
		"delivery_asked": delivery_asked,
		"phone_unlocked": phone_unlocked,
		"night_calls_total": night_calls_total,
		"night_calls_used": night_calls_used,
		"birthdays": birthdays,
		"hemisphere": hemisphere,
		"pantry": pantry,
		"fish_log": fish_log,
		"forage_log": forage_log,
		"forage_today": forage_today,
		"regulars": regular_memory,
	}


# Restore from to_save_data(). Missing values keep their defaults, and regulars
# without a character file any more are ignored.
func apply_save_data(data: Dictionary) -> void:
	money = int(data.get("money", money))
	restaurant_name = data.get("restaurant_name", restaurant_name)
	restaurant_color = data.get("restaurant_color", restaurant_color)
	date = data.get("date", date)  # Saves from before real dates had a "day" number instead; it's dropped.
	day_number = int(data.get("day_number", day_number))
	if data.get("day_cycle") is Dictionary:
		DayCycle.apply_save_data(data["day_cycle"])
	elif data.has("phase"):  # Saves from before version 6: one number for the phase.
		DayCycle.apply_old_phase(int(data["phase"]))
	else:  # Saves from before one-day-a-day had shifts instead: that day starts over.
		date = ""
	phase_done.assign(data.get("phase_done", []).map(func(i): return int(i)))
	var saved_plan = data.get("day_plan", {})
	if saved_plan is Dictionary and saved_plan.get("phases") is Array:
		day_plan = { "date": saved_plan.get("date", ""), "phases": saved_plan["phases"] }
	services_today.assign(data.get("services_today", []))
	chef_actions_today = data.get("chef_actions_today", {})
	# Ignore upgrades that were removed from data/upgrades.json.
	upgrades.assign(data.get("upgrades", []).filter(func(id): return GameData.upgrades.any(func(u): return u["id"] == id)))
	unlocks.assign(data.get("unlocks", []).map(func(id): return "walters_storm_soup" if id == "storm_soup" else id))  # Its old id.
	delivery_asked = bool(data.get("delivery_asked", false))
	phone_unlocked = bool(data.get("phone_unlocked", false))  # Saves from before the phone had to be unlocked start without it.
	night_calls_total = int(data.get("night_calls_total", 0))
	night_calls_used = int(data.get("night_calls_used", 0))
	birthdays = data.get("birthdays", {}) if data.get("birthdays", {}) is Dictionary else {}
	hemisphere = "south" if data.get("hemisphere", "north") == "south" else "north"
	pantry = {}
	var saved_pantry = data.get("pantry", {})
	if saved_pantry is Dictionary:
		for item in saved_pantry:
			if int(saved_pantry[item]) > 0:
				pantry[item] = int(saved_pantry[item])
	fish_log = data.get("fish_log", {}) if data.get("fish_log", {}) is Dictionary else {}
	for entry in fish_log.values():
		entry["caught"] = int(entry.get("caught", 0))
		entry["biggest_cm"] = int(entry.get("biggest_cm", 0))
		for account_id in entry.get("by", {}):
			entry["by"][account_id] = int(entry["by"][account_id])
	forage_log = data.get("forage_log", {}) if data.get("forage_log", {}) is Dictionary else {}
	for entry in forage_log.values():
		entry["found"] = int(entry.get("found", 0))
		for account_id in entry.get("by", {}):
			entry["by"][account_id] = int(entry["by"][account_id])
	forage_today = data.get("forage_today", {}) if data.get("forage_today", {}) is Dictionary else {}
	forage_today["picked"] = forage_today.get("picked", []).map(func(i): return int(i))
	forage_today["salt"] = int(forage_today.get("salt", 0))
	voicemails = data.get("voicemails", []).filter(func(v): return v is Dictionary and v.has("kind") and v.has("id"))
	var legacy_account_id := _account_from_old_save(data)
	var saved_regulars: Dictionary = data.get("regulars", {})
	for id in saved_regulars:
		if not regulars.has(id):
			continue
		for field in GameData.memory_fields(id):
			if saved_regulars[id].has(field):
				regulars[id][field] = saved_regulars[id][field]
		# Saves from before introductions: anyone who'd visited has told you their name.
		if not saved_regulars[id].has("introduced"):
			regulars[id]["introduced"] = int(regulars[id]["times_visited"]) > 0
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


# JSON stores every number as a float; keep a regular's counters whole (the
# number fields, except last_service_quality, plus the counts in served_by and
# visits_by_stage).
func _whole_number_counters(record: Dictionary) -> void:
	for field in GameData.memory_fields(record["id"]):
		if record[field] is float and field != "last_service_quality":
			record[field] = int(record[field])
	for counts in [record["served_by"], record["visits_by_stage"]]:
		for key in counts:
			counts[key] = int(counts[key])
