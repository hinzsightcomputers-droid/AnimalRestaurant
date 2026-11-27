# DeliveryDrive: a chef drives the night's deliveries in the restaurant's cart
# (DeliveryCar). Seen from just behind the driver's seat, the chef at the wheel,
# the lane and the woodland cottages rolling toward you. A prompt says which
# way to turn at the next crossroads ("Turn left!"); press that way before you
# get there and the cart takes the corner. Miss it and you carry straight on
# and go round the block: the next crossroads asks again, a little later,
# never a penalty. After each order's last turn the house is on the right: the
# cart pulls up, the chef carries the bag to the door and the person who
# ordered says thanks (paid as at the counter, plus a tip for bringing it).
# Then on to the next, and back home. Shown in the driver's own view (the
# whole screen when they're the only chef); the others carry on cooking.
# data/phone.json "drive" holds the numbers and the placeholder door lines.
class_name DeliveryDrive
extends Node

signal shown
signal finished

const FADE_SECONDS := 0.4
const BLOCK := 34.0          # Meters from one crossroads to the next.
const ROAD_WIDTH := 5.0
const TURN_RADIUS := 3.0
const LOT_AT := 0.6          # How far along a street its empty lot is (where a delivery's house goes).
const HOUSE_KINDS := ["wood_cottage_thatch", "wood_cottage_mushroom", "wood_cottage_stump", "wood_cottage_stone", "wood_cottage_mill", "wood_cottage_shop"]
const SEAT := Vector3(0.0, 0.0, 0.25)  # Where the driver sits, in the cart.

var view_manager: ViewManager
var player_index := 0
var bags: Array = []          # TakeoutBags, in delivery order.
var manager: DeliveryManager  # null in tests: nothing is paid.
var autopilot := false        # Tests: presses the right way by itself.
static var test_autopilot := false  # Tests in the whole game: every drive drives itself.

var _viewport := SubViewport.new()
var _layer: CanvasLayer = null
var _display: Control
var _box: ConversationBox
var _prompt: Label
var _list: Label
var _hint: Label
var _fade: ColorRect
var _world: Node3D
var _town: Node3D             # Everything outside the cart; it moves, the cart stays put.
var _cart: Node3D
var _driver: ChefModel
var _camera: Camera3D
var _rng := RandomNumberGenerator.new()

var _speed := 0.0
var _cruise := 8.0
var _to_go := 0.0             # Meters to the next crossroads' middle.
var _arm: Node3D              # The street being driven down.
var _arms_ahead := {}         # The next crossroads' streets: { -1: left, 0: straight, 1: right }.
var _behind: Array[Node3D] = []
var _want := 0                # The turn the prompt asks for (-1 left, 1 right).
var _pressed := 0             # The way the driver last pressed before the corner.
var _turning := false
var _stopping := false
var _stop_at := INF           # Meters along the street to pull up at (the delivery's lot).
var _along := 0.0             # Meters along the current street.
var _delivered: Array[String] = []
var _parcels: Array[MeshInstance3D] = []


func settings() -> Dictionary:
	return GameData.phone_settings.get("drive", {})


func _ready() -> void:
	_rng.seed = Time.get_ticks_usec()
	autopilot = autopilot or test_autopilot
	_cruise = float(settings().get("speed", 8.0))
	_viewport.own_world_3d = true
	_viewport.size = Vector2i(get_viewport().get_visible_rect().size)
	add_child(_viewport)
	_build_world()
	var full := view_manager == null or get_tree().get_nodes_in_group(Player.GROUP).size() <= 1
	var parent: Node = null
	if not full:
		parent = view_manager.view_for(player_index)
	if parent == null:
		_layer = CanvasLayer.new()
		_layer.layer = 6  # Over the HUD and the Moober banner (5).
		add_child(_layer)
		parent = _layer
	_make_display(parent)
	_run()


func _run() -> void:
	_display.modulate.a = 0.0
	await create_tween().tween_property(_display, "modulate:a", 1.0, FADE_SECONDS).finished
	shown.emit()
	_lay_first_street()
	_show_list()
	_speed = _cruise
	for bag in bags:
		var turns := _rng.randi_range(int(settings().get("turns", [1, 2])[0]), int(settings().get("turns", [1, 2])[1]))
		var last := 0
		var same := 0
		while turns > 0:
			var way := -1 if _rng.randf() < 0.5 else 1
			if way == last and same >= 1:
				way = -way  # Never three corners the same way (you'd drive in a circle).
			same = same + 1 if way == last else 0
			last = way
			if await _crossroads(way):
				turns -= 1
		await _pull_up(bag)
	_prompt.text = "All delivered! Heading home."
	await _drive_for(BLOCK * 0.8)
	_fade.color.a = 0.0
	await create_tween().tween_property(_display, "modulate:a", 0.0, FADE_SECONDS).finished
	finished.emit()
	if _layer != null:
		_layer.queue_free()
	elif is_instance_valid(_display):
		_display.queue_free()
	queue_free()


