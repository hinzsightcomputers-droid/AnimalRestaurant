# BackGarden: the bit of outdoors behind the restaurant, out the back door:
# a pond with three little docks to fish from (FishingSpot), stepping stones
# from the door, reeds and lily pads, a few more trees (pines by the pond,
# oaks to the east), places to forage (ForageSpot), and a lantern that
# comes on from evening to early morning (the real hour). Built in code; the
# lighting overall follows the real hour after hours (DayManager).
class_name BackGarden
extends Node3D

const POND_CENTER := Vector3(-7.0, 0.0, -11.0)
const POND_RADIUS := 2.4
const SPOT_DISTANCE := 2.95          # From the pond's middle to where a fisher stands.
const SPOT_ANGLES := [0.0, 45.0, -45.0]  # Degrees round from the side facing the restaurant.
const BACK_DOOR_OUTSIDE := Vector3(-3.3, 0.0, -5.9)
const LANTERN_SPOT := Vector3(-5.1, 0.0, -7.7)
const LANTERN_HOURS := ["evening", "late_night", "early_morning"]
const NATURE := "res://design/assets/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/"
const PLANTS := [
	["Tree_3_A_Color1.gltf", Vector3(-11.8, 0.0, -13.0), 4.2],
	["Tree_4_A_Color1.gltf", Vector3(-3.6, 0.0, -15.8), 3.8],
	["Tree_1_B_Color1.gltf", Vector3(-12.5, 0.0, -17.5), 4.5],
	["Bush_1_A_Color1.gltf", Vector3(-10.9, 0.0, -10.6), 0.9],
	["Bush_2_B_Color1.gltf", Vector3(-4.1, 0.0, -13.9), 0.8],
	["Bush_4_C_Color1.gltf", Vector3(-1.2, 0.0, -7.6), 0.7],
	["Rock_1_C_Color1.gltf", Vector3(-9.6, 0.0, -13.4), 0.5],
	["Tree_1_C_Color1.gltf", Vector3(6.8, 0.0, -17.4), 4.4],   # The oaks, off to the east.
	["Tree_2_A_Color1.gltf", Vector3(13.2, 0.0, -13.6), 4.0],
	["Bush_2_A_Color1.gltf", Vector3(5.2, 0.0, -12.6), 0.8],
	["Bush_1_C_Color1.gltf", Vector3(2.6, 0.0, -16.4), 0.7],
]

var _lantern_light: OmniLight3D
var _lantern_glass: StandardMaterial3D
var _lantern_check := 0.0
var _rng := RandomNumberGenerator.new()  # Seeded: the same reeds and stones every time.


func _ready() -> void:
	_rng.seed = 7
	_build_pond()
	for angle in SPOT_ANGLES:
		_build_spot(deg_to_rad(angle))
	_build_path()
	_build_reeds_and_pads()
	_build_lantern()
	_build_forage_spots()
	for plant in PLANTS:
		ModelFit.place(NATURE + plant[0], self, plant[1], Vector3(0.0, plant[2], 0.0))


func _process(delta: float) -> void:
	_lantern_check -= delta
	if _lantern_check <= 0.0:
		_lantern_check = 10.0
		var lit := Fishing.hour_block() in LANTERN_HOURS
		_lantern_light.visible = lit
		_lantern_glass.emission_energy_multiplier = 2.5 if lit else 0.0


func _build_pond() -> void:
	var bank := _cylinder(POND_RADIUS + 0.35, 0.03, Color(0.42, 0.36, 0.24))
	bank.position = POND_CENTER + Vector3(0.0, -0.035, 0.0)
	var water := _cylinder(POND_RADIUS, 0.04, Color(0.25, 0.5, 0.68, 0.88))
	var water_material: StandardMaterial3D = water.mesh.material
	water_material.roughness = 0.05
	water_material.metallic = 0.3
	water.position = POND_CENTER + Vector3(0.0, -0.03, 0.0)
	var body := StaticBody3D.new()
	body.name = "PondEdge"
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = POND_RADIUS - 0.15
	cylinder.height = 2.0
	shape.shape = cylinder
	shape.position = POND_CENTER + Vector3(0.0, 1.0, 0.0)
	body.add_child(shape)
	add_child(body)


