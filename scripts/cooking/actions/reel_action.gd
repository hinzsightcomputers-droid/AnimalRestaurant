# ReelAction: bring the hooked fish in. Hold the button (or RT, or the mouse,
# or pull the stick back) to reel: the line's tension rises; let go and it
# eases. The fish pulls in bursts, harder and more often the harder it is
# (its difficulty in data/fish.json). Keep the tension in the green band:
# too tight for too long (or right to the top) and the line snaps; too slack
# for too long and the fish shakes free. Reeling in the band brings it in;
# when it's all the way in it's caught. Scores the share of time spent in the
# band. Skipped if the bite was missed (session.context "failed"). Leaves
# "catch" ({ fish id, size }) and "finish_text" in session.context.
class_name ReelAction
extends CookAction

const TICK_EVERY := 0.09  # Seconds between reel clicks at full speed.

var _settings: Dictionary
var _fish: Dictionary
var _difficulty := 0.0
var _bobber: Node3D
var _rod: Node3D
var _from := Vector3.ZERO      # Where the bobber was when the fish was hooked.
var _tension := 0.5
var _progress := 0.0
var _pull_left := 0.0          # Seconds of the fish's current pull.
var _next_pull := 0.0          # Seconds until it pulls again.
var _high_time := 0.0
var _low_time := 0.0
var _time := 0.0
var _band_time := 0.0
var _tick := 0.0
var _side := 0.0               # Where the fish has dragged the bobber sideways.
var _tension_meter: FishingMeter
var _progress_meter: FishingMeter
var _ended := false
var _swimmer: Node3D            # The fish itself, swimming about on the line.
var _swim_angle := 0.0


func _begin() -> void:
	if session.context.get("failed", false):
		weight = 0.0
		finish(0.0)
		return
	_settings = GameData.fishing_settings.get("reel", {})
	_fish = session.context["fish"]
	_difficulty = clampf(float(_fish.get("difficulty", 0.3)), 0.0, 1.0)
	_bobber = session.context["bobber"]
	_rod = session.context["rod"]
	_from = _bobber.position
	_tension = float(_settings.get("start_tension", 0.45))
	_next_pull = randf_range(0.3, _pull_gap())
	var overlay := session.overlay()
	_tension_meter = FishingMeter.make(overlay, Rect2(0.88, 0.28, 0.035, 0.44), true, "Tension")
	_tension_meter.set_band(_low(), _high())
	_progress_meter = FishingMeter.make(overlay, Rect2(0.3, 0.84, 0.4, 0.035), false, "Reeled in")
	_swimmer = Fishing.make_model(_fish, maxf(_length() * 2.2, 0.45))  # Bigger than life, to be seen from the bank.
	_swimmer.position = _from
	session.add_child(_swimmer)
	_swim_angle = randf() * TAU


func uses_cursor() -> bool:
	return false


func end() -> void:
	for meter in [_tension_meter, _progress_meter]:
		if meter != null:
			meter.queue_free()


func update(delta: float, input: CookInput) -> void:
	if _ended:
		return
	_time += delta
	var reeling := 1.0 if input.held else clampf(input.stick.y, 0.0, 1.0)  # The stick pulled back, toward the bank.

	# The fish pulls in bursts.
	var pulling := _pull_left > 0.0
	if pulling:
		_pull_left -= delta
	else:
		_next_pull -= delta
		if _next_pull <= 0.0:
			var seconds: Dictionary = _settings.get("pull_seconds", { "min": 0.5, "max": 1.1 })
			_pull_left = randf_range(float(seconds["min"]), float(seconds["max"]))
			_next_pull = randf_range(_pull_gap() * 0.6, _pull_gap() * 1.4)
			_side = clampf(_side + randf_range(-0.35, 0.35), -0.6, 0.6)
			session.burst(_bobber.position, Color(0.8, 0.9, 1.0), 10, 0.45)
			session.play_sound("plop", _bobber.position, -8.0, 1.2)
	var strength: Dictionary = _settings.get("pull_strength", { "min": 0.35, "max": 1.15 })
	var pull := lerpf(float(strength["min"]), float(strength["max"]), _difficulty) if pulling else 0.0
	# Letting go gives the fish line: its pull only partly tightens a slack line.
	var give := float(_settings.get("slack_pull_share", 0.35))
	pull *= give + (1.0 - give) * reeling
	_tension += (float(_settings.get("reel_rise", 0.75)) * reeling - float(_settings.get("slack_fall", 0.55)) * (1.0 - reeling) + pull) * delta
	_tension = clampf(_tension, 0.0, 1.0)

	var in_band := _tension >= _low() and _tension <= _high()
	if in_band:
		_band_time += delta
	var speed := float(_settings.get("reel_speed", 0.2)) * lerpf(1.0, float(_settings.get("hard_fish_reel", 0.55)), _difficulty)
	_progress = minf(_progress + speed * reeling * delta * (1.0 if in_band else float(_settings.get("off_band_reel", 0.25))), 1.0)

	_high_time = _high_time + delta if _tension > _high() else maxf(_high_time - delta, 0.0)
	_low_time = _low_time + delta if _tension < _low() else maxf(_low_time - delta, 0.0)

	# The bobber comes in toward the bank, dragged about while the fish pulls.
	var near := Vector3(0.0, _from.y, -0.5)
	var wobble := sin(_time * 18.0) * 0.03 if pulling else 0.0
	_bobber.position = _from.lerp(near, _progress) + Vector3(_side * (1.0 - _progress) + wobble, -0.05 + sin(_time * 9.0) * 0.01, 0.0)
	_rod.rotation.x = lerpf(0.25, -0.25, _tension)  # Bends down as the line goes tight.
	_swim(delta, pulling)
	if reeling > 0.1:
		_tick -= delta * reeling
		if _tick <= 0.0:
			_tick = TICK_EVERY
			session.play_sound("tick", _rod.position, -10.0, 1.0 + _tension * 0.5)

	_tension_meter.set_marker(_tension, not in_band)
	_progress_meter.set_fill(_progress)
	var mood := "Too tight!" if _tension > _high() else ("Too slack!" if _tension < _low() else "Good")
	session.set_status("Tension: %s   Reeled in %d%%" % [mood, roundi(_progress * 100)])

	if _tension >= 1.0 or _high_time >= float(_settings.get("snap_seconds", 0.7)):
		_lose("Snap! The line broke.")
	elif _low_time >= float(_settings.get("escape_seconds", 1.6)):
		_lose("It shook free and got away.")
	elif _progress >= 1.0:
		_land()


