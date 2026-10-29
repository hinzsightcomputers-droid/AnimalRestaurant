# StirAction: stir a pot with a whisk, round and round. With a stick (or the
# keys) the whisk goes where the stick points, so rolling it round stirs; with
# the mouse, hold the button and circle it round the pot. The soup and what's
# in it swirl along. Stir enough turns to finish; the score is how much of
# the stirring was at a good pace (too slow and it catches, too fast and it
# slops over the side).
class_name StirAction
extends CookAction

@export var in_surface := "Pot"
@export var turns := 8.0                  # Turns of the whisk to finish.
@export var slow_speed := 0.5             # Turns a second: slower than this is too slow...
@export var fast_speed := 1.6             # ...and faster than this is too fast.
@export var reach := 0.65                 # How far out the whisk goes, as a share of the pot's radius.
@export var soup_follow := 2.5            # How quickly the soup catches up with the whisk.
@export var splash_every := 0.2           # Seconds between splashes while stirring too fast.

var _whisk: Node3D
var _swish: AudioStreamPlayer3D
var _steam: CPUParticles3D
var _angle := 0.0
var _has_angle := false
var _speed := 0.0                         # Turns a second, smoothed.
var _spin := 0.0                          # The soup's spin (radians a second).
var _progress := 0.0
var _stir_time := 0.0
var _good_time := 0.0
var _splash_timer := 0.0


func _begin() -> void:
	var leeway := GameState.upgrade_multiplier("stir_window")  # Steady Stove: a wider "just right".
	slow_speed /= leeway
	fast_speed *= leeway
	var pot := session.surface(in_surface)
	_whisk = _make_whisk()
	_whisk.position = pot.position + Vector3(pot.radius() * reach, -0.02, 0.0)
	_swish = session.loop_sound("drizzle", -30.0)
	_swish.position = pot.position
	_swish.play()
	_steam = session.make_steam(pot.radius())
	_steam.position = pot.position
	session.add_child(_steam)
	_steam.emitting = true


func uses_cursor() -> bool:
	return false


func cursor_height() -> float:
	return session.surface(in_surface).position.y


func end() -> void:
	_whisk.queue_free()
	_swish.queue_free()
	_steam.emitting = false


func update(delta: float, input: CookInput) -> void:
	var pot := session.surface(in_surface)
	var center := pot.position
	var direction := Vector2.ZERO
	if input.using_mouse:
		if input.held:
			direction = Vector2(input.cursor.x - center.x, input.cursor.z - center.z) / (pot.radius() * reach)
	elif input.stick.length() > 0.4:
		direction = input.stick
	var stirring := direction.length() > 0.25
	var turned := 0.0
	if stirring:
		direction = direction.limit_length(1.0)
		var angle := direction.angle()
		if _has_angle:
			turned = wrapf(angle - _angle, -PI, PI)
		_angle = angle
		_has_angle = true
		_progress += absf(turned) / TAU
		_stir_time += delta
		if _speed >= slow_speed and _speed <= fast_speed:
			_good_time += delta
	else:
		_has_angle = false
	_speed = lerpf(_speed, absf(turned) / TAU / delta, 1.0 - exp(-6.0 * delta))
	_spin = lerpf(_spin, turned / delta if stirring else 0.0, 1.0 - exp(-soup_follow * delta))

	# The whisk follows, leaning out, wires in the soup.
	var rest := Vector2(cos(_angle), sin(_angle)) * 0.5 if not stirring else direction
	var goal := center + Vector3(rest.x, 0.0, rest.y) * pot.radius() * reach + Vector3(0.0, -0.02, 0.0)
	_whisk.position = _whisk.position.lerp(goal, 1.0 - exp(-20.0 * delta))
	_whisk.rotation = Vector3(rest.y * 0.3, 0.0, -rest.x * 0.3)
	_whisk.rotate_y(_spin * delta)  # A little twist as it goes round.

	# What's in the pot swirls round with the soup.
	for item in pot.contents:
		var offset := item.position - center
		offset = offset.rotated(Vector3.UP, -_spin * delta * 0.8)
		item.position = center + offset
		item.rotate_y(-_spin * delta)

	_swish.volume_db = lerpf(-30.0, -6.0, clampf(_speed / fast_speed, 0.0, 1.0))
	_splash_timer -= delta
	if stirring and _speed > fast_speed and _splash_timer <= 0.0:
		_splash_timer = splash_every
		session.burst(_whisk.position + Vector3(0.0, 0.03, 0.0), pot.color, 8, 0.5)
		session.play_sound("plop", _whisk.position, -8.0, 1.4)
	var pace := "Too fast!" if _speed > fast_speed else ("Just right" if _speed >= slow_speed else "Faster!")
	session.set_status("Stirred %d / %d  -  %s" % [mini(int(_progress), int(turns)), int(turns), pace if stirring else "Stir!"])

	if _progress >= turns:
		var score := _good_time / maxf(_stir_time, 0.001)
		session.pop_text("Smooth!" if score >= 0.8 else ("Stirred" if score >= 0.5 else "Lumpy!"), center, CookSession.mood_of(score))
		finish(score)


# A balloon whisk, its origin at the bottom of the wires.
func _make_whisk() -> Node3D:
	var whisk := Node3D.new()
	var wire := StandardMaterial3D.new()
	wire.albedo_color = Color(0.85, 0.87, 0.9)
	wire.metallic = 0.8
	wire.roughness = 0.25
	for i in 4:
		var pivot := Node3D.new()
		pivot.rotation.y = i * PI / 4.0
		pivot.scale = Vector3(1.0, 1.6, 1.0)
		pivot.position.y = 0.026 * 1.6
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.0245
		mesh.outer_radius = 0.027
		mesh.rings = 24
		mesh.ring_segments = 4
		mesh.material = wire
		ring.mesh = mesh
		ring.rotation.x = PI * 0.5  # Standing up.
		pivot.add_child(ring)
		whisk.add_child(pivot)
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.008
	handle_mesh.bottom_radius = 0.006
	handle_mesh.height = 0.11
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.85, 0.35, 0.3)
	handle_mesh.material = wood
	handle.mesh = handle_mesh
	handle.position.y = 0.083 + 0.055
	whisk.add_child(handle)
	session.add_child(whisk)
	return whisk
