# Interactor: lives on a player and keeps track of the best Interactable in range
# (highest priority, then closest). The player tells it when to interact; it never reads input itself.
class_name Interactor
extends Node3D

signal focus_changed(interactable: Interactable)

var focused: Interactable = null
var locked_to: Interactable = null  # While set (e.g. mid-scrub), always use this one.


# Stick to one interactable until unlock(), so a busy player's presses can't
# drift to something else nearby.
func lock_to(interactable: Interactable) -> void:
	locked_to = interactable


func unlock() -> void:
	locked_to = null


func _physics_process(_delta: float) -> void:
	if locked_to != null:
		if focused != locked_to:
			focused = locked_to
			focus_changed.emit(focused)
		return

	var best: Interactable = null
	var best_distance := INF

	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var interactable := node as Interactable
		if interactable == null or not interactable.enabled:
			continue
		var distance := _flat_distance(global_position, interactable.global_position)
		if distance > interactable.radius:
			continue
		var better_priority := best == null or interactable.priority > best.priority
		var same_priority_but_closer := best != null and interactable.priority == best.priority and distance < best_distance
		if better_priority or same_priority_but_closer:
			best = interactable
			best_distance = distance

	if best != focused:
		focused = best
		focus_changed.emit(focused)


func try_interact(player_index: int) -> void:
	if focused != null:
		focused.interact(player_index)


# Distance on the floor plane, so height differences don't matter.
func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
