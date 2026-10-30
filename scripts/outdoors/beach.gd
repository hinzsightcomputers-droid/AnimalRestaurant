# Beach: Cheddar's secret beach, reached in his car (see CarTrip). Built in code
# far from the restaurant (data/trips.json beach.origin), so nobody at home
# can see it: a strip of sand with the sea toward -z, a pier with three spots
# to fish from (FishingSpot, the beach fish), shells and seaweed to gather
# (data/forage.json spots with area "beach"), a campfire lit from evening to
# early morning, Cheddar to chat with (beach_chat), and his car, where
# "Head home" starts the drive back. Fenced in, so nobody wanders into the sea.
class_name Beach
extends Node3D

const SAND_MIN := Vector2(-14.0, -9.6)   # The sand, from the origin (the waterline is the -z edge).
const SAND_MAX := Vector2(14.0, 4.2)
const PIER_HALF_WIDTH := 1.0
const PIER_END := -17.0
const WATER_Y := -0.12
const REACH := 45.0                       # Players this close to the origin are at the beach.
const NATURE := "res://design/assets/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/"
const PLANTS := [
	["Rock_1_C_Color1.gltf", Vector3(-12.6, 0.0, -7.8), 1.1],
	["Rock_2_B_Color1.gltf", Vector3(-11.8, 0.0, -6.6), 0.6],
	["Rock_3_C_Color1.gltf", Vector3(12.2, 0.0, -7.2), 0.9],
	["Bush_2_A_Color1.gltf", Vector3(-10.5, 0.0, 3.4), 0.9],
	["Bush_4_B_Color1.gltf", Vector3(-6.0, 0.0, 3.6), 0.7],
	["Bush_1_C_Color1.gltf", Vector3(1.5, 0.0, 3.7), 0.8],
	["Bush_2_C_Color1.gltf", Vector3(11.5, 0.0, 3.4), 0.9],
	["Grass_2_A_Color1.gltf", Vector3(-8.2, 0.0, 2.9), 0.5],
	["Grass_2_B_Color1.gltf", Vector3(-2.6, 0.0, 3.1), 0.5],
	["Grass_2_C_Color1.gltf", Vector3(9.0, 0.0, 2.8), 0.5],
	["Tree_3_B_Color1.gltf", Vector3(-13.0, 0.0, 6.5), 4.5],
	["Tree_4_B_Color1.gltf", Vector3(13.4, 0.0, 6.8), 4.2],
]

var car_trip: CarTrip
var cheddar: RegularFigure
var car_interactable := Interactable.new()
var _chat_interactable := Interactable.new()
var _fire_light: OmniLight3D
var _flame: MeshInstance3D
var _fire_check := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 5
	var settings: Dictionary = GameData.trips.get("beach", {})
	var origin: Array = settings.get("origin", [0.0, -400.0])
	position = Vector3(float(origin[0]), 0.0, float(origin[1]))
	_build_ground()
	_build_pier()
	_build_car(settings)
	_build_campfire(_at(settings.get("campfire_at", [-4.5, -1.5])))
	_build_umbrella(Vector3(-1.5, 0.0, -2.5))
	for plant in PLANTS:
		ModelFit.place(NATURE + plant[0], self, plant[1], Vector3(0.0, plant[2], 0.0))
	var spots := Forage.spots()
	for i in spots.size():
		if spots[i].get("area", "garden") == "beach":
			var spot := ForageSpot.new()
			spot.name = "ForageSpot%d" % i
			spot.spot_index = i
			spot.position = _at(spots[i].get("at", [0.0, 0.0]))
			add_child(spot)


func _process(delta: float) -> void:
	_time += delta
	if _flame != null and _flame.visible:
		_flame.scale = Vector3(1.0, 1.0 + sin(_time * 11.0) * 0.12, 1.0)
		_fire_light.light_energy = 2.2 + sin(_time * 13.0) * 0.25 + sin(_time * 7.0) * 0.2
	_fire_check -= delta
	if _fire_check <= 0.0:
		_fire_check = 10.0
		var lit: bool = Fishing.hour_block() in GameData.trips.get("beach", {}).get("campfire_hours", [])
		_flame.visible = lit
		_fire_light.visible = lit


