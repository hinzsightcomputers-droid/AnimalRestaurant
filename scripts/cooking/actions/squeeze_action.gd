# SqueezeAction: squeeze a sauce along dotted guide on the plate, like drawing
# a ketchup smile under a breakfast face. Hold the button to squeeze: a line of
# sauce follows the bottle; let go to stop, hold again to carry on. Each dot
# the line passes close to is ticked off. Done once they're all ticked, or once
# you've let go for finish_after seconds with at least done_share of them (so
# letting go to line up the next bit never ends it early). The guide is a dark
# dotted line drawn over everything, so it shows on the pale plate in any
# light. It scores the share of dots ticked, less a little for sauce that
# wandered off the guide, from least_score up: it's meant to be easy.
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
@export var finish_after := 1.5                  # Seconds let go (with done_share drawn) before it's done.
@export var guide_color := Color(0.36, 0.2, 0.1, 0.85)
@export var blob_radius := 0.006
@export var spacing := 0.004
@export var bottle_height := 0.04          # How high the nozzle is over the plate (lower still while squeezing).
@export var bottle_lean := 55.0           # Degrees the bottle leans away from the cook, so it never hides the guide...
@export var bottle_side_turn := 40.0      # ...and toward the side already drawn (it swings over when you go the other way).
@export var bottle_scale := 0.5          # A small squeeze bottle: the camera's close.

var _guide: Array[Vector3] = []
var _ticked: Array[bool] = []
var _dot_nodes: Array[MeshInstance3D] = []
var _dashes: Array[MeshInstance3D] = []  # The guide line between dots i and i + 1.
var _let_go := 0.0  # Seconds since the button was let go.
var _sheet: SauceSheet
var _bottle: Node3D
var _last = null   # Where the last blob went (Vector2), or null between squeezes.
var _blobs := 0
var _stray := 0
var _sound: AudioStreamPlayer3D
var _side := -1.0  # Which way the bottle leans: -1 left, 1 right. It starts at the left corner, the smile ahead to the right.


func view_point() -> Vector3:
	return session.surface(target).position


func cursor_area() -> Rect2:
	return session.area_of(target, 0.0)


func cursor_height() -> float:
	return _top()


func uses_cursor() -> bool:
	return true  # The dot shows where the sauce lands (the bottle leans out of the way).


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
		ball.radius = 0.005
		ball.height = 0.005
		ball.material = _guide_material()
		dot.mesh = ball
		dot.position = _guide[i] + Vector3(0.0, 0.002, 0.0)
		session.add_child(dot)
		_dot_nodes.append(dot)
	for i in _guide.size() - 1:  # A thin line joining the dots.
		var a := _guide[i] + Vector3(0.0, 0.002, 0.0)
		var b := _guide[i + 1] + Vector3(0.0, 0.002, 0.0)
		var dash := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.0018, 0.0008, a.distance_to(b))
		bar.material = _guide_material(0.55)
		dash.mesh = bar
		session.add_child(dash)
		dash.position = (a + b) * 0.5
		dash.look_at(dash.global_transform * Vector3.ZERO + (session.global_transform.basis * (b - a)), Vector3.UP)
		_dashes.append(dash)
	_sheet = session.make_sauce(target, "ketchup", sauce_color)
	_bottle = session.make_bottle(sauce_color)
	_bottle.position = _guide[0] + Vector3(0.0, bottle_height, 0.0)
	_bottle.scale = Vector3.ONE * bottle_scale
	_turn_bottle()
	_sound = session.loop_sound("drizzle", -12.0)


func end() -> void:
	for dot in _dot_nodes + _dashes:
		dot.queue_free()
	_bottle.queue_free()
	_sound.queue_free()


func update(delta: float, input: CookInput) -> void:
	var spot := Vector2(input.cursor.x, input.cursor.z)
	var squeezing := input.held
	var tip := Vector3(spot.x, _top() + (bottle_height * 0.4 if squeezing else bottle_height), spot.y)
	var moved := tip.x - _bottle.position.x
	_bottle.position = _bottle.position.lerp(tip, 1.0 - exp(-22.0 * delta))
	if absf(moved) > 0.002:  # Lean back over what's drawn, away from where it's going.
		_side = move_toward(_side, -signf(moved), delta * 4.0)
		_turn_bottle()
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
	_let_go = 0.0 if squeezing or _blobs == 0 else _let_go + delta
	session.set_status("%s: %d%% of the smile" % [sauce_name, roundi(share * 100.0)])
	if share >= 1.0 or (_let_go >= finish_after and share >= done_share):
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


# Its tip stays on the spot; its body leans away and to one side (_side).
func _turn_bottle() -> void:
	_bottle.rotation = Vector3(-deg_to_rad(bottle_lean), deg_to_rad(-bottle_side_turn) * _side, 0.0)


func _squeeze(point: Vector2) -> void:
	_sheet.pour(point, blob_radius * blob_radius * spacing * 1.9, maxf(blob_radius * 1.25, _sheet.cell * 1.6))
	_blobs += 1
	var nearest := INF
	for i in _guide.size():
		var gap := point.distance_to(Vector2(_guide[i].x, _guide[i].z))
		nearest = minf(nearest, gap)
		if gap <= tick_within and not _ticked[i]:
			_ticked[i] = true
			_dot_nodes[i].visible = false
			for d in [i - 1, i]:  # A bit of line goes once both its ends are done.
				if d >= 0 and d < _dashes.size() and _ticked[d] and _ticked[d + 1]:
					_dashes[d].visible = false
	if nearest > stray_from and _distance_to_curve(point) > stray_from:
		_stray += 1


# Dark, see-through and drawn over the food and the plate.
func _guide_material(alpha := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(guide_color, guide_color.a * alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.render_priority = 1
	return material


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
