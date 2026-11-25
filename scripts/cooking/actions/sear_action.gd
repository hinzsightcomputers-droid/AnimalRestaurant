# SearAction: a cube of steak in a frying pan over a burner (Squared Steak).
# Slide, then toss:
#   - The stick (or keys; the mouse: where it is from the pan's middle) tilts
#     the pan and the cube slides that way. It slows on its own and bumps softly
#     off the rim. Its speed is capped, so wild stick work can't fling it about.
#   - The middle of the pan is hottest, the edge cooler; only the face down
#     cooks: raw, seared (steam), burnt (smoke). Left still too long, the cube
#     sticks and its face smokes: a nudge of the pan frees it.
#   - Hold the button to wind up: the pan dips and the meter fills. Let go
#     while pushing the stick (or swipe the mouse while holding) to toss it that
#     way. A light toss rolls it one face, a strong one two faces (the top lands
#     down), too strong and it flies out onto the counter: press to put it back,
#     and it costs a little. Tossed from near the rim it catches the edge and
#     rolls one face more, somewhere you didn't plan; from the middle it lands
#     clean.
#   - With every face cooked, toss it toward the plate to serve.
# The map in the corner is the cube unfolded round the face down: the four
# beside it land with a light toss that way, the last one (the top) with a
# strong toss. Each face scores how close it got to seared, plus a little for
# clean landings and for never smoking, less a little for each drop.
class_name SearAction
extends CookAction

@export var target := "Plate"
@export_group("Pan")
@export var pan_model := "res://design/restaurant/frying_pan.glb"
@export var pan_length := 0.62           # The pan, handle and all, fitted to this long...
@export var pan_height := 0.07           # ...and this tall (the model's a deep skillet: shallower shows the steak).
@export var pan_floor := 0.024           # The pan's floor, over the counter.
@export var pan_inner_radius := 0.17
@export_group("Sliding")
@export var tilt_push := 0.9             # m/s² the cube speeds up with the pan tipped all the way.
@export var friction := 2.8              # How fast it slows on its own (a share of its speed, a second).
@export var max_speed := 0.32            # m/s, however hard it's pushed.
@export var rim_bounce := 0.3            # Of its speed into the rim, coming back.
@export var stick_after := 2.2           # Seconds sitting still before it sticks.
@export var nudge_to_free := 0.3         # Seconds of a firm tilt that free it.
@export_group("Steak")
@export var steak_size := 0.08
@export var raw_color := Color(0.74, 0.32, 0.34)
@export var seared_color := Color(0.36, 0.18, 0.09)
@export var burnt_color := Color(0.13, 0.09, 0.07)
@export var side_seconds := 3.2          # Seconds for a face to be just right, in the middle of the pan.
@export var edge_heat := 0.5             # How fast a face cooks at the rim, against the middle.
@export var stuck_heat := 1.5            # How much faster a stuck face cooks.
@export_group("Toss")
@export var wind_seconds := 1.0          # Holding this long fills the meter.
@export var two_faces_from := 0.45       # Meter share for a two-face tumble...
@export var out_from := 0.85             # ...and for over the rim onto the counter.
@export var rim_zone := 0.7              # Tossed from further out than this share of the room, it catches the rim.
@export var toss_seconds := 0.6
@export var hang := 0.75                 # The slow moment at the top of the toss (0 none, under 1).
@export var plate_seconds := 0.6
@export_group("Scoring")
@export var raw_at := 0.45
@export var perfect_from := 0.9
@export var perfect_to := 1.25
@export var burnt_at := 1.8
@export var clean_bonus := 0.04          # At most, for every toss landing clean.
@export var no_smoke_bonus := 0.04
@export var drop_cost := 0.08            # For each time it lands on the counter.

const NORMALS := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
const WAYS := [Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)]
const BURNER_TOP := 0.012               # The pan sits on the burner's grate.
const PAN_WIDTH := 0.663                # The pan model's width over its length.
const TILE := 30                        # The map's squares, in pixels (smaller in split screen).
const MOUSE_TILT_REACH := 0.2           # The mouse this far from the pan's middle tips it all the way.

