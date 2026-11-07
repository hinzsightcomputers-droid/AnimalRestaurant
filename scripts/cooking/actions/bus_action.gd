# BusAction: clear a table into a dish bin. The dirty dishes (the session's
# context "dishes": [{ at, model }]) sit on the table; hold the button on one,
# carry it over the bin and let go to drop it in. Let go anywhere else and it
# goes back where it was. Done when they're all in.
class_name BusAction
extends CookAction

@export var bin_surface := "Bin"           # Its DishBinModel child, "Bin", is what they go in.
@export var dish_size := 0.36              # How wide the dishes are on the table.
@export var carry_height := 0.14
@export var grab_margin := 0.03

var _dishes: Array[Node3D] = []            # Still on the table.
var _homes := {}                           # Dish -> where it sat.
var _carrying: Node3D = null
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
	if _carrying != null:
		var goal := Vector3(spot.x, carry_height, spot.z)
		_carrying.position = _carrying.position.lerp(goal, 1.0 - exp(-18.0 * delta))
		if not input.held:
			_drop(spot)
	elif input.just_pressed:
		var dish := _dish_at(spot)
		if dish != null:
			_carrying = dish
			_dishes.erase(dish)
			session.play_sound("clack", dish.position, -6.0, 1.6)
			session.wobble(dish, 0.1)
	session.set_status("Dishes left: %d" % (_dishes.size() + (1 if _carrying != null else 0)))
	if _dishes.is_empty() and _carrying == null and _landing == 0:
		finish(1.0)


func _drop(spot: Vector3) -> void:
	var dish := _carrying
	_carrying = null
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
	if _carrying != null:
		return not input.move_to(session.surface(bin_surface).position, delta, 0.9)
	if _dishes.is_empty():
		return false
	return input.move_to(_dishes[0].position, delta, 1.0) and not input.held
