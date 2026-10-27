# RegularMemory: the rules for regulars. Picks which regular visits, what they
# order, updates what they remember after a visit, and builds the facts the
# DialoguePicker uses. Works on plain record dictionaries (see data/regulars.json).
class_name RegularMemory
extends RefCounted

const SECONDS_PER_DAY := 86400


# A random regular not in `exclude_ids`, or {} if nobody comes this time.
static func pick_visitor(exclude_ids: Array) -> Dictionary:
	if randf() >= GameData.regular_settings.get("regular_chance", 0.4):
		return {}
	var candidates: Array = []
	for id in GameState.regulars:
		if not id in exclude_ids:
			candidates.append(GameState.regulars[id])
	return candidates.pick_random() if not candidates.is_empty() else {}


# Usually their favorite; otherwise anything except the dish they dislike.
static func choose_dish(record: Dictionary) -> Dictionary:
	if randf() < GameData.regular_settings.get("favorite_order_chance", 0.7):
		return GameData.get_dish(record["favorite_dish"])
	var options: Array = GameData.dishes.filter(func(d): return d["id"] != record["disliked_dish"])
	return options.pick_random() if not options.is_empty() else GameData.random_dish()


# Whole real-world days since they last visited, or -1 if they never have.
static func days_away(record: Dictionary, now_unix: int) -> int:
	var last_seen: String = record.get("last_seen", "")
	if last_seen.is_empty():
		return -1
	var seconds := now_unix - Time.get_unix_time_from_datetime_string(last_seen)
	return maxi(0, floori(seconds / float(SECONDS_PER_DAY)))


# Update the record after a finished visit, served by the chef with account id
# `server_id`. Returns true if they learned that chef's name just now.
static func record_visit(record: Dictionary, quality: float, reaction_id: String, now_string: String, server_id: String) -> bool:
	var settings := GameData.regular_settings
	var change: int = settings.get("relationship_change", {}).get(reaction_id, 0)
	record["relationship"] = clampi(int(record["relationship"]) + change, 0, settings.get("relationship_max", 10))
	record["times_visited"] = int(record["times_visited"]) + 1
	record["last_seen"] = now_string
	record["last_service_quality"] = quality
	if server_id.is_empty():
		return false

	record["served_by"][server_id] = int(record["served_by"].get(server_id, 0)) + 1
	var known: Array = record["known_players"]
	if not server_id in known and record["relationship"] >= settings.get("learn_name_at", 3):
		known.append(server_id)
		return true
	return false


# Of the chefs playing right now, the one this regular knows best (served them
# most, and knows their name first), or "" if nobody is playing.
static func favorite_chef_here(record: Dictionary) -> String:
	var best := ""
	var best_score := -1
	for account_id in Accounts.ids_in_play():
		var score: int = int(record["served_by"].get(account_id, 0))
		if account_id in record["known_players"]:
			score += 1000
		if score > best_score:
			best = account_id
			best_score = score
	return best


# e.g. "Regular", from the relationship_titles in data/regulars.json.
static func relationship_title(record: Dictionary) -> String:
	var title := ""
	for entry in GameData.regular_settings.get("relationship_titles", []):
		if record["relationship"] >= entry["min"]:
			title = entry["title"]
	return title


# Everything a dialogue line can check or mention. `chef_id` is the account of
# the chef they're talking to ({player}). `extra` adds event-specific facts like
# the dish ordered or the reaction.
static func dialogue_context(record: Dictionary, chef_id: String, extra: Dictionary = {}) -> Dictionary:
	var days := days_away(record, int(Time.get_unix_time_from_system()))
	var known_here: Array[String] = []  # Names of chefs playing now whose name they know.
	for account_id in Accounts.ids_in_play():
		if account_id in record["known_players"]:
			known_here.append(Accounts.get_account(account_id).get("name", ""))
	var context := {
		"regular": record["id"],
		"name": record["name"],
		"player": Accounts.get_account(chef_id).get("name", "Chef"),
		"personality": record.get("personality", []),
		"times_visited": record["times_visited"],
		"relationship": record["relationship"],
		"knows_player_name": chef_id in record["known_players"],
		"times_served_by_player": int(record["served_by"].get(chef_id, 0)),
		"known_here_count": known_here.size(),
		"known_here": _names_list(known_here),
		"last_quality": record["last_service_quality"],
		"days": days,
		"returned_after_away": days >= GameData.regular_settings.get("away_days", 3),
		"favorite": GameData.get_dish(record["favorite_dish"]).get("name", ""),
		"disliked": GameData.get_dish(record["disliked_dish"]).get("name", ""),
	}
	context.merge(extra, true)
	return context


# "Alex", "Alex and Sam", "Alex, Sam and Jo".
static func _names_list(names: Array[String]) -> String:
	if names.size() <= 1:
		return "".join(PackedStringArray(names))
	return "%s and %s" % [", ".join(PackedStringArray(names.slice(0, -1))), names[-1]]