var _pan := Node3D.new()                 # Its middle at the pan's middle, on the floor of the pan.
var _burner: Node3D
var _steak := Node3D.new()
var _faces: Array[Color] = []            # Each side's color, its alpha how done it is.
var _look := ShaderMaterial.new()
var _fat: CPUParticles3D                 # Sizzling round where it sits.
var _doneness := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _offset := Vector2.ZERO              # The cube's place in the pan (from its middle)...
var _velocity := Vector2.ZERO            # ...and how fast it's sliding.
var _still := 0.0                        # Seconds it's sat still.
var _stuck := false
var _nudging := 0.0                      # Seconds of firm tilt while stuck.
var _winding := false
var _power := 0.0                        # The meter, 0..1.
var _aim := Vector2.ZERO                 # Where the toss goes (a swipe while winding sticks).
var _flying := false                     # Mid-toss (or on its way to the plate).
var _on_counter := false                 # Tossed too hard: waiting to be put back.
var _flip_told := false                  # "Toss it!" shown for the face down now.
var _tosses := 0
var _clean := 0
var _drops := 0
var _ever_smoked := false
var _smoking := false
var _aim_arrow: Node3D
var _guides: Array[Node3D] = []          # One arrow per way to toss, round the cube.
var _go_paint: StandardMaterial3D        # A toss that way lands a face still to cook...
var _done_paint: StandardMaterial3D      # ...or one already done.
var _meter: MeshInstance3D
var _meter_paint: StandardMaterial3D
var _steam: CPUParticles3D
var _sizzle: AudioStreamPlayer3D
var _map: Control
var _tiles := {}                         # Map square name ("down", "top", or a way's index) -> Panel.
var _scripted_goal := 0.0                # A reel's wind-up: let go at this much power...
var _scripted_aim := Vector2.ZERO        # ...pushing this way.
var _scripted_wait := 0.0


func view_point() -> Vector3:
	return Vector3(0.0, pan_floor, 0.1)


func uses_cursor() -> bool:
	return false  # The cube shows where it is.


func _begin() -> void:
	_build_burner()
	_build_pan()
	_build_steak()
	_aim_arrow = session.make_arrow(0.07)
	_aim_arrow.visible = false
	for i in 4:
		var guide := session.make_arrow(0.05)
		guide.visible = false
		_guides.append(guide)
	var paint: StandardMaterial3D = ((_guides[0].get_child(0) as MeshInstance3D).mesh as PrimitiveMesh).material
	_go_paint = paint.duplicate()
	_go_paint.albedo_color = Color(0.45, 0.95, 0.4, 0.95)
	_done_paint = paint.duplicate()
	_done_paint.albedo_color = Color(0.65, 0.65, 0.65, 0.5)
	_meter = session.make_meter(Vector3(0.0, pan_floor + 0.002, pan_inner_radius + 0.07), 0.24, Vector2(0.0, out_from), Color(1.0, 0.85, 0.3))
	_meter_paint = (_meter.mesh as PrimitiveMesh).material
	_meter.get_parent().visible = false
	_steam = session.make_steam(steak_size * 0.6)
	_steak.add_child(_steam)
	_sizzle = session.loop_sound("sizzle", -6.0)
	_sizzle.play()
	_build_map()
	_place_steak()


func end() -> void:
	_fat.emitting = false
	_sizzle.stop()
	_steam.emitting = false
	_aim_arrow.queue_free()
	for guide in _guides:
		guide.queue_free()
	_meter.get_parent().queue_free()
	_burner.queue_free()
	_pan.queue_free()
	if is_instance_valid(_map):
		_map.queue_free()


