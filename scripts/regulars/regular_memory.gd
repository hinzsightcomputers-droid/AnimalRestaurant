# RegularMemory: the rules for regulars. Picks what they order (VisitSchedule
# picks who comes), works out their relationship stage, changes their
# relationship, updates what they remember after a visit, and builds the facts
# the DialoguePicker uses.
# Works on plain record dictionaries (see GameData.regulars). Every regular uses
# the same rules; only their data files differ.
class_name RegularMemory
extends RefCounted

const SECONDS_PER_DAY := 86400
const VISIT_START_STAGE := "visit_start_stage"  # On a record during a visit only (see begin_visit).


# Withdrawn and Gone regulars stay away, and referral-only ones wait for someone
# to recommend them.
static func visits_in_person(record: Dictionary) -> bool:
	if record.get("referral_only", false) and String(record.get("referred_by", "")).is_empty():
		return false
	return stage_of(record) >= GameData.regular_settings.get("lowest_stage_that_visits", -2)


# Usually their favorite; otherwise anything except the dish they dislike.
static func choose_dish(record: Dictionary) -> Dictionary:
	if randf() < GameData.regular_settings.get("favorite_order_chance", 0.7):
		return GameData.get_dish(record["favorite_dish"])
	var options: Array = GameData.dishes.filter(func(d): return d["id"] != record["disliked_dish"])
	return options.pick_random() if not options.is_empty() else GameData.random_dish()


# True if they already came in today (by the real local date), on any shift.
static func visited_today(record: Dictionary) -> bool:
	return GameClock.local_date_of(record["last_seen"]) == GameState.date


# Their stage from relationship: 1 to 4 when friendly, -1 to -4 when not
# (the "stages" table in data/regulars.json).
static func stage_of(record: Dictionary) -> int:
	for entry in GameData.regular_settings.get("stages", []):
		if record["relationship"] >= entry["min"]:
			return int(entry["stage"])
	return -4


# That stage's name for this regular, e.g. "Nervous" for Stitches at 10.
static func stage_name(record: Dictionary) -> String:
	var names: Dictionary = GameData.characters.get(record["id"], {}).get("stage_names", {})
	return names.get(str(stage_of(record)), "Stage %d" % stage_of(record))


# How much a reply in this tone changes their relationship right now, from their
# tone_reactions table. A [a, b] entry means either, at random (Stitches might
# think a joke is aimed at him).
static func tone_change(record: Dictionary, tone: String) -> int:
	var table: Dictionary = GameData.characters.get(record["id"], {}).get("tone_reactions", {})
	var stage := stage_of(record)
	var row: Dictionary = table.get("negative" if stage < 0 else str(stage), {})
	var value = row.get(tone, 0)
	if value is Array:
		return int(value.pick_random()) if not value.is_empty() else 0
	return int(value)


# Add to their relationship, kept between relationship_min and _max. Two rules
# keep the dark side deliberate:
#   - It can't drop below 0 unless they've had a run of rude replies (rude_streak).
#   - During a visit (see begin_visit) it can't drop more than one stage below
#     the stage they walked in at, however rude that visit gets.
# Returns the new value.
static func change_relationship(record: Dictionary, amount: int) -> int:
	var settings := GameData.regular_settings
	var before: int = record["relationship"]
	var after := clampi(before + amount, settings.get("relationship_min", -100), settings.get("relationship_max", 100))
	if after < 0 and before >= 0 and record["rude_streak"] < settings.get("rude_streak_to_go_negative", 3):
		after = 0
	if amount < 0 and record.has(VISIT_START_STAGE):
		after = maxi(after, mini(before, _lowest_in_stage_below(int(record[VISIT_START_STAGE]))))
	record["relationship"] = after
	return after


# A visit starts: remember their stage, for the one-stage-per-visit rule. Not
# saved (it isn't a memory field), and cleared by end_visit.
static func begin_visit(record: Dictionary) -> void:
	record[VISIT_START_STAGE] = stage_of(record)


static func end_visit(record: Dictionary) -> void:
	record.erase(VISIT_START_STAGE)


# The lowest relationship in the stage just below `stage` (e.g. stage 3 -> 25,
# the bottom of stage 2), or relationship_min if there's nothing below.
static func _lowest_in_stage_below(stage: int) -> int:
	var stages: Array = GameData.regular_settings.get("stages", [])  # Highest stage first.
	for i in stages.size() - 1:
		if int(stages[i]["stage"]) == stage:
			return int(stages[i + 1]["min"])
	return GameData.regular_settings.get("relationship_min", -100)


