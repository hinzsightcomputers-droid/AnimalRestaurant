# CarTrip: Cheddar's car and the trips in it (data/trips.json). Once his invite
# scene has unlocked it (cheddar_car), the car is parked out front. After
# hours, while he's at min_stage or better, Cheddar waits by it: any chef can
# ask to go to the beach (his car_greeting, then Let's go / Maybe later). Then
# every other chef at the restaurant is asked if they're coming (car_ask), each
# as soon as they're out of any close-up or dialogue, and the trip waits for
# every answer. Those coming drive off together in one shared view (DriveView,
# with Cheddar chatting), skippable once the chefs have been a few times, and
# arrive at the Beach. Its car takes everyone at the beach home the same way
# (car_home). Once they're home he gets back in and drives off, and isn't
# back until the next day (5 AM). While he's below min_stage the car stays put with a note on it
# (car_note). The trip count is saved; a trip isn't (quitting at the beach
# starts you back at the restaurant).
class_name CarTrip
extends Node3D

const SKIP_GRACE := 0.6  # Seconds into a drive before a press can skip it.

var beach: Beach
var _view_manager: ViewManager
var _car: Node3D
var _cheddar: RegularFigure
var _interactable := Interactable.new()
var _busy := false
var _check_left := 0.0
var _zoom := CameraZoomSettings.new()
var _emotion: StringName = &""  # How the last line from _line was said.
var _leaving := false  # Driving off, so _refresh leaves the car alone.


func _ready() -> void:
	_view_manager = get_tree().root.find_children("*", "ViewManager", true, false).front()
	var settings: Dictionary = GameData.trips.get("car", {})
	_car = Node3D.new()
	_car.name = "CheddarsCar"
	add_child(_car)
	var fit := ModelFit.place(String(settings.get("model", "")), _car, _at(settings.get("parked_at", [-7.5, 11.9])), Vector3(0.0, 0.0, float(settings.get("length", 3.2))))
	if fit != null:
		fit.rotation.y = PI / 2.0
	_cheddar = RegularFigure.make(settings.get("regular", "cheddar"))
	_cheddar.position = _at(settings.get("cheddar_at", [-5.4, 10.25]))
	_cheddar.rotation.y = deg_to_rad(-20.0)
	add_child(_cheddar)
	_interactable.radius = 1.6
	_interactable.position = _at(settings.get("step_out_at", [-7.5, 10.0]))
	_interactable.prompt_for_player = _prompt_for
	_interactable.interacted.connect(_on_interacted)
	add_child(_interactable)
	_zoom.distance = 4.2
	_zoom.pitch_degrees = 28.0
	_zoom.duration = 0.5
	_zoom.yaw_degrees = CameraRig.VIEW_YAW  # From the side the follow camera's on.
	beach = Beach.new()
	beach.name = "Beach"
	beach.car_trip = self
	add_child(beach)
	_refresh()


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = 1.0
		_refresh()


# The car's out front once it's unlocked; Cheddar's by it after hours while he's friendly enough.
func _refresh() -> void:
	if _leaving:
		return
	_car.visible = is_unlocked() and not left_today()
	_car.position = Vector3.ZERO
	_cheddar.visible = _car.visible and cheddar_ready() and DayCycle.doors_open() and (not _busy or _anyone_home())


# He brought everyone home today and drove off; he's back after 5 AM.
func left_today() -> bool:
	return GameState.cheddar_left_on == GameClock.today()


func is_unlocked() -> bool:
	return String(GameData.trips.get("car", {}).get("unlock", "cheddar_car")) in GameState.unlocks


func record() -> Dictionary:
	return GameState.regulars.get(GameData.trips.get("car", {}).get("regular", "cheddar"), {})


# At min_stage or better (and not gone), he'll drive.
func cheddar_ready() -> bool:
	var regular := record()
	if regular.is_empty() or Redemption.is_gone(regular):
		return false
	return RegularMemory.stage_of(regular) >= int(GameData.trips.get("car", {}).get("min_stage", 2))