# Whether a spot in the world is at the beach.
func contains(point: Vector3) -> bool:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length() < REACH


# Where the chefs stand when they arrive, in the world.
func arrival_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for at in GameData.trips.get("beach", {}).get("arrive_at", [[6.0, 3.0]]):
		points.append(global_transform * _at(at))
	return points


func _at(xz: Array) -> Vector3:
	return Vector3(float(xz[0]), 0.0, float(xz[1]))


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "BeachGround"
	add_child(body)
	_collider(body, Vector3(0.0, -0.1, -7.0), Vector3(40.0, 0.2, 30.0))  # The floor.
	# Fences: the dunes behind, the ends, the waterline (but not the pier), the pier's sides and end.
	_collider(body, Vector3(0.0, 1.0, SAND_MAX.y + 0.2), Vector3(30.0, 2.0, 0.4))
	_collider(body, Vector3(SAND_MIN.x - 0.2, 1.0, -3.0), Vector3(0.4, 2.0, 16.0))
	_collider(body, Vector3(SAND_MAX.x + 0.2, 1.0, -3.0), Vector3(0.4, 2.0, 16.0))
	var shore_width := SAND_MAX.x - PIER_HALF_WIDTH
	for side in [-1.0, 1.0]:
		_collider(body, Vector3(side * (PIER_HALF_WIDTH + shore_width / 2.0), 1.0, SAND_MIN.y - 0.2), Vector3(shore_width, 2.0, 0.4))
		_collider(body, Vector3(side * (PIER_HALF_WIDTH + 0.2), 1.0, (SAND_MIN.y + PIER_END) / 2.0), Vector3(0.4, 2.0, SAND_MIN.y - PIER_END))
	_collider(body, Vector3(0.0, 1.0, PIER_END - 0.2), Vector3(PIER_HALF_WIDTH * 2.0 + 0.8, 2.0, 0.4))

	var size := SAND_MAX - SAND_MIN
	_box(Vector3((SAND_MIN.x + SAND_MAX.x) / 2.0, -0.05, (SAND_MIN.y + SAND_MAX.y) / 2.0), Vector3(size.x, 0.1, size.y), Color(0.91, 0.82, 0.6))
	_box(Vector3(0.0, -0.045, SAND_MIN.y + 0.6), Vector3(size.x, 0.1, 1.2), Color(0.78, 0.68, 0.48))  # Wet sand.
	_box(Vector3(0.0, -0.06, SAND_MAX.y + 8.0), Vector3(60.0, 0.1, 16.0), Color(0.62, 0.66, 0.38))   # Dune grass behind.
	var sea := _box(Vector3(0.0, WATER_Y, SAND_MIN.y - 40.0), Vector3(120.0, 0.04, 80.0), Color(0.22, 0.5, 0.7, 0.9))
	var sea_material: StandardMaterial3D = sea.mesh.material
	sea_material.roughness = 0.05
	sea_material.metallic = 0.25
	for i in 3:  # Foam where the waves come in.
		var foam := _box(Vector3(_rng.randf_range(-6.0, 6.0), WATER_Y + 0.025, SAND_MIN.y - 0.3 - i * 0.5), Vector3(_rng.randf_range(8.0, 16.0), 0.01, 0.18), Color(0.95, 0.97, 1.0, 0.7))
		foam.name = "Foam%d" % i


func _build_pier() -> void:
	var length := SAND_MIN.y - PIER_END + 0.6
	_box(Vector3(0.0, 0.03, (SAND_MIN.y + 0.6 + PIER_END) / 2.0), Vector3(PIER_HALF_WIDTH * 2.0, 0.06, length), Color(0.6, 0.44, 0.28))
	var z := SAND_MIN.y
	while z > PIER_END:
		for side in [-1.0, 1.0]:
			var post := _cylinder(0.08, 0.9, Color(0.45, 0.32, 0.2))
			post.position = Vector3(side * (PIER_HALF_WIDTH - 0.05), -0.4, z)
		z -= 2.4
	# Fish off the end, and either side.
	for place in [[Vector3(0.0, 0.0, PIER_END + 0.45), 0.0], [Vector3(-0.6, 0.0, -13.6), 90.0], [Vector3(0.6, 0.0, -13.6), -90.0]]:
		var spot := FishingSpot.new()
		spot.name = "FishingSpot"
		spot.habitat = "beach"
		spot.water_y = WATER_Y
		spot.position = place[0]
		spot.rotation_degrees.y = place[1]
		add_child(spot)


