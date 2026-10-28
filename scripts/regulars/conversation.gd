# Conversation: the rules of talking with a regular, with no UI. A line from a
# character file can have "choices" (the player's replies, each tagged with a
# tone) or, for "pick_for_me" lines ("What do you recommend?" / "Surprise me"),
# "reactions" to the dish the player picks. This works out what each choice
# does: the relationship change (the line's own number, else the character's
# tone table), the reply, the rude streak and last rude line, memory flags it
# sets, any dish it orders, and what it does to other regulars ("others", e.g.
# apologizing to Mabel about Stitches also gives Stitches +3). CustomerManager
# runs the flow; ConversationBox shows it.
class_name Conversation
extends RefCounted

# The line's choices in button order: as written, except rude always goes last
# so it's never picked by accident.
static func choices_of(line: Dictionary) -> Array:
	var kind: Array = []
	var rude: Array = []
	for choice in line.get("choices", []):
		(rude if choice.get("tone", "") == "rude" else kind).append(choice)
	return kind + rude


# Apply the reply chef `chef_id` chose (its text already filled in). Returns
# { change, reply, others } where reply is the unfilled text they answer with
# and others is { regular_id: change } for anyone else it affected. A reply with
# "nickname" gives that chef a nickname ("" = just their name). A rude reply is
# news for their friends.
static func apply_choice(record: Dictionary, choice: Dictionary, said: String, chef_id := "") -> Dictionary:
	var tone: String = choice.get("tone", "")
	var change := _change_of(record, choice, tone)
	# Count the streak first, so the third rude reply in a row can go below 0.
	if tone == "rude":
		record["rude_streak"] = int(record["rude_streak"]) + 1
		record["last_rude_line"] = said
	else:
		record["rude_streak"] = 0
	RegularMemory.change_relationship(record, change)
	if tone == "rude":
		Gossip.queue(record, "rude", said)
	var others := {}
	var other_changes: Dictionary = choice.get("others", {})
	for other_id in other_changes:
		if GameState.regulars.has(other_id):
			RegularMemory.change_relationship(GameState.regulars[other_id], int(other_changes[other_id]))
			others[other_id] = int(other_changes[other_id])
	_set_flags(record, choice)
	if choice.has("nickname") and not chef_id.is_empty():
		var nicknames: Dictionary = record.get_or_add("nicknames", {})
		if String(choice["nickname"]).is_empty():
			nicknames.erase(chef_id)
		else:
			nicknames[chef_id] = choice["nickname"]
	# A playful reply can miss (e.g. Stitches at Nervous: +1 or -1).
	var reply: String = choice.get("reply", "")
	if change < 0 and choice.has("miss_reply"):
		reply = choice["miss_reply"]
	return { "change": change, "reply": reply, "others": others }


# What they say when the player picks `dish` for them, and apply its change.
# Returns { change, reply }.
static func apply_dish_pick(record: Dictionary, line: Dictionary, dish: Dictionary, context: Dictionary) -> Dictionary:
	var kind := "other"
	if dish.get("id", "") == record["favorite_dish"]:
		kind = "favorite"
	elif dish.get("id", "") == record["disliked_dish"]:
		kind = "disliked"
	var reactions: Dictionary = line.get("reactions", {})
	var reaction := _first_matching(reactions.get(kind, []), context)
	if reaction.is_empty():
		reaction = _first_matching(reactions.get("other", []), context)
	var change := int(reaction.get("change", 0))
	RegularMemory.change_relationship(record, change)
	_set_flags(record, reaction)
	return { "change": change, "reply": reaction.get("text", "") }


# The dish a line or choice orders ("dish": a dish id, a token like "soup", or
# "favorite"), or {} if it doesn't order one.
static func dish_of(entry: Dictionary, record: Dictionary) -> Dictionary:
	var value: String = entry.get("dish", "")
	if value.is_empty():
		return {}
	if value == "favorite":
		value = record["favorite_dish"]
	value = GameData.regular_settings.get("dish_tokens", {}).get(value, value)
	return GameData.get_dish(value)


static func _change_of(record: Dictionary, choice: Dictionary, tone: String) -> int:
	if not choice.has("change"):
		return RegularMemory.tone_change(record, tone)
	var value = choice["change"]
	if value is Array:
		return int(value.pick_random()) if not value.is_empty() else 0
	return int(value)


# What a line itself does once said, whatever the reply: memory flags it sets
# ("set") and whether they learn the chef's name ("learns_name"). Returns true
# if they learned it just now. (A line's "befriends" is handled by Gossip.)
static func apply_line(record: Dictionary, line: Dictionary, chef_id: String) -> bool:
	_set_flags(record, line)
	return line.get("learns_name", false) and RegularMemory.learn_name(record, chef_id)


static func _set_flags(record: Dictionary, entry: Dictionary) -> void:
	var flags: Dictionary = entry.get("set", {})
	for key in flags:
		record[key] = flags[key]


static func _first_matching(options: Array, context: Dictionary) -> Dictionary:
	for option in options:
		if DialoguePicker.conditions_met(option.get("conditions", {}), context):
			return option
	return {}