func _process(delta: float) -> void:
	if _town == null:
		return
	var step := _speed * delta
	_town.position.z += step  # (In the world's own frame, whichever way the town is turned.)
	_to_go -= step
	_along += step
	if _driver != null:
		_cart.position.y = absf(sin(Time.get_ticks_msec() * 0.007)) * 0.025 * clampf(_speed / _cruise, 0.0, 1.0)
	if _want != 0:
		var left := Input.is_action_pressed(InputSetup.action_name(player_index, "move_left"))
		var right := Input.is_action_pressed(InputSetup.action_name(player_index, "move_right"))
		if autopilot and _to_go < 14.0:
			left = _want < 0
			right = _want > 0
		if left != right:
			_pressed = -1 if left else 1
			_prompt.text = _turn_text(_want) + ("  ✓" if _pressed == _want else "\nThe other way!")


# Up to the next crossroads, asking for `way`. True if they took it.
func _crossroads(way: int) -> bool:
	_want = way
	_pressed = 0
	while _to_go > float(settings().get("prompt_at", 26.0)):
		await get_tree().process_frame
	_prompt.text = _turn_text(way)
	var slow := float(settings().get("corner_speed", 4.5))
	while _to_go > TURN_RADIUS:
		_speed = lerpf(slow, _cruise, clampf((_to_go - TURN_RADIUS) / 14.0, 0.0, 1.0))
		await get_tree().process_frame
	var took := _pressed == way
	_want = 0
	_free_behind()
	if took:
		_prompt.text = ""
		await _turn(way)
	else:
		_prompt.text = String(settings().get("missed_text", "Missed it! Round the block we go."))
		_speed = _cruise * 0.85
		_take(0)
		get_tree().create_timer(2.5).timeout.connect(_clear_missed)
	return took


func _clear_missed() -> void:
	if is_instance_valid(_prompt) and _want == 0 and not _stopping:
		_prompt.text = ""


func _turn_text(way: int) -> String:
	return "⬅  Turn left!" if way < 0 else "Turn right!  ➡"


# Round the corner: the town swings about a point beside the cart, so it
# drives a quarter circle and comes out on the middle of the new street.
func _turn(way: int) -> void:
	_turning = true
	var keep_speed := _speed
	_speed = 0.0
	_town.position.z -= TURN_RADIUS - _to_go  # Exactly at the corner's start.
	_to_go = TURN_RADIUS
	var pivot := Vector3(way * TURN_RADIUS, 0.0, 0.0)
	var start := _town.transform
	var angle := way * PI / 2.0
	var seconds := (PI / 2.0 * TURN_RADIUS) / maxf(keep_speed, 1.0)
	var swing := func(t: float) -> void:
		var spin := Basis(Vector3.UP, angle * t)
		_town.transform = Transform3D(spin, pivot - spin * pivot) * start
		_driver.rotation.z = -way * sin(t * PI) * 0.12
		_camera.rotation.z = -way * sin(t * PI) * 0.03
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(swing, 0.0, 1.0, seconds)
	await tween.finished
	_to_go = -TURN_RADIUS  # Out of the corner, just past the crossroads' middle.
	_take(way)
	_speed = keep_speed
	_turning = false


# Onto one of the crossroads' streets: the next crossroads gets laid at its end.
func _take(way: int) -> void:
	for other in _arms_ahead:
		if other != way:
			_behind.append(_arms_ahead[other])
	if _arm != null:
		_behind.append(_arm)
	_arm = _arms_ahead.get(way)
	_along = -_to_go  # Meters past the crossroads' middle, where this street starts.
	_to_go += BLOCK
	_lay_crossroads(_here() + _heading() * _to_go, _heading())


func _free_behind() -> void:
	for node in _behind:
		if is_instance_valid(node):
			node.queue_free()
	_behind.clear()


