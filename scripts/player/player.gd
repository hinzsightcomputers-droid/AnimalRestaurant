# Player: moves a capsule around the restaurant.
# Movement logic only. Where the input comes from is the PlayerInput child's job.
class_name Player
extends CharacterBody3D

@export var player_index := 0
@export var move_speed := 4.0
@export var acceleration := 25.0  # How quickly we reach full speed / stop.
@export var turn_speed := 12.0    # How quickly the body turns to face the move direction.

@onready var input: PlayerInput = $PlayerInput
@onready var visual: Node3D = $Visual
@onready var interactor: Interactor = $Interactor


func _ready() -> void:
	input.player_index = player_index


func _physics_process(delta: float) -> void:
	# The camera always looks toward -Z, so "up" on the stick is -Z in the world.
	var input_vector := input.get_move_vector()
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

	if input.is_interact_just_pressed():
		interactor.try_interact(player_index)
