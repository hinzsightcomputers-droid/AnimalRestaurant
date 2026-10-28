# TicketWheel: where order tickets go so the kitchen knows what to make. A
# player with tickets in their pocket (from taking orders at the counter or the
# phone) uses it and zooms in: the wheel spins, and each press clips their next
# ticket onto the clip at the front. A taken clip (or none there yet) just
# clunks: wait for an empty one to come round. Only orders on the wheel get
# ingredients from the freezer. Otherwise the wheel turns slowly so the
# tickets come round, each showing its number and dish and tinted by how far
# along the order is, and a ticket comes off when its order is done.
# Every order needs a clip, so once there's an order for each one (is_full) no
# more can be taken until one is done.
class_name TicketWheel
extends Station

const GROUP := "ticket_wheel"
const STATE_TINTS := {
	Order.State.WAITING: Color(0.99, 0.97, 0.9),
	Order.State.GATHERED: Color(1.0, 0.93, 0.7),
	Order.State.COOKING: Color(1.0, 0.82, 0.6),
	Order.State.READY: Color(0.78, 0.95, 0.72),
}

@export var order_board: OrderBoard
@export var clips := 8
@export var wheel_radius := 0.2              # Keep it (and its tickets) clear of the walls beside it.
@export var wheel_height := 0.42             # The wheel above the counter top.
@export var counter_top := 1.1               # Where it stands.
@export var idle_speed := 0.25               # Radians a second it turns on its own...
@export var clip_speed := 1.5                # ...and while someone is clipping tickets on.
@export var front_window := 0.22             # Radians either side of the front that count as "at the front".
@export_group("Camera zoom while clipping")
@export var zoom_look_offset := Vector3(0.0, 1.42, 0.0)
@export var camera_zoom: CameraZoomSettings

var _wheel := Node3D.new()                   # Turns; the clips and tickets are on it.
var _clip_nodes: Array[Node3D] = []
var _tickets := {}                           # Clip index -> { order, node }.
var _clipper: Player = null
var _queue: Array[Order] = []                # The clipper's tickets still to go on.
var _speed := 0.0
var _marker_material := StandardMaterial3D.new()  # The front marker: green while an empty clip is there.


func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	interactable.prompt_for_player = _prompt_for
	_speed = idle_speed
	_build()
	order_board.changed.connect(_refresh)


func _process(delta: float) -> void:
	var goal := clip_speed if _clipper != null else idle_speed
	_speed = lerpf(_speed, goal, 1.0 - exp(-3.0 * delta))
	_wheel.rotation.y += _speed * delta
	var index := _front_clip()
	var ready := _clipper != null and absf(_front_offset(index)) <= front_window and not _tickets.has(index)
	_marker_material.albedo_color = Color(0.35, 0.9, 0.4) if ready else Color(0.9, 0.3, 0.25)
	_marker_material.emission_enabled = ready


# True when every clip is spoken for: a ticket on it, or one still in someone's
# pocket (every order on the board gets a clip).
static func is_full(tree: SceneTree) -> bool:
	var wheel := tree.get_first_node_in_group(GROUP) as TicketWheel
	return wheel != null and wheel.order_board.orders.size() >= wheel.clips


# "Clip ticket" for someone with tickets (while clipping, the message says what to do).
func _prompt_for(player_index: int) -> String:
	if _clipper != null:
		return ""
	var player := Player.find(get_tree(), player_index)
	if player == null or player.tickets.is_empty():
		return ""
	return "Clip ticket" if player.tickets.size() == 1 else "Clip %d tickets" % player.tickets.size()


func _on_interacted(player_index: int) -> void:
	if _clipper == null:
		_start(player_index)
	elif player_index == _clipper.player_index and not _queue.is_empty():
		_try_clip()


func _start(player_index: int) -> void:
	var player := Player.find(get_tree(), player_index)
	if player == null or player.tickets.is_empty():
		return
	_clipper = player
	_queue = player.take_tickets()
	player.movement_locked = true
	player.interactor.lock_to(interactable)
	player.request_camera_focus(global_position + zoom_look_offset, camera_zoom)
	GameEvents.announce("Press %s when an empty clip comes round to the front." % InputSetup.interact_hint(player_index))
	_play_bounce()
	used.emit(self, player_index)


# The clip nearest the front: on, if it's close enough and empty.
func _try_clip() -> void:
	if _queue.is_empty():
		return  # All on (or back in their pocket): just waiting to let go.
	if _tickets.size() >= clips:  # Nowhere left: the rest go back in their pocket.
		for order in _queue:
			_clipper.add_ticket(order)
		_queue.clear()
		GameEvents.announce("The ticket wheel is full! Finish an order first.")
		_finish()
		return
	var index := _front_clip()
	var off := absf(_front_offset(index))
	if off > front_window or _tickets.has(index):
		_play_sound("clack", _clip_nodes[index].global_position)
		_wobble_wheel()
		return
	var order: Order = _queue.pop_front()
	_hang(order, index, true)
	order_board.clip(order)
	GameEvents.announce("Ticket #%d is on the wheel: %s." % [order.number, order.dish.get("name", "")])
	if _queue.is_empty():
		_finish()


func _finish() -> void:
	await get_tree().create_timer(0.6).timeout
	_clipper.movement_locked = false
	_clipper.interactor.unlock()
	_clipper.release_camera_focus()
	_clipper.ignore_interact_until_released()
	_clipper = null


