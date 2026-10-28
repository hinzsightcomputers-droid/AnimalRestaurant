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
@export var cursor_speed := 0.7            # Meters a second the stick moves the cursor.
@export var flick_strength := 0.8          # How far the stick has to go to count as a flick...
@export var flick_window := 0.2            # ...within this many seconds of leaving the center.
@export var flick_mouse_speed := 1.2       # Meters a second across the surface for a mouse swipe.
@export var bounds := Rect2(-0.64, -0.32, 1.28, 0.64)  # Where the cursor can go (x, z).
@export var work_height := 0.04            # Cursor height when a step doesn't ask for another.
@export_group("Feedback")
@export var text_size := 0.0017            # Pop-up text size.
@export var hint_top := 110.0              # Pixels from the top of the cook's view to the instructions.
@export var hint_font_size := 22

var recipe: CookRecipe
var player: Player
var ingredients: Ingredients = null        # What the cook brought, if anything (e.g. what to chop).
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


func start(cook_recipe: CookRecipe, cook: Player, view_manager: ViewManager, brought: Ingredients = null) -> void:
	recipe = cook_recipe
	player = cook
	ingredients = brought
	input = CookInput.new(self, cook.player_index, view_manager)
	input.cursor = Vector3(bounds.get_center().x, work_height, bounds.get_center().y)
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
	_cursor.visible = current != null and current.uses_cursor()
	_cursor.position = input.cursor + Vector3(0.0, 0.003, 0.0)
	_show_hint()


func _next_step() -> void:
	current = null
	_status = ""
	while _next < steps.size():
		var action := steps[_next]
		_next += 1
		action.begin(self)
		if action.background:
			_background.append(action)
			continue
		current = action
		input.height = action.cursor_height()
		return
	_finish()


func _finish() -> void:
	for action in _background:
		action.end()
	_background.clear()
	quality = CookRecipe.combine(steps)
	is_finished = true
	_cursor.visible = false
	_hint.text = "%s! %d%%" % [CookingMinigame.quality_label(quality), roundi(quality * 100)]
	play_sound("ding", Vector3(0.0, 0.1, 0.0))
	finished.emit(quality)


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
		if mesh_instance == _cursor or not mesh_instance.is_visible_in_tree() or mesh_instance.get_parent() is CookSurface:
			continue
		var placed := origin * mesh_instance.global_transform
		if Vector2(placed.origin.x, placed.origin.z).length() > plate.radius() * 1.3 or placed.origin.y < -0.03:
			continue
		parts.append({ "mesh": mesh_instance.mesh, "material": mesh_instance.material_override, "transform": placed })
	return parts


# A live line under the step's hint, e.g. "Syrup left: 40%".
func set_status(text: String) -> void:
	_status = text


func _show_hint() -> void:
	if current == null:
		return
	var lines := [current.title, _controls(current.hint)]
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

func surface(surface_name: String) -> CookSurface:
	return get_node_or_null(surface_name) as CookSurface


func clamp_to_bounds(point: Vector3) -> Vector3:
	point.x = clampf(point.x, bounds.position.x, bounds.end.x)
	point.z = clampf(point.z, bounds.position.y, bounds.end.y)
	return point


func add_piece(color: Color, thickness: float, at: Vector3, on_surface: String) -> CookPiece:
	var piece := CookPiece.new()
	add_child(piece)
	piece.setup(color, thickness)
	piece.position = at
	piece.surface = on_surface
	pieces.append(piece)
	return piece


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
	label.pixel_size = text_size
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
	_hint.offset_top = hint_top
	_hint.offset_left = 40.0
	_hint.offset_right = -40.0


func _build_cursor() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.012
	mesh.outer_radius = 0.02
	mesh.material = _flat_material(Color(1.0, 0.95, 0.6, 0.9))
	_cursor.mesh = mesh
	_cursor.scale.y = 0.3
	add_child(_cursor)


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
