# ReelCamera: frames a reel for a tall 9:16 video. It takes over the chef's
# CameraRig (which stops moving by itself) and moves between a few shots: the
# whole room, following the regular, close on their table for a conversation,
# and a wider one of the table for the chef arriving. glide_to eases over, cut_to
# jumps. Reels only.
class_name ReelCamera
extends Node

enum Shot { WIDE, FOLLOW, TABLE, SERVE, CAR, BEACH, STROLL, FISHING, CATCH }

const FOV := 42.0
const GLIDE_SPEED := 2.5     # Higher = gets to the next shot sooner.
const UI_SCALE := 2.0        # The dialogue box and replies, big enough to read on a phone.
const WIDE_POSITION := Vector3(2.6, 14.0, 15.5)  # The room from over the front, door included.
const WIDE_LOOK := Vector3(2.6, 0.0, 1.2)
const FOLLOW_OFFSET := Vector3(0.0, 4.0, 6.0)
const FOLLOW_LOOK_HEIGHT := 0.4
const TABLE_DISTANCE := 4.2  # In front of the regular, across their table.
const TABLE_HEIGHT := 1.9
const TABLE_SIDE := 0.45     # Toward the chef's side, so both faces show.
const TABLE_LOOK_DOWN := 0.65  # Looks below them, which puts them above the dialogue box.
const SERVE_DISTANCE := 3.8
const SERVE_HEIGHT := 2.6
const SERVE_SIDE := 2.9
const SERVE_LOOK_ACROSS := 0.3  # Toward the table, so the plate's in the shot.
const CAR_POSITION := Vector3(-1.6, 2.8, 5.2)  # Cheddar's car out front, across the corner of the restaurant.
const CAR_LOOK := Vector3(-6.8, 0.5, 10.8)
const BEACH_OFFSET := Vector3(-0.5, 2.2, 7.5)  # Behind the chef as they look out to sea.
const BEACH_LOOK := Vector3(-0.5, 1.2, -4.0)
const STROLL_OFFSET := Vector3(3.5, 4.0, 7.0)   # Along with the chef on the sand, from up the beach and clear of the umbrella.
const STROLL_LOOK := Vector3(0.0, 0.5, -2.0)
const FISHING_OFFSET := Vector3(3.6, 4.5, 3.4)  # Up and off to the side of the chef, or they stand right in front of the bobber.
const FISHING_LOOK := Vector3(-0.2, 0.2, -1.5)
const CATCH_OFFSET := Vector3(0.3, 1.25, 2.6)   # In front of them, once they've turned round with the fish.
const CATCH_LOOK := Vector3(0.15, 0.85, 0.0)

var view: PlayerView
var subject: Customer  # The regular.
var chef: Player
var spot: FishingSpot  # Where the chef's fishing.

var _shot := Shot.WIDE
var _position := WIDE_POSITION
var _look := WIDE_LOOK


func _ready() -> void:
	view.rig.set_process(false)
	view.rig.camera.fov = FOV


func glide_to(shot: Shot) -> void:
	_shot = shot


func cut_to(shot: Shot) -> void:
	_shot = shot
	var goal := _goal()
	_position = goal[0]
	_look = goal[1]


func _process(delta: float) -> void:
	view.set_ui_scale(UI_SCALE)
	var goal := _goal()
	var weight := 1.0 - exp(-GLIDE_SPEED * delta)
	_position = _position.lerp(goal[0], weight)
	_look = _look.lerp(goal[1], weight)
	view.rig.camera.look_at_from_position(_position, _look)


# [where the camera goes, what it looks at] for the current shot.
func _goal() -> Array:
	match _shot:
		Shot.FOLLOW:
			return [subject.global_position + FOLLOW_OFFSET, subject.global_position + Vector3.UP * FOLLOW_LOOK_HEIGHT]
		Shot.TABLE:
			return _at_table(TABLE_DISTANCE, TABLE_HEIGHT, TABLE_SIDE, 0.0)
		Shot.SERVE:
			return _at_table(SERVE_DISTANCE, SERVE_HEIGHT, SERVE_SIDE, SERVE_LOOK_ACROSS)
		Shot.CAR:
			return [CAR_POSITION, CAR_LOOK]
		Shot.BEACH:
			return [chef.global_position + BEACH_OFFSET, chef.global_position + BEACH_LOOK]
		Shot.STROLL:
			return [chef.global_position + STROLL_OFFSET, chef.global_position + STROLL_LOOK]
		Shot.FISHING:
			return [spot.to_global(FISHING_OFFSET), spot.to_global(FISHING_LOOK)]
		Shot.CATCH:
			return [spot.to_global(CATCH_OFFSET), spot.to_global(CATCH_LOOK)]
	return [WIDE_POSITION, WIDE_LOOK]


# From in front of the regular, moved `side` toward the chef's side of them.
func _at_table(distance: float, height: float, side: float, look_across: float) -> Array:
	var seat := subject.global_position
	var face := subject.global_basis.z
	face.y = 0.0
	face = face.normalized()
	var toward_chef := ReelDirector.BESIDE_CUSTOMER.normalized()
	var spot := seat + face * distance + toward_chef * side
	spot.y = height
	var look := seat + toward_chef * 0.45 + face * look_across
	look.y = seat.y + 0.9 - TABLE_LOOK_DOWN
	return [spot, look]
