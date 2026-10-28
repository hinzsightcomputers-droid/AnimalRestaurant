# GameState (autoload): the restaurant's progress. Money, the real date and
# which shift of it this is, the upgrades bought, what each regular remembers,
# and a record of every customer served this shift (for the end-of-shift
# summary). Loads the save file on startup and saves after each shift.
extends Node

signal money_changed(money: int)

const SAVE_VERSION := 3

var money := 0
# What the players named their restaurant and the color it's written in (on the
# sign, and when regulars say it). Empty until named on the start screen.
var restaurant_name := ""
var restaurant_color := "#d1453b"
# The real local date of the current (or last) shift, e.g. "2026-10-27", and
# which shift of that date it is (1 = the first). See begin_shift.
var date := ""
var shift := 1
# Ids of upgrades bought (see data/upgrades.json), in the order they were bought.
var upgrades: Array[String] = []
# One entry per customer served this shift:
# { species, regular, dish, price, quality, wait_seconds, satisfaction, reaction, payment }
var services_today: Array[Dictionary] = []
# What each chef did this shift, for the summary: account id -> { chopped, cooked, served, cleaned }.
var chef_actions_today: Dictionary = {}
# Regular id -> that regular's current record (see GameData.regulars). Only the
# memory fields (GameData.memory_fields) are saved; the profile (name, tastes...)
# always comes from their character file, so editing it still takes effect.
# known_players and served_by use account ids (see Accounts).
var regulars: Dictionary = {}
# Which regulars come in on `date` and when (see VisitSchedule): { date, visits: [{ id, at }] }.
# Saved, so the same regulars are expected all date long.
var schedule := { "date": "", "visits": [] }
# Regular ids the debug panel asked to visit next, in order. Not saved.
var forced_visitors: Array[String] = []
# Debug panel: the next regular who can asks "What do you recommend?" / "Surprise me". Not saved.
var force_pick_for_me := false
# Missed phone calls waiting on the phone, oldest first: { kind, id } (see PhoneCalls).
# Saved, so they keep until someone plays them.
var voicemails: Array = []
# Debug panel: who rings the phone next (a caller or regular id). Not saved.
var forced_caller := ""


func _ready() -> void:
	reset_regulars()
	SaveGame.load_game()


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


# A shift is starting: on a new real date it's shift 1, otherwise the next one.
func begin_shift() -> void:
	var today := GameClock.today()
	if today != date:
		date = today
		shift = 1


# The shift is over: count it and save, so quitting from the summary screen
# keeps its progress.
func finish_shift() -> void:
	shift += 1
	services_today.clear()
	chef_actions_today.clear()
	SaveGame.save_game()


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


# Today's planned regular visits, planning (and saving) them on the first ask.
func todays_visits() -> Array:
	if schedule["date"] != date:
		replan_today()
	return schedule["visits"]


# A fresh plan for today, e.g. from the debug panel. Regulars already sent in
# today aren't sent again.
func replan_today() -> void:
	schedule = { "date": date, "visits": VisitSchedule.plan() }
	SaveGame.save_game()


# The number the next shift will have (a new date starts again at 1).
func next_shift_number() -> int:
	return 1 if GameClock.today() != date else shift


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
		"shift": shift,
		"upgrades": upgrades,
		"schedule": schedule,
		"voicemails": voicemails,
		"regulars": regular_memory,
	}


# Restore from to_save_data(). Missing values keep their defaults, and regulars
# without a character file any more are ignored.
func apply_save_data(data: Dictionary) -> void:
	money = int(data.get("money", money))
	restaurant_name = data.get("restaurant_name", restaurant_name)
	restaurant_color = data.get("restaurant_color", restaurant_color)
	date = data.get("date", date)  # Saves from before real dates had a "day" number instead; it's dropped.
	shift = int(data.get("shift", shift))
	# Ignore upgrades that were removed from data/upgrades.json.
	upgrades.assign(data.get("upgrades", []).filter(func(id): return GameData.upgrades.any(func(u): return u["id"] == id)))
	var saved_schedule = data.get("schedule", {})
	if saved_schedule is Dictionary and saved_schedule.has("visits"):
		var visits: Array = saved_schedule["visits"].filter(func(v): return regulars.has(v.get("id", "")))
		schedule = { "date": saved_schedule.get("date", ""), "visits": visits }
	voicemails = data.get("voicemails", []).filter(func(v): return v is Dictionary and v.has("kind") and v.has("id"))
	var legacy_account_id := _account_from_old_save(data)
	var saved_regulars: Dictionary = data.get("regulars", {})
	for id in saved_regulars:
		if not regulars.has(id):
			continue
		for field in GameData.memory_fields(id):
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
