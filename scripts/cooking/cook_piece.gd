# CookPiece: one round piece of food in a close-up (a pancake). It has two
# sides that cook separately: the top shows the side facing up, and a slightly
# wider disc underneath shows the side facing down as a ring round the edge, so
# you can see the underside browning. It can be folded in half (an omelette):
# then it's a half-moon, twice as thick, its middle at its position. Placeholder
# shapes only.
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
var doneness := [0.0, 0.0]   # How cooked each side is: 1.0 is just right.
var down_side := 0           # Which side faces down.
var flipped := false
var cook_speed := 1.0        # Its own timer: some pieces cook a little faster.
var busy := false            # Mid-flip or mid-drop: steps leave it alone.
var folded := false
var up_shade := 0.0          # The side facing up looks at least this cooked (a fold's outside, already golden).
var scores := {}             # What each step thought of it, e.g. { "pour": 0.8, "flip": 1.0 }.

var _body := Node3D.new()    # Scaled to the radius.
var _top_material := StandardMaterial3D.new()
var _bottom_material := StandardMaterial3D.new()
var _bubbles: Array[MeshInstance3D] = []
var _discs: Array[MeshInstance3D] = []

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


func up_side() -> int:
	return 1 - down_side


func set_radius(value: float) -> void:
	radius = value
	var r := maxf(value, 0.001)
	_body.scale = Vector3(r, 1.0, r)


# Colors from how cooked each side is, and bubbles on a raw top as the
# underside gets close (the cook's tell that it's nearly time to flip).
func refresh() -> void:
	_top_material.albedo_color = cooked_color(raw_color, maxf(doneness[up_side()], up_shade))
	_bottom_material.albedo_color = cooked_color(raw_color.darkened(0.08), doneness[down_side])
	var tell := 0.0 if flipped or folded else clampf((doneness[down_side] - 0.5) / 0.45, 0.0, 1.0)
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


static func cooked_color(raw: Color, amount: float) -> Color:
	if amount < 1.0:
		return raw.lerp(GOLDEN, pow(clampf(amount / 1.0, 0.0, 1.0), 1.6))
	if amount < 1.4:
		return GOLDEN.lerp(BROWN, (amount - 1.0) / 0.4)
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
