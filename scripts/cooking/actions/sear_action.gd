# SearAction: a cube of steak in a frying pan over a burner (Squared Steak).
# The pan stays on the burner. Tilt it (the stick, the arrow keys/WASD, or a
# swipe of the mouse) and the cube rolls one face that way, onto the next spot
# in the pan: the side that faced that way lands face down. Only the face down
# cooks: raw, then seared (steam), then burnt (smoke), so the game is planning
# the rolls. The middle of the pan is hottest, the edges cooler, the corners
# coolest, and the pan's wall stops a roll.
# Leave a face down past seared and it sticks: wiggle the pan (tilt it a few
# times) to free it. The button salts the face on top (a bonus once that face
# is seared) and, once every face is cooked, plates the steak.
# The map in the corner is the cube unfolded round the face down: the four
# around it are where each tilt would land, the last one is the top.
# Each face scores how close it got to seared, plus a little for salted faces
# that came out well and for finishing quickly.
class_name SearAction
extends CookAction

@export var target := "Plate"
@export_group("Pan")
@export var pan_model := "res://design/restaurant/frying_pan.glb"
@export var pan_length := 0.62           # The pan, handle and all, fitted to this long...
@export var pan_height := 0.07           # ...and this tall (the model's a deep skillet: shallower shows the steak).
@export var pan_floor := 0.024           # The pan's floor, over the counter.
@export_group("Steak")
@export var steak_size := 0.08
@export var cell := 0.08                 # One roll moves the cube this far: a 3 by 3 of spots in the pan.
@export var raw_color := Color(0.74, 0.32, 0.34)
@export var seared_color := Color(0.36, 0.18, 0.09)
@export var burnt_color := Color(0.13, 0.09, 0.07)
@export var side_seconds := 3.2          # Seconds for a face to be just right, in the middle of the pan.
@export var edge_heat := 0.75            # How fast a face cooks on a spot by the wall...
@export var corner_heat := 0.55          # ...and in a corner, against the middle.
@export var roll_seconds := 0.28
@export var wiggles_to_free := 3         # Tilts it takes to free a stuck face.
@export var plate_seconds := 0.6
@export_group("Scoring")
@export var raw_at := 0.45
@export var perfect_from := 0.9
@export var perfect_to := 1.25
@export var burnt_at := 1.8
@export var salt_bonus := 0.03           # Added for each salted face that came out seared.
@export var speed_bonus := 0.06          # At most, for plating quickly.

const NORMALS := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
const WAYS := [Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)]
const BURNER_TOP := 0.012               # The pan sits on the burner's grate.
const PAN_WIDTH := 0.663                # The pan model's width over its length.
const TILE := 30                        # The map's squares, in pixels (smaller in split screen).
const STUCK_GLOW := Color(1.0, 0.55, 0.3)

var _pan := Node3D.new()                 # Its middle at the pan's middle, on the floor of the pan.
var _burner: Node3D
var _steak := Node3D.new()
var _faces: Array[StandardMaterial3D] = []
var _face_nodes: Array[MeshInstance3D] = []
var _doneness := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _salted := [false, false, false, false, false, false]
var _spot := Vector2i.ZERO               # Which spot in the pan it's on (-1..1 each way).
var _rolling := false                    # Mid-roll (or on its way to the plate).
var _stuck := false
var _stuck_shown := false                # This landing already stuck once.
var _wiggles := 0
var _flip_told := false                  # "Roll it!" shown for the face down now.
var _time := 0.0
var _arrows: Array[Node3D] = []
var _go_paint: StandardMaterial3D        # Arrow paints: a roll that lands a raw face...
var _done_paint: StandardMaterial3D      # ...or one already cooked.
var _steam: CPUParticles3D
var _sizzle: AudioStreamPlayer3D
var _smoking := false
var _map: Control
var _tiles := {}                         # Map square name ("down", "top", or a way's index) -> Panel.
var _scripted_pressed := false


func view_point() -> Vector3:
	return Vector3(0.0, pan_floor, 0.1)


func uses_cursor() -> bool:
	return false  # The cube shows where it is.