# Pulls up by the lot on this street, puts the house there, and hands over.
func _pull_up(bag: TakeoutBag) -> void:
	_stopping = true
	var caller: Dictionary = bag.dish.order.caller
	if _along > BLOCK * LOT_AT - 6.0:  # Too close to stop: the lot on the next street, then.
		await _crossroads_straight()
	var lot := _here() + _heading() * (BLOCK * LOT_AT - _along) + _heading().cross(Vector3.UP) * (ROAD_WIDTH / 2.0 + 4.0)
	var door := _build_destination(lot, caller)
	_prompt.text = "%s's house!" % caller.get("name", "?")
	var slow_from := BLOCK * LOT_AT - _along
	while _along < BLOCK * LOT_AT - 1.2:
		var left := BLOCK * LOT_AT - 1.2 - _along
		_speed = maxf(1.0, _cruise * clampf(left / maxf(slow_from, 0.1), 0.0, 1.0))
		await get_tree().process_frame
	_speed = 0.0
	await _doorstep(bag, door, caller)
	_delivered.append(caller.get("name", "?"))
	_show_list()
	_prompt.text = ""
	_stopping = false
	_speed = _cruise


func _crossroads_straight() -> void:
	while _to_go > TURN_RADIUS:
		await get_tree().process_frame
	_free_behind()
	_take(0)


func _drive_for(meters: float) -> void:
	var start := _along
	_speed = _cruise
	while _along - start < meters and _to_go > TURN_RADIUS + 1.0:
		await get_tree().process_frame


# The chef gets out, takes the bag to the door, and is thanked.
func _doorstep(bag: TakeoutBag, door: Dictionary, caller: Dictionary) -> void:
	await _fade_to(1.0)
	var walker := ChefModel.new()
	walker.height = _driver.height
	_town.add_child(walker)
	walker.apply_appearance(Accounts.appearance_of(player_index))
	walker.carrying = true
	if not _parcels.is_empty():
		_parcels.pop_back().queue_free()
	var parcel := CottageDressing._box(walker, Vector3(0.0, 0.78, 0.32), Vector3(0.3, 0.32, 0.24), Color("E8D2A6"))
	_hint.visible = false
	var stand: Vector3 = door["stand"]
	var start := _here() + _heading().cross(Vector3.UP) * 1.2
	walker.position = start
	walker.rotation.y = _facing(stand - start)
	_driver.visible = false
	var camera_at: Vector3 = _here() - _heading() * 3.5 + Vector3.UP * 2.6 - _heading().cross(Vector3.UP) * 1.5
	var look_camera := Camera3D.new()
	look_camera.fov = 50.0
	_town.add_child(look_camera)
	look_camera.look_at_from_position(_town.to_global(camera_at), _town.to_global((start + stand) * 0.5 + Vector3.UP * 0.8))
	look_camera.make_current()
	await _fade_to(0.0)
	var seconds := start.distance_to(stand) / 1.4
	await create_tween().tween_property(walker, "position", stand, seconds).finished
	walker.rotation.y = _facing(door["figure"].position - stand)
	walker.carrying = false
	parcel.queue_free()
	(door["figure"] as RegularFigure).talking = true
	var amount := 0
	if manager != null:
		amount = manager.pay(player_index, bag.dish, float(settings().get("tip_share", 0.15)))
	var line := _door_line(caller, bag)
	_box = ConversationBox.open(_display, player_index, caller.get("regular_id", ""))
	await _box.tell(caller.get("name", "?"), line)
	_box.close()
	(door["figure"] as RegularFigure).talking = false
	if manager != null:
		GameEvents.announce("Delivered %s's %s yourself. +$%d (tip included)" % [caller.get("name", "?"), bag.contents_name(), amount])
	await create_tween().tween_property(walker, "position", start, seconds).finished
	await _fade_to(1.0)
	walker.queue_free()
	look_camera.queue_free()
	_camera.make_current()
	_driver.visible = true
	_hint.visible = true
	await _fade_to(0.0)