func update(delta: float, input: CookInput) -> void:
	if _flying or _on_counter:
		for guide in _guides:
			guide.visible = false
	if _flying:
		return
	if _on_counter:
		session.set_status("On the counter! Press to put it back in the pan")
		if input.just_pressed:
			_put_back()
		return
	var tilt := _tilt(input)
	if input.just_pressed:
		_winding = true
		_power = 0.0
		_aim = Vector2.ZERO
	if _winding:
		_power = minf(_power + delta / wind_seconds, 1.0)
		if input.flick != Vector2.ZERO:
			_aim = input.flick
		elif input.stick.length() > 0.4:
			_aim = input.stick
		elif input.using_mouse and tilt.length() > 0.3:
			_aim = tilt
	_pan.rotation = _pan.rotation.lerp(Vector3(-0.1 if _winding else tilt.y * 0.1, 0.0, 0.0 if _winding else -tilt.x * 0.1), 1.0 - exp(-12.0 * delta))
	_slide(delta, Vector2.ZERO if _winding else tilt)
	_cook(delta)
	_place_steak()
	_show_aim()
	_show_map()
	if _winding and input.just_released:
		_winding = false
		_toss(_aim, _power)
		return
	if _stuck:
		session.set_status("Stuck! Nudge the pan to free it")
	elif _all_cooked():
		session.set_status("All sides cooked! Toss it toward the plate")
	elif _doneness[_down_side()] >= perfect_from:
		session.set_status("Seared! Toss it toward a green arrow (%d / 6)" % _seared_count())
	else:
		session.set_status("Sides seared: %d / 6" % _seared_count())


# The stick (or keys) as the pan's tilt; with the mouse, where it is from the
# pan's middle.
func _tilt(input: CookInput) -> Vector2:
	if input.using_mouse:
		return (Vector2(input.cursor.x, input.cursor.z) / MOUSE_TILT_REACH).limit_length(1.0)
	return input.stick.limit_length(1.0)


# Tilting speeds it up downhill; friction slows it; the rim bumps it back.
# Stuck, it holds still until nudged firmly for a moment.
func _slide(delta: float, tilt: Vector2) -> void:
	if _stuck:
		_nudging = _nudging + delta if tilt.length() > 0.5 else maxf(_nudging - delta, 0.0)
		if _nudging < nudge_to_free:
			return
		_unstick()
		_velocity = tilt.normalized() * max_speed * 0.4
		session.pop_text("Free!", _steak.position + Vector3(0.0, steak_size, 0.0), 1)
	_velocity += tilt * tilt_push * delta
	_velocity *= exp(-friction * delta)
	_velocity = _velocity.limit_length(max_speed)
	_offset += _velocity * delta
	var room := _room()
	if _offset.length() > room:
		var out := _offset.normalized()
		_offset = out * room
		var into := _velocity.dot(out)
		if into > 0.0:
			_velocity -= out * into * (1.0 + rim_bounce)
			if into > 0.08:
				session.play_sound("tick", _steak.position, -10.0, 0.7)
				session.wobble(_steak, 0.05)
	if _velocity.length() < 0.01 and not _winding:
		_still += delta
		if _still > stick_after:
			_stuck = true
			_nudging = 0.0
			_velocity = Vector2.ZERO
			session.pop_text("Sticking!", _steak.position + Vector3(0.0, steak_size, 0.0), -1)
			session.wobble(_steak, 0.08)
	else:
		_still = 0.0


func _unstick() -> void:
	_stuck = false
	_still = 0.0
	_nudging = 0.0


# How far the cube's middle can go from the pan's: its corners touch the rim.
func _room() -> float:
	return pan_inner_radius - steak_size * 0.7


# The face down cooks, fastest in the middle; stuck, faster still and smoking.
func _cook(delta: float) -> void:
	var down := _down_side()
	var was: float = _doneness[down]
	var heat := _heat() * (stuck_heat if _stuck else 1.0)
	_doneness[down] += delta * heat / side_seconds * GameState.difficulty_value("closeup_pace")
	_paint(down)
	var amount: float = _doneness[down]
	if was < perfect_from and amount >= perfect_from and not _flip_told:
		_flip_told = true
		session.pop_text("Serve it!" if _all_cooked() else "Toss it!", _steak.position + Vector3(0.0, steak_size, 0.0), 1)
		session.play_sound("tick", _steak.position, -2.0, 1.4)
	_steam.emitting = amount > 0.2 or _stuck
	_fat.position = Vector3(_steak.position.x, pan_floor + 0.002, _steak.position.z)
	_fat.emitting = true
	_fat.speed_scale = 0.6 + heat * 0.8
	var smoking := amount > 1.4 or _stuck
	if smoking and not _smoking:
		session.react("dish_burning")
		_ever_smoked = true
	_smoking = smoking
	_steam.color = Color(0.2, 0.18, 0.16) if smoking else Color.WHITE
	_sizzle.volume_db = -11.0 + 6.0 * heat


