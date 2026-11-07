# CookInput: the one place close-up cooking reads its controls, for one player.
# It turns a stick (left or right on a gamepad, WASD or the arrow keys on a
# keyboard), the interact button and the mouse into what steps want:
#   - cursor: a point on the work surface (session coordinates). The stick
#     moves it; the mouse puts it wherever it points.
#   - held / just_pressed / just_released: interact, the left mouse button, or
#     the right trigger on a gamepad.
#   - stick: where the stick (or the keys) points, as a direction on the surface.
#   - flick: a quick push of the stick (or tap of a key, even with another
#     held), or a quick swipe of the mouse, as a direction on the surface. Set
#     for one frame.
# The mouse only drives the player whose view it's over. Tuning is on the
# CookSession (cursor_speed, pad_cursor_speed, flick_*).
class_name CookInput
extends RefCounted

var cursor := Vector3.ZERO
var height := 0.0              # Height of the plane the cursor (and mouse) is on.
var held := false
var just_pressed := false
var just_released := false
var flick := Vector2.ZERO      # x, z on the surface, normalized; zero when there's no flick.
var stick := Vector2.ZERO      # x, z on the surface, up to 1 long; zero in the deadzone.
var using_mouse := false       # The mouse moved the cursor last (rather than the stick).
var scripted := false          # A reel is playing: the step plays itself (CookAction.scripted_hold), and nothing real counts.

const SCRIPTED_HAND_SPEED := 0.9  # Meters a second a reel's chef moves the cursor.

var _session: CookSession
var _player_index: int
var _view_manager: ViewManager
var _time := 0.0
var _last_mouse := Vector2(-1.0, -1.0)
var _stick_out_time := 0.0     # Seconds since the stick left the center.
var _stick_flicked := false    # This push already flicked: wait for the stick to come back.
var _mouse_trail: Array = []   # [time, point on the surface] for the last moment of mouse movement.
var _mouse_flicked := false
var _wait_for_release := true  # Until every button's been let go once.
var _keys_down := {}           # Direction keys held at the last update (for _key_flick).
var _scripted_step: CookAction = null  # The step a reel's hand was last on: a new one starts with the button up.


func _init(session: CookSession, player_index: int, view_manager: ViewManager) -> void:
	_session = session
	_player_index = player_index
	_view_manager = view_manager


func update(delta: float) -> void:
	if scripted:
		flick = Vector2.ZERO
		stick = Vector2.ZERO
		if _session.current != _scripted_step:
			_scripted_step = _session.current
			_press(false)  # Let go between steps, so the next one's first press counts.
			return
		_press(_session.current != null and _session.current.scripted_hold(delta, self))
		return
	_time += delta
	var raw := _raw_stick()
	var mouse_point = _mouse_point()  # null while the mouse isn't over this player's view.
	var mouse_position := _session.get_viewport().get_mouse_position()
	var mouse_moved := mouse_point != null and mouse_position.distance_to(_last_mouse) > 0.5
	_last_mouse = mouse_position
	if mouse_moved:
		cursor = mouse_point
		using_mouse = true
	elif raw.length() > InputSetup.DEADZONE:
		using_mouse = false
		var move := _on_surface(raw) * _cursor_speed(raw) * delta
		cursor += Vector3(move.x, 0.0, move.y)
	cursor = _session.clamp_to_bounds(cursor)
	cursor.y = height
	stick = _on_surface(raw).limit_length(1.0) if raw.length() > InputSetup.DEADZONE else Vector2.ZERO

	var pad := InputSetup.pad_of(_player_index)
	var now_held := Input.is_action_pressed(_action("interact")) \
		or (mouse_point != null and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) \
		or (pad >= 0 and Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) > 0.5)
	if _wait_for_release:  # The press that opened the close-up: it doesn't count as the first one.
		_wait_for_release = now_held
		now_held = false
	_press(now_held)

	flick = _stick_flick(raw, delta)
	var tap := _key_flick() if InputSetup.pad_of(_player_index) < 0 else Vector2.ZERO
	if flick == Vector2.ZERO:
		flick = tap
	var swipe := _mouse_flick(mouse_point)
	if flick == Vector2.ZERO:
		flick = swipe


# For a step playing itself: the cursor heads for `point`. True once it's there.
func move_to(point: Vector3, delta: float, speed := SCRIPTED_HAND_SPEED) -> bool:
	var goal := Vector3(point.x, height, point.z)
	cursor = cursor.move_toward(goal, speed * delta)
	return cursor.distance_to(goal) < 0.005


func _press(now_held: bool) -> void:
	just_pressed = now_held and not held
	just_released = held and not now_held
	held = now_held


