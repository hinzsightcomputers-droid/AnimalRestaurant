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
# [placeholder] nothing fills yet is left out too. "when": "drawing" (Clover) is
# only said while she still has a drawing you don't (see TownsfolkSpecials.has_drawing).
#
# What this adds to GameState.townsfolk: seen (lines heard), warm (warm replies
# by chef), setback (visits a rude reply cost), rude_last (chefs who were rude
# last visit), last_rude_line, last_tier and last_dish (the last meal),
# last_seen_unix, just_back and familiar_told; cold (chef -> the day of a
# crash-out) and grudge (chef -> the rude line they remember); outfits_seen
# (chef -> what they last saw them in) and outfit_day (see outfit_line).
#
# A crash_out reply (Amy) makes them cold to that chef for the rest of the day:
# their "cold" lines stand in for anything else they'd say, and next time they
# have an "after_crash_out" arrival. A grudge reply (Seth) puts that chef on
# their grudge list for good: "grudge" arrival and leaving lines, "grudge_drop"
# words left out of the rest, and only the "only": "grudge" ordering
# conversation, until an "apology" reply clears it.
#
# "now_and_then" (see _roll_now_and_then) are the things they do some visits:
# Iddy's "shallow and pedantic", Amy's news and outbursts, Violet's rare
# lines, Hezzy's songs and honks. A line can also say when it's true (see
# _true_now): who's in town, who's sitting in here, how yesterday went, and so on.
class_name TownsfolkTalk
extends RefCounted

const WHEN_NOW := ["day", "evening", "night", "breakfast", "weekend", "game_day"]  # These just join the pool, when they're true.


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
	if has_grudge(townsfolk_id, chef_id):
		words["last_rude_line"] = state["grudge"][chef_id]  # What they remember you saying.
	var low := lowest_regular()
	if not low.is_empty():
		words["low_regular"] = low["name"]
		words["low_them"] = GameData.characters.get(low["id"], {}).get("them", "them")
	var trip: String = _state(person.get("talk", {}).get("trip_from", townsfolk_id)).get("trip", "")
	if not trip.is_empty():
		words["trip"] = trip
	TownsfolkSpecials.add_words(townsfolk_id, words)
	return words


# Cold to this chef after a crash-out today.
static func is_cold(townsfolk_id: String, chef_id: String) -> bool:
	return int(_state(townsfolk_id).get("cold", {}).get(chef_id, -1)) == GameState.day_number


static func has_grudge(townsfolk_id: String, chef_id: String) -> bool:
	return _state(townsfolk_id).get("grudge", {}).has(chef_id)


# One of their cold lines.
static func _cold_line(townsfolk_id: String) -> String:
	var lines: Array = talk_of(townsfolk_id).get("cold", [])
	return String(lines.pick_random()) if not lines.is_empty() else ""


# `text` without their friendly words, for a chef they hold a grudge against.
static func _grudging(townsfolk_id: String, chef_id: String, text: String) -> String:
	if not has_grudge(townsfolk_id, chef_id):
		return text
	for words in talk_of(townsfolk_id).get("grudge_drop", []):
		text = text.replace(words, "")
	return text


static func fill(text: String, words: Dictionary) -> String:
	var result := text
	for key in words:
		result = result.replace("[%s]" % key, str(words[key]))
	return RegEx.create_from_string("([.!?])\"\\.").sub(result, "$1\"", true)  # A quote: "Go away." not "Go away.".


# "" until all of a line's placeholders can be filled.
static func _usable(text: String, words: Dictionary) -> bool:
	return not text.is_empty() and not "[" in fill(text, words)


# --- Picking lines --------------------------------------------------------------

static func _time_now() -> Dictionary:
	var phase := DayCycle.phase_id()
	# Walk-ins don't come in on the night shift itself, so dinner is as late as
	# they get: that's when night people say their night lines.
	var late: bool = phase == "dinner" or DayCycle.is_night()
	return { "day": not late, "evening": phase == "dinner", "night": late, "breakfast": phase == "breakfast", "weekend": GameClock.is_weekend(),
		"game_day": GameClock.is_weekend() and phase == "dinner" }  # Chompy's weekend dinners.


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
	if not _true_now(townsfolk_id, line):
		return false
	return not "[name]" in String(line["text"]) or chef_id in _state(townsfolk_id).get("met", [])


