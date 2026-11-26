# LightningAction: the last of Walter's Storm Soup. A zigzag of golden chili
# oil traced across the dark, swirling broth, a lightning bolt over the storm
# (the clouds go on going round under it). Trace it like the menu chalkboard:
# press on the ring at its start and hold, following the dots, and the oil
# goes down as you go; stray too far and you slip. When it's done the bolt
# flashes, the bowl lights up and the thunder rolls. Scores how close to the
# line it was drawn.
class_name LightningAction
extends CookAction

const GOLD := Color(1.0, 0.8, 0.25)
# The bolt across the bowl (x, z), as shares of its radius: down from the far side.
const BOLT := [Vector2(0.3, -0.8), Vector2(-0.2, -0.12), Vector2(0.22, -0.02), Vector2(-0.32, 0.78)]

@export var in_surface := "Bowl"
@export var spin := 2.6
@export var line_width := 0.007
@export_group("Feel")
@export var perfect_offset := 0.006
@export var worst_offset := 0.026
@export var slip_offset := 0.04
@export var grab_reach := 0.03

var _path: Array[Vector2] = []
var _t := 0.0
var _tracing := false
var _drawn := 0
var _scores: Array[float] = []
var _dots: Array[MeshInstance3D] = []
var _ring: MeshInstance3D
var _bottle: Node3D
var _bolt: Node3D
var _paint := StandardMaterial3D.new()
var _rain := 0.0


func _init() -> void:
	view_distance = 0.4
	view_pitch = 66.0


func view_point() -> Vector3:
	return session.surface(in_surface).position


func uses_cursor() -> bool:
	return false  # The bottle shows the spot.


func cursor_height() -> float:
	return _top()


func _top() -> float:
	return session.surface(in_surface).liquid_top() + 0.03  # Over the clouds.


func _begin() -> void:
	var bowl := session.surface(in_surface)
	var points: Array[Vector2] = []
	for share: Vector2 in BOLT:
		points.append(Vector2(bowl.position.x, bowl.position.z) + share * bowl.radius() * 0.85)
	_path = _even(points, 60)
	_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_paint.albedo_color = GOLD
	_bolt = Node3D.new()
	session.add_child(_bolt)
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.0025
	dot_mesh.height = 0.005
	var dot_paint := StandardMaterial3D.new()
	dot_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_paint.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
	dot_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot_mesh.material = dot_paint
	for i in 12:
		var dot := MeshInstance3D.new()
		dot.mesh = dot_mesh
		var p := _point(float(i) / 11.0)
		dot.position = Vector3(p.x, _top() + 0.002, p.y)
		session.add_child(dot)
		_dots.append(dot)
	_ring = session.make_ring(0.014, Color(1.0, 1.0, 1.0, 0.9))
	_bottle = _make_bottle()
	session.add_child(_bottle)
	_bottle.position = Vector3(bowl.position.x + bowl.radius() * 1.3, _top() + 0.06, bowl.position.z)


func end() -> void:
	for dot in _dots:
		if is_instance_valid(dot):
			dot.queue_free()
	if is_instance_valid(_ring):
		_ring.queue_free()
	if is_instance_valid(_bottle):
		_bottle.queue_free()


func update(delta: float, input: CookInput) -> void:
	var bowl := session.surface(in_surface)
	StormCloudsAction.keep_spinning(bowl, spin, delta)
	_rain -= delta
	if _rain <= 0.0:
		_rain = randf_range(0.06, 0.16)
		var at := Vector2.from_angle(randf() * TAU) * bowl.radius() * sqrt(randf()) * 0.85
		bowl.splash(Vector3(bowl.position.x + at.x, bowl.liquid_top(), bowl.position.z + at.y), 0.001)
	if done:
		return
	var spot := Vector2(input.cursor.x, input.cursor.z)
	_bottle.position = _bottle.position.lerp(Vector3(spot.x, _top() + (0.03 if _tracing else 0.06), spot.y), 1.0 - exp(-24.0 * delta))
	_ring.position = Vector3(_point(_t).x, _top() + 0.002, _point(_t).y)
	_ring.visible = not _tracing
	session.set_status("Lightning: %d%%" % roundi(_t * 100.0))
	if not _tracing:
		if input.just_pressed and spot.distance_to(_point(_t)) <= grab_reach:
			_tracing = true
			session.play_sound("drizzle", _ring.position, -12.0, 1.4)
		return
	if not input.held:
		_tracing = false
		return
	var along := _nearest_t(spot)
	var off := spot.distance_to(_point(along))
	if off > slip_offset:
		_tracing = false
		session.pop_text("Slipped!", _ring.position, -1)
		return
	if along > _t and along - _t < 0.2:
		_t = along
		_scores.append(1.0 - clampf((off - perfect_offset) / (worst_offset - perfect_offset), 0.0, 1.0))
		for i in _dots.size():
			if float(i) / (_dots.size() - 1) <= _t + 0.001 and _dots[i].visible:
				_dots[i].visible = false
		_draw_to(_t)
		if _t >= 0.98:
			_strike()


