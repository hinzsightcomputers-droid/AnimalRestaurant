# DrinkModel: a drink to look at, in a clear glass or a glass mug (the drink's
# "vessel"), filled to `fill` (0..1, the line at 0.8). Used in hands, in the
# drink machines, and on the table.
#
# The drink moves like one: wherever the glass goes, its surface tips back as it
# speeds up, rocks, and settles, and a stream landing in it (pour_in) sets it
# rippling. A round glass's liquid really does rock in a few set ways (side to
# side, a saddle, the middle up and down); each is a damped spring here, pushed
# by how the glass itself is speeding up, and drink_liquid.gdshader draws them
# added together. Ice and marshmallows float on that surface: they bob on it,
# slide down it, and bump the glass and each other.
#
# data/drink_kitchen.json says what else is in one: "fizz", "foam" (its color),
# "ice" (cubes), "pearls", "topping" ("marshmallows"), "clear" (see-through).
class_name DrinkModel
extends Node3D

const HEIGHT := 0.16
const RADIUS := 0.05
const FULL := 0.96             # The drink's height at fill 1, as a share of the glass's.
const LIQUID := preload("res://assets/shaders/drink_liquid.gdshader")
const GLASS := preload("res://assets/shaders/drink_glass.gdshader")

const ROCK_HZ := 2.7           # Side to side...
const SADDLE_HZ := 4.0         # ...the saddle...
const HEAVE_HZ := 4.6          # ...and the middle.
const ROCK_DAMPING := 0.075    # How soon each settles (1: no swing at all).
const SADDLE_DAMPING := 0.06
const HEAVE_DAMPING := 0.1
const PUSH := 0.75             # How much of the glass's own speeding up it feels.
const MOST_PUSH := 16.0        # Meters a second a second: a bump is no harder than this.
const CALM := 0.00012          # Below this much movement (m) it's still.
const TELEPORT := 1.5          # A glass that moved this far at once was put there, not carried.
const MARSHMALLOWS := 12
const MARSHMALLOW_SIZE := 0.0145
const ICE_SIZE := 0.026
const FALL := 2.2              # Gravity for what's dropped in (gentle: you can watch it).

var _liquid := MeshInstance3D.new()
var _paint: ShaderMaterial
var _fill := 1.0
var _level := 0.0
var _bottom := 0.0425          # The drink's radius at the bottom and the top of the glass.
var _top := 0.046
var _rock := Vector2.ZERO      # Meters up at the rim, along x and z, and how fast.
var _rock_speed := Vector2.ZERO
var _saddle := Vector2.ZERO
var _saddle_speed := Vector2.ZERO
var _heave := 0.0
var _heave_speed := 0.0
var _ripple := 0.0
var _last := Vector3.INF       # Where it was, and how fast it was going, a tick ago.
var _velocity := Vector3.ZERO
var _floaters: Array[Dictionary] = []  # { node, at (x, z), drift, y, rise (its speed up), size, dropped, kind }
var _still := false

static var _cylinder: ArrayMesh = null


static func make(drink: Dictionary, fill := 0.8, done := true) -> DrinkModel:
	var model := DrinkModel.new()
	model._build(drink)
	model.set_fill(fill)
	if done and fill > 0.0:
		model.add_extras(drink)
		if drink.get("topping", "") == "marshmallows":
			for i in MARSHMALLOWS:
				model.add_marshmallow(false)
	return model


# How wide the rim is, for a ring around it.
static func rim_radius(drink: Dictionary) -> float:
	return RADIUS * (1.08 if drink.get("vessel", "glass") == "mug" else 1.0)


