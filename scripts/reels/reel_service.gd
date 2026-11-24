# ReelService: a reel's chef played the way a person plays, for the "service"
# and "tidy" beats (see ReelDirector). It walks round the room on its own feet
# (a path worked out over the floor, round the tables and counters) and presses
# the real buttons, through Input, so everything that happens is the game's own:
# the host stand, leading them to a table, the drinks counter, the ticket wheel,
# the freezer, the stove's close-up, serving, chatting and the bill. In a
# dialogue box it reads before going on, and at a question it looks the replies
# over, wanders to another one, then settles on its pick: never straight away.
# The camera is the game's own, following the chef, framed for a tall video.
# Says how far it's got (mark) so a recording can be cut into parts.
class_name ReelService
extends Node

signal mark(part: String)

const CELL := 0.25                       # The floor grid for finding the way.
const FLOOR := Rect2(-8.0, -12.0, 16.0, 17.5)
const BODY := 0.3                        # How wide the chef is, for the grid.
const LEG_SECONDS := 8.0                 # Still walking one leg after this: stuck.
const ARRIVED := 0.12
const STEP_SECONDS := 60.0               # The longest any one step should take.
const COOK_SECONDS := 150.0
const WALK_FOV := 64.0                   # Across the tall view while walking about.
const SESSION_FOV := { "stove": 40.0, "oven": 40.0, "microwave": 40.0, "board": 40.0, "table": 45.0, "sink": 70.0 }
const BESIDE := Vector3(0.0, 0.0, 0.9)   # Where the chef stands to talk to someone seated (as ReelDirector).
const TONES := ["warm", "playful", "straight"]  # The replies it likes best, in order.

var main: Node
var chef: Player
var customers: CustomerManager
var camera: ReelCamera
var beat: Dictionary
var regular_id := ""
var customer: Customer
var failed := ""                         # Why it stopped, if it did.

var _grid := AStarGrid2D.new()
var _rng := RandomNumberGenerator.new()
var _answering := false                  # The box handler is running.
var _choosing := false                   # It's in the middle of picking a reply.
var _fov_goal := WALK_FOV
var _session_kind := ""                  # The close-up the chef is in, for the camera.


func _ready() -> void:
	_rng.seed = hash(regular_id + String(beat.get("do", "")))


func _process(delta: float) -> void:
	if not camera.close_up:
		return  # The reel's own shots (the opening) keep theirs.
	var cam := camera.view.rig.camera
	var goal: float = SESSION_FOV.get(_session_kind, WALK_FOV) if not _session_kind.is_empty() else _fov_goal
	cam.fov = lerpf(cam.fov, goal, 1.0 - exp(-4.0 * delta))


func _start_camera() -> void:
	camera.close_up_fov = WALK_FOV
	camera.close_up = true  # The rig steers, wide across the tall view.
	camera.view.rig.snap()
	_build_grid()
	_answer_boxes()


func _stop() -> void:
	_answering = false
	chef.scripted_move = Vector2.ZERO


# --- A whole visit ----------------------------------------------------------------