func _begin() -> void:
	_build_burner()
	_build_pan()
	_build_steak()
	for i in 4:
		var arrow := session.make_arrow(0.045)
		arrow.visible = false
		_arrows.append(arrow)
	var paint: StandardMaterial3D = ((_arrows[0].get_child(0) as MeshInstance3D).mesh as PrimitiveMesh).material
	_go_paint = paint.duplicate()
	_go_paint.albedo_color = Color(0.55, 0.95, 0.45, 0.95)
	_done_paint = paint.duplicate()
	_done_paint.albedo_color = Color(0.7, 0.7, 0.7, 0.6)
	_steam = session.make_steam(steak_size * 0.6)
	_steak.add_child(_steam)
	_sizzle = session.loop_sound("sizzle", -6.0)
	_sizzle.play()
	_build_map()
	_place_steak()


func end() -> void:
	_sizzle.stop()
	_steam.emitting = false
	for arrow in _arrows:
		arrow.queue_free()
	_burner.queue_free()
	_pan.queue_free()
	if is_instance_valid(_map):
		_map.queue_free()


func update(delta: float, input: CookInput) -> void:
	if _rolling:
		_show_arrows()
		return
	_time += delta
	_cook(delta)
	if input.flick != Vector2.ZERO:
		var way := Vector2(signf(input.flick.x), 0.0) if absf(input.flick.x) > absf(input.flick.y) else Vector2(0.0, signf(input.flick.y))
		if _stuck:
			_wiggle(way)
		else:
			_roll(way)
	elif input.just_pressed:
		if _all_cooked():
			_serve()
		else:
			_salt()
	_show_arrows()
	_show_map()
	if not _rolling:
		if _stuck:
			session.set_status("Stuck! Wiggle the pan to free it (%d / %d)" % [_wiggles, wiggles_to_free])
		elif _all_cooked():
			session.set_status("All sides cooked! Press to plate it")
		else:
			session.set_status("Sides seared: %d / 6" % _seared_count())


# The face down cooks, fastest in the middle of the pan; past seared it sticks.
func _cook(delta: float) -> void:
	var down := _down_side()
	var was: float = _doneness[down]
	_doneness[down] += delta * _heat(_spot) / side_seconds * GameState.difficulty_value("closeup_pace")
	_paint(down)
	var amount: float = _doneness[down]
	var above := _steak.position + Vector3(0.0, steak_size, 0.0)
	if was < perfect_from and amount >= perfect_from and not _flip_told:
		_flip_told = true
		session.pop_text("Plate it!" if _all_cooked() else "Roll it!", above, 1)
		session.play_sound("tick", _steak.position, -2.0, 1.4)
	if amount > perfect_to and not _stuck_shown:
		_stuck_shown = true
		_stuck = true
		_wiggles = 0
		session.pop_text("Stuck!", above, -1)
		session.wobble(_steak, 0.1)
	_steam.emitting = amount > 0.2
	if amount > 1.4:
		if not _smoking:
			_smoking = true
			session.react("dish_burning")
		_steam.color = Color(0.2, 0.18, 0.16)
	else:
		_smoking = false
		_steam.color = Color.WHITE
	_sizzle.volume_db = -10.0 + 6.0 * _heat(_spot)


func _heat(spot: Vector2i) -> float:
	var off := absi(spot.x) + absi(spot.y)
	return 1.0 if off == 0 else (edge_heat if off == 1 else corner_heat)


# Over it goes, one face toward `way`, onto the next spot; the wall stops it.
func _roll(way: Vector2) -> void:
	var next := _spot + Vector2i(roundi(way.x), roundi(way.y))
	_tilt_pan(way)
	if absi(next.x) > 1 or absi(next.y) > 1:
		session.play_sound("tick", _steak.position, -6.0, 0.7)
		session.wobble(_steak, 0.08)
		return
	var leaving := _down_side()
	_rolling = true
	_steam.emitting = false
	session.play_sound("whoosh", _steak.position, -8.0, 1.3)
	var axis := Vector3(way.y, 0.0, -way.x)  # Rolls over toward `way`.
	var start := _steak.quaternion
	var turned := (Quaternion(axis, PI * 0.5) * start).normalized()
	var from := _spot_position(_spot)
	var to := _spot_position(next)
	var rise := steak_size * 0.5 * (sqrt(2.0) - 1.0)  # Its middle rises as it tips over its edge.
	_spot = next
	var tween := _steak.create_tween()
	tween.tween_method(func(t: float):
		_steak.position = from.lerp(to, t) + Vector3(0.0, sin(t * PI) * rise, 0.0)
		_steak.quaternion = start.slerp(turned, t), 0.0, 1.0, roll_seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		_steak.quaternion = _snapped(turned)
		_rolling = false
		var now: float = _doneness[_down_side()]
		_flip_told = now >= perfect_from
		_stuck_shown = now > perfect_to  # Already past seared: it won't stick again.
		_place_steak()
		session.play_sound("plop", _steak.position, -4.0)
		session.burst(_steak.position, seared_color, 5, 0.18)
		var cooked: float = _doneness[leaving]
		session.pop_text(_verdict(cooked), _steak.position, CookSession.mood_of(score(cooked))))


