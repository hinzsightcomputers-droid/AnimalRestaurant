# Accounts (autoload): the chefs who play here, each { id, name, playtime_seconds }.
# Saved in their own file (user://accounts.json), separate from the restaurant
# save, so playtime is kept even if you quit mid-day. Also remembers which
# account each joined player is using; like InputSetup, that lasts across days.
# Regulars remember chefs by account id (see RegularMemory).
extends Node

signal player_account_changed(player_index: int)

const SAVE_PATH := "user://accounts.json"
const AUTOSAVE_SECONDS := 30.0

var accounts: Array[Dictionary] = []
var _by_player: Dictionary = {}  # player_index -> account id.
var _since_save := 0.0


func _ready() -> void:
	_load()


# Playtime only counts while the game isn't paused (autoloads stop with the tree).
func _process(delta: float) -> void:
	if _by_player.is_empty():
		return
	for player_index in _by_player:
		var account := get_account(_by_player[player_index])
		if not account.is_empty():
			account["playtime_seconds"] += delta
	_since_save += delta
	if _since_save >= AUTOSAVE_SECONDS:
		save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()


# A new account, saved straight away.
func create(account_name: String) -> Dictionary:
	var account := {
		"id": "chef_%d_%04d" % [int(Time.get_unix_time_from_system()), randi() % 10000],
		"name": account_name,
		"playtime_seconds": 0.0,
	}
	accounts.append(account)
	save()
	return account


# The account with this id, or {} if there is none.
func get_account(id: String) -> Dictionary:
	for account in accounts:
		if account["id"] == id:
			return account
	return {}


# The account with this name (ignoring case), or {}.
func find_by_name(account_name: String) -> Dictionary:
	for account in accounts:
		if account["name"].to_lower() == account_name.to_lower():
			return account
	return {}


func assign(player_index: int, id: String) -> void:
	_by_player[player_index] = id
	player_account_changed.emit(player_index)


func has_account(player_index: int) -> bool:
	return _by_player.has(player_index)


# The account player `player_index` is using, or {}.
func account_of(player_index: int) -> Dictionary:
	return get_account(_by_player.get(player_index, ""))


func id_of(player_index: int) -> String:
	return _by_player.get(player_index, "")


# What to call a player: their account name, or "Player 2" before they pick one.
func name_of(player_index: int) -> String:
	return account_of(player_index).get("name", "Player %d" % (player_index + 1))


func is_in_use(id: String) -> bool:
	return id in _by_player.values()


# Accounts nobody is playing as right now, most played first.
func available() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(accounts.filter(func(a): return not is_in_use(a["id"])))
	result.sort_custom(func(a, b): return a["playtime_seconds"] > b["playtime_seconds"])
	return result


# Account ids of everyone playing right now.
func ids_in_play() -> Array[String]:
	var result: Array[String] = []
	for player_index in InputSetup.active_players():
		if _by_player.has(player_index):
			result.append(_by_player[player_index])
	return result


# e.g. "2h 05m", "14m", or "under 1m".
static func format_playtime(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	if minutes < 1:
		return "under 1m"
	if minutes < 60:
		return "%dm" % minutes
	return "%dh %02dm" % [floori(minutes / 60.0), minutes % 60]


func save() -> void:
	_since_save = 0.0
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write accounts file: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({"accounts": accounts}, "\t"))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		push_warning("Accounts file is damaged, starting with no accounts.")
		return
	for account in parsed.get("accounts", []):
		if account is Dictionary and account.has("id") and account.has("name"):
			account["playtime_seconds"] = float(account.get("playtime_seconds", 0.0))
			accounts.append(account)
