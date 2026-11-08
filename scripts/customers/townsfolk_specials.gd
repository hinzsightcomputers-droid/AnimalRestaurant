# TownsfolkSpecials: each semi-regular's own feature, from keys in their talk
# block (see TownsfolkTalk, which calls in here at each moment of a visit):
#   books          Penny's [book]: a title from the list, a new one every 7 real
#                  days. When one's done she sometimes gives it to you
#                  (book_finished, gift penny_book).
#   trips          Miles' [trip]: picked when he leaves town. Coming back, a
#                  "back_gift" line gives you a photo (its "gift").
#   stories        Yaniv's [story]: { title, parts: [recap of each part] }. He
#                  tells a part each visit ([story] recaps the last one told),
#                  then a new story; his "story_part" goodbye sometimes says so.
#   leaves_gift    Clover: a decor id per visit, in turn, left on her table.
#   decor_changed  Jessie: an arrival moment for when the decor's different
#                  from her last visit (lines say which, see TownsfolkTalk._true_now).
#   car            Cody's car: { every, levels: [line] }. Up a level every
#                  `every` visits; the next visit he tells you about it.
#   knitting       Hazel: { every, gifts: [{ text, gift }] }. A finished piece
#                  every `every` visits, given to you.
#   mural          Luna: { before, after, gifts: { season: decor id } }. Each new
#                  season she says `before` leaving, then paints it that night
#                  (it's in your decor storage) and asks about it next time.
#   finally        Violet: said once her favorite can be had at last (with
#                  "same_fallback": true she has the same thing till then).
#   intuition      Seth: { after_served, lines }. Once a chef has served him that
#                  often (no grudge), one line a visit about how things are:
#                  the first whose "rough_yesterday", "low_regular", "streak" or
#                  "new_star" is true, else the one with none.
#   new_seat       Iddy: said sitting somewhere different from last time.
#   passing        Iddy: { chance, text, rough }: some visits, said once as a
#                  chef walks past his table (rough after a bad day).
#   oops           Makayla: said, eyes covered, when a burnt dish lands near her.
#   critic         Odette: { arrival, passed, not_yet, five_stars } for her
#                  critic visits (see Rating).
# Any line with "gift": a decor id gives it to you when said (see give).
class_name TownsfolkSpecials
extends RefCounted

const WEEK := 7 * 86400


static func _talk(townsfolk_id: String) -> Dictionary:
	return TownsfolkTalk.talk_of(townsfolk_id)


static func _state(townsfolk_id: String) -> Dictionary:
	return TownsfolkTalk._state(townsfolk_id)


# [book], [story] and [trip] for their lines.
static func add_words(townsfolk_id: String, words: Dictionary) -> void:
	var talk := _talk(townsfolk_id)
	var state := _state(townsfolk_id)
	var books: Array = talk.get("books", [])
	if not books.is_empty():
		words["book"] = books[_book_index(books)]
	var trips: Array = talk.get("trips", [])
	if not trips.is_empty():
		if String(state.get("trip", "")).is_empty():
			state["trip"] = trips.pick_random()
		words["trip"] = state["trip"]
	var stories: Array = talk.get("stories", [])
	var story: Dictionary = state.get("story", {})
	if not stories.is_empty() and int(story.get("part", 0)) > 0:
		var parts: Array = stories[int(story.get("n", 0)) % stories.size()]["parts"]
		words["story"] = parts[mini(int(story["part"]), parts.size()) - 1]


static func _book_index(books: Array) -> int:
	return int(GameClock.now_unix() / WEEK) % books.size()


# Something of theirs that comes first when they walk in, or "".
static func arrival(townsfolk_id: String, chef_id: String, words: Dictionary) -> String:
	var talk := _talk(townsfolk_id)
	var state := _state(townsfolk_id)
	state["star_news"] = GameState.stars > int(state.get("stars_seen", GameState.stars))
	state["stars_seen"] = GameState.stars
	var decor_now := str(GameState.decor_placed.map(func(p): return p.get("id", ""))).hash()
	var decor_was := int(state.get("decor_seen", decor_now))
	state["decor_seen"] = decor_now
	if decor_was != decor_now:
		var comment := TownsfolkTalk._for_moment(townsfolk_id, chef_id, talk.get("arrival", []), "decor_changed", words, "")
		if not comment.is_empty():
			return TownsfolkTalk.fill(comment["text"], words)
	if state.get("finally", false):
		state.erase("finally")
		if talk.has("finally"):
			return TownsfolkTalk.fill(talk["finally"], words)
	var mural: Dictionary = talk.get("mural", {})
	if not mural.is_empty() and state.has("mural_painting") and int(state.get("mural_day", 0)) < GameState.day_number:
		var season: String = state["mural_painting"]
		state.erase("mural_painting")
		state["mural_season"] = season
		var gift: String = mural.get("gifts", {}).get(season, "")
		if not gift.is_empty():
			state["gift"] = gift
		return TownsfolkTalk.fill(String(mural.get("after", "")), words)
	var car: Dictionary = talk.get("car", {})
	if not car.is_empty():
		var levels: Array = car.get("levels", [])
		var level := mini(1 + int(state.get("visits", 0)) / int(car.get("every", 5)), levels.size())
		if level > int(state.get("car_told", 0)):
			state["car_told"] = level
			return TownsfolkTalk.fill(levels[level - 1], words)
	var books: Array = talk.get("books", [])
	if not books.is_empty():
		var now := _book_index(books)
		var was := int(state.get("book_index", now))
		state["book_index"] = now
		if was != now and randf() < float(talk.get("book_gift_chance", 0.5)):
			state["gift"] = talk.get("book_gift", "")
			var finished := words.duplicate()
			finished["book"] = books[was % books.size()]
			return TownsfolkTalk.fill(String(talk.get("book_finished", "")), finished)
	var knitting: Dictionary = talk.get("knitting", {})
	if not knitting.is_empty():
		state["knitting"] = int(state.get("knitting", 0)) + 1
		if int(state["knitting"]) >= int(knitting.get("every", 8)):
			state["knitting"] = 0
			var gifts: Array = knitting.get("gifts", [])
			if not gifts.is_empty():
				var piece: Dictionary = gifts[int(state.get("knitted", 0)) % gifts.size()]
				state["knitted"] = int(state.get("knitted", 0)) + 1
				state["gift"] = piece.get("gift", "")
				return TownsfolkTalk.fill(piece["text"], words)
	return ""