# Whether what `line` is about is so right now. Its keys (all optional):
# in_town / away (a semi-regular), not_in_yet (in town, not been in today),
# regular_in (a regular sitting in here) with regular_at (at that table),
# min_stage ({ regular: stage }), rough_yesterday (true or false), season,
# not_friends (they haven't had their first time in with them yet),
# dirty_table, has_decor, no_decor (none of those ids placed), decor_up (placed),
# any_decor (one of those placed), few_decor (fewer than that placed), full_set.
static func _true_now(townsfolk_id: String, line: Dictionary) -> bool:
	if line.has("in_town") and not Townsfolk.is_in_town(line["in_town"]):
		return false
	if line.has("away") and Townsfolk.is_in_town(line["away"]):
		return false
	if line.has("not_in_yet") and (not Townsfolk.is_in_town(line["not_in_yet"]) or int(_state(line["not_in_yet"]).get("last_visit", -1)) == GameState.day_number):
		return false
	if line.has("regular_in"):
		var at: String = line.get("regular_at", "")
		if not customers_in().any(func(c): return c.regular_id == line["regular_in"] and (at.is_empty() or (c.seat != null and c.seat.table != null and c.seat.table.spot == at))):
			return false
	for regular_id in line.get("min_stage", {}):
		var record: Dictionary = GameState.regulars.get(regular_id, {})
		if record.is_empty() or not record.get("introduced", false) or RegularMemory.stage_of(record) < int(line["min_stage"][regular_id]):
			return false
	if line.has("rough_yesterday") and bool(line["rough_yesterday"]) != rough_yesterday():
		return false
	if line.has("season") and GameClock.season() != line["season"]:
		return false
	if line.has("not_friends") and line["not_friends"] in _state(townsfolk_id).get("friends_met", []):
		return false
	if line.has("decor_up") and not GameState.decor_placed.any(func(p): return p["id"] == line["decor_up"]):
		return false
	if line.get("dirty_table", false) and not _a_dirty_table():
		return false
	if line.get("has_decor", false) and GameState.decor_placed.is_empty():
		return false
	if line.has("any_decor") and not GameState.decor_placed.any(func(p): return p["id"] in line["any_decor"]):
		return false
	if line.has("few_decor") and GameState.decor_placed.size() >= int(line["few_decor"]):
		return false
	if line.get("full_set", false) and not Decor.has_full_set():
		return false
	if line.has("no_decor") and GameState.decor_placed.any(func(p): return p["id"] in line["no_decor"]):
		return false
	return true


# Everyone in the restaurant right now.
static func customers_in() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.find_children("*", "Customer", true, false) if tree != null else []


static func _a_dirty_table() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	return tree != null and tree.root.find_children("*", "DiningTable", true, false).any(func(t): return not t.is_clean())


# The last day open went badly (rough_day_below average satisfaction).
static func rough_yesterday() -> bool:
	return not GameState.service_history.is_empty() and float(GameState.service_history.back()) < _chance("rough_day_below", 0.5)


# The introduced regular who's lowest right now, or {} if nobody's below stage 1.
static func lowest_regular() -> Dictionary:
	var lowest := {}
	for record in GameState.regulars.values():
		if record.get("introduced", false) and (lowest.is_empty() or int(record["relationship"]) < int(lowest["relationship"])):
			lowest = record
	return lowest


# Lines with no "when" that can be said now, plus those whose "when" is true.
static func _pool(townsfolk_id: String, chef_id: String, lines: Array, words: Dictionary, dish_id: String) -> Array:
	var now := _time_now()
	return lines.filter(func(line):
		var when: String = line.get("when", "")
		if when == "drawing":  # Clover: only while she still has a drawing for you.
			return TownsfolkSpecials.has_drawing(townsfolk_id) and _can_say(townsfolk_id, chef_id, line, words, dish_id)
		if not when.is_empty() and not (when in WHEN_NOW and now[when]):
			return false
		return _can_say(townsfolk_id, chef_id, line, words, dish_id))


