# ReelDirector: plays a scenario's beats (see ReelScenario) in a running
# restaurant, through the game's own customers, chef and dialogue box, so what's
# recorded is the real thing: real walking, typing and voice blips. Nobody
# presses anything: it moves the box's highlight, picks and walks the chef
# itself. If a beat never finishes it gives up and says which, so a recording
# can't run forever.
class_name ReelDirector
extends Node

signal beat_started(index: int, beat: Dictionary)
signal finished(ok: bool)

const CHEF_START := Vector3(5.0, 0.0, -4.3)  # At the pass, in from the kitchen.
const BACK_LANE_Z := -3.0        # Where the chef walks along the back of the room.
const BESIDE_CUSTOMER := Vector3(0.0, 0.0, 0.9)  # Where the chef stands to talk or serve.
const CHEF_ARRIVED := 0.15       # How close to a point counts as there.
const LEG_SECONDS := 6.0         # A chef still walking one leg after this is stuck.
const BEAT_SECONDS := 30.0       # The longest any beat should take.
const READ_SECONDS := 1.0        # How long to look at the replies before moving (choices "read").
const PICK_SECONDS := 0.6        # How long the highlight stays on a reply before picking it (choices "hold").
const STEP_SECONDS := 0.2        # Per reply as the highlight moves.
const REPLY_HOLD_SECONDS := 1.5  # How long a finished line stays up (line and reaction "hold").

var scenario: Dictionary
var main: Node
var customer: Customer  # The regular.

var _customers: CustomerManager
var _chef: Player
var _talking := false
var _failed := false


func play() -> void:
	_customers = main.get_node("CustomerManager")
	while Player.find(get_tree(), 0) == null:
		await get_tree().process_frame
	_chef = Player.find(get_tree(), 0)
	_set_the_scene()
	var beats: Array = scenario["beats"]
	for i in beats.size():
		beat_started.emit(i, beats[i])
		await _run(beats[i], i)
		if _failed:
			finished.emit(false)
			return
	finished.emit(true)


func _set_the_scene() -> void:
	var lighting: String = scenario.get("lighting", scenario["meal"])
	if lighting != scenario["meal"]:
		main.get_node("DayManager")._light(GameState.phase_info(ReelScenario.meal_index(lighting)).get("lighting", {}), 0.0)
	for extra in scenario.get("extras", []):
		_customers.reel_extra(GameData.get_species(extra["species"]), GameData.get_dish(extra["dish"]), extra["table"])
	_chef.global_position = CHEF_START
	_chef.reset_physics_interpolation()


func _run(beat: Dictionary, index: int) -> void:
	match beat["do"]:
		"walk_in":
			customer = _customers.reel_walk_in(scenario["regular"]["id"], beat["table"])
			await _until(func(): return customer.state == Customer.State.WAITING_DRINK_ORDER, "%s to sit down" % customer.display_name)
			customer.serve_drink({}, 1.0)  # Straight to ordering.
		"line":
			await _line(beat, index)
		"choices":
			await _choices(beat)
		"reaction":
			await _finish_talking(float(beat.get("hold", REPLY_HOLD_SECONDS)))
		"serve":
			await _serve(beat)
		"wait":
			await _seconds(float(beat["seconds"]))


# The chef comes over and they say the line. A line with replies stops with
# them on screen, for the choices beat; any other is said to the end.
func _line(beat: Dictionary, index: int) -> void:
	await _walk_chef(_way_to_customer())
	var line := _line_for(beat, index)
	_talking = true
	_talk(line)
	if line.has("choices"):
		await _until(func(): return _box() != null and _box().is_choosing(), "the replies to show")
	else:
		await _finish_talking(float(beat.get("hold", REPLY_HOLD_SECONDS)))


func _talk(line: Dictionary) -> void:
	await _customers.reel_talk(_chef, customer, line)
	_talking = false


# The line from their file, with the reply's feeling swapped if the reaction beat says so.
func _line_for(beat: Dictionary, index: int) -> Dictionary:
	var line := ReelScenario.find_line(scenario["regular"]["id"], beat["line"]).duplicate(true)
	var beats: Array = scenario["beats"]
	if line.has("choices") and beats[index + 2].has("emotion"):
		for choice in line["choices"]:
			if choice.get("tone", "") == beats[index + 1]["pick"]:
				choice["emotion"] = beats[index + 2]["emotion"]
	return line


