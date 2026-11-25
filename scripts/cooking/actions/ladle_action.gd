# LadleAction: serve a soup. A ladle follows the cursor: press over the pot to
# scoop it full, then press over the bowl to pour it in, a few times over. Each
# ladleful scores how near the bowl's middle it was poured (the ring shows
# where's perfect); over the rim some of it spills. SpoonOutAction does the same
# with a serving spoon (macaroni).
class_name LadleAction
extends CookAction

@export var from_surface := "Pot"
@export var target := "Bowl"
@export var ladles := 3
@export var perfect_offset := 0.045        # Pouring this near the bowl's middle gets full marks.
@export_range(0.0, 1.0) var least_score := 0.5  # What one half over the rim scores.
@export var full_level := 0.8              # How full the bowl ends up (of its depth).
@export var carry_height := 0.11           # How far over the pot it's carried.
@export var serving := "Ladle"             # What one's called in the status.

var _ladle: Node3D
var _color := Color.WHITE                  # What's being served.
var _soup: MeshInstance3D                  # In the ladle.
var _full := false
var _busy := false
var _poured := 0
var _scores: Array[float] = []
var _ring: MeshInstance3D
var _stream: PourStream
var _pouring := 0.0                        # Seconds of it still to come off the ladle.
var _pour_to: CookSurface = null
var _level_to := 0.0
var _since_ring := 0.0
var _scooped_at := 0                       # Which ladleful's in it.
var _slop := Vector2.ZERO                  # The soup in it, rocking.
var _slop_speed := Vector2.ZERO
var _last_at := Vector3.ZERO
var _last_way := Vector3.ZERO


const BITS := 5               # Pieces of vegetable a ladleful brings along.
var _bits: Array[Node3D] = []

# Between the pot and the bowl.
func view_point() -> Vector3:
	return (session.surface(from_surface).position + session.surface(target).position) * 0.5


func uses_cursor() -> bool:
	return false  # The ladle shows the spot.


func marks_spot() -> bool:
	return true


func cursor_height() -> float:
	return session.surface(from_surface).position.y


func _begin() -> void:
	var pot := session.surface(from_surface)
	var bowl := session.surface(target)
	_color = pot.liquid_color()
	_ladle = _make_ladle(_color)
	_ladle.position = pot.position + Vector3(0.0, 0.12, 0.0)
	_last_at = _ladle.position
	_stream = PourStream.make(session, _color, 0.008, 0.8, 1.0)
	_ring = session.make_ring(perfect_offset, Color(1.0, 1.0, 1.0, 0.9))
	_ring.position = bowl.position + Vector3(0.0, bowl.depth, 0.0)


func end() -> void:
	_ladle.queue_free()
	_stream.finish(_stream.position - Vector3(0.0, 0.08, 0.0))
	_ring.queue_free()


func update(delta: float, input: CookInput) -> void:
	var pot := session.surface(from_surface)
	var bowl := session.surface(target)
	_ring.visible = _full
	_run(delta, pot)
	if not _busy:
		var goal := Vector3(input.cursor.x, pot.position.y + carry_height, input.cursor.z)
		_ladle.position = _ladle.position.lerp(goal, 1.0 - exp(-18.0 * delta))
		if input.just_pressed:
			var at := Vector3(_ladle.position.x, 0.0, _ladle.position.z)
			if not _full:
				if pot.contains(at, 0.02):
					_scoop(pot)
				else:
					session.pop_text("Scoop from the pot", pot.position, 0)
			elif bowl.contains(at, 0.05):
				_pour(bowl, at)
			else:
				session.pop_text("Over the bowl!", bowl.position, 0)
	session.set_status("%s %d of %d: %s" % [serving, mini(_poured + 1, ladles), ladles, "over the bowl" if _full else "scoop from the pot"])


