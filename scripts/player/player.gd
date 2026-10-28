# Player: moves a capsule around the restaurant and carries one item at a time.
# Movement logic only. Where the input comes from is the PlayerInput child's job.
class_name Player
extends CharacterBody3D

const GROUP := "players"

signal held_item_changed(item: RefCounted)
# Asks this player's camera to zoom in on a point / go back to following.
# Stations and conversations use these so they never touch cameras directly.
signal camera_focus_requested(point: Vector3, settings: CameraZoomSettings)
signal camera_focus_released

@export var player_index := 0
@export var move_speed := 4.0
@export var acceleration := 25.0  # How quickly we reach full speed / stop.
@export var turn_speed := 12.0    # How quickly the body turns to face the move direction.

var movement_locked := false      # True while busy (e.g. cooking).
var has_acted := false            # Becomes true the first time this player moves or interacts.
var held_item: RefCounted = null  # What the player is carrying, e.g. a CookedDish.
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


# `settings` = how close / what angle / how fast (null = the camera's default zoom).
func request_camera_focus(point: Vector3, settings: CameraZoomSettings = null) -> void:
	camera_focus_requested.emit(point, settings)


func release_camera_focus() -> void:
	camera_focus_released.emit()


func set_held_item(item: RefCounted) -> void:
	held_item = item
	held_item_changed.emit(item)


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
	if input.is_interact_just_pressed() and not _interact_blocked:
		has_acted = true
		interactor.try_interact(player_index)


# The press that's down right now (e.g. the one that closed a dialogue box)
# shouldn't also use whatever's in front of us: wait until it's let go.
func ignore_interact_until_released() -> void:
	_interact_blocked = true
