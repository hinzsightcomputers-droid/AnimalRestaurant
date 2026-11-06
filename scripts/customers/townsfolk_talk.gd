# TownsfolkTalk: how a semi-regular talks, from the "talk" block in their file
# (data/townsfolk/, see _template.json): what they say walking in, ordering,
# being served, chatting and leaving, with no UI. CustomerManager runs the visit
# and ConversationBox shows it.
#
# Semi-regulars have no relationship number. A reply changes their mood for that
# visit instead, which adds to the visit's satisfaction like the right drink.
# A few start reserved and warm up (familiar_after visits, or
# warm_choices_to_open warm replies from one chef), and lines can be for one
# voice or the other. They prefer lines you haven't heard yet.
#
# On each line: "when" is the moment it's for, "voice" is "before" or "familiar",
# "fav" means it talks about their favorite dish, so it's only said around that
# dish, and "later" parks it until the feature it needs exists. A line with a
# [placeholder] nothing fills yet is left out too.
#
# What this adds to GameState.townsfolk: seen (lines heard), warm (warm replies
# by chef), setback (visits a rude reply cost), rude_last (chefs who were rude
# last visit), last_rude_line, last_tier and last_dish (the last meal),
# last_seen_unix, just_back and familiar_told.
class_name TownsfolkTalk
extends RefCounted

const WHEN_NOW := ["day", "evening", "night", "breakfast", "weekend"]  # These just join the pool, when they're true.


static func talk_of(townsfolk_id: String) -> Dictionary:
	return GameData.get_townsfolk(townsfolk_id).get("talk", {})


static func has_talk(townsfolk_id: String) -> bool:
	return not talk_of(townsfolk_id).is_empty()


static func _state(townsfolk_id: String) -> Dictionary:
	return GameState.townsfolk.get_or_add(townsfolk_id, { "in_town": false, "until": 0, "met": [], "visits": 0, "last_visit": 0 })


static func _chance(key: String, fallback: float) -> float:
	return float(Townsfolk.settings().get(key, fallback))


# Whether they're using their warmer voice with this chef. The visit they're on
# counts, so familiar_after 4 means the fourth visit is the first in that voice.
static func is_familiar(townsfolk_id: String, chef_id: String) -> bool:
	var talk := talk_of(townsfolk_id)
	var state := _state(townsfolk_id)
	if talk.has("warm_choices_to_open"):
		return int(state.get("warm", {}).get(chef_id, 0)) >= int(talk["warm_choices_to_open"])
	if not talk.has("familiar_after"):
		return false
	return _visit_number(state) >= int(talk["familiar_after"])


static func _visit_number(state: Dictionary) -> int:
	return int(state.get("visits", 0)) + 1 - int(state.get("setback", 0))


# What their lines can mention. `dish` and `drink` are what they're having.
static func context(townsfolk_id: String, chef_id: String, dish: Dictionary = {}, drink: Dictionary = {}) -> Dictionary:
	var person := GameData.get_townsfolk(townsfolk_id)
	var state := _state(townsfolk_id)
	var words := {
		"name": Accounts.get_account(chef_id).get("name", ""),
		"fav_dish": GameData.get_dish(person.get("favorite_dish", "")).get("name", ""),
		"fav_drink": GameData.get_drink(person.get("favorite_drink", "")).get("name", ""),
		"restaurant": GameState.restaurant_name,
	}
	if not dish.is_empty():
		words["dish"] = dish.get("name", "")
	if not drink.is_empty():
		words["drink"] = drink.get("name", "")
	if state.has("last_rude_line"):
		words["last_rude_line"] = state["last_rude_line"]
	return words


static func fill(text: String, words: Dictionary) -> String:
	var result := text
	for key in words:
		result = result.replace("[%s]" % key, str(words[key]))
	return result


# "" until all of a line's placeholders can be filled.
static func _usable(text: String, words: Dictionary) -> bool:
	return not text.is_empty() and not "[" in fill(text, words)


# --- Picking lines --------------------------------------------------------------

static func _time_now() -> Dictionary:
	var phase := DayCycle.phase_id()
	# Walk-ins don't come in on the night shift itself, so dinner is as late as
	# they get: that's when night people say their night lines.
	var late: bool = phase == "dinner" or DayCycle.is_night()
	return { "day": not late, "evening": phase == "dinner", "night": late, "breakfast": phase == "breakfast", "weekend": GameClock.is_weekend() }


