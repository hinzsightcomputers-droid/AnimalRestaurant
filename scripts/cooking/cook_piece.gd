# CookPiece: one round piece of food in a close-up (a pancake). It has two
# sides that cook separately, and its edge shows the underside browning. It's
# soft: it jiggles when it's poured, moved or dropped (springs), droops off a
# spatula, rises as it cooks, and its wet top sets from the edge in, bubbling and
# leaving holes (batter.gdshader draws it all). It can be folded in half (an
# omelette): then it's a half-moon, twice as thick, its middle at its position.
# make_egg and make_bacon give it another look (kind): a sunny-side-up egg (a
# frilly white that sets as it cooks, a yolk on top) or a strip of bacon (pink
# to crisp, with stripes of fat).
class_name CookPiece
extends Node3D

const GOLDEN := Color(0.84, 0.55, 0.27)  # Golden brown, like a real pancake: any yellower and it read as egg.
const BROWN := Color(0.56, 0.31, 0.13)
const BURNT := Color(0.16, 0.1, 0.07)
const BATTER := preload("res://assets/shaders/batter.gdshader")
const NET_ROUND := 64          # The net it's drawn from: segments round it...
const NET_ACROSS := [0.0, 0.2, 0.34, 0.4, 0.43, 0.46, 0.49, 0.52, 0.55, 0.58, 0.61, 0.62, 0.65, 0.69, 0.73, 0.77, 0.81, 0.85, 0.89, 0.93, 0.97, 1.0]  # ...and rings from the middle of its bottom to the middle of its top.
const JIGGLE := 820.0          # Its springs: how stiff...
const JIGGLE_DAMP_RAW := 5.0   # ...and how soon they settle, raw and cooked.
const JIGGLE_DAMP_DONE := 13.0
const JIGGLE_MOST := 0.011     # The most its rim or middle moves (m).
const RISE_RAW := 0.55         # How tall it stands raw (of its thickness); cooked through it's 1.

var surface := ""            # Name of the surface it's on ("" while carried).
var radius := 0.0            # Current size (spreads while being poured).
var spread_to := 0.0         # The size it's spreading to.
var thickness := 0.022
var raw_color := Color.WHITE
var done_color := GOLDEN     # The color it is when just right (yellow for eggs), before browning.
var doneness := [0.0, 0.0]   # How cooked each side is: 1.0 is just right.
var down_side := 0           # Which side faces down.
var flipped := false
var cook_speed := 1.0        # Its own timer: some pieces cook a little faster.
var busy := false            # Mid-flip or mid-drop: steps leave it alone.
var folded := false
var up_shade := 0.0          # The side facing up looks at least this cooked (a fold's outside, already golden).
var scores := {}             # What each step thought of it, e.g. { "pour": 0.8, "flip": 1.0 }.
var kind := ""               # "egg" or "bacon" (see make_egg, make_bacon); "" a round piece.
var side_seconds := 0.0      # Above 0: seconds for the side that's down to be just right (instead of HeatAction's).

var _body := Node3D.new()    # Scaled to the radius.
var _top_material := StandardMaterial3D.new()
var _bottom_material := StandardMaterial3D.new()
var droop := 0.0               # How far its sides hang (m): on a spatula, in the air.
var stream := 0.0              # 1 while something's pouring into its middle.
var _round := MeshInstance3D.new()
var _look := ShaderMaterial.new()
var _height := 0.022           # Its thickness as it was made (the mesh's own; thickness can change).
var _seeds := [randf() * 40.0, randf() * 40.0]  # Each side's own pattern.
var _heave := 0.0
var _heave_speed := 0.0
var _tilt := Vector2.ZERO
var _tilt_speed := Vector2.ZERO
var _bend := 0.0
var _bend_speed := 0.0
var _mound := 0.0
var _last_place := Vector3.INF
var _last_speed := Vector3.ZERO
var _yolk_home := Vector3.ZERO
static var _net: ArrayMesh = null
var _stretch := Vector2.ONE   # An egg isn't quite round.
var _yolk_material: StandardMaterial3D = null
var _strip: MeshInstance3D = null  # Bacon.
var _strip_look: ShaderMaterial = null
var _yolk: MeshInstance3D = null

