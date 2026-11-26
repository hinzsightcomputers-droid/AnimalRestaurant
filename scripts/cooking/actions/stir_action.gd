# StirAction: stir a pot with a whisk (or a wooden spoon), round and round, counter-clockwise (an
# arrow round the pot shows the way). With a stick (or the keys) the whisk goes
# where the stick points, so rolling it round stirs; with the mouse, hold the
# button and circle it round the pot. The soup and what's in it swirl along.
# Stir enough turns to finish; the score is how much of the stirring was at a
# good pace (too slow and it catches, too fast and it slops over the side),
# with the first warm_up_turns always counted good and full marks from
# full_marks of it: it's meant to be easy to get right.
# Stirring a container (a saucepan, a bowl) can melt what's been dropped in
# (melt: butter, cheese), turn its liquid tint_to as it goes, and smooth out
# lumps; tool "spatula" folds with a spatula instead of a whisk, "spoon" with a wooden spoon.
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
@export var melt_level := 0.0             # What melts in brings the liquid up to this (of the pot's depth).
@export var coat := false                 # What else is in there takes on tint_to as well (macaroni in its sauce).
@export var heap := 0.0                   # coat: what's coated settles into a heap this tall over the sauce (not floating in it).
@export var thick_look := 0.0             # 1: a batter: the whisk's marks stay in it.
@export var lumps := 0                    # Lumps of flour that stir out.
@export_enum("whisk", "spatula", "spoon") var tool := "whisk"
@export var crumbles := false              # What's in there (chunks of fish) breaks up a bit with every splash: stir gently.

const SCRIPTED_TURNS := 1.3  # Turns a second for a reel's chef.

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
var _from_level := 0.0
var _clear := 0.0                         # How see-through its liquid was.
var _scripted_angle := 0.0
var _last_spot := Vector2.INF
var _wake := 0.0                          # How far the whisk's gone since its last ring.
var _coated := {}                         # coat: material -> the color it started.
var _heaping := {}                        # heap: piece -> [the height it started, the height it settles to] (pot's space).


