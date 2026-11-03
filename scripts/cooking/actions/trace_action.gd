# TraceAction: draw along a dotted line on each cut piece in turn (the
# context's "cookies"), with the controls of filleting: hold the button on the
# ring at the start and follow the dots; stray too far and it slips, so hold
# it again where it stopped. Each dot passed scores how close you were, and a
# piece scores their average. Two shapes:
#   - twist: a pretzel's loops; the strip of dough follows you round and ends
#     up a rope pretzel.
#   - roll_up: an arrow from a triangle's wide base to its tip; the dough rolls
#     up as you go, into a crescent.
class_name TraceAction
extends CookAction

@export_enum("twist", "roll_up") var shape := "twist"
@export var size := 0.12                   # How big the shape is across.
@export var dots := 14
@export var rope_radius := 0.009           # twist: how thick the pretzel's rope is.
@export_group("Feel")
@export var perfect_offset := 0.007        # Meters off the line that still score full marks...
@export var worst_offset := 0.035          # ...and the offset that scores none.
@export var slip_offset := 0.05            # Further than this and it slips.
@export var grab_reach := 0.045            # How near where it got to you have to grab to (re)start.

var _cookies: Array = []
var _index := 0
var _path: Array[Vector2] = []             # The current piece's line (x, z in the session), evenly spaced.
var _t := 0.0                              # How far along the line it's got.
var _tracing := false
var _passed := 0
var _scores: Array[float] = []
var _piece_scores: Array[float] = []
var _dot_nodes: Array[MeshInstance3D] = []
var _ring: MeshInstance3D
var _head: MeshInstance3D                  # roll_up: the arrow's head, at the tip.
var _rope: Node3D                          # twist: the rope so far.
var _roll: MeshInstance3D                  # roll_up: the rolled-up part so far.
var _dot_material := StandardMaterial3D.new()
var _done_material := StandardMaterial3D.new()
var _moving := false


func _init() -> void:
	view_distance = 0.42
	view_pitch = 70.0


func view_point() -> Vector3:
	if _cookies.is_empty():
		return super.view_point()
	var cookie: Node3D = _cookies[mini(_index, _cookies.size() - 1)]
	return cookie.position


func cursor_area() -> Rect2:
	if _cookies.is_empty():
		return Rect2()
	var area := Rect2(_cookies[0].position.x, _cookies[0].position.z, 0.0, 0.0)
	for cookie: Node3D in _cookies:
		area = area.expand(Vector2(cookie.position.x, cookie.position.z))
	return area.grow(size * 0.6 + 0.03)


func cursor_height() -> float:
	return _top()


func _begin() -> void:
	_cookies = session.context.get("cookies", [])
	if _cookies.is_empty():
		finish(1.0)
		return
	for material in [_dot_material, _done_material]:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dot_material.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	_done_material.albedo_color = Color(0.5, 1.0, 0.5, 0.9)
	_ring = session.make_ring(0.02, Color(0.6, 1.0, 0.55, 0.95))
	_start_on(0)


func end() -> void:
	_ring.queue_free()
	_clear_line()


func update(_delta: float, input: CookInput) -> void:
	if _moving or _index >= _cookies.size():
		return
	var spot := Vector2(input.cursor.x, input.cursor.z)
	_ring.position = _point3(_t)
	_ring.visible = not _tracing
	session.set_status("%s %d of %d: %d%%" % ["Twist" if shape == "twist" else "Roll up", _index + 1, _cookies.size(), roundi(_t * 100.0)])
	if not _tracing:
		if input.just_pressed and spot.distance_to(_point(_t)) <= grab_reach:
			_tracing = true
			session.play_sound("tick", _point3(_t), -8.0, 1.3)
		return
	if not input.held:
		_tracing = false
		return
	var along := _nearest_t(spot)
	var off := spot.distance_to(_point(along))
	if off > slip_offset:
		_tracing = false
		session.pop_text("Slipped!", _point3(_t), -1)
		return
	if along > _t and along - _t < 0.12:
		_t = along
		var score := 1.0 - clampf((off - perfect_offset) / (worst_offset - perfect_offset), 0.0, 1.0)
		while _passed < dots and float(_passed) / (dots - 1) <= _t + 0.001:
			_dot_nodes[_passed].material_override = _done_material
			_piece_scores.append(score)
			_passed += 1
		_shape_so_far()
		if _passed >= dots or _t >= 0.985:
			_finish_piece()