func _heat() -> float:
	return lerpf(1.0, edge_heat, clampf(_offset.length() / _room(), 0.0, 1.0))


# Up it goes toward `way` (snapped to the nearest of the four): one face, two,
# or out of the pan; from near the rim it catches the edge and rolls once more.
func _toss(way: Vector2, power: float) -> void:
	_fat.emitting = false
	_unstick()
	if way.length() < 0.2:  # No direction: a little hop, same face down.
		session.wobble(_steak, 0.15)
		session.pop_text("Push a way as you let go", _steak.position + Vector3(0.0, steak_size, 0.0), 0)
		return
	way = Vector2(signf(way.x), 0.0) if absf(way.x) > absf(way.y) else Vector2(0.0, signf(way.y))
	var plate := session.surface(target)
	var to_plate := Vector2(plate.position.x, plate.position.z) - _offset
	if _all_cooked() and power < out_from and way.dot(to_plate.normalized()) > 0.5:
		_serve()
		return
	_tosses += 1
	var out := power >= out_from
	var faces := 2 if power >= two_faces_from else 1
	var rim := not out and _offset.length() > _room() * rim_zone
	var extra := Vector2.ZERO
	if rim:  # Caught the edge: one more roll, off to a side.
		extra = Vector2(-way.y, way.x) * (1.0 if randf() < 0.5 else -1.0)
	var leaving := _down_side()
	var start_turn := _steak.quaternion
	var axis := Vector3(way.y, 0.0, -way.x)  # Rolls over toward `way`.
	var extra_axis := Vector3(extra.y, 0.0, -extra.x)
	var spin := faces * PI * 0.5
	var from := _steak.position
	var land: Vector3
	if out:
		faces = randi_range(1, 3)
		spin = faces * PI * 0.5
		var spot := way * (pan_inner_radius + 0.16)
		land = Vector3(spot.x, steak_size * 0.5, spot.y)
	else:
		var to := (_offset + way * (0.02 + 0.02 * faces)).limit_length(_room())
		if rim:
			to = _offset * 0.6
		land = Vector3(to.x, pan_floor + steak_size * 0.5, to.y)
	var height := 0.1 + 0.05 * faces + (0.1 if out else 0.0)
	var seconds := toss_seconds * (1.0 + 0.2 * (faces - 1)) * (1.3 if out else 1.0)
	_flying = true
	_winding = false
	_velocity = Vector2.ZERO
	_steam.emitting = false
	_aim_arrow.visible = false
	_meter.get_parent().visible = false
	session.play_sound("whoosh", from, -4.0, 1.2 - 0.1 * faces)
	var tween := _steak.create_tween()
	tween.tween_method(func(t: float):
		var s := t + hang * sin(TAU * t) / TAU  # Slow at the top.
		_steak.position = from.lerp(land, s) + Vector3(0.0, sin(s * PI) * height, 0.0)
		var turn := Quaternion(axis, spin * s) * start_turn
		if rim:
			turn = Quaternion(extra_axis, PI * 0.5 * clampf(s * 2.0 - 1.0, 0.0, 1.0)) * turn
		_steak.quaternion = turn, 0.0, 1.0, seconds)
	tween.tween_callback(func():
		var turn := Quaternion(axis, spin) * start_turn
		if rim:
			turn = Quaternion(extra_axis, PI * 0.5) * turn
		_steak.quaternion = _snapped(turn.normalized())
		_steak.position = land
		_flying = false
		_flip_told = _doneness[_down_side()] >= perfect_from
		session.wobble(_steak, 0.18)
		session.play_sound("plop", land)
		session.burst(land, seared_color, 10, 0.3)
		_rumble(0.4 if out else 0.25, 0.18)
		if out:
			_on_counter = true
			_drops += 1
			_steam.emitting = false
			session.pop_text("Oops!", land + Vector3(0.0, steak_size, 0.0), -1)
			return
		_offset = Vector2(land.x, land.z)
		var cooked: float = _doneness[leaving]
		if rim:
			session.pop_text("Rim!", land + Vector3(0.0, steak_size * 1.6, 0.0), 0)
		else:
			_clean += 1
			_sizzle_burst()
		session.pop_text(_verdict(cooked), land, CookSession.mood_of(score(cooked))))


