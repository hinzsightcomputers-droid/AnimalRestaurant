# PhoneCalls: the rules of phone calls, with no UI. Picks who rings next and
# builds what they say. A call is { kind, id }:
#   "townsfolk": a caller from data/callers.json ordering their usual (mostly).
#   "order":     a Withdrawn regular ordering instead of visiting, with a note
#                choice at the end (the redemption hook, from their file's
#                phone_greeting / phone_order / phone_note lines). Someone who
#                just fell to Gone makes one last order call like this, with no
#                note: its courier brings their goodbye (see Redemption).
#   "chat":      a regular at their top stage calling just to talk (phone_chat).
# All timings and chances are in data/phone.json. Phone runs the call and
# shows it; DeliveryManager handles the order it makes.
class_name PhoneCalls
extends RefCounted


# Who rings next (Withdrawn regulars first, sometimes a friend just to chat,
# otherwise someone from town), or {} if nobody. Skips anyone already waiting
# in voicemail, and `last_id` so the same townsfolk don't call twice in a row.
# Regulars mostly call at `night` (in the day their chance is scaled by
# regular_day_call_factor); townsfolk marked night_only only call at night,
# and are likelier then (night_only_weight).
static func next_call(last_id := "", night := false) -> Dictionary:
	var settings := GameData.phone_settings
	var waiting := GameState.voicemails.map(func(v): return v["id"])
	var factor: float = 1.0 if night else settings.get("regular_day_call_factor", 0.25)
	for kind in ["order", "chat"]:
		var chance: float = settings.get("regular_%s_call_chance" % kind, 0.0) * factor
		var ids := GameState.regulars.keys().filter(func(id): return _calls_today(id, kind) and not id in waiting)
		if not ids.is_empty() and randf() < chance:
			return { "kind": kind, "id": ids.pick_random() }
	var awake := GameData.callers.filter(func(c): return night or not c.get("night_only", false))
	var townsfolk := awake.filter(func(c): return c["id"] != last_id and not c["id"] in waiting)
	if townsfolk.is_empty():
		townsfolk = awake
	var pool := []
	for caller in townsfolk:
		for i in (int(settings.get("night", {}).get("night_only_weight", 3)) if night and caller.get("night_only", false) else 1):
			pool.append(caller)
	return { "kind": "townsfolk", "id": pool.pick_random()["id"] } if not pool.is_empty() else {}


# The call for a specific caller (debug panel), or {} with `why` explaining.
# A regular only calls when Withdrawn (to order) or at their top stage (to chat).
static func call_from(caller_id: String) -> Dictionary:
	if not GameData.get_caller(caller_id).is_empty():
		return { "kind": "townsfolk", "id": caller_id }
	for kind in ["order", "chat"]:
		if GameState.regulars.has(caller_id) and _right_stage(caller_id, kind):
			return { "kind": kind, "id": caller_id }
	return {}


# Would this regular make this kind of call today? Once per real date each.
static func _calls_today(regular_id: String, kind: String) -> bool:
	var record: Dictionary = GameState.regulars[regular_id]
	return _right_stage(regular_id, kind) and record.get("last_called", "") != GameState.date


static func _right_stage(regular_id: String, kind: String) -> bool:
	var stage := RegularMemory.stage_of(GameState.regulars[regular_id])
	var settings := GameData.phone_settings
	if kind == "order":
		return stage == int(settings.get("regular_order_call_stage", -3)) or Redemption.goodbye_due(GameState.regulars[regular_id])
	return stage >= int(settings.get("regular_chat_call_stage", 4))


# The phone starts ringing for `call`: a regular counts as having called today.
static func start_ringing(call: Dictionary) -> void:
	if call["kind"] != "townsfolk" and GameState.regulars.has(call["id"]):
		GameState.regulars[call["id"]]["last_called"] = GameState.date


# Everything said on `call`, for chef `chef_id` (live or played back from
# voicemail): { name, regular_id, lines: [text...], ask: {} or { text, options,
# choices }, dish: {} or the dish ordered }. The caller's lines are picked now,
# so a regular's memory (like an answered note) moves on.
static func build(call: Dictionary, chef_id: String, voicemail: bool) -> Dictionary:
	if call["kind"] == "townsfolk":
		return _build_townsfolk(GameData.get_caller(call["id"]), voicemail)
	return _build_regular(GameState.regulars.get(call["id"], {}), call["kind"], chef_id)


