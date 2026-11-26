# SpoonOutAction: serve saucy pasta with a big wooden serving spoon, the way
# LadleAction serves soup: press over the pot for a heaped spoonful, press over
# the bowl and it tumbles in. Every piece in the pot ends up in the bowl, heaped
# up in its sauce, and the pot empties as it goes.
class_name SpoonOutAction
extends LadleAction

const SPOON_REACH := 0.046          # How far from its middle the spoon's heap goes.
const HEAP_HEIGHT := 0.026
const FALL_SECONDS := 0.2
const LEFT_IN_POT := 0.24           # How full the pot ends up: a layer of sauce, deep enough to rock without baring the floor.

var _pot_level := 0.0
var _all := 0                       # Pieces there were to serve.


func _begin() -> void:
	super()
	var pot := session.surface(from_surface)
	_pot_level = pot.level
	_all = _pieces(pot).size()


func _dress(liquid: PotLiquid) -> void:
	liquid.dress({ "clear": 0.0, "foam": 0.0, "thick": 0.5, "glossy": 0.85 })


func _dip_y(pot: CookSurface) -> float:
	return maxf(pot.liquid_top() - 0.012, pot.position.y + 0.022)


# Whatever's still in the pot and hasn't melted away.
func _pieces(pot: CookSurface) -> Array:
	return pot.contents.filter(func(bit): return is_instance_valid(bit) and bit is Node3D and bit.visible and bit.scale.x > 0.3)


# A heap of it comes up on the spoon, and the sauce goes down in the pot. The
# last spoonful takes all that's left.
func _take_bits(pot: CookSurface) -> void:
	var here := _pieces(pot)
	var at := Vector2(_ladle.position.x - pot.position.x, _ladle.position.z - pot.position.z)
	here.sort_custom(func(a, b): return _away(a, pot, at) < _away(b, pot, at))  # The nearest first.
	var count := here.size()
	if _poured < ladles - 1:
		count = mini(roundi(float(_all) / ladles), count)
	for i in count:
		var bit: Node3D = here[i]
		pot.contents.erase(bit)
		if pot.in_it() != null:
			pot.in_it().sink_thing(bit)
		bit.reparent(_ladle)
		_bits.append(bit)
		# Round and round from the middle, the middle ones highest.
		var out := sqrt((i + 0.5) / count)
		var spot := Vector2.from_angle(i * 2.4) * out * SPOON_REACH * 0.85
		var rest := Vector3(spot.x, 0.008 + (1.0 - out * out) * HEAP_HEIGHT + randf() * 0.004, spot.y)
		var up := bit.create_tween()
		up.tween_property(bit, "position", rest, 0.14).set_trans(Tween.TRANS_QUAD)
		up.parallel().tween_property(bit, "rotation", Vector3(randf_range(-0.6, 0.6), randf() * TAU, randf_range(-0.6, 0.6)), 0.14)
	var to := lerpf(_pot_level, LEFT_IN_POT, float(_poured + 1) / ladles)
	_ladle.create_tween().tween_method(func(level: float): pot.fill_to(level), pot.level, to, 0.3)


func _away(bit: Node3D, pot: CookSurface, at: Vector2) -> float:
	var local := bit.global_position - pot.global_position
	return Vector2(local.x, local.z).distance_to(at)


# Off the spoon it tumbles, and heaps up in the bowl.
func _drop_bits(bowl: CookSurface) -> void:
	var level := _level_after()
	var reach := lerpf(bowl.floor_radius, bowl.rim_radius, sqrt(level)) * 0.78
	var count := _bits.size()
	for i in count:
		var bit := _bits[i]
		bit.reparent(session)
		var out := sqrt((i + 0.5) / count)
		var spot := Vector2.from_angle(i * 2.4 + _poured * 0.8) * out * reach
		# Each spoonful heaps on the last, over a thin layer of sauce: cheesy, not soupy.
		var dome := (1.0 - out * out) * (0.012 + 0.012 * _poured)
		var at := Vector3(bowl.position.x + spot.x, bowl.top_when(level) + 0.003 + _poured * 0.005 + dome + randf_range(0.0, 0.009), bowl.position.z + spot.y)
		var fall := bit.create_tween()
		fall.tween_interval(0.012 * (count - i))
		fall.tween_property(bit, "position", at, FALL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.parallel().tween_property(bit, "rotation", Vector3(randf_range(-0.5, 0.5), randf() * TAU, randf_range(-0.5, 0.5)), FALL_SECONDS)
		fall.tween_callback(func():
			bowl.contents.append(bit)
			bowl.splash(at, 0.003)
			if i % 6 == 0:
				session.play_sound("plop", at, -9.0, randf_range(0.85, 1.1)))
		# It gives a little as it lands.
		fall.tween_property(bit, "position:y", at.y - 0.004, 0.06)
		fall.tween_property(bit, "position:y", at.y, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bits.clear()


# A deep wooden serving spoon, its origin in the hollow, the handle up and back.
func _make_ladle(sauce_color: Color) -> Node3D:
	var spoon := Node3D.new()
	var wood := KitchenProps.handle_wood()
	var bowl := MeshInstance3D.new()
	bowl.mesh = _hollow()
	bowl.material_override = wood
	spoon.add_child(bowl)
	_soup = MeshInstance3D.new()
	var sauce_mesh := SphereMesh.new()
	sauce_mesh.radius = SPOON_REACH * 0.96
	sauce_mesh.height = 0.02
	var sauce := StandardMaterial3D.new()
	sauce.albedo_color = sauce_color
	sauce.roughness = 0.25
	sauce_mesh.material = sauce
	_soup.mesh = sauce_mesh
	_soup.visible = false
	spoon.add_child(_soup)
	var handle := MeshInstance3D.new()
	var handle_mesh := CapsuleMesh.new()
	handle_mesh.radius = 0.0085
	handle_mesh.height = 0.24
	handle_mesh.material = wood
	handle.mesh = handle_mesh
	handle.rotation.x = deg_to_rad(58.0)
	handle.position = Vector3(0.0, 0.062, 0.14)
	spoon.add_child(handle)
	session.add_child(spoon)
	return spoon


# The spoon's bowl: round, dished, with a thick rim.
static func _hollow() -> ArrayMesh:
	const ROUND := 40
	var profile := [Vector2(0.0, -0.014), Vector2(0.025, -0.012), Vector2(0.04, -0.005), Vector2(0.047, 0.005), Vector2(0.0495, 0.0075), Vector2(0.052, 0.006), Vector2(0.05, -0.004), Vector2(0.042, -0.014), Vector2(0.026, -0.021), Vector2(0.0, -0.023)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring: Vector2 in profile:
		for i in ROUND + 1:
			var turn := TAU * i / ROUND
			tool.add_vertex(Vector3(cos(turn) * ring.x, ring.y, sin(turn) * ring.x))
	for ring in profile.size() - 1:
		for i in ROUND:
			var a := ring * (ROUND + 1) + i
			var b := a + ROUND + 1
			for index in [a, b, a + 1, a + 1, b, b + 1]:
				tool.add_index(index)
	tool.generate_normals()
	return tool.commit()
