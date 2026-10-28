# Phone: the phone on the wall by the counter. Every so often while the
# restaurant is open it rings (sound, shaking, "Ring! Ring!"). Walk up and
# interact to answer: the call plays in the dialogue box (greeting, order,
# sometimes one quick reply) and the order goes to DeliveryManager.
# Nobody is ever punished for missing a call: if it rings out, or someone is
# talking with a regular when it rings, it goes to voicemail, and voicemails
# wait on the phone (with a blinking light) to be played back any time.
# The time until the next ring stands still during conversations, and the
# phone stays quiet while a regular is walking in. Timings: data/phone.json.
# When it's quiet, you can also pick it up to call a friend of someone Gone and
# ask them to talk to that regular for you (see Redemption).
class_name Phone
extends Station

const SHAKE_DEGREES := 6.0

@export var delivery_manager: DeliveryManager
@export var view_manager: ViewManager      # To show the call in the right player's view.
@export var day_manager: DayManager        # Rings only while open.
@export var customer_manager: CustomerManager

var _ringing: Dictionary = {}   # The call ringing right now, {} when quiet.
var _ring_left := 0.0           # Seconds before it goes to voicemail.
var _until_next_ring := 0.0
var _in_call := false
var _last_caller := ""
var _ring_sound := AudioStreamPlayer.new()
var _light_material := StandardMaterial3D.new()
var _time := 0.0

@onready var ring_label: Label3D = $RingLabel
@onready var voicemail_label: Label3D = $VoicemailLabel
@onready var voicemail_light: MeshInstance3D = $Visual/VoicemailLight


func _ready() -> void:
	super._ready()
	interactable.prompt_for_player = _prompt_for
	_ring_sound.stream = _ring_stream()
	add_child(_ring_sound)
	_light_material.emission_enabled = true
	voicemail_light.material_override = _light_material
	_until_next_ring = _random_seconds("first_ring_delay")


func is_ringing() -> bool:
	return not _ringing.is_empty()


func _prompt_for(player_index: int) -> String:
	if _in_call:
		return ""
	if is_ringing():
		return "Answer"
	if not GameState.voicemails.is_empty():
		return "Voicemail (%d)" % GameState.voicemails.size()
	if not Redemption.all_helpers(Accounts.id_of(player_index)).is_empty():
		return "Call a friend"
	return ""


func _on_interacted(player_index: int) -> void:
	var player := Player.find(get_tree(), player_index)
	if _in_call or player == null:
		return
	if is_ringing():
		var call := _ringing
		_stop_ringing()
		_play_bounce()
		_take_call(player, call, false)
	elif not GameState.voicemails.is_empty():
		_play_bounce()
		_take_call(player, GameState.voicemails.pop_front(), true)
	elif not Redemption.all_helpers(Accounts.id_of(player_index)).is_empty():
		_play_bounce()
		_call_friend(player)


func _process(delta: float) -> void:
	_time += delta
	_update_look()
	if _in_call:
		return
	if is_ringing():
		_ring_left -= delta
		if _ring_left <= 0.0 or _someone_talking():
			_to_voicemail()
		return
	if not GameState.forced_caller.is_empty():  # Debug panel.
		_ring_forced(GameState.forced_caller)
		return
	if not day_manager.is_open or _someone_talking() or _regular_arriving() or not BigMoments.due().is_empty():
		return  # (No calls at all on the evening of a big moment.)
	_until_next_ring -= delta
	if _until_next_ring > 0.0:
		return
	_until_next_ring = _random_seconds("seconds_between_calls")
	if GameState.voicemails.size() >= _max_voicemails():
		return  # Plenty waiting already: this call just doesn't happen.
	var call := PhoneCalls.next_call(_last_caller)
	if not call.is_empty():
		_ring(call)


func _ring(call: Dictionary) -> void:
	_ringing = call
	_last_caller = call["id"]
	_ring_left = GameData.phone_settings.get("ring_seconds", 15.0)
	PhoneCalls.start_ringing(call)
	_ring_sound.play()
	GameEvents.announce("The phone is ringing!")


func _ring_forced(caller_id: String) -> void:
	GameState.forced_caller = ""
	var call := PhoneCalls.call_from(caller_id)
	if call.is_empty():
		var regular_name: String = GameState.regulars.get(caller_id, {}).get("name", caller_id)
		GameEvents.announce("%s only phones when Withdrawn (to order) or at their top stage (to chat)." % regular_name)
		return
	_ring(call)


func _stop_ringing() -> void:
	_ringing = {}
	_ring_sound.stop()


func _to_voicemail() -> void:
	var call := _ringing
	_stop_ringing()
	if GameState.voicemails.size() < _max_voicemails():
		GameState.voicemails.append(call)
		GameEvents.announce("Missed a call from %s. They left a voicemail." % PhoneCalls.caller_info(call)["name"])