static func _build_townsfolk(caller: Dictionary, voicemail: bool) -> Dictionary:
	var result := { "name": caller.get("name", "Someone"), "regular_id": "", "lines": [], "ask": {}, "dish": {} }
	if caller.is_empty():
		return result
	var settings := GameData.phone_settings
	var usual: Array = GameData.menu().filter(func(d): return d["id"] == caller["usual_order"])  # Only once it's on the menu.
	var dish: Dictionary = usual[0] if not usual.is_empty() and randf() < settings.get("townsfolk_usual_order_chance", 0.75) else GameData.random_dish()
	result["dish"] = dish
	var context := {
		"dish": dish.get("name", ""),
		"restaurant": GameState.restaurant_name if not GameState.restaurant_name.is_empty() else "your restaurant",
	}
	for part in ["greeting", "order"]:
		var line := _random_part(caller, part)
		if not line.is_empty():
			result["lines"].append(DialoguePicker.fill(line["text"], context))
	# Sometimes one quick reply (not on a recording: there's nobody to reply to).
	var chat := _random_part(caller, "chat")
	if not voicemail and not chat.is_empty() and randf() < settings.get("townsfolk_chat_chance", 0.4):
		result["ask"] = _ask(chat, context)
	return result


static func _build_regular(record: Dictionary, kind: String, chef_id: String) -> Dictionary:
	var result := { "name": record.get("name", "Someone"), "regular_id": record.get("id", ""), "lines": [], "ask": {}, "dish": {} }
	if record.is_empty():
		return result
	if kind == "chat":
		var chat := RegularMemory.say(record, "phone_chat", RegularMemory.dialogue_context(record, chef_id))
		if not chat.is_empty():
			result["lines"].append(chat)
		return result

	var dish := RegularMemory.choose_dish(record)
	var greeting := RegularMemory.say(record, "phone_greeting", RegularMemory.dialogue_context(record, chef_id))
	if not greeting.is_empty():
		result["lines"].append(greeting)
	var order_line := RegularMemory.pick_line(record, "phone_order", RegularMemory.dialogue_context(record, chef_id))
	var line_dish := Conversation.dish_of(order_line, record)
	if not line_dish.is_empty():
		dish = line_dish
	var context := RegularMemory.dialogue_context(record, chef_id, { "dish": dish.get("name", "") })
	if not order_line.is_empty():
		result["lines"].append(DialoguePicker.fill(order_line["text"], context))
		Conversation.apply_line(record, order_line, chef_id)  # e.g. a note they've now answered.
	result["dish"] = dish
	var note := RegularMemory.pick_line(record, "phone_note", context)
	if not note.is_empty():
		result["ask"] = _ask(note, context)
	return result


# A line with choices, ready for the dialogue box.
static func _ask(line: Dictionary, context: Dictionary) -> Dictionary:
	var choices := Conversation.choices_of(line)
	return {
		"text": DialoguePicker.fill(line["text"], context),
		"options": choices.map(func(c): return DialoguePicker.fill(c["text"], context)),
		"choices": choices,
	}


# The chef picked option `index` of the call's ask. For a regular this is the
# note in the bag (relationship change, flags); townsfolk just answer.
# Returns { reply, change }.
static func answer(built: Dictionary, index: int, chef_id: String) -> Dictionary:
	var ask: Dictionary = built["ask"]
	var choice: Dictionary = ask["choices"][index]
	var record: Dictionary = GameState.regulars.get(built["regular_id"], {})
	if record.is_empty():
		return { "reply": choice.get("reply", ""), "change": 0 }
	var result := Conversation.apply_choice(record, choice, ask["options"][index], chef_id)
	result["reply"] = DialoguePicker.fill(result["reply"], RegularMemory.dialogue_context(record, chef_id))
	return result


# Who's on the line, for the order and the courier: { kind, id, name, species, regular_id }.
static func caller_info(call: Dictionary) -> Dictionary:
	if call["kind"] == "townsfolk":
		var caller := GameData.get_caller(call["id"])
		return { "kind": "townsfolk", "id": call["id"], "name": caller.get("name", "?"), "species": caller.get("species", ""), "regular_id": "" }
	var record: Dictionary = GameState.regulars.get(call["id"], {})
	return { "kind": call["kind"], "id": call["id"], "name": record.get("name", "?"), "species": record.get("species", ""), "regular_id": call["id"] }


# Debug panel: fill the voicemail with calls from town, one per caller, up to
# max_voicemails.
static func fill_voicemail() -> void:
	var max_count := int(GameData.phone_settings.get("max_voicemails", 6))
	var callers := GameData.callers.duplicate()
	callers.shuffle()
	for caller in callers:
		if GameState.voicemails.size() >= max_count:
			return
		GameState.voicemails.append({ "kind": "townsfolk", "id": caller["id"] })


static func _random_part(caller: Dictionary, part: String) -> Dictionary:
	var lines: Array = caller.get("lines", []).filter(func(l): return l.get("part", "") == part)
	return lines.pick_random() if not lines.is_empty() else {}