const BACON := preload("res://assets/shaders/bacon.gdshader")
const YOLK := Color(1.0, 0.68, 0.12)
const YOLK_SET := Color(0.98, 0.84, 0.45)
const EGG_RAW := Color(0.84, 0.85, 0.78)     # A raw white, still see-through-ish grey.
const EGG_WHITE := Color(0.99, 0.98, 0.94)
const BACON_RAW := Color(0.93, 0.52, 0.52)
const BACON_DONE := Color(0.7, 0.3, 0.18)
const FAT := Color(0.98, 0.9, 0.86)
const FAT_CRISP := Color(0.93, 0.7, 0.42)

const LEAVES := 34
var _leaves := 0  # Greens: how many leaves are on.
var _leaf_reach := 0.09
var _leaf_paints: Array[StandardMaterial3D] = []

const HALF_MOON_MIDDLE := 0.4244  # 4 / 3π: how far a half circle's middle is from its straight edge (of the radius).


func setup(color: Color, piece_thickness: float) -> void:
	raw_color = color
	thickness = piece_thickness
	_height = piece_thickness
	add_child(_body)
	_look.shader = BATTER
	_look.set_shader_parameter("seed", randf() * 20.0)
	_look.set_shader_parameter("thickness", _height)
	_look.set_shader_parameter("burnt", BURNT)
	_round.mesh = _make_net()
	_round.material_override = _look
	add_child(_round)
	_top_material.roughness = 0.75
	_top_material.set_meta(ToonStyle.FOOD, "egg")
	set_radius(0.0)
	refresh()


# A sunny-side-up egg, `white_radius` across its white: a not-quite-round
# white (raw grey, setting white; its edge browns) with a domed yolk on top.
# Call after setup.
func make_egg(white_radius: float, yolk_radius := 0.016) -> void:
	kind = "egg"
	raw_color = EGG_RAW
	done_color = EGG_WHITE
	_stretch = Vector2(randf_range(1.0, 1.12), randf_range(0.88, 1.0))
	_round.rotation.y = randf() * TAU
	_look.set_shader_parameter("stretch", _stretch)
	_look.set_shader_parameter("flat_egg", 1.0)
	_yolk_material = StandardMaterial3D.new()
	_yolk_material.roughness = 0.12
	_yolk_material.metallic_specular = 0.6
	_yolk_material.rim_enabled = true  # Light getting into it at its edge.
	_yolk_material.rim = 0.5
	_yolk_material.set_meta(ToonStyle.SKIP, true)  # Glossy, with no outline.
	var yolk := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = yolk_radius
	dome.height = yolk_radius * 1.45
	dome.radial_segments = 28
	dome.rings = 14
	dome.material = _yolk_material
	yolk.mesh = dome
	var off_middle := Vector2.from_angle(randf() * TAU) * white_radius * 0.15
	yolk.position = Vector3(off_middle.x, thickness * 0.9, off_middle.y)
	add_child(yolk)
	_yolk = yolk
	_yolk_home = yolk.position
	spread_to = white_radius
	refresh()