# From the counter back into the middle of the pan, same face down.
func _put_back() -> void:
	_on_counter = false
	_flying = true
	var from := _steak.position
	var land := Vector3(0.0, pan_floor + steak_size * 0.5, 0.0)
	var tween := _steak.create_tween()
	tween.tween_method(func(t: float):
		_steak.position = from.lerp(land, t) + Vector3(0.0, sin(t * PI) * 0.08, 0.0), 0.0, 1.0, 0.35)
	tween.tween_callback(func():
		_flying = false
		_offset = Vector2.ZERO
		_still = 0.0
		session.play_sound("plop", land, -4.0))


func _sizzle_burst() -> void:
	session.play_sound("sizzle", _steak.position, -2.0, 1.15)
	_steam.emitting = true
	_steam.restart()


func _rumble(strength: float, seconds: float) -> void:
	if session.player == null:
		return
	var pad := InputSetup.pad_of(session.player.player_index)
	if pad >= 0:
		Input.start_joy_vibration(pad, strength * 0.6, strength, seconds)


# Off the pan and onto the plate, and that's the dish.
func _serve() -> void:
	_flying = true
	_steam.emitting = false
	_aim_arrow.visible = false
	_meter.get_parent().visible = false
	var plate := session.surface(target)
	plate.slide_in()
	session.play_sound("whoosh", _steak.position, -4.0)
	var start := _steak.position
	var land := plate.position + Vector3(0.0, plate.thickness * 0.5 + steak_size * 0.5, 0.0)
	var tween := _steak.create_tween()
	tween.tween_method(func(t: float):
		var s := t + hang * 0.6 * sin(TAU * t) / TAU
		_steak.position = start.lerp(land, s) + Vector3(0.0, sin(s * PI) * 0.2, 0.0), 0.0, 1.0, plate_seconds)
	tween.tween_callback(func():
		_steak.position = land
		session.wobble(_steak, 0.15)
		session.play_sound("plop", land)
		_rumble(0.3, 0.2)
		_sizzle.stop()
		var scores := []
		for side in 6:
			scores.append(score(_doneness[side]))
		var bonus := clean_bonus * (float(_clean) / _tosses if _tosses > 0 else 1.0)
		if not _ever_smoked:
			bonus += no_smoke_bonus
			session.pop_text("No smoke!", land + Vector3(0.0, 0.1, 0.0), 1)
		finish(average(scores) + bonus - drop_cost * _drops))


# While winding up: the meter beside the pan (yellow one face, orange two, red
# out of the pan) and an arrow the way it'll go.
func _show_aim() -> void:
	_meter.get_parent().visible = _winding
	_aim_arrow.visible = false
	_show_guides()
	if not _winding:
		return
	session.set_meter(_meter, _power)
	_meter_paint.albedo_color = Color(1.0, 0.3, 0.2) if _power >= out_from else (Color(1.0, 0.55, 0.2) if _power >= two_faces_from else Color(1.0, 0.85, 0.3))
	if _aim_arrow.visible:
		var way := Vector2(signf(_aim.x), 0.0) if absf(_aim.x) > absf(_aim.y) else Vector2(0.0, signf(_aim.y))
		_aim_arrow.position = _steak.position + Vector3(way.x, 0.0, way.y) * steak_size * 1.1 + Vector3(0.0, -steak_size * 0.4, 0.0)
		_aim_arrow.rotation.y = -way.angle()