# Stuck: each tilt shakes the pan; enough of them and it comes free.
func _wiggle(way: Vector2) -> void:
	_tilt_pan(way)
	_wiggles += 1
	session.wobble(_steak, 0.06)
	session.play_sound("tick", _steak.position, -8.0, 1.0 + _wiggles * 0.1)
	if _wiggles >= wiggles_to_free:
		_stuck = false
		session.pop_text("Free!", _steak.position + Vector3(0.0, steak_size, 0.0), 1)


func _tilt_pan(way: Vector2) -> void:
	var tween := _pan.create_tween()
	tween.tween_property(_pan, "rotation", Vector3(way.y * 0.12, 0.0, -way.x * 0.12), 0.08)
	tween.tween_property(_pan, "rotation", Vector3.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# A shake of salt on the face on top, if it isn't salted or cooked yet.
func _salt() -> void:
	var top := _up_side()
	var above := _steak.position + Vector3(0.0, steak_size, 0.0)
	if _salted[top] or _doneness[top] >= raw_at:
		session.pop_text("Already salted" if _salted[top] else "Too late to salt", above, 0)
		return
	_salted[top] = true
	var shaker := KitchenProps.shaker(Color.WHITE, KitchenProps.CREAM)
	shaker.position = _steak.position + Vector3(0.03, steak_size * 1.4, 0.0)
	shaker.rotation.z = 2.6
	session.add_child(shaker)
	var shake := shaker.create_tween()
	for i in 3:
		shake.tween_property(shaker, "position:y", shaker.position.y + 0.02, 0.06)
		shake.tween_property(shaker, "position:y", shaker.position.y, 0.06)
	shake.tween_callback(shaker.queue_free)
	_add_salt(top)
	session.play_sound("tick", _steak.position, -10.0, 1.8)
	session.pop_text("Salted!", above, 1)


# White flecks on a face (they turn and brown with it).
func _add_salt(side: int) -> void:
	var fleck := StandardMaterial3D.new()
	fleck.albedo_color = Color(0.97, 0.96, 0.92)
	for i in 9:
		var dot := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.006, 0.006, 0.002)
		mesh.material = fleck
		dot.mesh = mesh
		dot.position = Vector3(randf_range(-0.36, 0.36) * steak_size, randf_range(-0.36, 0.36) * steak_size, 0.001)
		_face_nodes[side].add_child(dot)


# Off the pan and onto the plate, and that's the dish.
func _serve() -> void:
	_rolling = true
	_steam.emitting = false
	var plate := session.surface(target)
	plate.slide_in()
	session.play_sound("whoosh", _steak.position, -4.0)
	var start := _steak.position
	var land := plate.position + Vector3(0.0, plate.thickness * 0.5 + steak_size * 0.5, 0.0)
	var tween := _steak.create_tween()
	tween.tween_method(func(t: float):
		_steak.position = start.lerp(land, t) + Vector3(0.0, sin(t * PI) * 0.2, 0.0), 0.0, 1.0, plate_seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		_steak.position = land
		session.wobble(_steak, 0.15)
		session.play_sound("plop", land)
		_sizzle.stop()
		var scores := []
		var bonus := 0.0
		for side in 6:
			var side_score := score(_doneness[side])
			scores.append(side_score)
			if _salted[side] and side_score >= 0.9:
				bonus += salt_bonus
		var par := 6.0 * side_seconds / GameState.difficulty_value("closeup_pace") + 6.0
		var quick := clampf((par * 1.5 - _time) / (par * 0.5), 0.0, 1.0) * speed_bonus
		if quick > 0.01:
			session.pop_text("Quick!", land + Vector3(0.0, 0.1, 0.0), 1)
		finish(average(scores) + bonus + quick))


