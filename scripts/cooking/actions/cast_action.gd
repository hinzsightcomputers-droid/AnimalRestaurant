# CastAction: the first step of fishing. Hold the button (or the mouse, or
# RT) and the power bar rises and falls; let go and the bobber flies out that
# far (cast settings in data/fish.json), aimed left or right with the stick or
# the mouse. Ripples mark a hot spot somewhere in range: landing near it means
# a quicker bite (see BiteAction). Doesn't score. The fishing spot puts the
# bobber, rod and line in session.context before it starts; this leaves
# "cast_at" (where the bobber landed) and "hot" there for the next steps.
class_name CastAction
extends CookAction

const FLIGHT_SECONDS := 0.6
const AIM_WIDTH := 0.9  # How far left or right of straight out a cast can go (meters).
const SCRIPTED_PAUSE := 1.0  # A reel looks at the water this long before casting.

var _settings: Dictionary
var _charging := false
var _charge_time := 0.0
var _power := 0.0
var _flying := false
var _armed := false  # The press that started fishing has been let go.
var _bobber: Node3D
var _rod: Node3D
var _meter: FishingMeter
var _hot_at := Vector3.ZERO
var _scripted_pause := SCRIPTED_PAUSE


func _begin() -> void:
	weight = 0.0
	_settings = GameData.fishing_settings.get("cast", {})
	_bobber = session.context["bobber"]
	_rod = session.context["rod"]
	_bobber.position = _rod_tip()
	var water_y: float = session.context.get("water_y", 0.0)
	var near := float(_settings.get("min_distance", 0.8)) + 0.3
	var far := float(_settings.get("max_distance", 3.0)) - 0.2
	_hot_at = Vector3(randf_range(-AIM_WIDTH, AIM_WIDTH) * 0.6, water_y + 0.005, -randf_range(near, far))
	var ripples := session.make_ring(float(_settings.get("hot_spot_radius", 0.45)) * 0.7, Color(0.85, 0.95, 1.0, 0.6))
	ripples.position = _hot_at
	var pulse := ripples.create_tween().set_loops()
	pulse.tween_property(ripples, "scale", Vector3(1.25, 0.3, 1.25), 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(ripples, "scale", Vector3(0.85, 0.3, 0.85), 0.8).set_trans(Tween.TRANS_SINE)
	session.context["hot_spot"] = ripples
	_meter = FishingMeter.make(session.overlay(), Rect2(0.3, 0.84, 0.4, 0.035), false, "Power")


func uses_cursor() -> bool:
	return false


func end() -> void:
	if _meter != null:
		_meter.queue_free()


func update(delta: float, input: CookInput) -> void:
	if _flying:
		return
	if not _armed:
		_armed = not input.held
		return
	if input.just_pressed:
		_charging = true
		_charge_time = 0.0
	if _charging and input.held:
		_charge_time += delta
		_power = pingpong(_charge_time / float(_settings.get("charge_seconds", 1.2)), 1.0)
		_rod.rotation.x = lerpf(0.0, 0.6, _power)  # Drawn back over the shoulder.
		_meter.set_fill(_power)
		session.set_status("Let go to cast!")
	elif _charging and input.just_released:
		_cast(input)
	else:
		session.set_status("")


# Straight into the ripples.
func scripted_hold(delta: float, input: CookInput) -> bool:
	_scripted_pause -= delta
	if _scripted_pause > 0.0 or _flying:
		return false
	var distance := -_hot_at.z
	input.stick = Vector2(clampf(_hot_at.x * 3.0 / (AIM_WIDTH * distance), -1.0, 1.0), 0.0)
	var power := inverse_lerp(float(_settings.get("min_distance", 0.8)), float(_settings.get("max_distance", 3.0)), distance)
	return not _charging or _power < power


func _cast(input: CookInput) -> void:
	_charging = false
	_flying = true
	var distance := lerpf(float(_settings.get("min_distance", 0.8)), float(_settings.get("max_distance", 3.0)), _power)
	var aim := input.cursor.x / maxf(session.bounds.size.x * 0.5, 0.01) if input.using_mouse else input.stick.x
	var target := Vector3(clampf(aim, -1.0, 1.0) * AIM_WIDTH * distance / 3.0, session.context.get("water_y", 0.0), -distance)
	session.context["cast_at"] = target
	session.context["hot"] = Vector2(target.x - _hot_at.x, target.z - _hot_at.z).length() <= float(_settings.get("hot_spot_radius", 0.45))
	session.play_sound("whoosh", _rod_tip())
	var start := _rod_tip()
	var swing := session.create_tween()
	swing.tween_property(_rod, "rotation:x", -0.35, 0.15)
	swing.tween_property(_rod, "rotation:x", 0.0, 0.4)
	var flight := session.create_tween()
	flight.tween_method(func(t: float):
		_bobber.position = start.lerp(target, t) + Vector3(0.0, sin(t * PI) * (0.4 + distance * 0.2), 0.0),
		0.0, 1.0, FLIGHT_SECONDS)
	flight.tween_callback(_landed.bind(target))


func _landed(at: Vector3) -> void:
	session.play_sound("plop", at, -4.0, 0.8)
	session.burst(at, Color(0.8, 0.9, 1.0), 12, 0.4)
	if session.context.get("hot", false):
		session.pop_text("In the ripples!", at, 1)
	finish(1.0)


func _rod_tip() -> Vector3:
	return _rod.position + _rod.basis * session.context.get("rod_tip", Vector3(0.0, 0.0, -1.4))
