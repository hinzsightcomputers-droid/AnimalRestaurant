# MashAction: crush whole tomatoes in the pot into a sauce. A masher follows
# the cursor; press the button over a tomato and it comes down on it. Each
# takes a few presses to squash flat, and the red sauce in the pot comes up
# with every one crushed. A press that misses every tomato is wasted. Scores
# the share of presses that landed (never under half), once they're all crushed.
class_name MashAction
extends CookAction

const TOMATO := Color(0.86, 0.17, 0.12)
const STEM := Color(0.3, 0.55, 0.22)

@export var in_surface := "Pot"
@export var tomatoes := 4
@export var hits_each := 3
@export var tomato_radius := 0.03
@export var sauce_level := 0.45           # How full the pot is with them all crushed.
@export var sauce_color := Color(0.8, 0.22, 0.12, 0.95)

var _tomatoes: Array[Node3D] = []
var _hits := {}                            # Tomato -> presses it's had.
var _presses := 0
var _landed := 0
var _masher: Node3D
var _busy := false


func _init() -> void:
	view_distance = 0.5
	view_pitch = 62.0


func view_point() -> Vector3:
	return session.surface(in_surface).position


func uses_cursor() -> bool:
	return false  # The masher shows the spot.


func cursor_height() -> float:
	return session.surface(in_surface).position.y + tomato_radius


func _begin() -> void:
	var pot := session.surface(in_surface)
	var red := StandardMaterial3D.new()
	red.albedo_color = TOMATO
	red.roughness = 0.3
	red.set_meta(ToonStyle.FOOD, "veg")
	var green := StandardMaterial3D.new()
	green.albedo_color = STEM
	for i in tomatoes:
		var tomato := Node3D.new()
		var body := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = tomato_radius
		ball.height = tomato_radius * 1.7
		ball.material = red
		body.mesh = ball
		body.position.y = tomato_radius * 0.85
		tomato.add_child(body)
		var stem := MeshInstance3D.new()
		var star := CylinderMesh.new()
		star.top_radius = tomato_radius * 0.35
		star.bottom_radius = tomato_radius * 0.35
		star.height = 0.004
		star.radial_segments = 5
		star.material = green
		stem.mesh = star
		stem.position.y = tomato_radius * 1.7
		tomato.add_child(stem)
		var at := Vector2.from_angle(TAU * i / tomatoes + 0.4) * pot.radius() * 0.5
		tomato.position = Vector3(at.x, 0.0, at.y)
		pot.add_child(tomato)
		_tomatoes.append(tomato)
		_hits[tomato] = 0
	_masher = _make_masher()
	session.add_child(_masher)
	_masher.position = pot.position + Vector3(0.1, 0.12, 0.1)


func end() -> void:
	if is_instance_valid(_masher):
		_masher.queue_free()
	for tomato in _tomatoes:  # What's left of them is in the sauce now.
		if is_instance_valid(tomato):
			tomato.queue_free()


func update(delta: float, input: CookInput) -> void:
	var pot := session.surface(in_surface)
	var spot := Vector3(input.cursor.x, pot.position.y, input.cursor.z)
	if not _busy:
		_masher.position = _masher.position.lerp(spot + Vector3(0.0, 0.1, 0.0), 1.0 - exp(-18.0 * delta))
	var left := _tomatoes.filter(func(t): return _hits[t] < hits_each).size()
	session.set_status("Tomatoes to crush: %d" % left)
	if input.just_pressed and not _busy and not done:
		_mash(pot, spot)


func _mash(pot: CookSurface, spot: Vector3) -> void:
	_presses += 1
	var target: Node3D = null
	for tomato in _tomatoes:
		var at := pot.position + tomato.position
		if _hits[tomato] < hits_each and Vector2(at.x - spot.x, at.z - spot.z).length() <= tomato_radius * 1.5:
			target = tomato
			break
	_busy = true
	var down_to := pot.position.y + (tomato_radius * 1.7 * (1.0 - float(_hits[target] + 1) / hits_each) + 0.01 if target != null else 0.01)
	var push := _masher.create_tween()
	push.tween_property(_masher, "position:y", down_to, 0.07).set_ease(Tween.EASE_IN)
	push.tween_callback(func(): _landed_on(pot, target, spot))
	push.tween_property(_masher, "position:y", spot.y + 0.1, 0.12)
	push.tween_callback(func(): _busy = false)


func _landed_on(pot: CookSurface, tomato: Node3D, spot: Vector3) -> void:
	if tomato == null:
		session.play_sound("clack", spot, -8.0, 1.2)
		session.pop_text("Missed!", spot, -1)
		return
	_landed += 1
	_hits[tomato] += 1
	var squash := float(_hits[tomato]) / hits_each
	tomato.scale = Vector3(1.0 + squash * 0.7, maxf(1.0 - squash * 0.85, 0.12), 1.0 + squash * 0.7)
	session.play_sound("plop", spot, -4.0, 0.8 + randf() * 0.2)
	session.burst(spot + Vector3(0.0, 0.02, 0.0), TOMATO, 10, 0.3)
	var crushed := 0.0
	for each in _tomatoes:
		crushed += float(_hits[each]) / hits_each
	pot.fill_to(sauce_level * crushed / _tomatoes.size(), sauce_color)
	if _hits[tomato] >= hits_each:
		session.pop_text("Squished!", spot, 1)
	if _tomatoes.all(func(t): return _hits[t] >= hits_each):
		var score := maxf(float(_landed) / _presses, 0.5)
		session.pop_text("Lovely sauce!" if score >= 0.85 else "Saucy!", pot.position, CookSession.mood_of(score))
		finish(score)


# For a reel: over the next tomato still whole, and press.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if _busy:
		return false
	var pot := session.surface(in_surface)
	for tomato in _tomatoes:
		if _hits[tomato] < hits_each:
			return input.move_to(pot.position + tomato.position, delta, 1.2) and not input.held
	return false


# A potato masher: a wavy steel foot on a stem, a wooden handle on top.
func _make_masher() -> Node3D:
	var masher := Node3D.new()
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.78, 0.8, 0.83)
	steel.metallic = 0.6
	steel.roughness = 0.35
	var foot := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.026
	ring.outer_radius = 0.032
	ring.material = steel
	foot.mesh = ring
	masher.add_child(foot)
	var bar := MeshInstance3D.new()
	var cross := BoxMesh.new()
	cross.size = Vector3(0.056, 0.004, 0.006)
	cross.material = steel
	bar.mesh = cross
	masher.add_child(bar)
	var stem := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.003
	rod.bottom_radius = 0.003
	rod.height = 0.1
	rod.material = steel
	stem.mesh = rod
	stem.position.y = 0.05
	masher.add_child(stem)
	var handle := MeshInstance3D.new()
	var grip := CylinderMesh.new()
	grip.top_radius = 0.009
	grip.bottom_radius = 0.009
	grip.height = 0.06
	handle.mesh = grip
	handle.material_override = KitchenProps.handle_wood()
	handle.position.y = 0.12
	masher.add_child(handle)
	return masher