# Whether `line` can be said now by someone in that voice. `dish_id` is what
# they're having (or had last).
static func _can_say(townsfolk_id: String, chef_id: String, line: Dictionary, words: Dictionary, dish_id: String) -> bool:
	if line.has("later") or not _usable(String(line.get("text", "")), words):
		return false
	var voice: String = line.get("voice", "")
	if not voice.is_empty() and (voice == "familiar") != is_familiar(townsfolk_id, chef_id):
		return false
	if line.get("fav", false) and dish_id != GameData.get_townsfolk(townsfolk_id).get("favorite_dish", ""):
		return false
	return not "[name]" in String(line["text"]) or chef_id in _state(townsfolk_id).get("met", [])


# Lines with no "when" that can be said now, plus those whose "when" is true.
static func _pool(townsfolk_id: String, chef_id: String, lines: Array, words: Dictionary, dish_id: String) -> Array:
	var now := _time_now()
	return lines.filter(func(line):
		var when: String = line.get("when", "")
		if not when.is_empty() and not (when in WHEN_NOW and now[when]):
			return false
		return _can_say(townsfolk_id, chef_id, line, words, dish_id))


# The first line for the moment `when`, or {}.
static func _for_moment(townsfolk_id: String, chef_id: String, lines: Array, when: String, words: Dictionary, dish_id: String) -> Dictionary:
	for line in lines:
		if line.get("when", "") == when and _can_say(townsfolk_id, chef_id, line, words, dish_id):
			return line
	return {}


# Something from `pool` you haven't heard, starting over once you've heard it all.
static func _pick_unheard(townsfolk_id: String, pool: Array) -> Dictionary:
	if pool.is_empty():
		return {}
	var seen: Array = _state(townsfolk_id).get_or_add("seen", [])
	var fresh := pool.filter(func(line): return not _key(line) in seen)
	if fresh.is_empty():
		for line in pool:
			seen.erase(_key(line))
		fresh = pool
	var line: Dictionary = fresh.pick_random()
	seen.append(_key(line))
	return line


static func _key(line: Dictionary) -> String:
	return str(String(line.get("text", "")).hash())


# Their line for a holiday or the chef's birthday today, else sometimes for the
# season. "" for neither.
static func _season_line(townsfolk_id: String, chef_id: String, words: Dictionary) -> String:
	var seasons: Dictionary = talk_of(townsfolk_id).get("seasons", {})
	var today := GameClock.calendar_date()
	var state := _state(townsfolk_id)
	for event in EventCalendar.events_on(today):
		var key: String = { "new_years_day": "new_year" }.get(event["id"], event["id"])
		if event["kind"] == "chef_birthday":
			key = "chef_birthday" if event["id"] == chef_id else ""
		if seasons.has(key) and state.get("holiday_said", "") != today + key and _usable(seasons[key], words):
			state["holiday_said"] = today + key
			return seasons[key]
	var season: String = seasons.get(GameClock.season(), "")
	return season if randf() < _chance("season_line_chance", 0.25) and _usable(season, words) else ""


# --- A visit --------------------------------------------------------------------

# What they say at the host stand. The first time a chef meets them, they ask
# that chef's name and use it from then on.
static func arrival(townsfolk_id: String, chef_id: String) -> String:
	var state := _state(townsfolk_id)
	var lines: Array = talk_of(townsfolk_id).get("arrival", [])
	var words := context(townsfolk_id, chef_id)
	var last_dish: String = state.get("last_dish", "")
	var met: Array = state.get_or_add("met", [])
	var back: bool = state.get("just_back", false)
	state.erase("just_back")
	if not chef_id in met:
		met.append(chef_id)
		for line in lines:  # In any voice: a new chef still gets introduced.
			if line.get("when", "") == "first":
				return fill(line["text"], words)
	var line := {}
	if int(talk_of(townsfolk_id).get("familiar_after", 0)) == _visit_number(state) and not state.get("familiar_told", false):
		line = _for_moment(townsfolk_id, chef_id, lines, "familiar_moment", words, GameData.get_townsfolk(townsfolk_id).get("favorite_dish", ""))
		state["familiar_told"] = not line.is_empty()
	if line.is_empty() and back:
		line = _for_moment(townsfolk_id, chef_id, lines, "back", words, last_dish)
	if line.is_empty():
		var season := _season_line(townsfolk_id, chef_id, words)
		if not season.is_empty():
			return fill(season, words)
	var rude: Array = state.get("rude_last", [])
	if line.is_empty() and chef_id in rude:
		line = _for_moment(townsfolk_id, chef_id, lines, "rude_last_time", words, last_dish)
	rude.erase(chef_id)
	if line.is_empty() and _days_since_seen(state) >= int(Townsfolk.settings().get("away_real_days", 3)):
		line = _for_moment(townsfolk_id, chef_id, lines, "away", words, last_dish)
	if line.is_empty() and randf() < _chance("last_meal_line_chance", 0.5):
		var tier: String = state.get("last_tier", "")
		if tier == "burnt":
			line = _for_moment(townsfolk_id, chef_id, lines, "last_burnt", words, last_dish)
		elif tier == "perfect" or tier == "great":
			line = _for_moment(townsfolk_id, chef_id, lines, "last_great", words, last_dish)
	if line.is_empty():
		line = _pick_unheard(townsfolk_id, _pool(townsfolk_id, chef_id, lines, words, last_dish))
	return fill(String(line.get("text", "")), words)