func serve_regular() -> void:
	chef.global_position = Vector3(-2.5, 0.0, -4.4)  # Behind the host stand, waiting.
	chef.reset_physics_interpolation()
	chef.visual.rotation.y = 0.0
	mark.emit("arrival")
	customer = customers.reel_arrive(regular_id)
	customer.eat_duration = float(beat.get("eat_seconds", 16.0))
	# The room as they come in, then along with them to the host stand.
	camera.subject = customer
	camera.cut_to(ReelCamera.Shot.WIDE)
	get_tree().create_timer(float(beat.get("wide_seconds", 2.0))).timeout.connect(camera.glide_to.bind(ReelCamera.Shot.FOLLOW))
	await _until(func(): return customers.next_to_seat() == customer, "%s to reach the host stand" % customer.display_name)
	_start_camera()  # Now the game's own camera, on the chef.
	await _seconds(_rng.randf_range(0.6, 1.0))
	await _use(customers.order_counter.interactable)
	await _until(func(): return customers.leading(0) == customer or customer.state in Customer.SEATED_STATES or customer.state == Customer.State.WALKING_TO_SEAT, "the greeting to end", 120.0)
	if failed.is_empty() and customers.leading(0) == customer:
		mark.emit("seating")
		await _seconds(_rng.randf_range(0.3, 0.6))
		var table := _table_for(customer)
		await _use(table.interactable)
	await _until(func(): return customer.state == Customer.State.WAITING_DRINK_ORDER, "%s to sit down" % customer.display_name)
	mark.emit("drink_order")
	await _seconds(_rng.randf_range(0.3, 0.7))
	await _use(customer.interactable, _beside(customer))
	await _until(func(): return customer.state == Customer.State.WAITING_FOR_DRINK and _free(), "the drink order", 120.0)
	mark.emit("drink")
	await _make_drink()
	await _use(customer.interactable, _beside(customer))
	await _until(func(): return customer.state == Customer.State.WAITING_FOOD_ORDER and _free(), "the drink to be given")
	mark.emit("food_order")
	await _seconds(_rng.randf_range(0.5, 1.0))
	await _press()  # Still beside them.
	await _until(func(): return not chef.tickets.is_empty() and _free(), "the food order", 120.0)
	mark.emit("ticket_wheel")
	await _clip_ticket()
	mark.emit("cooking")
	await _cook_order()
	mark.emit("serving")
	await _use(customer.interactable, _beside(customer))
	await _until(func(): return customer.state == Customer.State.EATING and _free(), "the food to be served")
	# While they eat: back toward the kitchen a moment, then over for a chat.
	await _seconds(_rng.randf_range(0.6, 1.0))
	await _walk_to(Vector3(2.3, 0.0, -3.6))
	await _seconds(float(beat.get("chat_after", 3.0)))
	if customer.can_chat():
		mark.emit("chat")
		await _use(customer.interactable, _beside(customer))
		await _until(func(): return customer.chatted and _free(), "the chat", 120.0)
	await _until(func(): return customer.state == Customer.State.WANTS_BILL, "%s to finish eating" % customer.display_name, 120.0)
	mark.emit("bill")
	await _seconds(_rng.randf_range(0.5, 1.0))
	await _use(customers.order_counter.interactable, Vector3(-2.5, 0.0, -4.3))
	await _until(func(): return chef.held_item is Receipt, "the bill to print")
	await _seconds(_rng.randf_range(0.2, 0.4))
	await _use(customer.interactable, _beside(customer))
	await _until(func(): return customer.state in [Customer.State.LEAVING, Customer.State.GONE] and _free(), "the bill to be paid", 120.0)
	mark.emit("leaving")
	await _seconds(float(beat.get("after", 4.0)))
	_stop()


# The drink machine that makes what's wanted: along to its tap, hold to the line
# (then the marshmallows).
func _make_drink() -> void:
	var station := DrinkStation.with_work_for(get_tree(), chef.player_index)
	await _use(station.interactable)
	await _until(func(): return station._pourer == chef, "the machine")
	await _seconds(_rng.randf_range(0.5, 0.8))
	while station._pourer == chef:
		match station.next_move():
			"left", "right":
				await _press_action("move_" + station.next_move(), 0.1)
				await _seconds(_rng.randf_range(0.15, 0.3))
			"pour":
				await _seconds(_rng.randf_range(0.2, 0.4))
				var full := float(GameData.drink_settings.get("brew_fill_seconds" if station.brewer else "fill_seconds", 1.8))
				await _press(full * (1.0 - station._fill / DrinkStation.LINE) * _rng.randf_range(0.97, 1.03))
			"top":
				await _seconds(_rng.randf_range(0.3, 0.5))
				await _press()
		await get_tree().process_frame
	await _until(func(): return _holding(Drink) and _free(), "the drink")
	await _seconds(_rng.randf_range(0.2, 0.4))


# Up to the wheel, then clip the ticket on as an empty clip comes round.
func _clip_ticket() -> void:
	var wheel: TicketWheel = main.find_children("*", "TicketWheel", true, false).front()
	await _use(wheel.interactable, Vector3(3.75, 0.0, -4.35))
	await _until(func(): return wheel._clipper == chef, "the wheel")
	await _seconds(_rng.randf_range(0.5, 0.9))
	var tries := 0
	while wheel._clipper == chef and not wheel._queue.is_empty() and tries < 400:
		var index := wheel._front_clip()
		var off := wheel._front_offset(index)
		if off > -0.16 and off < -0.04 and not wheel._tickets.has(index):
			await _press()
			await _seconds(0.3)
		await get_tree().process_frame
		tries += 1
	await _until(func(): return wheel._clipper == null and _free(), "the wheel to let go")