# The four arrows round the cube, one per way to roll: green if it lands a face
# still to cook, grey if that face is done; none toward the wall, or when stuck.
func _show_arrows() -> void:
	for i in 4:
		var arrow := _arrows[i]
		var way: Vector2 = WAYS[i]
		var next := _spot + Vector2i(roundi(way.x), roundi(way.y))
		arrow.visible = not _rolling and not _stuck and absi(next.x) <= 1 and absi(next.y) <= 1
		if not arrow.visible:
			continue
		var paint := _done_paint if _doneness[_side_facing(way)] >= raw_at else _go_paint
		for part in arrow.get_children():
			(part as MeshInstance3D).material_override = paint
		var bob := 0.005 * (1.0 + sin(Time.get_ticks_msec() * 0.01))
		arrow.position = _steak.position + Vector3(way.x, 0.0, way.y) * (steak_size * 0.95 + bob) + Vector3(0.0, -steak_size * 0.4, 0.0)
		arrow.rotation.y = -way.angle()


func _place_steak() -> void:
	_steak.position = _spot_position(_spot)


func _spot_position(spot: Vector2i) -> Vector3:
	return Vector3(spot.x * cell, pan_floor + steak_size * 0.5, spot.y * cell)


# Faces seared just right or more.
func _seared_count() -> int:
	return _doneness.filter(func(amount: float): return amount >= perfect_from).size()


# Every face cooked at least a little: it can go on the plate.
func _all_cooked() -> bool:
	return _doneness.all(func(amount: float): return amount >= raw_at)


# Which side faces down now (0-5, as NORMALS).
func _down_side() -> int:
	return _side_along(Vector3.DOWN, _steak.quaternion)


func _up_side() -> int:
	return _side_along(Vector3.UP, _steak.quaternion)


# Which side faces `way` (x, z on the surface): the one a roll that way lands.
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
	_faces[side].albedo_color = _color_of(side)


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
	# Screen up is away from the cook (-z): the tilt that way lands the far face.
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
			label.add_theme_font_size_override("font_size", roundi(tile * 0.4))
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
		style.border_color = (STUCK_GLOW if _stuck else Color(1.0, 0.85, 0.3)) if down else Color(1.0, 0.97, 0.9, 0.9)
		if _salted[side]:
			style.shadow_color = Color(1.0, 1.0, 1.0, 0.8)
			style.shadow_size = 3
		(_tiles[key] as Panel).add_theme_stylebox_override("panel", style)


# --- For a reel ---------------------------------------------------------------------

# Salts a raw face on top now and then, rolls the shortest way to a face still
# to cook once the face down is seared, wiggles free when stuck, then plates it.
func scripted_hold(_delta: float, input: CookInput) -> bool:
	if _rolling or _scripted_pressed:  # Let go between presses.
		_scripted_pressed = false
		return false
	if _stuck:
		input.flick = Vector2(1.0 if _wiggles % 2 == 0 else -1.0, 0.0)
		return false
	if _all_cooked() and _doneness[_down_side()] >= 1.0:
		_scripted_pressed = true
		return true
	var top := _up_side()
	if not _salted[top] and _doneness[top] < raw_at and _salted.count(true) < 2:
		_scripted_pressed = true
		return true
	if _doneness[_down_side()] < 1.0:
		return false
	var way := _first_roll_to_raw()
	if way != Vector2.ZERO:
		input.flick = way
	return false


# Breadth-first over (turn, spot): the first roll of the shortest way to land a
# face still to cook (zero if there's none).
func _first_roll_to_raw() -> Vector2:
	var queue := [[_steak.quaternion, _spot, Vector2.ZERO]]
	var seen := {}
	while not queue.is_empty():
		var entry: Array = queue.pop_front()
		var turn: Quaternion = entry[0]
		var spot: Vector2i = entry[1]
		for way: Vector2 in WAYS:
			var next := spot + Vector2i(roundi(way.x), roundi(way.y))
			if absi(next.x) > 1 or absi(next.y) > 1:
				continue
			var turned := _snapped(Quaternion(Vector3(way.y, 0.0, -way.x), PI * 0.5) * turn)
			var first: Vector2 = way if entry[2] == Vector2.ZERO else entry[2]
			if _doneness[_side_along(Vector3.DOWN, turned)] < raw_at:
				return first
			var key := "%s|%s" % [Basis(turned), next]
			if not seen.has(key):
				seen[key] = true
				queue.append([turned, next, first])
	return Vector2.ZERO


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
	dish.top_radius = cell * 2.2
	dish.bottom_radius = cell * 2.1
	dish.height = 0.04
	dish.material = steel
	body.mesh = dish
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
		_face_nodes.append(face)
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
