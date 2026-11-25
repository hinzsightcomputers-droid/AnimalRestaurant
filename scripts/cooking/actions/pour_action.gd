# PourAction: aim a bottle over a surface and hold the button to pour. The
# batter spreads into a circle that grows the longer you pour; let go to stop.
# A quick press still pours least_share of the size, so none come out too tiny to flip.
# Pours one piece per CookRecipe.pieces. Each scores how close it came to
# target_radius. On a flat surface the batter goes in an outlined box (like the
# big breakfast's): the guide ring can't leave it, and a pour stops growing at
# its line, so nothing ever runs off the edge.
# With lanes, it's piped along lines instead (churros): one line for each piece,
# the nearest one left to the cursor is next, and target_radius is half its length.
class_name PourAction
extends CookAction

@export var surface := "Griddle"
@export var target_radius := 0.11         # The perfect size (meters).
@export var seconds_to_target := 1.3      # Holding this long pours exactly that much.
@export var perfect_within := 0.012       # Size error that still gets full marks...
@export var worst_error := 0.06           # ...and the error that gets none.
@export_range(0.0, 1.0) var least_share := 0.8  # Once started, it pours at least this much of the target size.
@export var most_over := 0.03            # Holding on, it stops by itself this far past the ring ("Too big!"): the bottle doesn't pour forever.
@export var spread_speed := 5.0           # How quickly batter spreads out to its size.
@export var batter_color := Color(0.96, 0.88, 0.66)
@export var done_color := CookPiece.GOLDEN  # What it cooks to when just right (yellow for eggs).
@export var thickness := 0.022
@export var lanes := false                 # Piped in sticks along lines, one for each piece.
@export var lane_gap := 0.085              # How far apart the lines are.
@export var leaves := false                # Not batter: salad leaves, piling up as they're poured.
@export var bottle_height := 0.2          # How high the nozzle is above the surface.
@export var show_guide := true            # A faint ring the size of a perfect pour.
@export var stack := false                # Poured straight onto a plate: it starts the plate's stack, so toppings and drizzles go on it.
@export var zone_size := Vector2.ZERO      # The outlined box the batter goes in (zero: the surface, zone_margin in from each side). None on a round surface.
@export var zone_margin := 0.05

const SCRIPTED_GAP := 0.26  # A reel pours its pieces this far apart, in a row.
const GAP_BETWEEN := 0.004  # Pieces stop growing this far from each other (and from the box's line), so they touch without overlapping.
const EDGE_GAP := 0.02      # A round surface (no box): how far in from its edge.

var _bottle: Node3D
var _stream: PourStream
var _guide: MeshInstance3D
var _lane_marks: Array = []                # Lanes: [faint outline, bright outline] for each...
var _lane_done: Array[bool] = []           # ...and whether it's been piped.
var _lane := 0                             # The one that's next.
var _outline: Node3D = null
var _glug: AudioStreamPlayer3D
var _pouring: CookPiece = null
var _area := 0.0
var _scores: Array[float] = []


func view_point() -> Vector3:
	return session.surface(surface).position


# The cursor stays in the box (or, without one, on the surface).
func cursor_area() -> Rect2:
	var box := _zone()
	if box.has_area():
		return box
	return session.area_of(surface, 0.03) if view_distance > 0.0 else Rect2()


# The box the batter goes in, on the surface's x/z (empty on a round surface).
func _zone() -> Rect2:
	var place := session.surface(surface)
	if place.round:
		return Rect2()
	var size := zone_size if zone_size != Vector2.ZERO else (place.size - Vector2.ONE * zone_margin * 2.0).max(Vector2.ZERO)
	return Rect2(place.position.x - size.x * 0.5, place.position.z - size.y * 0.5, size.x, size.y)


# No cursor ring over the batter: the guide ring (or, without it, the cursor
# until pouring starts) shows where it'll go.
func uses_cursor() -> bool:
	return false  # The bottle (and the guide circle) show the spot.


func _begin() -> void:
	_bottle = session.make_bottle(batter_color)
	_bottle.scale = Vector3.ONE * 0.8
	_guide = session.make_ring(target_radius)
	if lanes:
		_guide.visible = false
		for i in session.recipe.pieces:
			var line := Rect2(_lane_start(i) + Vector2(0.0, -thickness * 0.75), Vector2(target_radius * 2.0, thickness * 1.5))
			var height := session.surface(surface).position.y
			_lane_marks.append([session.make_box_outline(line, height, Color(1.0, 1.0, 1.0, 0.3)), session.make_box_outline(line, height, Color(1.0, 1.0, 1.0, 0.9))])
			_lane_done.append(false)
	elif _zone().has_area():
		_outline = session.make_box_outline(_zone(), session.surface(surface).position.y)
	_glug = session.loop_sound("pour", -6.0)
	_stream = PourStream.make(session, batter_color, 0.0085, 0.6)


