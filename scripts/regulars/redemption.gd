# Redemption: the rules for Gone regulars (stage -4) and winning them back.
# A regular who falls to Gone phones in one last delivery order, and its courier
# hands over their goodbye note instead of a payment slip. From then on they're
# Gone (goodbye_given): they never call or visit, and everyone else hears about it.
# There are two ways back, and both end in their return scene at closing time:
#   - A letter, written at the order counter. Each part's tone has to be one of
#     the tones their file's gone.letter.needs lists for that part. Only a
#     sincere letter gets an answer: a courier brings their reply
#     letter_reply_days later, and they come in at closing that day.
#   - A friend: a regular who is friends with them and likes you enough
#     (friend_min_relationship), asked during a visit or by phone. If that
#     friend has a "help" line about them in data/gossip.json, they agree, and
#     the Gone regular comes in at closing friend_return_days later.
# They come back at relationship 0 with their rude streak cleared. Each goodbye
# counts in times_gone; once it reaches permanent_after, they're gone for good.
# Settings: "gone" in data/regulars.json. Rules only: CustomerManager,
# DeliveryManager and Phone run the scenes.
class_name Redemption
extends RefCounted


static func settings() -> Dictionary:
	return GameData.regular_settings.get("gone", {})


# One of the "lines" in the settings (narration and menus), with [tokens] like
# [who], [friend] and [courier] filled in from `values`.
static func text(key: String, values := {}) -> String:
	var all := { "courier": GameData.phone_settings.get("courier", {}).get("name", "The courier") }
	all.merge(values, true)
	return DialoguePicker.fill(settings().get("lines", {}).get(key, key), all)


# Gone: they've left their goodbye note.
static func is_gone(record: Dictionary) -> bool:
	return record.get("goodbye_given", false)


# Fallen to Gone, but their last order (with the goodbye note) hasn't come yet.
static func goodbye_due(record: Dictionary) -> bool:
	return RegularMemory.stage_of(record) <= -4 and not is_gone(record)


static func is_permanent(record: Dictionary) -> bool:
	return int(record.get("times_gone", 0)) >= int(settings().get("permanent_after", 2))


# Gone, not for good, and not already on their way back.
static func can_win_back(record: Dictionary) -> bool:
	return is_gone(record) and not is_permanent(record) and String(record.get("returns_on", "")).is_empty()


# Their last order is being handed over: the goodbye. Everyone hears they're gone.
static func say_goodbye(record: Dictionary) -> void:
	record["goodbye_given"] = true
	record["times_gone"] = int(record.get("times_gone", 0)) + 1
	_clear_letter(record)
	record["returns_on"] = ""
	Gossip.tell_everyone(record, "gone")


static func goodbye_note(record: Dictionary) -> String:
	return _gone_data(record).get("goodbye_note", "")


# --- The letter --------------------------------------------------------------

# Gone regulars you could write to right now (none already has a letter on the way).
static func letter_targets() -> Array:
	return GameState.regulars.values().filter(func(r): return can_win_back(r) and String(r["letter_date"]).is_empty() and not letter_of(r).is_empty())


# Their file's letter: { needs: [[tones]...], reply, parts: [{ prompt, choices: [{ tone, text }] }] }.
static func letter_of(record: Dictionary) -> Dictionary:
	return _gone_data(record).get("letter", {})


# The letter is sent with these tones, one per part. Returns true if it's sincere.
static func send_letter(record: Dictionary, tones: Array) -> bool:
	var needs: Array = letter_of(record).get("needs", [])
	var sincere := tones.size() == needs.size()
	for i in mini(tones.size(), needs.size()):
		if not tones[i] in needs[i]:
			sincere = false
	record["letter_date"] = GameState.date
	record["letter_sincere"] = sincere
	record["reply_given"] = false
	return sincere