static func _days_since_seen(state: Dictionary) -> int:
	var seen := int(state.get("last_seen_unix", 0))
	return 0 if seen == 0 else (GameClock.now_unix() - seen) / 86400


# What they'd like to drink and how they ask: { drink, text }. Their favorite
# most of the time, and if it isn't on the menu yet, what they'd have instead.
static func drink_order(townsfolk_id: String, chef_id: String) -> Dictionary:
	var talk := talk_of(townsfolk_id)
	var lines: Dictionary = talk.get("drink", {})
	var menu := GameData.drink_menu()
	var on_menu := func(drink_id: String) -> Dictionary:
		var found := menu.filter(func(d): return d["id"] == drink_id)
		return found[0] if not found.is_empty() else {}
	var favorite: Dictionary = on_menu.call(GameData.get_townsfolk(townsfolk_id).get("favorite_drink", ""))
	var chance := 1.0 if lines.get("always", false) else float(talk.get("favorite_chance", Townsfolk.settings().get("favorite_chance", 0.7)))
	var drink := {}
	var text := ""
	if not favorite.is_empty() and randf() < chance:
		drink = favorite
		var options: Array = lines.get("favourite", [])
		text = String(options.pick_random()) if not options.is_empty() else ""
		if lines.has("night") and _time_now()["night"] and randf() < 0.5:
			text = lines["night"]
	elif favorite.is_empty() and lines.has("fallback"):
		drink = on_menu.call(lines.get("fallback_drink", ""))
		if not drink.is_empty() or not lines.has("fallback_drink"):
			text = lines["fallback"]
	if drink.is_empty():
		drink = on_menu.call(lines.get("other_drink", ""))
		if drink.is_empty():
			drink = GameData.random_drink()
		if text.is_empty():
			text = lines.get("other", "")
	return { "drink": drink, "text": fill(text, context(townsfolk_id, chef_id, {}, drink)) }


# The ordering conversation for this visit, or {} for none they can have. One
# that talks about their favorite dish needs it on the menu, and has them order it.
static func pick_order(townsfolk_id: String, chef_id: String) -> Dictionary:
	var favorite: String = GameData.get_townsfolk(townsfolk_id).get("favorite_dish", "")
	var can_have := GameData.menu().any(func(d): return d["id"] == favorite)
	var words := context(townsfolk_id, chef_id, { "name": "dish" }, { "name": "drink" })
	var pool: Array = talk_of(townsfolk_id).get("order", []).filter(func(talk_line):
		return (can_have or not talk_line.get("fav", false)) and _can_converse(townsfolk_id, chef_id, talk_line, words))
	return _pick_unheard(townsfolk_id, pool)


static func _can_converse(townsfolk_id: String, chef_id: String, line: Dictionary, words: Dictionary) -> bool:
	match String(line.get("only", "")):
		"familiar":
			if not is_familiar(townsfolk_id, chef_id):
				return false
		"night":
			if not _time_now()["night"]:
				return false
		"grudge":
			return false  # Seth's apology: comes with his grudge.
	if not _usable(line["text"], words):
		return false
	for choice in line.get("choices", []):
		if not _usable(String(choice.get("text", "")), words):
			return false
		for reply in [choice, choice.get("familiar", {}), choice.get("misses", {}), choice.get("day", {})]:
			if "[" in fill(String(reply.get("reply", "")), words):
				return false
	return true


