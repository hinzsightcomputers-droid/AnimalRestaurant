# DrizzleAction: hold the button and move to drizzle a line of syrup over the
# top of a stack, with only so much in the bottle. The line is drawn where it
# lands; near the edge it drips a little way down the side. The step ends when
# the bottle's empty. It scores how much of the top got covered (full marks at
# target_coverage), minus what was spilled off it.
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
var _drip_angles: Array[float] = []
var _bottle: Node3D
var _flow: AudioStreamPlayer3D
var _blob_mesh := SphereMesh.new()
var _top: CookPiece
var _top_y := 0.0


func _begin() -> void:
	_left = syrup_seconds
	_bottle = session.make_bottle(syrup_color)
	_flow = session.loop_sound("drizzle", -10.0)
	_top = session.top_piece(target)
	_top_y = (_top.position.y + _top.thickness) if _top != null else session.stack_top(target).y
	var material := StandardMaterial3D.new()
	material.albedo_color = syrup_color
	material.roughness = 0.12
	material.metallic_specular = 0.8
	_blob_mesh.radius = line_radius
	_blob_mesh.height = line_radius * 0.6
	_blob_mesh.radial_segments = 10
	_blob_mesh.rings = 4
	_blob_mesh.material = material


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
		session.pop_text("Delicious!" if score >= 0.8 else ("Bit messy" if _spilled > _on_top.size() * 0.3 else "Needs more syrup"), Vector3(_top.position.x, _top_y, _top.position.z) if _top != null else spot, CookSession.mood_of(score))
		finish(score)


func end() -> void:
	_flow.stop()
	_bottle.queue_free()


func _add_blob(point: Vector2) -> void:
	var blob := MeshInstance3D.new()
	blob.mesh = _blob_mesh
	var spread := randf_range(0.85, 1.15)
	blob.scale = Vector3(spread, 1.0, spread)
	var y := _top_y + 0.001
	if _top != null and point.distance_to(_center()) <= _top.radius:
		_on_top.append(point)
		var from_center := point - _center()
		if from_center.length() > _top.radius * 0.8 and randf() < drip_chance:
			_drip(from_center.angle())
	else:
		_spilled += 1
		var plate := session.surface(target)
		y = (plate.position.y if plate.contains(Vector3(point.x, 0.0, point.y)) else session.work_height) + 0.001
	blob.position = Vector3(point.x, y, point.y)
	session.add_child(blob)


func _center() -> Vector2:
	return Vector2(_top.position.x, _top.position.z)


# A thin run of syrup down the side of the stack, growing for a moment.
func _drip(angle: float) -> void:
	for other in _drip_angles:
		if absf(angle_difference(angle, other)) < 0.3:
			return
	_drip_angles.append(angle)
	var rim := _center() + Vector2.from_angle(angle) * (_top.radius * 1.04 + 0.002)
	var drip := Node3D.new()  # Hangs from the rim: scaling it down makes it longer.
	drip.position = Vector3(rim.x, _top_y, rim.y)
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


# Coverage of the top (sampled on a grid), less a penalty for spilling.
func _score() -> float:
	if _top == null or _on_top.is_empty():
		return 0.0
	var samples := 0
	var covered := 0
	var step := _top.radius / 7.0
	var reach := line_radius * 1.2
	for gx in range(-7, 8):
		for gz in range(-7, 8):
			var offset := Vector2(gx, gz) * step
			if offset.length() > _top.radius * 0.92:
				continue
			samples += 1
			var sample := _center() + offset
			for blob in _on_top:
				if blob.distance_to(sample) <= reach:
					covered += 1
					break
	var coverage := float(covered) / maxi(samples, 1)
	var spill := float(_spilled) / (_spilled + _on_top.size())
	return clampf(coverage / target_coverage, 0.0, 1.0) * (1.0 - clampf(spill * spill_penalty, 0.0, 1.0))
