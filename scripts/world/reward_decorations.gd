# RewardDecorations: what big moment rewards look like in the restaurant (see
# data/scenes.json). Each shows once it's unlocked, and goes again if the debug
# panel clears them:
#   - Cheddar's "World's Best Chef" sign, on the kitchen wall above the stove.
#   - Mabel's brass bell, on a bracket over the front door. It swings and rings
#     whenever a customer comes in (bell_sound in data/scenes.json, or a
#     built-in chime until there's a real sound).
#   - Zakk's driftwood board, high on the dining room's back wall.
# (The patchwork apron is a wardrobe item, data/wardrobe/patchwork_apron.json. Walter's Storm Soup
# goes on the menu: see GameData.menu.)
class_name RewardDecorations
extends Node3D

const SIGN_REWARD := "best_chef_sign"
const BELL_REWARD := "mabel_bell"
const BOARD_REWARD := "driftwood_board"
const SWING_DEGREES := 22.0

@export var customer_manager: CustomerManager  # Its customers ring the bell coming in.
@export var sign_spot: Marker3D                # Where the sign hangs.
@export var bell_spot: Marker3D                # Where the bell hangs (just inside the door).
@export var board_spot: Marker3D               # Where Zakk's board hangs.

var _sign: Node3D
var _bell: Node3D
var _bell_swing: Node3D
var _board: Node3D
var _chime := AudioStreamPlayer3D.new()
var _outside: Dictionary = {}  # Customer -> true while they're still outside the door.
var _swing_time := -1.0        # Seconds since the bell was rung (-1 = still).


func _ready() -> void:
	_sign = _build_sign()
	_bell = _build_bell()
	_board = _build_board()
	_chime.stream = chime_stream()
	_chime.unit_size = 12.0
	_bell_swing.add_child(_chime)
	GameState.unlocks_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_sign.visible = SIGN_REWARD in GameState.unlocks
	_bell.visible = BELL_REWARD in GameState.unlocks
	_board.visible = BOARD_REWARD in GameState.unlocks


func ring() -> void:
	_swing_time = 0.0
	_chime.play()


func _process(delta: float) -> void:
	_watch_the_door()
	if _swing_time >= 0.0:  # A swing that settles over a couple of seconds.
		_swing_time += delta
		var settle := exp(-_swing_time * 1.6)
		_bell_swing.rotation.x = deg_to_rad(SWING_DEGREES * sin(_swing_time * 9.0) * settle)
		if settle < 0.02:
			_swing_time = -1.0
			_bell_swing.rotation.x = 0.0


# A customer stepping in past the doorway rings it (couriers don't count).
func _watch_the_door() -> void:
	if not _bell.visible or customer_manager == null:
		return
	var door_z := bell_spot.global_position.z
	for child in customer_manager.get_children():
		var customer := child as Customer
		if customer == null or customer.state == Customer.State.LEAVING:
			continue
		var outside := customer.global_position.z > door_z
		if _outside.get(customer, false) and not outside:
			ring()
		_outside[customer] = outside
	for customer in _outside.keys():
		if not is_instance_valid(customer):
			_outside.erase(customer)


# A wooden board with the sign's words (from its reward name).
func _build_sign() -> Node3D:
	var sign := Node3D.new()
	sign_spot.add_child(sign)
	var board := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(1.9, 0.5, 0.05)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.72, 0.52, 0.32)
	board_mesh.material = wood
	board.mesh = board_mesh
	sign.add_child(board)
	var label := Label3D.new()
	label.text = "World's Best Chef\n(don't tell anyone I said that)"
	label.font_size = 40
	label.pixel_size = 0.0034
	label.outline_size = 0
	label.modulate = Color(0.25, 0.14, 0.08)
	label.position.z = 0.03
	sign.add_child(label)
	return sign


# A battered, sun-bleached surfboard shape, hung lengthwise and a little crooked.
func _build_board() -> Node3D:
	var board := Node3D.new()
	board_spot.add_child(board)
	board.rotation.z = deg_to_rad(84.0)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.79, 0.71, 0.58)
	wood.roughness = 0.95
	var plank := MeshInstance3D.new()
	var plank_mesh := CapsuleMesh.new()
	plank_mesh.radius = 0.2
	plank_mesh.height = 1.5
	plank_mesh.material = wood
	plank.mesh = plank_mesh
	plank.scale.z = 0.12
	board.add_child(plank)
	var grain := StandardMaterial3D.new()
	grain.albedo_color = Color(0.58, 0.48, 0.36)
	for x in [-0.08, 0.05, 0.11]:  # Weathered lines down its length.
		var line := MeshInstance3D.new()
		var line_mesh := BoxMesh.new()
		line_mesh.size = Vector3(0.012, 1.0 + x, 0.01)
		line_mesh.material = grain
		line.mesh = line_mesh
		line.position = Vector3(x, x * 0.4, 0.026)
		board.add_child(line)
	return board


# A bracket from the wall over the door, with the brass bell hanging from it.
func _build_bell() -> Node3D:
	var bell := Node3D.new()
	bell_spot.add_child(bell)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.2, 0.2, 0.22)
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.08, 2.6, 0.08)
	post_mesh.material = iron
	post.mesh = post_mesh
	post.position = Vector3(0.85, 1.3, 0.0)  # Beside the doorway.
	bell.add_child(post)
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.9, 0.06, 0.06)
	arm_mesh.material = iron
	arm.mesh = arm_mesh
	arm.position = Vector3(0.42, 2.57, 0.0)
	bell.add_child(arm)

	_bell_swing = Node3D.new()  # Pivots where the bell hangs from the arm.
	_bell_swing.position = Vector3(0.0, 2.54, 0.0)
	bell.add_child(_bell_swing)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.85, 0.66, 0.25)
	brass.metallic = 0.6
	brass.roughness = 0.35
	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.07
	body_mesh.bottom_radius = 0.17
	body_mesh.height = 0.24
	body_mesh.material = brass
	body.mesh = body_mesh
	body.position.y = -0.17
	_bell_swing.add_child(body)
	var cap := MeshInstance3D.new()
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.07
	cap_mesh.height = 0.1
	cap_mesh.material = brass
	cap.mesh = cap_mesh
	cap.position.y = -0.05
	_bell_swing.add_child(cap)
	return bell


# bell_sound from data/scenes.json, or a placeholder: a bright little chime
# (a few bell-like partials that ring out).
static func chime_stream() -> AudioStream:
	var path: String = GameData.scene_settings.get("bell_sound", "")
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path)
	var rate := 22050
	var total := int(rate * 1.6)
	var data := PackedByteArray()
	data.resize(total * 2)
	var partials := [[1320.0, 1.0], [2640.0, 0.45], [3560.0, 0.25], [1985.0, 0.2]]
	for i in total:
		var t := float(i) / rate
		var value := 0.0
		for partial in partials:
			value += sin(TAU * partial[0] * t) * partial[1] * exp(-t * (2.5 + partial[0] / 1500.0))
		value *= minf(1.0, t * 400.0) * 0.28  # A soft strike, no click.
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
