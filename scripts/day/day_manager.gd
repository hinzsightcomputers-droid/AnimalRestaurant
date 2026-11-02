# DayManager: runs the restaurant day in the scene. One day per real day (see
# GameClock), made of meals (data/day.json: Breakfast, Lunch, Dinner), always
# starting at the first. Where the day is lives in DayCycle; this moves it on
# and makes the restaurant match. No timer: each meal has its set of customers
# (GameState's plan), and once they've all been and gone, a player rings the
# bell at the counter for the next meal, and the lights change with it.
# Ringing it after the last meal closes up: anyone Gone who's due back comes
# to the door, any big moment scene due tonight plays (ScenePlayer). Once the
# phone is on the wall (see GameState.phone_unlocked) the night shift follows:
# the chairs go up, the lights go down, nobody walks in, and the phone takes a
# few calls (night in data/phone.json). When it's gone quiet (or straight
# after closing, without a phone) the day ends: the game pauses and
# `day_ended` carries the summary for the summary screen. Closing that starts
# After Hours: closed to customers with the chairs up, the lights following
# the real hour, the doors open, and the host stand offering the shop and the
# day's summary again. Opening the game again the same day comes straight
# back to After Hours. Once it's 5 AM on a later day the sign or the host
# stand opens up for the new day (start_next_day).
# On launch a banner says if today's a special day (EventCalendar), and chefs
# are asked their birthday on their first day (BirthdayAsker).
class_name DayManager
extends Node

signal day_closed
signal day_ended(summary: Dictionary)
signal summary_requested  # Someone asked the host stand for today's summary (after hours).
signal phase_started(phase: int)

const AFTER_HOURS_LIGHT_CHECK_SECONDS := 60.0

@export var customer_manager: CustomerManager
@export var delivery_manager: DeliveryManager
@export var scene_player: ScenePlayer
@export var sun: DirectionalLight3D               # Lit for each meal (data/day.json "lighting").
@export var world_environment: WorldEnvironment
@export var phone: Phone                          # Takes the night shift's calls.

var _announced_bell := false
var _lighting: Tween
var _night_ending := false
var _after_hours_block := ""  # The hour block After Hours is lit for.
var _light_check_left := 0.0


func _ready() -> void:
	customer_manager.day_manager = self
	GameState.begin_day()
	Music.play_hour_themes()  # In the restaurant the music follows the real hour.
	EventBanner.show_today(self)  # "Happy Halloween!", birthdays (see EventCalendar).
	var birthday_asker := BirthdayAsker.new()  # Asks new chefs their birthday once it's open.
	birthday_asker.day_manager = self
	birthday_asker.view_manager = customer_manager.view_manager
	add_child(birthday_asker)
	DayCycle.new_day_waiting.connect(_announce_new_day)
	if GameState.phone_news:
		GameState.phone_news = false
		get_tree().create_timer(2.0, false).timeout.connect(func(): GameEvents.announce(String(GameData.service.get("phone_installed", "There's a phone on the wall now."))))
	match DayCycle.phase:
		DayCycle.Phase.SUMMARY, DayCycle.Phase.AFTER_HOURS:
			DayCycle.phase = DayCycle.Phase.AFTER_HOURS  # A summary left open: it's at the host stand.
			_start_after_hours(0.0)
		DayCycle.Phase.NIGHT:
			customer_manager.accepting_customers = false
			_start_night(0.0)
		DayCycle.Phase.CLOSING:  # Picked up mid-closing: anyone due back, tonight's scene, then on.
			customer_manager.close()
			_light(GameData.day_settings.get("closing", {}).get("lighting", {}), 0.0)
		_:
			_start_phase(DayCycle.meal, 0.0)


func _process(delta: float) -> void:
	customer_manager.bell.wants_ringing = bell_ready()
	match DayCycle.phase:
		DayCycle.Phase.MEAL:
			if bell_ready() and not _announced_bell:
				_announced_bell = true
				GameEvents.announce("Everyone's been served! Ring the bell at the counter %s." % (
					"for %s" % GameState.phase_info(DayCycle.meal + 1).get("name", "the next meal") if not DayCycle.is_last_meal() else "to close up, once every table and dish is clean"))
		DayCycle.Phase.CLOSING:
			if not customer_manager.has_customers() and not _deliveries_waiting():
				if scene_player != null and scene_player.play_due():
					return  # Wait for tonight's big moment.
				if GameState.phone_unlocked and phone != null:
					_start_night()
				else:
					_end_day()
		DayCycle.Phase.NIGHT:
			if not _night_ending and phone != null and phone.quiet_for_tonight() and not _deliveries_waiting() and not customer_manager.has_customers():
				_end_night()
		DayCycle.Phase.AFTER_HOURS:
			_light_check_left -= delta
			if _light_check_left <= 0.0:
				_light_check_left = AFTER_HOURS_LIGHT_CHECK_SECONDS
				if GameClock.hour_block() != _after_hours_block:
					_light_after_hours()


