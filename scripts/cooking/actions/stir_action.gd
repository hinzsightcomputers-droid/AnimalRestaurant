# StirAction: stir a pot with a whisk, round and round, counter-clockwise (an
# arrow round the pot shows the way). With a stick (or the keys) the whisk goes
# where the stick points, so rolling it round stirs; with the mouse, hold the
# button and circle it round the pot. The soup and what's in it swirl along.
# Stir enough turns to finish; the score is how much of the stirring was at a
# good pace (too slow and it catches, too fast and it slops over the side),
# with the first warm_up_turns always counted good and full marks from
# full_marks of it: it's meant to be easy to get right.
# Stirring a container (a saucepan, a bowl) can melt what's been dropped in
# (melt: butter, cheese), turn its liquid tint_to as it goes, and smooth out
# lumps; tool "spatula" folds with a spatula instead of a whisk.
class_name StirAction
extends CookAction

@export var in_surface := "Pot"
@export var turns := 8.0                  # Turns of the whisk to finish.
@export var slow_speed := 0.25            # Turns a second: slower than this is too slow...
@export var fast_speed := 2.8             # ...and faster than this is too fast.
@export var warm_up_turns := 1.5          # The first turns always count as a good pace (getting going).
@export_range(0.0, 1.0) var full_marks := 0.85  # This share of the stirring at a good pace gets 100%.
@export var reach := 0.65                 # How far out the whisk goes, as a share of the pot's radius.
@export var soup_follow := 2.5            # How quickly the soup catches up with the whisk.
@export var splash_every := 0.2           # Seconds between splashes while stirring too fast.
@export var melt := false                 # What's been dropped in (its stack) melts away as you stir.
@export var tint_to := Color(0, 0, 0, 0)  # The liquid turns this color as you stir (none if see-through).
@export var lumps := 0                    # Lumps of flour that stir out.
@export_enum("whisk", "spatula") var tool := "whisk"

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
var _arrow: Node3D
var _wrong_way := 99.0                    # Seconds since they last stirred clockwise.
var _melting: Array[Node3D] = []           # Shrinking away as it's stirred (melt, lumps).
var _from_color := Color.WHITE


func _begin() -> void:
	var leeway := GameState.upgrade_multiplier("stir_window")  # Steady Stove: a wider "just right".
	slow_speed /= leeway
	fast_speed *= leeway
	var pot := session.surface(in_surface)
	_whisk = _make_whisk() if tool == "whisk" else _make_spatula()
	_whisk.position = _middle(pot) + Vector3(pot.radius() * reach, -0.02, 0.0)
	if melt and pot.depth > 0.0 and (pot.liquid == null or not pot.liquid.visible) and tint_to.a > 0.0:
		pot.fill_to(0.05, tint_to)  # What melts makes a little pool.
	_from_color = pot.liquid_color()
	if melt:
		for entry in session.stack_of(in_surface):
			_melting.append(entry["node"])
	for i in lumps:
		var lump := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = randf_range(0.008, 0.013)
		mesh.height = mesh.radius * 1.4
		var flour := StandardMaterial3D.new()
		flour.albedo_color = Color(0.97, 0.96, 0.92)
		mesh.material = flour
		lump.mesh = mesh
		var spot := Vector2.from_angle(randf() * TAU) * randf_range(0.2, 0.75) * pot.radius()
		lump.position = Vector3(spot.x, pot.liquid_top() - pot.position.y, spot.y)
		pot.add_child(lump)
		pot.contents.append(lump)
		_melting.append(lump)
	_swish = session.loop_sound("drizzle", -30.0)
	_swish.position = pot.position
	_swish.play()
	_steam = session.make_steam(pot.radius())
	_steam.position = pot.position
	session.add_child(_steam)
	_steam.emitting = true
	_arrow = _make_arrow(pot.radius() * 1.3)
	_arrow.position = pot.position + Vector3(0.0, 0.03, 0.0)


func view_point() -> Vector3:
	return _middle(session.surface(in_surface))


func uses_cursor() -> bool:
	return false


func cursor_height() -> float:
	return session.surface(in_surface).position.y


func end() -> void:
	_whisk.queue_free()
	_arrow.queue_free()
	for item in _melting:
		if is_instance_valid(item):
			item.visible = false
	if tint_to.a > 0.0:
		session.surface(in_surface).set_liquid_color(tint_to)
	_swish.queue_free()
	_steam.emitting = false