# Set their relationship directly (debug panel), ignoring the rules above.
static func set_relationship(record: Dictionary, value: int) -> void:
	var settings := GameData.regular_settings
	record["relationship"] = clampi(value, settings.get("relationship_min", -100), settings.get("relationship_max", 100))


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
	change_relationship(record, settings.get("relationship_change", {}).get(reaction_id, 0))
	record["times_visited"] = int(record["times_visited"]) + 1
	record["last_seen"] = now_string
	record["last_service_quality"] = quality
	var stage_key := str(stage_of(record))
	record["visits_by_stage"][stage_key] = int(record["visits_by_stage"].get(stage_key, 0)) + 1
	if server_id.is_empty():
		return false

	record["served_by"][server_id] = int(record["served_by"].get(server_id, 0)) + 1
	var known: Array = record["known_players"]
	if not server_id in known and stage_of(record) >= settings.get("learn_name_stage", 2):
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


# Everything a dialogue line can check or mention. `chef_id` is the account of
# the chef they're talking to ({player} / [name]). `extra` adds event-specific
# facts like the dish ordered or the reaction.
static func dialogue_context(record: Dictionary, chef_id: String, extra: Dictionary = {}) -> Dictionary:
	var days := days_away(record, GameClock.now_unix())
	var known_here: Array[String] = []  # Names of chefs playing now whose name they know.
	for account_id in Accounts.ids_in_play():
		if account_id in record["known_players"]:
			known_here.append(Accounts.get_account(account_id).get("name", ""))
	var chef_name: String = Accounts.get_account(chef_id).get("name", "Chef")
	var nickname: String = record.get("nickname", "")
	var wrong_names: Array = record.get("wrong_names", [])
	var dish_tokens: Dictionary = GameData.regular_settings.get("dish_tokens", {})
	var context := {
		"regular": record["id"],
		"name": record["name"],
		"player": chef_name,
		"nickname": nickname if not nickname.is_empty() else chef_name,
		"personality": record.get("personality", []),
		"times_visited": record["times_visited"],
		"relationship": record["relationship"],
		"stage": stage_of(record),
		"stage_name": stage_name(record),
		"knows_player_name": chef_id in record["known_players"],
		"times_served_by_player": int(record["served_by"].get(chef_id, 0)),
		"known_here_count": known_here.size(),
		"known_here": _names_list(known_here),
		"last_quality": record["last_service_quality"],
		"last_rude_line": record.get("last_rude_line", ""),
		"has_rude_line": not String(record.get("last_rude_line", "")).is_empty(),
		"wrong_name": wrong_names[int(record.get("wrong_name_index", 0)) % wrong_names.size()] if not wrong_names.is_empty() else chef_name,
		"player_favorite": record.get("player_favorite", ""),
		"days": days,
		"returned_after_away": days >= GameData.regular_settings.get("away_days", 3),
		"favorite": GameData.get_dish(record["favorite_dish"]).get("name", ""),
		"disliked": GameData.get_dish(record["disliked_dish"]).get("name", ""),
		"seen_lines": record.get("seen_lines", []),
		"memory": record,  # For "memory" conditions on character-specific fields.
	}
	for token in dish_tokens:  # "soup", "cheese dish"... -> that dish's name.
		context[token] = GameData.get_dish(dish_tokens[token]).get("name", token)
	context.merge(extra, true)
	return context


# The line this regular says for `event` (unfilled, with any choices), or {}.
# Remembers it in seen_lines, so they say something else next time.
static func pick_line(record: Dictionary, event: String, context: Dictionary) -> Dictionary:
	var line := DialoguePicker.pick_line(event, context)
	if not line.is_empty():
		var seen: Array = record.get_or_add("seen_lines", [])
		var key := DialoguePicker.line_key(line)
		seen.erase(key)
		seen.append(key)  # Most recent last.
	return line


# Like pick_line, but just the filled-in text ("" if nothing fits).
static func say(record: Dictionary, event: String, context: Dictionary) -> String:
	var line := pick_line(record, event, context)
	return DialoguePicker.fill(line["text"], context) if not line.is_empty() else ""


# "Alex", "Alex and Sam", "Alex, Sam and Jo".
static func _names_list(names: Array[String]) -> String:
	if names.size() <= 1:
		return "".join(PackedStringArray(names))
	return "%s and %s" % [", ".join(PackedStringArray(names.slice(0, -1))), names[-1]]
