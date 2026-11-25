# CookSession: one player's close-up cook of a CookRecipe at a station. The
# root of a close-up scene (e.g. scenes/cooking/stovetop_closeup.tscn) that the
# station puts on itself; its CookSurface children are where food goes. It
# runs the recipe's steps in order (background steps alongside), reads the
# player's controls through one CookInput, and when the last step is done
# combines the steps' qualities and emits finished(quality). The step's
# instructions show at the top of the cook's own view, and a real cooking tip or
# fact about the dish (data/cooking_facts.json) in its bottom-right corner.
#
# Everything here is in the session's own coordinates (y is up from the top
# of the station). Steps use the helpers below for the shared bits: pieces,
# stacks, sounds and feedback.
class_name CookSession
extends Node3D

signal finished(quality: float)

const REEL_HINT_SIZE := 36
const CARD_WIDTH := 640.0                  # The instructions card's text width (it wraps inside).
const CARD_MARGIN := 18.0
const HOW_SIZE := 0.72                     # The controls line, times hint_font_size.
const HOW_SECONDS := 6.0                   # The controls show this long at a step's start, then fold away (just the title and progress stay).
const STATUS_SIZE := 0.86
const CARD_TEXT := Color("#502312")
const CARD_STATUS := Color("#C2542A")
const FACTS_PATH := "res://data/cooking_facts.json"
const FACT_WIDTH := 330.0                  # The tip card's text width (smaller in split screen).
const FACT_SPLIT_WIDTH := 230.0
const FACT_MARGIN := 24.0                  # From the corner of the cook's view.
const SMALL_VIEW_PLAYERS := 3               # This many players or more: a quarter-screen view (ViewManager's four-way split)...
const SMALL_VIEW_MARKS := 1.7              # ...where the cursor, rings, outlines and meters are drawn this much bolder...
const SMALL_CARD_WIDTH := 560.0            # ...and the instructions are kept small.
const FACT_SECONDS := 20.0                 # A long step without a tip of its own moves on to the next fact.

@export_group("Controls")
@export var cursor_speed := 0.7            # Meters a second the keys move the cursor.
@export var pad_cursor_speed := 1.6        # Meters a second a gamepad stick, pushed all the way, moves it.
@export var flick_strength := 0.8          # How far the stick has to go to count as a flick...
@export var flick_window := 0.2            # ...within this many seconds of leaving the center.
@export var flick_mouse_speed := 1.2       # Meters a second across the surface for a mouse swipe.
@export var bounds := Rect2(-0.64, -0.32, 1.28, 0.64)  # Where the cursor can go (x, z).
@export var work_height := 0.04            # Cursor height when a step doesn't ask for another.
@export var worktop := false               # A butcher-block top under the whole work area while cooking (a close-up spread over loud counters).
@export_group("Feedback")
@export var text_size := 0.0017            # Pop-up text size.
@export var hint_top := 110.0              # Pixels from the top of the cook's view to the instructions.
@export var split_hint_top := 14.0         # The same in split screen: right at the top, off the close-up.
@export var hint_font_size := 22
@export var view_lift := 0.25               # A step's view looks this much (of its distance) above what it frames, so that sits under the instructions.

var recipe: CookRecipe
var player: Player
var ingredients: Ingredients = null        # What the cook brought, if anything (e.g. what to chop).
var context := {}                          # Anything else the steps need, set before start() (e.g. the dishes on a table).
var sharp_to := 0.0                        # How far past its middle the view stays sharp (0: BLUR_FROM), e.g. all the way to a cast bobber.
var home_view: Array = []                  # [point, CameraZoomSettings]: the station's usual close-up view, set before start().
var input: CookInput
var steps: Array[CookAction] = []          # This session's own copies of the recipe's steps.
var current: CookAction = null
var pieces: Array[CookPiece] = []
var quality := 0.0
var is_finished := false
var small_view := false                    # Cooking in a quarter of the screen: bolder marks, smaller words.

var _next := 0
var _background: Array[CookAction] = []
var _stacks := {}  # Surface name -> [{ node, at, height }], bottom first.
var _status := ""
var _cursor := MeshInstance3D.new()
var _spot := MeshInstance3D.new()          # A ring on the spot under a tool that's held up (CookAction.marks_spot).
var _screen: Control                       # The instructions' holder, on the cook's own view.
var _hint := Label.new()                   # The step's name (a reel: the recipe's), then how it went.
var _how := Label.new()                    # The controls, smaller, under it.
var _status_label := Label.new()           # The live line, e.g. "Chops left: 5".
var _card := PanelContainer.new()          # Holds the three: a cream card, so nothing cooking shows through the words.
var _pops: Array[Label3D] = []             # Pop-up words still showing (one at a time, so they never pile up).
var _framed := false                       # The camera is on a step's own view, not home_view.
var _text_scale := 1.0                      # Pop-up text shrinks when the camera comes in closer than the station's view.
var _how_time := 0.0                       # How long this step's controls have been showing.
var _home_lifted := false                  # The station's own view has been moved down under the card.
var _fact_card := PanelContainer.new()     # "Chef's tip" and the tip, in the bottom-right corner.
var _fact_label := Label.new()
var _facts: Array = []                     # This recipe's dish facts, in turn...
var _fact_next := 0
var _fact_time := 0.0                      # ...and how long the one showing has been up.
var _fact_is_tip := false                  # The card shows the current step's own tip.
static var _all_facts := {}                # data/cooking_facts.json's recipes, loaded once.


