# SearAction: a cube of steak in a frying pan over a burner (Squared Steak).
# The pan follows the cursor (stick or mouse) around the burner, and the steak
# slides about inside it: start, stop or swing the pan and it skids, bumping
# off the pan's walls. The side facing down cooks, fastest with the pan right
# over the flame and the steak in the middle of the pan.
# Hold the button to brace the pan (it stops following), then flick toward a
# side of the steak: it's tossed and rolls over that way, so the side you
# flicked toward lands face down. Sear all six sides once, then toss it toward
# the plate to serve it. Each side scores how cooked it got (raw, seared or
# burnt, like HeatAction), so a side that lands down twice overcooks.
class_name SearAction
extends CookAction

@export var target := "Plate"
@export_group("Pan")
@export var pan_model := "res://design/restaurant/frying_pan.glb"
@export var pan_length := 0.62           # The pan, handle and all, fitted to this long...
@export var pan_height := 0.07           # ...and this tall (the model's a deep skillet: shallower shows the steak).
@export var pan_inner_radius := 0.17     # Where the steak bumps the wall (from the pan's middle).
@export var pan_floor := 0.024           # The pan's floor, over the counter.
@export var pan_reach := 0.2             # How far the pan can go from the burner's middle.
@export var pan_follow := 12.0           # How quickly the pan catches up with the cursor.
@export_group("Steak")
@export var steak_size := 0.11
@export var raw_color := Color(0.74, 0.32, 0.34)
@export var seared_color := Color(0.36, 0.18, 0.09)
@export var burnt_color := Color(0.13, 0.09, 0.07)
@export var side_seconds := 4.5          # Seconds for a side to be just right, over the flame.
@export var grip := 1.2                  # The pan has to speed up or slow down this hard (m/s²) before the steak slides...
@export var slide_drag := 0.45           # ...and once it's sliding, this much (m/s²) slows it.
@export_range(0.0, 1.0) var bounce := 0.35  # How much speed it keeps off the wall.
@export_group("Toss")
@export var toss_height := 0.15
@export var toss_seconds := 0.5
@export var plate_seconds := 0.6
@export_group("Scoring")
@export var raw_at := 0.45
@export var perfect_from := 0.9
@export var perfect_to := 1.25
@export var burnt_at := 1.8

const NORMALS := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
const SCRIPTED_CIRCLE := 0.06           # A reel swirls the pan this far round the burner.
const SCRIPTED_DONE := 1.0              # How done a reel lets a side get.
const BURNER_TOP := 0.012               # The pan sits on the burner's grate.
const PAN_WIDTH := 0.663                # The pan model's width over its length.

var _pan := Node3D.new()                 # Its middle at the pan's middle, on the floor of the pan.
var _pan_at := Vector2.ZERO              # Where the pan is (x, z)...
var _pan_velocity := Vector2.ZERO        # ...how fast it's going...
var _pan_push := Vector2.ZERO            # ...and how hard it's speeding up (smoothed).
var _burner: Node3D
var _steak := Node3D.new()
var _faces: Array[StandardMaterial3D] = []
var _doneness := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _seared := [false, false, false, false, false, false]  # Sides that have been face down.
var _offset := Vector2.ZERO              # The steak's place in the pan (from its middle)...
var _slide := Vector2.ZERO               # ...and how fast it's sliding.
var _spin := 0.0                         # Its spin from glancing off the wall (radians a second).
var _braced := false                     # The button's down: the pan holds still for a flick.
var _flying := false                     # Mid-toss (or on its way to the plate).
var _arrows: Array[Node3D] = []
var _steam: CPUParticles3D
var _sizzle: AudioStreamPlayer3D
var _smoking := false
var _scripted_pressed := false
var _scripted_time := 0.0


func view_point() -> Vector3:
	return Vector3(0.0, pan_floor, 0.1)


func cursor_area() -> Rect2:
	return Rect2(-pan_reach, -pan_reach, pan_reach * 2.0, pan_reach * 2.0)


func uses_cursor() -> bool:
	return false  # The pan shows where it is.


func _begin() -> void:
	_build_burner()
	_build_pan()
	_build_steak()
	for i in 4:
		var arrow := session.make_arrow(0.05)
		arrow.visible = false
		_arrows.append(arrow)
	_steam = session.make_steam(steak_size * 0.6)
	_steak.add_child(_steam)
	_sizzle = session.loop_sound("sizzle", -6.0)
	_sizzle.play()
	_place_steak()