# Seth's one read of the room this visit, or {}.
static func intuition(townsfolk_id: String, chef_id: String, words: Dictionary) -> Dictionary:
	var hunches: Dictionary = _talk(townsfolk_id).get("intuition", {})
	var state := _state(townsfolk_id)
	if hunches.is_empty() or int(state.get("intuition_day", -1)) == GameState.day_number:
		return {}
	if int(state.get("served", {}).get(chef_id, 0)) < int(hunches.get("after_served", 3)) or TownsfolkTalk.has_grudge(townsfolk_id, chef_id):
		return {}
	var low := TownsfolkTalk.lowest_regular()
	var low_now := not low.is_empty() and RegularMemory.stage_of(low) < 0
	for line in hunches.get("lines", []):
		var ok := true
		if line.has("rough_yesterday"):
			ok = TownsfolkTalk.rough_yesterday()
		elif line.has("low_regular"):
			ok = low_now
		elif line.has("streak"):
			ok = ServiceStreak.count >= int(line["streak"])
		elif line.has("new_star"):
			ok = state.get("star_news", false)
		if ok:
			state["intuition_day"] = GameState.day_number
			var filled := words.duplicate()
			if low_now:
				filled["regular"] = low["name"]
			return { "text": TownsfolkTalk.fill(line["text"], filled) }
	return {}


# Something of theirs for goodbye, or {}. (Miles picks his next trip here, so
# his leaving-town line can name it.)
static func leaving(townsfolk_id: String, chef_id: String, words: Dictionary) -> Dictionary:
	var talk := _talk(townsfolk_id)
	var state := _state(townsfolk_id)
	var until := int(state.get("until", 0))
	var trips: Array = talk.get("trips", [])
	if not trips.is_empty() and until > 0 and until <= GameState.day_number + 1 and state.get("trip_picked", -1) != until:
		var others := trips.filter(func(t): return t != state.get("trip", ""))
		state["trip"] = others.pick_random() if not others.is_empty() else trips.pick_random()
		state["trip_picked"] = until
		words["trip"] = state["trip"]
	var stories: Array = talk.get("stories", [])
	if not stories.is_empty():
		var story: Dictionary = state.get_or_add("story", { "n": 0, "part": 0 })
		if int(story["part"]) >= Array(stories[int(story["n"]) % stories.size()]["parts"]).size():
			story["n"] = int(story["n"]) + 1  # That one's over: a new one.
			story["part"] = 0
		story["part"] = int(story["part"]) + 1  # Told today.
		if randf() < float(talk.get("story_part_chance", 0.5)):
			for line in talk.get("leaving", []):
				if line.get("when", "") == "story_part":
					return line
	var drawings: Array = talk.get("leaves_gift", [])
	if not drawings.is_empty():
		state["gift"] = drawings[int(state.get("left_gifts", 0)) % drawings.size()]
		state["left_gifts"] = int(state.get("left_gifts", 0)) + 1
	var mural: Dictionary = talk.get("mural", {})
	if not mural.is_empty() and state.get("mural_season", "") != GameClock.season() and not state.has("mural_painting"):
		if state.has("mural_season") or int(state.get("visits", 0)) > 0:
			state["mural_painting"] = GameClock.season()
			state["mural_day"] = GameState.day_number
			return { "text": mural.get("before", "") }
		state["mural_season"] = GameClock.season()  # Already up when you first meet her.
	return {}


# Iddy sat down at `spot`: his line if it's somewhere new, else "".
static func new_seat(townsfolk_id: String, spot: String) -> String:
	var lines: Array = _talk(townsfolk_id).get("new_seat", [])
	var state := _state(townsfolk_id)
	var last: String = state.get("last_table", "")
	state["last_table"] = spot
	if lines.is_empty() or last.is_empty() or last == spot:
		return ""
	return String(lines.pick_random())


# A chef walked past their table: Iddy's "You good?" some visits, else "".
static func passing(townsfolk_id: String) -> String:
	var passing: Dictionary = _talk(townsfolk_id).get("passing", {})
	if passing.is_empty() or randf() >= float(passing.get("chance", 0.5)):
		return ""
	return String(passing.get("rough", passing["text"]) if TownsfolkTalk.rough_yesterday() else passing.get("text", ""))


# A gift from what they just said (once), or "".
static func take_gift(townsfolk_id: String) -> String:
	var state := _state(townsfolk_id)
	var gift: String = state.get("gift", "")
	state.erase("gift")
	return gift


# `decor_id` goes into your decor storage, with the news.
static func give(townsfolk_id: String, decor_id: String) -> void:
	var item := Decor.get_item(decor_id)
	if item.is_empty():
		push_warning("No decor item %s for %s's gift" % [decor_id, townsfolk_id])
		return
	GameState.decor_stored[decor_id] = int(GameState.decor_stored.get(decor_id, 0)) + 1
	GameEvents.announce("%s gave you %s! It's in your decor storage." % [GameData.get_townsfolk(townsfolk_id).get("name", "?"), item.get("name", decor_id)])