func start(cook_recipe: CookRecipe, cook: Player, view_manager: ViewManager, brought: Ingredients = null) -> void:
	recipe = cook_recipe
	player = cook
	small_view = InputSetup.active_players().size() >= SMALL_VIEW_PLAYERS
	ingredients = brought
	input = CookInput.new(self, cook.player_index, view_manager)
	input.cursor = Vector3(0.0, work_height, 0.0)  # The middle of the station.
	if ingredients != null:  # A pot's broth takes on what's going in it.
		for child in get_children():
			if child is CookSurface and child.ingredient_tint > 0.0:
				child.tint(child.color.lerp(ingredients.color(), child.ingredient_tint))
	for step in recipe.steps:
		steps.append(step.duplicate(true))
	if worktop:
		_build_worktop()
	_build_cursor()
	_build_hint(view_manager)
	_blur_background(view_manager.rig_for(cook.player_index) if view_manager != null else null)
	react("cooking")  # Focused till they're done.
	_next_step()


func _exit_tree() -> void:
	if _blurred != null and is_instance_valid(_blurred) and _blurred.attributes == _blur:
		_blurred.attributes = null
	if player != null and is_instance_valid(player):
		ChefReactions.release(get_tree(), "cooking", player.player_index)
	if _screen != null:
		_screen.queue_free()


func _process(delta: float) -> void:
	_follow_blur()
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
	_spot.visible = current != null and not _cursor.visible and current.marks_spot() and not input.scripted
	_spot.position = _cursor.position
	_clear_the_cursor(delta)
	_how_time += delta
	_show_hint()
	_fact_time += delta
	if not _fact_is_tip and _fact_time >= FACT_SECONDS and _facts.size() > 1:
		_show_fact(_next_fact())


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
		var middle := action.view_point()  # Start in the middle of where the step is (and the camera will be).
		if area.has_area():
			middle = Vector3(area.get_center().x, 0.0, area.get_center().y)
		input.new_step(clamp_to_bounds(middle), action.keeps_press())
		_how_time = 0.0
		_frame_step(action)
		_fact_for(action)
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
	_spot.visible = false
	if context.has("finish_text"):  # A step said how it went (e.g. "Caught a Bluegill!").
		_hint.text = context["finish_text"]
	elif recipe.finish_text.is_empty():
		_hint.text = "%s! %d%%" % [CookingMinigame.quality_label(quality), roundi(quality * 100)]
	else:
		_hint.text = recipe.finish_text
	_fact_card.visible = false
	_how.visible = false
	_status_label.visible = false
	play_sound("ding", Vector3(0.0, 0.1, 0.0))
	if quality >= SPARKLE_FROM and not steps.is_empty():
		sparkle(steps[-1].view_point() + Vector3(0.0, 0.06, 0.0))
	finished.emit(quality)


# The style guide's close-up: the station sharp, the kitchen behind it a warm
# blur, on the cook's own camera while they cook (put back after).
const SPARKLE_FROM := 0.85     # A dish this good gets a sparkle as it's done.
const BLUR_FROM := 0.45        # Meters past the station's middle where the blur starts (just behind its back edge: all of the cooking stays sharp)...
const BLUR_OVER := 0.5         # ...and how far it takes to reach full.
const BLUR_AMOUNT := 0.12
var _blur: CameraAttributesPractical = null
var _blurred: Camera3D = null
func _blur_background(rig: CameraRig) -> void:
	if rig == null or rig.camera == null or rig.camera.attributes != null:
		return
	_blur = CameraAttributesPractical.new()
	_blur.dof_blur_far_enabled = true
	_blur.dof_blur_far_transition = BLUR_OVER
	_blur.dof_blur_amount = BLUR_AMOUNT
	_blurred = rig.camera
	_blurred.attributes = _blur
	_follow_blur()


# The camera moves between views (and back out for the whole station), so the
# blur's start follows it: always just behind the station, never on the food.
func _follow_blur() -> void:
	if _blur != null and is_instance_valid(_blurred):
		_blur.dof_blur_far_distance = _blurred.global_position.distance_to(global_position) + (BLUR_FROM if sharp_to <= 0.0 else sharp_to)


# Move the cook's camera to look at `at` (session coordinates) from in front,
# `distance` away, `pitch` degrees down, over `seconds`.
func frame(at: Vector3, distance: float, pitch: float, seconds := 0.5) -> void:
	var zoom := CameraZoomSettings.new()
	zoom.distance = distance
	zoom.pitch_degrees = pitch
	zoom.yaw_degrees = rad_to_deg(global_rotation.y)  # From the front, however the station turns.
	zoom.duration = seconds
	player.request_camera_focus(global_transform * _lifted(at, distance, pitch), zoom)
	_framed = true
	if home_view.size() == 2:
		_text_scale = minf(distance / (home_view[1] as CameraZoomSettings).distance, 1.0)


