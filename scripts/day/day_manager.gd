# DayManager: runs the restaurant day. One day per real day (see GameClock),
# made of meals (data/day.json: Breakfast, Lunch, Dinner), always starting at
# the first. No timer: each meal has its set of customers (GameState's plan),
# and once they've all been and gone, a player rings the bell at the counter
# for the next meal, and the lights change with it. Ringing it after the last
# meal closes up: anyone Gone who's due back comes to the door, any big moment
# scene due tonight plays (ScenePlayer), then the day ends: the game pauses and
# `day_ended` carries the summary for the summary screen. After that it's
# closed until tomorrow, and opening the game again the same day finds it
# closed (`closed_for_today`).
class_name DayManager
extends Node

signal day_closed
signal day_ended(summary: Dictionary)
signal closed_for_today  # Opened after closing on the same day: nothing to do until tomorrow.
signal phase_started(phase: int)

@export var customer_manager: CustomerManager
@export var delivery_manager: DeliveryManager
@export var scene_player: ScenePlayer
@export var sun: DirectionalLight3D               # Lit for each meal (data/day.json "lighting").
@export var world_environment: WorldEnvironment

var is_open := true       # During the meals; false from closing on.
var _has_ended := false
var _announced_bell := false
var _lighting: Tween


func _ready() -> void:
	customer_manager.day_manager = self
	GameState.begin_day()
	Music.play_hour_themes()  # In the restaurant the music follows the real hour.
	if GameState.is_closed_today():
		is_open = false
		_has_ended = true
		_light(GameData.day_settings.get("closing", {}).get("lighting", {}), 0.0)
		customer_manager.accepting_customers = false
		get_tree().set_deferred("paused", true)
		closed_for_today.emit.call_deferred()
		return
	_start_phase(GameState.phase, 0.0)


func _process(_delta: float) -> void:
	if _has_ended:
		return
	customer_manager.bell.wants_ringing = bell_ready()
	if is_open:
		if bell_ready() and not _announced_bell:
			_announced_bell = true
			GameEvents.announce("Everyone's been served! Ring the bell at the counter %s." % (
				"for %s" % GameState.phase_info(GameState.phase + 1).get("name", "the next meal") if not _is_last_phase() else "to close up"))
	elif not customer_manager.has_customers() and not _deliveries_waiting():
		if scene_player != null and scene_player.play_due():
			return  # Wait for tonight's big moment.
		_end_day()


# The meal's customers have all been and gone, so the bell can be rung.
func bell_ready() -> bool:
	return is_open and not _has_ended and customer_manager.phase_finished()


# The counter's prompt while the bell's ready, e.g. "Ring the bell: Lunch".
func bell_prompt() -> String:
	if _is_last_phase():
		return "Ring the bell: close up"
	return "Ring the bell: %s" % GameState.phase_info(GameState.phase + 1).get("name", "next meal")


# The bell was rung: the next meal, or closing after the last.
func ring_bell() -> void:
	if not bell_ready():
		return
	if _is_last_phase():
		_close()
	else:
		GameState.set_phase(GameState.phase + 1)
		_start_phase(GameState.phase)


# Debug: straight to meal `phase` (or closing, for GameState.CLOSED), sending
# everyone in the restaurant home.
func skip_to(phase: int) -> void:
	if _has_ended:
		return
	customer_manager.send_everyone_home()
	if phase == GameState.CLOSED:
		GameState.set_phase(GameState.phase_count() - 1)
		_close()
		return
	is_open = true
	GameState.set_phase(phase)
	_start_phase(phase)


# Called by the summary screen's button, only once it's a new day (or the
# debug panel made it one): a fresh restaurant; GameState (an autoload) keeps
# money and the date, and the new scene starts the new day.
func start_next_day() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _start_phase(phase: int, light_seconds := -1.0) -> void:
	_announced_bell = false
	var info := GameState.phase_info(phase)
	_light(info.get("lighting", {}), light_seconds)
	var plan := GameState.todays_plan()
	customer_manager.start_phase(plan[phase] if phase < plan.size() else [], GameState.phase_done)
	GameEvents.announce("%s time!" % info.get("name", "Meal"))
	phase_started.emit(phase)


func _is_last_phase() -> bool:
	return GameState.phase >= GameState.phase_count() - 1


func _deliveries_waiting() -> bool:
	return delivery_manager != null and delivery_manager.has_deliveries()


func _close() -> void:
	is_open = false
	customer_manager.bell.wants_ringing = false
	customer_manager.close()
	_light(GameData.day_settings.get("closing", {}).get("lighting", {}))
	GameEvents.announce("Closing time! Time to tidy up.")
	day_closed.emit()


func _end_day() -> void:
	_has_ended = true
	get_tree().paused = true
	var summary := DaySummary.build(GameState.services_today, GameState.chef_actions_today)
	summary["date"] = GameState.date
	summary["day_number"] = GameState.day_number
	GameState.close_day()  # Closed until tomorrow + save.
	day_ended.emit(summary)


# Fade the sun, ambient light and sky to a meal's lighting over `seconds`
# (-1: lighting_fade_seconds from data/day.json). Big moment scenes dim from
# whatever this sets (see ScenePlayer).
func _light(lighting: Dictionary, seconds := -1.0) -> void:
	if lighting.is_empty():
		return
	if seconds < 0.0:
		seconds = float(GameData.day_settings.get("lighting_fade_seconds", 2.5))
	if _lighting != null:
		_lighting.kill()
	_lighting = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # Carries on into the paused summary.
	var duration := maxf(seconds, 0.01)
	if sun != null:
		var energy := float(lighting.get("sun_energy", sun.light_energy))
		sun.set_meta("base_energy", energy)
		_lighting.tween_property(sun, "light_color", Color(lighting.get("sun_color", sun.light_color.to_html())), duration)
		_lighting.tween_property(sun, "light_energy", energy, duration)
	var environment: Environment = world_environment.environment if world_environment != null else null
	if environment != null:
		var ambient := float(lighting.get("ambient_energy", environment.ambient_light_energy))
		world_environment.set_meta("base_ambient", ambient)
		_lighting.tween_property(environment, "ambient_light_color", Color(lighting.get("ambient_color", environment.ambient_light_color.to_html())), duration)
		_lighting.tween_property(environment, "ambient_light_energy", ambient, duration)
		_lighting.tween_property(environment, "background_color", Color(lighting.get("sky_color", environment.background_color.to_html())), duration)
