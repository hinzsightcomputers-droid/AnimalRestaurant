# ScenePlayer: plays a big moment scene from data/scenes.json (see BigMoments).
# At closing, once the last customer has left, DayManager asks it to play
# whatever is due. The regular walks in and the staging comes on: the lights
# dim (and flicker, for Mabel's storm), the music drops, rain if the scene asks
# for it, and the chef they know best has their camera moved in close. Then the
# steps play in one dialogue box: narration, lines, choices (each with its own
# reply), and "cook", the co-cooking minigame at the stove, which can't fail.
# A line or a choice can have an "emotion" for how the regular feels saying it
# (see Conversation).
# Afterwards the regular leaves, everything goes back to normal, and
# BigMoments.finish sets the scene's flags and rewards.
class_name ScenePlayer
extends Node

signal scene_finished(scene: Dictionary)

@export var customer_manager: CustomerManager
@export var view_manager: ViewManager
@export var cooking_station: CookingStation
@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var camera_zoom: CameraZoomSettings  # The chef's camera during the scene.

var _playing := false
var _played_this_shift := false
var _rain := AudioStreamPlayer.new()
var _staging: Tween


func _ready() -> void:
	_rain.stream = _rain_stream()
	_rain.volume_db = -14.0
	add_child(_rain)


func is_playing() -> bool:
	return _playing


# Start tonight's scene, if one is due and none has played this shift. Returns
# true while one is playing (the day waits for it).
func play_due() -> bool:
	if _playing:
		return true
	if _played_this_shift:
		return false
	var scene := BigMoments.due()
	if scene.is_empty():
		return false
	_played_this_shift = true
	play(scene)
	return true


func play(scene: Dictionary) -> void:
	var record: Dictionary = GameState.regulars.get(scene.get("regular", ""), {})
	var player := _chef_for(record)
	if record.is_empty() or player == null:
		return
	_playing = true
	var staging: Dictionary = scene.get("staging", {})
	_stage(staging, true)
	var visitor := customer_manager.walk_in(record, Customer.State.ARRIVING)
	visitor.talking = true
	while visitor.is_walking():
		await get_tree().process_frame

	var chef_id := Accounts.id_of(player.player_index)
	_hold(player, visitor)
	var box := _open_box(player, record)
	for step in scene.get("steps", []):
		if step.has("cook"):
			box.close()
			await _cook_together(player, visitor, step)
			_hold(player, visitor)
			box = _open_box(player, record)
			continue
		var context := RegularMemory.dialogue_context(record, chef_id)
		var speaker: String = "" if step.has("narrate") else record["name"]
		var text := DialoguePicker.fill(step.get("narrate", step.get("say", "")), context)
		var feeling := Conversation.emotion_of(step)
		if not step.has("narrate"):
			visitor.say(text)
			visitor.emote(feeling)
		var choices: Array = step.get("choices", [])
		if choices.is_empty():
			await box.tell(speaker, text, feeling)
			continue
		var picked := await box.ask(speaker, text, choices.map(func(c): return DialoguePicker.fill(c["text"], context)), feeling)
		var reply := DialoguePicker.fill(choices[picked].get("reply", ""), context)
		if not reply.is_empty():
			visitor.say(reply)
			visitor.emote(Conversation.emotion_of(choices[picked]))
			await box.tell(record["name"], reply, Conversation.emotion_of(choices[picked]))
	box.close()

	player.ignore_interact_until_released()
	player.movement_locked = false
	player.interactor.unlock()
	player.release_camera_focus()
	visitor.talking = false
	customer_manager.walk_out(visitor)
	_stage(staging, false)
	BigMoments.finish(scene)
	_playing = false
	scene_finished.emit(scene)


# The chef playing who this regular knows best, or the first player.
func _chef_for(record: Dictionary) -> Player:
	var favorite := RegularMemory.favorite_chef_here(record)
	for i in 4:
		var player := Player.find(get_tree(), i)
		if player != null and Accounts.id_of(i) == favorite:
			return player
	for i in 4:
		if Player.find(get_tree(), i) != null:
			return Player.find(get_tree(), i)
	return null


# Keep the chef in place, camera in close on the two of them.
func _hold(player: Player, visitor: Customer) -> void:
	player.movement_locked = true
	player.interactor.lock_to(visitor.interactable)  # Not usable: presses only move the scene on.
	player.request_camera_focus((player.global_position + visitor.global_position) * 0.5 + Vector3.UP * 1.2, camera_zoom)


func _open_box(player: Player, record: Dictionary) -> ConversationBox:
	return ConversationBox.open(ConversationBox.parent_for(view_manager, player.player_index, self), player.player_index, record["id"])


# The co-cooking minigame: the chef at the stove, the regular beside them
# coaching each stir. It can't come out worse than the step's min_quality.
func _cook_together(player: Player, visitor: Customer, step: Dictionary) -> void:
	player.release_camera_focus()
	var stove := cooking_station.interactable.global_position
	player.global_position = Vector3(stove.x, player.global_position.y, stove.z)
	visitor.global_position = Vector3(stove.x + 0.9, 0.0, stove.z)
	await cooking_station.cook_together(player, step["cook"], step, visitor)


# Lights, music and rain for the scene (on), or back to normal (off).
func _stage(staging: Dictionary, on: bool) -> void:
	var seconds: float = GameData.scene_settings.get("staging_seconds", 1.5)
	var dim: float = staging.get("dim", 1.0) if on else 1.0
	if _staging != null:
		_staging.kill()
	_staging = create_tween().set_parallel()
	if sun != null:
		if not sun.has_meta("base_energy"):
			sun.set_meta("base_energy", sun.light_energy)
		_staging.tween_property(sun, "light_energy", float(sun.get_meta("base_energy")) * dim, seconds)
	var environment: Environment = world_environment.environment if world_environment != null else null
	if environment != null:
		if not world_environment.has_meta("base_ambient"):
			world_environment.set_meta("base_ambient", environment.ambient_light_energy)
		_staging.tween_property(environment, "ambient_light_energy", float(world_environment.get_meta("base_ambient")) * dim, seconds)
	if on and staging.get("flicker", false) and sun != null:  # Once, after the lights go down.
		var low: float = float(sun.get_meta("base_energy")) * dim
		_staging.chain().tween_property(sun, "light_energy", low * 0.15, 0.06)
		_staging.chain().tween_property(sun, "light_energy", low, 0.1)
		_staging.chain().tween_property(sun, "light_energy", low * 0.3, 0.05)
		_staging.chain().tween_property(sun, "light_energy", low, 0.2)
	if on and staging.get("rain", false):
		_rain.play()
	elif not on:
		_rain.stop()
	var music: String = staging.get("music", "")
	if music.is_empty():
		Music.dip(staging.get("music_db", 0.0) if on else 0.0, seconds)
		return
	# Their own song: the usual music fades out first, then it fades in (and
	# the other way round afterwards).
	Music.fade_out(seconds)
	await get_tree().create_timer(seconds).timeout
	if on:
		Music.play(music, seconds)
	else:
		Music.play_hour_themes()


# Placeholder rain: soft filtered noise, looping (until a real sound is added).
func _rain_stream() -> AudioStreamWAV:
	var rate := 22050
	var total := rate * 3
	var data := PackedByteArray()
	data.resize(total * 2)
	var smooth := 0.0
	for i in total:
		smooth = lerpf(smooth, randf_range(-1.0, 1.0), 0.35)
		data.encode_s16(i * 2, int(smooth * 0.35 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = total
	return wav
