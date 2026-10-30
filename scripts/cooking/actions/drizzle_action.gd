# DrizzleAction: hold the button and move to drizzle a line of syrup over the
# top of a stack, with only so much in the bottle. The line is drawn where it
# lands, on whichever piece is highest there (so a wider one underneath gets
# some too); near a piece's round edge it drips a little way down the side. The
# step ends when the bottle's empty. It scores how much of the food showing
# from above got covered (full marks at target_coverage), minus what was
# spilled off it.
class_name DrizzleAction
extends CookAction

@export var target := "Plate"
@export var syrup_seconds := 3.0              # How long the bottle lasts while held.
@export var syrup_color := Color(0.5, 0.24, 0.05)
@export var line_radius := 0.013              # How thick the line is.
@export var spacing := 0.007                  # Gap between the blobs that make up the line.
@export_range(0.0, 1.0) var target_coverage := 0.45  # Share of the top to cover for full marks.
@export var spill_penalty := 1.5              # How much each spilled share costs.
@export_range(0.0, 1.0) var drip_chance := 0.35      # Chance a blob near the edge drips.
@export var drip_length := Vector2(0.015, 0.04)      # Shortest and longest drip.
@export var bottle_height := 0.14

var _left := 0.0
var _last_point = null       # Where the line got to (Vector2), or null between drizzles.
var _on_top: Array[Vector2] = []
var _spilled := 0
var _drip_angles: Array = []  # [piece, angle] for each drip, so they don't bunch up.
var _bottle: Node3D
var _flow: AudioStreamPlayer3D
var _blob_mesh := SphereMesh.new()
var _foods: Array[CookPiece] = []  # The pieces in the stack, highest first.
var _top_y := 0.0


func _begin() -> void:
	_left = syrup_seconds
	_bottle = session.make_bottle(syrup_color)
	_flow = session.loop_sound("drizzle", -10.0)
	for entry in session.stack_of(target):
		if entry["node"] is CookPiece:
			_foods.push_front(entry["node"])
	_top_y = _surface_of(_foods[0]) if not _foods.is_empty() else session.stack_top(target).y
	var material := StandardMaterial3D.new()
	material.albedo_color = syrup_color
	material.roughness = 0.12
	material.metallic_specular = 0.8
	_blob_mesh.radius = line_radius
	_blob_mesh.height = line_radius * 0.6
	_blob_mesh.radial_segments = 10
	_blob_mesh.rings = 4
	_blob_mesh.material = material


func view_point() -> Vector3:
	return Vector3(session.stack_top(target).x, _top_y, session.stack_top(target).z)


func cursor_area() -> Rect2:
	return session.area_of(target, 0.03) if view_distance > 0.0 else Rect2()


func cursor_height() -> float:
	return _top_y


func update(delta: float, input: CookInput) -> void:
	var spot := input.cursor
	var pouring := input.held and _left > 0.0
	_bottle.position = _bottle.position.lerp(spot + Vector3(0.0, bottle_height, 0.0), 1.0 - exp(-20.0 * delta))
	_bottle.rotation.z = lerp_angle(_bottle.rotation.z, deg_to_rad(-8.0 if pouring else -40.0), 1.0 - exp(-14.0 * delta))
	if pouring:
		_left = maxf(0.0, _left - delta)
		var point := Vector2(spot.x, spot.z)
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
	else:
		_last_point = null
		if _flow.playing:
			_flow.stop()
	session.set_status("Syrup left: %d%%" % ceili(_left / syrup_seconds * 100.0))
	if _left <= 0.0:
		var score := _score()
		session.pop_text("Delicious!" if score >= 0.8 else ("Bit messy" if _spilled > _on_top.size() * 0.3 else "Needs more syrup"), Vector3(_foods[0].position.x, _top_y, _foods[0].position.z) if not _foods.is_empty() else spot, CookSession.mood_of(score))
		finish(score)


func end() -> void:
	_flow.stop()
	_bottle.queue_free()


func _add_blob(point: Vector2) -> void:
	var blob := MeshInstance3D.new()
	blob.mesh = _blob_mesh
	var spread := randf_range(0.85, 1.15)
	blob.scale = Vector3(spread, 1.0, spread)
	var y := 0.0
	var food := _food_at(point)
	if food != null:
		_on_top.append(point)
		y = _surface_of(food) + 0.001
		var from_middle := point - food.middle()
		var round_edge := not food.folded or from_middle.y < -food.radius * 0.3  # A folded one's straight edge is its fold: no drips.
		if round_edge and from_middle.length() > food.radius * 0.8 and randf() < drip_chance:
			_drip(food, from_middle.angle())
	else:
		_spilled += 1
		var plate := session.surface(target)
		y = (plate.position.y if plate.contains(Vector3(point.x, 0.0, point.y)) else session.work_height) + 0.001
	blob.position = Vector3(point.x, y, point.y)
	session.add_child(blob)


# The highest piece over a point, or null.
func _food_at(point: Vector2) -> CookPiece:
	for food in _foods:
		if food.covers(point):
			return food
	return null


func _surface_of(food: CookPiece) -> float:
	return food.position.y + food.thickness


# A thin run of syrup down the side of a piece, growing for a moment.
func _drip(food: CookPiece, angle: float) -> void:
	for other in _drip_angles:
		if other[0] == food and absf(angle_difference(angle, other[1])) < 0.3:
			return
	_drip_angles.append([food, angle])
	var rim := food.middle() + Vector2.from_angle(angle) * (food.radius * 1.04 + 0.002)
	var drip := Node3D.new()  # Hangs from the rim: scaling it down makes it longer.
	drip.position = Vector3(rim.x, _surface_of(food), rim.y)
	var strand := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = line_radius * 0.55
	mesh.height = 1.0
	mesh.material = _blob_mesh.material
	strand.mesh = mesh
	strand.position.y = -0.5
	drip.add_child(strand)
	drip.scale = Vector3(1.0, 0.001, 1.0)
	session.add_child(drip)
	var length := randf_range(drip_length.x, drip_length.y)
	drip.create_tween().tween_property(drip, "scale:y", length, 1.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


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
			for blob in _on_top:
				if blob.distance_to(sample) <= reach:
					covered += 1
					break
	var coverage := float(covered) / maxi(samples, 1)
	var spill := float(_spilled) / (_spilled + _on_top.size())
	return clampf(coverage / target_coverage, 0.0, 1.0) * (1.0 - clampf(spill * spill_penalty, 0.0, 1.0))
