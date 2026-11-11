# CookPiece: one round piece of food in a close-up (a pancake). It has two
# sides that cook separately: the top shows the side facing up, and a slightly
# wider disc underneath shows the side facing down as a ring round the edge, so
# you can see the underside browning. It can be folded in half (an omelette):
# then it's a half-moon, twice as thick, its middle at its position. Placeholder
# shapes only.
# make_egg and make_bacon give it another look (kind): a sunny-side-up egg (a
# frilly white that sets as it cooks, a yolk on top) or a strip of bacon (pink
# to crisp, with stripes of fat).
class_name CookPiece
extends Node3D

const GOLDEN := Color(0.88, 0.6, 0.25)
const BROWN := Color(0.55, 0.32, 0.14)
const BURNT := Color(0.16, 0.1, 0.07)
const BUBBLES := 8

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
var _bubbles: Array[MeshInstance3D] = []
var _discs: Array[MeshInstance3D] = []
var _stretch := Vector2.ONE   # An egg isn't quite round.
var _yolk_material: StandardMaterial3D = null
var _fat_material: StandardMaterial3D = null
var _strip: Node3D = null      # Bacon's look (not in the body, which is scaled to the radius).

const YOLK := Color(1.0, 0.68, 0.12)
const YOLK_SET := Color(0.98, 0.84, 0.45)
const EGG_RAW := Color(0.84, 0.85, 0.78)     # A raw white, still see-through-ish grey.
const EGG_WHITE := Color(0.99, 0.98, 0.94)
const BACON_RAW := Color(0.93, 0.52, 0.52)
const BACON_DONE := Color(0.7, 0.3, 0.18)
const FAT := Color(0.98, 0.9, 0.86)
const FAT_CRISP := Color(0.93, 0.7, 0.42)

const HALF_MOON_MIDDLE := 0.4244  # 4 / 3π: how far a half circle's middle is from its straight edge (of the radius).


func setup(color: Color, piece_thickness: float) -> void:
	raw_color = color
	thickness = piece_thickness
	add_child(_body)
	var bottom := _disc(1.06, thickness * 0.5, _bottom_material)
	bottom.position.y = thickness * 0.25
	var top := _disc(1.0, thickness * 0.55, _top_material)
	top.position.y = thickness * 0.725
	_discs.assign([bottom, top])
	_top_material.roughness = 0.35
	var bubble_material := StandardMaterial3D.new()
	bubble_material.albedo_color = color.darkened(0.25)
	for i in BUBBLES:
		var bubble := _disc(0.07 + randf() * 0.04, 0.002, bubble_material)
		var spot := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * 0.75
		bubble.position = Vector3(spot.x, thickness + 0.001, spot.y)
		bubble.visible = false
		_bubbles.append(bubble)
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
	_body.rotation.y = randf() * TAU
	_top_material.roughness = 0.25
	_yolk_material = StandardMaterial3D.new()
	_yolk_material.roughness = 0.15
	var yolk := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = yolk_radius
	dome.height = yolk_radius * 1.3
	dome.radial_segments = 20
	dome.rings = 8
	dome.material = _yolk_material
	yolk.mesh = dome
	var off_middle := Vector2.from_angle(randf() * TAU) * white_radius * 0.15
	yolk.position = Vector3(off_middle.x, thickness * 0.9, off_middle.y)
	add_child(yolk)
	spread_to = white_radius
	refresh()


# A strip of bacon, `length` long and `width` wide (lying along x): a slightly
# wavy strip, the side facing up on top and the side facing down peeking out
# round its edge, with two stripes of fat along it. Call after setup.
func make_bacon(length: float, width: float) -> void:
	kind = "bacon"
	raw_color = BACON_RAW
	done_color = BACON_DONE
	for disc in _discs:
		disc.visible = false
	_fat_material = StandardMaterial3D.new()
	_fat_material.roughness = 0.4
	_strip = Node3D.new()
	add_child(_strip)
	const SEGMENTS := 4
	var segment := length / SEGMENTS
	for i in SEGMENTS:
		var part := Node3D.new()
		part.position.x = -length * 0.5 + segment * (i + 0.5)
		part.rotation.z = deg_to_rad(5.0 if i % 2 == 0 else -5.0)  # A gentle ripple.
		_strip.add_child(part)
		_box(part, Vector3(segment * 1.04, thickness * 0.5, width * 1.08), thickness * 0.25, _bottom_material)
		_box(part, Vector3(segment * 1.02, thickness * 0.55, width), thickness * 0.725, _top_material)
		for side in [-0.22, 0.22]:
			var stripe := _box(part, Vector3(segment * 1.02, thickness * 0.08, width * 0.16), thickness, _fat_material)
			stripe.position.z = width * side
	set_radius(length * 0.5)  # For getting hold of it (the body itself is hidden).
	spread_to = width
	refresh()


