# DrizzleAction: hold the button and move to drizzle syrup over the top of a
# stack, with only so much in the bottle, which stays over the plate. It's a real
# liquid (SauceSheet): it falls in a stream that coils as it lands, heaps and
# spreads, runs round what's on the food (butter), over the edge and down the
# side, and pools on the plate; thick sauces hold their shape. The step ends
# when the bottle's empty. It scores how much of the food showing from above
# got covered (full marks at target_coverage), minus what was spilled off it,
# from least_score up: any syrup on the food scores well.
class_name DrizzleAction
extends CookAction

@export var target := "Plate"
@export var syrup_seconds := 3.0              # How long the bottle lasts while held.
@export var syrup_color := Color(0.38, 0.17, 0.04)  # Deep amber maple: any redder and it read as ketchup.
@export var line_radius := 0.013              # How thick the line is.
@export var kind := "syrup"                   # What it's like: SauceSheet.KINDS.
@export var flow_rate := 0.00004             # How much comes out (m³ a second).
@export var spacing := 0.007                  # How often along the line it's noted (for the score).
@export_range(0.0, 1.0) var target_coverage := 0.45  # Share of the top to cover for full marks.
@export var spill_penalty := 1.5              # How much each spilled share costs.
@export_range(0.0, 1.0) var least_score := 0.85  # Any syrup on the food scores at least this: it's a treat, not a test.
@export var bottle_height := 0.1
@export var bottle_scale := 0.62              # A small bottle, leaning away from the cook, so it doesn't hide the food.
@export var bottle_lean := 48.0
@export var one_stroke := false               # Done as soon as one line on the food is let go (a squiggle of ketchup).
@export var least_blobs := 6                  # How much of that line has to be on the food to count.

const SCRIPTED_REACH := 0.75    # A reel's zigzag covers this much of the food's radius...
const SCRIPTED_ZIGZAGS := 7.0   # ...going across this many times.

var _left := 0.0
var _last_point = null       # Where the line got to (Vector2), or null between drizzles.
var _on_top: Array[Vector2] = []
var _spilled := 0
var _sheet: SauceSheet
var _stream: PourStream
var _land := Vector3.INF     # Where the stream lands: it trails behind the bottle.
var _coil := 0.0
var _squeeze := 0.0
var _poured := false
var _bottle: Node3D
var _flow: AudioStreamPlayer3D
var _foods: Array[CookPiece] = []  # The pieces in the stack, highest first.
var _top_y := 0.0


func uses_cursor() -> bool:
	return false  # The bottle shows the spot.


func marks_spot() -> bool:
	return true


func _begin() -> void:
	_left = syrup_seconds
	_bottle = session.make_bottle(syrup_color)
	_bottle.scale = Vector3.ONE * bottle_scale
	_flow = session.loop_sound("drizzle", -10.0)
	for entry in session.stack_of(target):
		if entry["node"] is CookPiece:
			_foods.push_front(entry["node"])
	_top_y = _surface_of(_foods[0]) if not _foods.is_empty() else session.stack_top(target).y
	_sheet = session.make_sauce(target, kind, syrup_color)
	_stream = PourStream.make(session, syrup_color.lerp(SauceSheet.KINDS[kind]["light"], 0.35) if SauceSheet.KINDS[kind]["light"] is Color else syrup_color, line_radius * 0.34, SauceSheet.KINDS[kind]["gloss"], 1.4)
	session.get_tree().create_timer(1.6, false).timeout.connect(_look_again)  # The butter's softer by then.


func view_point() -> Vector3:
	return Vector3(session.stack_top(target).x, _top_y, session.stack_top(target).z)


func cursor_area() -> Rect2:
	return session.area_of(target, 0.03) if view_distance > 0.0 else Rect2()


func cursor_height() -> float:
	return _top_y


