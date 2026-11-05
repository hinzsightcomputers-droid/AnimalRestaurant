# CookSession: one player's close-up cook of a CookRecipe at a station. The
# root of a close-up scene (e.g. scenes/cooking/stovetop_closeup.tscn) that the
# station puts on itself; its CookSurface children are where food goes. It
# runs the recipe's steps in order (background steps alongside), reads the
# player's controls through one CookInput, and when the last step is done
# combines the steps' qualities and emits finished(quality). The step's
# instructions show at the top of the cook's own view.
#
# Everything here is in the session's own coordinates (y is up from the top
# of the station). Steps use the helpers below for the shared bits: pieces,
# stacks, sounds and feedback.
class_name CookSession
extends Node3D

signal finished(quality: float)

@export_group("Controls")
@export var cursor_speed := 0.7            # Meters a second the keys move the cursor.
@export var pad_cursor_speed := 1.6        # Meters a second a gamepad stick, pushed all the way, moves it.
@export var flick_strength := 0.8          # How far the stick has to go to count as a flick...
@export var flick_window := 0.2            # ...within this many seconds of leaving the center.
@export var flick_mouse_speed := 1.2       # Meters a second across the surface for a mouse swipe.
@export var bounds := Rect2(-0.64, -0.32, 1.28, 0.64)  # Where the cursor can go (x, z).
@export var work_height := 0.04            # Cursor height when a step doesn't ask for another.
@export_group("Feedback")
@export var text_size := 0.0017            # Pop-up text size.
@export var hint_top := 110.0              # Pixels from the top of the cook's view to the instructions.
@export var split_hint_top := 14.0         # The same in split screen: right at the top, off the close-up.
@export var hint_font_size := 22
@export var view_lift := 0.2                # A step's view looks this much (of its distance) above what it frames, so that sits under the instructions.

var recipe: CookRecipe
var player: Player
var ingredients: Ingredients = null        # What the cook brought, if anything (e.g. what to chop).
var context := {}                          # Anything else the steps need, set before start() (e.g. the dishes on a table).
var home_view: Array = []                  # [point, CameraZoomSettings]: the station's usual close-up view, set before start().
var input: CookInput
var steps: Array[CookAction] = []          # This session's own copies of the recipe's steps.
var current: CookAction = null
var pieces: Array[CookPiece] = []
var quality := 0.0
var is_finished := false

var _next := 0
var _background: Array[CookAction] = []
var _stacks := {}  # Surface name -> [{ node, at, height }], bottom first.
var _status := ""
var _cursor := MeshInstance3D.new()
var _screen: Control                       # The instructions' holder, on the cook's own view.
var _hint := Label.new()
var _framed := false                       # The camera is on a step's own view, not home_view.
var _text_scale := 1.0                      # Pop-up text shrinks when the camera comes in closer than the station's view.


func start(cook_recipe: CookRecipe, cook: Player, view_manager: ViewManager, brought: Ingredients = null) -> void:
	recipe = cook_recipe
	player = cook
	ingredients = brought
	input = CookInput.new(self, cook.player_index, view_manager)
	input.cursor = Vector3(0.0, work_height, 0.0)  # The middle of the station.
	if ingredients != null:  # A pot's broth takes on what's going in it.
		for child in get_children():
			if child is CookSurface and child.ingredient_tint > 0.0:
				child.tint(child.color.lerp(ingredients.color(), child.ingredient_tint))
	for step in recipe.steps:
		steps.append(step.duplicate(true))
	_build_cursor()
	_build_hint(view_manager)
	_next_step()


func _exit_tree() -> void:
	if _screen != null:
		_screen.queue_free()


func _process(delta: float) -> void:
	if is_finished or input == null:
		return
	input.update(delta)
	for action in _background.duplicate():
		action.update(delta, input)
		if action.done:
			action.end()
			_background.erase(action)
	if current != null:
		current.update(delta, input)
		if current.done:
			current.end()
			_next_step()
		elif current.to_background:  # Leaves something going (a tray in the oven) and lets the next step start.
			current.to_background = false
			_background.append(current)
			_next_step()
	_cursor.visible = current != null and current.uses_cursor()
	_cursor.position = input.cursor + Vector3(0.0, 0.003, 0.0)
	_show_hint()