# The meal's customers have all been and gone, so the bell can be rung.
func bell_ready() -> bool:
	return DayCycle.is_open() and customer_manager.phase_finished()


# The counter's prompt while the bell's ready, e.g. "Ring the bell: Lunch".
func bell_prompt() -> String:
	if DayCycle.is_last_meal():
		return "Ring the bell: close up" if cleanup_left().is_empty() else "Clean up first!"
	return "Ring the bell: %s" % GameState.phase_info(DayCycle.meal + 1).get("name", "next meal")


# The bell was rung: the next meal, or closing after the last (once everything's
# clean). Whether it worked.
func ring_bell() -> bool:
	if not bell_ready():
		return false
	if DayCycle.is_last_meal():
		var left := cleanup_left()
		if not left.is_empty():
			GameEvents.announce("Clean up before closing: %s." % left)
			return false
		_close()
	else:
		DayCycle.to_meal(DayCycle.meal + 1)
		_start_phase(DayCycle.meal)
	return true


# What still needs cleaning before closing, e.g. "2 tables to clear, 1 to wipe,
# 5 dishes to wash", or "" when it's all done.
func cleanup_left() -> String:
	var to_clear := 0
	var to_wipe := 0
	var tables := {}
	for node in get_tree().get_nodes_in_group(CustomerManager.SEAT_GROUP):
		if node is Seat and node.table != null:
			tables[node.table] = true
	for table: DiningTable in tables:
		if not table.dishes.is_empty():
			to_clear += 1
		elif not table.spills.is_empty():
			to_wipe += 1
	var to_wash := 0
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		if node is Player and node.held_item is DishBin:
			to_wash += (node.held_item as DishBin).dishes.size()
	var sink := get_tree().get_first_node_in_group(Sink.GROUP) as Sink
	var washing := sink != null and sink.session != null
	var parts: Array[String] = []
	if to_clear > 0:
		parts.append("%d %s to clear" % [to_clear, "table" if to_clear == 1 else "tables"])
	if to_wipe > 0:
		parts.append("%d %s to wipe" % [to_wipe, "table" if to_wipe == 1 else "tables"])
	if to_wash > 0:
		parts.append("%d dirty %s to wash" % [to_wash, "dish" if to_wash == 1 else "dishes"])
	elif washing:
		parts.append("the washing-up to finish")
	return ", ".join(parts)


# Debug: straight to meal `meal` (DayCycle.Phase.MEAL), closing, the night
# shift or After Hours (ending the day without showing the summary), sending
# everyone in the restaurant home. Going back to a meal from later in the day
# reloads the restaurant.
func skip_to(target: DayCycle.Phase, meal := 0) -> void:
	if target == DayCycle.Phase.NIGHT and not GameState.phone_unlocked:
		GameEvents.announce("The night shift needs the phone: unlock it first.")
		return
	if target == DayCycle.phase and target != DayCycle.Phase.MEAL:
		return
	var going_back := target == DayCycle.Phase.MEAL and not DayCycle.is_open() \
		or DayCycle.is_after_hours() \
		or DayCycle.is_night() and target == DayCycle.Phase.CLOSING
	if going_back:
		GameState.night_calls_used = 0  # A night started again gets its calls again.
		DayCycle.force(target, meal if target == DayCycle.Phase.MEAL else GameState.phase_count() - 1)
		_reload()
		return
	customer_manager.send_everyone_home()
	match target:
		DayCycle.Phase.MEAL:
			DayCycle.force(DayCycle.Phase.MEAL, meal)
			_start_phase(meal)
		DayCycle.Phase.CLOSING:
			_close()
		DayCycle.Phase.NIGHT:
			if DayCycle.is_open():
				_close()
			_start_night()
		DayCycle.Phase.AFTER_HOURS:
			if DayCycle.is_open():
				_close()
			_end_day(false)
			enter_after_hours()