# Meters a second for this push: on a gamepad, from nothing at the edge of the
# deadzone up to pad_cursor_speed at full tilt (so a light touch can still aim);
# the keys, always cursor_speed. Both times the player's setting (Settings).
func _cursor_speed(raw: Vector2) -> float:
	if InputSetup.pad_of(_player_index) < 0:
		return _session.cursor_speed * Settings.key_cursor_speed
	var tilt := clampf((raw.length() - InputSetup.DEADZONE) / (1.0 - InputSetup.DEADZONE), 0.0, 1.0)
	return _session.pad_cursor_speed * Settings.pad_cursor_speed * tilt / maxf(raw.length(), 0.001)  # / length: _on_surface(raw) is already that long.

# Whichever stick is pushed further (only the left one, or the keys, on a keyboard).
func _raw_stick() -> Vector2:
	var left := Input.get_vector(_action("move_left"), _action("move_right"), _action("move_up"), _action("move_down"))
	var pad := InputSetup.pad_of(_player_index)
	if pad >= 0:
		var right := Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
		if right.length() > InputSetup.DEADZONE and right.length() > left.length():
			return right.limit_length(1.0)
	return left


# A push from the center to the edge within flick_window seconds.
func _stick_flick(raw: Vector2, delta: float) -> Vector2:
	var strength := raw.length()
	if strength < 0.3:
		_stick_out_time = 0.0
		_stick_flicked = false
		return Vector2.ZERO
	_stick_out_time += delta
	if not _stick_flicked and strength >= _session.flick_strength and _stick_out_time <= _session.flick_window:
		_stick_flicked = true
		return _on_surface(raw).normalized()
	return Vector2.ZERO


# On a keyboard, a fresh tap of a direction key, even with another one still
# held from aiming (which would stop it counting as a push from the center).
func _key_flick() -> Vector2:
	var tapped := Vector2.ZERO
	for key in [["move_up", Vector2.UP], ["move_down", Vector2.DOWN], ["move_left", Vector2.LEFT], ["move_right", Vector2.RIGHT]]:
		var down := Input.is_action_pressed(_action(key[0]))
		if down and not _keys_down.get(key[0], false):
			tapped = key[1]
		_keys_down[key[0]] = down
	return _on_surface(tapped).normalized() if tapped != Vector2.ZERO else Vector2.ZERO


# The mouse moving faster than flick_mouse_speed (meters a second across the surface).
func _mouse_flick(mouse_point) -> Vector2:
	if mouse_point == null:
		_mouse_trail.clear()
		return Vector2.ZERO
	var point := Vector2(mouse_point.x, mouse_point.z)
	_mouse_trail.append([_time, point])
	while _mouse_trail.size() > 2 and _time - _mouse_trail[0][0] > 0.08:
		_mouse_trail.pop_front()
	var span: float = _time - _mouse_trail[0][0]
	if span <= 0.0:
		return Vector2.ZERO
	var velocity: Vector2 = (point - _mouse_trail[0][1]) / span
	if velocity.length() < _session.flick_mouse_speed * 0.4:
		_mouse_flicked = false
	elif not _mouse_flicked and velocity.length() >= _session.flick_mouse_speed:
		_mouse_flicked = true
		return velocity.normalized()
	return Vector2.ZERO


# A stick direction as a direction on the surface: "up" is away from the camera.
func _on_surface(raw: Vector2) -> Vector2:
	var camera := _camera()
	if camera == null:
		return raw
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	var world := right.normalized() * raw.x - forward.normalized() * raw.y
	var local := _session.global_basis.inverse() * world
	return Vector2(local.x, local.z)


# Where the mouse points on the cursor's plane, or null when it isn't over this player's view.
func _mouse_point() -> Variant:
	var view := _view() as PlayerView
	if view == null or not view.is_visible_in_tree():
		return null
	var mouse := view.get_global_mouse_position()
	var rect := view.get_global_rect()
	if not rect.has_point(mouse) or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return null
	var camera := view.rig.camera
	var screen := (mouse - rect.position) / rect.size * Vector2(view.viewport.size)
	var up := _session.global_basis.y.normalized()
	var plane := Plane(up, _session.to_global(Vector3(0.0, height, 0.0)))
	var hit = plane.intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	return _session.to_local(hit) if hit != null else null


func _view() -> Control:
	return _view_manager.view_for(_player_index) if _view_manager != null else null


func _camera() -> Camera3D:
	var view := _view() as PlayerView
	return view.rig.camera if view != null else null


func _action(action: String) -> String:
	return InputSetup.action_name(_player_index, action)