func _build_car(settings: Dictionary) -> void:
	var car_settings: Dictionary = GameData.trips.get("car", {})
	var at := _at(settings.get("car_at", [7.0, 1.6]))
	var fit := ModelFit.place(String(car_settings.get("model", "")), self, at, Vector3(0.0, 0.0, float(car_settings.get("length", 3.2))))
	if fit != null:
		fit.rotation.y = PI / 2.0
	car_interactable.radius = 1.6
	car_interactable.position = at + Vector3(0.0, 0.0, 1.2)
	car_interactable.prompt_for_player = func(player_index: int) -> String:
		return "Head home" if car_trip != null and car_trip.can_start(player_index) else ""
	car_interactable.interacted.connect(func(player_index: int):
		if car_trip != null and car_trip.can_start(player_index):
			car_trip.start(player_index, false))
	add_child(car_interactable)

	cheddar = RegularFigure.make("cheddar")
	cheddar.position = _at(settings.get("cheddar_at", [4.6, 0.9]))
	cheddar.rotation.y = deg_to_rad(20.0)
	add_child(cheddar)
	_chat_interactable.radius = 1.2
	_chat_interactable.position = cheddar.position + Vector3(0.0, 0.0, 0.5)
	_chat_interactable.prompt_for_player = func(player_index: int) -> String:
		return "Talk to %s" % GameState.regulars.get("cheddar", {}).get("name", "Cheddar") if car_trip != null and car_trip.can_chat(player_index) else ""
	_chat_interactable.interacted.connect(func(player_index: int):
		if car_trip != null and car_trip.can_chat(player_index):
			car_trip.chat(player_index, cheddar))
	add_child(_chat_interactable)


func _build_campfire(at: Vector3) -> void:
	for i in 6:  # A ring of stones.
		var angle := i * TAU / 6.0
		var stone := _cylinder(0.12, 0.12, Color(0.5, 0.48, 0.45))
		stone.position = at + Vector3(sin(angle) * 0.45, 0.06, cos(angle) * 0.45)
	for i in 3:  # Logs, crossed.
		var wood := _cylinder(0.06, 0.7, Color(0.42, 0.28, 0.16))
		wood.position = at + Vector3(0.0, 0.1, 0.0)
		wood.rotation = Vector3(PI / 2.0, i * PI / 3.0, 0.0)
	_flame = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.22
	mesh.height = 0.55
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.6, 0.2)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.55, 0.15)
	material.emission_energy_multiplier = 3.0
	mesh.material = material
	_flame.mesh = mesh
	_flame.position = at + Vector3(0.0, 0.35, 0.0)
	add_child(_flame)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.7, 0.4)
	_fire_light.omni_range = 9.0
	_fire_light.position = at + Vector3(0.0, 0.9, 0.0)
	add_child(_fire_light)


func _build_umbrella(at: Vector3) -> void:
	var pole := _cylinder(0.035, 2.0, Color(0.9, 0.9, 0.88))
	pole.position = at + Vector3(0.0, 1.0, 0.0)
	pole.rotation.z = 0.12
	var canopy := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 1.2
	mesh.height = 0.45
	mesh.radial_segments = 8
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.45, 0.35)
	mesh.material = material
	canopy.mesh = mesh
	canopy.position = at + Vector3(0.2, 2.0, 0.0)
	canopy.rotation.z = 0.12
	add_child(canopy)
	var towel := _box(at + Vector3(0.6, 0.01, 0.6), Vector3(0.8, 0.02, 1.6), Color(0.35, 0.6, 0.85))
	towel.rotation.y = 0.3


func _collider(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)


func _box(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	node.mesh = mesh
	node.position = at
	add_child(node)
	return node


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