func _draw_to(t: float) -> void:
	var upto := clampi(ceili(t * (_path.size() - 1)), 0, _path.size() - 1)
	if upto <= _drawn:
		return
	ChalkAction.chalk_line(_bolt, _path.slice(_drawn, upto + 1), _top(), line_width, _paint)
	_drawn = upto


# The bolt is down: it flashes, the bowl lights up, and the thunder rolls.
func _strike() -> void:
	_tracing = false
	_draw_to(1.0)
	_ring.visible = false
	_bottle.visible = false
	var bowl := session.surface(in_surface)
	var middle := Vector3(bowl.position.x, _top(), bowl.position.z)
	var liquid := bowl.in_it()
	var broth: Color = liquid.look.get_shader_parameter("soup") if liquid != null else Color(0.14, 0.2, 0.34)
	var lit := broth.lerp(Color(0.75, 0.85, 1.0), 0.6)
	var lights := _bolt.create_tween()
	for i in 2:  # Flash-flash: the bolt goes white and the storm lights up.
		lights.tween_property(_paint, "albedo_color", Color.WHITE, 0.04)
		if liquid != null:
			lights.parallel().tween_method(liquid.set_color, broth, lit, 0.04)
		lights.tween_property(_paint, "albedo_color", GOLD, 0.14)
		if liquid != null:
			lights.parallel().tween_method(liquid.set_color, lit, broth, 0.14)
	session.play_sound("thunder", middle, 2.0, 1.0)
	session.burst(middle + Vector3(0.0, 0.01, 0.0), GOLD, 18, 0.35)
	var score := average(_scores) if not _scores.is_empty() else 1.0
	session.pop_text("Storm Soup!" if score >= 0.75 else "A bit of a drizzle", middle + Vector3(0.0, 0.06, 0.0), CookSession.mood_of(score))
	await session.get_tree().create_timer(0.6).timeout
	finish(score)


# For a reel: onto the ring, then along the bolt.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if done or _path.is_empty():
		return false
	var at := Vector3(_point(_t).x, _top(), _point(_t).y)
	if not _tracing:
		return input.move_to(at, delta, 1.0) and not input.held
	var ahead := _point(minf(_t + 0.08, 1.0))
	input.move_to(Vector3(ahead.x, _top(), ahead.y), delta, 0.2)
	return true


func _point(t: float) -> Vector2:
	var at := clampf(t, 0.0, 1.0) * (_path.size() - 1)
	var i := mini(floori(at), _path.size() - 2)
	return _path[i].lerp(_path[i + 1], at - i)


func _nearest_t(spot: Vector2) -> float:
	var best := _t
	var best_gap := INF
	for i in _path.size():
		var t := float(i) / (_path.size() - 1)
		if t < _t - 0.05 or t > _t + 0.25:
			continue
		var gap := spot.distance_squared_to(_path[i])
		if gap < best_gap:
			best_gap = gap
			best = t
	return best


func _even(points: Array[Vector2], count: int) -> Array[Vector2]:
	var lengths: Array[float] = [0.0]
	for i in range(1, points.size()):
		lengths.append(lengths[-1] + points[i].distance_to(points[i - 1]))
	var out: Array[Vector2] = []
	var j := 0
	for k in count + 1:
		var want := lengths[-1] * k / count
		while j < points.size() - 2 and lengths[j + 1] < want:
			j += 1
		var span := lengths[j + 1] - lengths[j]
		out.append(points[j].lerp(points[j + 1], 0.0 if span <= 0.0 else (want - lengths[j]) / span))
	return out


# A little squeeze bottle of golden chili oil, nozzle down.
func _make_bottle() -> Node3D:
	var bottle := Node3D.new()
	var body := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.014
	tube.bottom_radius = 0.014
	tube.height = 0.06
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.3, 0.12)
	red.roughness = 0.4
	tube.material = red
	body.mesh = tube
	body.position.y = 0.045
	bottle.add_child(body)
	var nozzle := MeshInstance3D.new()
	var tip := CylinderMesh.new()
	tip.top_radius = 0.008
	tip.bottom_radius = 0.002
	tip.height = 0.015
	tip.material = red
	nozzle.mesh = tip
	nozzle.position.y = 0.008
	bottle.add_child(nozzle)
	return bottle
