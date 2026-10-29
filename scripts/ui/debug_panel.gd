# DebugPanel: a developer tool for testing regulars, opened and closed with F3.
# Pick a regular to see everything they remember, set their relationship (or
# jump to a stage), queue them to visit next, or reset them. It can also fake the
# date forward to test "you've been gone" lines, show and re-roll which regulars
# come in today, ring the phone for any caller or fill its voicemail, send a
# regular to Gone and skip through winning them back, and play each big moment
# scene at closing (or set up its trigger), and practice close-up recipes or
# put only one dish on the menu. The game pauses while it's open, and changes are
# saved when it closes. Built in code, since it's only a tool.
extends CanvasLayer

const TOGGLE_KEY := KEY_F3
const PANEL_WIDTH := 460
const DAY_STEPS := [1, 3, 7]

var _regular_picker: OptionButton
var _info: Label
var _slider: HSlider
var _slider_label: Label
var _stage_buttons: HBoxContainer
var _date_label: Label
var _queue_label: Label
var _schedule_label: Label
var _caller_picker: OptionButton
var _phone_label: Label
var _gone_label: Label
var _scene_label: Label
var _kitchen_label: Label
var _dish_picker: OptionButton
var _was_paused := false
var _players_label: Label
var _changed := false     # Something to save when the panel closes.
var _updating := false    # True while _refresh moves the slider, so it isn't treated as an edit.


func _ready() -> void:
	visible = false
	_build()


# _input, not _unhandled_input, so F3 works whatever has focus.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == TOGGLE_KEY:
		get_viewport().set_input_as_handled()
		_set_open(not visible)


func _set_open(open: bool) -> void:
	visible = open
	if open:
		_was_paused = get_tree().paused
		get_tree().paused = true
		_refresh()
	else:
		get_tree().paused = _was_paused
		if _changed:
			SaveGame.save_game()
			_changed = false


func _selected_id() -> String:
	return _regular_picker.get_item_metadata(_regular_picker.selected) if _regular_picker.item_count > 0 else ""


func _selected_record() -> Dictionary:
	return GameState.regulars.get(_selected_id(), {})


# --- Actions ---------------------------------------------------------------

func _skip_days(days: int) -> void:
	GameClock.set_offset_days(GameClock.offset_days() + days)
	_refresh()


# Another player without a gamepad: Player 2 gets the arrow keys (and Enter),
# Players 3 and 4 no device at all (they stand still until "WASD: P3").
# Each gets a "Test chef" account (made once, then reused), with no birthday
# question, so nothing waits on input they can't give.
func _add_player() -> void:
	var player_manager := get_tree().root.find_children("*", "PlayerManager", true, false).front() as PlayerManager
	var players := InputSetup.active_players()
	if player_manager == null or players.size() >= InputSetup.MAX_PLAYERS:
		return
	var index := 0
	while index in players:
		index += 1
	var account := Accounts.find_by_name("Test chef %d" % (index + 1))
	if account.is_empty():
		account = Accounts.create("Test chef %d" % (index + 1))
	if Accounts.is_in_use(account["id"]):
		return
	Accounts.assign(index, account["id"])
	GameState.birthdays[account["id"]] = GameState.birthdays.get(account["id"], "")
	_changed = true
	InputSetup.assign_device(index, "keys_right" if not InputSetup.is_device_used("keys_right") else "debug_%d" % index)
	player_manager._spawn(index)
	_refresh()


# Everyone to a different corner of the dining room, so each gets their own view.
func _spread_players() -> void:
	var spots := [Vector3(-6, 0, 4), Vector3(6, 0, 4), Vector3(-6, 0, -4), Vector3(6, 0, -4)]
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		player.global_position = spots[player.player_index % spots.size()]
		player.reset_physics_interpolation()


# WASD (and E) move `index` instead; whoever had them stands still.
func _control_player(index: int) -> void:
	if Player.find(get_tree(), index) == null:
		return
	for other in InputSetup.active_players():
		if other != index and InputSetup.device_of(other) == "keys_left":
			InputSetup.assign_device(other, "debug_%d" % other)
	InputSetup.assign_device(index, "keys_left")
	_refresh()


