# HUD: on-screen info. Shows the shift and money, the current orders as tickets
# (OrderTickets), and short messages from GameEvents. The real date and time sit big at the
# top: there when a shift starts, fading away as soon as anyone moves, and
# fading back once everyone has stood still for CLOCK_STILL_SECONDS.
# In split screen, anything over a view that's zoomed in on a minigame or a
# chat hides until it's done, so it doesn't cover it.
# Display only.
extends CanvasLayer

const CLOCK_STILL_SECONDS := 10.0
const CLOCK_FADE_SECONDS := 0.4
const MOVING_SPEED := 0.2  # A player going faster than this (m/s) counts as moving.
const MESSAGE_TIME := 4.0
const MAX_MESSAGES := 3
const MESSAGE_BOTTOM_GAP := 30.0  # Pixels from the bottom of the screen, with nothing below.
const MESSAGE_SPACING := 8.0      # Pixels kept between the messages and what's under them.
const MAX_ORDERS_IN_QUARTERS := 2  # In the four-way split.
const MAX_ORDERS_SHOWN := 3  # The rest are under them.
const ORDERS_PAGE_SECONDS := 8.0  # Looking through the rest, back to the first ones after this long.
const ORDER_TIMES_EVERY := 1.0  # Seconds between updates of the orders' time left.
const ORDERS_AT := Vector2(20.0, 16.0)  # From the screen's top left, or the corner of the view they're moved to.

@export var order_board: OrderBoard
@export var day_manager: DayManager

@onready var tickets: OrderTickets = $OrderTickets
@onready var money_label: Label = $MoneyLabel
@onready var streak_label: Label = $StreakLabel
@onready var message_label: Label = $MessageLabel
@onready var join_label: Label = $JoinLabel
@onready var clock: Control = $Clock
@onready var time_label: Label = $Clock/Lines/TimeLabel
@onready var date_label: Label = $Clock/Lines/DateLabel

var _messages: Array[Dictionary] = []  # Recent messages, oldest first: { text, time_left }
var _still_seconds := 0.0   # How long nobody has moved.
var _clock_shown := true    # Shown at the start of the shift.
var _clock_tween: Tween
var _view_manager: ViewManager
var _ui_scale := 1.0
var _order_times_left := 0.0
var _orders_page := 0       # Which few orders are showing: 0 the most urgent.
var _orders_page_left := 0.0


func _ready() -> void:
	_apply_style()
	order_board.changed.connect(_refresh_orders)
	GameEvents.message.connect(_show_message)
	_refresh_orders()
	message_label.text = ""
	var managers := get_tree().root.find_children("*", "ViewManager", true, false)
	_view_manager = managers.front() if not managers.is_empty() else null
	# Real values from the start: the game can open paused (the new-chef welcome),
	# and the labels would show the scene's placeholder text until the first frame.
	time_label.text = GameClock.describe_time(GameClock.now_local())
	date_label.text = GameClock.describe_date(GameState.date)
	_refresh_day_and_money.call_deferred()


func _process(delta: float) -> void:
	_look_through(delta)
	_refresh_scale()
	_refresh_day_and_money()
	_refresh_streak()
	_refresh_clock(delta)
	_place_clock()
	_refresh_join_hint()
	_place_orders()
	_keep_clear_of_close_ups()
	_place_messages()
	_order_times_left -= delta
	if _order_times_left <= 0.0:
		_order_times_left = ORDER_TIMES_EVERY
		_refresh_orders()
	if _messages.is_empty():
		return
	for message in _messages:
		message["time_left"] -= delta
	var count_before := _messages.size()
	_messages = _messages.filter(func(m): return m["time_left"] > 0.0)
	if _messages.size() != count_before:
		_refresh_messages()


# e.g. "Day 4  Lunch  Lunch rush 2:15   $18": which day and meal it is
# (DayCycle), the day curve's phase and the time left for arrivals
# (ArrivalPacing), then how many customers are still inside ("Ring the bell!"
# once they've all gone), the calls still to come at night, "After hours" once
# the day's done, and money. With the debug panel's pacing line on, a second
# line: phase, players, cap, waiting, next arrival.
func _refresh_day_and_money() -> void:
	var where := DayCycle.phase_name()
	if DayCycle.is_new_day_waiting():
		where = "New day! Open up inside"
	elif DayCycle.is_night():
		var calls := maxi(GameState.night_calls_total - GameState.night_calls_used, 0)
		where = "Night  %s" % ("%d call%s to come" % [calls, "" if calls == 1 else "s"] if calls > 0 else "quiet")
	elif DayCycle.is_open():
		var status := day_manager.customer_manager.status()
		var left := day_manager.customer_manager.customers_left()
		if day_manager.bell_ready():
			where = "%s  Ring the bell!" % DayCycle.phase_name()
		elif status["open"]:
			var part := "" if String(status["phase"]) == DayCycle.phase_name() else String(status["phase"]) + " "  # Not "Lunch  Lunch 5:25".
			where = "%s  %s%d:%02d" % [DayCycle.phase_name(), part, int(status["seconds"]) / 60, int(status["seconds"]) % 60]
		else:
			where = "%s  %d to go" % [DayCycle.phase_name(), left]
	money_label.text = "Day %d  %s   $%d" % [GameState.day_number, where, GameState.money]
	if ArrivalPacing.show_debug_line and DayCycle.is_open():
		money_label.text += "\n" + ArrivalPacing.debug_line(day_manager.customer_manager.status())