# A step with a view of its own gets it; one without goes back to the station's.
func _frame_step(action: CookAction) -> void:
	if action.view_distance > 0.0:
		frame(action.view_point(), action.view_distance, action.view_pitch, action.view_seconds)
	elif (_framed or not _home_lifted) and home_view.size() == 2:
		var home := home_view[1] as CameraZoomSettings
		var point: Vector3 = home_view[0]
		var lifted := point
		if home != null:  # Up the screen, as this view sees it (its own yaw, in the world).
			var pitch := deg_to_rad(home.pitch_degrees)
			var yaw := deg_to_rad(home.yaw_degrees)
			lifted += Vector3(-sin(yaw) * sin(pitch), cos(pitch), -cos(yaw) * sin(pitch)) * home.distance * view_lift
		player.request_camera_focus(lifted, home)
		_framed = false
		_home_lifted = true
		_text_scale = 1.0


# A point a view looks at, moved up the screen by view_lift of its distance, so
# what it frames sits under the instructions card (local to the session).
func _lifted(at: Vector3, distance: float, pitch: float) -> Vector3:
	var tilt := deg_to_rad(pitch)
	return at + Vector3(0.0, cos(tilt), -sin(tilt)) * distance * view_lift


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
		if mesh_instance == _cursor or mesh_instance.get_parent() == _cursor or mesh_instance == _spot or mesh_instance.get_parent() == _spot or not mesh_instance.is_visible_in_tree() or (mesh_instance.get_parent() is CookSurface and not mesh_instance.has_meta("food")) or mesh_instance.transparency >= 1.0:
			continue
		var placed := origin * mesh_instance.global_transform
		if Vector2(placed.origin.x, placed.origin.z).length() > plate.radius() * 1.3 or placed.origin.y < -0.03:
			continue
		parts.append({ "mesh": mesh_instance.mesh, "material": mesh_instance.material_override, "transform": placed })
	return parts


# For a reel: the words at the top, big enough to read on a phone.
func big_hint() -> void:
	_hint.add_theme_font_size_override("font_size", REEL_HINT_SIZE)


# The cook's own view, full-size, for a step's on-screen bits (e.g. a tension
# meter). Freed with the session.
func overlay() -> Control:
	return _screen


# A live line under the step's hint, e.g. "Syrup left: 40%".
# The cook pulls a face (a ChefReactions trigger, e.g. "dish_burning").
func react(trigger: String) -> void:
	if player != null:
		ChefReactions.react(get_tree(), trigger, player.player_index)


func set_status(text: String) -> void:
	_status = text


# The cards go see-through while the cursor's under them, so it never gets lost there.
const CARD_FADED := 0.22
func _clear_the_cursor(delta: float) -> void:
	var at := input.screen_point(input.cursor) if not input.scripted and _screen != null and current != null and current.aims() else Vector2.INF
	for card: Control in [_card, _fact_card]:
		var view := _screen.get_global_rect() if _screen != null else Rect2()
		var under := at != Vector2.INF and card.get_global_rect().grow(18.0).has_point(view.position + at * view.size)
		card.modulate.a = lerpf(card.modulate.a, CARD_FADED if under else 1.0, 1.0 - exp(-12.0 * delta))


func _show_hint() -> void:
	if current == null:
		return
	_hint.text = recipe.display_name if input.scripted else current.title
	_how.text = "" if input.scripted else _controls(current.hint)  # Nobody watching a reel needs the controls.
	_how.visible = not _how.text.is_empty() and _how_time < HOW_SECONDS
	_status_label.text = _status
	_status_label.visible = not _status.is_empty()
	_style_card(input.scripted)


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


# How high whatever's on a surface is at a point (Vector2 of x and z -> session
# height, INF off the surface): the food, its edges rounded, things on it (butter)
# and the surface itself. For a SauceSheet; it's as things are now.
func lie_on(surface_name: String) -> Callable:
	var place := surface(surface_name)
	var foods: Array[CookPiece] = []
	var bumps := []  # [box] of everything else.
	for entry in stack_of(surface_name):
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		if node is CookPiece:
			foods.push_front(node)
			continue
		var to_session := global_transform.affine_inverse()
		var meshes := node.find_children("*", "MeshInstance3D", true, false)
		if node is MeshInstance3D:
			meshes.append(node)
		for mesh: MeshInstance3D in meshes:
			if mesh.get_parent() is SauceSheet:
				continue
			bumps.append((to_session * mesh.global_transform) * mesh.get_aabb())
	return func(point: Vector2) -> float:
		if not place.contains(Vector3(point.x, 0.0, point.y), -0.004):
			return INF
		var top := place.position.y
		for food in foods:
			if is_instance_valid(food):
				top = maxf(top, food.height_at(point))
		for box: AABB in bumps:
			var from_middle := (point - Vector2(box.get_center().x, box.get_center().z)) / (Vector2(box.size.x, box.size.z) * 0.5)
			var out := maxf(absf(from_middle.x), absf(from_middle.y))
			if out < 1.0:
				top = maxf(top, box.position.y + box.size.y * sqrt(1.0 - pow(out, 4.0)))
		return top