# The four arrows round the cube, once the face down is seared: green if a toss that way lands a face still
# to cook, grey if it's done. Winding up past the two-face mark, every way
# lands the top, so they all go by the top. The way being aimed is bigger.
func _show_guides() -> void:
	var aimed := _snapped_way(_aim) if _winding else Vector2.ZERO
	var strong := _winding and _power >= two_faces_from
	# Only when it wants turning: the face down is seared (or a toss is being wound up).
	var needed: bool = _winding or _doneness[_down_side()] >= perfect_from
	for i in 4:
		var guide := _guides[i]
		var way: Vector2 = WAYS[i]
		guide.visible = needed
		if not needed:
			continue
		var lands := _up_side() if strong else _side_facing(way)
		var paint := _done_paint if _doneness[lands] >= perfect_from else _go_paint
		for part in guide.get_children():
			(part as MeshInstance3D).material_override = paint
		var big := way == aimed
		var bob := 0.006 * (1.0 + sin(Time.get_ticks_msec() * 0.012)) if big else 0.0
		guide.scale = Vector3.ONE * (1.6 if big else 1.0)
		guide.position = _steak.position + Vector3(way.x, 0.0, way.y) * (steak_size * 0.95 + bob) + Vector3(0.0, -steak_size * 0.4, 0.0)
		guide.rotation.y = -way.angle()


static func _snapped_way(way: Vector2) -> Vector2:
	if way.length() < 0.2:
		return Vector2.ZERO
	return Vector2(signf(way.x), 0.0) if absf(way.x) > absf(way.y) else Vector2(0.0, signf(way.y))


func _place_steak() -> void:
	_steak.position = Vector3(_offset.x, pan_floor + steak_size * 0.5, _offset.y)


# Faces seared just right or more.
func _seared_count() -> int:
	return _doneness.filter(func(amount: float): return amount >= perfect_from).size()


# Every face seared (or past it): it can go on the plate.
func _all_cooked() -> bool:
	return _doneness.all(func(amount: float): return amount >= perfect_from)


# Which side faces down now (0-5, as NORMALS).
func _down_side() -> int:
	return _side_along(Vector3.DOWN, _steak.quaternion)


func _up_side() -> int:
	return _side_along(Vector3.UP, _steak.quaternion)


# Which side faces `way` (x, z on the surface): the one a light toss that way lands.
func _side_facing(way: Vector2) -> int:
	return _side_along(Vector3(way.x, 0.0, way.y), _steak.quaternion)


static func _side_along(direction: Vector3, turn: Quaternion) -> int:
	var best := 0
	var most := -INF
	for i in 6:
		var along: float = (turn * NORMALS[i]).dot(direction)
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


func _color_of(side: int) -> Color:
	var amount: float = _doneness[side]
	if amount <= 1.0:
		return raw_color.lerp(seared_color, clampf(amount, 0.0, 1.0))
	return seared_color.lerp(burnt_color, clampf((amount - 1.0) / (burnt_at - 1.0), 0.0, 1.0))


func _paint(side: int) -> void:
	_faces[side] = Color(_color_of(side), _doneness[side])
	var sides := PackedColorArray(_faces)
	_look.set_shader_parameter("sides", sides)


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


# --- The map: the cube unfolded round the face down ------------------------------

func _build_map() -> void:
	var screen := session.overlay()
	if screen == null:
		return
	var split := InputSetup.active_players().size() > 1
	var tile := roundi(TILE * (0.75 if split else 1.0))
	var gap := 3
	_map = Control.new()
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(_map)
	_map.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	var width := tile * 4 + gap * 3
	var height := tile * 3 + gap * 2
	var margin := 24
	_map.offset_left = -width - margin
	_map.offset_right = -margin
	_map.offset_top = -height - margin - 30
	_map.offset_bottom = -margin - 30
	# Screen up is away from the cook (-z): a toss that way lands the far face.
	var cells := {"3": Vector2i(1, 0), "1": Vector2i(0, 1), "down": Vector2i(1, 1), "0": Vector2i(2, 1), "top": Vector2i(3, 1), "2": Vector2i(1, 2)}
	for key: String in cells:
		var square := Panel.new()
		square.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var at: Vector2i = cells[key]
		square.position = Vector2(at.x * (tile + gap), at.y * (tile + gap))
		square.size = Vector2(tile, tile)
		_map.add_child(square)
		if key == "top":
			var label := Label.new()
			label.text = "top"
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", roundi(tile * 0.55))
			label.position = Vector2(at.x * (tile + gap), at.y * (tile + gap) + tile)
			UiStyle.title(label)
			_map.add_child(label)
		_tiles[key] = square
	_show_map()


