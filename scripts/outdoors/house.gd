# House: one regular's house (data/houses.json; Town builds them), beside the
# restaurant with its front door toward the street. Built in code: walls, a
# roof, a door that opens, windows lit unless they've gone dark, a porch, and
# the regular's own touches (Stitches' patches, Cheddar's lights and star).
# Their name goes up by the door once they've invited the chefs over (the
# house's unlock); before that it's locked.
#
# After hours any chef can knock (once a restaurant day per house, see Town):
#   Locked (not invited yet): it's locked, nobody's expecting you.
#   Dark (at dark_stage or lower, or gone): nobody answers.
#   Below porch_stage: a polite "not tonight" through the door (house_not_tonight).
#   Already visited today: a line through the door (house_again).
#   Otherwise a visit: they open the door (house_greeting). At inside_stage
#   and up they ask everyone in: the chefs near the porch fade into the room
#   (built far away at inside_at, like the beach) and the regular settles in
#   (house_greeting again, with "inside"). Each chef can then Chat
#   (house_chat), Give a gift (house_gift: whatever's in the takeout bag
#   they're carrying, a dish or something from the pantry, see gift_kind) or Say goodbye
#   (house_farewell), which ends the visit for everyone once they've all
#   finished talking. At items_stage their things inside can be looked at
#   (house_item). Other chefs join in with "Talk to ...". A porch visit also
#   ends once everyone's walked off.
# Lines get "inside", "house_item", "gift_kind" and "gift" in their context.
# A visit isn't saved, but the knock is (quitting mid-visit still counts it).
class_name House
extends Node3D

enum Door { LOCKED, DARK, NOT_TONIGHT, AGAIN, OPEN, BUSY }

const FADE_NAME := "HouseFade"
const DOOR_SIZE := Vector2(0.95, 1.85)
const DOOR_OPEN_DEGREES := 100.0   # Swings in, out of sight.

var data: Dictionary = {}           # Its entry in data/houses.json.
var regular_id := ""

var _view_manager: ViewManager
var _size := Vector2(4.4, 4.0)
var _door_hinge: Node3D
var _door_spot := Interactable.new()
var _porch_figure: RegularFigure
var _porch_talk := Interactable.new()
var _windows: Array[MeshInstance3D] = []
var _window_lit: StandardMaterial3D
var _window_dark: StandardMaterial3D
var _porch_light: OmniLight3D
var _nameplate: Label3D
var _room: Node3D
var _room_size := Vector2(6.0, 5.0)
var _room_figure: RegularFigure
var _room_talk := Interactable.new()
var _exit := Interactable.new()
var _items: Array[Node3D] = []      # Their things, out from items_stage.
var _zoom := CameraZoomSettings.new()
var _room_zoom := CameraZoomSettings.new()  # Inside: steeper, to see over everyone's heads.
var _check_left := 0.0

# The visit going on, if any.
var _visiting := false
var _inside := false
var _moving := false                # Fading in or out.
var _ending := false
var _knocking := false              # A knock that's only answered through the door.
var _talking := {}                  # player_index -> true while talking to them (or looking at something).
var _gifts := {}                    # player_index -> gifts given this visit.
var _guests: Array[int] = []        # Who went in.


func _ready() -> void:
	var managers := get_tree().root.find_children("*", "ViewManager", true, false)
	_view_manager = managers.front() if not managers.is_empty() else null
	regular_id = String(data.get("regular", ""))
	position = _at(data.get("at", [0.0, 0.0]))
	var settings := Town.settings()
	_size = _vector2(settings.get("size", [4.4, 4.0]))
	_room_size = _vector2(settings.get("room", {}).get("size", [6.0, 5.0]))
	_zoom.distance = 3.4
	_zoom.pitch_degrees = 26.0
	_zoom.duration = 0.5
	_room_zoom.distance = 4.2
	_room_zoom.pitch_degrees = 48.0
	_room_zoom.duration = 0.5
	_build_outside()
	_build_room()
	_refresh()


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = 0.5
		_refresh()
		if _visiting and not _inside and not _moving and not _ending and _talking.is_empty() and not _anyone_near():
			_end_visit()  # They've all wandered off.


func record() -> Dictionary:
	return GameState.regulars.get(regular_id, {})


func regular_name() -> String:
	return record().get("name", regular_id.capitalize())


func is_unlocked() -> bool:
	return String(data.get("unlock", "")) in GameState.unlocks


func is_visiting() -> bool:
	return _visiting


func door_state() -> Door:
	var regular := record()
	var settings := Town.settings()
	if regular.is_empty():
		return Door.LOCKED
	var stage := RegularMemory.stage_of(regular)
	if Redemption.is_gone(regular) or stage <= int(settings.get("dark_stage", -3)):
		return Door.DARK
	if not is_unlocked():
		return Door.LOCKED
	if _visiting or _knocking:
		return Door.BUSY
	if stage < int(settings.get("porch_stage", 2)):
		return Door.NOT_TONIGHT
	if Town.visited_today(regular_id):
		return Door.AGAIN
	return Door.OPEN


# How a gift goes down: "favourite", "liked" or "other". Items are dish, fish
# or forage ids; "kind:fish" in their lists means any fish.
func gift_kind(item_id: String) -> String:
	if _wants(data.get("favourites", []), item_id):
		return "favourite"
	if _wants(data.get("likes", []), item_id):
		return "liked"
	return "other"