func _real_date() -> void:
	GameClock.set_offset_days(0)
	_refresh()


# Move the date forward to the next holiday or birthday (see EventCalendar).
# Restart the game (or force a new day) to see its banner on launch.
func _next_special_day() -> void:
	var today := GameClock.calendar_date()
	var next := EventCalendar.next_event_after(today)
	if next.is_empty():
		return
	var days := roundi((Time.get_unix_time_from_datetime_string(next) - Time.get_unix_time_from_datetime_string(today)) / 86400.0)
	_skip_days(days)


# Every chef gets asked their birthday again.
func _forget_birthdays() -> void:
	GameState.birthdays.clear()
	_changed = true
	_refresh()


func _on_slider_changed(value: float) -> void:
	if _updating:
		return
	RegularMemory.set_relationship(_selected_record(), int(value))
	_changed = true
	_refresh()


# Jump to where a stage starts: its lowest value when friendly, its highest when
# not (so -1 is "just slipped below 0").
func _jump_to_stage(stage: int) -> void:
	var stages: Array = GameData.regular_settings.get("stages", [])
	for i in stages.size():
		if int(stages[i]["stage"]) == stage:
			var value: int = stages[i]["min"] if stage > 0 else stages[i - 1]["min"] - 1
			RegularMemory.set_relationship(_selected_record(), value)
	_changed = true
	_refresh()


func _visit_next() -> void:
	GameState.forced_visitors.append(_selected_id())
	_refresh()


# The next regular who's close enough asks you to pick their dish.
func _force_pick_for_me() -> void:
	GameState.force_pick_for_me = true
	_refresh()


# They forget every chef's name (and nicknames, and Mabel's name test), so the
# name moment plays again next time they're at stage 2 or higher.
func _forget_names() -> void:
	var record := _selected_record()
	record["known_players"].clear()
	if record.has("nicknames"):
		record["nicknames"].clear()
	if record.has("name_test_passed"):
		record["name_test_passed"] = false
	_changed = true
	_refresh()


func _reset_character() -> void:
	GameState.reset_regular(_selected_id())
	GameState.forced_visitors.erase(_selected_id())
	_changed = true
	_refresh()


func _replan_today() -> void:
	GameState.replan_today()
	_refresh()


func _add_money() -> void:
	GameState.add_money(100)
	_changed = true


# Clears the name, so the start screen asks for one again (next time it shows).
func _rename_restaurant() -> void:
	GameState.restaurant_name = ""
	_changed = true
	GameEvents.announce("The restaurant will be renamed on the start screen.")


# The phone rings for the picked caller as soon as the panel closes.
func _ring_phone() -> void:
	GameState.forced_caller = _caller_picker.get_item_metadata(_caller_picker.selected)
	_refresh()


func _fill_voicemail() -> void:
	PhoneCalls.fill_voicemail()
	_changed = true
	_refresh()


func _clear_voicemail() -> void:
	GameState.voicemails.clear()
	_changed = true
	_refresh()


# Gone: they phone in one last order right away, and its courier brings their goodbye note.
func _final_call() -> void:
	var record := _selected_record()
	RegularMemory.set_relationship(record, -80)
	record["goodbye_given"] = false
	record["last_called"] = ""
	GameState.forced_caller = record["id"]
	_changed = true
	_refresh()


# Straight to Gone, skipping the last order and note.
func _gone_now() -> void:
	var record := _selected_record()
	RegularMemory.set_relationship(record, -80)
	Redemption.say_goodbye(record)
	_changed = true
	_refresh()


# The letter you sent has been with them long enough: the reply (or the
# silence, if it wasn't sincere) comes now.
func _letter_due() -> void:
	var record := _selected_record()
	if not String(record["letter_date"]).is_empty():
		record["letter_date"] = Redemption.add_days(GameState.date, -int(Redemption.settings().get("letter_reply_days", 3)))
		_changed = true
	_refresh()