func update(delta: float, input: CookInput) -> void:
	var spot := input.cursor
	var place := session.surface(surface)
	spot.y = place.position.y
	if lanes:
		spot = _lane_spot(spot)
	elif _pouring == null:  # The guide ring never crosses the box's line (or a round surface's edge).
		spot = _keep_ring_in(spot, place)
	if _pouring == null:
		_guide.visible = show_guide and not lanes
		_guide.position = spot + Vector3(0.0, 0.002, 0.0)
		if input.just_pressed:
			_try_start(spot)
	elif input.held or _pouring.spread_to < target_radius * least_share:  # A quick press still pours enough to flip.
		_area += PI * target_radius * target_radius / seconds_to_target * delta * GameState.difficulty_value("closeup_pace")  # Slower on Easy: easier to stop at the right size.
		var largest := target_radius + most_over if lanes else minf(target_radius + most_over, _room_at(_pouring.position, _pouring))  # Never into the next one or off the edge.
		_pouring.spread_to = minf(sqrt(_area / PI), largest)
		if _pouring.spread_to >= largest:
			_stop_pouring()
	else:
		_stop_pouring()

	for piece in session.pieces:  # Batter keeps spreading after it lands.
		if piece.radius < piece.spread_to:
			piece.set_radius(lerpf(piece.radius, piece.spread_to, 1.0 - exp(-spread_speed * delta)))

	var pouring := _pouring != null
	var from := _pouring.position if pouring and not lanes else spot
	var tip := from + Vector3(0.0, bottle_height, 0.0)
	_bottle.position = _bottle.position.lerp(tip, 1.0 - exp(-20.0 * delta))
	var tilt := deg_to_rad(-8.0 if pouring else -40.0)  # Nozzle straight down while pouring.
	_bottle.rotation.z = lerp_angle(_bottle.rotation.z, tilt, 1.0 - exp(-14.0 * delta))
	_bottle.rotation.x = deg_to_rad(-34.0)  # Leaning away, so the batter shows.
	var squeezed := lerpf(_bottle.scale.x, 0.66 if pouring else 0.8, 1.0 - exp(-12.0 * delta))
	_bottle.scale = Vector3(squeezed, 0.8, 0.8 + (0.8 - squeezed) * 0.5)
	var land := from + Vector3(0.0, thickness * 0.6 if pouring else 0.0, 0.0)
	_stream.flow(_bottle.position, land, pouring, delta)
	for piece in session.pieces:
		piece.stream = 1.0 if piece == _pouring and _stream.landed else 0.0
	if pouring:
		if not _glug.playing:
			_glug.play()
	elif _glug.playing:
		_glug.stop()

	if session.recipe.pieces > 1:
		session.set_status("%d of %d" % [mini(_scores.size() + 1, session.recipe.pieces), session.recipe.pieces])
	if _scores.size() >= session.recipe.pieces and _pouring == null:
		finish(average(_scores))


func end() -> void:
	for piece in session.pieces:  # The last pour finishes spreading by itself.
		if piece.radius < piece.spread_to:
			piece.create_tween().tween_method(piece.set_radius, piece.radius, piece.spread_to, 0.5).set_ease(Tween.EASE_OUT)
	for piece in session.pieces:
		piece.stream = 0.0
	_glug.stop()
	_bottle.queue_free()
	_stream.finish(_stream.position - Vector3(0.0, bottle_height, 0.0))
	_guide.queue_free()
	for marks in _lane_marks:
		for mark: Node3D in marks:
			mark.queue_free()
	if _outline != null:
		_outline.queue_free()


# Each piece side by side, stopped at just the right size.
func scripted_hold(delta: float, input: CookInput) -> bool:
	if _pouring != null:
		return _pouring.spread_to < target_radius
	var count := session.recipe.pieces
	if _scores.size() >= count:
		return false
	if lanes:
		var start := _lane_start(_scores.size())
		return input.move_to(Vector3(start.x + target_radius, 0.0, start.y), delta) and _lane == _scores.size()
	var side := (_scores.size() - (count - 1) / 2.0) * SCRIPTED_GAP
	return input.move_to(session.surface(surface).position + Vector3(side, 0.0, 0.0), delta)