func end() -> void:
	_sizzle.stop()
	_steam.emitting = false
	for arrow in _arrows:
		arrow.queue_free()
	_burner.queue_free()
	_pan.queue_free()


func update(delta: float, input: CookInput) -> void:
	_move_pan(delta, input)
	if not _flying:
		_slide_steak(delta)
		_cook(delta)
		_place_steak()
		if input.just_pressed:
			_braced = true
		elif _braced and not input.held:
			_braced = false
		if _braced and input.flick != Vector2.ZERO:
			_braced = false
			_toss(input.flick)
	_show_arrows()
	var seared := _seared.count(true)
	if not _flying:
		session.set_status("Last side! Toss it onto the plate when it's seared" if seared >= 6 else "Sides seared: %d / 6" % seared)


# The pan heads for the cursor (or holds still while braced), and how hard it
# speeds up or slows down is what makes the steak slide.
func _move_pan(delta: float, input: CookInput) -> void:
	var goal := _pan_at if _braced or _flying else Vector2(input.cursor.x, input.cursor.z).limit_length(pan_reach)
	var was := _pan_velocity
	var next := _pan_at.lerp(goal, 1.0 - exp(-pan_follow * delta))
	_pan_velocity = (next - _pan_at) / maxf(delta, 0.0001)
	_pan_at = next
	_pan_push = _pan_push.lerp((_pan_velocity - was) / maxf(delta, 0.0001), 1.0 - exp(-30.0 * delta))
	_pan.position = Vector3(_pan_at.x, pan_floor, _pan_at.y)
	_pan.rotation.x = deg_to_rad(-6.0) if _braced else 0.0  # Braced: tipped back a touch, ready to toss.


# The steak in the pan's frame: the pan speeding up pushes it the other way;
# grip holds it until that push is strong enough, then it skids and drags to a
# stop, bouncing off the wall.
func _slide_steak(delta: float) -> void:
	var push := -_pan_push
	if _slide.length() < 0.005 and push.length() < grip:
		_slide = Vector2.ZERO
	else:
		_slide += push * delta
		var speed := _slide.length()
		if speed > 0.0:
			_slide -= _slide / speed * minf(speed, slide_drag * delta)
	_offset += _slide * delta
	var room := pan_inner_radius - steak_size * 0.6
	if _offset.length() > room:
		var out := _offset.normalized()
		_offset = out * room
		var into := _slide.dot(out)
		if into > 0.0:
			var along := _slide - out * into
			_slide = along - out * into * bounce
			_spin += out.cross(along) * 25.0  # A glancing hit turns it.
			if into > 0.06:
				session.play_sound("tick", _steak.position, -6.0, 0.7)
				session.wobble(_steak, 0.08)
	_spin *= exp(-3.0 * delta)
	if absf(_spin) > 0.01:
		_steak.quaternion = Quaternion(Vector3.UP, _spin * delta) * _steak.quaternion


# The side facing down cooks: fastest with the pan over the flame and the
# steak in the middle of the pan.
func _cook(delta: float) -> void:
	var over_flame := clampf(1.0 - _pan_at.length() / (pan_reach * 1.6), 0.25, 1.0)
	var in_middle := lerpf(1.0, 0.7, _offset.length() / pan_inner_radius)
	var down := _down_side()
	_doneness[down] += delta * over_flame * in_middle / side_seconds * GameState.difficulty_value("closeup_pace")
	_seared[down] = true
	_paint(down)
	var amount: float = _doneness[down]
	_steam.emitting = amount > 0.2
	if amount > 1.4:
		if not _smoking:
			_smoking = true
			session.react("dish_burning")
		_steam.color = Color(0.2, 0.18, 0.16)
	else:
		_smoking = false
		_steam.color = Color.WHITE
	_sizzle.volume_db = -9.0 + 5.0 * over_flame


