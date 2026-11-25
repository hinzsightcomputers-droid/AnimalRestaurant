# DrainAction: take the boiling pasta off the heat (a press: this is what
# BoilAction is scored on), then hold to tip the water out, letting go at the
# line so a little of the pasta water stays for the sauce. Tipped right out
# it's dry; plenty left, it's watery. Presses left over from the step before
# (still rubbing cheese) never count: the button has to have been up a moment
# first, it can't come off before it's cooked, and pouring takes a new press.
class_name DrainAction
extends CookAction

@export var in_surface := "Pot"
@export var pour_seconds := 2.2            # Holding this long empties the pot (longer on Easy).
@export var line := 0.22                   # How much water to leave (of the pot's full).
@export var perfect_within := 0.09         # This far off the line still gets full marks.
@export var tilt_degrees := 16.0

const SCRIPTED_DONE := 1.0                 # How boiled a reel's chef lets it get.
const ARM_AFTER := 0.35                    # The button's up this long before a press takes the pasta off.
const TAP_SECONDS := 0.3                   # Letting go of the pour this soon was a stray tap: it just stops.

var _armed := false
var _up_for := 0.0                         # Seconds the button's been up.
var _off := false                          # Off the heat...
var _let_go := false                       # ...and the press that did it has been let go.
var _poured_for := 0.0
var _pouring := false
var _mark: MeshInstance3D
var _sound: AudioStreamPlayer3D
var _stream: CPUParticles3D
var _models: Array[Node3D] = []            # The pot and its model: what tips.
var _homes: Array[Transform3D] = []
var _tilt := 0.0


func uses_cursor() -> bool:
	return false


func view_point() -> Vector3:
	return session.surface(in_surface).position


func _begin() -> void:
	var pot := session.surface(in_surface)
	for node in [pot, session.get_node_or_null("PotModel")]:
		if node != null:
			_models.append(node)
			_homes.append(node.transform)
	_mark = session.make_ring(pot.radius() * 0.95, Color(1.0, 1.0, 1.0, 0.95))
	_mark.reparent(pot)
	_mark.position = Vector3(0.0, pot.depth * line, 0.0)
	_mark.visible = false
	_sound = session.loop_sound("pour", -8.0)
	_sound.position = pot.position
	_stream = CPUParticles3D.new()
	_stream.amount = 90
	_stream.lifetime = 0.4
	_stream.direction = Vector3(-0.6, 0.1, 0.0)
	_stream.spread = 6.0
	_stream.initial_velocity_min = 0.25
	_stream.initial_velocity_max = 0.35
	_stream.gravity = Vector3(0.0, -2.5, 0.0)
	_stream.mesh = session.dot_mesh(0.012, Color(0.74, 0.88, 0.93, 0.8))
	_stream.emitting = false
	_stream.position = pot.position + Vector3(-pot.radius() * 1.15, pot.depth, 0.0)
	session.add_child(_stream)


func end() -> void:
	_mark.queue_free()
	_sound.queue_free()
	_stream.emitting = false
	for i in _models.size():
		_models[i].create_tween().tween_property(_models[i], "transform", _homes[i], 0.25).set_trans(Tween.TRANS_QUAD)


func update(delta: float, input: CookInput) -> void:
	var pot := session.surface(in_surface)
	_up_for = 0.0 if input.held else _up_for + delta
	if not _off:
		var early := _early()
		session.set_status("Wait for the green" if early else ("Now!" if _armed else "Let go, then press to take it off"))
		if _armed and input.just_pressed:
			if early:
				session.pop_text("Not ready yet!", pot.position, 0)
			else:
				_off = true
				if _boil() != null:
					_boil().take_off()
				_mark.visible = true
		_armed = _armed or _up_for >= ARM_AFTER
		return
	_let_go = _let_go or not input.held
	if not _pouring and _let_go and input.just_pressed:
		_pouring = true
		_poured_for = 0.0
		_sound.play()
	if _pouring:
		_poured_for += delta
		if pot.liquid != null:
			pot.liquid.knock(Vector2(-0.12, randf_range(-0.04, 0.04)) * delta * 6.0)
		pot.fill_to(pot.level - delta / pour_seconds * GameState.difficulty_value("closeup_pace"))
		_sink_pasta(pot)
		if not input.held and _poured_for < TAP_SECONDS:
			_pouring = false
			_sound.stop()
		elif not input.held or pot.level <= 0.0:
			_finish_pour(pot)
			return
	_stream.emitting = _pouring
	_tilt = lerpf(_tilt, deg_to_rad(tilt_degrees) if _pouring else 0.0, 1.0 - exp(-8.0 * delta))
	_show_tilt(pot)
	session.set_status("Let go at the line!" if _pouring else "Hold to pour the water out")


# For a reel: off the heat once it's al dente, then down to the line.
func scripted_hold(_delta: float, _input: CookInput) -> bool:
	if not _off:
		return _armed and (_boil() == null or _boil().doneness >= SCRIPTED_DONE)
	return _let_go and session.surface(in_surface).level > line


# Not cooked yet (it can't come off).
func _early() -> bool:
	return _boil() != null and _boil().doneness < _boil().perfect_from


func _boil() -> BoilAction:
	return session.step_of(BoilAction) as BoilAction


func _finish_pour(pot: CookSurface) -> void:
	_pouring = false
	_sound.stop()
	var error := absf(pot.level - line)
	var result := 1.0 if error <= perfect_within else clampf(1.0 - (error - perfect_within) / 0.5, 0.3, 1.0)
	session.pop_text("Perfect!" if result >= 1.0 else ("Drained dry!" if pot.level < line else "Still watery"), pot.position, CookSession.mood_of(result))
	finish(result)


# The pasta goes down with the water, heaping up at the bottom.
func _sink_pasta(pot: CookSurface) -> void:
	if _boil() == null:
		return
	var i := 0
	for bit in _boil().bits():
		if is_instance_valid(bit):
			var heap := 0.006 + 0.009 * (i % 3)
			var top := pot.depth * maxf(pot.level, 0.0) - 0.004
			if top <= heap:  # Left high and dry.
				if pot.liquid != null:
					pot.liquid.sink_thing(bit)
				bit.position.y = lerpf(bit.position.y, heap, 0.15)
		i += 1


# Tipped to the left about its middle, the pot and its model as one.
func _show_tilt(pot: CookSurface) -> void:
	var middle := _homes[0].origin
	var turn := Transform3D(Basis(Vector3.BACK, _tilt), Vector3.ZERO)
	for i in _models.size():
		var home := _homes[i]
		home.origin -= middle
		home = turn * home
		home.origin += middle
		_models[i].transform = home
	_stream.position = pot.position + Vector3(-pot.radius() * 1.15, pot.depth * 0.6, 0.0)