func _start_on(index: int) -> void:
	_index = index
	_t = 0.0
	_passed = 0
	_tracing = false
	_piece_scores.clear()
	_clear_line()
	var cookie: MeshInstance3D = _cookies[index]
	var middle := Vector2(cookie.position.x, cookie.position.z)
	var points: Array[Vector2] = []
	if shape == "twist":
		# A pretzel, from its left end: up across the middle, round the
		# right loop, over the top, round the left loop, and down to its right end.
		var shape_points := [Vector2(-0.22, 0.45), Vector2(0.08, 0.08), Vector2(0.42, -0.22), Vector2(0.32, -0.46), Vector2(0.0, -0.3), Vector2(-0.32, -0.46), Vector2(-0.42, -0.22), Vector2(-0.08, 0.08), Vector2(0.22, 0.45)]
		for i in shape_points.size() - 1:
			var p0: Vector2 = shape_points[maxi(i - 1, 0)]
			var p1: Vector2 = shape_points[i]
			var p2: Vector2 = shape_points[i + 1]
			var p3: Vector2 = shape_points[mini(i + 2, shape_points.size() - 1)]
			for step in 12:
				points.append(middle + _catmull(p0, p1, p2, p3, step / 12.0) * size)
		points.append(middle + shape_points[-1] * size)
	else:  # From the middle of the base (near you) to the tip.
		var half := CookSession.half_of(cookie)
		for step in 13:
			points.append(middle + Vector2(0.0, lerpf(half.y * 0.85, -half.y * 0.9, step / 12.0)))
	_path = _even(points, 100)
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.0035
	dot_mesh.height = 0.007
	for i in dots:
		var dot := MeshInstance3D.new()
		dot.mesh = dot_mesh
		dot.material_override = _dot_material
		dot.position = _point3(float(i) / (dots - 1))
		session.add_child(dot)
		_dot_nodes.append(dot)
	if shape == "roll_up":
		_head = MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.012
		cone.height = 0.022
		cone.material = _dot_material
		_head.mesh = cone
		_head.position = _point3(1.0)
		_head.rotation.x = -PI * 0.5  # Pointing away, up the screen.
		session.add_child(_head)


func _finish_piece() -> void:
	_tracing = false
	_moving = true
	while _passed < dots:
		_piece_scores.append(_piece_scores[-1] if not _piece_scores.is_empty() else 1.0)
		_passed += 1
	var score := average(_piece_scores)
	_scores.append(score)
	var cookie: MeshInstance3D = _cookies[_index]
	_final_shape(cookie)
	session.pop_text(("Twisted!" if shape == "twist" else "Rolled!") if score >= 0.85 else ("Not bad" if score >= 0.6 else "Wonky!"), cookie.position, CookSession.mood_of(score))
	session.play_sound("plop", cookie.position, -6.0, 1.3)
	_clear_line()
	if _index + 1 < _cookies.size():
		session.frame(_cookies[_index + 1].position, view_distance, view_pitch, 0.35)
		await session.get_tree().create_timer(0.35).timeout
		_moving = false
		_start_on(_index + 1)
	else:
		_index = _cookies.size()
		finish(average(_scores))


# What's been traced so far: the rope round the pretzel, or the dough rolled up
# to here (the flat part left shrinking toward the tip).
func _shape_so_far() -> void:
	var cookie: MeshInstance3D = _cookies[_index]
	if shape == "twist":
		if _rope != null:
			_rope.queue_free()
		var points := []
		var count := maxi(int(_t * 40.0), 2)
		for i in count:
			var p := _point(_t * i / (count - 1))
			points.append(Vector3(p.x - cookie.position.x, rope_radius - (cookie.mesh as CylinderMesh).height * 0.5, p.y - cookie.position.z))
		_rope = CookSession.rope(points, Vector2(rope_radius * 0.8, rope_radius))
		for ball: MeshInstance3D in _rope.get_children():
			ball.material_override = (cookie.mesh as CylinderMesh).material
		cookie.add_child(_rope)
		_strip_look(cookie).scale.x = maxf(1.0 - _t, 0.05)  # The strip gets used up.
	else:
		var half := CookSession.half_of(cookie)
		var look := _strip_look(cookie)
		look.scale.z = maxf(1.0 - _t * 0.9, 0.1)
		look.position.z = -half.y * (1.0 - look.scale.z)  # Anchored at the tip.
		if _roll == null:
			_roll = MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 1.0
			mesh.bottom_radius = 1.0
			mesh.height = 1.0
			_roll.mesh = mesh
			_roll.material_override = (cookie.mesh as CylinderMesh).material
			_roll.rotation.z = PI * 0.5  # Lying across.
			cookie.add_child(_roll)
		var radius := 0.006 + _t * 0.012
		_roll.scale = Vector3(radius, half.x * 2.0 * (1.0 - _t * 0.6), radius)
		_roll.position = Vector3(0.0, radius, half.y - _t * half.y * 1.8)


