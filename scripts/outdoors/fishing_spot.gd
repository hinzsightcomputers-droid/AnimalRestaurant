# FishingSpot: a place on a bank to fish from, facing the water along its -z.
# After hours a chef with free hands gets "Fish" here: they step onto the spot,
# their camera zooms in from behind them, and a CookSession runs the fishing
# close-up (data/recipes/fishing.tres: CastAction, BiteAction, ReelAction)
# with a rod, a line and a bobber. A catch goes to the pantry and the Fish
# Log (Fishing.record_catch). One chef per spot; fish as often as you like.
class_name FishingSpot
extends Node3D

const RECIPE := "res://data/recipes/fishing.tres"
const RESULT_SHOW_TIME := 1.8
const ROD_GRIP := Vector3(0.22, 0.8, -0.1)     # Where the rod is held, from the spot.
const ROD_TIP := Vector3(0.0, 0.55, -1.35)      # The tip, from the grip.

@export var habitat := "pond"
@export var water_y := -0.03                   # The water's surface, from the spot.

var session: CookSession = null
var _fisher: Player = null
var _interactable := Interactable.new()
var _line: Node3D = null
var _zoom := CameraZoomSettings.new()


func _ready() -> void:
	_interactable.prompt = "Fish"
	_interactable.radius = 1.0
	_interactable.prompt_for_player = _prompt_for
	_interactable.interacted.connect(_on_interacted)
	add_child(_interactable)
	_zoom.distance = 3.6
	_zoom.pitch_degrees = 36.0
	_zoom.duration = 0.5


# "Fish" after hours for a chef with free hands, while nobody's fishing here.
func _prompt_for(player_index: int) -> String:
	if session != null or not DayCycle.doors_open():
		return ""
	var player := Player.find(get_tree(), player_index)
	return _interactable.prompt if player != null and player.held_item == null else ""


func _on_interacted(player_index: int) -> void:
	if not _prompt_for(player_index).is_empty():
		_start(Player.find(get_tree(), player_index))


func _start(player: Player) -> void:
	_fisher = player
	session = CookSession.new()
	session.bounds = Rect2(-1.2, -3.2, 2.4, 2.9)
	session.work_height = water_y
	add_child(session)
	var rod := _make_rod()
	var bobber := _make_bobber()
	bobber.position = rod.position + ROD_TIP
	_line = _make_line()
	session.context = { "rod": rod, "rod_tip": ROD_TIP, "bobber": bobber, "water_y": water_y, "habitat": habitat }

	# Step up to the water's edge, facing it.
	player.global_position = Vector3(global_position.x, player.global_position.y, global_position.z)
	var facing := -global_basis.z
	player.visual.rotation.y = atan2(facing.x, facing.z)
	player.movement_locked = true
	player.interactor.lock_to(_interactable)
	var zoom: CameraZoomSettings = _zoom.duplicate()
	zoom.yaw_degrees = rad_to_deg(global_rotation.y)  # From behind the fisher.
	player.request_camera_focus(global_transform * Vector3(0.0, 0.0, -1.7), zoom)
	player.hide_from_own_view(true)
	session.finished.connect(_on_finished)
	session.start(load(RECIPE), player, get_tree().root.find_children("*", "ViewManager", true, false).front())


func _process(_delta: float) -> void:
	if session == null or _line == null:
		return
	var rod: Node3D = session.context["rod"]
	var bobber: Node3D = session.context["bobber"]
	var from := rod.global_transform * ROD_TIP
	var to := bobber.global_position + Vector3(0.0, 0.03, 0.0)
	_line.visible = bobber.visible and from.distance_to(to) > 0.01
	if _line.visible:
		_line.global_position = from
		_line.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
		_line.scale = Vector3(1.0, 1.0, from.distance_to(to))


func _on_finished(_quality: float) -> void:
	await get_tree().create_timer(RESULT_SHOW_TIME).timeout
	var caught: Dictionary = session.context.get("catch", {})
	if not caught.is_empty():
		Fishing.record_catch(caught["id"], caught["size"], _fisher.player_index)
	session.queue_free()
	session = null
	_line = null
	_fisher.movement_locked = false
	_fisher.interactor.unlock()
	_fisher.release_camera_focus()
	_fisher.hide_from_own_view(false)
	_fisher.ignore_interact_until_released()
	_fisher = null


# A rod from the grip out to the tip, in the session (gone with it).
func _make_rod() -> Node3D:
	var rod := Node3D.new()
	rod.position = ROD_GRIP
	session.add_child(rod)
	var pole := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.006
	mesh.bottom_radius = 0.016
	mesh.height = ROD_TIP.length()
	mesh.material = _material(Color(0.45, 0.3, 0.18))
	pole.mesh = mesh
	# The cylinder stands along y: lay it along the grip-to-tip line, thin end at the tip.
	pole.basis = Basis(Quaternion(Vector3.UP, ROD_TIP.normalized()))
	pole.position = ROD_TIP / 2.0
	rod.add_child(pole)
	var reel := MeshInstance3D.new()
	var reel_mesh := CylinderMesh.new()
	reel_mesh.top_radius = 0.035
	reel_mesh.bottom_radius = 0.035
	reel_mesh.height = 0.03
	reel_mesh.material = _material(Color(0.7, 0.72, 0.75))
	reel.mesh = reel_mesh
	reel.rotation.z = PI / 2.0
	reel.position = ROD_TIP * 0.12 + Vector3(0.0, -0.04, 0.0)
	rod.add_child(reel)
	return rod


# Red on top, white underneath.
func _make_bobber() -> Node3D:
	var bobber := Node3D.new()
	session.add_child(bobber)
	for half in [[Color(0.9, 0.15, 0.12), 0.02], [Color(0.97, 0.97, 0.95), -0.02]]:
		var ball := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.06
		mesh.height = 0.08
		mesh.material = _material(half[0])
		ball.mesh = mesh
		ball.position.y = half[1]
		bobber.add_child(ball)
	return bobber


# A thin line one meter along -z; _process stretches it from the tip to the bobber.
func _make_line() -> Node3D:
	var line := Node3D.new()
	session.add_child(line)
	var thread := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0025
	mesh.bottom_radius = 0.0025
	mesh.height = 1.0
	mesh.material = _material(Color(0.95, 0.95, 0.9))
	thread.mesh = mesh
	thread.rotation.x = PI / 2.0
	thread.position.z = -0.5
	line.add_child(thread)
	return line


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	return material