func _wants(list: Array, item_id: String) -> bool:
	return item_id in list or ("kind:" + Pantry.kind_of(item_id)) in list


# Windows, porch light, nameplate and their things, to match how they are.
func _refresh() -> void:
	var lit := door_state() != Door.DARK
	for window in _windows:
		window.material_override = _window_lit if lit else _window_dark
	_porch_light.visible = lit and is_unlocked()
	_nameplate.visible = is_unlocked()
	var regular := record()
	var show_items := not regular.is_empty() and RegularMemory.stage_of(regular) >= int(Town.settings().get("items_stage", 4))
	for item in _items:
		item.visible = show_items


# --- At the door ------------------------------------------------------------

func _door_prompt(player_index: int) -> String:
	var player := Player.find(get_tree(), player_index)
	if player == null or not DayCycle.doors_open() or not _is_free(player):
		return ""
	match door_state():
		Door.BUSY:
			return ""
		Door.LOCKED:
			return _text("knock", "Knock")
	var owner := regular_name() + ("'" if regular_name().ends_with("s") else "'s")
	return _text("knock_named", "Knock on {names} door").format({ "name": regular_name(), "names": owner })


func _on_door(player_index: int) -> void:
	if _door_prompt(player_index).is_empty():
		return
	var player := Player.find(get_tree(), player_index)
	match door_state():
		Door.LOCKED:
			await _answer_through_door(player, { "speaker": "", "text": _text("locked", "(It's locked.)"), "emotion": &"" })
		Door.DARK:
			await _answer_through_door(player, { "speaker": "", "text": _text("dark", "(Nobody answers.)"), "emotion": &"" })
		Door.NOT_TONIGHT:
			await _answer_through_door(player, _say("house_not_tonight", player_index))
		Door.AGAIN:
			await _answer_through_door(player, _say("house_again", player_index))
		Door.OPEN:
			_start_visit(player)


# A knock, a pause, and an answer through the closed door (or none).
func _answer_through_door(player: Player, line: Dictionary) -> void:
	_knocking = true
	_hold(player, _door_point())
	_play("knock")
	await _wait(float(Town.settings().get("knock_wait_seconds", 0.8)))
	var box := _open_box(player.player_index)
	await box.tell(line.get("speaker", regular_name()), line["text"], line["emotion"])
	box.close()
	_release(player)
	_knocking = false


func _start_visit(player: Player) -> void:
	var index := player.player_index
	_visiting = true
	_inside = false
	_ending = false
	_talking = { index: true }
	_gifts = {}
	_guests = []
	Town.mark_visited(regular_id)
	SaveGame.save_game()
	_hold(player, _door_point())
	_play("knock")
	await _wait(float(Town.settings().get("knock_wait_seconds", 0.8)))
	_swing_door(true)
	_porch_figure.visible = true
	await _wait(0.4)
	var greeting := _say("house_greeting", index)
	if RegularMemory.stage_of(record()) >= int(Town.settings().get("inside_stage", 3)):
		_porch_figure.talking = true
		var box := _open_box(index)
		await box.tell(regular_name(), greeting["text"], greeting["emotion"])
		box.close()
		_porch_figure.talking = false
		await _go_inside(index)
		greeting = _say("house_greeting", index)  # Settled in now ("inside").
	_talking.erase(index)
	await _talk(player, greeting)


# Another chef comes over to talk ("Talk to ...").
func _talk_prompt(player_index: int) -> String:
	var player := Player.find(get_tree(), player_index)
	if not _visiting or _moving or _ending or player == null or not _is_free(player) or _talking.has(player_index):
		return ""
	return _text("talk", "Talk to {name}").format({ "name": regular_name() })


func _on_talk(player_index: int, in_room: bool) -> void:
	if in_room != _inside or _talk_prompt(player_index).is_empty():
		return
	_talk(Player.find(get_tree(), player_index), _say("house_greeting", player_index))


# One chef talks with them, starting on `first`, until they say goodbye: Chat,
# Give a gift (while they've one left this visit) or Say goodbye.
func _talk(player: Player, first: Dictionary) -> void:
	if player == null:
		return
	var index := player.player_index
	_talking[index] = true
	var figure := _figure()
	figure.talking = true
	_hold(player, figure.global_position)
	var menu: Dictionary = Town.settings().get("menu", {})
	var per_visit := int(Town.settings().get("gifts", {}).get("gifts_per_visit", 1))
	var box := _open_box(index)
	var line := first
	while true:
		var options: Array = [menu.get("chat", "Chat")]
		var can_give := int(_gifts.get(index, 0)) < per_visit
		if can_give:
			options.append(menu.get("gift", "Give a gift"))
		options.append(menu.get("goodbye", "Say goodbye"))
		var picked := await box.ask(line.get("speaker", regular_name()), line["text"], options, line["emotion"])
		if _ending or picked == options.size() - 1:
			break  # Goodbye (theirs, or someone else's).
		if picked == 0:
			line = _say("house_chat", index)
		else:
			line = await _give(player, box, line)
	var farewell := _say("house_farewell", index)
	await box.tell(regular_name(), farewell["text"], farewell["emotion"])
	box.close()
	figure.talking = false
	_release(player)
	_talking.erase(index)
	_end_visit()