# Over it goes, toward the flick: the side that way ends up face down. Once all
# six are seared, a toss toward the plate serves it instead.
func _toss(flick: Vector2) -> void:
	var plate := session.surface(target)
	var to_plate := Vector2(plate.position.x, plate.position.z) - _pan_at
	if _seared.count(true) >= 6 and flick.normalized().dot(to_plate.normalized()) > 0.5:
		_serve()
		return
	var way := Vector2(signf(flick.x), 0.0) if absf(flick.x) > absf(flick.y) else Vector2(0.0, signf(flick.y))
	var leaving := _down_side()
	_flying = true
	_steam.emitting = false
	session.play_sound("whoosh", _steak.position, -4.0)
	var axis := Vector3(way.y, 0.0, -way.x)  # Rolls over toward the flick.
	var start := _steak.quaternion
	var turned := (Quaternion(axis, PI * 0.5) * start).normalized()
	var from := _offset
	var to := (_offset + way * 0.03).limit_length(pan_inner_radius - steak_size * 0.6)
	var tween := _steak.create_tween()
	tween.tween_method(func(t: float):
		_offset = from.lerp(to, t)
		_place_steak(sin(t * PI) * toss_height)
		_steak.quaternion = start.slerp(turned, t), 0.0, 1.0, toss_seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		_steak.quaternion = _snapped(turned)
		_flying = false
		_slide = way * 0.15  # It lands with a little skid.
		_place_steak()
		session.wobble(_steak, 0.15)
		session.play_sound("plop", _steak.position)
		session.burst(_steak.position, seared_color, 8, 0.25)
		var cooked: float = _doneness[leaving]
		session.pop_text(_verdict(cooked), _steak.position, CookSession.mood_of(score(cooked))))


# Off the pan and onto the plate, and that's the dish.
func _serve() -> void:
	_flying = true
	_steam.emitting = false
	var plate := session.surface(target)
	plate.slide_in()
	session.play_sound("whoosh", _steak.position, -4.0)
	var start := _steak.position
	var land := plate.position + Vector3(0.0, plate.thickness * 0.5 + steak_size * 0.5, 0.0)
	var tween := _steak.create_tween()
	tween.tween_method(func(t: float):
		_steak.position = start.lerp(land, t) + Vector3(0.0, sin(t * PI) * toss_height * 1.4, 0.0), 0.0, 1.0, plate_seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		_steak.position = land
		session.wobble(_steak, 0.15)
		session.play_sound("plop", land)
		var scores := []
		for side in 6:
			scores.append(score(_doneness[side]))
		_sizzle.stop()
		finish(average(scores)))


# The four arrows round the steak while the pan's braced, one per way to toss.
func _show_arrows() -> void:
	for i in 4:
		var arrow := _arrows[i]
		arrow.visible = _braced and not _flying
		if not arrow.visible:
			continue
		var way := Vector2.from_angle(i * PI * 0.5)
		var bob := 0.006 * (1.0 + sin(Time.get_ticks_msec() * 0.01))
		arrow.position = _steak.position + Vector3(way.x, 0.0, way.y) * (steak_size * 0.95 + bob) + Vector3(0.0, -steak_size * 0.4, 0.0)
		arrow.rotation.y = -way.angle()


# The steak sits on the pan's floor at its place in the pan, `lift` above it.
func _place_steak(lift := 0.0) -> void:
	_steak.position = Vector3(_pan_at.x + _offset.x, pan_floor + steak_size * 0.5 + lift, _pan_at.y + _offset.y)


# Which side faces down now (0-5, as NORMALS).
func _down_side() -> int:
	var best := 0
	var lowest := INF
	for i in 6:
		var facing: Vector3 = _steak.quaternion * NORMALS[i]
		if facing.y < lowest:
			lowest = facing.y
			best = i
	return best


# Which side faces `way` (x, z on the surface).
func _side_facing(way: Vector2) -> int:
	var best := 0
	var most := -INF
	for i in 6:
		var facing: Vector3 = _steak.quaternion * NORMALS[i]
		var along := facing.x * way.x + facing.z * way.y
		if along > most:
			most = along
			best = i
	return best


# A turn rounded to the nearest quarter turns, so the steak always lands square.
static func _snapped(turn: Quaternion) -> Quaternion:
	var basis := Basis(turn)
	var columns := []
	for c in 3:
		var v := basis[c]
		var axis := 0
		for a in 3:
			if absf(v[a]) > absf(v[axis]):
				axis = a
		var snapped := Vector3.ZERO
		snapped[axis] = signf(v[axis])
		columns.append(snapped)
	return Basis(columns[0], columns[1], columns[2]).get_rotation_quaternion()


func _paint(side: int) -> void:
	var amount: float = _doneness[side]
	var color := raw_color.lerp(seared_color, clampf(amount, 0.0, 1.0)) if amount <= 1.0 \
		else seared_color.lerp(burnt_color, clampf((amount - 1.0) / (burnt_at - 1.0), 0.0, 1.0))
	_faces[side].albedo_color = color


# 0..1 for how well a side came out at this doneness.
func score(amount: float) -> float:
	if amount < perfect_from:
		return clampf((amount - raw_at) / (perfect_from - raw_at), 0.0, 1.0)
	if amount <= perfect_to:
		return 1.0
	return clampf(1.0 - (amount - perfect_to) / (burnt_at - perfect_to), 0.0, 1.0)