# The piece's final look: a rope pretzel, or a crescent.
func _final_shape(cookie: MeshInstance3D) -> void:
	if shape == "twist":
		var points := []
		for i in 48:
			var p := _point(i / 47.0)
			points.append(Vector3(p.x - cookie.position.x, rope_radius, p.y - cookie.position.z))
		if _rope != null:
			_rope.queue_free()
			_rope = null
		var pretzel := CookSession.rope(points, Vector2(rope_radius * 0.8, rope_radius * 1.1))
		pretzel.position.y = -(cookie.mesh as CylinderMesh).height * 0.5
		session.dress(cookie, pretzel, Vector2(size * 0.45, size * 0.48), rope_radius * 2.0 - (cookie.mesh as CylinderMesh).height * 0.5)
	else:
		var half := CookSession.half_of(cookie)
		var points := []
		for i in 9:  # A curve, thick in the middle, its ends bending toward you.
			var a := lerpf(-1.0, 1.0, i / 8.0)
			points.append(Vector3(a * half.x * 1.4, 0.0, a * a * half.y * 0.6))
		if _roll != null:
			_roll.queue_free()
			_roll = null
		var crescent := CookSession.rope(points, Vector2(0.008, 0.02))
		session.dress(cookie, crescent, Vector2(half.x * 1.5, half.y * 0.6), 0.02)
		session.wobble(crescent, 0.2)


func _strip_look(cookie: MeshInstance3D) -> Node3D:
	for child in cookie.get_children():
		if child.has_meta("look"):
			return child
	return cookie


func _clear_line() -> void:
	for node in _dot_nodes:
		node.queue_free()
	_dot_nodes.clear()
	if _head != null:
		_head.queue_free()
		_head = null


func _point(t: float) -> Vector2:
	var at := clampf(t, 0.0, 1.0) * (_path.size() - 1)
	var i := mini(int(at), _path.size() - 2)
	return _path[i].lerp(_path[i + 1], at - i)


func _point3(t: float) -> Vector3:
	var p := _point(t)
	return Vector3(p.x, _top() + 0.004, p.y)


func _nearest_t(spot: Vector2) -> float:
	# Only near where it's got to: a pretzel crosses itself.
	var best := _t
	var best_gap := INF
	for i in 41:
		var t := clampf(_t - 0.04 + i * 0.004, 0.0, 1.0)
		var gap := spot.distance_squared_to(_point(t))
		if gap < best_gap:
			best_gap = gap
			best = t
	return best


func _top() -> float:
	if _cookies.is_empty():
		return session.work_height
	var cookie: MeshInstance3D = _cookies[mini(_index, _cookies.size() - 1)]
	return cookie.position.y + CookSession.top_of(cookie)


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


# The points respaced evenly along the line, `count` of them.
static func _even(points: Array[Vector2], count: int) -> Array[Vector2]:
	var lengths: Array[float] = [0.0]
	for i in range(1, points.size()):
		lengths.append(lengths[-1] + points[i].distance_to(points[i - 1]))
	var total := lengths[-1]
	var even: Array[Vector2] = []
	var j := 0
	for k in count:
		var want := total * k / (count - 1)
		while j < points.size() - 2 and lengths[j + 1] < want:
			j += 1
		var span := lengths[j + 1] - lengths[j]
		even.append(points[j].lerp(points[j + 1], (want - lengths[j]) / span if span > 0.0 else 0.0))
	return even
