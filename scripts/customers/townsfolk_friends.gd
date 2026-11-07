# TownsfolkFriends: the "friends" lines in a semi-regular's talk block (see
# TownsfolkTalk): duos with a friend who's in at the same time, mentions of a
# friend you've met, and gossip about how you treated a friend.
#
# Each entry is one of:
#   { "with": id, "beats": [...] }  a duo, when that friend is in too. A beat is
#       { "who": id, "text" } said by one of them, or { "narration" }. With
#       "first": true it's the first time they're ever in together, and their
#       other duos wait for it.
#   { "about": id, "text" }  a mention, once this chef has met that friend (a
#       semi-regular they've served, or a regular who's told them their name).
#   { "kind": id, "text" } / { "rude": id, "text" }  gossip: said the next time
#       they see a chef who picked a warm (or rude) reply with that friend.
#       [last_rude_line] is what the chef said.
# "later" parks an entry, like any line.
#
# Pairs ("pairs" in their file) sometimes walk in together: see pair_for.
#
# What this adds to GameState.townsfolk: gossip ({ chef: { friend, tone, line } }),
# friends_met (friends they've had their first time in with) and duo_day.
class_name TownsfolkFriends
extends RefCounted


static func _entries(townsfolk_id: String) -> Array:
	return TownsfolkTalk.talk_of(townsfolk_id).get("friends", []).filter(func(e): return not e.has("later"))


# --- Gossip ---------------------------------------------------------------------

# A chef picked a reply in `tone` with `friend_id` (a semi-regular or a regular):
# anyone with gossip for that will pass it on next time they see that chef.
static func heard(friend_id: String, chef_id: String, tone: String, said: String) -> void:
	var kind: String = { "warm": "kind", "rude": "rude" }.get(tone, "")
	if kind.is_empty():
		return
	for person in GameData.townsfolk:
		if person["id"] == friend_id:
			continue
		if _entries(person["id"]).any(func(e): return e.get(kind, "") == friend_id):
			var gossip: Dictionary = TownsfolkTalk._state(person["id"]).get_or_add("gossip", {})
			gossip[chef_id] = { "friend": friend_id, "tone": kind, "line": said }


# Their gossip for this chef, said once, or "".
static func gossip_line(townsfolk_id: String, chef_id: String) -> String:
	var gossip: Dictionary = TownsfolkTalk._state(townsfolk_id).get("gossip", {})
	if not gossip.has(chef_id):
		return ""
	var news: Dictionary = gossip[chef_id]
	gossip.erase(chef_id)
	var words := TownsfolkTalk.context(townsfolk_id, chef_id)
	words["last_rude_line"] = news.get("line", "")
	for entry in _entries(townsfolk_id):
		if entry.get(news["tone"], "") == news["friend"] and TownsfolkTalk._usable(entry["text"], words):
			var said := TownsfolkTalk.fill(entry["text"], words)
			return RegEx.create_from_string("([.!?])\"\\.").sub(said, "$1\"", true)  # "Go away." not "Go away.".
	return ""


# --- Mentions -------------------------------------------------------------------

static func has_met(chef_id: String, friend_id: String) -> bool:
	if GameState.regulars.has(friend_id):
		return bool(GameState.regulars[friend_id].get("introduced", false))
	return chef_id in GameState.townsfolk.get(friend_id, {}).get("met", [])


# A mention of a friend this chef has met, one they haven't heard yet if they
# can. {} for none.
static func mention(townsfolk_id: String, chef_id: String) -> Dictionary:
	var words := TownsfolkTalk.context(townsfolk_id, chef_id)
	var pool := _entries(townsfolk_id).filter(func(e):
		return e.has("about") and has_met(chef_id, e["about"]) and TownsfolkTalk._usable(e["text"], words))
	return TownsfolkTalk._pick_unheard(townsfolk_id, pool)


# --- Duos -----------------------------------------------------------------------

# The friends they have duos with.
static func duo_friends(townsfolk_id: String) -> Array:
	var ids := []
	for entry in _entries(townsfolk_id):
		if entry.has("with") and not entry["with"] in ids:
			ids.append(entry["with"])
	return ids


static func _first_of(a: String, b: String) -> Dictionary:
	for pair in [[a, b], [b, a]]:
		for entry in _entries(pair[0]):
			if entry.get("with", "") == pair[1] and entry.get("first", false):
				return entry
	return {}


# A duo with whichever of `present` (friends in right now) they can have one
# with, or {}: { friend, beats }. One a day; the first time in together comes
# first. Saying it is up to the caller: see duo_said.
static func duo(townsfolk_id: String, present: Array) -> Dictionary:
	var state := TownsfolkTalk._state(townsfolk_id)
	if int(state.get("duo_day", -1)) == GameState.day_number:
		return {}
	for friend_id in present:
		if int(TownsfolkTalk._state(friend_id).get("duo_day", -1)) == GameState.day_number:
			continue
		var first := _first_of(townsfolk_id, friend_id)
		if not first.is_empty() and not friend_id in state.get("friends_met", []):
			return { "friend": friend_id, "beats": first["beats"], "first": true }
		var pool := _entries(townsfolk_id).filter(func(e):
			return e.get("with", "") == friend_id and not e.get("first", false))
		var picked := TownsfolkTalk._pick_unheard(townsfolk_id, pool)
		if not picked.is_empty():
			return { "friend": friend_id, "beats": picked["beats"] }
	return {}


# They had `duo`: neither has another today, and they've met now.
static func duo_said(townsfolk_id: String, duo_line: Dictionary) -> void:
	var friend_id: String = duo_line["friend"]
	for pair in [[townsfolk_id, friend_id], [friend_id, townsfolk_id]]:
		var state := TownsfolkTalk._state(pair[0])
		state["duo_day"] = GameState.day_number
		var met: Array = state.get_or_add("friends_met", [])
		if not pair[1] in met:
			met.append(pair[1])


# --- Walking in together --------------------------------------------------------

# Someone from their "pairs" who walks in right behind them (pair_chance of the
# time): in town and not in yet today. {} for nobody. They count as in today.
static func pair_for(townsfolk_id: String) -> Dictionary:
	if randf() >= float(Townsfolk.settings().get("pair_chance", 0.35)):
		return {}
	var free := []
	for friend_id in GameData.get_townsfolk(townsfolk_id).get("pairs", []):
		var state: Dictionary = GameState.townsfolk.get(friend_id, {})
		if state.get("in_town", false) and int(state.get("last_visit", 0)) != GameState.day_number:
			free.append(friend_id)
	if free.is_empty():
		return {}
	var friend_id: String = free.pick_random()
	GameState.townsfolk[friend_id]["last_visit"] = GameState.day_number
	return GameData.get_townsfolk(friend_id)