# What they say at the door: their own "delivery_door" line when they have one
# (the user writes these), or one of the placeholders in data/phone.json.
func _door_line(caller: Dictionary, bag: TakeoutBag) -> String:
	var chef_id := Accounts.id_of(player_index)
	var context := { "dish": bag.contents_name(), "restaurant": GameState.restaurant_name if not GameState.restaurant_name.is_empty() else "the restaurant" }
	var text := ""
	var record: Dictionary = GameState.regulars.get(caller.get("regular_id", ""), {})
	if not record.is_empty():
		var regular_context := RegularMemory.dialogue_context(record, chef_id, context)
		text = DialoguePicker.fill(RegularMemory.pick_line(record, "delivery_door", regular_context).get("text", ""), regular_context)
	elif caller.get("kind", "") == "townsfolk":
		text = Townsfolk.line(caller.get("id", ""), "delivery_door", context, chef_id)
	if text.is_empty():
		var options: Array = settings().get("door_lines", ["Oh, it's here! Thank you!"])
		text = String(options[_rng.randi() % options.size()]).format(context)
	return text


# The turn (about y) that has a model facing `toward` (models face +z).
func _facing(toward: Vector3) -> float:
	return atan2(toward.x, toward.z)


func _fade_to(alpha: float) -> void:
	await create_tween().tween_property(_fade, "color:a", alpha, 0.35).finished


# --- The town ---------------------------------------------------------------

func _here() -> Vector3:  # Where the cart is, in the town's own space.
	return _town.transform.affine_inverse() * Vector3.ZERO


func _heading() -> Vector3:  # Which way the cart faces, in the town's own space (always along an axis).
	var ahead := _town.basis.inverse() * Vector3.FORWARD
	return Vector3(roundf(ahead.x), 0.0, roundf(ahead.z))


func _lay_first_street() -> void:
	_arm = _lay_street(Vector3(0.0, 0.0, 8.0), Vector3.FORWARD, BLOCK * 0.7 + 8.0, false)
	_to_go = BLOCK * 0.7
	_along = 8.0
	_lay_crossroads(Vector3(0.0, 0.0, -_to_go), Vector3.FORWARD)


# A crossroads at `middle` (the cart coming along `heading`): its square and
# the three streets out of it.
func _lay_crossroads(middle: Vector3, heading: Vector3) -> void:
	var right := heading.cross(Vector3.UP)
	_arms_ahead = {
		-1: _lay_street(middle, -right, BLOCK, true),
		0: _lay_street(middle, heading, BLOCK, true),
		1: _lay_street(middle, right, BLOCK, true),
	}
	var square := CottageDressing._box(_arms_ahead[0], middle + Vector3(0.0, 0.006, 0.0), Vector3(ROAD_WIDTH, 0.02, ROAD_WIDTH), Color("A27F5C"))
	square.name = "Square"
	# A signpost on the corner, for something to look at while you wait for it.
	var post := WoodPiece.make("wood_lantern_post", _arms_ahead[0], middle - heading * (ROAD_WIDTH / 2.0 + 0.6) + right * (ROAD_WIDTH / 2.0 + 0.6), 2.6)
	if post != null:
		_light(_arms_ahead[0], middle - heading * (ROAD_WIDTH / 2.0 + 0.6) + right * (ROAD_WIDTH / 2.0 + 0.6) + Vector3.UP * 2.4)