func _next_step() -> void:
	current = null
	_status = ""
	while _next < steps.size():
		var action := steps[_next]
		_next += 1
		bring_in(action)
		action.begin(self)
		if action.done:  # Over before it started (e.g. nothing to reel in): no updates.
			action.end()
			continue
		if action.background:
			_background.append(action)
			continue
		current = action
		input.height = action.cursor_height()
		var area := action.cursor_area()
		if area.has_area():  # Start it in the middle of where the step is (and the camera will be).
			var middle := area.get_center()
			input.cursor = Vector3(middle.x, input.height, middle.y)
		_frame_step(action)
		if not action.cue.is_empty():
			pop_text(action.cue, action.view_point(), 1)
		return
	_finish()


func _finish() -> void:
	for action in _background:
		action.end()
	_background.clear()
	quality = CookRecipe.combine(steps)
	is_finished = true
	_cursor.visible = false
	if context.has("finish_text"):  # A step said how it went (e.g. "Caught a Bluegill!").
		_hint.text = context["finish_text"]
	elif recipe.finish_text.is_empty():
		_hint.text = "%s! %d%%" % [CookingMinigame.quality_label(quality), roundi(quality * 100)]
	else:
		_hint.text = recipe.finish_text
	play_sound("ding", Vector3(0.0, 0.1, 0.0))
	finished.emit(quality)


# Move the cook's camera to look at `at` (session coordinates) from in front,
# `distance` away, `pitch` degrees down, over `seconds`.
func frame(at: Vector3, distance: float, pitch: float, seconds := 0.5) -> void:
	var zoom := CameraZoomSettings.new()
	zoom.distance = distance
	zoom.pitch_degrees = pitch
	zoom.yaw_degrees = rad_to_deg(global_rotation.y)  # From the front, however the station turns.
	zoom.duration = seconds
	var tilt := deg_to_rad(pitch)
	at += Vector3(0.0, cos(tilt), -sin(tilt)) * distance * view_lift  # Up the screen.
	player.request_camera_focus(global_transform * at, zoom)
	_framed = true
	if home_view.size() == 2:
		_text_scale = minf(distance / (home_view[1] as CameraZoomSettings).distance, 1.0)


# A step with a view of its own gets it; one without goes back to the station's.
func _frame_step(action: CookAction) -> void:
	if action.view_distance > 0.0:
		frame(action.view_point(), action.view_distance, action.view_pitch, action.view_seconds)
	elif _framed and home_view.size() == 2:
		player.request_camera_focus(home_view[0], home_view[1])
		_framed = false
		_text_scale = 1.0


# The first step of a kind, e.g. step_of(HeatAction), or null.
func step_of(kind: Script) -> CookAction:
	for action in steps:
		if action.get_script() == kind:
			return action
	return null


# What's on a surface, as plain meshes for CookedDish.look: every visible mesh
# over it (not the surface itself), placed relative to its top middle.
func snapshot(surface_name: String) -> Array:
	var plate := surface(surface_name)
	var parts := []
	if plate == null:
		return parts
	var origin := plate.global_transform.affine_inverse()
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == _cursor or not mesh_instance.is_visible_in_tree() or (mesh_instance.get_parent() is CookSurface and not mesh_instance.has_meta("food")) or mesh_instance.transparency >= 1.0:
			continue
		var placed := origin * mesh_instance.global_transform
		if Vector2(placed.origin.x, placed.origin.z).length() > plate.radius() * 1.3 or placed.origin.y < -0.03:
			continue
		parts.append({ "mesh": mesh_instance.mesh, "material": mesh_instance.material_override, "transform": placed })
	return parts


# The cook's own view, full-size, for a step's on-screen bits (e.g. a tension
# meter). Freed with the session.
func overlay() -> Control:
	return _screen


# A live line under the step's hint, e.g. "Syrup left: 40%".
func set_status(text: String) -> void:
	_status = text


func _show_hint() -> void:
	if current == null:
		return
	var lines := [] if input.scripted else [current.title, _controls(current.hint)]  # Nobody watching a reel needs the controls.
	if not _status.is_empty():
		lines.append(_status)
	_hint.text = "\n".join(lines.filter(func(line): return not line.is_empty()))