# What's pouring off the ladle's lip, the bowl filling as it lands, and what's
# left in the ladle slopping as it's carried.
func _run(delta: float, pot: CookSurface) -> void:
	_pouring = maxf(_pouring - delta, 0.0)
	var lip := _ladle.to_global(Vector3(-0.034, 0.012, 0.0))
	lip = session.to_local(lip)
	var land := Vector3(lip.x, (_pour_to.liquid_top() if _pour_to != null else lip.y - 0.05), lip.z)
	_stream.flow(lip, land, _pouring > 0.08, delta)
	if _pour_to != null:
		if _stream.landed:
			_pour_to.fill_to(move_toward(_pour_to.level, _level_to, delta * full_level / ladles / 0.3), _color)
			_since_ring += delta
			if _since_ring > 0.07:
				_since_ring = 0.0
				_pour_to.splash(land, 0.005)
				_pour_to.liquid.knock(Vector2.from_angle(randf() * TAU) * 0.03)
				_dress(_pour_to.liquid)
		elif _pouring <= 0.0 and _pour_to.level < _level_to:
			_pour_to.fill_to(_level_to, _color)
	var way := (_ladle.position - _last_at) / maxf(delta, 0.001)
	_last_at = _ladle.position
	_slop_speed += (Vector2(way.x, way.z) * -0.35 - _slop * 160.0 - _slop_speed * 5.0) * delta
	_slop_speed += -Vector2(way.x - _last_way.x, way.z - _last_way.z) * 0.9
	_last_way = way
	_slop = (_slop + _slop_speed * delta).limit_length(0.4)
	_soup.rotation = Vector3(_slop.y, 0.0, -_slop.x)
	_soup.visible = _full and _pouring <= 0.12 and not _emptied() or _soup.visible and _pouring > 0.12
	var left := clampf(_pouring / 0.42, 0.05, 1.0) if _pouring > 0.0 else 1.0
	_soup.scale = Vector3.ONE * left


# How what's in the bowl looks.
func _dress(liquid: PotLiquid) -> void:
	liquid.dress({ "oil": 1.0 })


func _emptied() -> bool:
	return _busy and _pour_to != null and _pouring <= 0.12 and _scooped_at < _poured


# For a reel: scoop and pour till it's full.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if _busy:
		return false
	var goal := session.surface(target if _full else from_surface).position
	var there := input.move_to(goal, delta)
	return there and Vector2(_ladle.position.x - goal.x, _ladle.position.z - goal.z).length() < 0.02 and not input.held


# How low it goes to scoop.
func _dip_y(pot: CookSurface) -> float:
	return pot.position.y - 0.005


func _scoop(pot: CookSurface) -> void:
	_busy = true
	var tween := _ladle.create_tween()
	tween.tween_property(_ladle, "position:y", _dip_y(pot), 0.14).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func():
		_scooped_at = _poured + 1
		_soup.visible = true
		pot.splash(_ladle.position, 0.007)
		if pot.in_it() != null:
			pot.in_it().knock(Vector2(randf_range(-0.04, 0.04), 0.05))
		_take_bits(pot)
		session.play_sound("plop", pot.position, -6.0, 0.9)
		session.burst(Vector3(pot.position.x, pot.liquid_top(), pot.position.z), _color, 4, 0.15))
	tween.tween_property(_ladle, "position:y", pot.position.y + carry_height, 0.16).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func():
		_full = true
		_busy = false)


# Some of what's floating in the pot comes up in the ladle...
func _take_bits(pot: CookSurface) -> void:
	var here: Array = pot.contents.filter(func(bit): return is_instance_valid(bit) and bit is Node3D)
	if here.is_empty():
		return
	here.sort_custom(func(a, b): return _size_of(a) > _size_of(b))  # The chunks first, not just flakes of herb.
	@warning_ignore("integer_division")
	var among := maxi(here.size() / 2, 1)
	for i in mini(BITS, among):
		var bit: Node3D = here[(i * 7 + _poured * 3) % among]
		if bit in _bits:
			continue
		pot.contents.erase(bit)
		if pot.in_it() != null:
			pot.in_it().sink_thing(bit)
		bit.reparent(_ladle)
		bit.position = Vector3(randf_range(-0.016, 0.016), 0.018, randf_range(-0.016, 0.016))
		_bits.append(bit)


static func _size_of(bit: Node3D) -> float:
	if bit is MeshInstance3D and (bit as MeshInstance3D).mesh != null:
		return (bit as MeshInstance3D).get_aabb().size.length()
	return 0.02