# A sauce over what's on a surface (SauceSheet.KINDS).
func make_sauce(surface_name: String, kind: String, color: Color) -> SauceSheet:
	var area := area_of(surface_name)
	var side := maxf(area.size.x, area.size.y)
	return SauceSheet.make(self, Rect2(area.get_center() - Vector2.ONE * side * 0.5, Vector2.ONE * side), surface(surface_name).position.y, kind, color, lie_on(surface_name))


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
	label.render_priority = 20  # Over sauces and steam.
	label.outline_render_priority = 19
	label.font_size = 48
	label.outline_size = 14
	UiStyle.title(label)
	label.pixel_size = text_size * _text_scale
	label.modulate = [Color(1.0, 0.55, 0.45), Color.WHITE, Color(0.6, 1.0, 0.55)][clampi(mood + 1, 0, 2)]
	label.outline_modulate = Color(0.2, 0.12, 0.08)
	label.position = at + Vector3(0.0, 0.08, 0.0)
	for old in _pops:  # The one before goes: words never stack.
		if is_instance_valid(old):
			old.queue_free()
	_pops = [label]
	add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.1, 1.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.6)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.5).set_delay(0.6)
	tween.chain().tween_callback(label.queue_free)


# 1 for a score worth cheering, -1 for a bad one, 0 in between.
static func mood_of(score: float) -> int:
	return 1 if score >= 0.8 else (-1 if score < 0.45 else 0)


# How much bolder marks are drawn: rings, outlines, the cursor, meters.
func _marks() -> float:
	return SMALL_VIEW_MARKS if small_view else 1.0


# A quick squash and stretch.
func wobble(node: Node3D, amount := 0.2) -> void:
	if node is CookPiece and not (node as CookPiece).kind in ["bacon", "churro"] and not (node as CookPiece).folded:  # Soft all by itself.
		(node as CookPiece).jolt(amount)
		return
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
	particles.mesh = dot_mesh(0.008, color)
	particles.position = at
	add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


const LOOP_MOMENT := 0.4  # How long play_sound plays a looping sound.
func play_sound(sound: String, at: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var sound_player := AudioStreamPlayer3D.new()
	sound_player.stream = CookSounds.get_sound(sound)
	sound_player.volume_db = volume_db
	sound_player.pitch_scale = pitch * randf_range(0.93, 1.07)
	sound_player.unit_size = 6.0
	sound_player.position = at
	add_child(sound_player)
	sound_player.play()
	if sound in CookSounds.LOOPS:  # A moment of one that goes on forever (a splash of pouring): it fades, or they pile up.
		var fade := sound_player.create_tween()
		fade.tween_interval(LOOP_MOMENT)
		fade.tween_property(sound_player, "volume_db", -50.0, 0.25)
		fade.tween_callback(sound_player.queue_free)
		return
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
	var body_mesh := CapsuleMesh.new()  # A soft squeezy body, rounded at both ends.
	body_mesh.radius = 0.032
	body_mesh.height = 0.13
	body_mesh.radial_segments = 16
	body_mesh.material = body_material
	body.mesh = body_mesh
	body.position.y = 0.03 + 0.065
	bottle.add_child(body)
	var cap_material := StandardMaterial3D.new()
	cap_material.albedo_color = KitchenProps.CREAM
	cap_material.roughness = 0.45
	var collar := MeshInstance3D.new()  # The screw cap the nozzle sits on.
	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = 0.026
	collar_mesh.bottom_radius = 0.024
	collar_mesh.height = 0.016
	collar_mesh.radial_segments = 16
	collar_mesh.material = cap_material
	collar.mesh = collar_mesh
	collar.position.y = 0.036
	bottle.add_child(collar)
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
	var metal := KitchenProps.steel().duplicate() as StandardMaterial3D
	metal.albedo_color = Color(0.5, 0.49, 0.48)  # Dark enough not to glare under the griddle lamp.
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.12, 0.004, 0.11)
	blade_mesh.material = metal
	blade.mesh = blade_mesh
	spatula.add_child(blade)
	var wood := KitchenProps.handle_wood()
	# A short metal neck bends up off the back of the blade, so the handle starts
	# above the food and doesn't run through what's next to the blade.
	var neck := MeshInstance3D.new()
	var neck_mesh := BoxMesh.new()
	neck_mesh.size = Vector3(0.014, 0.004, 0.05)
	neck_mesh.material = metal
	neck.mesh = neck_mesh
	neck.rotation.x = deg_to_rad(-45.0)  # Rising toward the cook.
	neck.position = Vector3(0.0, 0.017, 0.055 + 0.017)
	spatula.add_child(neck)
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.009
	handle_mesh.bottom_radius = 0.011
	handle_mesh.height = 0.2
	handle_mesh.material = wood
	handle.mesh = handle_mesh
	handle.rotation.x = deg_to_rad(45.0)  # Back toward the cook and well up, clear of the food round the blade.
	var start := Vector3(0.0, 0.034, 0.089)  # The top of the neck.
	handle.position = start + Vector3(0.0, cos(handle.rotation.x), sin(handle.rotation.x)) * 0.1
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


