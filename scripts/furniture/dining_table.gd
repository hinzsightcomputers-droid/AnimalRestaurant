# DiningTable: a table that gets dirty after a customer eats (one leftover plate
# per customer). While dirty, players can scrub it (press interact a few times);
# its seats aren't given to new customers until it is clean. The first scrub
# locks that player at the table and zooms their camera in until it is clean.
class_name DiningTable
extends Station

signal cleanliness_changed(table: DiningTable)

@export var scrubs_needed := 3
@export_group("Camera zoom while cleaning")
@export var zoom_look_height := 0.8          # The camera looks at the table top.
@export var camera_zoom: CameraZoomSettings  # Distance, angle and tween time of the zoom-in.

var is_dirty := false
var scrubs_done := 0
var mess_positions: Array[Vector3] = []  # Where each leftover plate sits (world space).
var _cleaner: Player = null              # Who is scrubbing right now.


func _ready() -> void:
	super._ready()
	_update_interactable()


# Called when a customer leaves; `at` is where their plate was.
func make_dirty(at: Vector3) -> void:
	is_dirty = true
	scrubs_done = 0
	mess_positions.append(at)
	_update_interactable()
	cleanliness_changed.emit(self)
	GameEvents.announce("A table needs cleaning.")


func _on_interacted(player_index: int) -> void:
	if not is_dirty:
		return
	if _cleaner != null and _cleaner.player_index != player_index:
		return  # Someone else is already scrubbing this table.
	if _cleaner == null:
		_start_cleaning(player_index)

	scrubs_done += 1
	_play_bounce()
	if scrubs_done >= scrubs_needed:
		is_dirty = false
		mess_positions.clear()
		_finish_cleaning()
		GameEvents.announce("Player %d cleaned the table." % (player_index + 1))
	_update_interactable()
	cleanliness_changed.emit(self)
	used.emit(self, player_index)


func _start_cleaning(player_index: int) -> void:
	_cleaner = Player.find(get_tree(), player_index)
	if _cleaner == null:
		return
	_cleaner.movement_locked = true
	_cleaner.interactor.lock_to(interactable)
	_cleaner.request_camera_focus(global_position + Vector3.UP * zoom_look_height, camera_zoom)


func _finish_cleaning() -> void:
	if _cleaner == null:
		return
	_cleaner.movement_locked = false
	_cleaner.interactor.unlock()
	_cleaner.release_camera_focus()
	_cleaner = null


# Only usable while dirty; the prompt shows scrub progress.
func _update_interactable() -> void:
	interactable.enabled = is_dirty
	if scrubs_done == 0:
		interactable.prompt = "Clean table"
	else:
		interactable.prompt = "Scrub (%d/%d)" % [scrubs_done, scrubs_needed]