# A little dock reaching over the water, and the spot to fish from on it.
func _build_spot(angle: float) -> void:
	var outward := Vector3(sin(angle), 0.0, cos(angle))  # From the pond's middle.
	var at := POND_CENTER + outward * SPOT_DISTANCE
	var facing := Basis.looking_at(-outward)
	var dock := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.9, 0.06, 1.3)
	mesh.material = _material(Color(0.55, 0.38, 0.24))
	dock.mesh = mesh
	dock.basis = facing
	dock.position = at - outward * 0.45 + Vector3(0.0, 0.01, 0.0)
	add_child(dock)
	var spot := FishingSpot.new()
	spot.name = "FishingSpot"
	spot.basis = facing
	spot.position = at
	add_child(spot)


func _build_path() -> void:
	var to := POND_CENTER + Vector3(0.0, 0.0, SPOT_DISTANCE + 0.6)
	var stones := 6
	for i in stones:
		var t := (i + 0.5) / stones
		var stone := _cylinder(_rng.randf_range(0.26, 0.34), 0.04, Color(0.62, 0.6, 0.56))
		stone.position = BACK_DOOR_OUTSIDE.lerp(to, t) + Vector3(_rng.randf_range(-0.12, 0.12), -0.01, _rng.randf_range(-0.08, 0.08))


# Reeds round the far side, lily pads on the water.
func _build_reeds_and_pads() -> void:
	for i in 26:
		var angle := deg_to_rad(_rng.randf_range(100.0, 260.0))
		var reed := _cylinder(0.015, _rng.randf_range(0.5, 0.9), Color(0.36, 0.55, 0.25))
		var radius := POND_RADIUS + _rng.randf_range(-0.15, 0.25)
		reed.position = POND_CENTER + Vector3(sin(angle) * radius, reed.mesh.height / 2.0 - 0.03, cos(angle) * radius)
		reed.rotation = Vector3(_rng.randf_range(-0.12, 0.12), 0.0, _rng.randf_range(-0.12, 0.12))
	for i in 6:
		var angle := _rng.randf() * TAU
		var radius := _rng.randf_range(0.6, POND_RADIUS - 0.4)
		var pad := _cylinder(_rng.randf_range(0.14, 0.22), 0.012, Color(0.3, 0.58, 0.28))
		pad.position = POND_CENTER + Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)


# Where things to forage might turn up (data/forage.json; see ForageSpot).
func _build_forage_spots() -> void:
	var spots := Forage.spots()
	for i in spots.size():
		if spots[i].get("area", "garden") != "garden":
			continue  # E.g. the beach's (see Beach).
		var at: Array = spots[i].get("at", [0.0, 0.0])
		var spot := ForageSpot.new()
		spot.name = "ForageSpot%d" % i
		spot.spot_index = i
		spot.position = Vector3(float(at[0]), 0.0, float(at[1]))
		add_child(spot)


func _build_lantern() -> void:
	var post := _cylinder(0.05, 1.7, Color(0.2, 0.18, 0.16))
	post.position = LANTERN_SPOT + Vector3(0.0, 0.85, 0.0)
	var glass := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, 0.28, 0.22)
	_lantern_glass = _material(Color(1.0, 0.85, 0.55))
	_lantern_glass.emission_enabled = true
	_lantern_glass.emission = Color(1.0, 0.75, 0.4)
	mesh.material = _lantern_glass
	glass.mesh = mesh
	glass.position = LANTERN_SPOT + Vector3(0.0, 1.82, 0.0)
	add_child(glass)
	_lantern_light = OmniLight3D.new()
	_lantern_light.light_color = Color(1.0, 0.8, 0.55)
	_lantern_light.light_energy = 1.8
	_lantern_light.omni_range = 7.0
	_lantern_light.position = LANTERN_SPOT + Vector3(0.0, 1.9, 0.0)
	add_child(_lantern_light)


func _cylinder(radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.material = _material(color)
	node.mesh = mesh
	add_child(node)
	return node


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