# A line for the moment `when` (one at random if there are a few), or {}.
static func _for_moment(townsfolk_id: String, chef_id: String, lines: Array, when: String, words: Dictionary, dish_id: String) -> Dictionary:
	var found := lines.filter(func(line): return line.get("when", "") == when and _can_say(townsfolk_id, chef_id, line, words, dish_id))
	var line: Dictionary = found.pick_random() if not found.is_empty() else {}
	if line.has("gift"):
		_state(townsfolk_id)["gift"] = line["gift"]
	return line


# Outfits townsfolk notice (Rush): what a chef has on in these slots.
const OUTFIT_SLOTS := ["hat", "top", "dress", "bottom", "shoes", "apron"]


# Chef `chef_id`'s outfit as townsfolk see it: { slot: item id or "" }.
static func outfit_of(chef_id: String) -> Dictionary:
	var look := Accounts.appearance_of_account(chef_id)
	var outfit := {}
	for slot in OUTFIT_SLOTS:
		outfit[slot] = look.worn(slot)
	return outfit


# Someone with "outfit" lines (Rush) remembers what each chef wore last time
# (outfits_seen in their GameState.townsfolk record). If it's changed, they
# say one of those lines, once a visit, for arriving or eating; the first time
# they see a chef they just take it in. A line with "part" (a slot, e.g. "hat")
# is for when that's new, and comes first; one with "wearing" (a slot or an
# item id) only if the chef has it on, and one with "unlocked" only once that's
# unlocked. Lines with [name] wait until they know the chef's name, so there
# should always be some without. "" for nothing to say.
static func outfit_line(townsfolk_id: String, chef_id: String) -> String:
	var talk := talk_of(townsfolk_id)
	var state := _state(townsfolk_id)
	if not talk.has("outfit") or Accounts.get_account(chef_id).is_empty() or int(state.get("outfit_day", -1)) == GameState.day_number:
		return ""
	var seen: Dictionary = state.get_or_add("outfits_seen", {})
	var now := outfit_of(chef_id)
	if not seen.has(chef_id):
		seen[chef_id] = now
		return ""
	var before: Dictionary = seen[chef_id]
	var new_parts := OUTFIT_SLOTS.filter(func(slot): return not String(now[slot]).is_empty() and String(now[slot]) != String(before.get(slot, "")))
	if new_parts.is_empty() and OUTFIT_SLOTS.all(func(slot): return String(now[slot]) == String(before.get(slot, ""))):
		return ""
	var look := Accounts.appearance_of_account(chef_id)
	var words := context(townsfolk_id, chef_id)
	var pool: Array = talk["outfit"].filter(func(line):
		return _wears(look, line) and (not line.has("unlocked") or line["unlocked"] in GameState.unlocks) and _can_say(townsfolk_id, chef_id, line, words, ""))
	var line := {}
	for slot in new_parts:
		var about := pool.filter(func(each): return each.get("part", "") == slot)
		if not about.is_empty():
			line = _pick_unheard(townsfolk_id, about)
			break
	if line.is_empty():
		var general := pool.filter(func(each): return not each.has("part"))
		var special := general.filter(func(each): return each.has("wearing") or each.has("unlocked"))
		line = _pick_unheard(townsfolk_id, special if not special.is_empty() and randf() < 0.5 else general)
	if line.is_empty():
		return ""
	seen[chef_id] = now
	state["outfit_day"] = GameState.day_number
	return fill(line["text"], words)


# Whether the chef has on what `line` is about ("wearing": a slot or item id).
static func _wears(look: CharacterAppearance, line: Dictionary) -> bool:
	if not line.has("wearing"):
		return true
	var what := String(line["wearing"])
	return not look.worn(what).is_empty() if what in Wardrobe.SLOTS else what in look.worn_items()


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
	if line.has("gift"):
		_state(townsfolk_id)["gift"] = line["gift"]
	return line


# Each of their "now_and_then" entries comes up `chance` of visits (rolled as
# they walk in), at one of its moments ("at": arrival, eating or leaving), and
# then says one of its lines instead of what they'd say there. "familiar": true
# waits for their warmer voice; "loud": true makes everyone near jump (see
# take_startle); "asked_after" is what they say if you walk up straight after.
# A line can have "then": a second line said after it.
static func _roll_now_and_then(townsfolk_id: String, chef_id: String) -> void:
	var due := []
	var entries: Array = talk_of(townsfolk_id).get("now_and_then", [])
	for i in entries.size():
		var entry: Dictionary = entries[i]
		if entry.get("familiar", false) and not is_familiar(townsfolk_id, chef_id):
			continue
		if randf() < float(entry.get("chance", 0.0)):
			due.append({ "entry": i, "at": Array(entry.get("at", ["eating"])).pick_random() })
	_state(townsfolk_id)["now_and_then"] = due