# [button], [stick], [grip] (to hold) and [flick_up] in a hint, as this player's controls.
func _controls(text: String) -> String:
	var button := InputSetup.interact_hint(player.player_index)
	var stick := InputSetup.move_hint(player.player_index)
	var grip := "RT"
	var flick_up := "flick the right stick up"
	if InputSetup.pad_of(player.player_index) < 0:
		button += " (or click)"
		stick += " (or the mouse)"
		grip = button
		flick_up = "tap %s (or swipe the mouse up)" % InputSetup.up_hint(player.player_index)
	return text.replace("[button]", button).replace("[stick]", stick).replace("[grip]", grip).replace("[flick_up]", flick_up)


# --- Surfaces, pieces and stacks --------------------------------------------

# Slides in any surface out of sight (CookSurface.slides_in) that a step
# works with (its surface, target, from_surface or in_surface).
func bring_in(action: CookAction) -> void:
	for key in ["surface", "target", "from_surface", "in_surface", "into"]:
		var surface_name = action.get(key)
		if surface_name is String and not surface_name.is_empty() and surface(surface_name) != null:
			surface(surface_name).slide_in()


func surface(surface_name: String) -> CookSurface:
	return get_node_or_null(surface_name) as CookSurface


func clamp_to_bounds(point: Vector3) -> Vector3:
	point.x = clampf(point.x, bounds.position.x, bounds.end.x)
	point.z = clampf(point.z, bounds.position.y, bounds.end.y)
	var area := current.cursor_area() if current != null else Rect2()  # The step's own, if it has one.
	if area.has_area():
		point.x = clampf(point.x, area.position.x, area.end.x)
		point.z = clampf(point.z, area.position.y, area.end.y)
	return point


func add_piece(color: Color, thickness: float, at: Vector3, on_surface: String) -> CookPiece:
	var piece := CookPiece.new()
	add_child(piece)
	piece.setup(color, thickness)
	piece.position = at
	piece.surface = on_surface
	pieces.append(piece)
	return piece


# A surface's rectangle (x, z), `margin` bigger all round, e.g. for a step's cursor_area.
func area_of(surface_name: String, margin := 0.0) -> Rect2:
	var found := surface(surface_name)
	var size := Vector2(found.size.x, found.size.x if found.round else found.size.y)
	return Rect2(Vector2(found.position.x, found.position.z) - size * 0.5, size).grow(margin)


func pieces_on(surface_name: String) -> Array[CookPiece]:
	var found: Array[CookPiece] = []
	found.assign(pieces.filter(func(p): return p.surface == surface_name))
	return found


func stack_of(surface_name: String) -> Array:
	return _stacks.get(surface_name, [])


# The middle of the top of what's stacked on a surface (the surface itself when empty).
func stack_top(surface_name: String) -> Vector3:
	var stack := stack_of(surface_name)
	if stack.is_empty():
		return surface(surface_name).position
	var top: Dictionary = stack[-1]
	return top["at"] + Vector3(0.0, top["height"], 0.0)


# `node` goes on top of the stack, landing at `at`, `height` tall.
func stack_push(surface_name: String, node: Node3D, at: Vector3, height: float) -> void:
	_stacks.get_or_add(surface_name, []).append({ "node": node, "at": at, "height": height })


# The highest piece of food in a stack (not toppings), or null.
func top_piece(surface_name: String) -> CookPiece:
	var stack := stack_of(surface_name)
	for i in range(stack.size() - 1, -1, -1):
		if stack[i]["node"] is CookPiece:
			return stack[i]["node"]
	return null


# --- Feedback ----------------------------------------------------------------

# Words that float up and fade, e.g. "Golden!". good: green, bad: red, else white.
func pop_text(text: String, at: Vector3, mood := 0) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48
	label.outline_size = 14
	label.pixel_size = text_size * _text_scale
	label.modulate = [Color(1.0, 0.55, 0.45), Color.WHITE, Color(0.6, 1.0, 0.55)][clampi(mood + 1, 0, 2)]
	label.outline_modulate = Color(0.2, 0.12, 0.08)
	label.position = at + Vector3(0.0, 0.08, 0.0)
	add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.1, 1.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.6)
	tween.chain().tween_callback(label.queue_free)