# The serving streak under the money, once it's paying something (ServiceStreak).
func _refresh_streak() -> void:
	var run := ServiceStreak.count
	streak_label.visible = run >= 2 and not DayCycle.is_after_hours()  # It starts over tomorrow: nothing to keep going tonight.
	if run >= 2:
		streak_label.text = String(ServiceStreak.settings().get("hud", "Streak x{count}")).format({
			"count": run, "percent": roundi(ServiceStreak.tip_percent(run)) })


# "8:42 PM" over "Tuesday, October 27". Hides while anyone moves; comes back
# after everyone has been still for a while.
func _refresh_clock(delta: float) -> void:
	time_label.text = GameClock.describe_time(GameClock.now_local())
	date_label.text = GameClock.describe_date(GameState.date)
	if _anyone_moving():
		_still_seconds = 0.0
		_show_clock(false)
	else:
		_still_seconds += delta
		if _still_seconds >= CLOCK_STILL_SECONDS:
			_show_clock(true)


# Centred at the top, but slid left when the day-and-money line is long
# enough to run under it ("Day 9  Breakfast  Opening 2:53  $1673" at 1080p).
func _place_clock() -> void:
	var box := clock.get_global_rect()
	var text_width := clock.get_combined_minimum_size().x * clock.get_global_transform().get_scale().x
	var centre := get_viewport().get_visible_rect().size.x / 2.0
	var text_right := centre + text_width / 2.0
	var room_right := money_label.get_global_rect().position.x - 24.0
	var shift := minf(0.0, room_right - text_right)
	clock.global_position.x = centre - box.size.x / 2.0 + shift


func _anyone_moving() -> bool:
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		if player != null and Vector2(player.velocity.x, player.velocity.z).length() > MOVING_SPEED:
			return true
	return false


func _show_clock(shown: bool) -> void:
	if shown == _clock_shown:
		return
	_clock_shown = shown
	if _clock_tween != null:
		_clock_tween.kill()
	_clock_tween = create_tween()
	_clock_tween.tween_property(clock, "modulate:a", 1.0 if shown else 0.0, CLOCK_FADE_SECONDS)


# e.g. "More players: Enter (arrow keys) or A (gamepad) to join". Hidden when full.
func _refresh_join_hint() -> void:
	var options := PackedStringArray()
	if not InputSetup.is_device_used("keys_left"):
		options.append("E (WASD)")
	if InputSetup.two_on_keyboard and not InputSetup.is_device_used("keys_right"):
		options.append("Enter (arrow keys)")
	options.append("A (gamepad)")
	# Not while anyone's talking: one less thing over the dialogue box.
	join_label.visible = InputSetup.active_players().size() < InputSetup.MAX_PLAYERS and get_tree().get_nodes_in_group(ConversationBox.GROUP).is_empty()
	join_label.text = "More players: press %s to join" % " or ".join(options)


func _keep_clear_of_close_ups() -> void:
	var close_ups := _view_manager.close_up_rects() if _view_manager != null else ([] as Array[Rect2])
	for control: Control in [tickets, money_label, clock]:
		control.visible = not close_ups.any(func(r: Rect2): return r.intersects(control.get_global_rect()))
	message_label.visible = message_label.text != "" and not close_ups.any(func(r: Rect2): return r.intersects(message_label.get_global_rect()))
	streak_label.visible = streak_label.visible and not close_ups.any(func(r: Rect2): return r.intersects(streak_label.get_global_rect()))
	join_label.visible = join_label.visible and not close_ups.any(func(r: Rect2): return r.intersects(join_label.get_global_rect()))


# The messages sit at the bottom of the screen, but above the join hint and
# above any dialogue box under them, so they never cover what someone's saying.
func _place_messages() -> void:
	var bottom := get_viewport().get_visible_rect().size.y - MESSAGE_BOTTOM_GAP
	if join_label.visible:
		bottom = minf(bottom, join_label.get_global_rect().position.y - MESSAGE_SPACING)
	var span := message_label.get_global_rect()
	for box in get_tree().get_nodes_in_group(ConversationBox.GROUP):
		var rect := _box_rect(box as Control)
		if rect.size.x > 0.0 and rect.position.x < span.end.x and rect.end.x > span.position.x:
			bottom = minf(bottom, rect.position.y - MESSAGE_SPACING)
	message_label.reset_size()  # Its board fits what it says now, not the longest it's said.
	message_label.global_position = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - message_label.size.x / 2.0, bottom - message_label.size.y)


# The visible panel of a dialogue box (the box itself may span its whole view).
func _box_rect(box: Control) -> Rect2:
	if box == null or not box.is_visible_in_tree():
		return Rect2()
	for child in box.find_children("*", "PanelContainer", true, false):
		if (child as Control).is_visible_in_tree():
			return (child as Control).get_global_rect()
	return box.get_global_rect()


