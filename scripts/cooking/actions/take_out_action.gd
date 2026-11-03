# TakeOutAction: back to the oven for a tray left baking (a BakeAction with
# leave_in): the camera comes down to the oven door and the bake carries on as
# usual until you press to take it out. Its score is the bake's (give it no
# weight of its own).
class_name TakeOutAction
extends CookAction

var _bake: BakeAction


func _init() -> void:
	weight = 0.0
	view_distance = 0.95  # Straight on at the oven door, like the bake.
	view_pitch = 6.0
	view_seconds = 0.8


func view_point() -> Vector3:
	return _bake.oven_front if _bake != null else super.view_point()


func _begin() -> void:
	_bake = session.step_of(BakeAction) as BakeAction
	if _bake == null or _bake.done:
		finish(1.0)
		return
	_bake.claimed = true


func uses_cursor() -> bool:
	return false


func update(_delta: float, _input: CookInput) -> void:
	if _bake.done:
		finish(_bake.quality)

