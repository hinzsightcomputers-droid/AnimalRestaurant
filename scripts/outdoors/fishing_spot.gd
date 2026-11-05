# FishingSpot: a place on a bank to fish from, facing the water along its -z.
# After hours a chef with free hands gets "Fish" here: they step onto the spot,
# their camera zooms in from behind them, and a CookSession runs the fishing
# close-up (data/recipes/fishing.tres: CastAction, BiteAction, ReelAction)
# with a rod, a line and a bobber. A catch goes to the pantry and the Fish
# Log (Fishing.record_catch). One chef per spot; fish as often as you like.
class_name FishingSpot
extends Node3D

signal catch_held  # The chef's turned round and is holding it up.

const RECIPE := "res://data/recipes/fishing.tres"
const REEL_TEXT_SIZE := 0.005                   # Words over the water, big enough for a reel's wider shot.
const RESULT_SHOW_TIME := 1.8
const ROD_GRIP := Vector3(0.22, 0.8, -0.1)     # Where the rod is held, from the spot.
const ROD_TIP := Vector3(0.0, 0.55, -1.35)      # The tip, from the grip.
const SHOW_OFF_DELAY := 0.9                     # Seconds after the catch before the chef holds it up...
const SHOW_OFF_SECONDS := 2.4                   # ...and how long they do.
const HOLD_UP := Vector3(0.3, 1.05, 0.3)        # Where the line's held: up by their hand, the fish hanging beside them.
const LINE_DROP := 0.08                         # How much line between their hands and the fish.

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


# A reel's chef fishes here by themselves, seen by the reel's own camera with the rod in their hands.
func reel_start(player: Player) -> void:
	_start(player)
	session.input.scripted = true
	session.text_size = REEL_TEXT_SIZE
	(player.visual.get_node("Chef") as ChefModel).carrying = true


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
	var caught: Dictionary = session.context.get("catch", {})
	if caught.is_empty():
		await get_tree().create_timer(RESULT_SHOW_TIME).timeout
	else:
		await _show_off(caught)
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


# Once the catch is out of the water, the chef turns round and holds it up for
# their camera, which comes in on them from the front.
func _show_off(caught: Dictionary) -> void:
	await get_tree().create_timer(SHOW_OFF_DELAY).timeout  # Out of the water it leaps first.
	session.visible = false
	var player := _fisher
	player.hide_from_own_view(false)
	player.visual.rotation.y += PI
	var chef := player.visual.get_node_or_null("Chef") as ChefModel
	if chef != null:
		chef.carrying = true  # Arms out, holding it up.
	var length := clampf(caught["size"] / 100.0 * 2.0, 0.5, 0.9)  # Bigger than life, for the photo.
	var held := Node3D.new()  # The line in their hands, the fish hanging off it nose up.
	held.position = HOLD_UP
	player.visual.add_child(held)
	var line := MeshInstance3D.new()
	var line_mesh := CylinderMesh.new()
	line_mesh.top_radius = 0.004
	line_mesh.bottom_radius = 0.004
	line_mesh.height = LINE_DROP
	line_mesh.material = _material(Color(0.95, 0.95, 0.9))
	line.mesh = line_mesh
	line.position.y = -LINE_DROP / 2.0
	held.add_child(line)
	var fish := Fishing.make_model(GameData.get_fish(caught["id"]), length)
	# Nose up (it points along -z), then turned so its side faces the camera.
	fish.basis = Basis(Vector3.UP, PI / 2.0) * Basis(Vector3.RIGHT, PI / 2.0)
	fish.position.y = -LINE_DROP - length * 0.45
	held.add_child(fish)
	var zoom: CameraZoomSettings = _zoom.duplicate()
	zoom.distance = 2.4
	zoom.pitch_degrees = 14.0
	zoom.yaw_degrees = rad_to_deg(global_rotation.y)  # Where it was, behind them: now in front.
	player.request_camera_focus(player.global_position + Vector3(0.0, 0.9, 0.0), zoom)
	catch_held.emit()
	var swing := held.create_tween()  # It swings on the line, slowing down.
	for i in 4:
		var angle := 0.35 * pow(0.55, i)
		swing.tween_property(held, "rotation:z", angle if i % 2 == 0 else -angle, 0.32).set_trans(Tween.TRANS_SINE)
	swing.tween_property(held, "rotation:z", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(SHOW_OFF_SECONDS).timeout
	held.queue_free()
	if chef != null:
		chef.carrying = player.held_item != null


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