func is_busy() -> bool:
	return _busy


# Can this chef start a trip from where they are (to the beach from home, or home from the beach)?
func can_start(player_index: int) -> bool:
	var player := Player.find(get_tree(), player_index)
	return not _busy and player != null and _is_free(player) and is_unlocked() and cheddar_ready() and DayCycle.doors_open()


func can_chat(player_index: int) -> bool:
	var player := Player.find(get_tree(), player_index)
	return not _busy and player != null and _is_free(player) and beach.contains(player.global_position)


func at_beach(player: Player) -> bool:
	return beach.contains(player.global_position)


func _prompt_for(player_index: int) -> String:
	if not is_unlocked() or not DayCycle.doors_open() or _busy or _leaving or left_today():
		return ""
	if not cheddar_ready():
		return "Look at Cheddar's car"
	return "Go to the beach with %s" % record().get("name", "Cheddar") if can_start(player_index) else ""


func _on_interacted(player_index: int) -> void:
	if _prompt_for(player_index).is_empty():
		return
	if not cheddar_ready():
		_show_note(player_index)
		return
	start(player_index, true)


# The note on the car while he's not up for trips (car_note, by his stage).
func _show_note(player_index: int) -> void:
	var player := Player.find(get_tree(), player_index)
	var regular := record()
	var text := RegularMemory.say(regular, "car_note", RegularMemory.dialogue_context(regular, Accounts.id_of(player_index)))
	if player == null or text.is_empty():
		return
	_hold(player, _car.get_child(0).global_position if _car.get_child_count() > 0 else _interactable.global_position)
	var box := _open_box(player_index)
	await box.tell("", text)
	box.close()
	_release(player)


# A chat with Cheddar at the beach (beach_chat).
func chat(player_index: int, figure: RegularFigure) -> void:
	var player := Player.find(get_tree(), player_index)
	var regular := record()
	var line := RegularMemory.pick_line(regular, "beach_chat", RegularMemory.dialogue_context(regular, Accounts.id_of(player_index)))
	if player == null or line.is_empty():
		return
	_hold(player, figure.global_position)
	figure.talking = true
	var box := _open_box(player_index)
	await box.tell(regular.get("name", "Cheddar"), DialoguePicker.fill(line["text"], RegularMemory.dialogue_context(regular, Accounts.id_of(player_index))), Conversation.emotion_of(line))
	box.close()
	figure.talking = false
	_release(player)


# `player_index` asks Cheddar to go: to the beach, or home from it.
func start(player_index: int, to_beach: bool) -> void:
	var starter := Player.find(get_tree(), player_index)
	if _busy or starter == null:
		return
	_busy = true
	var regular := record()
	var choices: Dictionary = GameData.trips.get("choices", {})
	_hold(starter, _cheddar.global_position if to_beach else beach.cheddar.global_position)
	var box := _open_box(player_index)
	var picked := await box.ask(regular.get("name", "Cheddar"), _line("car_greeting" if to_beach else "car_home", player_index),
		choices.get("go" if to_beach else "home", ["Let's go!", "Maybe later"]), _emotion)
	box.close()
	if picked != 0:
		_release(starter)
		_busy = false
		return

	# Everyone else in the same place gets asked (once they're free), and the trip waits for them all.
	var answers := {}
	for other in get_tree().get_nodes_in_group(Player.GROUP):
		var player := other as Player
		if player == starter or at_beach(player) == to_beach:
			continue
		answers[player.player_index] = null
		_ask(player, to_beach, answers)
	if not answers.is_empty():
		GameEvents.announce("Waiting for everyone to answer %s..." % regular.get("name", "Cheddar"))
	while answers.values().has(null):
		await get_tree().process_frame
	var travelers: Array[int] = [player_index]
	for index in answers:
		if answers[index]:
			travelers.append(index)
	await _drive(travelers, to_beach)
	_busy = false