func update(delta: float, input: CookInput) -> void:
	input.cursor = session.surface(target).keep_inside(input.cursor, line_radius)  # The syrup stays on the plate.
	var spot := input.cursor
	var pouring := input.held and _left > 0.0
	_bottle.position = _bottle.position.lerp(spot + Vector3(0.0, bottle_height, 0.0), 1.0 - exp(-20.0 * delta))
	_bottle.rotation.x = lerp_angle(_bottle.rotation.x, deg_to_rad(-bottle_lean if pouring else -bottle_lean - 25.0), 1.0 - exp(-14.0 * delta))
	_bottle.rotation.y = deg_to_rad(-24.0)
	_squeeze = lerpf(_squeeze, 1.0 if pouring else 0.0, 1.0 - exp(-12.0 * delta))  # Squeezed flat as it pours.
	_bottle.scale = Vector3(1.0 - 0.18 * _squeeze, 1.0, 1.0 + 0.08 * _squeeze) * bottle_scale
	if _land == Vector3.INF or not _stream.visible:
		_land = spot
	var was := _land
	_land = _land.lerp(spot, 1.0 - exp(-13.0 * delta))
	_land.y = _sheet.top_at(Vector2(_land.x, _land.z))
	_stream.flow(_bottle.position, _land, pouring, delta)
	if pouring and _stream.landed:
		_left = maxf(0.0, _left - delta)
		var point := Vector2(_land.x, _land.z)
		_lay(Vector2(was.x, was.z), point, flow_rate * delta)
		if _last_point == null:
			_add_blob(point)
			_last_point = point
		else:
			var steps := int(_last_point.distance_to(point) / spacing)
			for i in steps:
				_add_blob(_last_point.lerp(point, float(i + 1) / steps))
			if steps > 0:
				_last_point = point
		if not _flow.playing:
			_flow.play()
	elif not pouring:
		if one_stroke and _last_point != null and _on_top.size() >= least_blobs:
			_left = 0.0  # One line's enough: letting go finishes it.
		_last_point = null
		if _flow.playing:
			_flow.stop()
	if not one_stroke:
		session.set_status("Left: %d%%" % ceili(_left / syrup_seconds * 100.0))
	if _left <= 0.0:
		var score := _score()
		session.pop_text("Delicious!" if score >= 0.8 else ("Bit messy" if _spilled > _on_top.size() * 0.3 else "Needs more syrup"), Vector3(_foods[0].position.x, _top_y, _foods[0].position.z) if not _foods.is_empty() else spot, CookSession.mood_of(score))
		finish(score)


func end() -> void:
	_flow.stop()
	_bottle.queue_free()
	_stream.finish(_land)


# Back and forth down the food until the bottle's empty.
func scripted_hold(_delta: float, input: CookInput) -> bool:
	var middle := session.stack_top(target)
	var reach := (_foods[0].radius if not _foods.is_empty() else 0.1) * SCRIPTED_REACH
	var through := 1.0 - _left / syrup_seconds
	var across := sin(through * PI * SCRIPTED_ZIGZAGS) * reach
	input.cursor = Vector3(middle.x + across, input.height, middle.z + lerpf(-reach, reach, through))
	return _left > 0.0


# Some of it landing between two points, coiling on itself.
func _lay(from: Vector2, to: Vector2, amount: float) -> void:
	var parts := clampi(ceili(from.distance_to(to) / (line_radius * 0.35)), 1, 8)
	for i in parts:
		_coil += TAU * 0.16
		var off := Vector2.from_angle(_coil) * line_radius * (0.28 if kind != "foam" else 0.5)
		_sheet.pour(from.lerp(to, float(i + 1) / parts) + off, amount / parts, maxf(line_radius * 0.62, _sheet.cell * 1.3))
	_poured = true


# The butter's melted a bit more: what the sauce lies on is lower there.
func _look_again() -> void:
	if is_instance_valid(_sheet) and is_instance_valid(session):
		_sheet.look_under(session.lie_on(target))


# Note where a bit of it landed, for the score.
func _add_blob(point: Vector2) -> void:
	if _food_at(point) != null:
		_on_top.append(point)
	else:
		_spilled += 1


# The highest piece over a point, or null.
func _food_at(point: Vector2) -> CookPiece:
	for food in _foods:
		if food.covers(point):
			return food
	return null


func _surface_of(food: CookPiece) -> float:
	return food.position.y + food.thickness


# Coverage of the food showing from above (sampled on a grid over all of it),
# less a penalty for spilling.
func _score() -> float:
	if _foods.is_empty() or _on_top.is_empty():
		return 0.0
	var reach_out := 0.0
	var middle := Vector2(_foods[0].position.x, _foods[0].position.z)
	for food in _foods:
		reach_out = maxf(reach_out, middle.distance_to(food.middle()) + food.radius)
	const STEPS := 7
	var step := reach_out / STEPS
	var reach := line_radius * 1.2
	var samples := 0
	var covered := 0
	for gx in range(-STEPS, STEPS + 1):
		for gz in range(-STEPS, STEPS + 1):
			var sample := middle + Vector2(gx, gz) * step
			var food := _food_at(sample)
			# Not right at an edge, where a line can't quite reach.
			if food == null or sample.distance_to(food.middle()) > food.radius * 0.92:
				continue
			samples += 1
			if _sheet.depth_at(sample) > 0.0004:
				covered += 1
				continue
			for blob in _on_top:
				if blob.distance_to(sample) <= reach:
					covered += 1
					break
	var coverage := float(covered) / maxi(samples, 1)
	var spill := float(_spilled) / (_spilled + _on_top.size())
	var neatness := clampf(coverage / target_coverage, 0.0, 1.0) * (1.0 - clampf(spill * spill_penalty, 0.0, 1.0))
	return lerpf(least_score, 1.0, neatness)
