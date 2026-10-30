# Player: moves a capsule around the restaurant and carries one item at a time.
# Movement logic only. Where the input comes from is the PlayerInput child's job.
class_name Player
extends CharacterBody3D

const GROUP := "players"
const OWN_VIEW_LAYER := 11  # Render layers 11-14: each player's own, see hide_from_own_view().

signal held_item_changed(item: RefCounted)
signal tickets_changed
# Asks this player's camera to zoom in on a point / go back to following.
# Stations and conversations use these so they never touch cameras directly.
signal camera_focus_requested(point: Vector3, settings: CameraZoomSettings)
signal camera_focus_released

@export var player_index := 0
@export var move_speed := 4.0
@export var acceleration := 25.0  # How quickly we reach full speed / stop.
@export var turn_speed := 12.0    # How quickly the body turns to face the move direction.

var movement_locked := false      # True while busy (e.g. cooking).
var hidden_from_own_view := false  # In a close-up: their own camera leaves them out.
var has_acted := false            # Becomes true the first time this player moves or interacts.
var held_item: RefCounted = null  # What the player is carrying, e.g. a CookedDish.
var tickets: Array[Order] = []    # Order tickets in their pocket, for the TicketWheel (hands stay free).
var _interact_blocked := false    # See ignore_interact_until_released().

@onready var input: PlayerInput = $PlayerInput
@onready var visual: Node3D = $Visual
@onready var interactor: Interactor = $Interactor


# Finds the player with the given index, or null.
static func find(tree: SceneTree, index: int) -> Player:
	for node in tree.get_nodes_in_group(GROUP):
		if node is Player and node.player_index == index:
			return node
	return null


func _ready() -> void:
	add_to_group(GROUP)
	input.player_index = player_index
	set_collision_mask_value(Customer.BODY_LAYER, true)  # Bump into customers, not through them.


# `settings` = how close / what angle / how fast (null = the camera's default zoom).
func request_camera_focus(point: Vector3, settings: CameraZoomSettings = null) -> void:
	camera_focus_requested.emit(point, settings)


func release_camera_focus() -> void:
	camera_focus_released.emit()


# During a close-up (the oven, pouring a drink) the chef would stand in the way
# of their own camera: hide them from it while it's zoomed in. Everyone else's
# view still shows them. Their meshes get a render layer of their own
# (OWN_VIEW_LAYER + player_index) instead of the usual one, which their
# CameraRig leaves out while zoomed in (every other camera draws all layers).
func hide_from_own_view(hidden: bool) -> void:
	if hidden:
		for node in visual.find_children("*", "VisualInstance3D", true, false):
			var mesh := node as VisualInstance3D
			mesh.set_layer_mask_value(1, false)
			mesh.set_layer_mask_value(own_view_layer(), true)
	hidden_from_own_view = hidden


func own_view_layer() -> int:
	return OWN_VIEW_LAYER + player_index


func set_held_item(item: RefCounted) -> void:
	held_item = item
	held_item_changed.emit(item)


func add_ticket(order: Order) -> void:
	tickets.append(order)
	tickets_changed.emit()


func take_tickets() -> Array[Order]:
	var taken := tickets.duplicate()
	tickets.clear()
	tickets_changed.emit()
	return taken


func drop_ticket(order: Order) -> void:
	if tickets.has(order):
		tickets.erase(order)
		tickets_changed.emit()


# Someone leaving mid-shift doesn't strand their orders: their tickets go on the wheel.
func _exit_tree() -> void:
	var wheel := get_tree().get_first_node_in_group(TicketWheel.GROUP) as TicketWheel
	if wheel != null:
		for order in tickets:
			wheel.clip_now(order)


func _physics_process(delta: float) -> void:
	# The camera always looks toward -Z, so "up" on the stick is -Z in the world.
	var input_vector := Vector2.ZERO if movement_locked else input.get_move_vector()
	var direction := Vector3(input_vector.x, 0.0, input_vector.y)

	var target_velocity := direction * move_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()

	# Turn the visible body (not the collision shape) to face where we are walking.
	if direction.length() > 0.1:
		var target_yaw := atan2(direction.x, direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, turn_speed * delta)

	if input_vector != Vector2.ZERO:
		has_acted = true
	if _interact_blocked and not input.is_interact_pressed():
		_interact_blocked = false
	if input.is_interact_just_pressed() and not _interact_blocked and not in_conversation():
		has_acted = true
		interactor.try_interact(player_index)


# A dialogue box of ours is open: interact moves the conversation on, so it
# mustn't also use the counter, chair or table in front of us.
func in_conversation() -> bool:
	return get_tree().get_nodes_in_group(ConversationBox.GROUP).any(func(box): return box.player_index == player_index and not box.is_queued_for_deletion())


# The press that's down right now (e.g. the one that closed a dialogue box)
# shouldn't also use whatever's in front of us: wait until it's let go.
func ignore_interact_until_released() -> void:
	_interact_blocked = true