# They come in at closing this shift, as if a letter or a friend had worked.
func _back_at_closing() -> void:
	var record := _selected_record()
	if Redemption.is_gone(record):
		record["returns_on"] = GameState.date
		_changed = true
	_refresh()


func _close_now() -> void:
	_skip_to_phase(GameState.CLOSED)


# Straight to a meal (or closing), sending everyone in the restaurant home.
func _skip_to_phase(phase: int) -> void:
	for day in get_tree().root.find_children("*", "DayManager", true, false):
		day.skip_to(phase)
	_refresh()


# Today counts as over (even if it isn't), and the restaurant reopens for a new
# day straight away: a fresh plan at the first meal.
func _force_new_day() -> void:
	GameState.date = ""
	SaveGame.save_game()
	_set_open(false)
	get_tree().paused = false
	get_tree().reload_current_scene()


# The scene plays at closing this shift, once the last customer has left.
func _play_scene(scene_id: String) -> void:
	GameState.forced_scene = scene_id
	_refresh()


# Everything its trigger needs: 90 relationship, 3 visits at stage 4, and its
# setup (Cheddar knowing your favorite food, Mabel's story told), not played yet.
func _meet_trigger(scene_id: String) -> void:
	var scene := GameData.get_scene(scene_id)
	var record: Dictionary = GameState.regulars[scene["regular"]]
	RegularMemory.set_relationship(record, 90)
	record["visits_by_stage"]["4"] = maxi(3, int(record["visits_by_stage"].get("4", 0)))
	record["big_moment_done"] = false
	if record.has("player_favorite") and String(record["player_favorite"]).is_empty():
		record["player_favorite"] = GameData.dishes[0]["id"]
	if record.has("story_part"):
		record["story_part"] = maxi(3, int(record["story_part"]))
	_changed = true
	_refresh()


func _clear_unlocks() -> void:
	GameState.unlocks.clear()
	GameState.unlocks_changed.emit()
	_changed = true
	_refresh()


# --- Display ---------------------------------------------------------------

func _refresh() -> void:
	_players_label.text = "  ".join(PackedStringArray(InputSetup.active_players().map(func(i): return "P%d %s (%s)" % [
		i + 1, Accounts.name_of(i), { "keys_left": "WASD", "keys_right": "arrows" }.get(InputSetup.device_of(i), "pad" if InputSetup.device_of(i).begins_with("pad_") else "idle")])))
	var offset := GameClock.offset_days()
	var events: Array = EventCalendar.events_on(GameClock.calendar_date()).map(func(e): return e["banner"])
	var birthdays: Array = GameState.birthdays.keys().map(func(id): return "%s: %s" % [
		Accounts.get_account(id).get("name", "?"), EventCalendar.describe(GameState.birthdays[id]) if GameState.birthdays[id] != "" else "rather not say"])
	_date_label.text = "Game date: %s%s
Today: %s
Next special day: %s
Chef birthdays: %s" % [GameClock.now_string().left(10),
		"  (real date + %d days)" % offset if offset > 0 else "  (real date)",
		" / ".join(PackedStringArray(events)) if not events.is_empty() else "nothing special",
		EventCalendar.next_event_after(GameClock.calendar_date()),
		", ".join(PackedStringArray(birthdays)) if not birthdays.is_empty() else "none yet"]

	var meals := PackedStringArray()
	var plan := GameState.todays_plan()
	for i in plan.size():
		var regulars := PackedStringArray()
		var walk_ins := 0
		for entry in plan[i]:
			if entry.has("regular"):
				var visitor: Dictionary = GameState.regulars.get(entry["regular"], {})
				regulars.append("%s%s" % [visitor.get("name", entry["regular"]), " (came)" if RegularMemory.visited_today(visitor) else ""])
			else:
				walk_ins += 1
		var now := " <- now" if i == GameState.phase else ""
		meals.append("%s: %d townsfolk%s%s%s" % [GameState.phase_info(i).get("name", "?"), walk_ins, ", " if not regulars.is_empty() else "", ", ".join(regulars), now])
	var state := "closed" if GameState.phase == GameState.CLOSED else (
		"night, %d of %d calls" % [GameState.night_calls_used, GameState.night_calls_total] if GameState.phase == GameState.NIGHT
		else "%d of this meal done" % GameState.phase_done.size())
	_schedule_label.text = "Day %d, %s (%s)