func _build(drink: Dictionary) -> void:
	var mug: bool = drink.get("vessel", "glass") == "mug"
	var outer_top := rim_radius(drink)
	var outer_bottom := RADIUS * (1.0 if mug else 0.84)
	var wall := 0.0035
	_bottom = outer_bottom - wall
	_top = outer_top - wall
	var color := Color(drink.get("color", "#888888"))
	_paint = ShaderMaterial.new()
	_paint.shader = LIQUID
	_paint.set_shader_parameter("drink", color)
	_paint.set_shader_parameter("alpha", 0.62 if drink.get("clear", false) else 1.0)
	_paint.set_shader_parameter("glass_height", HEIGHT)
	_paint.set_shader_parameter("radii", Vector2(_bottom, _top))
	_paint.set_shader_parameter("fizz", 1.0 if drink.get("fizz", false) else 0.0)
	if drink.has("foam"):
		_paint.set_shader_parameter("foam_color", Color(drink["foam"]))
		_paint.set_shader_parameter("foam", 0.009)
	_liquid.mesh = _unit_cylinder()
	_liquid.material_override = _paint
	_liquid.position.y = 0.006
	_liquid.custom_aabb = AABB(Vector3(-0.07, -0.02, -0.07), Vector3(0.14, 0.22, 0.14))
	add_child(_liquid)
	var glass := ShaderMaterial.new()
	glass.shader = GLASS
	glass.set_shader_parameter("glass", Color(1.0, 0.95, 0.86) if mug else Color(0.88, 0.95, 1.0))
	glass.set_shader_parameter("body", 0.035 if mug else 0.02)
	glass.render_priority = 1  # Over the drink inside.
	var vessel := MeshInstance3D.new()
	vessel.mesh = _lathe([
		Vector2(0.0, 0.0), Vector2(outer_bottom * 0.92, 0.0), Vector2(outer_bottom, 0.004), Vector2(lerpf(outer_bottom, outer_top, 0.5), HEIGHT * 0.5),
		Vector2(outer_top, HEIGHT), Vector2(outer_top - wall * 0.4, HEIGHT + 0.002), Vector2(outer_top - wall, HEIGHT),
		Vector2(_bottom, 0.007), Vector2(0.0, 0.006)])
	vessel.material_override = glass
	vessel.sorting_offset = 0.2
	add_child(vessel)
	var rim := MeshInstance3D.new()  # Its lip, to catch the light.
	var lip := TorusMesh.new()
	lip.inner_radius = outer_top - wall
	lip.outer_radius = outer_top + 0.0012
	lip.rings = 32
	lip.ring_segments = 6
	rim.mesh = lip
	rim.material_override = glass
	rim.position.y = HEIGHT
	rim.sorting_offset = 0.25
	add_child(rim)
	if mug:
		var handle := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.026
		torus.outer_radius = 0.04
		torus.rings = 20
		torus.ring_segments = 10
		handle.mesh = torus
		handle.material_override = glass
		handle.rotation_degrees = Vector3(90, 0, 0)
		handle.position = Vector3(outer_top + 0.018, HEIGHT * 0.5, 0.0)
		handle.scale = Vector3(1.0, 1.0, 1.25)
		handle.sorting_offset = 0.2
		add_child(handle)


# What's in it besides the drink: ice cubes, tapioca pearls, steam off a hot one.
func add_extras(drink: Dictionary) -> void:
	for i in int(drink.get("ice", 0)):
		_add_ice()
	for i in int(drink.get("pearls", 0)):
		_add_pearl(i)
	if drink.get("temperature", "") == "hot":
		_add_steam()


# 0 = empty, 0.8 = the line, 1 = the brim (more spills).
func set_fill(fill: float) -> void:
	_fill = clampf(fill, 0.0, 1.0)
	_level = maxf(HEIGHT * FULL * _fill, 0.001)
	_liquid.visible = _fill > 0.01
	_paint.set_shader_parameter("level", _level)
	_still = false


# How high the drink is (in this node's own meters), for a stream to land on.
func level() -> float:
	return _liquid.position.y + _level


# A stream is landing in it: rings, and a bit of a rock.
func pour_in(delta: float) -> void:
	_ripple = move_toward(_ripple, 0.0022, delta * 0.02)
	_heave_speed += randf_range(-1.0, 1.0) * 2.2 * delta
	_rock_speed += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 1.8 * delta
	_still = false


# Set it rocking (put down, or bumped).
func jolt(amount: float) -> void:
	_rock_speed += Vector2.from_angle(randf() * TAU) * amount
	_heave_speed += amount * 0.6
	_still = false


func is_calm() -> bool:
	return _still