static func _now_and_then(townsfolk_id: String, chef_id: String, moment: String, words: Dictionary, dish_id: String) -> Dictionary:
	var state := _state(townsfolk_id)
	var entries: Array = talk_of(townsfolk_id).get("now_and_then", [])
	for due in state.get("now_and_then", []).duplicate():
		if due["at"] != moment or int(due["entry"]) >= entries.size():
			continue
		state["now_and_then"].erase(due)
		var entry: Dictionary = entries[int(due["entry"])]
		var line := _pick_unheard(townsfolk_id, entry.get("lines", []).filter(func(l): return _can_say(townsfolk_id, chef_id, l, words, dish_id)))
		if line.is_empty():
			continue
		if entry.get("loud", false):
			state["startle"] = true
		if entry.has("asked_after"):
			state["asked_after"] = entry["asked_after"]
		return line
	return {}


# Whether what they just said made everyone near jump (once).
static func take_startle(townsfolk_id: String) -> bool:
	var state := _state(townsfolk_id)
	var loud: bool = state.get("startle", false)
	state.erase("startle")
	return loud


static func _key(line: Dictionary) -> String:
	return str(String(line.get("text", JSON.stringify(line.get("beats", [])))).hash())  # A duo is its beats.


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
	_roll_now_and_then(townsfolk_id, chef_id)
	if not chef_id in met:
		met.append(chef_id)
		for line in lines:  # In any voice: a new chef still gets introduced.
			if line.get("when", "") == "first":
				return fill(line["text"], words)
	if has_grudge(townsfolk_id, chef_id):
		var cold := _for_moment(townsfolk_id, chef_id, lines, "grudge", words, last_dish)
		if not cold.is_empty():
			return fill(cold["text"], words)
	var crashed: Dictionary = state.get("cold", {})
	if crashed.has(chef_id) and int(crashed[chef_id]) < GameState.day_number:
		crashed.erase(chef_id)
		var fresh_start := _for_moment(townsfolk_id, chef_id, lines, "after_crash_out", words, last_dish)
		if not fresh_start.is_empty():
			return fill(fresh_start["text"], words)
	if state.get("missed", false):
		state.erase("missed")
		var excuse := _for_moment(townsfolk_id, chef_id, lines, "missed", words, last_dish)
		if not excuse.is_empty():
			return fill(excuse["text"], words)
	if state.get("before_bell", false):
		state.erase("before_bell")
		var barely := _for_moment(townsfolk_id, chef_id, lines, "before_bell", words, last_dish)
		if not barely.is_empty():
			return fill(barely["text"], words)
	var gossip := TownsfolkFriends.gossip_line(townsfolk_id, chef_id)
	if not gossip.is_empty():
		return gossip
	var special := TownsfolkSpecials.arrival(townsfolk_id, chef_id, words)
	if not special.is_empty():
		return special
	var now := _now_and_then(townsfolk_id, chef_id, "arrival", words, last_dish)
	if not now.is_empty():
		return fill(now["text"], words)
	var line := {}
	if int(talk_of(townsfolk_id).get("familiar_after", 0)) == _visit_number(state) and not state.get("familiar_told", false):
		line = _for_moment(townsfolk_id, chef_id, lines, "familiar_moment", words, GameData.get_townsfolk(townsfolk_id).get("favorite_dish", ""))
		state["familiar_told"] = not line.is_empty()
	if line.is_empty() and back:
		line = _for_moment(townsfolk_id, chef_id, lines, "back_gift", words, last_dish)
	if line.is_empty() and back:
		line = _for_moment(townsfolk_id, chef_id, lines, "back", words, last_dish)
	if line.is_empty():
		var compliment := outfit_line(townsfolk_id, chef_id)
		if not compliment.is_empty():
			return compliment
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
	var grudging := pool.filter(func(talk_line): return talk_line.get("only", "") == "grudge")
	if not grudging.is_empty():
		return grudging.pick_random()  # Every time, till you say sorry.
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
			if not has_grudge(townsfolk_id, chef_id):
				return false  # Seth's apology: only with his grudge.
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
	TownsfolkFriends.heard(townsfolk_id, chef_id, String(choice.get("tone", "")), fill(String(choice.get("text", "")), context(townsfolk_id, chef_id)))
	if choice.get("grudge", false) and not has_grudge(townsfolk_id, chef_id):
		state.get_or_add("grudge", {})[chef_id] = fill(String(choice.get("text", "")), context(townsfolk_id, chef_id))
	if choice.get("apology", false):
		state.get("grudge", {}).erase(chef_id)
	var emotion: StringName = &"sad" if mood < 0.0 else (&"happy" if mood > 0.0 else &"")
	if choice.get("crash_out", false):
		var lines: Array = talk.get("crash_out", [])
		reply = String(lines.pick_random()) if not lines.is_empty() else ""
		state.get_or_add("cold", {})[chef_id] = GameState.day_number
		emotion = &"angry"
	return { "reply": reply, "mood": mood, "emotion": emotion, "laugh_chain": result.get("laugh_chain", choice.get("laugh_chain", false)) }