%s" % [GameState.day_number, GameClock.describe_date(GameState.date), state, "
".join(meals)]

	_phone_label.text = "Phone: %s.  Voicemails: %d%s" % [
		"on the wall" if GameState.phone_unlocked else ("goes up tomorrow" if GameState.delivery_asked else "not yet (a townsfolk asks at the bill on day 3+)"),
		GameState.voicemails.size(),
		"   Rings next: %s" % GameState.forced_caller if not GameState.forced_caller.is_empty() else ""]

	var record := _selected_record()
	if record.is_empty():
		_info.text = "No regulars found in data/characters/."
		return
	_updating = true
	_slider.value = record["relationship"]
	_updating = false
	_slider_label.text = "%+d  (stage %d: %s)" % [record["relationship"], RegularMemory.stage_of(record), RegularMemory.stage_name(record)]
	_update_stage_buttons(record)
	_info.text = _info_text(record)

	var names := PackedStringArray()
	for regular_id in GameState.forced_visitors:
		names.append(GameState.regulars[regular_id]["name"])
	_gone_label.text = _gone_text(record)
	var scene_lines := PackedStringArray()
	for scene in GameData.scenes:
		var scene_record: Dictionary = GameState.regulars.get(scene["regular"], {})
		var status := "done" if scene_record.get("big_moment_done", false) else ("due at closing" if BigMoments.is_ready(scene) else "not yet")
		if GameState.forced_scene == scene["id"]:
			status = "playing at closing (forced)"
		scene_lines.append("%s: %s" % [scene["name"], status])
	scene_lines.append("Unlocked: %s" % (", ".join(GameState.unlocks.map(BigMoments.reward_name)) if not GameState.unlocks.is_empty() else "nothing yet"))
	_scene_label.text = "\n".join(scene_lines)
	_queue_label.text = "Coming next: %s (at the next free seat)" % ", ".join(names) if not names.is_empty() else ""


# Every memory field, plus a few things worked out from them.
func _info_text(record: Dictionary) -> String:
	var lines := PackedStringArray()
	var days := RegularMemory.days_away(record, GameClock.now_unix())
	lines.append("Days since last visit: %s" % (str(days) if days >= 0 else "never visited"))
	lines.append("Visits in person: %s" % ("yes" if RegularMemory.visits_in_person(record) else "no (stays away)"))
	var known := PackedStringArray()
	for account_id in record["known_players"]:
		known.append(Accounts.get_account(account_id).get("name", account_id))
	lines.append("Knows the names of: %s" % (", ".join(known) if not known.is_empty() else "nobody"))
	lines.append("")
	for field in GameData.memory_fields(record["id"]):
		if field in ["relationship", "known_players"]:
			continue
		var value = record[field]
		lines.append("%s: %s" % [field, JSON.stringify(value) if value is Array or value is Dictionary or value is String else str(value)])
	return "\n".join(lines)


func _gone_text(record: Dictionary) -> String:
	var permanent_after := int(Redemption.settings().get("permanent_after", 2))
	var state := "Gone%s" % (" for good" if Redemption.is_permanent(record) else "") if Redemption.is_gone(record) \
		else ("fallen to Gone: last order (with the note) still to come" if Redemption.goodbye_due(record) else "not Gone")
	var lines := PackedStringArray(["%s %s. Times gone: %d of %d." % [record["name"], state, int(record["times_gone"]), permanent_after]])
	if not String(record["letter_date"]).is_empty():
		lines.append("Letter sent %s (%s). Answer due %s." % [record["letter_date"], "sincere" if record["letter_sincere"] else "not sincere",
			Redemption.add_days(record["letter_date"], int(Redemption.settings().get("letter_reply_days", 3)))])
	if not String(record["returns_on"]).is_empty():
		lines.append("Comes back at closing on %s." % record["returns_on"])
	return "\n".join(lines)