# Rings running out over open water from a point, fading as they go, and drops
# thrown up with them if it's hit hard.
func water_rings(at: Vector3, reach: float, drops := 0, speed := 0.6) -> void:
	for i in 3:
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.93
		mesh.outer_radius = 1.0
		mesh.rings = 48
		mesh.ring_segments = 6
		var paint := _flat_material(Color(0.93, 0.98, 1.0, 0.6))
		paint.no_depth_test = false  # Not over a dock.
		mesh.material = paint
		ring.mesh = mesh
		ring.position = at + Vector3(0.0, 0.03, 0.0)
		ring.scale = Vector3(0.02, 0.02, 0.02)
		add_child(ring)
		var wide := reach * (1.0 - 0.25 * i)
		var run := ring.create_tween().set_parallel(true)
		run.tween_property(ring, "scale", Vector3(wide, 0.02, wide), 1.1).set_delay(i * 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		run.tween_property(paint, "albedo_color:a", 0.0, 1.1).set_delay(i * 0.16)
		run.chain().tween_callback(ring.queue_free)
	if drops > 0:
		burst(at, Color(0.86, 0.94, 1.0, 0.85), drops, speed)
		burst(at, Color(1.0, 1.0, 1.0, 0.9), drops / 2, speed * 1.4)


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


# A rope of dough along points (session or local), smooth and round, radii.x
# thick at its ends and radii.y in the middle; where it crosses over itself, the
# later part lies on top. With bands, it's rolled up in so many layers (a croissant).
static func rope(points: Array, radii: Vector2, bands := 0) -> Node3D:
	var rope_node := Node3D.new()
	var look := MeshInstance3D.new()
	look.mesh = rope_mesh(points, radii, bands)
	rope_node.add_child(look)
	return rope_node


static func rope_mesh(points: Array, radii: Vector2, bands := 0) -> ArrayMesh:
	const AROUND := 14
	var path: Array[Vector3] = []
	var count := points.size()
	var between := 3 if bands == 0 else 10
	for i in count - 1:
		var before: Vector3 = points[maxi(i - 1, 0)]
		var after: Vector3 = points[mini(i + 2, count - 1)]
		for k in between:
			path.append((points[i] as Vector3).cubic_interpolate(points[i + 1], before, after, float(k) / between))
	path.append(points[count - 1])
	var total := path.size()
	var thick: Array[float] = []
	for i in total:
		var t := float(i) / maxf(total - 1, 1)
		var radius := lerpf(radii.x, radii.y, sin(t * PI))
		if bands > 0:  # Each layer steps up to the next, nearer the middle.
			var from_middle := absf(t - 0.5) * 2.0
			radius *= 0.86 + 0.24 * (1.0 - fposmod(from_middle * bands * 0.5, 1.0))
		thick.append(radius)
	if bands == 0:
		var lifts: Array[float] = []
		for i in total:
			var lift := 0.0
			for j in i:
				var apart := Vector2(path[i].x - path[j].x, path[i].z - path[j].z).length()
				if (i - j) * 1.0 > total * 0.12:
					lift = maxf(lift, radii.y * 1.1 * (1.0 - smoothstep(radii.y * 0.8, radii.y * 2.4, apart)))
			lifts.append(lift)
		for i in total:
			path[i].y += lifts[i]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	var rings: Array = []  # [middle, along, radius]: its length, and a rounded end at each end.
	for i in total:
		var along := (path[mini(i + 1, total - 1)] - path[maxi(i - 1, 0)])
		along = along.normalized() if along.length() > 0.000001 else Vector3.RIGHT
		if i == 0:
			for k in 5:
				var turn := PI * 0.5 * k / 5.0
				rings.append([path[0] - along * thick[0] * cos(turn), along, maxf(thick[0] * sin(turn), 0.0002)])
		rings.append([path[i], along, thick[i]])
		if i == total - 1:
			for k in 5:
				var turn := PI * 0.5 * (k + 1) / 5.0
				rings.append([path[i] + along * thick[i] * sin(turn), along, maxf(thick[i] * cos(turn), 0.0002)])
	for ring in rings:
		var side := (ring[1] as Vector3).cross(Vector3.UP)
		side = side.normalized() if side.length() > 0.001 else Vector3.RIGHT
		var up := side.cross(ring[1]).normalized()
		for k in AROUND + 1:
			var turn := TAU * k / AROUND
			tool.add_vertex(ring[0] + (side * cos(turn) + up * sin(turn)) * float(ring[2]))
	for i in rings.size() - 1:
		for k in AROUND:
			var c := i * (AROUND + 1) + k
			var d := c + AROUND + 1
			for index in [c, c + 1, d, c + 1, d + 1, d]:
				tool.add_index(index)
	tool.generate_normals()
	return tool.commit()


# --- Meters and tools ---------------------------------------------------------

# A flat bar lying at `at` (or standing up, facing the camera), its good part
# marked in green: returns its fill bar (a child; use set_meter to fill it).
func make_meter(at: Vector3, length: float, band: Vector2, fill_color: Color, standing := false) -> MeshInstance3D:
	var meter := Node3D.new()
	meter.position = at
	if standing:
		meter.rotation.x = PI * 0.5
	add_child(meter)
	var thick := 1.0 + (_marks() - 1.0) * 0.5
	var parts := [
		[Vector3(length, 0.002, 0.04 * thick), 0.0, Color(0.2, 0.15, 0.1, 0.75), 0.0],
		[Vector3((band.y - band.x) * length, 0.003, 0.048 * thick), ((band.x + band.y) * 0.5 - 0.5) * length, Color(0.4, 0.95, 0.45, 0.65), 0.002],
		[Vector3(length, 0.004, 0.026 * thick), 0.0, fill_color, 0.004],
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
	var wood := KitchenProps.handle_wood()
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
	var metal := KitchenProps.steel()
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
# A thin white box outline lying on a surface at height `y`: a zone to put
# things in (Rect2 on x/z, like a cursor area).
func make_box_outline(box: Rect2, y: float, color := Color(1.0, 1.0, 1.0, 0.55)) -> Node3D:
	var outline := Node3D.new()
	var line := 0.006 * _marks()
	var paint := _flat_material(color)
	var middle := Vector3(box.get_center().x, y + 0.002, box.get_center().y)
	for side in 4:
		var across := side < 2
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(box.size.x + line if across else line, 0.002, line if across else box.size.y)
		mesh.material = paint
		bar.mesh = mesh
		var way := -1.0 if side % 2 == 0 else 1.0
		bar.position = middle + (Vector3(0.0, 0.0, way * box.size.y * 0.5) if across else Vector3(way * box.size.x * 0.5, 0.0, 0.0))
		outline.add_child(bar)
	add_child(outline)
	return outline


func make_ring(ring_radius: float, color := Color(1.0, 1.0, 1.0, 0.55)) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = ring_radius - 0.003 * _marks()
	mesh.outer_radius = ring_radius + 0.003 * _marks()
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
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var middle := CenterContainer.new()  # Keeps the card in the middle of the view, whatever its size.
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(middle)
	middle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	# With 2+ players a cook always has a view of their own, a small one.
	middle.offset_top = split_hint_top if InputSetup.active_players().size() > 1 else hint_top
	middle.offset_bottom = middle.offset_top
	middle.add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(column)
	for pair in [[_hint, 1.0], [_how, HOW_SIZE], [_status_label, STATUS_SIZE]]:
		var label: Label = pair[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.custom_minimum_size.x = SMALL_CARD_WIDTH if small_view else CARD_WIDTH
		label.add_theme_font_size_override("font_size", roundi(hint_font_size * float(pair[1])))
		column.add_child(label)
	UiStyle.title(_hint)
	_style_card(false)
	_build_fact_card()


# --- Chef's tips -------------------------------------------------------------

# The card in the bottom-right of the cook's view (at the top it would cover the
# instructions): a small heading and the tip.
func _build_fact_card() -> void:
	var split := InputSetup.active_players().size() > 1
	_fact_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiStyle.panel(CARD_MARGIN * 0.8)
	style.content_margin_top = CARD_MARGIN * 0.45
	style.content_margin_bottom = CARD_MARGIN * 0.5
	_fact_card.add_theme_stylebox_override("panel", style)
	_screen.add_child(_fact_card)
	_fact_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_fact_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # Its corner stays put; it grows to the left and up.
	_fact_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var top := -FACT_MARGIN
	_fact_card.offset_right = -FACT_MARGIN
	_fact_card.offset_left = -FACT_MARGIN
	_fact_card.offset_top = top
	_fact_card.offset_bottom = top
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	_fact_card.add_child(column)
	var heading := Label.new()
	heading.text = "Chef's tip"
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.title(heading)
	heading.add_theme_font_size_override("font_size", roundi(hint_font_size * (0.62 if split else 0.78)))
	heading.add_theme_color_override("font_color", CARD_STATUS)
	column.add_child(heading)
	_fact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fact_label.custom_minimum_size.x = FACT_SPLIT_WIDTH if split else FACT_WIDTH
	_fact_label.add_theme_font_size_override("font_size", roundi(hint_font_size * (0.55 if split else 0.68)))
	_fact_label.add_theme_color_override("font_color", CARD_TEXT)
	column.add_child(_fact_label)
	_fact_card.visible = false
	var recipe_id := recipe.resource_path.get_file().get_basename()
	var entry: Dictionary = _facts_data().get(recipe_id, {})
	_facts = entry.get("facts", [])


# A step's own tip if it has one, else the dish's next fact.
func _fact_for(action: CookAction) -> void:
	var recipe_id := recipe.resource_path.get_file().get_basename()
	var tips: Dictionary = _facts_data().get(recipe_id, {}).get("steps", {})
	if tips.has(action.title):
		_fact_is_tip = true
		_show_fact(tips[action.title])
	elif _fact_is_tip or not _fact_card.visible:
		_fact_is_tip = false
		_show_fact(_next_fact())


func _next_fact() -> String:
	if _facts.is_empty():
		return ""
	var fact: String = _facts[_fact_next % _facts.size()]
	_fact_next += 1
	return fact


func _show_fact(text: String) -> void:
	_fact_time = 0.0
	if text.is_empty():
		_fact_card.visible = false
		return
	var fresh := not _fact_card.visible or _fact_label.text != text
	_fact_label.text = text
	_fact_card.visible = true
	if fresh:
		_fact_card.modulate.a = 0.0
		_fact_card.create_tween().tween_property(_fact_card, "modulate:a", 1.0, 0.35)


static func _facts_data() -> Dictionary:
	if _all_facts.is_empty() and FileAccess.file_exists(FACTS_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FACTS_PATH))
		if parsed is Dictionary:
			_all_facts = parsed.get("recipes", {})
	return _all_facts


# A player's card: dark words on cream. A reel's: just the outlined words, as before.
func _style_card(reel: bool) -> void:
	if _card.has_meta(&"reel") and _card.get_meta(&"reel") == reel:
		return
	_card.set_meta(&"reel", reel)
	var style := UiStyle.panel(CARD_MARGIN)
	style.content_margin_top = CARD_MARGIN * (0.32 if small_view else 0.5)
	style.content_margin_bottom = CARD_MARGIN * (0.32 if small_view else 0.5)
	_card.add_theme_stylebox_override("panel", StyleBoxEmpty.new() if reel else style)
	for label in [_hint, _how, _status_label]:
		label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88) if reel else CARD_TEXT)
		label.add_theme_color_override("font_outline_color", Color(0.2, 0.13, 0.08))
		label.add_theme_constant_override("outline_size", 8 if reel else 0)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88) if reel else CARD_STATUS)