# 1 for a score worth cheering, -1 for a bad one, 0 in between.
static func mood_of(score: float) -> int:
	return 1 if score >= 0.8 else (-1 if score < 0.45 else 0)


# A quick squash and stretch.
func wobble(node: Node3D, amount := 0.2) -> void:
	var tween := node.create_tween()
	var base := node.scale
	tween.tween_property(node, "scale", base * Vector3(1.0 + amount, 1.0 - amount, 1.0 + amount), 0.06)
	tween.tween_property(node, "scale", base, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# A little burst of bits (crumbs, splashes, sparkles).
func burst(at: Vector3, color: Color, amount := 12, speed := 0.35) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = 0.5
	particles.explosiveness = 0.95
	particles.direction = Vector3.UP
	particles.spread = 70.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0.0, -1.5, 0.0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0
	particles.mesh = _dot_mesh(0.008, color)
	particles.position = at
	add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func play_sound(sound: String, at: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var sound_player := AudioStreamPlayer3D.new()
	sound_player.stream = CookSounds.get_sound(sound)
	sound_player.volume_db = volume_db
	sound_player.pitch_scale = pitch * randf_range(0.93, 1.07)
	sound_player.unit_size = 6.0
	sound_player.position = at
	add_child(sound_player)
	sound_player.play()
	sound_player.finished.connect(sound_player.queue_free)


# A looping sound for a step to start and stop (it goes when the session does).
func loop_sound(sound: String, volume_db := 0.0) -> AudioStreamPlayer3D:
	var sound_player := AudioStreamPlayer3D.new()
	sound_player.stream = CookSounds.get_sound(sound)
	sound_player.volume_db = volume_db
	sound_player.unit_size = 6.0
	add_child(sound_player)
	return sound_player


# A squeeze bottle, its origin at the nozzle tip (the body is above it).
func make_bottle(liquid: Color) -> Node3D:
	var bottle := Node3D.new()
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = liquid
	body_material.roughness = 0.3
	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.034
	body_mesh.bottom_radius = 0.034
	body_mesh.height = 0.13
	body_mesh.material = body_material
	body.mesh = body_mesh
	body.position.y = 0.03 + 0.065
	bottle.add_child(body)
	var cap_material := StandardMaterial3D.new()
	cap_material.albedo_color = Color(0.95, 0.95, 0.92)
	var nozzle := MeshInstance3D.new()
	var nozzle_mesh := CylinderMesh.new()
	nozzle_mesh.top_radius = 0.004
	nozzle_mesh.bottom_radius = 0.022
	nozzle_mesh.height = 0.03
	nozzle_mesh.material = cap_material
	nozzle.mesh = nozzle_mesh
	nozzle.position.y = 0.015
	nozzle.rotation.x = PI  # Narrow end at the tip.
	bottle.add_child(nozzle)
	add_child(bottle)
	return bottle


# A spatula: a flat metal blade with its middle at the origin, and a handle
# running back toward the cook (+z) and up.
func make_spatula() -> Node3D:
	var spatula := Node3D.new()
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.82, 0.84, 0.87)
	metal.metallic = 0.7
	metal.roughness = 0.3
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.12, 0.004, 0.11)
	blade_mesh.material = metal
	blade.mesh = blade_mesh
	spatula.add_child(blade)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.28, 0.16)
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.009
	handle_mesh.bottom_radius = 0.011
	handle_mesh.height = 0.2
	handle_mesh.material = wood
	handle.mesh = handle_mesh
	handle.rotation.x = deg_to_rad(70.0)  # Lying back toward the cook, rising a little.
	handle.position = Vector3(0.0, 0.035, 0.055 + 0.094)
	spatula.add_child(handle)
	add_child(spatula)
	return spatula


# --- Cut pieces ----------------------------------------------------------------
# The pieces CutAction cuts (the context's "cookies") are flat discs of dough
# (a CylinderMesh each), which the later steps put things on and the oven
# browns. A piece can be given another look (dress): it goes see-through and
# the look, sharing its material so it browns the same, shows instead. Its
# footprint ("half": half its size across, x and z) and height ("top": of its
# top above its middle) are kept as metadata for the steps that need them.

