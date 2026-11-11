# SqueezeAction: squeeze a sauce along dotted guide on the plate, like drawing
# a ketchup smile under a breakfast face. Hold the button to squeeze: a line of
# sauce follows the bottle; let go to stop, hold again to carry on. Each dot
# the line passes close to is ticked off. Done once they're all ticked, or once
# you let go with at least done_share of them. It scores the share of dots
# ticked, less a little for sauce that wandered off the guide, from
# least_score up: it's meant to be easy.
class_name SqueezeAction
extends CookAction

@export var target := "Plate"
@export var sauce_color := Color(0.8, 0.1, 0.06)
@export var sauce_name := "Ketchup"
@export_enum("smile") var shape := "smile"
@export var smile_middle := Vector2(0.0, 0.07)  # Off the target's middle: the smile's corners are level with this.
@export var smile_width := 0.15
@export var smile_dip := 0.035                   # How far the middle dips below the corners.
@export var dots := 9
@export var tick_within := 0.016                 # How near the line has to pass a dot.
@export var stray_from := 0.024                  # Sauce further than this from the guide is wasted.
@export_range(0.0, 1.0) var done_share := 0.6
@export_range(0.0, 1.0) var least_score := 0.4
@export var blob_radius := 0.006
@export var spacing := 0.004
@export var bottle_height := 0.12

var _guide: Array[Vector3] = []
var _ticked: Array[bool] = []
var _dot_nodes: Array[MeshInstance3D] = []
var _blob_mesh: CylinderMesh
var _bottle: Node3D
var _last = null   # Where the last blob went (Vector2), or null between squeezes.
var _blobs := 0
var _stray := 0
var _sound: AudioStreamPlayer3D


func view_point() -> Vector3:
	return session.surface(target).position


func cursor_area() -> Rect2:
	return session.area_of(target, 0.0)


func cursor_height() -> float:
	return _top()


func uses_cursor() -> bool:
	return false  # The bottle shows the spot.


func _begin() -> void:
	var middle := session.surface(target).position
	for i in dots:
		var t := float(i) / maxf(dots - 1, 1)
		var across := (t - 0.5) * smile_width
		var dip := smile_dip * (1.0 - pow(2.0 * t - 1.0, 2.0))  # A curve: lowest in the middle.
		_guide.append(Vector3(middle.x + smile_middle.x + across, _top(), middle.z + smile_middle.y + dip))
		_ticked.append(false)
		var dot := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.004
		ball.height = 0.004
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ball.material = material
		dot.mesh = ball
		dot.position = _guide[i] + Vector3(0.0, 0.002, 0.0)
		session.add_child(dot)
		_dot_nodes.append(dot)
	_blob_mesh = CylinderMesh.new()
	_blob_mesh.top_radius = blob_radius
	_blob_mesh.bottom_radius = blob_radius
	_blob_mesh.height = 0.003
	_blob_mesh.radial_segments = 10
	var sauce := StandardMaterial3D.new()
	sauce.albedo_color = sauce_color
	sauce.roughness = 0.15
	_blob_mesh.material = sauce
	_bottle = session.make_bottle(sauce_color)
	_bottle.position = _guide[0] + Vector3(0.0, bottle_height, 0.0)
	_sound = session.loop_sound("drizzle", -12.0)


func end() -> void:
	for dot in _dot_nodes:
		dot.queue_free()
	_bottle.queue_free()
	_sound.queue_free()


func update(delta: float, input: CookInput) -> void:
	var spot := Vector2(input.cursor.x, input.cursor.z)
	var squeezing := input.held
	var tip := Vector3(spot.x, _top() + (bottle_height * 0.7 if squeezing else bottle_height), spot.y)
	_bottle.position = _bottle.position.lerp(tip, 1.0 - exp(-22.0 * delta))
	_bottle.rotation.z = lerp_angle(_bottle.rotation.z, 0.0 if squeezing else deg_to_rad(-30.0), 1.0 - exp(-14.0 * delta))
	if squeezing:
		if _last == null:
			_squeeze(spot)
			_last = spot
		else:
			var steps := int((_last as Vector2).distance_to(spot) / spacing)
			for i in steps:
				_squeeze((_last as Vector2).lerp(spot, float(i + 1) / steps))
			if steps > 0:
				_last = spot
		if not _sound.playing:
			_sound.play()
	else:
		_last = null
		if _sound.playing:
			_sound.stop()
	var share := _share()
	session.set_status("%s: %d%% of the smile" % [sauce_name, roundi(share * 100.0)])
	if share >= 1.0 or (input.just_released and share >= done_share):
		var waste := float(_stray) / maxf(_blobs, 1)
		var score := lerpf(least_score, 1.0, share) * (1.0 - 0.4 * waste)
		session.pop_text("What a smile!" if score >= 0.85 else ("Cheeky grin" if score >= 0.6 else "A wonky smile"), view_point(), CookSession.mood_of(score))
		finish(score)


# Along the dots, end to end, the button held all the way.
func scripted_hold(delta: float, input: CookInput) -> bool:
	for i in _guide.size():
		if not _ticked[i]:
			var arrived := input.move_to(_guide[i], delta, 0.25)
			return input.held or arrived
	return false


func _squeeze(point: Vector2) -> void:
	var blob := MeshInstance3D.new()
	blob.mesh = _blob_mesh
	blob.position = Vector3(point.x, _top() + 0.0015, point.y)
	session.add_child(blob)
	_blobs += 1
	var nearest := INF
	for i in _guide.size():
		var gap := point.distance_to(Vector2(_guide[i].x, _guide[i].z))
		nearest = minf(nearest, gap)
		if gap <= tick_within and not _ticked[i]:
			_ticked[i] = true
			_dot_nodes[i].visible = false
	if nearest > stray_from and _distance_to_curve(point) > stray_from:
		_stray += 1


func _share() -> float:
	return float(_ticked.count(true)) / maxf(_ticked.size(), 1)


func _distance_to_curve(point: Vector2) -> float:
	var best := INF
	for i in _guide.size() - 1:
		var a := Vector2(_guide[i].x, _guide[i].z)
		var b := Vector2(_guide[i + 1].x, _guide[i + 1].z)
		best = minf(best, point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)))
	return best


func _top() -> float:
	return session.surface(target).position.y