func _show_map() -> void:
	if _map == null:
		return
	for key: String in _tiles:
		var side := _down_side() if key == "down" else (_up_side() if key == "top" else _side_facing(WAYS[int(key)]))
		var style := StyleBoxFlat.new()
		style.bg_color = _color_of(side)
		style.set_corner_radius_all(5)
		var down := key == "down"
		style.set_border_width_all(4 if down else 2)
		style.border_color = (Color(1.0, 0.45, 0.25) if _stuck else Color(1.0, 0.85, 0.3)) if down else Color(1.0, 0.97, 0.9, 0.9)
		if key == _landing_tile():  # Where the wind-up being held would land.
			style.set_border_width_all(5)
			style.border_color = Color(0.45, 0.95, 0.4)
			style.shadow_color = Color(0.45, 0.95, 0.4, 0.6)
			style.shadow_size = 6
		(_tiles[key] as Panel).add_theme_stylebox_override("panel", style)


# The map square a toss now would land ("" when not winding up or not aimed).
func _landing_tile() -> String:
	if not _winding or _power >= out_from:
		return ""
	if _power >= two_faces_from:
		return "top"
	var aimed := _snapped_way(_aim)
	return "" if aimed == Vector2.ZERO else str(WAYS.find(aimed))


# --- For a reel ---------------------------------------------------------------------

# Slides back toward the middle and keeps it moving while a face cooks; once
# it's seared, winds up and tosses onto a face still to cook (a light toss to
# a side, a strong one for the top), then serves toward the plate.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if _flying:
		return false
	if _on_counter:
		_scripted_wait += delta
		if _scripted_wait > 0.4:
			_scripted_wait = 0.0
			return true
		return false
	if _winding:
		input.stick = _scripted_aim
		return _power < _scripted_goal  # Let go (pushing the aim) at the goal.
	var down: float = _doneness[_down_side()]
	if down < 1.0:  # Cooking: drift toward the middle, a little circle so it never sticks.
		var t := Time.get_ticks_msec() * 0.002
		input.stick = (-_offset * 8.0).limit_length(0.6) + Vector2(cos(t), sin(t)) * 0.35
		return false
	if _offset.length() > _room() * 0.4:
		input.stick = (-_offset * 10.0).limit_length(1.0)
		return false
	if _all_cooked():
		_scripted_aim = Vector2.LEFT
		_scripted_goal = 0.25
		return true
	_scripted_aim = Vector2.ZERO
	for way: Vector2 in WAYS:
		if _doneness[_side_facing(way)] < perfect_from:
			_scripted_aim = way
			_scripted_goal = 0.25
			break
	if _scripted_aim == Vector2.ZERO:
		_scripted_aim = Vector2.RIGHT
		_scripted_goal = 0.6 if _doneness[_up_side()] < perfect_from else 0.25
	return true


# --- Building ---------------------------------------------------------------

func _build_burner() -> void:
	_burner = KitchenProps.gas_ring()
	session.add_child(_burner)


func _build_pan() -> void:
	session.add_child(_pan)
	_pan.position = Vector3(0.0, pan_floor, 0.0)
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
	_pan.add_child(body)


# A soft-edged cube of it, each side browning on its own (steak.gdshader).
func _build_steak() -> void:
	session.add_child(_steak)
	for i in 6:
		_faces.append(Color(raw_color, 0.0))
	_look.shader = preload("res://assets/shaders/steak.gdshader")
	_look.set_shader_parameter("sear_size", steak_size)
	_look.set_shader_parameter("sides", PackedColorArray(_faces))
	var meat := MeshInstance3D.new()
	meat.mesh = PlaceAction.rounded_block(Vector3.ONE * steak_size, steak_size * 0.13)
	meat.material_override = _look
	_steak.add_child(meat)
	_fat = session.make_sizzle()
	_fat.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fat.emission_box_extents = Vector3(steak_size * 0.56, 0.001, steak_size * 0.56)
	session.add_child(_fat)


# A basis that turns a quad (facing +z) to face `normal`.
static func _facing(normal: Vector3) -> Basis:
	if normal.is_equal_approx(Vector3.BACK):
		return Basis.IDENTITY
	if normal.is_equal_approx(Vector3.FORWARD):
		return Basis(Vector3.UP, PI)
	var axis := Vector3.BACK.cross(normal).normalized()
	return Basis(axis, Vector3.BACK.angle_to(normal))
