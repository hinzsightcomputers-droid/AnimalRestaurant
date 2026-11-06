# Townsfolk: the named walk-ins (data/townsfolk/, see GameData.townsfolk).
# They're friendly from the start (no stages, no house, no big moment), have
# their own lines for each step of a visit, a favorite dish and drink, and
# remember each chef who's served them. They come and go: about in_town of them
# live here at once, each for a few weeks before moving away for a while, and
# someone else moves in (data/service.json "semi_regulars"). Residents never
# leave. Anyone without a model walks in as the plain placeholder body.
# What changes is in GameState.townsfolk, by id: { in_town, until (the day they
# move away, or can come back), met: [account ids], visits, last_visit (the
# day they last walked in) }.
class_name Townsfolk
extends RefCounted


static func settings() -> Dictionary:
	return GameData.service.get("semi_regulars", {})


# Who's here and who's away, for a new day: anyone due to leave moves away, and
# others move in until there are in_town again. Returns the morning's news
# (nothing on the very first day, when the town just fills up).
static func rotate(day: int) -> Array[String]:
	var news: Array[String] = []
	var states := GameState.townsfolk
	var first := states.is_empty()
	var here := 0
	for person in GameData.townsfolk:
		var state: Dictionary = states.get_or_add(person["id"], { "in_town": false, "until": 0, "met": [], "visits": 0, "last_visit": 0 })
		if person.get("resident", false):
			state["in_town"] = true
			continue
		if state["in_town"] and int(state["until"]) > 0 and int(state["until"]) <= day:
			state["in_town"] = false
			state["until"] = day + _days("away_days", [14, 40])
			news.append(String(settings().get("moved_away", "{name} moved away.")).format({ "name": person["name"] }))
		elif state["in_town"]:
			here += 1
	var away := GameData.townsfolk.filter(func(p): return not p.get("resident", false) and not states[p["id"]]["in_town"] and int(states[p["id"]]["until"]) <= day)
	away.shuffle()
	while here < int(settings().get("in_town", 12)) and not away.is_empty():
		var person: Dictionary = away.pop_back()
		var state: Dictionary = states[person["id"]]
		state["in_town"] = true
		var stay := _days("stay_days", [14, 35])
		state["until"] = day + (randi_range(1, stay) if first else stay)  # The first lot leave at different times.
		here += 1
		if not first:
			news.append(String(settings().get("moved_in", "{name} just moved to town.")).format({ "name": person["name"] }))
	return news


static func _days(key: String, fallback: Array) -> int:
	var range_days: Array = settings().get(key, fallback)
	return randi_range(int(range_days[0]), int(range_days[1]))


static func is_in_town(townsfolk_id: String) -> bool:
	return bool(GameState.townsfolk.get(townsfolk_id, {}).get("in_town", false))


# Who walks in next: someone in town who hasn't been in yet today. {} if nobody.
static func pick_walk_in() -> Dictionary:
	if GameState.townsfolk.is_empty():
		rotate(GameState.day_number)  # A save from before townsfolk: they move in now.
	var free := GameData.townsfolk.filter(func(p):
		var state: Dictionary = GameState.townsfolk.get(p["id"], {})
		return state.get("in_town", false) and int(state.get("last_visit", 0)) != GameState.day_number)
	if free.is_empty():
		return {}
	var person: Dictionary = free.pick_random()
	GameState.townsfolk[person["id"]]["last_visit"] = GameState.day_number
	return person


# Their favorite (when it can be had) favorite_chance of the time, else `fallback`.
static func choose(person: Dictionary, favorite_key: String, can_have: Array, fallback: Dictionary) -> Dictionary:
	var favorite := String(person.get(favorite_key, ""))
	var found := can_have.filter(func(item): return item["id"] == favorite)
	if not found.is_empty() and randf() < float(settings().get("favorite_chance", 0.5)):
		return found[0]
	return fallback


# One of their lines for `step` of the visit, talking to chef `chef_id`, with
# {dish}, {drink} and {chef} filled in: from their seasonal lines half the time
# in that season, else their own. Lines with {chef} wait until they've met that
# chef. "" if they have none (the generic townsfolk line is said instead).
static func line(townsfolk_id: String, step: String, context: Dictionary, chef_id: String) -> String:
	var lines: Dictionary = GameData.get_townsfolk(townsfolk_id).get("lines", {})
	var met: bool = chef_id in GameState.townsfolk.get(townsfolk_id, {}).get("met", [])
	var usable := func(options) -> Array:
		return Array(options if options is Array else []).filter(func(text): return met or not "{chef}" in String(text))
	var options: Array = usable.call(lines.get("seasonal", {}).get(GameClock.season(), {}).get(step, []))
	if options.is_empty() or randf() < 0.5:
		var own: Array = usable.call(lines.get(step, []))
		if not own.is_empty():
			options = own
	if options.is_empty():
		return ""
	var filled := context.duplicate()
	filled["chef"] = Accounts.get_account(chef_id).get("name", "")
	return String(options.pick_random()).format(filled)


# Their eating bubble for how the food came out (perfect, great, okay, burnt), or "".
static func eating_line(townsfolk_id: String, tier: String) -> String:
	return String(GameData.get_townsfolk(townsfolk_id).get("lines", {}).get("eating", {}).get(tier, ""))


# They paid: one more visit, and they know the chef who served them now.
static func record_visit(townsfolk_id: String, chef_id: String) -> void:
	var state: Dictionary = GameState.townsfolk.get(townsfolk_id, {})
	if state.is_empty():
		return
	state["visits"] = int(state.get("visits", 0)) + 1
	var met: Array = state.get_or_add("met", [])
	if not chef_id.is_empty() and not chef_id in met:
		met.append(chef_id)