func _physics_process(delta: float) -> void:
	if not is_inside_tree() or delta <= 0.0:
		return
	var here := global_position
	var push := Vector3.ZERO
	if _last == Vector3.INF or _last.distance_to(here) > TELEPORT:
		_velocity = Vector3.ZERO
	else:
		var velocity := (here - _last) / delta
		push = ((velocity - _velocity) / delta).limit_length(MOST_PUSH)
		_velocity = velocity
	_last = here
	if _still and push.length() < 0.05 and _floaters.is_empty():
		return
	var local := global_basis.orthonormalized().inverse() * push
	var down := global_basis.orthonormalized().inverse() * Vector3(0.0, -9.8, 0.0)  # A tipped glass: the drink stays level.
	var felt := Vector2(local.x * PUSH - down.x, local.z * PUSH - down.z)
	var w := TAU * ROCK_HZ
	_rock_speed += (-_rock * w * w - _rock_speed * 2.0 * ROCK_DAMPING * w - felt * (_top * w * w / 9.8)) * delta
	_rock += _rock_speed * delta
	w = TAU * SADDLE_HZ
	var squeeze := Vector2(felt.x * felt.x - felt.y * felt.y, 2.0 * felt.x * felt.y) * 0.012
	_saddle_speed += (-_saddle * w * w - _saddle_speed * 2.0 * SADDLE_DAMPING * w + squeeze) * delta
	_saddle += _saddle_speed * delta
	w = TAU * HEAVE_HZ
	_heave_speed += (-_heave * w * w - _heave_speed * 2.0 * HEAVE_DAMPING * w - local.y * 0.06) * delta
	_heave += _heave_speed * delta
	_ripple = move_toward(_ripple, 0.0, delta * 0.004)
	var most := minf(_level, HEIGHT - _level) * 0.85 + 0.002  # Never over the rim, or through the bottom.
	_rock = _rock.limit_length(most)
	_saddle = _saddle.limit_length(most * 0.4)
	_heave = clampf(_heave, -most * 0.5, most * 0.5)
	_still = push.length() < 0.05 and _rock.length() + _saddle.length() + absf(_heave) + _ripple < CALM and _rock_speed.length() < 0.004
	_paint.set_shader_parameter("tilt", _rock)
	_paint.set_shader_parameter("saddle", _saddle)
	_paint.set_shader_parameter("heave", _heave)
	_paint.set_shader_parameter("ripple", _ripple)
	if not _floaters.is_empty():
		_float(delta, felt)


# How far the surface is up from level at (x, z) across the glass (-1..1): the
# same sum as the shader's, without the rings.
func _wave(p: Vector2) -> float:
	var r2 := p.length_squared()
	return _rock.dot(p) * (1.5 - 0.5 * r2) + _saddle.x * (p.x * p.x - p.y * p.y) + _saddle.y * 2.0 * p.x * p.y + _heave * (1.0 - 2.0 * r2)


# --- What floats -----------------------------------------------------------------

func _radius_at(y: float) -> float:
	return lerpf(_bottom, _top, clampf(y / HEIGHT, 0.0, 1.0))


