extends Node

# The phone ringing through a chat: it should hold (quieter) while anyone's in a
# conversation, then ring at least ring_after_chat_seconds before voicemail.
# Headless is fine:
#   APPDATA=<copy of a save> godot --headless res://tools/phone_check.tscn

var main: Node


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.0).timeout
	var phone: Node = _find(main, func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("phone/phone.gd"))[0]
	var call := PhoneCalls.next_call("", false)
	if call.is_empty():
		print("PHONE FAIL no call to ring")
		get_tree().quit(1)
		return
	print("PHONE paused: ", get_tree().paused)
	get_tree().paused = false
	GameState.voicemails.clear()
	var before: int = GameState.voicemails.size()
	phone._ring(call)
	# A pretend conversation: a node in the dialogue box group.
	var chat := Node.new()
	var fake := GDScript.new()
	fake.source_code = "extends Node
var player_index := 7
var speaker_id := \"\"
"
	fake.reload()
	chat.set_script(fake)
	chat.add_to_group(ConversationBox.GROUP)
	add_child(chat)
	var ring: float = GameData.phone_settings.get("ring_seconds", 15.0)
	await get_tree().create_timer(ring + 5.0).timeout
	var ok := true
	ok = _check("still ringing after %.0f s of chat" % (ring + 5.0), phone.is_ringing()) and ok
	ok = _check("no voicemail during the chat", GameState.voicemails.size() == before) and ok
	ok = _check("quieter during the chat", phone._ring_sound.volume_db < 0.0) and ok
	chat.queue_free()
	await get_tree().create_timer(4.0).timeout
	ok = _check("still ringing 4 s after the chat", phone.is_ringing()) and ok
	ok = _check("full volume after the chat", phone._ring_sound.volume_db == 0.0) and ok
	# It held with its time left (the whole ring here), and gets at least ring_after_chat_seconds.
	await get_tree().create_timer(maxf(ring, float(GameData.phone_settings.get("ring_after_chat_seconds", 8.0))) - 4.0 + 1.0).timeout
	ok = _check("voicemail once it rang out", not phone.is_ringing() and GameState.voicemails.size() == before + 1) and ok
	# Whoever rang doesn't ring again this meal, even with the phone forgetting
	# who rang last (as after a restart).
	if call["kind"] == "townsfolk":
		var again := false
		for i in 200:
			again = again or PhoneCalls.next_call("", false).get("id", "") == call["id"]
		ok = _check("%s doesn't phone again this meal" % call["id"], not again) and ok
	print("PHONE ", "ALL OK" if ok else "FAILED")
	get_tree().quit(0 if ok else 1)


func _check(what: String, passed: bool) -> bool:
	print("PHONE %s %s" % ["ok  " if passed else "FAIL", what])
	return passed


func _find(n: Node, f: Callable, out := []) -> Array:
	if f.call(n):
		out.append(n)
	for c in n.get_children():
		_find(c, f, out)
	return out