func _choices(beat: Dictionary) -> void:
	await _seconds(float(beat.get("read", READ_SECONDS)))
	for stop in beat.get("highlight", []):
		await _move_highlight(stop["tone"])
		await _seconds(float(stop.get("hold", PICK_SECONDS)))
	await _move_highlight(beat["pick"])
	await _seconds(float(beat.get("hold", PICK_SECONDS)))
	_box().pick()


# One reply at a time, the short way round (the list wraps, like the real thing).
func _move_highlight(tone: String) -> void:
	var box := _box()
	var line := ReelScenario.find_line(scenario["regular"]["id"], _said_line())
	var tones: Array = Conversation.choices_of(line).map(func(c): return c.get("tone", ""))
	var target := tones.find(tone)
	var count := tones.size()
	var down := posmod(target - box.highlighted(), count)
	var step := 1 if down <= count - down else -1
	while box.highlighted() != target:
		box.highlight(posmod(box.highlighted() + step, count))
		if box.highlighted() != target:
			await _seconds(STEP_SECONDS)


# The id of the last line beat.
func _said_line() -> String:
	var found := ""
	for beat in scenario["beats"]:
		if beat["do"] == "line":
			found = beat["line"]
		elif beat["do"] == "choices" and _box() != null:
			return found
	return found


# Let each line type out and stay up for `hold` seconds, until the talk is over.
func _finish_talking(hold: float) -> void:
	while _talking:
		await _until(func(): return not _talking or (_box() != null and _box().is_waiting()), "the line to finish")
		if _failed or not _talking:
			return
		await _seconds(hold)
		_box().move_on()
		await get_tree().process_frame


# The chef goes to the pass, picks up the plate and brings it over.
func _serve(beat: Dictionary) -> void:
	var order := _customers.reel_order(customer, GameData.get_dish(beat["dish"]))
	var way_back := _way_to_customer()
	way_back.reverse()
	way_back.append(CHEF_START)
	await _walk_chef(way_back)
	_chef.set_held_item(CookedDish.new(order, float(beat.get("quality", 1.0))))
	await _walk_chef(_way_to_customer())
	_customers.reel_serve(_chef, customer, _chef.held_item)


# From the pass: along the back, down the aisle beside their chair, and up to them.
func _way_to_customer() -> Array[Vector3]:
	var stand := customer.global_position + BESIDE_CUSTOMER
	var aisle: float = customer.seat.approach_point.global_position.x
	var points: Array[Vector3] = [Vector3(aisle, 0.0, BACK_LANE_Z), Vector3(aisle, 0.0, stand.z), Vector3(stand.x, 0.0, stand.z)]
	return points


# The chef walks `points` as if a player were steering, then faces the customer.
func _walk_chef(points: Array[Vector3]) -> void:
	for point in points:
		var left := LEG_SECONDS
		while _flat(point - _chef.global_position).length() > CHEF_ARRIVED:
			var to := _flat(point - _chef.global_position).normalized()
			_chef.scripted_move = Vector2(to.x, to.z)
			await get_tree().physics_frame
			left -= get_physics_process_delta_time()
			if left <= 0.0:
				_fail("the chef got stuck on the way to %s, at %s" % [point, _chef.global_position])
				break
		if _failed:
			break
	_chef.scripted_move = Vector2.ZERO
	if customer != null:
		var to_them := _flat(customer.global_position - _chef.global_position)
		_chef.visual.rotation.y = atan2(to_them.x, to_them.z)


func _flat(offset: Vector3) -> Vector3:
	return Vector3(offset.x, 0.0, offset.z)


func _box() -> ConversationBox:
	return _customers.reel_box


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(done: Callable, waiting_for: String) -> void:
	var left := BEAT_SECONDS
	while not done.call():
		await get_tree().process_frame
		left -= get_process_delta_time()
		if left <= 0.0:
			_fail("gave up waiting for %s" % waiting_for)
			return


func _fail(reason: String) -> void:
	_failed = true
	push_error("Reel stopped: " + reason)
