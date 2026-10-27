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


# Update the record after a finished visit. Returns true if they learned the
# player's name just now.
static func record_visit(record: Dictionary, quality: float, reaction_id: String, now_string: String) -> bool:
	var settings := GameData.regular_settings
	var change: int = settings.get("relationship_change", {}).get(reaction_id, 0)
	record["relationship"] = clampi(int(record["relationship"]) + change, 0, settings.get("relationship_max", 10))
	record["times_visited"] = int(record["times_visited"]) + 1
	record["last_seen"] = now_string
	record["last_service_quality"] = quality

	if not record["knows_player_name"] and record["relationship"] >= settings.get("learn_name_at", 3):
		record["knows_player_name"] = true
		return true
	return false


# e.g. "Regular", from the relationship_titles in data/regulars.json.
static func relationship_title(record: Dictionary) -> String:
	var title := ""
	for entry in GameData.regular_settings.get("relationship_titles", []):
		if record["relationship"] >= entry["min"]:
			title = entry["title"]
	return title


# Everything a dialogue line can check or mention. `extra` adds event-specific
# facts like the dish ordered or the reaction.
static func dialogue_context(record: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var days := days_away(record, int(Time.get_unix_time_from_system()))
	var context := {
		"regular": record["id"],
		"name": record["name"],
		"player": GameState.player_name,
		"personality": record.get("personality", []),
		"times_visited": record["times_visited"],
		"relationship": record["relationship"],
		"knows_player_name": record["knows_player_name"],
		"last_quality": record["last_service_quality"],
		"days": days,
		"returned_after_away": days >= GameData.regular_settings.get("away_days", 3),
		"favorite": GameData.get_dish(record["favorite_dish"]).get("name", ""),
		"disliked": GameData.get_dish(record["disliked_dish"]).get("name", ""),
	}
	context.merge(extra, true)
	return context