# ...and goes into the bowl with the soup, to float there.
func _drop_bits(bowl: CookSurface) -> void:
	for i in _bits.size():
		var bit := _bits[i]
		bit.reparent(session)
		var spot := Vector2.from_angle(randf() * TAU) * bowl.radius() * sqrt(randf()) * 0.5
		var at := Vector3(bowl.position.x + spot.x, maxf(bowl.top_when(_level_after()), bowl.liquid_top()), bowl.position.z + spot.y)
		var fall := bit.create_tween()
		fall.tween_interval(0.06 * i)
		fall.tween_property(bit, "position", at, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.parallel().tween_property(bit, "rotation", Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3)), 0.2)
		fall.tween_callback(func():
			bowl.contents.append(bit)
			bowl.splash(at, 0.004)
			if bowl.in_it() != null:
				bowl.in_it().float_thing(bit, 0.002))
	_bits.clear()


func _level_after() -> float:
	return full_level * (_poured + 1) / ladles


func _pour(bowl: CookSurface, at: Vector3) -> void:
	_busy = true
	var off := Vector2(at.x - bowl.position.x, at.z - bowl.position.z).length()
	var result := 1.0 if off <= perfect_offset else lerpf(1.0, least_score, clampf((off - perfect_offset) / maxf(bowl.radius() + 0.05 - perfect_offset, 0.01), 0.0, 1.0))
	var pot := session.surface(from_surface)
	var tween := _ladle.create_tween()
	tween.tween_property(_ladle, "position", Vector3(at.x, bowl.position.y + bowl.depth + 0.07, at.z), 0.12)
	tween.tween_property(_ladle, "rotation:z", deg_to_rad(70.0), 0.18)
	tween.tween_callback(func():
		_pouring = 0.42
		_pour_to = bowl
		if bowl.level <= 0.0:
			bowl.fill_to(0.0, _color)
		_drop_bits(bowl)
		_poured += 1
		_scores.append(result)
		_level_to = full_level * _poured / ladles
		session.play_sound("pour", at, -10.0, 1.1)
		session.play_sound("plop", at, -4.0, 1.1)
		session.burst(bowl.position + Vector3(0.0, bowl.depth, 0.0), _color, 14 if result < 0.8 else 4, 0.4 if result < 0.8 else 0.15)
		session.pop_text("Lovely!" if result >= 1.0 else ("Nice" if result >= 0.8 else "Spilled a bit: pour in the middle"), bowl.position, CookSession.mood_of(result)))
	tween.tween_interval(0.5)
	tween.tween_property(_ladle, "rotation:z", 0.0, 0.15)
	tween.tween_callback(func():
		_full = false
		_busy = false
		if _poured >= ladles:
			finish(average(_scores)))


# A steel ladle, its origin at the cup, the handle up and back.
func _make_ladle(soup_color: Color) -> Node3D:
	var ladle := Node3D.new()
	var cup := MeshInstance3D.new()
	var cup_mesh := CylinderMesh.new()
	cup_mesh.top_radius = 0.034
	cup_mesh.bottom_radius = 0.02
	cup_mesh.height = 0.03
	cup_mesh.material = KitchenProps.steel(KitchenProps.SAGE_STEEL)
	cup.mesh = cup_mesh
	ladle.add_child(cup)
	_soup = MeshInstance3D.new()
	var soup_mesh := CylinderMesh.new()
	soup_mesh.top_radius = 0.031
	soup_mesh.bottom_radius = 0.031
	soup_mesh.height = 0.004
	var soup := StandardMaterial3D.new()
	soup.albedo_color = soup_color
	soup.roughness = 0.25
	soup_mesh.material = soup
	_soup.mesh = soup_mesh
	_soup.position.y = 0.0155
	_soup.visible = false
	ladle.add_child(_soup)
	var handle := MeshInstance3D.new()
	var handle_mesh := CapsuleMesh.new()
	handle_mesh.radius = 0.008
	handle_mesh.height = 0.2
	handle_mesh.material = KitchenProps.handle_wood()
	handle.mesh = handle_mesh
	handle.rotation.x = deg_to_rad(40.0)
	handle.position = Vector3(0.0, 0.085, 0.085)
	ladle.add_child(handle)
	session.add_child(ladle)
	return ladle