# One button per stage, named for this regular (e.g. "Nervous").
func _update_stage_buttons(record: Dictionary) -> void:
	for child in _stage_buttons.get_children():
		child.queue_free()
	var names: Dictionary = GameData.characters.get(record["id"], {}).get("stage_names", {})
	for entry in GameData.regular_settings.get("stages", []):
		var stage := int(entry["stage"])
		var button := Button.new()
		button.text = "%+d" % stage
		button.tooltip_text = names.get(str(stage), "")
		button.disabled = stage == RegularMemory.stage_of(record)
		button.pressed.connect(_jump_to_stage.bind(stage))
		_stage_buttons.add_child(button)


# --- Layout ----------------------------------------------------------------

func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.custom_minimum_size.x = PANEL_WIDTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	_add_label(box, "Debug panel  (F3 to close)", 22)

	_add_label(box, "Date", 18, true)
	_date_label = _add_label(box, "")
	var date_row := _add_row(box)
	for days in DAY_STEPS:
		_add_button(date_row, "+%d day%s" % [days, "" if days == 1 else "s"], _skip_days.bind(days))
	_add_button(date_row, "Real date", _real_date)
	var event_row := _add_row(box)
	_add_button(event_row, "Next special day", _next_special_day)
	_add_button(event_row, "Show today's banner", func(): EventBanner.show_today(get_tree().current_scene))
	_add_button(event_row, "Forget birthdays", _forget_birthdays)

	_add_label(box, "Today", 18, true)
	_schedule_label = _add_label(box, "")
	var phase_row := _add_row(box)
	for i in GameState.phase_count():
		_add_button(phase_row, GameState.phase_info(i).get("name", "?"), _skip_to_phase.bind(i))
	_add_button(phase_row, "Closing", _skip_to_phase.bind(GameState.CLOSED))
	_add_button(phase_row, "Night", _skip_to_phase.bind(GameState.NIGHT))
	var today_row := _add_row(box)
	_add_button(today_row, "Re-roll today", _replan_today)
	_add_button(today_row, "Force a new day", _force_new_day)

	_add_label(box, "Regulars", 18, true)
	_regular_picker = OptionButton.new()
	for regular_id in GameState.regulars:
		_regular_picker.add_item(GameState.regulars[regular_id]["name"])
		_regular_picker.set_item_metadata(_regular_picker.item_count - 1, regular_id)
	_regular_picker.item_selected.connect(func(_index): _refresh())
	box.add_child(_regular_picker)

	_slider_label = _add_label(box, "")
	_slider = HSlider.new()
	_slider.min_value = GameData.regular_settings.get("relationship_min", -100)
	_slider.max_value = GameData.regular_settings.get("relationship_max", 100)
	_slider.step = 1
	_slider.value_changed.connect(_on_slider_changed)
	box.add_child(_slider)
	_stage_buttons = _add_row(box)

	var actions := _add_row(box)
	_add_button(actions, "Visit next", _visit_next)
	_add_button(actions, "Reset character", _reset_character)
	_add_button(actions, "Next order: pick for me", _force_pick_for_me)
	_add_button(actions, "Forget names", _forget_names)
	_queue_label = _add_label(box, "")
	_info = _add_label(box, "")

	_add_label(box, "Gone and redemption", 18, true)
	_add_label(box, "For the regular picked above.")
	var gone_row := _add_row(box)
	_add_button(gone_row, "Final call now", _final_call)
	_add_button(gone_row, "Gone now", _gone_now)
	var gone_row_2 := _add_row(box)
	_add_button(gone_row_2, "Letter answer now", _letter_due)
	_add_button(gone_row_2, "Back at closing", _back_at_closing)
	_add_button(gone_row_2, "Close now", _close_now)
	_gone_label = _add_label(box, "")

	_add_label(box, "Scenes", 18, true)
	for scene in GameData.scenes:
		var scene_row := _add_row(box)
		_add_label(scene_row, scene["name"]).custom_minimum_size.x = 170
		_add_button(scene_row, "Play at closing", _play_scene.bind(scene["id"]))
		_add_button(scene_row, "Meet trigger", _meet_trigger.bind(scene["id"]))
	var scene_row_2 := _add_row(box)
	_add_button(scene_row_2, "Close now", _close_now)
	_add_button(scene_row_2, "Clear unlocks", _clear_unlocks)
	_scene_label = _add_label(box, "")

	_add_label(box, "Kitchen", 18, true)
	var kitchen_row := _add_row(box)
	_add_button(kitchen_row, "Practice pancakes (P1)", _practice.bind("pancakes"))
	_add_button(kitchen_row, "Practice soup (P1)", _practice.bind("soup"))
	_add_button(kitchen_row, "Only serve pancakes", _only_serve.bind("honey_pancakes"))
	var chopping_row := _add_row(box)
	_add_button(chopping_row, "Practice chopping (P1)", _practice_chopping)
	_add_button(chopping_row, "Only serve vegetable soup", _only_serve.bind("vegetable_soup"))
	_add_button(kitchen_row, "Whole menu", _only_serve.bind(""))
	var fish_row := _add_row(box)
	_add_button(fish_row, "Practice filleting (P1)", _practice_chopping.bind("filleting"))
	_add_button(fish_row, "Practice fish stew (P1)", _practice.bind("fish_stew"))
	var cookie_row := _add_row(box)
	_add_button(cookie_row, "Practice acorn cookies (P1)", _practice.bind("acorn_cookies", "oven"))
	_add_button(cookie_row, "Unlock all dishes", _unlock_all_dishes)
	_add_button(cookie_row, "Unlock all drinks", _unlock_all_drinks)
	var any_dish_row := _add_row(box)
	_dish_picker = OptionButton.new()
	for dish in GameData.dishes:
		_dish_picker.add_item(dish["name"])
		_dish_picker.set_item_metadata(_dish_picker.item_count - 1, dish["id"])
	any_dish_row.add_child(_dish_picker)
	_add_button(any_dish_row, "Practice it (P1)", _practice_picked)
	_add_button(any_dish_row, "Only serve it", func(): _only_serve(_picked_dish()["id"]))
	var dishes_row := _add_row(box)
	_add_button(dishes_row, "Make tables messy", _make_tables_messy)
	_add_button(dishes_row, "Empty the plate rack", _empty_rack)
	_kitchen_label = _add_label(box, "")

	_add_label(box, "Players", 18, true)
	_players_label = _add_label(box, "")
	var players_row := _add_row(box)
	_add_button(players_row, "Add a player", _add_player)
	_add_button(players_row, "Spread players out", _spread_players)
	var control_row := _add_row(box)
	for i in InputSetup.MAX_PLAYERS:
		_add_button(control_row, "WASD: P%d" % (i + 1), _control_player.bind(i))

	_add_label(box, "Phone", 18, true)
	_caller_picker = OptionButton.new()
	for caller in GameData.callers:
		_caller_picker.add_item("%s (%s)" % [caller["name"], caller["species"]])
		_caller_picker.set_item_metadata(_caller_picker.item_count - 1, caller["id"])
	for regular_id in GameState.regulars:  # They only call when Withdrawn (to order) or at their top stage (to chat).
		_caller_picker.add_item("%s (regular)" % GameState.regulars[regular_id]["name"])
		_caller_picker.set_item_metadata(_caller_picker.item_count - 1, regular_id)
	box.add_child(_caller_picker)
	var phone_row := _add_row(box)
	_add_button(phone_row, "Ring now", _ring_phone)
	_add_button(phone_row, "Fill voicemail", _fill_voicemail)
	_add_button(phone_row, "Clear voicemail", _clear_voicemail)
	var phone_row_2 := _add_row(box)
	_add_button(phone_row_2, "Unlock the phone", _unlock_phone)
	_add_button(phone_row_2, "Remove the phone", _remove_phone)
	_phone_label = _add_label(box, "")

	_add_label(box, "Money", 18, true)
	_add_button(_add_row(box), "+$100", _add_money)

	_add_label(box, "Restaurant", 18, true)
	_add_button(_add_row(box), "Rename restaurant", _rename_restaurant)


