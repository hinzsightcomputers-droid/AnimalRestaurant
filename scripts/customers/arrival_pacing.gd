# ArrivalPacing: how fast customers come in, from data/pacing.json. Each meal
# runs on its own clock (meal_seconds), and the day curve's phases (opening,
# lunch rush, afternoon, dinner rush, closing) each sit in one meal. Only so
# many customers can be waiting for food at once (the cap); when there's room,
# the next comes after a random gap. Both depend on how many players are in
# (read live), the phase, and bonus hooks (hired staff, the star rating).
# Pure logic: CustomerManager keeps the clock and does the arriving.
class_name ArrivalPacing
extends RefCounted

static var show_debug_line := false  # The debug panel's "Pacing line": shown live under the HUD's day line.


# e.g. "Lunch rush | 2 players | cap 4 | waiting 3 | next in 7.2s | 1 regular to come"
# from CustomerManager.status().
static func debug_line(status: Dictionary) -> String:
	var next := "next in %.1fs" % status["next"] if status["next"] >= 0.0 else ("full" if status["waiting"] >= status["cap"] else "nobody coming")
	var line := "%s | %d player%s | cap %d | waiting %d | %s" % [status["phase"], status["players"], "" if status["players"] == 1 else "s", status["cap"], status["waiting"], next]
	if status["regulars_to_come"] > 0:
		line += " | %d regular%s to come" % [status["regulars_to_come"], "" if status["regulars_to_come"] == 1 else "s"]
	return line


static func settings() -> Dictionary:
	return GameData.pacing


static func meal_id(meal: int) -> String:
	return String(GameState.phase_info(meal).get("id", ""))


# How long meal `meal` runs, in seconds.
static func meal_seconds(meal: int) -> float:
	return float(settings().get("meal_seconds", {}).get(meal_id(meal), 300.0))


# The day curve's phases in meal `meal`, in order.
static func phases_of(meal: int) -> Array:
	var id := meal_id(meal)
	return settings().get("phases", []).filter(func(phase): return phase.get("meal", "") == id)


# The phase at `elapsed` seconds into meal `meal` (its last one once time's
# up), or {} if the meal has none.
static func phase_at(meal: int, elapsed: float) -> Dictionary:
	var phases := phases_of(meal)
	for phase in phases:
		if elapsed < float(phase.get("to", INF)):
			return phase
	return phases.back() if not phases.is_empty() else {}


static func find_phase(id: String) -> Dictionary:
	for phase in settings().get("phases", []):
		if phase.get("id", "") == id:
			return phase
	return {}


# When arrivals stop in meal `meal` (seconds on its clock): the start of a
# phase's quiet_last stretch, else the end of the meal.
static func arrivals_close_at(meal: int) -> float:
	for phase in phases_of(meal):
		if phase.has("quiet_last"):
			return float(phase["to"]) - float(phase["quiet_last"])
	return meal_seconds(meal)


static func arrivals_open(meal: int, elapsed: float) -> bool:
	return elapsed < arrivals_close_at(meal)


# How many players are in right now (at least 1).
static func player_count() -> int:
	return maxi(InputSetup.active_players().size(), 1)


# The players table's row for `count` players (the nearest one there is).
static func player_row(count := -1) -> Dictionary:
	if count < 1:
		count = player_count()
	var best := {}
	for row in settings().get("players", []):
		if best.is_empty() or absi(int(row["players"]) - count) < absi(int(best["players"]) - count):
			best = row
	return best if not best.is_empty() else { "players": 1, "cap": 2, "gap": [6, 20], "pair_scale": 1.0 }


# How many can be waiting for food at once at `elapsed` into meal `meal`.
static func cap(meal: int, elapsed: float) -> int:
	return maxi(1, int(player_row().get("cap", 2)) + int(phase_at(meal, elapsed).get("cap_add", 0)) + bonus())


# What the hooks add to the cap: hired staff and the star rating.
static func bonus() -> int:
	var bonuses: Dictionary = settings().get("bonuses", {})
	return staff_count() * int(bonuses.get("per_staff", 1)) + int(bonuses.get("stars", {}).get(str(GameState.stars), 0))


# Hired staff members (a hook: none can be hired yet).
static func staff_count() -> int:
	return 0


# Seconds until the next arrival once there's room: short when nobody's inside
# (`empty`), else the player-count gap times the phase's gap_scale (and the
# Welcome Sign and difficulty, as before).
static func gap(meal: int, elapsed: float, empty: bool) -> float:
	var range := _range(settings().get("empty_gap", [2, 5])) if empty else _range(player_row().get("gap", [6, 20])) * float(phase_at(meal, elapsed).get("gap_scale", 1.0))
	var scale := 1.0 if empty else GameState.upgrade_multiplier("arrival_interval") * GameState.difficulty_value("arrival_interval")
	return randf_range(range.x, range.y) * scale


# The middle of the normal gap for `count` players (to rescale a countdown when
# someone joins or leaves).
static func gap_middle(count: int) -> float:
	var range := _range(player_row(count).get("gap", [6, 20]))
	return (range.x + range.y) * 0.5


# Times the chance a townsfolk walks in with a friend.
static func pair_scale() -> float:
	return float(player_row().get("pair_scale", 1.0))


# Whether an arrival now brings a surprise second customer behind them.
static func surprise(meal: int, elapsed: float) -> bool:
	return phase_at(meal, elapsed).get("rush", false) and randf() < float(settings().get("surprise_chance", 0.17))


static func surprise_delay() -> float:
	var range := _range(settings().get("surprise_delay", [1.5, 4]))
	return randf_range(range.x, range.y)


# A regular's visit_window: the phase ids they like to come in (character file).
static func window_of(regular_id: String) -> Array:
	return GameData.characters.get(regular_id, {}).get("visit_window", [])


# The meal a regular's visit goes in: one their window covers (at random if
# it covers several), else any meal.
static func meal_for(regular_id: String, meal_count: int) -> int:
	var meals := []
	for phase_id in window_of(regular_id):
		var index := _meal_index(String(find_phase(phase_id).get("meal", "")))
		if index >= 0 and index < meal_count and not index in meals:
			meals.append(index)
	return meals.pick_random() if not meals.is_empty() else randi() % maxi(meal_count, 1)


# The chance a planned regular (or "" for the critic) is the next arrival.
static func regular_chance(regular_id: String, meal: int, elapsed: float) -> float:
	var chance := float(settings().get("regular_chance", 0.25))
	if not regular_id.is_empty() and String(phase_at(meal, elapsed).get("id", "")) in window_of(regular_id):
		chance *= float(settings().get("window_boost", 3.0))
	return clampf(chance, 0.0, 1.0)


# Whether the regulars still to come this meal must come now to fit in before
# arrivals stop.
static func urgent(meal: int, elapsed: float, still_to_come: int) -> bool:
	return arrivals_close_at(meal) - elapsed < float(settings().get("urgent_seconds", 50)) * still_to_come


static func _meal_index(id: String) -> int:
	var phases: Array = GameData.day_settings.get("phases", [])
	for i in phases.size():
		if phases[i].get("id", "") == id:
			return i
	return -1


static func _range(values) -> Vector2:
	return Vector2(float(values[0]), float(values[1])) if values is Array and values.size() >= 2 else Vector2(5, 10)