# The freezer, the chopping board if it needs it, then the stove (or oven...).
func _cook_order() -> void:
	var freezer: Freezer = main.find_children("*", "Freezer", true, false).front()
	await _use(freezer.interactable)
	await _until(func(): return _holding(Ingredients), "the ingredients")
	var ingredients := chef.held_item as Ingredients
	if ingredients.needs_chopping():
		var boards := main.find_children("*", "ChoppingBoard", true, false).filter(func(b): return b.is_visible_in_tree() and b.session == null)
		await _run_session(_nearest(boards), "board")
	var dish: Dictionary = ingredients.order.dish
	var stations := main.find_children("*", "CookingStation", true, false).filter(func(s): return s.is_visible_in_tree() and s.makes(dish) and s.session == null)
	if stations.is_empty():
		_fail("nowhere to cook %s" % dish.get("name", "?"))
		return
	var station: CookingStation = _nearest(stations)
	await _run_session(station, station.station_id)
	await _until(func(): return _holding(CookedDish) and _free(), "the plate", 20.0)


# Use a station whose close-up plays itself (the chef's hand doing it well).
func _run_session(station: Station, kind: String) -> void:
	await _use(station.interactable)
	await _until(func(): return station.get("session") != null, "the close-up at %s" % station.name)
	if not failed.is_empty():
		return
	station.session.input.scripted = true
	station.session.big_hint()
	_session_kind = kind
	await _until(func(): return station.get("session") == null, "%s to be done" % station.name, COOK_SECONDS)
	_session_kind = ""


# --- Tidying up ------------------------------------------------------------------

# A messy table: clear the dishes into a bin and wash them ("clear"), and/or wipe
# the spills ("wipe").
func tidy() -> void:
	_start_camera()
	var table: DiningTable = main.find_children("*", "DiningTable", true, false).filter(func(t): return t.spot == beat.get("table", "kitchen")).front()
	table._reel_mess()
	var clear: bool = beat.get("clear", true)
	if not clear:
		table.dishes.clear()
		table._update_interactable()
		table.cleanliness_changed.emit(table)
	var sink: Sink = main.find_children("*", "Sink", true, false).front()
	chef.global_position = Vector3(2.3, 0.0, -3.6) if clear else table.global_position + Vector3(-2.2, 0.0, -1.6)
	chef.reset_physics_interpolation()
	camera.view.rig.snap()
	await _seconds(1.0)
	if clear:
		mark.emit("bin")
		await _use(sink.interactable)
		await _until(func(): return _holding(DishBin), "a dish bin")
		mark.emit("clear")
		await _run_session(table, "table")
		mark.emit("wash")
		await _run_session(sink, "sink")
	if beat.get("wipe", false) and not table.spills.is_empty():
		mark.emit("wipe")
		await _run_session(table, "table")
	await _seconds(float(beat.get("after", 2.0)))
	_stop()


# --- Walking ---------------------------------------------------------------------

# Walk up to `target` (to `stand` if given, else as near it as the floor allows),
# make sure it's the one the chef would use, then press.
func _use(target: Interactable, stand := Vector3.INF) -> void:
	if not failed.is_empty():
		return
	await _walk_to(stand if stand != Vector3.INF else target.global_position)
	var left := 2.0
	while chef.interactor.focused != target and left > 0.0:  # Edge in until it's the one in front of them.
		var to := _flat(target.global_position - chef.global_position)
		chef.scripted_move = Vector2(to.x, to.z).normalized() * 0.5
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
	chef.scripted_move = Vector2.ZERO
	_face(target.global_position)
	if chef.interactor.focused != target:
		_fail("couldn't reach %s (in front of them: %s)" % [target.get_parent().name, chef.interactor.focused.get_parent().name if chef.interactor.focused != null else "nothing"])
		return
	await _seconds(_rng.randf_range(0.15, 0.3))
	await _press()


func _walk_to(goal: Vector3) -> void:
	for point in _path(chef.global_position, goal):
		var left := LEG_SECONDS
		while _flat(point - chef.global_position).length() > ARRIVED:
			var to := _flat(point - chef.global_position).normalized()
			chef.scripted_move = Vector2(to.x, to.z)
			await get_tree().physics_frame
			left -= get_physics_process_delta_time()
			if left <= 0.0:
				break  # Close enough: carry on from here.
	chef.scripted_move = Vector2.ZERO