# --- Kitchen ---------------------------------------------------------------

# Player 1 cooks the recipe at the stove right away, with no order. Closes the panel.
func _practice(recipe_id: String, station_id := "stove") -> void:
	var stations := get_tree().root.find_children("*", "CookingStation", true, false).filter(func(s): return s.station_id == station_id)
	var stove: CookingStation = stations.front() if not stations.is_empty() else null
	var recipe := CookRecipe.for_dish({ "recipe": recipe_id })
	if stove == null or recipe == null:
		return
	_set_open(false)
	stove.practice(Player.find(get_tree(), 0), recipe)


func _picked_dish() -> Dictionary:
	return GameData.get_dish(_dish_picker.get_item_metadata(_dish_picker.selected))


# The dish picked in the Kitchen section, at its own station (dishes without a
# close-up recipe have nothing to practice).
func _practice_picked() -> void:
	var dish := _picked_dish()
	if not dish.has("recipe"):
		_kitchen_label.text = "%s has no close-up recipe." % dish["name"]
		return
	_practice(dish["recipe"], CookingStation.station_of(dish))


# Player 1 chops at the board right away, with nothing to hand back. Closes the panel.
func _practice_chopping(recipe_id := "chopping") -> void:
	var boards := get_tree().root.find_children("*", "ChoppingBoard", true, false)
	if boards.is_empty():
		return
	_set_open(false)
	boards.front().practice(Player.find(get_tree(), 0), CookRecipe.for_dish({ "recipe": recipe_id }))