func _box(parent: Node3D, box_size: Vector3, height: float, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	var box := MeshInstance3D.new()
	box.mesh = mesh
	box.position.y = height
	parent.add_child(box)
	return box


func up_side() -> int:
	return 1 - down_side


func set_radius(value: float) -> void:
	radius = value
	var r := maxf(value, 0.001)
	_body.scale = Vector3(r * _stretch.x, 1.0, r * _stretch.y)


# Colors from how cooked each side is, and bubbles on a raw top as the
# underside gets close (the cook's tell that it's nearly time to flip).
func refresh() -> void:
	var down: float = doneness[down_side]
	match kind:
		"egg":  # Sunny side up: the heat from below sets the white, and its frilly edge browns.
			_top_material.albedo_color = cooked_color(raw_color, minf(down, 1.0), done_color)
			_bottom_material.albedo_color = cooked_color(raw_color, down, done_color)
			_yolk_material.albedo_color = YOLK.lerp(YOLK_SET, clampf((down - 1.1) / 0.5, 0.0, 1.0))  # Goes pale and hard if overdone.
		"bacon":
			var up: float = maxf(doneness[up_side()], up_shade)
			_top_material.albedo_color = cooked_color(raw_color, up, done_color)
			_bottom_material.albedo_color = cooked_color(raw_color.darkened(0.08), down, done_color)
			_fat_material.albedo_color = cooked_color(FAT, up, FAT_CRISP)
		_:
			_top_material.albedo_color = cooked_color(raw_color, maxf(doneness[up_side()], up_shade), done_color)
			_bottom_material.albedo_color = cooked_color(raw_color.darkened(0.08), down, done_color)
	var tell := 0.0 if flipped or folded or not kind.is_empty() else clampf((down - 0.5) / 0.45, 0.0, 1.0)
	for i in _bubbles.size():
		_bubbles[i].visible = i < roundi(tell * BUBBLES)


# Whether it's over a point (x, z in the session), going by its shape.
func covers(point: Vector2) -> bool:
	var offset := point - middle()
	return offset.length() <= radius and (not folded or offset.y <= 0.0)


# The middle of its circle (a folded one's is on its straight edge).
func middle() -> Vector2:
	return Vector2(position.x, position.z + _body.position.z)


# Fold the near half over the far half, over `seconds`: a half-moon after.
func fold_over(seconds: float) -> void:
	for disc in _discs:
		disc.visible = false
	for bubble in _bubbles:
		bubble.visible = false
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
	const SEGMENTS := 16
	var mesh := ArrayMesh.new()
	var edge: Array[Vector3] = []
	for i in SEGMENTS + 1:
		var angle := PI * i / SEGMENTS
		edge.append(Vector3(cos(angle), 0.0, sin(angle) * side))
	var lift := Vector3(0.0, height, 0.0)
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	top.set_normal(Vector3.UP)
	for i in SEGMENTS:
		for corner in [Vector3.ZERO, edge[i], edge[i + 1]]:
			top.add_vertex(corner + lift)
	top.commit(mesh)
	mesh.surface_set_material(0, _top_material)
	var rest := SurfaceTool.new()
	rest.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS:
		rest.set_normal(Vector3.DOWN)
		for corner in [Vector3.ZERO, edge[i + 1], edge[i]]:
			rest.add_vertex(corner)
		rest.set_normal((edge[i] + edge[i + 1]).normalized())
		for corner in [edge[i], edge[i + 1], edge[i + 1] + lift, edge[i], edge[i + 1] + lift, edge[i] + lift]:
			rest.add_vertex(corner)
	rest.set_normal(Vector3(0.0, 0.0, -side))  # The straight edge.
	for corner in [Vector3.LEFT, Vector3.RIGHT, Vector3.RIGHT + lift, Vector3.LEFT, Vector3.RIGHT + lift, Vector3.LEFT + lift]:
		rest.add_vertex(corner)
	rest.commit(mesh)
	mesh.surface_set_material(1, _bottom_material)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


static func cooked_color(raw: Color, amount: float, done := GOLDEN) -> Color:
	if amount < 1.0:
		return raw.lerp(done, pow(clampf(amount / 1.0, 0.0, 1.0), 1.6))
	if amount < 1.4:
		return done.lerp(BROWN, (amount - 1.0) / 0.4)
	return BROWN.lerp(BURNT, clampf((amount - 1.4) / 0.4, 0.0, 1.0))


func _disc(disc_radius: float, height: float, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = disc_radius
	mesh.bottom_radius = disc_radius
	mesh.height = height
	mesh.radial_segments = 32
	mesh.rings = 1
	mesh.material = material
	var disc := MeshInstance3D.new()
	disc.mesh = mesh
	_body.add_child(disc)
	return disc