# A strip of bacon, `length` long and `width` wide (lying along x): a slightly
# wavy strip, the side facing up on top and the side facing down peeking out
# round its edge, with two stripes of fat along it. Call after setup.
func make_bacon(length: float, width: float) -> void:
	kind = "bacon"
	raw_color = BACON_RAW
	done_color = BACON_DONE
	_round.visible = false
	_strip_look = ShaderMaterial.new()
	_strip_look.shader = BACON
	for pair in [["strip", Vector2(length, width)], ["thickness", thickness], ["seed", randf() * 30.0], ["raw", BACON_RAW], ["done", BACON_DONE], ["fat_raw", FAT], ["fat_done", FAT_CRISP], ["burnt", BURNT]]:
		_strip_look.set_shader_parameter(pair[0], pair[1])
	var block := BoxMesh.new()
	block.size = Vector3(1.0, 1.0, 1.0)
	block.subdivide_width = 60
	block.subdivide_depth = 8
	_strip = MeshInstance3D.new()
	_strip.mesh = block
	_strip.material_override = _strip_look
	_strip.custom_aabb = AABB(Vector3(-length, -0.02, -width), Vector3(length * 2.0, 0.06, width * 2.0))
	add_child(_strip)
	set_radius(length * 0.5)  # For getting hold of it (the body itself is hidden).
	spread_to = width
	refresh()


# Salad leaves, dropping on one by one as it's filled out to `reach`. Call after setup.
func make_greens(reach: float) -> void:
	kind = "greens"
	_leaf_reach = reach
	_round.visible = false
	for color: Color in [raw_color, raw_color.lightened(0.18), raw_color.darkened(0.18), Color(0.62, 0.78, 0.36), Color(0.5, 0.2, 0.32)]:
		var paint := StandardMaterial3D.new()
		paint.albedo_color = color
		paint.roughness = 0.5
		paint.cull_mode = BaseMaterial3D.CULL_DISABLED
		paint.set_meta(ToonStyle.FOOD, "veg")
		_leaf_paints.append(paint)