# Corners of the way from `from` to `to` over the floor grid.
func _path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var start := _free_cell(_cell(from))
	var end := _free_cell(_cell(to))
	var cells := _grid.get_id_path(start, end)
	var points: Array[Vector3] = []
	var i := 1
	while i < cells.size():
		var far := i
		while far + 1 < cells.size() and _clear_line(cells[i - 1] if points.is_empty() else _cell(points.back()), cells[far + 1]):
			far += 1
		points.append(_world(cells[far]))
		i = far + 1
	if not points.is_empty():
		points[points.size() - 1] = Vector3(to.x, 0.0, to.z) if not _grid.is_point_solid(_cell(to)) else points.back()
	return points


func _clear_line(a: Vector2i, b: Vector2i) -> bool:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y)) * 2
	for s in steps + 1:
		var t := float(s) / maxf(steps, 1)
		var c := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
		if _grid.is_point_solid(c):
			return false
	return true


func _build_grid() -> void:
	_grid.region = Rect2i(0, 0, ceili(FLOOR.size.x / CELL), ceili(FLOOR.size.y / CELL))
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	var space := chef.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = BODY
	query.shape = ball
	for x in _grid.region.size.x:
		for y in _grid.region.size.y:
			query.transform = Transform3D(Basis(), _world(Vector2i(x, y)) + Vector3.UP * 0.6)
			for hit in space.intersect_shape(query, 4):
				if not hit["collider"] is CharacterBody3D:  # People move; furniture doesn't.
					_grid.set_point_solid(Vector2i(x, y))
					break


func _cell(at: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi((at.x - FLOOR.position.x) / CELL), 0, _grid.region.size.x - 1), clampi(roundi((at.z - FLOOR.position.y) / CELL), 0, _grid.region.size.y - 1))


func _world(cell: Vector2i) -> Vector3:
	return Vector3(FLOOR.position.x + cell.x * CELL, 0.0, FLOOR.position.y + cell.y * CELL)


func _free_cell(cell: Vector2i) -> Vector2i:
	if not _grid.is_point_solid(cell):
		return cell
	for ring in range(1, 12):
		var best := Vector2i(-1, -1)
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				var c := cell + Vector2i(dx, dy)
				if _grid.is_in_boundsv(c) and not _grid.is_point_solid(c) and (best.x < 0 or Vector2(c - cell).length() < Vector2(best - cell).length()):
					best = c
		if best.x >= 0:
			return best
	return cell


func _beside(who: Customer) -> Vector3:
	var at := who.global_position + BESIDE
	return Vector3(at.x, 0.0, at.z)


func _face(point: Vector3) -> void:
	var to := _flat(point - chef.global_position)
	if to.length() > 0.01:
		chef.visual.rotation.y = atan2(to.x, to.z)


func _nearest(nodes: Array) -> Node3D:
	nodes.sort_custom(func(a, b): return a.global_position.distance_to(chef.global_position) < b.global_position.distance_to(chef.global_position))
	return nodes.front()


# Where to seat them: the table they asked for if it's free and clean, else the
# beat's, else any that will do.
func _table_for(who: Customer) -> DiningTable:
	var tables := main.find_children("*", "DiningTable", true, false).filter(func(t): return t.can_seat(0))
	for wanted in [who.wanted_table, String(beat.get("table", "corner"))]:
		for table in tables:
			if table.spot == wanted:
				return table
	return tables.front()


# --- Talking ---------------------------------------------------------------------

# Answers every dialogue box of the chef's while the beat runs: reads each line
# for a moment before going on, and takes its time over a question.
func _answer_boxes() -> void:
	_answering = true
	while _answering and is_inside_tree():
		var box := _box()
		if box != null and not _choosing:
			if box.is_waiting():
				var line: String = box._plain
				await _seconds(clampf(0.7 + line.length() * 0.03, 1.0, 3.6))
				if is_instance_valid(box) and box.is_waiting():
					await _press()
					await _seconds(0.15)
			elif box.is_choosing():
				_choosing = true
				await _choose(box)
				_choosing = false
		await get_tree().process_frame


# Looks the replies over, tries another on for size, then picks its own.
func _choose(box: ConversationBox) -> void:
	var options: Array = box._option_texts
	var pick := _pick(options)
	var reading := 0
	for option in options:
		reading += String(option).length()
	await _seconds(clampf(1.0 + reading * 0.015, 1.4, 3.2))
	if options.size() > 1 and _rng.randf() < 0.75:
		var detour := posmod(pick + (1 if _rng.randf() < 0.5 else -1), options.size())
		if options.size() == 2 or detour != pick:
			await _highlight(box, detour)
			await _seconds(_rng.randf_range(0.6, 1.1))
	await _highlight(box, pick)
	await _seconds(_rng.randf_range(0.5, 0.9))
	if is_instance_valid(box) and box.is_choosing():
		await _press()
		await _seconds(0.2)