func _land() -> void:
	_ended = true
	var size: int = session.context.get("size", 20)
	var name: String = _fish.get("name", "Fish")
	session.context["catch"] = { "id": _fish["id"], "size": size }
	session.context["finish_text"] = "Caught a %s! %d cm" % [name, size]
	_bobber.visible = false
	var model := _swimmer  # Out of the water it comes.
	_swimmer = null
	var show := Vector3(0.0, 0.75, -0.7)
	var tween := session.create_tween().set_parallel()
	tween.tween_property(model, "position", show, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "rotation", Vector3(0.0, PI / 2.0, 0.25), 0.5)
	tween.chain().tween_callback(session.wobble.bind(model, 0.25))
	session.burst(_bobber.position, Color(0.8, 0.9, 1.0), 20, 0.6)
	session.play_sound("plop", _bobber.position, 0.0, 0.6)
	session.pop_text("%s! %d cm" % [name, size], show + Vector3(0.0, 0.2, 0.0), 1)
	finish(_band_time / maxf(_time, 0.001))


func _lose(text: String) -> void:
	_ended = true
	if _swimmer != null:  # Off it darts.
		var away := _swimmer.position + _swimmer.basis.z * -0.8 + Vector3(0.0, -0.15, 0.0)
		var tween := _swimmer.create_tween()
		tween.tween_property(_swimmer, "position", away, 0.5).set_ease(Tween.EASE_IN)
		tween.tween_callback(_swimmer.queue_free)
	session.context["failed"] = true
	session.context["finish_text"] = text
	session.pop_text(text.get_slice("!", 0).get_slice(".", 0), _bobber.position, -1)
	_bobber.visible = false
	finish(0.0)


# The fish swims round and round under the bobber, tugging on the line: faster
# and with a splash while it pulls, its back breaking the surface. It faces
# the way it's going.
func _swim(delta: float, pulling: bool) -> void:
	if _swimmer == null:
		return
	_swim_angle += delta * (4.5 if pulling else 1.4)
	var reach := lerpf(0.3, 0.1, _progress)
	var water_y: float = session.context.get("water_y", 0.0)
	var at := _bobber.position + Vector3(cos(_swim_angle) * reach, 0.0, sin(_swim_angle) * reach * 0.6)
	at.y = water_y + (0.0 if pulling else -0.02)  # Its back breaks the surface, more so as it fights.
	var heading := at - _swimmer.position
	_swimmer.position = at
	if Vector2(heading.x, heading.z).length() > 0.0001:
		_swimmer.rotation = Vector3(0.0, atan2(-heading.x, -heading.z), sin(_time * (14.0 if pulling else 6.0)) * 0.15)


# How long the fish's model is: its size, toned down to fit the view.
func _length() -> float:
	return clampf(session.context.get("size", 20) / 100.0, 0.12, 1.0) * 0.8


func _low() -> float:
	return float(_settings.get("safe_low", 0.25))


func _high() -> float:
	return float(_settings.get("safe_high", 0.78))


# Seconds between pulls: long for easy fish, short for hard ones.
func _pull_gap() -> float:
	var every: Dictionary = _settings.get("pull_every", { "easy": 2.4, "hard": 0.9 })
	return lerpf(float(every["easy"]), float(every["hard"]), _difficulty)
