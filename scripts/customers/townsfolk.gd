# Townsfolk: the named walk-ins (data/townsfolk/, see GameData.townsfolk).
# They're friendly from the start (no stages, no house, no big moment), have
# their own lines for each step of a visit, a favorite dish and drink, and
# remember each chef who's served them. They come and go: about in_town of them
# live here at once, each for a few weeks before moving away for a while, and
# someone else moves in (data/service.json "semi_regulars"). Residents never
# leave. Anyone without a model walks in as the plain placeholder body. Those
# with a "talk" block in their file speak through TownsfolkTalk instead of the
# per-step lines here.
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
		state["just_back"] = int(state.get("visits", 0)) > 0
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
# `progress` is how far through the meal's customers this is (0 to 1): someone
# whose talk says "arrives": "late" waits till late_after of the way through
# (unless there's nobody else), and comes "before_bell" in the last stretch.
# Someone with a "skip_chance" sometimes doesn't turn up at all (missed).
# Not everyone comes every day: at most visits_per_day of them, new_per_day of
# those someone you've never served (so the town's faces arrive a few at a
# time), and those who've been away longest are likelier.
static func pick_walk_in(progress := 0.0) -> Dictionary:
	if GameState.townsfolk.is_empty():
		rotate(GameState.day_number)  # A save from before townsfolk: they move in now.
	var today := GameState.day_number
	var came := GameState.townsfolk.values().filter(func(s): return int(s.get("last_visit", 0)) == today and not s.get("missed", false))
	if came.size() >= int(settings().get("visits_per_day", 999)):
		return {}
	var new_today := came.filter(func(s): return int(s.get("first_day", -1)) == today).size()
	var allow_new := new_today < int(settings().get("new_per_day", 999))
	var free := GameData.townsfolk.filter(func(p):
		var state: Dictionary = GameState.townsfolk.get(p["id"], {})
		var unmet := int(state.get("visits", 0)) == 0 and not state.has("first_day")
		return state.get("in_town", false) and int(state.get("last_visit", 0)) != today and (allow_new or not unmet))
	var late_after := float(settings().get("late_after", 0.6))
	var on_time := free.filter(func(p): return p.get("talk", {}).get("arrives", "") != "late")
	if progress < late_after and not on_time.is_empty():
		free = on_time
	while not free.is_empty():
		var person: Dictionary = _longest_away(free)
		free.erase(person)
		var state: Dictionary = GameState.townsfolk[person["id"]]
		state["last_visit"] = today
		if int(state.get("visits", 0)) == 0 and not state.has("first_day"):
			state["first_day"] = today
		if randf() < float(person.get("talk", {}).get("skip_chance", 0.0)):
			state["missed"] = true  # Didn't make it today. Nobody waits; they'll have an excuse.
			continue
		state["before_bell"] = progress >= float(settings().get("before_bell_after", 0.9)) and person.get("talk", {}).get("arrives", "") == "late"
		return person
	return {}


# One of `people` at random, likelier the more days since they were last in
# (up to MAX_AWAY_WEIGHT; someone never in counts as that).
const MAX_AWAY_WEIGHT := 4
static func _longest_away(people: Array) -> Dictionary:
	var weights := people.map(func(p):
		var last := int(GameState.townsfolk.get(p["id"], {}).get("last_visit", 0))
		return MAX_AWAY_WEIGHT if last <= 0 else clampi(GameState.day_number - last, 1, MAX_AWAY_WEIGHT))
	var roll := randf() * float(weights.reduce(func(a, b): return a + b, 0))
	for i in people.size():
		roll -= weights[i]
		if roll < 0.0:
			return people[i]
	return people.back()


# Their favorite (when it can be had) favorite_chance of the time, else `fallback`.
static func choose(person: Dictionary, favorite_key: String, can_have: Array, fallback: Dictionary) -> Dictionary:
	var favorite := String(person.get(favorite_key, ""))
	var found := can_have.filter(func(item): return item["id"] == favorite)
	var chance: float = person.get("talk", {}).get("favorite_chance", settings().get("favorite_chance", 0.7))
	var state: Dictionary = GameState.townsfolk.get(person.get("id", ""), {})
	if not found.is_empty():
		if state.has("fallback_" + favorite_key):
			state.erase("fallback_" + favorite_key)
			state["finally"] = true  # It's on at last (Violet: "Finally.").
		if randf() < chance:
			return found[0]
	elif person.get("talk", {}).get("same_fallback", false) and not state.is_empty():
		var same := can_have.filter(func(item): return item["id"] == state.get("fallback_" + favorite_key, ""))
		if not same.is_empty():
			return same[0]
		state["fallback_" + favorite_key] = fallback.get("id", "")
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
	if not chef_id.is_empty():
		var served: Dictionary = state.get_or_add("served", {})  # Visits each chef served them.
		served[chef_id] = int(served.get(chef_id, 0)) + 1
	var met: Array = state.get_or_add("met", [])
	if not chef_id.is_empty() and not chef_id in met:
		met.append(chef_id)