# A street from `from` along `along`, `length` long: the dirt road, cottages
# both sides facing it (leaving the empty lot on the right), trees and a
# lantern or two. `from_corner`: it starts at a crossroads, so the road starts
# past the square.
func _lay_street(from: Vector3, along: Vector3, length: float, from_corner: bool) -> Node3D:
	var street := Node3D.new()
	street.name = "Street"
	_town.add_child(street)
	var right := along.cross(Vector3.UP)
	var start := ROAD_WIDTH / 2.0 if from_corner else 0.0
	var road_length := length - start - ROAD_WIDTH / 2.0
	var middle := from + along * (start + road_length / 2.0)
	var size := Vector3(ROAD_WIDTH, 0.02, road_length) if absf(along.z) > 0.5 else Vector3(road_length, 0.02, ROAD_WIDTH)
	CottageDressing._box(street, middle, size, Color("A27F5C"))
	var shapes := Node3D.new()
	street.add_child(shapes)
	var mark := start + 1.0
	while mark < start + road_length - 1.0:  # Pebbles down the middle, so you can see it move.
		CottageDressing._box(shapes, from + along * mark + right * _rng.randf_range(-1.2, 1.2) + Vector3.UP * 0.02, Vector3(0.4, 0.03, 0.3), Color("7E6046"))
		mark += _rng.randf_range(2.5, 4.0)
	for side in [-1.0, 1.0]:  # Mossy verges.
		CottageDressing._box(shapes, middle + right * side * (ROAD_WIDTH / 2.0 + 0.4) + Vector3.UP * 0.01, Vector3(0.8, 0.03, road_length) if absf(along.z) > 0.5 else Vector3(road_length, 0.03, 0.8), Color("6F8F4A"))
	MeshMerge.merge(shapes, false)
	var at := start + 7.0
	var lot := length * LOT_AT
	while at < length - 6.0:
		for side in [-1.0, 1.0]:
			if side > 0.0 and absf(at - lot) < 6.0:
				CottageDressing._box(street, from + along * at + right * (ROAD_WIDTH / 2.0 + 4.0) + Vector3.UP * 0.02, Vector3(4.0, 0.03, 4.0), Color("7FA35A"))  # The empty lot.
				continue
			var house_at: Vector3 = from + along * at + right * side * (ROAD_WIDTH / 2.0 + 4.2 + _rng.randf_range(0.0, 1.0))
			var facing: Vector3 = -right * side
			WoodPiece.make(HOUSE_KINDS[_rng.randi() % HOUSE_KINDS.size()], street, house_at, 0.0, atan2(facing.x, facing.z))
			if _rng.randf() < 0.7:
				var tree := "wood_tree_oak" if _rng.randf() < 0.5 else ("wood_tree_pine" if _rng.randf() < 0.5 else "wood_tree_birch")
				WoodPiece.make(tree, street, house_at + along * 4.4 + right * side * 2.5, _rng.randf_range(3.5, 5.0))
		at += _rng.randf_range(8.5, 10.0)
	var lamp := from + along * (length * 0.3) - right * (ROAD_WIDTH / 2.0 + 0.7)
	if WoodPiece.make("wood_lantern_post", street, lamp, 2.6) != null:
		_light(street, lamp + Vector3.UP * 2.4)
	return street


func _light(parent: Node3D, at: Vector3) -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.48)
	lamp.light_energy = 1.6 if _is_night() else 0.4
	lamp.omni_range = 9.0
	lamp.position = at
	parent.add_child(lamp)


# The delivery's house in the lot: a cottage with its door lit, a lantern by
# the door, and whoever ordered waiting outside it. { figure, stand }.
func _build_destination(lot: Vector3, caller: Dictionary) -> Dictionary:
	var right := _heading().cross(Vector3.UP)
	var house := Node3D.new()
	house.name = "Destination"
	(_arm if _arm != null else _town).add_child(house)
	var facing := -right
	var house_at := lot + right * (WoodPiece.size_of("wood_cottage_thatch").y / 2.0 + 0.4)  # Its front just behind the lot's middle.
	WoodPiece.make("wood_cottage_thatch", house, house_at, 0.0, atan2(facing.x, facing.z))
	var path := CottageDressing._box(house, lot - right * 0.8 + Vector3.UP * 0.025, Vector3(2.2, 0.03, 1.0) if absf(right.x) > 0.5 else Vector3(1.0, 0.03, 2.2), Color("C9B79A"))
	path.name = "Path"
	CottageDressing.lantern(house, lot + right * 0.1 + _heading() * 1.2 + Vector3.UP * 1.9)
	_light(house, lot - right * 0.6 + _heading() * 1.0 + Vector3.UP * 1.8)
	var figure := _figure_for(caller)
	house.add_child(figure)
	figure.position = lot - right * 0.2
	figure.rotation.y = atan2(facing.x, facing.z)
	return { "figure": figure, "stand": lot - right * 1.25 }


func _figure_for(caller: Dictionary) -> RegularFigure:
	var regular_id: String = caller.get("regular_id", "")
	if not regular_id.is_empty():
		return RegularFigure.make(regular_id)
	var own: Dictionary = GameData.get_townsfolk(caller.get("id", "")).get("model", {})
	if own.is_empty():
		var kind := GameData.get_species(caller.get("species", "")) if not String(caller.get("species", "")).is_empty() else {}
		var models: Array = kind.get("models", [])
		if not models.is_empty():
			var height: Array = kind.get("height", [1.0, 1.1])
			own = { "path": models[0], "height": randf_range(float(height[0]), float(height[1])) }
	var figure := RegularFigure.make_from(own, caller.get("id", "someone"))
	if figure.get_child_count() == 0:  # No model yet: a little stand-in.
		CottageDressing._ball(figure, Vector3(0, 0.45, 0), 0.32, Color("D8B48A"), 1.3)
		CottageDressing._ball(figure, Vector3(0, 0.95, 0), 0.24, Color("D8B48A"))
	return figure