# Asks one chef if they're coming (or, at the beach, tells them it's time to go).
func _ask(player: Player, to_beach: bool, answers: Dictionary) -> void:
	var index := player.player_index
	while is_instance_valid(player) and not _is_free(player):
		await get_tree().process_frame  # Let them finish their close-up or conversation first.
	if not is_instance_valid(player):
		answers[index] = false  # They left the game.
		return
	var choices: Dictionary = GameData.trips.get("choices", {})
	_hold(player, player.global_position + Vector3(0.0, 0.0, -0.5))
	var box := _open_box(player.player_index)
	var picked := await box.ask(record().get("name", "Cheddar"), _line("car_ask" if to_beach else "car_home", player.player_index),
		choices.get("coming" if to_beach else "home_others", ["Coming!", "Not this time"]), _emotion)
	box.close()
	answers[player.player_index] = picked == 0 or not to_beach  # Nobody gets left at the beach.
	if not answers[player.player_index]:
		_release(player)


# The drive itself: one shared view while the chefs are moved, then they're there.
func _drive(travelers: Array[int], to_beach: bool, reel_seconds := 0.0, reel_lines: Array = []) -> void:
	var settings: Dictionary = GameData.trips.get("drive", {})
	var skippable := GameState.car_trips >= int(settings.get("skip_after_trips", 3))
	if to_beach:
		GameState.car_trips += 1
		SaveGame.save_game()
	var drive := DriveView.new()
	drive.view_manager = _view_manager
	drive.travelers = travelers
	drive.full_screen = travelers.size() >= get_tree().get_nodes_in_group(Player.GROUP).size() and not ReelSandbox.active()
	drive.skippable = skippable
	add_child(drive)
	await drive.shown
	var points := beach.arrival_points() if to_beach else _home_points(travelers.size())
	for i in travelers.size():
		var player := Player.find(get_tree(), travelers[i])
		if player != null:
			player.release_camera_focus()
			_place(player, points[i % points.size()], to_beach)
	var seconds := reel_seconds if reel_seconds > 0.0 else float(settings.get("seconds" if to_beach else "home_seconds", 12.0))
	var script := reel_lines.duplicate()
	var lines := script.size() if not script.is_empty() else (int(settings.get("chatter_lines", 2)) if to_beach else 1)
	var say_at: Array[float] = []
	for i in lines:
		say_at.append(0.6 + i * seconds / (lines + 0.5))
	var time := 0.0
	var skipped := false
	var armed := {}
	while time < seconds and not skipped:
		await get_tree().process_frame
		time += get_process_delta_time()
		if not say_at.is_empty() and time >= say_at[0]:
			say_at.pop_front()
			drive.say(_said_line(script.pop_front()) if not script.is_empty() else _line("car_chatter", travelers[0]), _emotion)
		if skippable and time > SKIP_GRACE:
			for index in travelers:
				var pressed := Input.is_action_pressed(InputSetup.action_name(index, "interact"))
				if not pressed:
					armed[index] = true
				elif armed.get(index, false):
					skipped = true
	if to_beach:
		drive.say(_line("car_arrive", travelers[0]), _emotion)
		var wait := 0.0
		while wait < 2.5 and not skipped:
			await get_tree().process_frame
			wait += get_process_delta_time()
	drive.close()
	for index in travelers:
		var player := Player.find(get_tree(), index)
		if player != null:
			_release(player)
	if not to_beach:
		_drive_off()


# A reel opens on the car out front, Cheddar beside it and `chef` about to get in.
func reel_stage(chef: Player) -> void:
	_leaving = true  # So _refresh leaves them out, whatever the day says.
	_car.visible = true
	_cheddar.visible = true
	_place(chef, _at(GameData.trips.get("car", {}).get("step_out_at", [-7.5, 10.0])), true)


