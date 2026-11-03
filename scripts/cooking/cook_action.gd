# CookAction: one step of a close-up recipe (pour, wait, flip, place,
# drizzle...). Each kind of step is its own script extending this one, with its
# tuning as exported variables, so a recipe (a CookRecipe .tres) is just a list
# of these with their settings. Adding a new kind of step means writing a new
# script: CookSession runs any CookAction without knowing what it does.
#
# A session gets its own copy of each step, so the runtime variables below are
# per cook. A step reads its controls from the session's CookInput, works with
# the session's surfaces and pieces, and calls finish(quality) when it's done.
class_name CookAction
extends Resource

@export var title := ""            # Shown above the stove while this step is going, e.g. "Pour the batter".
@export_multiline var hint := ""   # How to do it. [button] and [stick] become this player's controls.
@export var weight := 1.0          # Its share of the dish's quality (0 = doesn't count).
# Runs alongside the steps after it instead of before them (e.g. the griddle's
# heat, which keeps cooking while you pour and flip). It finishes on its own.
@export var background := false
@export_group("Camera")
# How close the cook's camera comes in on this step (view_point) while it's going;
# 0 keeps the station's usual close-up view.
@export var view_distance := 0.0
@export_range(5.0, 89.0) var view_pitch := 60.0  # How steeply it looks down (5: straight on).
@export var view_seconds := 0.5         # How long the camera takes to get there.
@export_group("")

var session: CookSession
var done := false
var quality := 0.0


func begin(cook_session: CookSession) -> void:
	session = cook_session
	_begin()


# Called every frame while the step is going.
func update(_delta: float, _input: CookInput) -> void:
	pass


# Clean up anything only this step needed (its tool, sounds).
func end() -> void:
	pass


# What the camera looks at while view_distance is set (session coordinates).
func view_point() -> Vector3:
	return Vector3(session.bounds.get_center().x, session.work_height, session.bounds.get_center().y)


# Where the cursor can go during this step (x, z in the session), within its
# bounds; empty: anywhere in them. A step with a close view keeps it on screen.
func cursor_area() -> Rect2:
	return Rect2()


# Whether to show the aiming cursor during this step.
func uses_cursor() -> bool:
	return true


# Whether the cursor is just its dot (when what's held already shows the spot).
func cursor_dot() -> bool:
	return false


# How high above the session the cursor should sit, so the mouse points at
# what this step works on (e.g. the top of a stack).
func cursor_height() -> float:
	return session.work_height


# What a piece needs from this step once it's cooked enough, e.g. "Flip!"
# (HeatAction shows it over the piece); "" if nothing.
func ready_word(_piece: CookPiece) -> String:
	return ""


func finish(result: float) -> void:
	quality = clampf(result, 0.0, 1.0)
	done = true


func _begin() -> void:
	pass


# Average of a list of scores (0 if there are none).
static func average(scores: Array) -> float:
	if scores.is_empty():
		return 0.0
	var total := 0.0
	for score in scores:
		total += score
	return total / scores.size()