# Gifts come in a takeout bag (packed at the restaurant's takeout counter):
# offers what's in theirs, hands it over and returns the reaction, or `line`
# again if they changed their mind.
func _give(player: Player, box: ConversationBox, line: Dictionary) -> Dictionary:
	var bag := player.held_item as TakeoutBag
	if bag == null or bag.is_delivery():
		var why := "delivery_bag" if bag != null else "no_gifts"
		return { "speaker": "", "text": _text(why, "(Bring something in a takeout bag.)"), "emotion": &"" }
	var menu: Dictionary = Town.settings().get("menu", {})
	var options: Array = [_text("give", "Give the {gift}").format({ "gift": bag.contents_name() }), menu.get("never_mind", "Never mind")]
	var picked := await box.ask("", _text("gift_ask", "What will you give?"), options)
	return _hand_over(player, bag) if picked == 0 else line


func _hand_over(player: Player, bag: TakeoutBag) -> Dictionary:
	player.set_held_item(null)  # Pantry things left the pantry when they were packed.
	var kind := gift_kind(bag.contents_id())
	var gifts: Dictionary = Town.settings().get("gifts", {})
	var worth := int(gifts.get(kind + "_points", 0))
	var points := mini(worth, Town.gift_points_left(regular_id))
	if points > 0:
		RegularMemory.change_relationship(record(), points)
		Town.add_gift_points(regular_id, points)
		_pop(_text("points", "+{points} friendship").format({ "points": points }), Color(1.0, 0.55, 0.65))
	elif worth > 0:
		_pop(_text("capped", "That's plenty of presents for {name} today").format({ "name": regular_name() }), Color(0.9, 0.9, 0.9))
	_gifts[player.player_index] = int(_gifts.get(player.player_index, 0)) + 1
	SaveGame.save_game()
	return _say("house_gift", player.player_index, { "gift_kind": kind, "gift": bag.contents_name() })


# Words floating up over the regular (how much a gift meant).
func _pop(text: String, color: Color) -> void:
	FloatText.pop(self, _figure().global_position + Vector3(0.9, 1.3, 0.3), text, color)  # Beside them, clear of the nameplate.


# Looking at one of their things: they tell you about it.
func _item_prompt(player_index: int, item: Dictionary) -> String:
	var player := Player.find(get_tree(), player_index)
	if not _inside or _moving or _ending or player == null or not _is_free(player) or _talking.has(player_index):
		return ""
	if RegularMemory.stage_of(record()) < int(Town.settings().get("items_stage", 4)):
		return ""
	return _text("look", "Look at {item}").format({ "item": item.get("name", "it") })


func _on_item(player_index: int, item: Dictionary, node: Node3D) -> void:
	if _item_prompt(player_index, item).is_empty():
		return
	var player := Player.find(get_tree(), player_index)
	_talking[player_index] = true
	_room_figure.talking = true
	_hold(player, node.global_position)
	var line := _say("house_item", player_index, { "house_item": item.get("id", "") })
	var box := _open_box(player_index)
	await box.tell(regular_name(), line["text"], line["emotion"])
	box.close()
	_room_figure.talking = _talking.size() > 1
	_release(player)
	_talking.erase(player_index)


# The door inside: saying goodbye from there ends the visit too.
func _exit_prompt(player_index: int) -> String:
	var player := Player.find(get_tree(), player_index)
	if not _inside or _moving or _ending or player == null or not _is_free(player) or _talking.has(player_index):
		return ""
	return _text("leave", "Say goodbye")


func _on_exit(player_index: int) -> void:
	if _exit_prompt(player_index).is_empty():
		return
	var player := Player.find(get_tree(), player_index)
	_talking[player_index] = true
	_hold(player, _room_figure.global_position)
	_room_figure.talking = true
	var farewell := _say("house_farewell", player_index)
	var box := _open_box(player_index)
	await box.tell(regular_name(), farewell["text"], farewell["emotion"])
	box.close()
	_room_figure.talking = false
	_release(player)
	_talking.erase(player_index)
	_end_visit()


# --- In and out ---------------------------------------------------------------

# Everyone near the porch fades into the room with `starter`.
func _go_inside(starter: int) -> void:
	_moving = true
	var radius := float(Town.settings().get("porch_radius", 4.5))
	var guests: Array[int] = [starter]
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var other := node as Player
		if other.player_index != starter and _is_free(other) and _flat_distance(other.global_position, _door_point()) <= radius:
			guests.append(other.player_index)
			other.movement_locked = true
	_guests = guests
	await _fade(guests, true)
	_inside = true
	_porch_figure.visible = false
	_swing_door(false)
	var points := _room_points(guests.size())
	for i in guests.size():
		var guest := Player.find(get_tree(), guests[i])
		if guest != null:
			guest.release_camera_focus()
			_place(guest, points[i], PI)  # Facing into the room.
	await _snap_cameras(guests)
	await _fade(guests, false)
	for index in guests:
		var guest := Player.find(get_tree(), index)
		if guest != null and index != starter:
			guest.movement_locked = false
	_moving = false