# What they say when the food lands, by how it came out (perfect, great, okay or
# burnt). "" if they have nothing to say about this dish.
static func served(townsfolk_id: String, chef_id: String, tier: String, dish: Dictionary) -> String:
	var talk := talk_of(townsfolk_id)
	if is_cold(townsfolk_id, chef_id):
		return _cold_line(townsfolk_id)
	var line: Dictionary = talk.get("served", {}).get(tier, {})
	var text: String = _grudging(townsfolk_id, chef_id, line.get("text", ""))
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
	if is_cold(townsfolk_id, chef_id):
		return { "text": _cold_line(townsfolk_id) }
	var state := _state(townsfolk_id)
	if state.has("asked_after"):  # Hezzy, straight after an outburst.
		var asked: String = state["asked_after"]
		state.erase("asked_after")
		return { "text": asked }
	var now := _now_and_then(townsfolk_id, chef_id, "eating", words, dish_id)
	if not now.is_empty():
		return now
	var hunch := TownsfolkSpecials.intuition(townsfolk_id, chef_id, words)
	if not hunch.is_empty():
		return hunch
	if randf() < _chance("eating_choice_chance", 0.35):
		var chats: Array = talk.get("eating_chat", []).filter(func(line):
			return (dish_id == favorite or not line.get("fav", false)) and _can_converse(townsfolk_id, chef_id, line, words))
		var chat := _pick_unheard(townsfolk_id, chats)
		if not chat.is_empty():
			return chat
	var season: String = talk.get("seasons", {}).get(GameClock.season(), "")
	if randf() < _chance("season_line_chance", 0.25) and _usable(season, words):
		return { "text": season }
	var compliment := outfit_line(townsfolk_id, chef_id)
	if not compliment.is_empty():
		return { "text": compliment }
	if randf() < _chance("friend_line_chance", 0.3):
		var about := TownsfolkFriends.mention(townsfolk_id, chef_id)
		if not about.is_empty():
			return about
	return _pick_unheard(townsfolk_id, _pool(townsfolk_id, chef_id, talk.get("eating", []), words, dish_id))


# Goodbye. The last visit before they go away has its own line.
static func leaving(townsfolk_id: String, chef_id: String, dish: Dictionary) -> String:
	var state := _state(townsfolk_id)
	var lines: Array = talk_of(townsfolk_id).get("leaving", [])
	var words := context(townsfolk_id, chef_id, dish)
	var dish_id: String = dish.get("id", "")
	var line := {}
	if is_cold(townsfolk_id, chef_id):
		return _cold_line(townsfolk_id)
	if has_grudge(townsfolk_id, chef_id):
		line = _for_moment(townsfolk_id, chef_id, lines, "grudge", words, dish_id)
	if line.is_empty():
		line = _now_and_then(townsfolk_id, chef_id, "leaving", words, dish_id)
	if line.is_empty():
		line = TownsfolkSpecials.leaving(townsfolk_id, chef_id, words)
	var until := int(state.get("until", 0))
	if line.is_empty() and until > 0 and until <= GameState.day_number + 1:
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