# The summary screen was closed (or the debug panel skipped it): After Hours.
func enter_after_hours() -> void:
	get_tree().paused = false
	if DayCycle.phase == DayCycle.Phase.SUMMARY:
		DayCycle.to_after_hours()
	_start_after_hours()


# After hours, from the host stand: today's summary (with the shop and friends) again.
func open_summary() -> void:
	if DayCycle.is_after_hours():
		get_tree().paused = true
		summary_requested.emit()


# It's a new restaurant day (5 AM has been) and someone opened up from the
# sign or the host stand: a fresh restaurant. GameState (an autoload) keeps
# money and the date, and the new scene starts the new day. Returns false
# (and does nothing) if it isn't a new day yet.
func start_next_day() -> bool:
	if not DayCycle.is_new_day_waiting():
		return false
	_reload()
	return true


func _reload() -> void:
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


func _deliveries_waiting() -> bool:
	return delivery_manager != null and delivery_manager.has_deliveries()


func _close() -> void:
	DayCycle.to_closing()
	customer_manager.bell.wants_ringing = false
	customer_manager.close()
	_light(GameData.day_settings.get("closing", {}).get("lighting", {}))
	GameEvents.announce("Closing time! Time to tidy up.")
	day_closed.emit()


# The night shift: night lighting, chairs up on the tables, and a few phone
# calls (picked now, or carried on from a save). `light_seconds` 0 = at once.
func _start_night(light_seconds := -1.0) -> void:
	if not DayCycle.is_night() or GameState.night_calls_total == 0:  # (0: the debug panel jumped here.)
		var calls: Dictionary = GameData.phone_settings.get("night", {}).get("calls", { "min": 3, "max": 5 })
		GameState.night_calls_total = randi_range(int(calls["min"]), int(calls["max"]))
		GameState.night_calls_used = 0
	if not DayCycle.is_night():
		DayCycle.to_night()
	_light(GameState.phase_info(GameState.NIGHT).get("lighting", {}), light_seconds)
	_put_chairs_up(light_seconds)
	if light_seconds != 0.0:
		GameEvents.announce("Night shift: chairs up, phone orders only.")
	phase_started.emit(GameState.NIGHT)


# The night's calls are done and delivered: say so, then end the day.
func _end_night() -> void:
	_night_ending = true
	GameEvents.announce("The phone has gone quiet. That's the day done!")
	await get_tree().create_timer(4.0, false).timeout
	_end_day()


# The day's over: its summary is kept (DayCycle) and, unless `show` is false
# (the debug panel skipping ahead), shown with the game paused.
func _end_day(show := true) -> void:
	var summary := DaySummary.build(GameState.services_today, GameState.chef_actions_today)
	summary["date"] = GameState.date
	summary["day_number"] = GameState.day_number
	GameState.close_day(summary)  # On to the summary + save.
	if show:
		get_tree().paused = true
		day_ended.emit(summary)


# After hours: nobody walks in or phones, the chairs are up, the lights follow
# the real hour, and the doors and the host stand's catalogue are open (they
# ask DayCycle). `light_seconds` 0 = at once (coming back to it on launch).
func _start_after_hours(light_seconds := -1.0) -> void:
	customer_manager.accepting_customers = false
	_put_chairs_up(light_seconds)
	_light_after_hours(light_seconds)
	GameEvents.announce("After hours! The doors are open. The host stand has the shop and today's summary.")
	if DayCycle.is_new_day_waiting():
		_announce_new_day()
	phase_started.emit(DayCycle.Phase.AFTER_HOURS)


func _announce_new_day() -> void:
	if DayCycle.phase == DayCycle.Phase.AFTER_HOURS:
		GameEvents.announce("A new day has started! Head inside to open up at the sign or the host stand.")


func _light_after_hours(light_seconds := -1.0) -> void:
	_after_hours_block = GameClock.hour_block()
	_light_check_left = AFTER_HOURS_LIGHT_CHECK_SECONDS
	_light(GameData.day_settings.get("after_hours", {}).get("lighting", {}).get(_after_hours_block, {}), light_seconds)


func _put_chairs_up(light_seconds: float) -> void:
	for node in get_tree().get_nodes_in_group(CustomerManager.SEAT_GROUP):
		if node is Seat:
			node.put_up(true, 0.0 if light_seconds == 0.0 else 0.6)


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