func dress(cookie: MeshInstance3D, look: Node3D, half := Vector2.ZERO, top := -1.0) -> void:
	for child in cookie.get_children():
		if child.has_meta("look"):
			child.queue_free()
	look.set_meta("look", true)
	cookie.add_child(look)
	cookie.transparency = 1.0
	var material := (cookie.mesh as CylinderMesh).material as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Shapes made by hand (prism) show either way round.
	var meshes := look.find_children("*", "MeshInstance3D", true, false)
	if look is MeshInstance3D:
		meshes.append(look)
	for node: MeshInstance3D in meshes:
		if node.material_override == null and not node.has_meta("own_material"):
			node.material_override = material
	if half != Vector2.ZERO:
		cookie.set_meta("half", half)
	if top >= 0.0:
		cookie.set_meta("top", top)


# Half a piece's size across (x, z).
static func half_of(cookie: MeshInstance3D) -> Vector2:
	var radius := (cookie.mesh as CylinderMesh).top_radius
	return cookie.get_meta("half", Vector2(radius, radius))


# How far a piece's top is above its middle.
static func top_of(cookie: MeshInstance3D) -> float:
	return cookie.get_meta("top", (cookie.mesh as CylinderMesh).height * 0.5)


# Whether a point (x, z) is on a piece, going by its footprint (round ones by their circle).
static func on_piece(cookie: MeshInstance3D, point: Vector2) -> bool:
	var half := half_of(cookie)
	var offset := point - Vector2(cookie.position.x, cookie.position.z)
	if not cookie.has_meta("half"):
		return offset.length() <= half.x
	return absf(offset.x) <= half.x and absf(offset.y) <= half.y


