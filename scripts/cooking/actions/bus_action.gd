# BusAction: clear a table into a dish bin. The dirty dishes (the session's
# context "dishes": [{ at, model }]) sit on the table; hold the button on one,
# carry it over the bin and let go to drop it in. Passing over another on the
# way picks it up too, in a stack. Let go anywhere else and they go back where
# they were. Done when they're all in.
class_name BusAction
extends CookAction

@export var bin_surface := "Bin"           # Its DishBinModel child, "Bin", is what they go in.
@export var dish_size := 0.36              # How wide the dishes are on the table.
@export var carry_height := 0.14
@export var grab_margin := 0.03
@export var stack_gap := 0.04

var _dishes: Array[Node3D] = []            # Still on the table.
var _homes := {}                           # Dish -> where it sat.
var _carrying: Array[Node3D] = []          # Stacked, bottom first.
var _landing := 0


func _begin() -> void:
	for entry in session.context.get("dishes", []):
		var dish := ModelFit.place(entry["model"], session, entry["at"], Vector3(dish_size, 0.0, dish_size))
		if dish == null:
			continue
		dish.rotation.y = randf() * TAU
		_dishes.append(dish)
		_homes[dish] = entry["at"]


func update(delta: float, input: CookInput) -> void:
	var spot := input.cursor
	for i in _carrying.size():
		var goal := Vector3(spot.x, carry_height + stack_gap * i, spot.z)
		_carrying[i].position = _carrying[i].position.lerp(goal, 1.0 - exp(-18.0 * delta))
	if not _carrying.is_empty() and not input.held:
		for dish in _carrying:
			_drop(dish, spot)
		_carrying.clear()
	elif input.just_pressed or not _carrying.is_empty():
		var dish := _dish_at(spot)
		if dish != null:
			_carrying.append(dish)
			_dishes.erase(dish)
			session.play_sound("clack", dish.position, -6.0, 1.5 + 0.1 * _carrying.size())
			session.wobble(dish, 0.1)
	session.set_status("Dishes left: %d" % (_dishes.size() + _carrying.size()))
	if _dishes.is_empty() and _carrying.is_empty() and _landing == 0:
		finish(1.0)


func _drop(dish: Node3D, spot: Vector3) -> void:
	_landing += 1
	var bin_at := session.surface(bin_surface)
	var tween := dish.create_tween()
	if bin_at.contains(spot, 0.05):
		var bin: DishBinModel = bin_at.get_node("Bin")
		tween.tween_property(dish, "position", bin_at.transform * bin.next_spot(), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(dish, "scale", Vector3.ONE * DishBinModel.DISH_SIZE / dish_size, 0.16)
		tween.tween_callback(func():
			_landing -= 1
			bin.add(dish)
			session.play_sound("clack", dish.global_position, -2.0, 1.9)
			session.wobble(bin, 0.08))
	else:
		tween.tween_property(dish, "position", _homes[dish], 0.2).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(func():
			_landing -= 1
			_dishes.append(dish))
		session.pop_text("Into the bin!", spot, 0)


func _dish_at(spot: Vector3) -> Node3D:
	var best: Node3D = null
	var best_gap := INF
	for dish in _dishes:
		var gap := Vector2(dish.position.x - spot.x, dish.position.z - spot.z).length()
		if gap <= dish_size * 0.5 + grab_margin and gap < best_gap:
			best = dish
			best_gap = gap
	return best


# For a reel: each dish in turn, carried over the bin and let go.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if not _carrying.is_empty():
		return not input.move_to(session.surface(bin_surface).position, delta, 0.9)
	if _dishes.is_empty():
		return false
	return input.move_to(_dishes[0].position, delta, 1.0) and not input.held