func _begin() -> void:
	var leeway := GameState.upgrade_multiplier("stir_window")  # Steady Stove: a wider "just right".
	slow_speed /= leeway
	fast_speed *= leeway
	var pot := session.surface(in_surface)
	match tool:
		"spatula":
			_whisk = _make_spatula()
		"spoon":
			_whisk = KitchenProps.wooden_spoon()
			session.add_child(_whisk)
		_:
			_whisk = _make_whisk()
	_whisk.position = _middle(pot) + Vector3(pot.radius() * reach, -0.02, 0.0)
	if melt and pot.depth > 0.0 and (pot.liquid == null or not pot.liquid.visible) and tint_to.a > 0.0:
		pot.fill_to(0.05, tint_to)  # What melts makes a little pool.
	_from_color = pot.liquid_color()
	_from_level = pot.level
	if pot.liquid != null:
		var was_clear = pot.liquid.look.get_shader_parameter("clear")
		_clear = was_clear if was_clear is float else 0.0
		pot.liquid.set_boil(0.0)
	if melt:
		for entry in session.stack_of(in_surface):
			_melting.append(entry["node"])
	if coat:
		for item in pot.contents:
			if item is MeshInstance3D and not item in _melting:
				var material := (item as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
				if material != null:
					_coated[material] = material.albedo_color
				if heap > 0.0:
					_settle(pot, item)
	for i in lumps:
		var lump := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = randf_range(0.008, 0.013)
		mesh.height = mesh.radius * 1.4
		var flour := StandardMaterial3D.new()
		flour.albedo_color = Color(0.97, 0.96, 0.92)
		flour.set_meta(ToonStyle.FOOD, "dough")
		mesh.material = flour
		lump.mesh = mesh
		var spot := Vector2.from_angle(randf() * TAU) * randf_range(0.2, 0.75) * pot.radius()
		lump.position = Vector3(spot.x, pot.liquid_top() - pot.position.y, spot.y)
		pot.add_child(lump)
		pot.contents.append(lump)
		if pot.in_it() != null:
			pot.in_it().float_thing(lump, mesh.radius * 0.35)
		_melting.append(lump)
	_swish = session.loop_sound("drizzle", -30.0)
	_swish.position = pot.position
	_swish.play()
	_steam = session.make_steam(pot.radius())
	_steam.position = pot.position
	session.add_child(_steam)
	_steam.emitting = String(in_surface) in ["Pot", "Saucepan"]  # (A bowl of batter's cold.)
	_arrow = _make_arrow(pot.radius() * 1.3)
	_arrow.position = pot.position + Vector3(0.0, 0.03, 0.0)


func view_point() -> Vector3:
	return _middle(session.surface(in_surface))


# heap: it stops floating and settles onto the others, highest in the middle,
# with just a layer of sauce under them all: cheesy, not soupy.
func _settle(pot: CookSurface, item: Node3D) -> void:
	if pot.in_it() != null:
		pot.in_it().sink_thing(item)
	var out := clampf(Vector2(item.position.x, item.position.z).length() / (pot.radius() * 0.8), 0.0, 1.0)
	var top := pot.top_when(maxf(pot.level, melt_level)) - pot.position.y
	_heaping[item] = [item.position.y, top + 0.002 + (1.0 - out * out) * heap + randf() * heap * 0.45]


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

	# The soup goes round with it, dipping in the middle and slopping at the whisk.
	var soup := pot.in_it()
	if soup != null:
		soup.spin = _spin * 0.8
		soup.dragging = stirring
		if stirring:
			var pushed := Vector2(cos(_angle), sin(_angle))
			soup.knock(pushed * minf(_speed, 3.0) * 0.16 * delta)
			if _last_spot != Vector2.INF:
				_wake += _last_spot.distance_to(pushed)
			_last_spot = pushed
			if _wake > 0.45:
				_wake = 0.0
				soup.splash(pushed * pot.radius() * reach, 0.0012 + minf(_speed, 3.0) * 0.0007)
		soup.dress({ "thick": thick_look })
	# What's in the pot swirls round with the soup.
	for item in pot.contents:
		if not is_instance_valid(item) or soup != null and soup.carries(item):
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
		if pot.liquid != null and melt:  # It clouds, thickens and comes up as everything melts into it.
			pot.liquid.dress({ "clear": clampf(_clear * (1.0 - share * 3.0), 0.0, 1.0), "foam": 0.0, "thick": maxf(thick_look, share * 0.5), "glossy": 0.85 })
			pot.fill_to(lerpf(_from_level, maxf(_from_level, melt_level), share))
	for material: StandardMaterial3D in _coated:
		material.albedo_color = (_coated[material] as Color).lerp(tint_to, share * 0.8)
	for item: Node3D in _heaping:
		if is_instance_valid(item):
			item.position.y = lerpf(_heaping[item][0], _heaping[item][1], smoothstep(0.0, 0.7, share))

	_swish.volume_db = lerpf(-30.0, -6.0, clampf(_speed / fast_speed, 0.0, 1.0))
	_splash_timer -= delta
	if stirring and _speed > fast_speed and _splash_timer <= 0.0:
		_splash_timer = splash_every
		session.burst(_whisk.position + Vector3(0.0, 0.03, 0.0), pot.color, 8, 0.5)
		if crumbles:
			_crumble(pot)
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


# Round and round the way the arrow goes, at an easy pace.
func scripted_hold(delta: float, input: CookInput) -> bool:
	_scripted_angle -= TAU * minf(SCRIPTED_TURNS, (slow_speed + fast_speed) * 0.5) * delta  # A good pace, however gentle it has to be.
	input.stick = Vector2.from_angle(_scripted_angle)
	return false


# Where it stirs: the pot's middle, at its liquid.
func _middle(pot: CookSurface) -> Vector3:
	return Vector3(pot.position.x, pot.liquid_top(), pot.position.z)


# A wet spatula for folding, standing up with its blade in the pot.
func _make_spatula() -> Node3D:
	var holder := Node3D.new()
	session.add_child(holder)  # In the tree first: moved under it after, the spatula would end up meters away.
	var spatula := session.make_spatula()
	spatula.reparent(holder, false)
	spatula.rotation.x = deg_to_rad(-75.0)
	spatula.position = Vector3(0.0, 0.05, 0.0)
	return holder


# A curved arrow round the pot, going counter-clockwise seen from above: dashes
# round three quarters of a circle `arc_radius` across, and a head.
func _make_arrow(arc_radius: float) -> Node3D:
	var arrow := Node3D.new()
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(1.0, 0.85, 0.3, 0.8)
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
		mesh.size = Vector3(arc_radius * SWEEP / DASHES * 0.62, 0.003, 0.011)
		mesh.material = paint
		dash.mesh = mesh
		dash.position = Vector3(cos(angle), 0.0, sin(angle)) * arc_radius
		dash.rotation.y = atan2(cos(angle), sin(angle))  # Along the circle.
		arrow.add_child(dash)
		end_angle = angle - SWEEP / DASHES
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.022
	cone.height = 0.042
	cone.material = paint
	head.mesh = cone
	head.position = Vector3(cos(end_angle), 0.0, sin(end_angle)) * arc_radius
	head.rotation = Vector3(0.0, atan2(cos(end_angle), sin(end_angle)), -PI * 0.5)  # Its point along the circle, the way round.
	arrow.add_child(head)
	session.add_child(arrow)
	return arrow


# A balloon whisk, its origin at the bottom of the wires.
func _make_whisk() -> Node3D:
	var whisk := KitchenProps.whisk()
	session.add_child(whisk)
	return whisk


# A chunk (the nearest whole one to the whisk) breaks: it shrinks, and a flake
# of it floats off.
func _crumble(pot: CookSurface) -> void:
	var best: Node3D = null
	var best_gap := INF
	for piece in pot.contents:
		if piece is Node3D and is_instance_valid(piece) and not piece.has_meta("crumbled"):
			var gap := (piece as Node3D).global_position.distance_to(_whisk.global_position)
			if gap < best_gap:
				best_gap = gap
				best = piece
	if best == null:
		return
	best.set_meta("crumbled", true)
	best.create_tween().tween_property(best, "scale", best.scale * 0.6, 0.15)
	var flake := best.duplicate() as Node3D
	pot.add_child(flake)
	flake.scale = best.scale * 0.4
	flake.position = best.position + Vector3(randf_range(-0.03, 0.03), 0.0, randf_range(-0.03, 0.03))
	session.pop_text("Falling apart!", pot.position, -1)
