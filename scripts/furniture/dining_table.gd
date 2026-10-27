# DiningTable: a table that gets dirty after a customer eats (one leftover plate
# per customer). While dirty, players can scrub it (press interact a few times);
# its seats aren't given to new customers until it is clean.
class_name DiningTable
extends Station

signal cleanliness_changed(table: DiningTable)

@export var scrubs_needed := 3

var is_dirty := false
var scrubs_done := 0
var mess_positions: Array[Vector3] = []  # Where each leftover plate sits (world space).


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

	scrubs_done += 1
	_play_bounce()
	if scrubs_done >= scrubs_needed:
		is_dirty = false
		mess_positions.clear()
		GameEvents.announce("Player %d cleaned the table." % (player_index + 1))
	_update_interactable()
	cleanliness_changed.emit(self)
	used.emit(self, player_index)


# Only usable while dirty; the prompt shows scrub progress.
func _update_interactable() -> void:
	interactable.enabled = is_dirty
	if scrubs_done == 0:
		interactable.prompt = "Clean table"
	else:
		interactable.prompt = "Scrub (%d/%d)" % [scrubs_done, scrubs_needed]