# A reel that starts at the beach, `chef` just out of the car.
func reel_arrive(chef: Player) -> void:
	_place(chef, beach.arrival_points()[0], true)


# A reel's drive to the beach, for the first chef, `seconds` long (0 = as usual),
# with these of his lines (none = picked as usual).
func reel_drive(seconds: float, chatter: Array) -> void:
	var travelers: Array[int] = [0]
	await _drive(travelers, true, seconds, chatter)
	_leaving = false


# His line with this id, with its emotion in _emotion.
func _said_line(line_id: String) -> String:
	var regular := record()
	var line := ReelScenario.find_line(regular.get("id", "cheddar"), line_id)
	_emotion = Conversation.emotion_of(line)
	return DialoguePicker.fill(line.get("text", ""), RegularMemory.dialogue_context(regular, Accounts.id_of(0)))


# Home again: Cheddar hops in and the car drives off down the road, not to
# be seen again until tomorrow.
func _drive_off() -> void:
	GameState.cheddar_left_on = GameClock.today()
	SaveGame.save_game()
	_leaving = true
	_car.visible = true
	_cheddar.visible = true
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(_cheddar, "visible", false, 0.0)  # In he gets.
	tween.tween_interval(0.5)
	tween.tween_property(_car, "position:x", 40.0, 3.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_leaving = false
		_refresh())
	GameEvents.announce("%s waves and drives off. See you tomorrow!" % record().get("name", "Cheddar"))

# Beside the car out front, in a row along the curb.
func _home_points(count: int) -> Array[Vector3]:
	var at := _at(GameData.trips.get("car", {}).get("step_out_at", [-7.5, 10.0]))
	var points: Array[Vector3] = []
	for i in count:
		points.append(at + Vector3((i - (count - 1) / 2.0) * 0.9, 0.0, 0.0))
	return points


func _place(player: Player, at: Vector3, to_beach: bool) -> void:
	player.global_position = at + Vector3(0.0, 0.05, 0.0)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	player.visual.rotation.y = 0.0 if to_beach else PI  # Facing the sea, or the restaurant.


# Cheddar's line for an event, said to that chef, with its emotion in _emotion.
func _line(event: String, player_index: int) -> String:
	var regular := record()
	var context := RegularMemory.dialogue_context(regular, Accounts.id_of(player_index))
	var line := RegularMemory.pick_line(regular, event, context)
	_emotion = Conversation.emotion_of(line) if not line.is_empty() else &""
	return DialoguePicker.fill(line.get("text", ""), context)


func _is_free(player: Player) -> bool:
	return not player.movement_locked and not player.in_conversation() and not player.hidden_from_own_view


func _anyone_home() -> bool:
	return get_tree().get_nodes_in_group(Player.GROUP).any(func(p): return not at_beach(p))


# Keep a chef in place with their camera in close, while they talk.
func _hold(player: Player, toward: Vector3) -> void:
	player.movement_locked = true
	player.interactor.lock_to(_interactable)
	player.request_camera_focus((player.global_position + toward) * 0.5 + Vector3.UP * 1.0, _zoom)


func _release(player: Player) -> void:
	player.movement_locked = false
	player.interactor.unlock()
	player.release_camera_focus()
	player.ignore_interact_until_released()


func _open_box(player_index: int) -> ConversationBox:
	return ConversationBox.open(ConversationBox.parent_for(_view_manager, player_index, self), player_index, "cheddar")


func _at(xz: Array) -> Vector3:
	return Vector3(float(xz[0]), 0.0, float(xz[1]))


# Debug: everyone straight to the beach, or home, without the drive.
func debug_send_everyone(to_beach: bool) -> void:
	var players := get_tree().get_nodes_in_group(Player.GROUP)
	var points := beach.arrival_points() if to_beach else _home_points(players.size())
	for i in players.size():
		_place(players[i], points[i % points.size()], to_beach)
