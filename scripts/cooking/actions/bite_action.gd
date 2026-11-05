# BiteAction: fishing's wait for a bite. A fish is picked now (Fishing.pick:
# what's biting in this habitat, season and hour, or the debug panel's), the
# bobber bobs, a nibble or two twitch it (fakes!), then it goes right under:
# press the button while it's down to hook the fish. Too soon (on a nibble) or
# too late and it swims off. Timings are the bite settings in data/fish.json;
# landing in the ripples (CastAction's "hot") shortens the wait. Leaves "fish"
# and "size" in session.context, or "failed" and "finish_text".
class_name BiteAction
extends CookAction

const NIBBLE_DIP := 0.025
const BITE_DIP := 0.08
const ROD_PULL := 6.0  # Radians the rod tips down per meter the bobber's pulled under.
const SCRIPTED_REACTION := 0.35  # Seconds a reel's chef takes to strike.

var _settings: Dictionary
var _fish: Dictionary
var _bobber: Node3D
var _rest := Vector3.ZERO
var _time := 0.0
var _wait := 0.0
var _nibbles: Array[float] = []
var _bitten := false
var _bite_left := 0.0
var _dip := 0.0  # How far under the bobber is pulled right now.
var _rod: Node3D


func _begin() -> void:
	weight = 0.0
	_settings = GameData.fishing_settings.get("bite", {})
	_bobber = session.context["bobber"]
	_rod = session.context.get("rod")
	_rest = session.context.get("cast_at", _bobber.position)
	_fish = Fishing.pick(session.context.get("habitat", "pond"))
	var wait: Dictionary = _settings.get("wait_seconds", { "min": 3.0, "max": 8.0 })
	_wait = randf_range(float(wait["min"]), float(wait["max"]))
	if session.context.get("hot", false):
		_wait *= float(_settings.get("hot_spot_wait_factor", 0.5))
	var nibbles: Dictionary = _settings.get("nibbles", { "min": 0, "max": 2 })
	for i in randi_range(int(nibbles["min"]), int(nibbles["max"])):
		_nibbles.append(randf_range(_wait * 0.25, maxf(_wait - 0.7, _wait * 0.3)))
	_nibbles.sort()
	_bite_left = float(_settings.get("bite_window_seconds", 1.0))


func uses_cursor() -> bool:
	return false


func end() -> void:
	var ripples: Node3D = session.context.get("hot_spot")
	if is_instance_valid(ripples):
		ripples.queue_free()


func update(delta: float, input: CookInput) -> void:
	_time += delta
	_dip = move_toward(_dip, BITE_DIP if _bitten else 0.0, delta * 0.6)
	_bobber.position = _rest + Vector3(0.0, sin(_time * 2.4) * 0.008 - _dip, 0.0)
	if _rod != null:  # The rod tip's pulled down with the bobber.
		_rod.rotation.x = lerp_angle(_rod.rotation.x, -_dip * ROD_PULL, 1.0 - exp(-14.0 * delta))
	if _fish.is_empty():
		_fail("Nothing's biting here right now.")
		return
	if not _nibbles.is_empty() and _time >= _nibbles[0]:
		_nibbles.pop_front()
		_dip = NIBBLE_DIP
		session.play_sound("plop", _rest, -16.0, 1.6)
	if not _bitten:
		if input.just_pressed:
			_fail("Too soon! It swam off.")
			return
		if _time >= _wait:
			_bitten = true
			_dip = BITE_DIP
			session.play_sound("plop", _rest, 2.0, 0.6)
			session.play_sound("ding", _rest, -2.0, 1.5)  # The tell: a fish is on!
			session.burst(_rest, Color(0.8, 0.9, 1.0), 16, 0.5)
			session.pop_text("!", _rest + Vector3(0.0, 0.15, 0.0), 1)
		session.set_status("Watch the bobber...")
		return
	session.set_status("NOW!")
	if input.just_pressed:
		session.context["fish"] = _fish
		session.context["size"] = Fishing.roll_size(_fish)
		session.pop_text("Hooked!", _rest, 1)
		finish(1.0)
		return
	_bite_left -= delta
	if _bite_left <= 0.0:
		_fail("Too slow... it got away.")


# Ignores the nibbles and strikes on the bite.
func scripted_hold(_delta: float, _input: CookInput) -> bool:
	return _bitten and _bite_left <= float(_settings.get("bite_window_seconds", 1.0)) - SCRIPTED_REACTION


func _fail(text: String) -> void:
	session.context["failed"] = true
	session.context["finish_text"] = text
	session.pop_text(text.get_slice("!", 0).get_slice(".", 0), _rest, -1)
	finish(0.0)