# A bright dot, drawn over everything, gently pulsing. Steps where a tool or
# a held piece already shows the spot hide it (uses_cursor).
func _build_cursor() -> void:
	_cursor.mesh = dot_mesh(0.0145 * _marks(), Color(1.0, 0.92, 0.35, 0.99))
	(_cursor.mesh.material as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	(_cursor.mesh.material as StandardMaterial3D).no_depth_test = true
	add_child(_cursor)
	_add_ring(_cursor, 0.0175 * _marks(), 0.0035 * _marks(), Color(0.22, 0.1, 0.05))  # A dark edge: it shows on pale dough and dark pans alike.
	add_child(_spot)
	_spot.visible = false
	_add_ring(_spot, 0.015 * _marks(), 0.0045 * _marks(), Color(0.22, 0.1, 0.05))
	_add_ring(_spot, 0.015 * _marks(), 0.0022 * _marks(), Color(1.0, 0.92, 0.35), 3)
	var pulse := _cursor.create_tween().set_loops()
	pulse.tween_property(_cursor, "scale", Vector3.ONE * 1.2, 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_cursor, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_SINE)


# A ring lying on the surface, drawn over everything.
func _add_ring(on: Node3D, at_radius: float, half_width: float, color: Color, priority := 2) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = at_radius - half_width
	mesh.outer_radius = at_radius + half_width
	var paint := _flat_material(Color(color, 0.99))  # (Not quite solid, so it's drawn after everything that is.)
	paint.render_priority = priority
	mesh.material = paint
	ring.mesh = mesh
	ring.scale.y = 0.2
	on.add_child(ring)


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.no_depth_test = true
	return material


# A small ball of one color (particles, the cursor).
func dot_mesh(dot_radius: float, color: Color) -> SphereMesh:
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
	steam.amount = 16
	steam.lifetime = 1.7
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = at_radius * 0.7
	steam.direction = Vector3.UP
	steam.spread = 15.0
	steam.initial_velocity_min = 0.05
	steam.initial_velocity_max = 0.12
	steam.gravity = Vector3(0.0, 0.08, 0.0)
	steam.scale_amount_min = 1.3
	steam.scale_amount_max = 2.8
	steam.angle_min = -180.0
	steam.angle_max = 180.0
	steam.angular_velocity_min = -35.0
	steam.angular_velocity_max = 35.0
	var grow := Curve.new()  # Puffs swell as they rise...
	grow.add_point(Vector2(0.0, 0.25))
	grow.add_point(Vector2(1.0, 1.0))
	steam.scale_amount_curve = grow
	var fade := Gradient.new()  # ...and fade in, then out.
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.3, Color(1.0, 1.0, 1.0, 0.2))
	steam.color_ramp = fade
	steam.mesh = _sprite_mesh(0.05, _wisp_texture())
	steam.emitting = false
	return steam