# A flat shape `height` tall, standing on y = 0, from its outline (x, z),
# which must be convex (seen either side: give it a two-sided material).
static func prism(outline: PackedVector2Array, height: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := outline.size()
	var middle := Vector2.ZERO
	for point in outline:
		middle += point
	middle /= count
	for i in count:
		var a := outline[i]
		var b := outline[(i + 1) % count]
		tool.set_normal(Vector3.UP)
		for p in [middle, b, a]:
			tool.add_vertex(Vector3(p.x, height, p.y))
		tool.set_normal(Vector3.DOWN)
		for p in [middle, a, b]:
			tool.add_vertex(Vector3(p.x, 0.0, p.y))
		var side := (b - a).orthogonal().normalized() * -1.0
		tool.set_normal(Vector3(side.x, 0.0, side.y))
		for corner in [Vector3(a.x, 0.0, a.y), Vector3(b.x, height, b.y), Vector3(b.x, 0.0, b.y), Vector3(a.x, 0.0, a.y), Vector3(a.x, height, a.y), Vector3(b.x, height, b.y)]:
			tool.add_vertex(corner)
	return tool.commit()


# A row of balls along points (session or local), `radius` each (or tapering
# from radii[0] at the ends to radii[1] in the middle): a rope of dough.
static func rope(points: Array, radii: Vector2) -> Node3D:
	var rope_node := Node3D.new()
	var count := points.size()
	for i in count:
		var t := float(i) / maxf(count - 1, 1)
		var radius := lerpf(radii.x, radii.y, sin(t * PI))
		var ball := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 10
		mesh.rings = 5
		ball.mesh = mesh
		ball.position = points[i]
		rope_node.add_child(ball)
	return rope_node


# --- Meters and tools ---------------------------------------------------------

# A flat bar lying at `at` (or standing up, facing the camera), its good part
# marked in green: returns its fill bar (a child; use set_meter to fill it).
func make_meter(at: Vector3, length: float, band: Vector2, fill_color: Color, standing := false) -> MeshInstance3D:
	var meter := Node3D.new()
	meter.position = at
	if standing:
		meter.rotation.x = PI * 0.5
	add_child(meter)
	var parts := [
		[Vector3(length, 0.002, 0.04), 0.0, Color(0.2, 0.15, 0.1, 0.75), 0.0],
		[Vector3((band.y - band.x) * length, 0.003, 0.048), ((band.x + band.y) * 0.5 - 0.5) * length, Color(0.4, 0.95, 0.45, 0.65), 0.002],
		[Vector3(length, 0.004, 0.026), 0.0, fill_color, 0.004],
	]
	var fill: MeshInstance3D = null
	for part in parts:
		var mesh := BoxMesh.new()
		mesh.size = part[0]
		var material := _flat_material(part[2])
		material.render_priority = roundi(part[3] * 1000.0)
		mesh.material = material
		var bar := MeshInstance3D.new()
		bar.mesh = mesh
		bar.position = Vector3(part[1], part[3], 0.0)
		meter.add_child(bar)
		fill = bar
	fill.set_meta("length", length)
	set_meter(fill, 0.0)
	return fill


func set_meter(fill: MeshInstance3D, amount: float) -> void:
	var length: float = fill.get_meta("length")
	amount = clampf(amount, 0.0, 1.0)
	fill.scale.x = maxf(amount, 0.001)
	fill.position.x = (amount - 1.0) * length * 0.5


# A jug, its origin at the spout's tip (the body behind it, +x), tipping
# forward (rotation.z) to pour.
func make_jug(liquid: Color) -> Node3D:
	var jug := Node3D.new()
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.9, 0.95, 1.0, 0.45)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.035
	body_mesh.bottom_radius = 0.04
	body_mesh.height = 0.1
	body_mesh.material = glass
	body.mesh = body_mesh
	body.position = Vector3(0.04, 0.0, 0.0)
	jug.add_child(body)
	var inside := MeshInstance3D.new()
	var inside_mesh := CylinderMesh.new()
	inside_mesh.top_radius = 0.031
	inside_mesh.bottom_radius = 0.036
	inside_mesh.height = 0.06
	var filling := StandardMaterial3D.new()
	filling.albedo_color = liquid
	inside_mesh.material = filling
	inside.mesh = inside_mesh
	inside.position = Vector3(0.04, -0.018, 0.0)
	jug.add_child(inside)
	var spout := MeshInstance3D.new()
	var spout_mesh := CylinderMesh.new()
	spout_mesh.top_radius = 0.006
	spout_mesh.bottom_radius = 0.014
	spout_mesh.height = 0.04
	spout_mesh.material = glass
	spout.mesh = spout_mesh
	spout.position = Vector3(0.0, 0.04, 0.0)
	spout.rotation.z = deg_to_rad(50.0)
	jug.add_child(spout)
	add_child(jug)
	return jug


# A pastry brush, its origin at the bristles' tip, the handle up and back.
func make_brush() -> Node3D:
	var brush := Node3D.new()
	var bristles := MeshInstance3D.new()
	var bristle_mesh := BoxMesh.new()
	bristle_mesh.size = Vector3(0.035, 0.03, 0.01)
	var hair := StandardMaterial3D.new()
	hair.albedo_color = Color(0.95, 0.85, 0.55)
	bristle_mesh.material = hair
	bristles.mesh = bristle_mesh
	bristles.position.y = 0.015
	brush.add_child(bristles)
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.007
	handle_mesh.bottom_radius = 0.009
	handle_mesh.height = 0.12
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.6, 0.38, 0.2)
	handle_mesh.material = wood
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, 0.09, 0.0)
	brush.add_child(handle)
	brush.rotation.x = deg_to_rad(25.0)  # Leaning back toward the cook.
	add_child(brush)
	return brush


# Kitchen tongs, their tips at the origin, pointing down; `opened` 0 to 1.
func make_tongs() -> Node3D:
	var tongs := Node3D.new()
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.82, 0.84, 0.87)
	metal.metallic = 0.7
	metal.roughness = 0.3
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.008, 0.16, 0.012)
		mesh.material = metal
		arm.mesh = mesh
		arm.position = Vector3(side * 0.02, 0.08, 0.0)
		arm.rotation.z = side * 0.18
		arm.name = "Left" if side < 0.0 else "Right"
		tongs.add_child(arm)
	tongs.rotation.x = deg_to_rad(20.0)
	add_child(tongs)
	return tongs