func update(delta: float, input: CookInput) -> void:
	var pot := session.surface(in_surface)
	var center := _middle(pot)
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
		if turned > 0.0:  # Clockwise (seen from above): doesn't count.
			_wrong_way = 0.0
			turned = 0.0
		_progress += -turned / TAU
		_stir_time += delta
		if _progress < warm_up_turns or (_speed >= slow_speed and _speed <= fast_speed):
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
		if not is_instance_valid(item):
			continue
		var origin := pot.position if item.get_parent() == session else Vector3.ZERO  # In the pot's own space, or the session's.
		var offset := item.position - Vector3(origin.x, item.position.y, origin.z)
		offset = offset.rotated(Vector3.UP, -_spin * delta * 0.8)
		item.position = Vector3(origin.x, item.position.y, origin.z) + offset
		item.rotate_y(-_spin * delta)
	# Melting in and smoothing out as it goes.
	var share := clampf(_progress / turns, 0.0, 1.0)
	for item in _melting:
		if is_instance_valid(item):
			item.scale = Vector3.ONE * maxf(1.0 - share * 1.15, 0.001)
	if tint_to.a > 0.0:
		pot.set_liquid_color(_from_color.lerp(tint_to, share))

	_swish.volume_db = lerpf(-30.0, -6.0, clampf(_speed / fast_speed, 0.0, 1.0))
	_splash_timer -= delta
	if stirring and _speed > fast_speed and _splash_timer <= 0.0:
		_splash_timer = splash_every
		session.burst(_whisk.position + Vector3(0.0, 0.03, 0.0), pot.color, 8, 0.5)
		session.play_sound("plop", _whisk.position, -8.0, 1.4)
	_wrong_way += delta
	_arrow.rotation.y += delta * 0.8  # Turning the way to stir.
	var pace := "Too fast!" if _speed > fast_speed else ("Just right" if _speed >= slow_speed or _progress < warm_up_turns else "Faster!")
	if _wrong_way < 0.6:
		pace = "The other way! Follow the arrow"
	elif not stirring:
		pace = "Don't stop stirring!"
	session.set_status("Stirred %d / %d  -  %s" % [mini(int(_progress), int(turns)), int(turns), pace])

	if _progress >= turns:
		var score := clampf(_good_time / maxf(_stir_time, 0.001) / full_marks, 0.0, 1.0)
		session.pop_text("Smooth!" if score >= 0.8 else ("Stirred" if score >= 0.5 else "Lumpy!"), center, CookSession.mood_of(score))
		finish(score)


# Where it stirs: the pot's middle, at its liquid.
func _middle(pot: CookSurface) -> Vector3:
	return Vector3(pot.position.x, pot.liquid_top(), pot.position.z)


# A wet spatula for folding, standing up with its blade in the pot.
func _make_spatula() -> Node3D:
	var holder := Node3D.new()
	var spatula := session.make_spatula()
	spatula.reparent(holder)
	spatula.rotation.x = deg_to_rad(-75.0)
	spatula.position.y = 0.05
	session.add_child(holder)
	return holder


# A curved arrow round the pot, going counter-clockwise seen from above: dashes
# round three quarters of a circle `arc_radius` across, and a head.
func _make_arrow(arc_radius: float) -> Node3D:
	var arrow := Node3D.new()
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(1.0, 0.85, 0.3, 0.95)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.no_depth_test = true  # Over the pot's rim.
	paint.render_priority = 2
	const DASHES := 14
	const SWEEP := PI * 1.5
	var end_angle := 0.0
	for i in DASHES:
		var angle := -float(i) / DASHES * SWEEP  # Down the angle: counter-clockwise on screen.
		var dash := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(arc_radius * SWEEP / DASHES * 0.7, 0.004, 0.024)
		mesh.material = paint
		dash.mesh = mesh
		dash.position = Vector3(cos(angle), 0.0, sin(angle)) * arc_radius
		dash.rotation.y = atan2(cos(angle), sin(angle))  # Along the circle.
		arrow.add_child(dash)
		end_angle = angle - SWEEP / DASHES
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.045
	cone.height = 0.07
	cone.material = paint
	head.mesh = cone
	head.position = Vector3(cos(end_angle), 0.0, sin(end_angle)) * arc_radius
	head.rotation = Vector3(0.0, atan2(cos(end_angle), sin(end_angle)), -PI * 0.5)  # Its point along the circle, the way round.
	arrow.add_child(head)
	session.add_child(arrow)
	return arrow


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
