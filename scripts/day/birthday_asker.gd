# BirthdayAsker: asks each chef their birthday on their first day (once the
# restaurant is open and they're free), in a dialogue box: the month, which
# part of it, then the day. Saved in GameState.birthdays ("" if they'd rather
# not say, so they aren't asked again). If it's today, the banner shows. The
# lines are in design/calendar/calendar.json (birthday_question).
class_name BirthdayAsker
extends Node

const CHECK_SECONDS := 1.0
const FIRST_ASK_DELAY := 5.0  # Seconds into the day before the first question.

var day_manager: DayManager
var view_manager: ViewManager

var _asking := false
var _wait := FIRST_ASK_DELAY


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0 or _asking or day_manager == null or not DayCycle.is_open():
		return
	_wait = CHECK_SECONDS
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		var account_id := Accounts.id_of(player.player_index)
		if account_id.is_empty() or GameState.birthdays.has(account_id):
			continue
		if player.movement_locked or player.held_item != null or player.in_conversation():
			continue
		_ask(player, account_id)
		return


func _ask(player: Player, account_id: String) -> void:
	_asking = true
	var lines: Dictionary = EventCalendar.data().get("birthday_question", {})
	var title: String = lines.get("title", "")
	player.movement_locked = true
	var box := ConversationBox.open(ConversationBox.parent_for(view_manager, player.player_index, self), player.player_index, "")
	var months: Array = EventCalendar.MONTHS.duplicate()
	months.append(lines.get("rather_not_say", "I'd rather not say"))
	var month := await box.ask(title, String(lines.get("ask_month", "When's your birthday?")).format({ "player": Accounts.name_of(player.player_index) }), months) + 1
	if month > 12:
		GameState.birthdays[account_id] = ""
		await box.tell(title, lines.get("no_thanks", "No problem!"))
	else:
		# The days in three parts, so the list fits: 1-10, 11-20, 21-end.
		var last := EventCalendar.days_in_month(month)
		var parts := [[1, 10], [11, 20], [21, last]]
		var month_name: String = EventCalendar.MONTHS[month - 1]
		var part: Array = parts[await box.ask(title, String(lines.get("ask_part", "Which part of {month}?")).format({ "month": month_name }),
			parts.map(func(p): return "%s %d to %d" % [month_name, p[0], p[1]]))]
		var days := range(part[0], part[1] + 1)
		var day: int = days[await box.ask(title, lines.get("ask_day", "And the day?"), days.map(func(d): return "%s %d" % [month_name, d]))]
		var month_day := "%02d-%02d" % [month, day]
		GameState.birthdays[account_id] = month_day
		await box.tell(title, String(lines.get("thanks", "Got it: {date}.")).format({ "date": EventCalendar.describe(month_day) }))
		if month_day == GameClock.calendar_date().substr(5):
			EventBanner.show_today(get_tree().current_scene)
	box.close()
	player.ignore_interact_until_released()
	player.movement_locked = false
	SaveGame.save_game()
	_asking = false