func _float(delta: float, felt: Vector2) -> void:
	var radius := _radius_at(_level)
	for floater in _floaters:
		var at: Vector2 = floater["at"]
		var size: float = floater["size"]
		var p := at / radius
		var top := _level + _wave(p) + float(floater["ride"])
		var y: float = floater["y"]
		var rise: float = floater["rise"]
		if floater["dropped"]:  # Still falling in.
			rise -= FALL * delta
			y += rise * delta
			if y <= top:
				floater["dropped"] = false
				_heave_speed += rise * 0.05
				_ripple = maxf(_ripple, 0.0016)
				_rock_speed += p * rise * 0.04
				_still = false
		else:  # Bobbing: a spring up to the surface, in something thick.
			rise += ((top - y) * 420.0 - rise * 9.0) * delta
			y += rise * delta
		y = maxf(y, size * 0.5)
		floater["y"] = y
		floater["rise"] = rise
		var drift: Vector2 = floater["drift"]
		if not floater["dropped"]:
			var slope := Vector2(_wave(p + Vector2(0.1, 0.0)) - _wave(p - Vector2(0.1, 0.0)), _wave(p + Vector2(0.0, 0.1)) - _wave(p - Vector2(0.0, 0.1))) / (0.2 * radius)
			drift += (-slope * 3.0 - felt * 0.05) * delta
			drift *= exp(-1.6 * delta)
		at += drift * delta
		var wall := radius - size * 0.62
		if at.length() > wall:
			var out := at.normalized()
			at = out * wall
			drift -= out * maxf(drift.dot(out), 0.0) * 1.4
		floater["at"] = at
		floater["drift"] = drift
	for i in _floaters.size():  # Shoulder each other aside.
		for j in range(i + 1, _floaters.size()):
			var a := _floaters[i]
			var b := _floaters[j]
			var room: float = (a["size"] + b["size"]) * 0.5
			var apart: Vector2 = b["at"] - a["at"]
			if absf(a["y"] - b["y"]) > room or apart.length() >= room:
				continue
			var way := apart.normalized() if apart.length() > 0.0001 else Vector2.from_angle(randf() * TAU)
			var shove := way * (room - apart.length()) * 0.5
			a["at"] -= shove
			b["at"] += shove
			a["drift"] -= shove * 2.0
			b["drift"] += shove * 2.0
	for floater in _floaters:
		var node: Node3D = floater["node"]
		var at: Vector2 = floater["at"]
		var p := at / radius
		node.position = Vector3(at.x, _liquid.position.y + floater["y"], at.y)
		var lean := Vector3(-(_wave(p + Vector2(0.1, 0.0)) - _wave(p - Vector2(0.1, 0.0))), 0.2 * radius, -(_wave(p + Vector2(0.0, 0.1)) - _wave(p - Vector2(0.0, 0.1)))).normalized()
		var axis := Vector3.UP.cross(lean)
		var turn := Basis(Vector3.UP, floater["turn"])
		node.basis = (Basis(axis.normalized(), Vector3.UP.angle_to(lean)) if axis.length() > 0.0001 else Basis.IDENTITY) * turn * (floater["basis"] as Basis)


func _add_floater(node: Node3D, size: float, at: Vector2, y: float, dropped: bool, ride: float) -> void:
	add_child(node)
	_floaters.append({ "node": node, "size": size, "at": at, "drift": Vector2.ZERO, "y": y, "rise": 0.0, "dropped": dropped, "ride": ride, "turn": randf() * TAU, "basis": node.basis })
	node.position = Vector3(at.x, _liquid.position.y + y, at.y)
	_still = false


# A mini marshmallow: one that's there, or dropped in from `from` above the rim.
func add_marshmallow(dropped := true, from := 0.1) -> void:
	var node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = MARSHMALLOW_SIZE * 0.5
	mesh.height = MARSHMALLOW_SIZE * 1.25
	mesh.radial_segments = 10
	mesh.rings = 3
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(1.0, 0.97, 0.94) if randf() < 0.7 else Color(1.0, 0.82, 0.86)
	paint.roughness = 0.9
	mesh.material = paint
	node.mesh = mesh
	node.rotation = Vector3(randf_range(0.6, 1.6), 0.0, randf_range(-0.6, 0.6))
	var at := Vector2.from_angle(randf() * TAU) * _radius_at(_level) * sqrt(randf()) * 0.72
	_add_floater(node, MARSHMALLOW_SIZE, at, HEIGHT + from if dropped else _level, dropped, MARSHMALLOW_SIZE * 0.25)
	if dropped:
		_floaters[-1]["drift"] = Vector2(randf_range(-0.02, 0.02), randf_range(-0.02, 0.02))


func _add_ice() -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.85, 0.95) * ICE_SIZE
	var paint := ShaderMaterial.new()
	paint.shader = GLASS
	paint.set_shader_parameter("glass", Color(0.93, 0.98, 1.0))
	paint.set_shader_parameter("body", 0.42)
	paint.set_shader_parameter("edge", 0.5)
	mesh.material = paint
	node.mesh = mesh
	node.rotation = Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	node.sorting_offset = 0.1
	_add_floater(node, ICE_SIZE * 1.12, Vector2.from_angle(randf() * TAU) * 0.02, _level, false, -ICE_SIZE * 0.12)