# A little four-point sparkle burst (lantern yellow) for something that came
# out just right: the style guide's "sparkles mark what matters".
const SPARKLE_COLOR := Color("#FFD15C")
func sparkle(at: Vector3, amount := 7) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = 0.9
	particles.explosiveness = 0.85
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.09
	particles.direction = Vector3.UP
	particles.spread = 50.0
	particles.initial_velocity_min = 0.04
	particles.initial_velocity_max = 0.12
	particles.gravity = Vector3.ZERO
	particles.damping_min = 0.1
	particles.damping_max = 0.2
	var pop := Curve.new()  # Pops up, holds, shrinks away.
	pop.add_point(Vector2(0.0, 0.0))
	pop.add_point(Vector2(0.2, 1.0))
	pop.add_point(Vector2(0.7, 0.9))
	pop.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = pop
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	particles.color = SPARKLE_COLOR
	particles.mesh = _sprite_mesh(0.045, _sparkle_texture(), 2.5)
	particles.position = at
	add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


# A flat picture that always faces the camera, tinted by its particle's color.
func _sprite_mesh(width: float, texture: Texture2D, glow := 0.0) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, width)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true  # Without it they're all one size, and ones not born yet show.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	if glow > 0.0:  # Bright enough for the bloom to catch.
		material.albedo_color = Color(glow, glow, glow)
	mesh.material = material
	return mesh