# Every table gets a dirty dish (a plate or a soup bowl) at each of its chairs.
func _make_tables_messy() -> void:
	var dishes := [{}, GameData.get_dish("vegetable_soup")]
	var i := 0
	for seat in get_tree().root.find_children("*", "Seat", true, false):
		if seat.table != null and seat.table.session == null:
			seat.table.make_dirty(seat.meal_position(), dishes[i % dishes.size()])
			i += 1
	_kitchen_label.text = "Made %d dirty dishes." % i


func _empty_rack() -> void:
	var sink := get_tree().get_first_node_in_group(Sink.GROUP) as Sink
	if sink != null:
		while sink.take_plate():
			pass
		_kitchen_label.text = "No clean plates left."


# Every dish on the menu, as if they were all bought (and the scene ones played).
func _unlock_all_drinks() -> void:
	for drink in GameData.shop_drinks():
		if not drink["id"] in GameState.unlocks:
			GameState.unlocks.append(drink["id"])
	GameState.unlocks_changed.emit()
	_changed = true
	_refresh()


# The phone goes up right away (as if a customer had asked yesterday).
func _unlock_phone() -> void:
	GameState.delivery_asked = true
	GameState.phone_unlocked = true
	_changed = true
	_refresh()


# Back to no phone, and nobody's asked yet (to see the unlock again).
func _remove_phone() -> void:
	GameState.delivery_asked = false
	GameState.phone_unlocked = false
	_changed = true
	_refresh()


func _unlock_all_dishes() -> void:
	for dish in GameData.dishes:
		if not GameData.is_unlocked(dish["id"]):
			GameState.unlocks.append(dish["id"])
	GameState.unlocks_changed.emit()
	_changed = true
	_kitchen_label.text = "All %d dishes are on the menu." % GameData.dishes.size()


func _only_serve(dish_id: String) -> void:
	GameState.forced_dish = dish_id
	_kitchen_label.text = "Only %s on the menu (until you restart)." % GameData.get_dish(dish_id).get("name", dish_id) if not dish_id.is_empty() else "The whole menu again."


func _add_label(parent: Control, text: String, font_size := 15, heading := false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	if heading:
		label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	parent.add_child(label)
	return label


func _add_row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button