func _try_start(spot: Vector3) -> void:
	if not session.surface(surface).contains(spot):
		session.pop_text("Pour it on the %s!" % surface.to_lower(), spot, -1)
		session.wobble(_bottle)
		return
	if not lanes and _room_at(spot) < target_radius * least_share:  # Not even a small one fits between the others.
		session.pop_text("No room there", spot, -1)
		session.wobble(_bottle)
		return
	_pouring = session.add_piece(batter_color, thickness, spot, surface)
	_pouring.done_color = done_color
	if lanes:
		_lane_done[_lane] = true
		_pouring.make_churro(spot.x)
	if leaves:
		_pouring.make_greens(target_radius)
	_area = 0.0
	session.wobble(_bottle, 0.12)


# Where a lane starts (its left end, x and z in the session).
func _lane_start(index: int) -> Vector2:
	var middle := session.surface(surface).position
	return Vector2(middle.x - target_radius, middle.z + (index - (session.recipe.pieces - 1) / 2.0) * lane_gap)


# Where the nozzle is: at the start of the nearest lane that's left, or at the
# end of what's being piped.
func _lane_spot(spot: Vector3) -> Vector3:
	if _pouring == null:
		var nearest := INF
		for i in _lane_done.size():
			var gap := absf(_lane_start(i).y - spot.z) - (0.015 if i == _lane else 0.0)  # It doesn't flicker between two.
			if not _lane_done[i] and gap < nearest:
				nearest = gap
				_lane = i
	for i in _lane_marks.size():
		_lane_marks[i][0].visible = not _lane_done[i] and i != _lane
		_lane_marks[i][1].visible = i == _lane and (not _lane_done[i] or _pouring != null)
	var start := _lane_start(_lane)
	return Vector3(start.x + (_pouring.radius * 2.0 if _pouring != null else 0.0), spot.y, start.y)


# Where the ring goes for a cursor at `spot`: moved in so the whole ring, and
# even the biggest "Too big!" pour around it, stays inside the box (a round
# surface: inside its edge). So holding on in a corner is no free "Perfect".
func _keep_ring_in(spot: Vector3, place: CookSurface) -> Vector3:
	var reach := target_radius + most_over
	var box := _zone()
	if not box.has_area():
		return place.keep_inside(spot, reach + EDGE_GAP) if place.contains(spot) else spot
	var inner := box.grow(-reach - GAP_BETWEEN)
	spot.x = clampf(spot.x, inner.position.x, maxf(inner.end.x, inner.position.x))
	spot.z = clampf(spot.z, inner.position.y, maxf(inner.end.y, inner.position.y))
	return spot


# How big a piece poured at `spot` can get before it reaches the box's line (or
# a round surface's edge) or touches another (whatever size that one is
# spreading to), so it never runs off or into another.
func _room_at(spot: Vector3, skip: CookPiece = null) -> float:
	var box := _zone()
	var room := session.surface(surface).edge_room(spot) - EDGE_GAP
	if box.has_area():
		room = minf(minf(spot.x - box.position.x, box.end.x - spot.x), minf(spot.z - box.position.y, box.end.y - spot.z)) - GAP_BETWEEN
	for piece in session.pieces:
		if piece == skip:
			continue
		var gap := Vector2(piece.position.x - spot.x, piece.position.z - spot.z).length()
		room = minf(room, gap - piece.spread_to - GAP_BETWEEN)
	return room


func _stop_pouring() -> void:
	var piece := _pouring
	_pouring = null
	var error := absf(piece.spread_to - target_radius)
	var score := 1.0 - clampf((error - perfect_within) / (worst_error - perfect_within), 0.0, 1.0)
	var words := "Perfect size!" if error <= perfect_within else ("Too small" if piece.spread_to < target_radius else "Too big!")
	if score >= 0.8 and error > perfect_within:
		words = "Nice!"
	if not lanes and not session.surface(surface).contains(piece.position, -piece.spread_to):
		score *= 0.6
		words = "Over the edge!"
	piece.scores["pour"] = score
	_scores.append(score)
	if stack:
		session.stack_push(surface, piece, piece.position, piece.thickness)
	session.pop_text(words, piece.position, CookSession.mood_of(score))
	session.wobble(piece, 0.1)
	session.play_sound("plop", piece.position, -6.0, 0.8)