# Up or down a reply at a time, the short way round.
func _highlight(box: ConversationBox, target: int) -> void:
	var count: int = box._option_texts.size()
	var tries := 0
	while is_instance_valid(box) and box.is_choosing() and box.highlighted() != target and tries < 12:
		var down := posmod(target - box.highlighted(), count)
		await _press_action("move_down" if down <= count - down else "move_up", 0.08)
		await _seconds(_rng.randf_range(0.25, 0.4))
		tries += 1


# Which reply: the drink they ordered, a dish they'll like, or a kind word.
func _pick(options: Array) -> int:
	if customer != null and not customer.drink.is_empty():
		var drink_name := String(customer.drink.get("name", ""))
		if customer.drink_secret:  # "The usual": their favorite.
			drink_name = String(GameData.get_drink(String(GameState.regulars[regular_id].get("favorite_drink", ""))).get("name", drink_name))
		if drink_name in options:
			return options.find(drink_name)
	var menu: Array = GameData.menu().map(func(d): return String(d["name"]))
	if options.all(func(o): return String(o) in menu):  # "Surprise me": their favorite.
		var favorite := String(GameData.get_dish(String(GameState.regulars.get(regular_id, {}).get("favorite_dish", ""))).get("name", ""))
		return maxi(options.find(favorite), 0)
	var tones := _tones_of(options)
	for tone in beat.get("tones", TONES):
		if tone in tones:
			return tones.find(tone)
	for i in options.size():
		if tones[i] != "rude":
			return i
	return 0


# Each reply's tone, found by its text in the regular's file ("" if it has none).
func _tones_of(options: Array) -> Array:
	var choices := []
	for line in GameData.characters.get(regular_id, {}).get("lines", []):
		_gather_choices(line, choices)
	var tones := []
	for option in options:
		var tone := ""
		for choice in choices:
			if _same_text(String(choice.get("text", "")), String(option)):
				tone = String(choice.get("tone", ""))
				break
		tones.append(tone)
	return tones


func _gather_choices(line: Dictionary, into: Array) -> void:
	for choice in line.get("choices", []):
		into.append(choice)
		if choice.get("then") is Dictionary:
			_gather_choices(choice["then"], into)


# A reply's text from the file ({name} and all) against how it was shown.
func _same_text(raw: String, shown: String) -> bool:
	if raw == shown:
		return true
	var pieces := []
	var last := 0
	for found in RegEx.create_from_string("\\{[^}]*\\}").search_all(raw):
		pieces.append(ConversationBox._escape_regex(raw.substr(last, found.get_start() - last)))
		last = found.get_end()
	pieces.append(ConversationBox._escape_regex(raw.substr(last)))
	var regex := RegEx.create_from_string("^" + ".*".join(pieces) + "$")
	return regex.is_valid() and regex.search(shown) != null


func _box() -> ConversationBox:
	for node in get_tree().get_nodes_in_group(ConversationBox.GROUP):
		var box := node as ConversationBox
		if box != null and box.player_index == 0 and not box.is_queued_for_deletion():
			return box
	return null


# --- Buttons and waiting ---------------------------------------------------------

func _press(hold := 0.1) -> void:
	await _press_action("interact", hold)


func _press_action(action: String, hold: float) -> void:
	var event := InputEventAction.new()
	event.action = InputSetup.action_name(0, action)
	event.pressed = true
	Input.parse_input_event(event)
	await _seconds(hold)
	var up := InputEventAction.new()
	up.action = event.action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _holding(kind) -> bool:
	return is_instance_of(chef.held_item, kind)


func _free() -> bool:
	return not chef.movement_locked and _box() == null


func _flat(offset: Vector3) -> Vector3:
	return Vector3(offset.x, 0.0, offset.z)


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(done: Callable, waiting_for: String, seconds := STEP_SECONDS) -> void:
	if not failed.is_empty():
		return
	var left := seconds
	while not done.call():
		await get_tree().process_frame
		left -= get_process_delta_time()
		if left <= 0.0:
			_fail("gave up waiting for %s" % waiting_for)
			return


func _fail(reason: String) -> void:
	if failed.is_empty():
		failed = reason
	_stop()