# The visit's over: once everyone's finished talking, those inside come back
# out onto the porch, and the door closes.
func _end_visit() -> void:
	if _ending or not _visiting:
		return
	_ending = true
	while not _talking.is_empty():
		await get_tree().process_frame
	if _inside:
		_moving = true
		var guests: Array[int] = []
		for index in _guests:
			var guest := Player.find(get_tree(), index)
			if guest != null and _flat_distance(guest.global_position, _room.global_position) < 20.0:
				guests.append(index)
				guest.movement_locked = true
		await _fade(guests, true)
		_inside = false
		_swing_door(true)
		_porch_figure.visible = true
		var points := _porch_points(guests.size())
		for i in guests.size():
			var guest := Player.find(get_tree(), guests[i])
			if guest != null:
				guest.release_camera_focus()
				_place(guest, points[i], 0.0)  # Facing the street.
		await _snap_cameras(guests)
		await _fade(guests, false)
		for index in guests:
			var guest := Player.find(get_tree(), index)
			if guest != null:
				guest.movement_locked = false
		_moving = false
		await _wait(0.8)  # A wave from the door.
	_porch_figure.visible = false
	_porch_figure.talking = false
	_swing_door(false)
	_visiting = false
	_ending = false
	_guests = []


# Fade these chefs' views to black (or back).
func _fade(indices: Array[int], to_black: bool) -> void:
	var seconds := float(Town.settings().get("fade_seconds", 0.35))
	for index in indices:
		var view := _view_manager.view_for(index) if _view_manager != null else null
		if view == null:
			continue
		var cover: ColorRect = view.get_node_or_null(FADE_NAME)
		if cover == null:
			cover = ColorRect.new()
			cover.name = FADE_NAME
			cover.color = Color(0.0, 0.0, 0.0, 0.0)
			cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.add_child(cover)
		cover.create_tween().tween_property(cover, "color:a", 1.0 if to_black else 0.0, seconds)
	await _wait(seconds + 0.05)
	if not to_black:
		for index in indices:
			var view := _view_manager.view_for(index) if _view_manager != null else null
			var cover: Node = view.get_node_or_null(FADE_NAME) if view != null else null
			if cover != null:
				cover.queue_free()


# Their cameras jump to where they are now (their views may regroup the frame after).
func _snap_cameras(indices: Array[int]) -> void:
	for _pass in 3:
		for index in indices:
			var rig := _view_manager.rig_for(index) if _view_manager != null else null
			if rig != null:
				rig.snap()
		await get_tree().process_frame


func _place(player: Player, at: Vector3, facing: float) -> void:
	player.global_position = at + Vector3(0.0, 0.05, 0.0)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	player.visual.rotation.y = facing