func _is_night() -> bool:
	return Fishing.hour_block() in ["evening", "late_night", "early_morning"]


func _build_world() -> void:
	_world = Node3D.new()
	_world.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # It all moves in _process.
	_viewport.add_child(_world)
	var sky := Color.html(String(GameData.trips.get("drive", {}).get("sky", {}).get(Fishing.hour_block(), "#1d2747")))
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = sky.lerp(Color.WHITE, 0.45)
	env.ambient_light_energy = 0.75
	env.fog_enabled = true  # Hides streets appearing at the far end.
	env.fog_light_color = sky
	env.fog_density = 0.028
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	_world.add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55.0, 40.0, 0.0)
	moon.light_energy = 0.35 if _is_night() else 1.0
	moon.light_color = Color(0.72, 0.78, 1.0) if _is_night() else Color(1.0, 0.95, 0.88)
	moon.shadow_enabled = true
	_world.add_child(moon)
	CottageDressing._box(_world, Vector3(0.0, -0.03, 0.0), Vector3(400.0, 0.02, 400.0), Color("587A3C"))  # Grass everywhere.

	_town = Node3D.new()
	_town.name = "Town"
	_world.add_child(_town)

	_cart = Node3D.new()
	_cart.name = "Cart"
	_world.add_child(_cart)
	var look := DeliveryCar.build_look()
	look.rotation.y = PI  # Its front toward -z, the way it drives.
	_cart.add_child(look)
	for x in [-0.45, 0.45]:  # Headlamps, lighting the road ahead.
		var beam := SpotLight3D.new()
		beam.light_color = Color(1.0, 0.9, 0.7)
		beam.light_energy = 3.0 if _is_night() else 0.0
		beam.spot_range = 18.0
		beam.spot_angle = 28.0
		beam.position = Vector3(x, 0.9, -1.3)
		beam.rotation_degrees.x = -8.0
		_cart.add_child(beam)
	for i in bags.size():  # The parcels in the back, one off at each door.
		_parcels.append(CottageDressing._box(_cart, Vector3(-0.3 + (i % 3) * 0.3, 1.0 + (i / 3) * 0.33, 0.75), Vector3(0.28, 0.3, 0.22), Color("E8D2A6")))
	_driver = ChefModel.new()
	_driver.height = 1.5
	_driver.position = Vector3(-0.3, 0.62, -0.55)  # The left of the bench.
	_driver.rotation.y = PI
	_cart.add_child(_driver)
	_driver.apply_appearance(Accounts.appearance_of(player_index))

	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.position = Vector3(0.3, 2.02, 2.5)  # Just under the canopy's edge, behind the bench.
	_camera.rotation_degrees.x = -8.0
	_cart.add_child(_camera)
	_camera.make_current()


func _make_display(parent: Node) -> void:
	_display = Control.new()
	_display.name = "DeliveryDrive"
	_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_display)
	var picture := TextureRect.new()
	picture.texture = _viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.add_child(picture)
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.04, 0.06, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.add_child(_fade)
	_prompt = _label(36, Control.PRESET_CENTER_TOP, 40.0)
	_list = _label(20, Control.PRESET_TOP_LEFT, 16.0)
	_list.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_list.grow_horizontal = Control.GROW_DIRECTION_END
	_list.position = Vector2(24.0, 20.0)
	_hint = _label(18, Control.PRESET_CENTER_BOTTOM, -44.0)
	_hint.text = "Turn with %s" % InputSetup.move_hint(player_index)


func _label(font_size: int, preset: Control.LayoutPreset, y: float) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("FFF4DC"))
	label.add_theme_color_override("font_outline_color", Color(0.18, 0.11, 0.07))
	label.add_theme_constant_override("outline_size", 10)
	var font := load("res://assets/fonts/fredoka_semibold.tres")
	if font != null:
		label.add_theme_font_override("font", font)
	label.set_anchors_and_offsets_preset(preset)
	label.position.y += y
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.add_child(label)
	return label


func _show_list() -> void:
	var lines: Array[String] = ["Deliveries"]
	var done := _delivered.duplicate()
	for bag in bags:
		var who: String = bag.dish.order.caller.get("name", "?")
		var tick := who in done
		if tick:
			done.erase(who)
		lines.append("%s %s's %s" % ["✓" if tick else "•", who, bag.contents_name()])
	_list.text = "\n".join(lines)