# The tickets sit at the top left. In the four-way split, with player 1 zoomed in
# on something, they move down to the view below so everyone still has them.
func _place_orders() -> void:
	var place := ORDERS_AT
	var close_ups := _view_manager.close_up_rects() if _view_manager != null else ([] as Array[Rect2])
	var half := get_viewport().get_visible_rect().size.y * 0.5
	if close_ups.any(func(r: Rect2): return r.has_point(place) and r.end.y < half + 10.0):
		place.y += half
	tickets.position = place


# The first MAX_ORDERS_SHOWN orders, the most urgent first; any more are under
# them, a page at a time for whoever presses the orders button (_look_through).
# With a serving time limit (ServiceStreak.timed), a seated customer's order
# starts with how long is left to keep the streak going; without one, nothing.
func _refresh_orders() -> void:
	var orders := order_board.orders.duplicate()
	orders.sort_custom(func(a, b): return _urgency(a) < _urgency(b) or (_urgency(a) == _urgency(b) and a.number < b.number))
	var count := MAX_ORDERS_SHOWN if InputSetup.active_players().size() < 3 else MAX_ORDERS_IN_QUARTERS
	var pages := maxi(ceili(float(orders.size()) / count), 1)
	if _orders_page >= pages:
		_orders_page = 0
	var first := _orders_page * count
	var shown := orders.slice(first, first + count)
	var below := ""
	if pages > 1:
		var buttons: Array[String] = []  # Everyone's, each once.
		for player_index in InputSetup.active_players():
			if not InputSetup.orders_hint(player_index) in buttons:
				buttons.append(InputSetup.orders_hint(player_index))
		var button := " / ".join(buttons)
		below = "%d more   [%s] look through" % [orders.size() - count, button] if _orders_page == 0 else "%d to %d of %d   [%s] %s" % [first + 1, first + shown.size(), orders.size(), button, "next" if _orders_page + 1 < pages else "back to the first"]
	tickets.show_orders(shown, orders.size() - shown.size(), below, _ui_scale, _time_left)


# Anyone's orders button: the next few orders, round to the first ones again;
# left alone a while, it goes back to those by itself.
func _look_through(delta: float) -> void:
	for player_index in InputSetup.active_players():
		if not Input.is_action_just_pressed(InputSetup.action_name(player_index, "orders")):
			continue
		var player := Player.find(get_tree(), player_index)
		if player != null and (player.decorating or player.on_phone):
			continue  # It's another button there.
		_orders_page += 1
		_orders_page_left = ORDERS_PAGE_SECONDS
		_refresh_orders()
	if _orders_page > 0:
		_orders_page_left -= delta
		if _orders_page_left <= 0.0:
			_orders_page = 0
			_refresh_orders()


# Seconds left for a customer at a table waiting on this order, or INF for
# others (deliveries, gifts) and once it's late (nothing left to save).
func _urgency(order: Order) -> float:
	if not is_instance_valid(order.customer) or order.customer.state != Customer.State.WAITING_FOR_FOOD:
		return INF
	var left := ServiceStreak.seconds_left(order.customer)
	return left if left > 0.0 else INF


# "(42s) " for a customer at a table waiting on this order, "(late) " once it
# can't keep the streak going; nothing for others.
func _time_left(order: Order) -> String:
	if not is_instance_valid(order.customer) or order.customer.state != Customer.State.WAITING_FOR_FOOD:
		return ""
	if not ServiceStreak.timed():
		return ""
	var left := ServiceStreak.seconds_left(order.customer)
	return "(%ds) " % ceili(left) if left > 0.0 else "(late) "


# Smaller text in split screen, like the views' (see UiScale).
func _refresh_scale() -> void:
	var scale := _view_manager.ui_scale if _view_manager != null else 1.0
	if scale != _ui_scale:
		_ui_scale = scale
		UiScale.apply(self, scale)
		_refresh_orders()


func _show_message(text: String) -> void:
	_messages.append({"text": text, "time_left": MESSAGE_TIME})
	if _messages.size() > MAX_MESSAGES:
		_messages.pop_front()
	_refresh_messages()


func _refresh_messages() -> void:
	var lines := PackedStringArray()
	for message in _messages:
		lines.append(message["text"])
	message_label.text = "\n".join(lines)
	message_label.visible = not lines.is_empty()  # No empty slate.


# Chalk on little slate boards in wood frames, like the menu chalkboard by the
# door (data/ui_style.json "chalk"): the day and money, the streak, the clock and
# the messages each on a board; the join hint is chalk on its own.
func _apply_style() -> void:
	UiStyle.chalk_label(money_label, "money")
	UiStyle.chalk_label(streak_label, "streak")
	UiStyle.chalk_label(message_label)
	UiStyle.chalk_label(join_label, "text", false)
	UiStyle.chalk_label(time_label, "text", false)
	UiStyle.chalk_label(date_label, "money", false)
	clock.add_theme_stylebox_override("panel", UiStyle.chalk_board(22.0, 6.0))