# Just inside the room's door, side by side.
func _room_points(count: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i in count:
		points.append(_room.global_position + Vector3((i - (count - 1) / 2.0) * 0.8, 0.0, _room_size.y / 2.0 - 1.5))
	return points


# On the path in front of the porch, side by side.
func _porch_points(count: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i in count:
		points.append(_door_point() + Vector3((i - (count - 1) / 2.0) * 0.8, 0.0, 0.6))
	return points


# Debug: everyone to the front of the house, facing it.
func debug_send_everyone() -> void:
	var players := get_tree().get_nodes_in_group(Player.GROUP)
	var points := _porch_points(players.size())
	for i in players.size():
		_place(players[i], points[i], PI)


# --- Helpers ---------------------------------------------------------------------

# Their line for `event` to that chef: { text, emotion } (with a fallback if none fits).
func _say(event: String, player_index: int, extra: Dictionary = {}) -> Dictionary:
	var regular := record()
	if regular.is_empty():
		return { "text": "...", "emotion": &"" }
	var facts := { "inside": _inside, "house_item": "", "gift_kind": "", "gift": "" }
	facts.merge(extra, true)
	var line := RegularMemory.say_feeling(regular, event, RegularMemory.dialogue_context(regular, Accounts.id_of(player_index), facts))
	if String(line["text"]).is_empty():
		line["text"] = "..."
	return line


func _text(key: String, fallback: String) -> String:
	return String(Town.settings().get("text", {}).get(key, fallback))


func _figure() -> RegularFigure:
	return _room_figure if _inside else _porch_figure


func _door_point() -> Vector3:
	return _door_spot.global_position


func _anyone_near() -> bool:
	var radius := float(Town.settings().get("porch_radius", 4.5)) * 1.5
	return get_tree().get_nodes_in_group(Player.GROUP).any(func(p): return _flat_distance(p.global_position, _door_point()) <= radius)


func _is_free(player: Player) -> bool:
	return not player.movement_locked and not player.in_conversation() and not player.hidden_from_own_view


# Keep a chef in place with their camera in close, while they talk.
func _hold(player: Player, toward: Vector3) -> void:
	player.movement_locked = true
	player.interactor.lock_to(_door_spot)
	player.request_camera_focus((player.global_position + toward) * 0.5 + Vector3.UP * 1.0, _room_zoom if _inside else _zoom)


func _release(player: Player) -> void:
	if not is_instance_valid(player):
		return
	player.movement_locked = false
	player.interactor.unlock()
	player.release_camera_focus()
	player.ignore_interact_until_released()


func _open_box(player_index: int) -> ConversationBox:
	return ConversationBox.open(ConversationBox.parent_for(_view_manager, player_index, self), player_index, regular_id)


func _swing_door(open: bool) -> void:
	var tween := _door_hinge.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_door_hinge, "rotation:y", deg_to_rad(DOOR_OPEN_DEGREES) if open else 0.0, 0.5)


func _play(sound: String) -> void:
	var sound_player := AudioStreamPlayer3D.new()
	sound_player.stream = CookSounds.get_sound(sound)
	sound_player.unit_size = 6.0
	sound_player.position = Vector3(0.0, 1.2, _size.y / 2.0)
	add_child(sound_player)
	sound_player.play()
	sound_player.finished.connect(sound_player.queue_free)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _at(xz: Array) -> Vector3:
	return Vector3(float(xz[0]), 0.0, float(xz[1]))


static func _vector2(pair: Array) -> Vector2:
	return Vector2(float(pair[0]), float(pair[1]))


static func _color(hex: Variant, fallback: Color) -> Color:
	return Color.from_string(String(hex), fallback) if hex != null else fallback


func _model_path(model: String) -> String:
	var parts := model.split("/", true, 1)
	if parts.size() < 2:
		return ""
	return String(Town.settings().get("model_dirs", {}).get(parts[0], "")) + parts[1] + ".gltf"


# --- Building it ---------------------------------------------------------------------

func _build_outside() -> void:
	var settings := Town.settings()
	var look: Dictionary = data.get("look", {})
	var walls := _color(look.get("walls"), Color(0.85, 0.8, 0.7))
	var trim := _color(look.get("trim"), Color(0.95, 0.93, 0.88))
	var height := float(settings.get("wall_height", 2.4))
	var roof_height := float(settings.get("roof_height", 1.3))
	var front := _size.y / 2.0

	var body := StaticBody3D.new()
	body.name = "Walls"
	add_child(body)
	_collider(body, Vector3(0.0, 1.5, 0.0), Vector3(_size.x, 3.0, _size.y))
	_box(self, Vector3(0.0, height / 2.0, 0.0), Vector3(_size.x, height, _size.y), walls)
	_box(self, Vector3(0.0, 0.12, 0.0), Vector3(_size.x + 0.08, 0.24, _size.y + 0.08), walls.darkened(0.3))  # Footing.
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(_size.x + 0.5, roof_height, _size.y + 0.5)
	prism.material = _material(_color(look.get("roof"), Color(0.5, 0.3, 0.25)))
	roof.mesh = prism
	roof.position = Vector3(0.0, height + roof_height / 2.0, 0.0)
	add_child(roof)
	_box(self, Vector3(_size.x * 0.22, height + roof_height * 0.55, -_size.y * 0.15), Vector3(0.4, roof_height * 1.1, 0.4), Color(0.55, 0.32, 0.25))  # Chimney.

	# The doorway (warm inside), the door on its hinge, a knob.
	_box(self, Vector3(0.0, DOOR_SIZE.y / 2.0, front + 0.005), Vector3(DOOR_SIZE.x, DOOR_SIZE.y, 0.01), Color(0.35, 0.24, 0.14))
	_box(self, Vector3(0.0, DOOR_SIZE.y + 0.06, front + 0.02), Vector3(DOOR_SIZE.x + 0.2, 0.12, 0.04), trim)
	_door_hinge = Node3D.new()
	_door_hinge.name = "DoorHinge"
	_door_hinge.position = Vector3(-DOOR_SIZE.x / 2.0, 0.0, front + 0.03)
	add_child(_door_hinge)
	_box(_door_hinge, Vector3(DOOR_SIZE.x / 2.0, DOOR_SIZE.y / 2.0, 0.0), Vector3(DOOR_SIZE.x, DOOR_SIZE.y, 0.05), _color(look.get("door"), Color(0.45, 0.3, 0.2)))
	var knob := _sphere(_door_hinge, Vector3(DOOR_SIZE.x * 0.82, 0.95, 0.04), 0.04, Color(0.85, 0.7, 0.3))
	knob.name = "Knob"

	# Windows either side, with sills (and flower boxes, if they have them).
	_window_lit = _material(Color(1.0, 0.86, 0.55))
	_window_lit.emission_enabled = true
	_window_lit.emission = Color(1.0, 0.78, 0.45)
	_window_lit.emission_energy_multiplier = 1.3
	_window_dark = _material(Color(0.12, 0.13, 0.18))
	for side in [-1.0, 1.0]:
		var x: float = side * _size.x * 0.3
		_box(self, Vector3(x, 1.45, front + 0.01), Vector3(0.86, 0.76, 0.02), trim)
		var window := _box(self, Vector3(x, 1.45, front + 0.025), Vector3(0.72, 0.62, 0.02), Color.WHITE)
		_windows.append(window)
		_box(self, Vector3(x, 1.45, front + 0.04), Vector3(0.04, 0.62, 0.01), trim)  # Crossbars.
		_box(self, Vector3(x, 1.45, front + 0.04), Vector3(0.72, 0.04, 0.01), trim)
		_box(self, Vector3(x, 1.08, front + 0.06), Vector3(0.9, 0.05, 0.12), trim)
		if look.has("window_boxes"):
			_box(self, Vector3(x, 0.98, front + 0.1), Vector3(0.82, 0.16, 0.18), Color(0.45, 0.3, 0.2))
			for i in 5:
				_sphere(self, Vector3(x - 0.32 + i * 0.16, 1.1, front + 0.1), 0.06, _color(look.get("window_boxes"), Color.PINK) if i % 2 == 0 else Color(0.4, 0.65, 0.3))

	# Patches (Stitches mends everything, his house too).
	for patch: Dictionary in look.get("patches", []):
		var at: Array = patch.get("at", [0.0, 1.0])
		var size: Array = patch.get("size", [0.5, 0.5])
		var color := _color(patch.get("color"), Color(0.9, 0.7, 0.6))
		_box(self, Vector3(float(at[0]), float(at[1]), front + 0.012), Vector3(float(size[0]) + 0.05, float(size[1]) + 0.05, 0.01), color.darkened(0.35))
		_box(self, Vector3(float(at[0]), float(at[1]), front + 0.02), Vector3(float(size[0]), float(size[1]), 0.012), color)

	# Cheddar's: lights along the roof's edges and a star on top.
	if look.get("string_lights", false):
		var colors := [Color(1.0, 0.3, 0.3), Color(1.0, 0.85, 0.3), Color(0.4, 0.9, 0.4), Color(0.4, 0.6, 1.0)]
		var half := (_size.x + 0.5) / 2.0
		var count := 9
		for side in [-1.0, 1.0]:
			for i in count:
				var t := float(i) / count
				var bulb := _sphere(self, Vector3(side * half * (1.0 - t), height + roof_height * t - 0.06, front + 0.27), 0.05, colors[(i + (0 if side < 0 else 2)) % colors.size()])
				var glow: StandardMaterial3D = bulb.mesh.material
				glow.emission_enabled = true
				glow.emission = glow.albedo_color
				glow.emission_energy_multiplier = 2.0
	if look.has("star"):
		var star := MeshInstance3D.new()
		star.mesh = _star_mesh(0.32, _color(look.get("star"), Color.GOLD))
		star.position = Vector3(0.0, height + roof_height + 0.25, front + 0.27)
		add_child(star)

	# Porch: a step, a light by the door, their name over it.
	_box(self, Vector3(0.0, 0.05, front + 0.55), Vector3(1.8, 0.1, 1.1), Color(0.6, 0.47, 0.35))
	var lamp := _box(self, Vector3(DOOR_SIZE.x / 2.0 + 0.25, 1.9, front + 0.06), Vector3(0.14, 0.2, 0.1), Color(1.0, 0.9, 0.6))
	var lamp_material: StandardMaterial3D = lamp.mesh.material
	lamp_material.emission_enabled = true
	lamp_material.emission = Color(1.0, 0.8, 0.5)
	_porch_light = OmniLight3D.new()
	_porch_light.light_color = Color(1.0, 0.82, 0.55)
	_porch_light.light_energy = 1.2
	_porch_light.omni_range = 4.0
	_porch_light.position = Vector3(0.0, 2.1, front + 0.6)
	add_child(_porch_light)
	_nameplate = Label3D.new()
	_nameplate.text = regular_name()
	_nameplate.font_size = 56
	_nameplate.pixel_size = 0.004
	_nameplate.outline_size = 12
	_nameplate.modulate = trim
	_nameplate.outline_modulate = walls.darkened(0.6)
	_nameplate.position = Vector3(0.0, DOOR_SIZE.y + 0.3, front + 0.05)
	add_child(_nameplate)

	for decor: Dictionary in data.get("decor", []):
		var fit := ModelFit.place(_model_path(String(decor.get("model", ""))), self, _at(decor.get("at", [0.0, 0.0])), Vector3(float(decor.get("size", 1.0)), 0.0, 0.0))
		if fit != null:
			fit.rotation_degrees.y = float(decor.get("turn", 0.0))

	_door_spot.position = Vector3(0.0, 0.0, front + 0.9)
	_door_spot.radius = 1.3
	_door_spot.prompt_for_player = _door_prompt
	_door_spot.interacted.connect(_on_door)
	add_child(_door_spot)
	_porch_figure = RegularFigure.make(regular_id)
	_porch_figure.position = Vector3(0.0, 0.1, front + 0.3)
	_porch_figure.visible = false
	add_child(_porch_figure)
	_porch_talk.position = Vector3(0.0, 0.0, front + 1.0)
	_porch_talk.radius = 1.5
	_porch_talk.priority = 1
	_porch_talk.prompt_for_player = func(index: int) -> String: return _talk_prompt(index) if not _inside else ""
	_porch_talk.interacted.connect(_on_talk.bind(false))
	add_child(_porch_talk)


# The room inside, far from everything (inside_at), open at the front so the
# camera sees in over a low wall.
func _build_room() -> void:
	var settings: Dictionary = Town.settings().get("room", {})
	var room_data: Dictionary = data.get("room", {})
	_room = Node3D.new()
	_room.name = "Room"
	_room.top_level = true
	add_child(_room)
	_room.global_position = _at(data.get("inside_at", [200.0, 0.0]))
	var height := float(settings.get("wall_height", 2.6))
	var low := float(settings.get("front_wall_height", 0.5))
	var door_width := float(settings.get("door_width", 1.3))
	var half := _room_size / 2.0
	var walls := _color(room_data.get("walls"), Color(0.9, 0.86, 0.78))

	var body := StaticBody3D.new()
	body.name = "RoomWalls"
	_room.add_child(body)
	_collider(body, Vector3(0.0, -0.1, 0.0), Vector3(_room_size.x + 4.0, 0.2, _room_size.y + 4.0))
	_collider(body, Vector3(0.0, 1.5, -half.y - 0.1), Vector3(_room_size.x, 3.0, 0.2))
	_collider(body, Vector3(0.0, 1.5, half.y + 0.1), Vector3(_room_size.x, 3.0, 0.2))
	for side in [-1.0, 1.0]:
		_collider(body, Vector3(side * (half.x + 0.1), 1.5, 0.0), Vector3(0.2, 3.0, _room_size.y))

	_box(_room, Vector3(0.0, -0.08, 0.0), Vector3(40.0, 0.1, 40.0), Color(0.15, 0.18, 0.13))  # The dark yard round it.
	_box(_room, Vector3(0.0, -0.05, 0.0), Vector3(_room_size.x, 0.1, _room_size.y), _color(room_data.get("floor"), Color(0.6, 0.45, 0.3)))
	_box(_room, Vector3(0.0, height / 2.0, -half.y - 0.075), Vector3(_room_size.x + 0.3, height, 0.15), walls)
	for side in [-1.0, 1.0]:
		_box(_room, Vector3(side * (half.x + 0.075), height / 2.0, 0.0), Vector3(0.15, height, _room_size.y), walls.darkened(0.08))
		var piece := (_room_size.x - door_width) / 2.0
		_box(_room, Vector3(side * (door_width / 2.0 + piece / 2.0), low / 2.0, half.y + 0.075), Vector3(piece + 0.15, low, 0.15), walls.darkened(0.15))
	_box(_room, Vector3(0.0, 0.005, half.y - 0.35), Vector3(1.0, 0.01, 0.55), Color(0.55, 0.36, 0.24))  # Doormat.
	var light := OmniLight3D.new()
	light.light_color = _color(room_data.get("light"), Color(1.0, 0.85, 0.65))
	light.light_energy = 1.6
	light.omni_range = maxf(_room_size.x, _room_size.y) * 1.3
	light.position = Vector3(0.0, height - 0.3, 0.3)
	_room.add_child(light)

	for thing: Dictionary in room_data.get("furniture", []):
		var at := _at(thing.get("at", [0.0, 0.0])) + Vector3(0.0, float(thing.get("height", 0.0)), 0.0)
		var fit := ModelFit.place(_model_path(String(thing.get("model", ""))), _room, at, Vector3(float(thing.get("size", 1.0)), 0.0, 0.0))
		if fit != null:
			fit.rotation_degrees.y = float(thing.get("turn", 0.0))

	_room_figure = RegularFigure.make(regular_id)
	_room_figure.position = _at(room_data.get("regular_at", [0.0, -1.0]))
	_room.add_child(_room_figure)
	_room_talk.position = _room_figure.position + Vector3(0.0, 0.0, 0.8)
	_room_talk.radius = 1.3
	_room_talk.priority = 1
	_room_talk.prompt_for_player = func(index: int) -> String: return _talk_prompt(index) if _inside else ""
	_room_talk.interacted.connect(_on_talk.bind(true))
	_room.add_child(_room_talk)

	for item: Dictionary in room_data.get("items", []):
		var node := _build_item(item)
		_items.append(node)
		var spot := Interactable.new()
		spot.position = Vector3(node.position.x, 0.0, minf(node.position.z + 0.8, half.y - 0.7))
		spot.radius = 1.0
		spot.prompt_for_player = _item_prompt.bind(item)
		spot.interacted.connect(_on_item.bind(item, node))
		node.visibility_changed.connect(func(): spot.enabled = node.visible)
		_room.add_child(spot)

	_exit.position = Vector3(0.0, 0.0, half.y - 0.2)
	_exit.radius = 0.75
	_exit.prompt_for_player = _exit_prompt
	_exit.interacted.connect(_on_exit)
	_room.add_child(_exit)


# One of their things: a model, or a shape made here (sign, poster, trophy, sewing_kit, teddy).
func _build_item(item: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = "Item_" + String(item.get("id", ""))
	node.position = _at(item.get("at", [0.0, 0.0])) + Vector3(0.0, float(item.get("height", 0.0)), 0.0)
	node.rotation_degrees.y = float(item.get("turn", 0.0))
	_room.add_child(node)
	var size := float(item.get("size", 0.3))
	var color := _color(item.get("color"), Color(0.7, 0.3, 0.25))
	match String(item.get("shape", "")):
		"sign":
			_box(node, Vector3(0.0, size * 0.15, 0.0), Vector3(size, size * 0.3, 0.05), color)
			_box(node, Vector3(0.0, size * 0.15, 0.015), Vector3(size * 0.94, size * 0.24, 0.03), color.darkened(0.25))
			_label(node, String(item.get("text", "")), Vector3(0.0, size * 0.15, 0.04), size * 0.85, Color(1.0, 0.93, 0.75))
		"poster":
			_box(node, Vector3(0.0, size * 0.5, 0.0), Vector3(size * 0.72, size, 0.02), Color(0.95, 0.85, 0.4))
			_box(node, Vector3(0.0, size * 0.5, 0.008), Vector3(size * 0.64, size * 0.92, 0.02), color)
			_star(node, Vector3(0.0, size * 0.78, 0.022), size * 0.1, Color(1.0, 0.85, 0.3))
			_label(node, String(item.get("text", "")), Vector3(0.0, size * 0.42, 0.022), size * 0.58, Color(1.0, 0.92, 0.6))
		"trophy":
			var gold := Color(0.95, 0.75, 0.25)
			_box(node, Vector3(0.0, size * 0.08, 0.0), Vector3(size * 0.55, size * 0.16, size * 0.55), Color(0.3, 0.2, 0.14))
			_cylinder(node, Vector3(0.0, size * 0.32, 0.0), size * 0.06, size * 0.06, size * 0.32, gold, true)
			_cylinder(node, Vector3(0.0, size * 0.7, 0.0), size * 0.38, size * 0.14, size * 0.45, gold, true)
			for side in [-1.0, 1.0]:
				var handle := MeshInstance3D.new()
				var torus := TorusMesh.new()
				torus.inner_radius = size * 0.08
				torus.outer_radius = size * 0.13
				torus.material = _shiny(gold)
				handle.mesh = torus
				handle.position = Vector3(side * size * 0.4, size * 0.72, 0.0)
				handle.rotation_degrees.x = 90.0
				node.add_child(handle)
		"sewing_kit":
			_cylinder(node, Vector3(0.0, size * 0.15, 0.0), size * 0.45, size * 0.4, size * 0.3, Color(0.69, 0.53, 0.31))
			_sphere(node, Vector3(-size * 0.12, size * 0.38, 0.0), size * 0.2, Color(0.78, 0.22, 0.2))
			for i in 4:  # Pins in the cushion.
				var pin := _cylinder(node, Vector3(-size * 0.12 + (i - 1.5) * size * 0.07, size * 0.55, (i % 2) * size * 0.05), size * 0.012, size * 0.012, size * 0.14, Color(0.85, 0.85, 0.9))
				pin.rotation_degrees.z = (i - 1.5) * 18.0
			for i in 3:  # Spools of thread.
				_cylinder(node, Vector3(size * (0.22 + i * 0.08), size * 0.38, size * (0.15 - i * 0.15)), size * 0.08, size * 0.08, size * 0.17, [Color(0.3, 0.45, 0.85), Color(0.95, 0.8, 0.3), Color(0.4, 0.75, 0.45)][i])
		"teddy":
			var fur := Color(0.61, 0.42, 0.26)
			var body := _sphere(node, Vector3(0.0, size * 0.35, 0.0), size * 0.35, fur)
			body.scale = Vector3(1.0, 1.1, 0.9)
			_sphere(node, Vector3(0.0, size * 0.88, 0.0), size * 0.26, fur)
			for side in [-1.0, 1.0]:
				_sphere(node, Vector3(side * size * 0.19, size * 1.08, 0.0), size * 0.09, fur.darkened(0.2))
				_sphere(node, Vector3(side * size * 0.33, size * 0.45, size * 0.08), size * 0.12, fur)  # Arms.
				_sphere(node, Vector3(side * size * 0.2, size * 0.1, size * 0.22), size * 0.13, fur)    # Feet.
				_sphere(node, Vector3(side * size * 0.09, size * 0.95, size * 0.22), size * 0.03, Color(0.08, 0.06, 0.05))  # Eyes.
			_sphere(node, Vector3(0.0, size * 0.83, size * 0.22), size * 0.09, Color(0.85, 0.7, 0.5))  # Snout.
			_box(node, Vector3(size * 0.08, size * 0.38, size * 0.3), Vector3(size * 0.2, size * 0.18, 0.02), Color(0.43, 0.63, 0.78))  # Patches.
			_box(node, Vector3(-size * 0.12, size * 0.98, size * 0.2), Vector3(size * 0.12, size * 0.1, 0.02), Color(0.9, 0.76, 0.36))
		_:
			var fit := ModelFit.place(_model_path(String(item.get("model", ""))), node, Vector3.ZERO, Vector3(size, 0.0, 0.0))
			if fit == null:
				_box(node, Vector3(0.0, size * 0.5, 0.0), Vector3.ONE * size, color)
	return node


func _collider(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	node.mesh = mesh
	node.position = at
	parent.add_child(node)
	return node


func _sphere(parent: Node3D, at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = _material(color)
	node.mesh = mesh
	node.position = at
	parent.add_child(node)
	return node


func _cylinder(parent: Node3D, at: Vector3, top: float, bottom: float, height: float, color: Color, shiny := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	mesh.material = _shiny(color) if shiny else _material(color)
	node.mesh = mesh
	node.position = at
	parent.add_child(node)
	return node


func _star(parent: Node3D, at: Vector3, radius: float, color: Color) -> void:
	var star := MeshInstance3D.new()
	star.mesh = _star_mesh(radius, color)
	star.position = at
	parent.add_child(star)


# A flat five-pointed star facing +z, glowing a little.
func _star_mesh(radius: float, color: Color) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var from := PI / 2.0 + i * TAU / 10.0
		var to := PI / 2.0 + (i + 1) * TAU / 10.0
		var from_radius := radius if i % 2 == 0 else radius * 0.45
		var to_radius := radius if i % 2 == 1 else radius * 0.45
		tool.add_vertex(Vector3.ZERO)
		tool.add_vertex(Vector3(cos(to) * to_radius, sin(to) * to_radius, 0.0))
		tool.add_vertex(Vector3(cos(from) * from_radius, sin(from) * from_radius, 0.0))
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	tool.set_material(material)
	return tool.commit()


# Text across a board, sized to fit `width`.
func _label(parent: Node3D, text: String, at: Vector3, width: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.outline_size = 0
	var longest := 1
	for line in text.split("\n"):
		longest = maxi(longest, line.length())
	label.pixel_size = width / (longest * label.font_size * 0.62)
	label.modulate = color
	label.position = at
	parent.add_child(label)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


func _shiny(color: Color) -> StandardMaterial3D:
	var material := _material(color)
	material.metallic = 0.8
	material.roughness = 0.25
	return material
