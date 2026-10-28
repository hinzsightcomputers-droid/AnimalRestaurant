# CookPiece: one round piece of food in a close-up (a pancake). It has two
# sides that cook separately: the top shows the side facing up, and a slightly
# wider disc underneath shows the side facing down as a ring round the edge, so
# you can see the underside browning. Placeholder shapes only.
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
var scores := {}             # What each step thought of it, e.g. { "pour": 0.8, "flip": 1.0 }.

var _body := Node3D.new()    # Scaled to the radius.
var _top_material := StandardMaterial3D.new()
var _bottom_material := StandardMaterial3D.new()
var _bubbles: Array[MeshInstance3D] = []


func setup(color: Color, piece_thickness: float) -> void:
	raw_color = color
	thickness = piece_thickness
	add_child(_body)
	var bottom := _disc(1.06, thickness * 0.5, _bottom_material)
	bottom.position.y = thickness * 0.25
	var top := _disc(1.0, thickness * 0.55, _top_material)
	top.position.y = thickness * 0.725
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
	_top_material.albedo_color = cooked_color(raw_color, doneness[up_side()])
	_bottom_material.albedo_color = cooked_color(raw_color.darkened(0.08), doneness[down_side])
	var tell := 0.0 if flipped else clampf((doneness[down_side] - 0.5) / 0.45, 0.0, 1.0)
	for i in _bubbles.size():
		_bubbles[i].visible = i < roundi(tell * BUBBLES)


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