func _add_pearl(index: int) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.0085
	mesh.height = 0.017
	mesh.radial_segments = 10
	mesh.rings = 6
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.13, 0.07, 0.05)
	paint.roughness = 0.2
	mesh.material = paint
	node.mesh = mesh
	var ring := index / 7
	var angle := TAU * (index % 7) / 7.0 + ring * 0.5
	node.position = Vector3(cos(angle) * (_bottom - 0.006), 0.016 + ring * 0.015, sin(angle) * (_bottom - 0.006))
	add_child(node)


func _add_steam() -> void:
	var steam := CPUParticles3D.new()
	steam.amount = 7
	steam.lifetime = 1.8
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = RADIUS * 0.5
	steam.direction = Vector3.UP
	steam.spread = 14.0
	steam.gravity = Vector3.ZERO
	steam.initial_velocity_min = 0.05
	steam.initial_velocity_max = 0.09
	var swell := Curve.new()
	swell.add_point(Vector2(0.0, 0.35))
	swell.add_point(Vector2(1.0, 1.0))
	steam.scale_amount_curve = swell
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.25, Color(1.0, 0.99, 0.96, 0.2))
	fade.set_color(fade.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
	steam.color_ramp = fade
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.06, 0.06)
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.vertex_color_use_as_albedo = true
	paint.albedo_texture = CookSession._puff_texture()
	paint.render_priority = 2
	mesh.material = paint
	steam.mesh = mesh
	steam.position.y = HEIGHT
	add_child(steam)


# --- Shapes -----------------------------------------------------------------------

# The unit cylinder the shader shapes: a top in rings, sides in rows, a bottom.
# UV.x says which: 1 the top, 0 the sides, -1 the bottom.
static func _unit_cylinder() -> ArrayMesh:
	if _cylinder != null:
		return _cylinder
	const AROUND := 28
	const RINGS := 7
	const ROWS := 6
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var point := func(ring: float, step: int, y: float, part: float) -> void:
		var angle := TAU * step / AROUND
		var across := Vector2(cos(angle), sin(angle))
		tool.set_uv(Vector2(part, 0.0))
		tool.set_normal(Vector3(across.x, 0.0, across.y) if part == 0.0 else Vector3(0.0, part, 0.0))
		tool.add_vertex(Vector3(across.x * ring, y, across.y * ring))
	for step in AROUND:
		for ring in RINGS:
			var a := float(ring) / RINGS
			var b := float(ring + 1) / RINGS
			for corner in [[a, step], [b, step], [b, step + 1], [a, step], [b, step + 1], [a, step + 1]]:
				point.call(corner[0], corner[1], 1.0, 1.0)
		for row in ROWS:
			var low := float(row) / ROWS
			var high := float(row + 1) / ROWS
			for corner in [[low, step], [low, step + 1], [high, step + 1], [low, step], [high, step + 1], [high, step]]:
				point.call(1.0, corner[1], corner[0], 0.0)
		for corner in [[0.0, step], [1.0, step + 1], [1.0, step]]:
			point.call(corner[0], corner[1], 0.0, -1.0)
	_cylinder = tool.commit()
	return _cylinder


# A shape turned on a lathe from its outline (distance from the middle, height),
# bottom middle first, then up the outside and down the inside.
static func _lathe(outline: Array) -> ArrayMesh:
	const AROUND := 32
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size() - 1:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[i + 1]
		var along := (b - a).normalized()
		var out := Vector2(along.y, -along.x)
		for step in AROUND:
			var angles := [TAU * step / AROUND, TAU * (step + 1) / AROUND]
			for corner in [[a, 0], [b, 1], [b, 0], [a, 0], [a, 1], [b, 1]]:
				var angle: float = angles[corner[1]]
				var at: Vector2 = corner[0]
				tool.set_normal(Vector3(cos(angle) * out.x, out.y, sin(angle) * out.x))
				tool.add_vertex(Vector3(cos(angle) * at.x, at.y, sin(angle) * at.x))
	return tool.commit()
