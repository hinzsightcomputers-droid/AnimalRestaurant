# ReelSandbox: keeps a reel recording away from the real game files. When the
# game was started to play a reel (reel_player.tscn, or --scenario=<name> after
# the --), nothing is read from or written to save.json, accounts.json,
# settings.json or debug.json: SaveGame, Accounts, Settings and GameClock all
# ask active() first. The reel's state only ever lives in memory, so it's gone
# when the game closes, even after a crash. set_up() builds that state from a
# scenario (see ReelScenario). Only a fresh launch can be in the sandbox, so the
# real game is never switched over while it's running.
class_name ReelSandbox
extends RefCounted

const PLAYER_SCENE := "reel_player.tscn"
const SCENARIO_ARG := "--scenario="
const REAL_FILES := ["user://save.json", "user://accounts.json", "user://settings.json", "user://debug.json"]
const VISITS_BEFORE := 3      # A regular who isn't on their first visit has been in this many times.
const DAYS_SINCE_VISIT := 2   # And was last in this long ago.
const DAY_NUMBER := 30        # Far enough in that no first-days events happen.

static var _active := -1  # -1 = not worked out yet.


static func active() -> bool:
	if _active < 0:
		_active = 0
		for arg in OS.get_cmdline_args():
			if arg.ends_with(PLAYER_SCENE):
				_active = 1
		if not _scenario_arg().is_empty():
			_active = 1
	return _active == 1


# The scenario asked for on the command line, else `preferred`, else the first
# in res://reels/.
static func scenario_name(preferred := "") -> String:
	var asked := _scenario_arg()
	if not asked.is_empty():
		return asked
	if not preferred.is_empty():
		return preferred
	var all := ReelScenario.names()
	return all[0] if not all.is_empty() else ""


static func _scenario_arg() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(SCENARIO_ARG):
			return arg.trim_prefix(SCENARIO_ARG)
	return ""


# A fingerprint of the real files, to check afterwards that they didn't change.
static func fingerprint() -> Dictionary:
	var prints := {}
	for path in REAL_FILES:
		prints[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	return prints


# GameState, Accounts and DayCycle as the scenario says, in memory only. A quiet
# restaurant: nobody planned, no phone, no new-chef guide or birthday question.
static func set_up(scenario: Dictionary) -> void:
	if not active():
		push_error("ReelSandbox.set_up outside the sandbox: this would overwrite the real game state.")
		return
	var today := GameClock.today()
	var chef := Accounts.create(String(scenario.get("chef", "Chef")))
	Accounts.assign(0, chef["id"])
	GameState.mark_guided(chef["id"])
	GameState.birthdays[chef["id"]] = ""
	GameState.restaurant_name = String(scenario.get("restaurant", "Dinner Time"))
	GameState.date = today
	GameState.day_number = DAY_NUMBER
	GameState.day_plan = { "date": today, "phases": GameData.day_settings.get("phases", []).map(func(_p): return []) }
	DayCycle.phase = DayCycle.Phase.MEAL
	DayCycle.meal = ReelScenario.meal_index(scenario["meal"])
	DayCycle.reset_date = today
	_set_up_regular(scenario["regular"], chef["id"])
	for beat in scenario["beats"]:
		if beat.has("dish") and not beat["dish"] in GameState.unlocks:
			GameState.unlocks.append(beat["dish"])
		if beat.get("do", "") == "cook":  # Its dish on the menu, so its station is in the kitchen (the microwave with Mochi).
			for dish in GameData.dishes.filter(func(d): return d.get("recipe", "") == beat["recipe"]):
				if not dish["id"] in GameState.unlocks:
					GameState.unlocks.append(dish["id"])


static func _set_up_regular(wanted: Dictionary, chef_id: String) -> void:
	var record: Dictionary = GameState.regulars[wanted["id"]]
	RegularMemory.set_relationship(record, int(wanted["relationship"]))
	if not wanted.get("first_visit", false):
		record["times_visited"] = VISITS_BEFORE
		record["last_seen"] = Time.get_datetime_string_from_unix_time(GameClock.now_unix() - DAYS_SINCE_VISIT * GameClock.SECONDS_PER_DAY)
		record["known_players"] = [chef_id]
		record["introduced"] = true
	var memory: Dictionary = wanted.get("memory", {})
	for field in memory:
		record[field] = memory[field]
