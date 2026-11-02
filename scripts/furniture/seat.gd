# Seat: a chair customers can sit on. Knows which table it belongs to, so a
# messy table keeps its seats from being given to new customers. At night the
# chairs go up on the tables.
class_name Seat
extends Station

const SEAT_HEIGHT := 0.45  # The chair's seat above the floor: upside down, it rests on the table there.

@export var table: DiningTable

var _stack_tween: Tween
var _up := false

@onready var seat_point: Marker3D = $SeatPoint          # Where the customer sits.
@onready var approach_point: Marker3D = $ApproachPoint  # Where they step to before sitting.


func is_put_up() -> bool:
	return _up


func is_table_clean() -> bool:
	return table == null or table.is_clean()


# Where a seated customer's plate goes: in front of the chair, on the table.
func meal_position() -> Vector3:
	return seat_point.global_position + global_basis.z * 0.75


# Up on its table, upside down (night), or back on the floor. `seconds` 0 = at once.
func put_up(up: bool, seconds := 0.6) -> void:
	if table == null:
		return
	_up = up
	var target := Transform3D.IDENTITY
	if up:
		var top := table.global_position + Vector3(0.0, DiningTable.TOP_HEIGHT, 0.0)
		var over_its_side := (global_position - table.global_position) * 0.3
		over_its_side.y = 0.0
		target = Transform3D(Basis(Vector3.RIGHT, PI), to_local(top + over_its_side) + Vector3.UP * SEAT_HEIGHT)
	if _stack_tween != null:
		_stack_tween.kill()
	if seconds <= 0.0:
		visual.transform = target
		return
	_stack_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_stack_tween.tween_property(visual, "transform", target, seconds)


# --- A regular's secret ------------------------------------------------------
# Something a regular hid under this chair (GameState.hidden_secret, set when
# they say a line with "hides"): a coin glints in the seat until a chef with
# free hands looks (data/service.json "secrets").

var _secret_spot: Interactable
var _secret_glint: Node3D


func _ready() -> void:
	super._ready()
	_secret_spot = Interactable.new()
	_secret_spot.name = "SecretSpot"
	_secret_spot.radius = 1.0
	_secret_spot.priority = 2
	_secret_spot.prompt_for_player = _secret_prompt
	_secret_spot.interacted.connect(_find_secret)
	add_child(_secret_spot)
	_secret_spot.position = interactable.position


func _process(_delta: float) -> void:
	var here := _has_secret()
	if here and _secret_glint == null:
		_secret_glint = _make_glint()
	if _secret_glint != null:
		_secret_glint.visible = here


func _has_secret() -> bool:
	var secret := GameState.hidden_secret
	return not secret.is_empty() and secret.get("seat", "") == String(name) and not secret.get("found", false)


func _secret_data() -> Dictionary:
	return GameData.service.get("secrets", {}).get(GameState.hidden_secret.get("item", ""), {})


func _secret_prompt(player_index: int) -> String:
	if not _has_secret() or _occupied():
		return ""
	var player := Player.find(get_tree(), player_index)
	if player == null or player.held_item != null or _leading(player):
		return ""
	return String(_secret_data().get("prompt", "Check the chair"))


func _find_secret(player_index: int) -> void:
	if _secret_prompt(player_index).is_empty():
		return
	var data := _secret_data()
	GameState.hidden_secret["found"] = true
	GameState.hidden_secret["found_by"] = Accounts.id_of(player_index)
	var reward := int(data.get("reward", 0))
	if reward > 0:
		GameState.add_money(reward)
	GameEvents.announce(String(data.get("found", "{chef} found something in the chair!")).format({ "chef": Accounts.name_of(player_index) }))
	_play_bounce()


func _occupied() -> bool:
	return get_tree().get_nodes_in_group(Customer.GROUP).any(func(c): return c.seat == self)


func _leading(player: Player) -> bool:
	return get_tree().get_nodes_in_group(Customer.GROUP).any(func(c): return c.leader == player)


# A gold coin wedged into the seat with a sparkle now and then, on the
# chair's visual so it goes up with it at night.
func _make_glint() -> Node3D:
	var glint := Node3D.new()
	glint.name = "SecretGlint"
	glint.position = Vector3(0.1, SEAT_HEIGHT + 0.03, 0.05)
	visual.add_child(glint)
	var coin := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.07
	mesh.bottom_radius = 0.07
	mesh.height = 0.012
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.8, 0.25)
	gold.metallic = 0.8
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.75, 0.2)
	gold.emission_energy_multiplier = 1.2
	mesh.material = gold
	coin.mesh = mesh
	coin.rotation_degrees = Vector3(70.0, 0.0, 0.0)  # Tipped up, wedged into the back of the seat.
	glint.add_child(coin)
	var sparkle := CPUParticles3D.new()
	sparkle.amount = 6
	sparkle.lifetime = 1.3
	sparkle.direction = Vector3.UP
	sparkle.spread = 60.0
	sparkle.initial_velocity_min = 0.1
	sparkle.initial_velocity_max = 0.35
	sparkle.gravity = Vector3.ZERO
	sparkle.scale_amount_min = 0.6
	sparkle.scale_amount_max = 1.2
	var dot := SphereMesh.new()
	dot.radius = 0.04
	dot.height = 0.08
	var shine := StandardMaterial3D.new()
	shine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shine.albedo_color = Color(1.0, 0.95, 0.6)
	dot.material = shine
	sparkle.mesh = dot
	glint.add_child(sparkle)
	return glint
