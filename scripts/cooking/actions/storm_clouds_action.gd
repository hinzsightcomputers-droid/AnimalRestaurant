# StormCloudsAction: Walter's Storm Soup. The dark broth in the bowl is spun
# into a whirlpool and rain patters on it; fluffy cloud dumplings hang over
# the cursor. Press to drop one: in the storm ring (between the calm eye and
# the rim) it's caught and goes round and round with the swirl like a storm
# cloud. Too near the eye or the rim scores less. Scores the average.
class_name StormCloudsAction
extends CookAction

const CLOUD := Color(0.97, 0.97, 1.0)

@export var in_surface := "Bowl"
@export var clouds := 4
@export var spin := 2.6                     # How fast the broth goes round (radians a second).
@export var ring_share := 0.55              # The storm ring, as a share of the bowl's radius...
@export var perfect_within := 0.018         # ...this near it gets full marks...
@export var worst_off := 0.05               # ...this far off, the least.
@export var broth_color := Color(0.14, 0.2, 0.34, 1)

var _cloud: Node3D                          # The one waiting over the cursor.
var _ring: MeshInstance3D
var _dropped := 0
var _scores: Array[float] = []
var _busy := false
var _rain := 0.0
var _first: Node3D                          # The first cloud in: the others go in the gaps round from it (for a reel).


func _init() -> void:
	view_distance = 0.42
	view_pitch = 64.0


func view_point() -> Vector3:
	return session.surface(in_surface).position


func uses_cursor() -> bool:
	return false  # The cloud shows the spot.


func cursor_height() -> float:
	return session.surface(in_surface).liquid_top()


func _begin() -> void:
	var bowl := session.surface(in_surface)
	if bowl.liquid == null:
		bowl.fill_to(0.8, broth_color)
	_ring = session.make_ring(bowl.radius() * ring_share, Color(1.0, 1.0, 1.0, 0.55))
	_ring.position = Vector3(bowl.position.x, bowl.liquid_top() + 0.004, bowl.position.z)
	_next_cloud()


func end() -> void:
	if is_instance_valid(_ring):
		_ring.queue_free()
	if is_instance_valid(_cloud) and not _busy:
		_cloud.queue_free()


func update(delta: float, input: CookInput) -> void:
	var bowl := session.surface(in_surface)
	keep_spinning(bowl, spin, delta)
	_rain -= delta  # A patter of rain on it.
	if _rain <= 0.0:
		_rain = randf_range(0.05, 0.14)
		var at := Vector2.from_angle(randf() * TAU) * bowl.radius() * sqrt(randf()) * 0.85
		bowl.splash(Vector3(bowl.position.x + at.x, bowl.liquid_top(), bowl.position.z + at.y), 0.0012)
	if done or _busy or _cloud == null:
		return
	var spot := Vector3(input.cursor.x, bowl.liquid_top() + 0.07, input.cursor.z)
	_cloud.position = _cloud.position.lerp(spot, 1.0 - exp(-16.0 * delta))
	_cloud.rotation.y += delta * 0.6
	session.set_status("Clouds: %d of %d" % [_dropped, clouds])
	if input.just_pressed:
		_drop(bowl)


# The broth goes on going round (a stirred pot slows down by itself).
static func keep_spinning(bowl: CookSurface, speed: float, delta: float) -> void:
	var liquid := bowl.in_it()
	if liquid != null:
		liquid.spin = move_toward(liquid.spin, speed, delta * 3.0)
		liquid.dragging = true


func _drop(bowl: CookSurface) -> void:
	_busy = true
	var cloud := _cloud
	_cloud = null
	var off := Vector2(cloud.position.x - bowl.position.x, cloud.position.z - bowl.position.z)
	var reach := bowl.radius() * 0.82
	if off.length() > reach:
		off = off.normalized() * reach
	var miss := absf(off.length() - bowl.radius() * ring_share)
	var score := 1.0 - clampf((miss - perfect_within) / (worst_off - perfect_within), 0.0, 0.6)
	var at := Vector3(bowl.position.x + off.x, bowl.liquid_top() + 0.004, bowl.position.z + off.y)
	var fall := cloud.create_tween()
	fall.tween_property(cloud, "position", at, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_callback(func():
		bowl.contents.append(cloud)
		if _first == null:
			_first = cloud
		bowl.splash(at, 0.004)
		if bowl.in_it() != null:
			bowl.in_it().float_thing(cloud, 0.004)
		session.play_sound("plop", at, -4.0, 0.9)
		session.burst(at + Vector3(0.0, 0.01, 0.0), CLOUD, 6, 0.15)
		session.pop_text("Caught!" if score >= 0.9 else ("Cloud!" if score >= 0.6 else "Too far out"), at + Vector3(0.0, 0.05, 0.0), CookSession.mood_of(score))
		_scores.append(score)
		_dropped += 1
		_busy = false
		if _dropped >= clouds:
			finish(average(_scores))
		else:
			_next_cloud())


func _next_cloud() -> void:
	var bowl := session.surface(in_surface)
	_cloud = make_cloud(0.02)
	session.add_child(_cloud)
	_cloud.position = Vector3(bowl.position.x + bowl.radius() * 1.4, bowl.liquid_top() + 0.09, bowl.position.z)


# A fluffy cloud dumpling: a few soft white puffs, flat underneath.
static func make_cloud(size: float) -> Node3D:
	var cloud := Node3D.new()
	var paint := StandardMaterial3D.new()
	paint.albedo_color = CLOUD
	paint.roughness = 0.9
	paint.set_meta(ToonStyle.FOOD, "dough")
	for puff in [[Vector3(0.0, 0.0, 0.0), 1.0], [Vector3(0.9, -0.15, 0.2), 0.75], [Vector3(-0.85, -0.15, -0.1), 0.8], [Vector3(0.2, 0.25, -0.6), 0.65], [Vector3(-0.2, -0.1, 0.75), 0.6]]:
		var ball := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = size * puff[1]
		mesh.height = size * puff[1] * 1.5
		mesh.radial_segments = 16
		mesh.rings = 8
		mesh.material = paint
		ball.mesh = mesh
		ball.position = puff[0] * size
		cloud.add_child(ball)
	return cloud


# For a reel: over the storm ring, a different spot each time, and drop.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if _busy or _cloud == null or done:
		return false
	var bowl := session.surface(in_surface)
	var start := 0.5
	if is_instance_valid(_first):  # In the gap round from the first, wherever the storm has taken it.
		start = Vector2(_first.position.x - bowl.position.x, _first.position.z - bowl.position.z).angle() - 0.35
	var round := Vector2.from_angle(start + _dropped * TAU / clouds) * bowl.radius() * ring_share
	var target := Vector3(bowl.position.x + round.x, bowl.liquid_top(), bowl.position.z + round.y)
	input.move_to(target, delta, 2.0)
	return _cloud.position.distance_to(target + Vector3(0.0, 0.07, 0.0)) < 0.006 and not input.held