# Answer `call` (or play it back from voicemail): the lines in a dialogue box,
# then the order goes in. The player stays at the phone until it's done.
func _take_call(player: Player, call: Dictionary, voicemail: bool) -> void:
	_in_call = true
	var chef_id := Accounts.id_of(player.player_index)
	player.movement_locked = true
	player.interactor.lock_to(interactable)
	var built := PhoneCalls.build(call, chef_id, voicemail)
	var speaker: String = built["name"]
	if voicemail:
		speaker += GameData.phone_settings.get("voicemail_suffix", " (voicemail)")
	var box := ConversationBox.open(_view_of(player), player.player_index, built["regular_id"])
	for line in built["lines"]:
		await box.tell(speaker, line)
	if not built["ask"].is_empty():
		var record: Dictionary = GameState.regulars.get(built["regular_id"], {})
		var before: int = record.get("relationship", 0)
		var picked := await box.ask(speaker, built["ask"]["text"], built["ask"]["options"])
		var result := PhoneCalls.answer(built, picked, chef_id)
		if not record.is_empty() and record["relationship"] != before:
			GameEvents.announce("%s: %+d -> %d (%s)" % [record["name"], record["relationship"] - before, record["relationship"], RegularMemory.stage_name(record)])
		if not String(result["reply"]).is_empty():
			await box.tell(speaker, result["reply"])
	box.close()
	player.ignore_interact_until_released()  # The press that closed the box shouldn't pick the phone up again.
	player.movement_locked = false
	player.interactor.unlock()
	if not built["dish"].is_empty():
		delivery_manager.add_delivery(built["dish"], PhoneCalls.caller_info(call))
		GameEvents.announce("%s ordered %s for delivery." % [built["name"], built["dish"].get("name", "something")])
	_in_call = false


# Call a friend of someone Gone: pick who (and about whom), ask them, and they
# say they'll talk to them. The phone doesn't ring for anyone else meanwhile.
func _call_friend(player: Player) -> void:
	_in_call = true
	var chef_id := Accounts.id_of(player.player_index)
	player.movement_locked = true
	player.interactor.lock_to(interactable)
	var helpers := Redemption.all_helpers(chef_id)
	var options: Array = helpers.map(func(h): return Redemption.text("phone_option", { "friend": GameState.regulars[h["friend"]]["name"], "who": GameState.regulars[h["gone"]]["name"] }))
	options.append(Redemption.text("hang_up"))
	var box := ConversationBox.open(_view_of(player), player.player_index, "")
	var picked := await box.ask("Phone", Redemption.text("phone_who"), options)
	if picked < helpers.size():
		var friend: Dictionary = GameState.regulars[helpers[picked]["friend"]]
		var gone: Dictionary = GameState.regulars[helpers[picked]["gone"]]
		var context := Redemption.help_context(friend, gone["id"], chef_id)
		await box.tell(Accounts.name_of(player.player_index), Redemption.ask_friend_text(gone))
		await box.tell(friend["name"], DialoguePicker.fill(RegularMemory.pick_line(friend, "gossip", context)["text"], context))
		Redemption.friend_agreed(gone)
		GameEvents.announce("%s will talk to %s." % [friend["name"], gone["name"]])
	box.close()
	player.ignore_interact_until_released()
	player.movement_locked = false
	player.interactor.unlock()
	_in_call = false


# Someone is in a conversation (with a regular, or anything else using the dialogue box).
func _someone_talking() -> bool:
	return get_tree().get_nodes_in_group(ConversationBox.GROUP).any(func(box): return not box.is_queued_for_deletion())


func _regular_arriving() -> bool:
	return GameData.phone_settings.get("quiet_while_regular_arrives", true) and customer_manager.regular_arriving()


func _view_of(player: Player) -> Control:
	return ConversationBox.parent_for(view_manager, player.player_index, self)


# Shakes and shows "Ring! Ring!" in time with the ring; the light blinks while
# voicemails are waiting.
func _update_look() -> void:
	var ring_time: float = GameData.phone_settings.get("ring_seconds", 15.0) - _ring_left
	var sounding := is_ringing() and fmod(ring_time, 3.0) < 1.2
	visual.rotation.z = deg_to_rad(sin(_time * 45.0) * SHAKE_DEGREES) if sounding else 0.0
	ring_label.visible = is_ringing()
	ring_label.position.y = 2.45 + (0.06 * sin(_time * 12.0) if sounding else 0.0)
	var waiting := GameState.voicemails.size()
	voicemail_label.visible = waiting > 0 and not is_ringing()
	voicemail_label.text = "%d voicemail%s" % [waiting, "" if waiting == 1 else "s"]
	var lit := waiting > 0 and fmod(_time, 1.2) < 0.7
	_light_material.albedo_color = Color(0.95, 0.2, 0.15) if lit else Color(0.35, 0.12, 0.1)
	_light_material.emission = Color(1.0, 0.25, 0.15) if lit else Color.BLACK


func _max_voicemails() -> int:
	return int(GameData.phone_settings.get("max_voicemails", 6))


func _random_seconds(key: String) -> float:
	var range_: Dictionary = GameData.phone_settings.get(key, { "min": 20, "max": 40 })
	return randf_range(range_["min"], range_["max"])


# The ring_sound from data/phone.json, or a built-in placeholder: an old
# phone's trill, 1.2 seconds on and 1.8 off, looping.
func _ring_stream() -> AudioStream:
	var path: String = GameData.phone_settings.get("ring_sound", "")
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path)
	var rate := 22050
	var total := rate * 3
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var t := float(i) / rate
		var value := 0.0
		if t < 1.2 and fmod(t * 20.0, 1.0) < 0.5:
			value = (sin(TAU * 480.0 * t) + sin(TAU * 620.0 * t)) * 0.18
		data.encode_s16(i * 2, int(value * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = total
	return wav