# On the wheel straight away, no close-up (e.g. the tickets of someone who left).
func clip_now(order: Order) -> void:
	if order.on_wheel or not order_board.orders.has(order):
		return
	for index in clips:
		if not _tickets.has(index):
			_hang(order, index, false)
			break
	order_board.clip(order)  # Even with every clip taken, the kitchen still gets it.


func _hang(order: Order, index: int, animate: bool) -> void:
	var ticket := _make_ticket(order)
	_clip_nodes[index].add_child(ticket)
	_tickets[index] = { "order": order, "node": ticket }
	if animate:  # Flies in from in front, and snaps on.
		ticket.position = Vector3(0.0, -0.12, 0.35)
		ticket.scale = Vector3.ONE * 1.6
		var tween := ticket.create_tween().set_parallel(true)
		tween.tween_property(ticket, "position", Vector3.ZERO, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ticket, "scale", Vector3.ONE, 0.18)
		tween.chain().tween_callback(func():
			_play_sound("tick", ticket.global_position, 0.0, 0.7)
			_play_sound("plop", ticket.global_position, -6.0, 1.6))


# Tickets of finished orders come off; the rest show how far along they are.
func _refresh() -> void:
	for index in _tickets.keys():
		var entry: Dictionary = _tickets[index]
		var order: Order = entry["order"]
		if not order_board.orders.has(order):
			entry["node"].queue_free()
			_tickets.erase(index)
			continue
		var paper: MeshInstance3D = entry["node"].get_node("Paper")
		paper.material_override.albedo_color = STATE_TINTS[order.state]


func _front_clip() -> int:
	var best := 0
	for index in clips:
		if absf(_front_offset(index)) < absf(_front_offset(best)):
			best = index
	return best


# How far round from the front (facing the camera, +z) a clip is, in radians.
func _front_offset(index: int) -> float:
	return wrapf(-index * TAU / clips + _wheel.rotation.y, -PI, PI)


func _wobble_wheel() -> void:
	var tween := _wheel.create_tween()
	tween.tween_property(_wheel, "position:y", _wheel.position.y - 0.01, 0.05)
	tween.tween_property(_wheel, "position:y", counter_top + wheel_height, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_sound(sound: String, at: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = CookSounds.get_sound(sound)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	add_child(player)
	player.global_position = at
	player.play()
	player.finished.connect(player.queue_free)


# A post on the counter, a wheel on top with clips round its rim.
func _build() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.75, 0.77, 0.8)
	metal.metallic = 0.8
	metal.roughness = 0.3
	_mesh_on(visual, _cylinder(0.08, 0.02, metal), Vector3(0.0, counter_top + 0.01, 0.0))
	_mesh_on(visual, _cylinder(0.012, wheel_height, metal), Vector3(0.0, counter_top + wheel_height * 0.5, 0.0))
	_wheel.position.y = counter_top + wheel_height
	# A little tab under the front of the rim (it doesn't turn): where tickets clip on.
	_marker_material.emission = Color(0.2, 0.8, 0.3)
	var marker := _mesh_on(visual, _box(Vector3(0.03, 0.012, 0.03), _marker_material), Vector3(0.0, counter_top + wheel_height - 0.03, wheel_radius + 0.012))
	marker.rotation.y = PI * 0.25
	visual.add_child(_wheel)
	var ring := TorusMesh.new()
	ring.inner_radius = wheel_radius - 0.008
	ring.outer_radius = wheel_radius
	ring.material = metal
	_mesh_on(_wheel, ring, Vector3.ZERO)
	_mesh_on(_wheel, _cylinder(0.035, 0.03, metal), Vector3.ZERO)  # Hub.
	for i in 4:
		var spoke := _mesh_on(_wheel, _box(Vector3(wheel_radius * 2.0, 0.008, 0.008), metal), Vector3.ZERO)
		spoke.rotation.y = i * PI / 4.0
	var clip_material := StandardMaterial3D.new()
	clip_material.albedo_color = Color(0.25, 0.27, 0.3)
	clip_material.metallic = 0.6
	for index in clips:
		var angle := -index * TAU / clips  # Clip i is at the front when the wheel has turned i steps.
		var clip := Node3D.new()
		clip.position = Vector3(sin(angle), 0.0, cos(angle)) * wheel_radius
		clip.rotation.y = angle  # Facing outward.
		_mesh_on(clip, _box(Vector3(0.035, 0.025, 0.012), clip_material), Vector3(0.0, -0.01, 0.006))
		_wheel.add_child(clip)
		_clip_nodes.append(clip)


# A ticket hanging from its clip, facing out: number and dish on the front.
func _make_ticket(order: Order) -> Node3D:
	var ticket := Node3D.new()
	var paper := MeshInstance3D.new()
	paper.name = "Paper"
	paper.mesh = _box(Vector3(0.1, 0.13, 0.002), null)
	var material := StandardMaterial3D.new()
	material.albedo_color = STATE_TINTS[order.state]
	material.roughness = 0.9
	paper.material_override = material
	paper.position = Vector3(0.0, -0.075, 0.008)
	ticket.add_child(paper)
	var words := Label3D.new()
	words.text = "#%d\n%s" % [order.number, String(order.dish.get("name", "")).replace(" ", "\n")]  # A word a line.
	words.font_size = 32
	words.pixel_size = 0.0007
	words.modulate = TicketPopup.INK
	words.outline_size = 0
	words.position = Vector3(0.0, -0.075, 0.0102)
	ticket.add_child(words)
	return ticket


func _mesh_on(parent: Node3D, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	parent.add_child(instance)
	return instance


func _cylinder(radius: float, height: float, material: Material) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.material = material
	return mesh


func _box(box_size: Vector3, material: Material) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	return mesh