func _add_leaf() -> void:
	var k := _leaves
	_leaves += 1
	var out := _leaf_reach * 0.72 * sqrt((k + 0.5) / LEAVES)
	var turn := k * 2.39996
	var leaf := MeshInstance3D.new()
	leaf.mesh = _leaf_mesh(randf_range(0.05, 0.072))
	leaf.material_override = _leaf_paints[4 if k % 7 == 3 else k % 4]
	var rests := Vector3(cos(turn) * out, 0.004 + thickness * randf_range(0.15, 0.62), sin(turn) * out)
	leaf.rotation = Vector3(randf_range(-0.25, 0.25), -turn + randf_range(-0.6, 0.6), randf_range(0.05, 0.4))
	leaf.position = rests + Vector3(0.0, 0.12, 0.0)
	add_child(leaf)
	var fall := leaf.create_tween()
	fall.tween_property(leaf, "position", rests, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(leaf, "rotation", leaf.rotation, 0.22).from(leaf.rotation + Vector3(randf_range(-1.5, 1.5), 1.0, randf_range(-1.0, 1.0)))
	fall.tween_property(leaf, "scale", Vector3(1.08, 0.7, 1.08), 0.06)
	fall.tween_property(leaf, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# A ruffled leaf along x, cupped, with its rib down the middle.
static func _leaf_mesh(long: float) -> ArrayMesh:
	const ALONG := 12
	const ACROSS := 10
	var wave := randf() * TAU
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	for i in ALONG + 1:
		var u := float(i) / ALONG
		var wide := long * 0.42 * pow(sin(PI * pow(u, 0.75)), 0.6) + 0.001
		for k in ACROSS + 1:
			var v := float(k) / ACROSS * 2.0 - 1.0
			var ruffle := sin(u * 17.0 + wave + signf(v) * 1.3) * absf(v) * absf(v) * long * 0.07
			var y := long * (0.16 * v * v - 0.1 * absf(v) * 0.4 + 0.12 * u * u) + ruffle
			tool.add_vertex(Vector3((u - 0.35) * long, y, v * wide * (1.0 + 0.12 * sin(u * 23.0 + wave))))
	for i in ALONG:
		for k in ACROSS:
			var a := i * (ACROSS + 1) + k
			var b := a + ACROSS + 1
			for index in [a, a + 1, b, a + 1, b + 1, b]:
				tool.add_index(index)
	tool.generate_normals()
	return tool.commit()


# An egg's yolk shown or not (it drops in last as the egg pours out).
func show_yolk(on: bool) -> void:
	if _yolk != null:
		_yolk.visible = on


func up_side() -> int:
	return 1 - down_side


func set_radius(value: float) -> void:
	radius = value
	var r := maxf(value, 0.001)
	_body.scale = Vector3(r * _stretch.x, 1.0, r * _stretch.y)
	_round.visible = value > 0.002 and not folded and _strip == null and kind != "greens"
	if kind == "greens":
		while _leaves < LEAVES and _leaves < ceili(LEAVES * pow(value / _leaf_reach, 2.0)):
			_add_leaf()
	_look.set_shader_parameter("radius", r)


# Colors from how cooked each side is, and bubbles on a raw top as the
# underside gets close (the cook's tell that it's nearly time to flip).
func refresh() -> void:
	var down: float = doneness[down_side]
	match kind:
		"egg":  # Sunny side up: the heat from below sets the white, and its frilly edge browns.
			_yolk_material.albedo_color = YOLK.lerp(YOLK_SET, clampf((down - 1.1) / 0.5, 0.0, 1.0))  # Goes pale and hard if overdone.
		"bacon":
			_strip_look.set_shader_parameter("up", maxf(doneness[up_side()], up_shade))
			_strip_look.set_shader_parameter("down", down)
			_strip_look.set_shader_parameter("cooked", doneness[0] + doneness[1])
		_:
			_top_material.albedo_color = cooked_color(raw_color, maxf(doneness[up_side()], up_shade), done_color)
			_bottom_material.albedo_color = cooked_color(raw_color.darkened(0.08), down, done_color)
	var first: float = doneness[0]
	var rise := lerpf(RISE_RAW, 1.0, smoothstep(0.1, 1.0, first)) if kind.is_empty() else 1.0
	var bubbly := done_color == GOLDEN
	for pair in [["raw", raw_color], ["done", done_color], ["brown", BROWN if bubbly else done_color.darkened(0.22).lerp(GOLDEN, 0.3)], ["up", maxf(doneness[up_side()], up_shade)], ["down", down], ["up_seed", _seeds[up_side()]], ["down_seed", _seeds[down_side]], ["up_holes", 0.0 if flipped else 1.0], ["bubbles", 1.0 if bubbly else 0.35], ["bubbled", first], ["rise", rise], ["mirror", -1.0 if flipped else 1.0]]:
		_look.set_shader_parameter(pair[0], pair[1])


# Set it jiggling: pushed down in the middle by `amount` (as a drop would).
func jolt(amount := 0.2, sideways := Vector2.ZERO) -> void:
	_heave_speed -= amount * 1.2
	_tilt_speed += sideways * amount * 1.6 + Vector2.from_angle(randf() * TAU) * amount * 0.25


# Its springs: how it moves throws it about, the more the rawer it is.
func _physics_process(delta: float) -> void:
	if folded or _strip != null or kind == "greens":
		return
	var soft := lerpf(1.0, 0.4, clampf(doneness[0] + doneness[1], 0.0, 1.0))
	if _last_place != Vector3.INF and delta > 0.0:
		var speed := (position - _last_place) / delta
		var push := (speed - _last_speed).limit_length(3.0)
		_last_speed = speed
		_heave_speed -= push.y * 0.05 * soft
		_tilt_speed -= Vector2(push.x, push.z) * 0.09 * soft
	_last_place = position
	var damp := lerpf(JIGGLE_DAMP_DONE, JIGGLE_DAMP_RAW, soft)
	_heave_speed += (-JIGGLE * _heave - damp * _heave_speed) * delta
	_heave = clampf(_heave + _heave_speed * delta, -JIGGLE_MOST, JIGGLE_MOST)
	_tilt_speed += (-JIGGLE * 0.8 * _tilt - damp * _tilt_speed) * delta
	_tilt = (_tilt + _tilt_speed * delta).limit_length(JIGGLE_MOST)
	_bend_speed += (420.0 * (droop - _bend) - 13.0 * _bend_speed) * delta
	_bend += _bend_speed * delta
	_mound = lerpf(_mound, stream, 1.0 - exp(-(9.0 if stream > 0.0 else 4.0) * delta))
	for pair in [["heave", _heave], ["tilt", _tilt], ["bend", _bend], ["mound", _mound * _height * 0.5], ["ripple", _mound * 0.0011]]:
		_look.set_shader_parameter(pair[0], pair[1])
	if _yolk != null:  # The yolk wobbles with it.
		var wide := 1.0 - _heave * 16.0
		_yolk.scale = Vector3(wide, 1.0 + _heave * 30.0, wide)
		_yolk.position = _yolk_home + Vector3(_tilt.x, 0.0, _tilt.y) * 0.45


# The net every round piece is drawn from (its shape is the shader's).
static func _make_net() -> ArrayMesh:
	if _net != null:
		return _net
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := NET_ACROSS.size()
	for ring in rings:
		for i in NET_ROUND + 1:
			tool.set_uv(Vector2(NET_ACROSS[ring], float(i) / NET_ROUND))
			tool.set_normal(Vector3.UP)
			tool.add_vertex(Vector3(cos(TAU * i / NET_ROUND), NET_ACROSS[ring], sin(TAU * i / NET_ROUND)) * 0.1)
	for ring in rings - 1:
		for i in NET_ROUND:
			var a := ring * (NET_ROUND + 1) + i
			var b := a + NET_ROUND + 1
			for index in [a, b, a + 1, a + 1, b, b + 1]:
				tool.add_index(index)
	_net = tool.commit()
	_net.custom_aabb = AABB(Vector3(-0.17, -0.06, -0.17), Vector3(0.34, 0.14, 0.34))
	return _net


# How far it reaches in a direction (its outline isn't a perfect circle), and how
# high its top is at a point (session x, z), or -INF off it.
func height_at(point: Vector2) -> float:
	if not covers(point):
		return -INF
	var tall := thickness
	var gap := radius - (point - middle()).length()
	var bulge := tall * 0.5
	if not folded and gap < bulge:  # Its edge rounds over.
		var in_from := 1.0 - gap / bulge
		tall = bulge + bulge * sqrt(maxf(1.0 - in_from * in_from, 0.0))
	return position.y + tall


# Whether it's over a point (x, z in the session), going by its shape.
func covers(point: Vector2) -> bool:
	var offset := point - middle()
	return offset.length() <= radius and (not folded or offset.y <= 0.0)


# The middle of its circle (a folded one's is on its straight edge).
func middle() -> Vector2:
	return Vector2(position.x, position.z + _body.position.z)


# Fold the near half over the far half, over `seconds`: a half-moon after.
func fold_over(seconds: float) -> void:
	_round.visible = false
	_top_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # The flap shows its underside as it turns.
	_bottom_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var stays := _half_moon(-1.0, thickness)
	_body.add_child(stays)
	# Along the middle, on top: the near half turns over on it. Not in the body,
	# which is only stretched sideways (turning in there would stretch it up).
	var hinge := Node3D.new()
	hinge.position.y = thickness
	add_child(hinge)
	var flap := _half_moon(1.0, thickness)
	flap.position.y = -thickness
	flap.scale = _body.scale
	hinge.add_child(flap)
	var tween := create_tween()
	tween.tween_property(hinge, "rotation:x", -PI, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	stays.queue_free()
	hinge.queue_free()
	folded = true
	thickness *= 2.0
	_body.add_child(_half_moon(-1.0, thickness))
	# Its position goes to the half-moon's middle, so stacking and plating center it.
	var shift := HALF_MOON_MIDDLE * radius
	position.z -= shift
	_body.position.z = shift


# Half a disc of this piece, `height` tall, on the far (side -1) or near (1)
# side of its middle: the top in the up side's color, the rest the down side's.
func _half_moon(side: float, height: float) -> MeshInstance3D:
	const SEGMENTS := 28
	var mesh := ArrayMesh.new()
	var edge: Array[Vector3] = []
	for i in SEGMENTS + 1:
		var angle := PI * i / SEGMENTS
		edge.append(Vector3(cos(angle), 0.0, sin(angle) * side))
	var lift := Vector3(0.0, height, 0.0)
	# Mirroring to the far side (side -1) turns every triangle inside out; put
	# them back the right way round, or the toon outline (drawn on back faces)
	# covers the whole top in dark brown, hiding the ketchup.
	var add_triangles := func(tool: SurfaceTool, corners: Array) -> void:
		for t in range(0, corners.size(), 3):
			var order := [0, 1, 2] if side > 0.0 else [0, 2, 1]
			for k in order:
				tool.add_vertex(corners[t + k])
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	top.set_normal(Vector3.UP)
	if folded:  # Both layers: soft and pillowy, rounded over at the fold and the rim.
		const RINGS := 14
		lift *= 0.32
		top.set_smooth_group(0)
		for ring in RINGS:
			for i in SEGMENTS:
				var corners := []
				for corner in [[ring, i], [ring + 1, i], [ring + 1, i + 1], [ring, i], [ring + 1, i + 1], [ring, i + 1]]:
					var out_at := float(corner[0]) / RINGS
					var way: Vector3 = edge[corner[1]]
					var in_from := clampf(minf(1.0 - out_at, absf(way.z) * out_at) / 0.3, 0.0, 1.0)
					var tall := height * (0.32 + 0.78 * sqrt(1.0 - pow(1.0 - in_from, 2.0)) + 0.05 * in_from * sin(way.x * out_at * 7.0 + out_at * 3.0))
					corners.append(way * out_at + Vector3(0.0, tall, 0.0))
				add_triangles.call(top, corners)
		top.generate_normals()
	else:
		for i in SEGMENTS:
			add_triangles.call(top, [Vector3.ZERO + lift, edge[i] + lift, edge[i + 1] + lift])
	top.commit(mesh)
	mesh.surface_set_material(0, _top_material)
	var rest := SurfaceTool.new()
	rest.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS:
		rest.set_normal(Vector3.DOWN)
		add_triangles.call(rest, [Vector3.ZERO, edge[i + 1], edge[i]])
		rest.set_normal((edge[i] + edge[i + 1]).normalized())
		add_triangles.call(rest, [edge[i], edge[i + 1], edge[i + 1] + lift, edge[i], edge[i + 1] + lift, edge[i] + lift])
	rest.set_normal(Vector3(0.0, 0.0, -side))  # The straight edge.
	add_triangles.call(rest, [Vector3.LEFT, Vector3.RIGHT, Vector3.RIGHT + lift, Vector3.LEFT, Vector3.RIGHT + lift, Vector3.LEFT + lift])
	rest.commit(mesh)
	mesh.surface_set_material(1, _bottom_material)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


static func cooked_color(raw: Color, amount: float, done := GOLDEN) -> Color:
	if amount < 1.0:
		return raw.lerp(done, pow(clampf(amount / 1.0, 0.0, 1.0), 1.6))
	# Past just right it browns: a pancake toward BROWN; anything with its own done
	# color (yellow egg) toward a deeper shade of that, never the pancake's red-brown.
	var brown := BROWN if done == GOLDEN else done.darkened(0.22).lerp(GOLDEN, 0.3)
	if amount < 1.4:
		return done.lerp(brown, (amount - 1.0) / 0.4)
	return brown.lerp(BURNT, clampf((amount - 1.4) / 0.4, 0.0, 1.0))
