# Gossip: regulars talk to their friends about you. Friendships are mutual
# entries in each regular's `friends` list (some start that way in their
# character files; others form when a line with "befriends" is said). When you
# cross a stage boundary with someone, or pick a rude reply with them, each of
# their friends gets a piece of gossip in `pending_gossip`:
# { about, kind: "kind" | "rude", quote } where quote is the exact rude line.
# The friend brings it up once, on their next visit (lines in data/gossip.json).
# Rules only; CustomerManager runs the conversation.
class_name Gossip
extends RefCounted


static func are_friends(a_id: String, b_id: String) -> bool:
	return b_id in GameState.regulars.get(a_id, {}).get("friends", [])


# Make two regulars friends (both ways). Returns true if they weren't already.
static func befriend(a_id: String, b_id: String) -> bool:
	if a_id == b_id or not GameState.regulars.has(a_id) or not GameState.regulars.has(b_id) or are_friends(a_id, b_id):
		return false
	GameState.regulars[a_id]["friends"].append(b_id)
	GameState.regulars[b_id]["friends"].append(a_id)
	return true


# Tell each of `record`'s friends something about them: "kind" or "rude" (with
# the line to quote). Each friend keeps only the latest news about each regular.
static func queue(record: Dictionary, kind: String, quote := "") -> void:
	for friend_id in record.get("friends", []):
		var friend: Dictionary = GameState.regulars.get(friend_id, {})
		if friend.is_empty():
			continue
		var pending: Array = friend["pending_gossip"]
		for i in range(pending.size() - 1, -1, -1):
			if pending[i].get("about", "") == record["id"]:
				pending.remove_at(i)
		pending.append({ "about": record["id"], "kind": kind, "quote": quote })


# Their stage changed: up is good news, down is bad (quoting the rude line
# behind it, if a rude streak is what did it).
static func on_stage_change(record: Dictionary, before: int, after: int) -> void:
	if after > before:
		queue(record, "kind")
	elif after < before:
		queue(record, "rude", record.get("last_rude_line", "") if int(record.get("rude_streak", 0)) > 0 else "")


# The oldest gossip `record` has to tell, removed from their list (it's only
# ever brought up once), or {} if none.
static func take_next(record: Dictionary) -> Dictionary:
	var pending: Array = record.get("pending_gossip", [])
	while not pending.is_empty():
		var item: Dictionary = pending.pop_front()
		if GameState.regulars.has(item.get("about", "")):
			return item
	return {}


# What a gossip line can check or quote ([last_rude_line] is the quote).
static func context(item: Dictionary) -> Dictionary:
	var quote: String = item.get("quote", "")
	return {
		"gossip_about": item.get("about", ""),
		"gossip_kind": item.get("kind", ""),
		"last_rude_line": quote,
		"has_rude_line": not quote.is_empty(),
	}
