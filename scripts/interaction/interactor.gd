# Interactor: lives on a player and keeps track of the closest Interactable in range.
# The player tells it when to interact; it never reads input itself.
class_name Interactor
extends Node3D

signal focus_changed(interactable: Interactable)

var focused: Interactable = null


func _physics_process(_delta: float) -> void:
	var best: Interactable = null
	var best_distance := INF

	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var interactable := node as Interactable
		if interactable == null or not interactable.enabled:
			continue
		var distance := _flat_distance(global_position, interactable.global_position)
		if distance <= interactable.radius and distance < best_distance:
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
