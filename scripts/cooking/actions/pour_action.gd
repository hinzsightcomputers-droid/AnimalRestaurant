# PourAction: aim a bottle over a surface and hold the button to pour. The
# batter spreads into a circle that grows the longer you pour; let go to stop.
# A quick press still pours least_share of the size, so none come out too tiny to flip.
# Pours one piece per CookRecipe.pieces. Each scores how close it came to
# target_radius, and less if it runs off the edge.
class_name PourAction
extends CookAction

@export var surface := "Griddle"
@export var target_radius := 0.11         # The perfect size (meters).
@export var seconds_to_target := 1.3      # Holding this long pours exactly that much.
@export var perfect_within := 0.012       # Size error that still gets full marks...
@export var worst_error := 0.06           # ...and the error that gets none.
@export_range(0.0, 1.0) var least_share := 0.8  # Once started, it pours at least this much of the target size.
@export var spread_speed := 5.0           # How quickly batter spreads out to its size.
@export var batter_color := Color(0.96, 0.88, 0.66)
@export var done_color := CookPiece.GOLDEN  # What it cooks to when just right (yellow for eggs).
@export var thickness := 0.022
@export var bottle_height := 0.2          # How high the nozzle is above the surface.
@export var show_guide := true            # A faint ring the size of a perfect pour.
@export var stack := false                # Poured straight onto a plate: it starts the plate's stack, so toppings and drizzles go on it.

var _bottle: Node3D
var _stream: MeshInstance3D
var _guide: MeshInstance3D
var _glug: AudioStreamPlayer3D
var _pouring: CookPiece = null
var _area := 0.0
var _scores: Array[float] = []


func view_point() -> Vector3:
	return session.surface(surface).position


# With a view of its own, the cursor stays on the surface (and on screen).
func cursor_area() -> Rect2:
	return session.area_of(surface, 0.03) if view_distance > 0.0 else Rect2()


# No cursor ring over the batter: the guide ring (or, without it, the cursor
# until pouring starts) shows where it'll go.
func uses_cursor() -> bool:
	return false  # The bottle (and the guide circle) show the spot.


func _begin() -> void:
	_bottle = session.make_bottle(batter_color)
	_guide = session.make_ring(target_radius)
	_glug = session.loop_sound("pour", -6.0)
	_stream = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.006
	mesh.bottom_radius = 0.008
	mesh.height = 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = batter_color
	mesh.material = material
	_stream.mesh = mesh
	_stream.visible = false
	session.add_child(_stream)


func update(delta: float, input: CookInput) -> void:
	var spot := input.cursor
	var top := session.surface(surface).position.y
	spot.y = top
	if _pouring == null:
		_guide.visible = show_guide
		_guide.position = spot + Vector3(0.0, 0.002, 0.0)
		if input.just_pressed:
			_try_start(spot)
	elif input.held or _pouring.spread_to < target_radius * least_share:  # A quick press still pours enough to flip.
		_area += PI * target_radius * target_radius / seconds_to_target * delta * GameState.difficulty_value("closeup_pace")  # Slower on Easy: easier to stop at the right size.
		_pouring.spread_to = sqrt(_area / PI)
	else:
		_stop_pouring()

	for piece in session.pieces:  # Batter keeps spreading after it lands.
		if piece.radius < piece.spread_to:
			piece.set_radius(lerpf(piece.radius, piece.spread_to, 1.0 - exp(-spread_speed * delta)))

	var pouring := _pouring != null
	var tip := (_pouring.position if pouring else spot) + Vector3(0.0, bottle_height, 0.0)
	_bottle.position = _bottle.position.lerp(tip, 1.0 - exp(-20.0 * delta))
	var tilt := deg_to_rad(-8.0 if pouring else -40.0)  # Nozzle straight down while pouring.
	_bottle.rotation.z = lerp_angle(_bottle.rotation.z, tilt, 1.0 - exp(-14.0 * delta))
	_stream.visible = pouring
	if pouring:
		_stream.position = _pouring.position + Vector3(0.0, bottle_height * 0.5, 0.0)
		_stream.scale = Vector3(1.0, bottle_height, 1.0)
		if not _glug.playing:
			_glug.play()
	elif _glug.playing:
		_glug.stop()

	if _scores.size() >= session.recipe.pieces and _pouring == null:
		finish(average(_scores))


func end() -> void:
	for piece in session.pieces:  # The last pour finishes spreading by itself.
		if piece.radius < piece.spread_to:
			piece.create_tween().tween_method(piece.set_radius, piece.radius, piece.spread_to, 0.5).set_ease(Tween.EASE_OUT)
	_glug.stop()
	_bottle.queue_free()
	_stream.queue_free()
	_guide.queue_free()


func _try_start(spot: Vector3) -> void:
	if not session.surface(surface).contains(spot):
		session.pop_text("Pour it on the %s!" % surface.to_lower(), spot, -1)
		session.wobble(_bottle)
		return
	for piece in session.pieces:
		var gap := Vector2(piece.position.x - spot.x, piece.position.z - spot.z).length()
		if gap < piece.spread_to + 0.02:
			session.pop_text("No room there", spot, -1)
			session.wobble(_bottle)
			return
	_pouring = session.add_piece(batter_color, thickness, spot, surface)
	_pouring.done_color = done_color
	_area = 0.0
	session.wobble(_bottle, 0.12)


func _stop_pouring() -> void:
	var piece := _pouring
	_pouring = null
	var error := absf(piece.spread_to - target_radius)
	var score := 1.0 - clampf((error - perfect_within) / (worst_error - perfect_within), 0.0, 1.0)
	var words := "Perfect size!" if error <= perfect_within else ("Too small" if piece.spread_to < target_radius else "Too much!")
	if score >= 0.8 and error > perfect_within:
		words = "Nice!"
	if not session.surface(surface).contains(piece.position, -piece.spread_to):
		score *= 0.6
		words = "Over the edge!"
	piece.scores["pour"] = score
	_scores.append(score)
	if stack:
		session.stack_push(surface, piece, piece.position, piece.thickness)
	session.pop_text(words, piece.position, CookSession.mood_of(score))
	session.wobble(piece, 0.1)
	session.play_sound("plop", piece.position, -6.0, 0.8)