func _verdict(amount: float) -> String:
	if amount < raw_at:
		return "Still raw!"
	if amount < perfect_from:
		return "Bit pale"
	if amount <= perfect_to:
		return "Seared!"
	if amount < burnt_at:
		return "Bit dark"
	return "Burnt!"


# A reel: swirls the pan gently and tosses each side once it's seared, toward a
# side that hasn't been down yet, then onto the plate.
func scripted_hold(delta: float, input: CookInput) -> bool:
	_scripted_time += delta
	if _flying:
		_scripted_pressed = false
		return false
	var swirl := Vector2.from_angle(_scripted_time * 2.2) * SCRIPTED_CIRCLE
	input.move_to(Vector3(swirl.x, 0.0, swirl.y), delta, 0.4)
	if _doneness[_down_side()] < SCRIPTED_DONE:
		return false
	if not _scripted_pressed:
		_scripted_pressed = true
		return true
	var plate := session.surface(target)
	var way := Vector2(plate.position.x, plate.position.z) - _pan_at
	if _seared.count(true) < 6:
		for candidate in [Vector2.RIGHT, Vector2.LEFT, Vector2(0.0, 1.0), Vector2(0.0, -1.0)]:
			way = candidate
			if not _seared[_side_facing(candidate)]:
				break
	input.flick = way.normalized()
	return true


# --- Building ---------------------------------------------------------------

# A gas ring on the counter: a dark iron grate and a ring of little flames.
func _build_burner() -> void:
	_burner = Node3D.new()
	session.add_child(_burner)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.15, 0.15)
	iron.roughness = 0.6
	var plate := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.2
	disc.bottom_radius = 0.21
	disc.height = 0.012
	disc.material = iron
	plate.mesh = disc
	plate.position.y = 0.006
	_burner.add_child(plate)
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color(1.0, 0.62, 0.2)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.5, 0.15)
	flame.emission_energy_multiplier = 2.0
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 12:
		var tongue := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.008
		cone.height = 0.012  # Under the pan: they show round its edge when it moves off the middle.
		cone.radial_segments = 6
		cone.material = flame
		tongue.mesh = cone
		var spot := Vector2.from_angle(i * TAU / 12.0) * 0.07
		tongue.position = Vector3(spot.x, 0.007, spot.y)
		_burner.add_child(tongue)


func _build_pan() -> void:
	session.add_child(_pan)
	var fit := ModelFit.place(pan_model, _pan, Vector3.ZERO, Vector3(pan_length, pan_height, pan_length * PAN_WIDTH))
	if fit != null:
		fit.stretch = true
		# The model's pan is toward -x with its handle off to +x: its middle on this node.
		fit.position = Vector3(pan_length * 0.17, BURNER_TOP - pan_floor, 0.0)
		return
	var steel := StandardMaterial3D.new()  # Without the model: a plain dark pan.
	steel.albedo_color = Color(0.18, 0.18, 0.2)
	var body := MeshInstance3D.new()
	var dish := CylinderMesh.new()
	dish.top_radius = pan_inner_radius + 0.02
	dish.bottom_radius = pan_inner_radius
	dish.height = 0.04
	dish.material = steel
	body.mesh = dish
	body.position.y = 0.0
	_pan.add_child(body)


# Six faces, each its own material so each side browns on its own, round a
# slightly smaller pink middle that fills the edges.
func _build_steak() -> void:
	session.add_child(_steak)
	var half := steak_size * 0.5
	for i in 6:
		var material := StandardMaterial3D.new()
		material.albedo_color = raw_color
		material.roughness = 0.7
		_faces.append(material)
		var face := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(steak_size, steak_size)
		quad.material = material
		face.mesh = quad
		var normal: Vector3 = NORMALS[i]
		face.position = normal * half
		face.basis = _facing(normal)
		_steak.add_child(face)
	var middle := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * steak_size * 0.985
	var pink := StandardMaterial3D.new()
	pink.albedo_color = raw_color.darkened(0.15)
	box.material = pink
	middle.mesh = box
	_steak.add_child(middle)


# A basis that turns a quad (facing +z) to face `normal`.
static func _facing(normal: Vector3) -> Basis:
	if normal.is_equal_approx(Vector3.BACK):
		return Basis.IDENTITY
	if normal.is_equal_approx(Vector3.FORWARD):
		return Basis(Vector3.UP, PI)
	var axis := Vector3.BACK.cross(normal).normalized()
	return Basis(axis, Vector3.BACK.angle_to(normal))
