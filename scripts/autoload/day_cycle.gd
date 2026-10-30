# DayCycle (autoload): where the restaurant day is. The one place that knows
# the day's phase; the HUD, lighting, customers, phone, doors and dialogue ask
# it instead of keeping their own flags. A day goes:
#   MEAL (each meal in data/day.json, `meal` says which) -> CLOSING -> NIGHT
#   (only once the phone is on the wall) -> SUMMARY -> AFTER_HOURS
# and After Hours lasts until a player opens up on a new restaurant day (5 AM
# local, see GameClock). Saved with the game (GameState.to_save_data), so a
# relaunch picks up the same phase. It also notices 5 AM going by: things that
# reset once a day (forage spots, house visits) hear `daily_reset` whatever
# the phase, and in After Hours the players are told a new day can start.
extends Node

enum Phase { MEAL, CLOSING, NIGHT, SUMMARY, AFTER_HOURS }

# Which phases each can move on to (a new day always starts at MEAL; see start_day).
const NEXT := {
	Phase.MEAL: [Phase.MEAL, Phase.CLOSING],
	Phase.CLOSING: [Phase.NIGHT, Phase.SUMMARY],
	Phase.NIGHT: [Phase.SUMMARY],
	Phase.SUMMARY: [Phase.AFTER_HOURS],
	Phase.AFTER_HOURS: [],
}
const NAMES := { Phase.MEAL: "meal", Phase.CLOSING: "closing", Phase.NIGHT: "night", Phase.SUMMARY: "summary", Phase.AFTER_HOURS: "after_hours" }
const CHECK_SECONDS := 1.0

signal phase_changed(phase: Phase)
signal daily_reset(date: String)  # 5 AM went by (or the game started on a new restaurant day).
signal new_day_waiting            # 5 AM came during the summary or After Hours.

var phase := Phase.MEAL
var meal := 0  # During MEAL: which one (an index into data/day.json "phases").
# The day's summary (see DaySummary.build), kept so it can be reopened after
# hours. {} before the day has ended.
var summary: Dictionary = {}
# The restaurant day daily things last reset on, e.g. "2026-10-29".
var reset_date := ""

var _check_left := 0.0
var _told_new_day := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # The summary pauses the game; 5 AM still counts.


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_SECONDS
	check_clock()


# Daily resets at 5 AM, and in After Hours the news that a new day can start.
func check_clock() -> void:
	var today := GameClock.today()
	if reset_date != today:
		reset_date = today
		daily_reset.emit(today)
	if is_new_day_waiting() and not _told_new_day:
		_told_new_day = true
		new_day_waiting.emit()


# --- Asking --------------------------------------------------------------------

func is_open() -> bool:  # Serving meals: walk-ins and daytime phone calls.
	return phase == Phase.MEAL


func is_closing() -> bool:
	return phase == Phase.CLOSING


func is_night() -> bool:  # The night shift: phone orders only.
	return phase == Phase.NIGHT


func is_after_hours() -> bool:  # Includes the summary, which comes first.
	return phase in [Phase.SUMMARY, Phase.AFTER_HOURS]


# The day is over (summary or After Hours) and it's past 5 AM on a later day:
# the next interaction with the sign or host stand opens up.
func is_new_day_waiting() -> bool:
	return is_after_hours() and not GameState.date.is_empty() and GameClock.today() != GameState.date


# Chairs on the tables: the night shift and after hours.
func chairs_up() -> bool:
	return phase in [Phase.NIGHT, Phase.SUMMARY, Phase.AFTER_HOURS]


# The chefs can go out the doors (only once the day's done).
func doors_open() -> bool:
	return phase == Phase.AFTER_HOURS


# e.g. "Lunch", "Closing", "Night", "After hours".
func phase_name() -> String:
	match phase:
		Phase.MEAL:
			return GameState.phase_info(meal).get("name", "Meal")
		Phase.CLOSING:
			return "Closing"
		Phase.NIGHT:
			return GameState.phase_info(GameState.NIGHT).get("name", "Night")
	return "After hours"


# For dialogue conditions: "breakfast" (the meal's id), "closing", "night",
# "summary" or "after_hours".
func phase_id() -> String:
	if phase == Phase.MEAL:
		return GameState.phase_info(meal).get("id", "meal")
	return NAMES[phase]


func is_last_meal() -> bool:
	return meal >= GameState.phase_count() - 1


# --- Moving on ------------------------------------------------------------------

# A new restaurant day: the first meal, no summary yet. Called by GameState.begin_day.
func start_day() -> void:
	phase = Phase.MEAL
	meal = 0
	summary = {}
	_told_new_day = false
	phase_changed.emit(phase)


func to_meal(index: int) -> void:
	meal = index
	_go(Phase.MEAL)


func to_closing() -> void:
	_go(Phase.CLOSING)


func to_night() -> void:
	_go(Phase.NIGHT)


# The day's over: keep its summary for reopening later.
func to_summary(day_summary: Dictionary) -> void:
	summary = day_summary
	_go(Phase.SUMMARY)


func to_after_hours() -> void:
	_go(Phase.AFTER_HOURS)


# Debug: straight to a phase, whatever comes before it.
func force(to: Phase, meal_index := 0) -> void:
	meal = meal_index
	phase = to
	GameState.phase_done.clear()
	SaveGame.save_game()
	phase_changed.emit(phase)


func _go(to: Phase) -> void:
	if not to in NEXT[phase]:
		push_warning("Day phase %s can't go to %s" % [NAMES[phase], NAMES[to]])
	phase = to
	GameState.phase_done.clear()
	SaveGame.save_game()
	phase_changed.emit(phase)


# --- Saving ---------------------------------------------------------------------

func to_save_data() -> Dictionary:
	return { "phase": NAMES[phase], "meal": meal, "summary": summary, "reset_date": reset_date }


# From to_save_data(). Quitting during the summary comes back to After Hours
# (the summary can be reopened at the host stand).
func apply_save_data(data: Dictionary) -> void:
	var saved = NAMES.find_key(String(data.get("phase", "meal")))
	phase = saved if saved != null else Phase.MEAL
	if phase == Phase.SUMMARY:
		phase = Phase.AFTER_HOURS
	meal = int(data.get("meal", 0))
	summary = data.get("summary", {}) if data.get("summary", {}) is Dictionary else {}
	reset_date = String(data.get("reset_date", ""))


# Saves from before DayCycle had one number: a meal index, NIGHT, or CLOSED
# (closed until tomorrow, which is now After Hours).
func apply_old_phase(old_phase: int) -> void:
	summary = {}
	reset_date = GameState.date
	if old_phase == GameState.CLOSED:
		phase = Phase.AFTER_HOURS
	elif old_phase == GameState.NIGHT:
		phase = Phase.NIGHT
	else:
		phase = Phase.MEAL
		meal = old_phase