# A flat ring on the surface, e.g. to show how big a pour should be.
func make_ring(ring_radius: float, color := Color(1.0, 1.0, 1.0, 0.55)) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = ring_radius - 0.003
	mesh.outer_radius = ring_radius + 0.003
	mesh.material = _flat_material(color)
	ring.mesh = mesh
	ring.scale.y = 0.3
	add_child(ring)
	return ring


# A flat yellow arrow `length` long, lying on the surface pointing along +x
# (turn it with rotation.y), drawn over everything; with both_ways it has a
# head at each end.
func make_arrow(length: float, both_ways := false) -> Node3D:
	var arrow := Node3D.new()
	var paint := _flat_material(Color(1.0, 0.85, 0.3, 0.95))
	paint.no_depth_test = true
	paint.render_priority = 2
	var head_length := minf(0.035, length * 0.3)
	var shaft := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(length - head_length * (2.0 if both_ways else 1.0), 0.003, head_length * 0.35)
	bar.material = paint
	shaft.mesh = bar
	shaft.position.x = -head_length * 0.5 if not both_ways else 0.0
	arrow.add_child(shaft)
	for way in ([1.0, -1.0] if both_ways else [1.0]):
		var head := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = head_length * 0.6
		cone.height = head_length
		cone.material = paint
		head.mesh = cone
		head.position.x = way * (length * 0.5 - head_length * 0.5)
		head.rotation.z = -PI * 0.5 * way  # Its point outward.
		head.scale.x = 0.25  # Flat on the surface.
		arrow.add_child(head)
	add_child(arrow)
	return arrow


# An arrow up the screen for "flick up", hidden until show_flick puts it over
# something (each frame, so it bobs).
func make_flick_arrow() -> Node3D:
	var arrow := make_arrow(0.08)
	arrow.rotation.y = PI * 0.5
	arrow.visible = false
	return arrow


func show_flick(arrow: Node3D, over: Vector3) -> void:
	arrow.visible = true
	arrow.position = over + Vector3(0.0, 0.02, -0.008 * (1.0 + sin(Time.get_ticks_msec() * 0.01)))


# The step's instructions, at the top of the cook's own view (just theirs in split screen).
func _build_hint(view_manager: ViewManager) -> void:
	_screen = Control.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ConversationBox.parent_for(view_manager, player.player_index, self).add_child(_screen)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", hint_font_size)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
	_hint.add_theme_color_override("font_outline_color", Color(0.2, 0.13, 0.08))
	_hint.add_theme_constant_override("outline_size", 8)
	_screen.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	# With 2+ players a cook always has a view of their own, a small one.
	_hint.offset_top = split_hint_top if InputSetup.active_players().size() > 1 else hint_top
	_hint.offset_left = 40.0
	_hint.offset_right = -40.0


# A bright dot, drawn over everything, gently pulsing. Steps where a tool or
# a held piece already shows the spot hide it (uses_cursor).
func _build_cursor() -> void:
	_cursor.mesh = _dot_mesh(0.0125, Color(1.0, 0.92, 0.35, 0.99))
	(_cursor.mesh.material as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	(_cursor.mesh.material as StandardMaterial3D).no_depth_test = true
	add_child(_cursor)
	var pulse := _cursor.create_tween().set_loops()
	pulse.tween_property(_cursor, "scale", Vector3.ONE * 1.2, 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_cursor, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.no_depth_test = true
	return material


func _dot_mesh(dot_radius: float, color: Color) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = dot_radius
	mesh.height = dot_radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true  # So particles can tint it.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	mesh.material = material
	return mesh


# Steam rising off something; steps set emitting and color as it cooks.
func make_steam(at_radius: float) -> CPUParticles3D:
	var steam := CPUParticles3D.new()
	steam.amount = 10
	steam.lifetime = 1.3
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = at_radius * 0.7
	steam.direction = Vector3.UP
	steam.spread = 15.0
	steam.initial_velocity_min = 0.05
	steam.initial_velocity_max = 0.12
	steam.gravity = Vector3(0.0, 0.08, 0.0)
	steam.scale_amount_min = 1.0
	steam.scale_amount_max = 2.2
	steam.mesh = _dot_mesh(0.01, Color(1.0, 1.0, 1.0, 0.3))
	steam.emitting = false
	return steam