# The chef picked `choice`. Returns { reply, mood, emotion }: the reply as written
# for how things stand, and how much that does for their mood this visit.
static func answer(townsfolk_id: String, chef_id: String, choice: Dictionary) -> Dictionary:
	var talk := talk_of(townsfolk_id)
	var state := _state(townsfolk_id)
	var result := choice
	if choice.has("familiar") and is_familiar(townsfolk_id, chef_id):
		result = choice["familiar"]
	elif choice.has("misses") and randf() < _chance("playful_miss_chance", 0.5):
		result = choice["misses"]
	elif choice.has("day") and not _time_now()["night"]:
		result = choice["day"]
	var reply: String = result.get("reply", "")
	var mood := float(result.get("mood", 0.0))
	match String(choice.get("tone", "")):
		"warm":
			var warm: Dictionary = state.get_or_add("warm", {})
			warm[chef_id] = int(warm.get(chef_id, 0)) + 1
		"rude":
			state.get_or_add("warm", {}).erase(chef_id)
			state["last_rude_line"] = choice.get("text", "")
			var rude: Array = state.get_or_add("rude_last", [])
			if not chef_id in rude:
				rude.append(chef_id)
			state["setback"] = int(state.get("setback", 0)) + int(talk.get("rude_sets_back", 0))
	if choice.get("crash_out", false):
		var lines: Array = talk.get("crash_out", [])
		reply = String(lines.pick_random()) if not lines.is_empty() else ""
	return { "reply": reply, "mood": mood, "emotion": &"sad" if mood < 0.0 else (&"happy" if mood > 0.0 else &"") }


# What they say when the food lands, by how it came out (perfect, great, okay or
# burnt). "" if they have nothing to say about this dish.
static func served(townsfolk_id: String, chef_id: String, tier: String, dish: Dictionary) -> String:
	var talk := talk_of(townsfolk_id)
	var line: Dictionary = talk.get("served", {}).get(tier, {})
	var text: String = line.get("text", "")
	if line.has("familiar") and is_familiar(townsfolk_id, chef_id):
		text = line["familiar"]
	if line.get("fav", false) and dish.get("id", "") != GameData.get_townsfolk(townsfolk_id).get("favorite_dish", ""):
		return ""
	var words := context(townsfolk_id, chef_id, dish)
	if not _usable(text, words):
		return ""
	var intro: String = talk.get("served_intro", "")
	return fill(text if intro.is_empty() else "%s %s" % [intro, text], words)


# Walking up while they eat: a line, or sometimes a chat with choices (it has
# "choices"). {} for nothing.
static func eating(townsfolk_id: String, chef_id: String, dish: Dictionary) -> Dictionary:
	var talk := talk_of(townsfolk_id)
	var words := context(townsfolk_id, chef_id, dish)
	var dish_id: String = dish.get("id", "")
	var favorite: String = GameData.get_townsfolk(townsfolk_id).get("favorite_dish", "")
	if randf() < _chance("eating_choice_chance", 0.35):
		var chats: Array = talk.get("eating_chat", []).filter(func(line):
			return (dish_id == favorite or not line.get("fav", false)) and _can_converse(townsfolk_id, chef_id, line, words))
		var chat := _pick_unheard(townsfolk_id, chats)
		if not chat.is_empty():
			return chat
	var season: String = talk.get("seasons", {}).get(GameClock.season(), "")
	if randf() < _chance("season_line_chance", 0.25) and _usable(season, words):
		return { "text": season }
	return _pick_unheard(townsfolk_id, _pool(townsfolk_id, chef_id, talk.get("eating", []), words, dish_id))


# Goodbye. The last visit before they go away has its own line.
static func leaving(townsfolk_id: String, chef_id: String, dish: Dictionary) -> String:
	var state := _state(townsfolk_id)
	var lines: Array = talk_of(townsfolk_id).get("leaving", [])
	var words := context(townsfolk_id, chef_id, dish)
	var dish_id: String = dish.get("id", "")
	var line := {}
	var until := int(state.get("until", 0))
	if until > 0 and until <= GameState.day_number + 1:
		line = _for_moment(townsfolk_id, chef_id, lines, "leaving_town", words, dish_id)
	if line.is_empty():
		line = _pick_unheard(townsfolk_id, _pool(townsfolk_id, chef_id, lines, words, dish_id))
	return fill(String(line.get("text", "")), words)


# They paid: what to remember about the meal for next time.
static func after_visit(townsfolk_id: String, dish: Dictionary, quality: float) -> void:
	var state := _state(townsfolk_id)
	state["last_tier"] = CookingMinigame.quality_label(quality).to_lower()
	state["last_dish"] = dish.get("id", "")
	state["last_seen_unix"] = GameClock.now_unix()