# Gone regulars whose letter has been with them long enough for an answer
# (sincere or not: see reply_arrived and no_reply).
static func letters_due() -> Array:
	var wait := int(settings().get("letter_reply_days", 3))
	return GameState.regulars.values().filter(func(r):
		return can_win_back(r) and not String(r["letter_date"]).is_empty() and not r["reply_given"] \
			and days_between(r["letter_date"], GameState.date) >= wait)


static func reply_text(record: Dictionary) -> String:
	return letter_of(record).get("reply", "")


# Their reply was read: they come in at closing today.
static func reply_arrived(record: Dictionary) -> void:
	record["reply_given"] = true
	record["returns_on"] = GameState.date


# An insincere letter: no answer ever comes, and you can write another.
static func no_reply(record: Dictionary) -> void:
	_clear_letter(record)


# --- Asking a friend ---------------------------------------------------------

# Who `friend` could talk to for you right now: ids of their Gone friends. Only
# if the friend isn't Gone themselves, likes you enough, and has a "help" line
# about them (chef `chef_id` asking).
static func friend_can_help(friend: Dictionary, chef_id: String) -> Array:
	if is_gone(friend) or int(friend["relationship"]) < int(settings().get("friend_min_relationship", 50)):
		return []
	var result := []
	for gone_id in friend.get("friends", []):
		var gone: Dictionary = GameState.regulars.get(gone_id, {})
		if not gone.is_empty() and can_win_back(gone) and not DialoguePicker.pick_line("gossip", help_context(friend, gone_id, chef_id)).is_empty():
			result.append(gone_id)
	return result


# Every friend who could help, for the phone: [{ friend, gone }] (ids).
static func all_helpers(chef_id: String) -> Array:
	var result := []
	for friend_id in GameState.regulars:
		for gone_id in friend_can_help(GameState.regulars[friend_id], chef_id):
			result.append({ "friend": friend_id, "gone": gone_id })
	return result


# What the friend's "help" line (in data/gossip.json) is picked with.
static func help_context(friend: Dictionary, gone_id: String, chef_id: String) -> Dictionary:
	return RegularMemory.dialogue_context(friend, chef_id, { "gossip_about": gone_id, "gossip_kind": "help" })


# What the chef asks a friend about this Gone regular (their file's gone.ask_friend).
static func ask_friend_text(gone: Dictionary) -> String:
	return _gone_data(gone).get("ask_friend", "Could you talk to %s for me?" % gone["name"])


# The friend agreed: the Gone regular comes in at closing friend_return_days from now.
static func friend_agreed(gone: Dictionary) -> void:
	gone["returns_on"] = add_days(GameState.date, int(settings().get("friend_return_days", 1)))


# --- Coming back -------------------------------------------------------------

# Gone regulars who come in at closing today.
static func returning_today() -> Array:
	return GameState.regulars.values().filter(func(r):
		return is_gone(r) and not String(r["returns_on"]).is_empty() and r["returns_on"] <= GameState.date)


# Their return scene is over: back at 0, a clean slate on rudeness. times_gone
# stays, so the next fall can be the permanent one.
static func welcome_back(record: Dictionary) -> void:
	RegularMemory.set_relationship(record, 0)
	record["rude_streak"] = 0
	record["goodbye_given"] = false
	record["returns_on"] = ""
	record["last_note"] = ""
	_clear_letter(record)
	record["last_seen"] = GameClock.now_string()  # They came in today.


# --- Dates -------------------------------------------------------------------

# Whole days from date `a` to date `b` ("2026-10-28" style).
static func days_between(a: String, b: String) -> int:
	return floori((Time.get_unix_time_from_datetime_string(b) - Time.get_unix_time_from_datetime_string(a)) / float(RegularMemory.SECONDS_PER_DAY))


static func add_days(date: String, days: int) -> String:
	return Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(date) + days * RegularMemory.SECONDS_PER_DAY)


static func _clear_letter(record: Dictionary) -> void:
	record["letter_date"] = ""
	record["letter_sincere"] = false
	record["reply_given"] = false


static func _gone_data(record: Dictionary) -> Dictionary:
	return GameData.characters.get(record.get("id", ""), {}).get("gone", {})