static var _puff: Texture2D = null
static func _puff_texture() -> Texture2D:
	if _puff == null:
		var soft := Gradient.new()
		soft.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		soft.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		var texture := GradientTexture2D.new()
		texture.gradient = soft
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		texture.width = 64
		texture.height = 64
		_puff = texture
	return _puff


# A wisp of steam: soft, and not quite round.
static var _wisp: Texture2D = null
static func _wisp_texture() -> Texture2D:
	if _wisp == null:
		var size := 96
		var noise := FastNoiseLite.new()
		noise.frequency = 0.02
		noise.fractal_octaves = 2
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / size * 2.0 - Vector2.ONE
				var round := 1.0 - smoothstep(0.0, 1.0, p.length())
				var cloud := clampf(0.8 + noise.get_noise_2d(x, y) * 0.35, 0.0, 1.0)
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, round * round * cloud))
		_wisp = ImageTexture.create_from_image(image)
	return _wisp


# A patch of powder: fine grains, thicker in the middle.
static var _dust: Texture2D = null
func dust_texture() -> Texture2D:
	if _dust == null:
		var size := 64
		var grains := RandomNumberGenerator.new()
		grains.seed = 7
		var image := Image.create(size, size, true, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var out := ((Vector2(x, y) + Vector2(0.5, 0.5)) / size * 2.0 - Vector2.ONE).length()
				var thick := 1.0 - smoothstep(0.0, 1.0, out)
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, thick * (0.45 if grains.randf() > thick * 0.6 else 1.0)))
		image.generate_mipmaps()
		_dust = ImageTexture.create_from_image(image)
	return _dust


# A soap bubble's skin: clear in the middle, bright round the edge.
static var _soap: StandardMaterial3D = null
func soap_skin() -> StandardMaterial3D:
	if _soap == null:
		_soap = StandardMaterial3D.new()
		_soap.albedo_color = Color(0.92, 0.97, 1.0, 0.42)
		_soap.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_soap.roughness = 0.04
		_soap.metallic_specular = 1.0
		_soap.rim_enabled = true
		_soap.rim = 1.0
		_soap.rim_tint = 0.2
		_soap.set_meta(ToonStyle.SKIP, true)
	return _soap


# Fat sizzling round something on a hot surface: tiny bubbles all along its edge,
# and now and then a spit. Steps set emitting and reach (sizzle_reach).
func make_sizzle(color := Color(1.0, 0.93, 0.72, 0.75)) -> CPUParticles3D:
	var sizzle := CPUParticles3D.new()
	sizzle.amount = 46
	sizzle.lifetime = 0.42
	sizzle.randomness = 0.6
	sizzle.direction = Vector3.UP
	sizzle.spread = 30.0
	sizzle.initial_velocity_min = 0.0
	sizzle.initial_velocity_max = 0.02
	sizzle.gravity = Vector3.ZERO
	sizzle.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	sizzle.emission_ring_axis = Vector3.UP
	sizzle.emission_ring_height = 0.001
	var pop := Curve.new()  # Swells, and pops.
	pop.add_point(Vector2(0.0, 0.2))
	pop.add_point(Vector2(0.75, 1.0))
	pop.add_point(Vector2(0.8, 0.0))
	sizzle.scale_amount_curve = pop
	sizzle.scale_amount_min = 0.35
	sizzle.scale_amount_max = 1.0
	var bead := SphereMesh.new()
	bead.radius = 0.0042
	bead.height = 0.0084
	bead.radial_segments = 10
	bead.rings = 5
	var skin := StandardMaterial3D.new()
	skin.albedo_color = color
	skin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	skin.roughness = 0.08
	skin.metallic_specular = 0.8
	bead.material = skin
	sizzle.mesh = bead
	sizzle.emitting = false
	return sizzle


func sizzle_reach(sizzle: CPUParticles3D, reach: float) -> void:
	sizzle.emission_ring_radius = reach * 1.03
	sizzle.emission_ring_inner_radius = reach * 0.97


static var _star: Texture2D = null
static func _sparkle_texture() -> Texture2D:
	if _star == null:
		var size := 64
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / size * 2.0 - Vector2.ONE
				var star := 1.0 - (sqrt(absf(p.x)) + sqrt(absf(p.y)))  # Four points, pinched in between.
				var core := 1.0 - p.length() * 2.2
				var alpha := clampf(maxf(star * 2.5, core), 0.0, 1.0)
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
		_star = ImageTexture.create_from_image(image)
	return _star


# A honey butcher-block top under the work area (bounds, a little bigger), its
# top a hair over the counter's so the two don't flicker: the close-up's food
# and tools sit on warm wood, not on loud orange.
func _build_worktop() -> void:
	var slab := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(bounds.size.x + 0.9, 0.03, bounds.size.y + 0.9)
	mesh.material = KitchenProps.counter_wood()
	slab.mesh = mesh
	slab.position = Vector3(bounds.get_center().x, 0.0015 - 0.015, bounds.get_center().y)
	add_child(slab)
