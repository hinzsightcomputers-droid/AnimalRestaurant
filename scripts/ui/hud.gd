# HUD: on-screen info. Shows the shift and money, lists current orders, and
# shows short messages from GameEvents. The real date and time sit big at the
# top: there when a shift starts, fading away as soon as anyone moves, and
# fading back once everyone has stood still for CLOCK_STILL_SECONDS.
# Display only.
extends CanvasLayer

const CLOCK_STILL_SECONDS := 10.0
const CLOCK_FADE_SECONDS := 0.4
const MOVING_SPEED := 0.2  # A player going faster than this (m/s) counts as moving.
const MESSAGE_TIME := 4.0
const MAX_MESSAGES := 3
const MAX_ORDERS_SHOWN := 3  # Then "+2 more", so the list doesn't fill the screen.
const STATE_NAMES := {
	Order.State.WAITING: "waiting",
	Order.State.GATHERED: "ingredients out",
	Order.State.COOKING: "cooking",
	Order.State.READY: "ready",
}

@export var order_board: OrderBoard
@export var day_manager: DayManager

@onready var orders_label: Label = $OrdersLabel
@onready var money_label: Label = $MoneyLabel
@onready var message_label: Label = $MessageLabel
@onready var join_label: Label = $JoinLabel
@onready var clock: Control = $Clock
@onready var time_label: Label = $Clock/TimeLabel
@onready var date_label: Label = $Clock/DateLabel

var _messages: Array[Dictionary] = []  # Recent messages, oldest first: { text, time_left }
var _still_seconds := 0.0   # How long nobody has moved.
var _clock_shown := true    # Shown at the start of the shift.
var _clock_tween: Tween
var _view_manager: ViewManager
var _ui_scale := 1.0


func _ready() -> void:
	order_board.changed.connect(_refresh_orders)
	GameEvents.message.connect(_show_message)
	_refresh_orders()
	message_label.text = ""
	var managers := get_tree().root.find_children("*", "ViewManager", true, false)
	_view_manager = managers.front() if not managers.is_empty() else null


func _process(delta: float) -> void:
	_refresh_scale()
	_refresh_day_and_money()
	_refresh_clock(delta)
	_refresh_join_hint()
	if _messages.is_empty():
		return
	for message in _messages:
		message["time_left"] -= delta
	var count_before := _messages.size()
	_messages = _messages.filter(func(m): return m["time_left"] > 0.0)
	if _messages.size() != count_before:
		_refresh_messages()


# e.g. "Day 4  Lunch  3 to come   $18": which day and meal it is, how many of
# its customers haven't left yet ("Ring the bell!" once they all have,
# "Closed" from closing on, the calls still to come at night), and money.
func _refresh_day_and_money() -> void:
	var where := "Closed"
	if day_manager.is_night:
		var calls := maxi(GameState.night_calls_total - GameState.night_calls_used, 0)
		where = "Night  %s" % ("%d call%s to come" % [calls, "" if calls == 1 else "s"] if calls > 0 else "quiet")
	elif day_manager.is_open:
		var left := day_manager.customer_manager.customers_left()
		where = "%s  %s" % [GameState.phase_info(GameState.phase).get("name", "?"), "Ring the bell!" if day_manager.bell_ready() else "%d to go" % left]
	money_label.text = "Day %d  %s   $%d" % [GameState.day_number, where, GameState.money]


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
	if not InputSetup.is_device_used("keys_right"):
		options.append("Enter (arrow keys)")
	options.append("A (gamepad)")
	join_label.visible = InputSetup.active_players().size() < InputSetup.MAX_PLAYERS
	join_label.text = "More players: press %s to join" % " or ".join(options)


# The first MAX_ORDERS_SHOWN orders, then "+2 more".
func _refresh_orders() -> void:
	var lines := PackedStringArray(["Orders"])
	if order_board.orders.is_empty():
		lines.append("  (none)")
	for order in order_board.orders.slice(0, MAX_ORDERS_SHOWN):
		var state: String = STATE_NAMES[order.state] if order.on_wheel or order.state != Order.State.WAITING else "ticket not on the wheel"
		lines.append("  #%d %s for %s - %s" % [order.number, order.dish.get("name", "?"), order.for_name(), state])
	if order_board.orders.size() > MAX_ORDERS_SHOWN:
		lines.append("  +%d more" % (order_board.orders.size() - MAX_ORDERS_SHOWN))
	orders_label.text = "\n".join(lines)


# Smaller text in split screen, like the views' (see UiScale).
func _refresh_scale() -> void:
	var scale := _view_manager.ui_scale if _view_manager != null else 1.0
	if scale != _ui_scale:
		_ui_scale = scale
		UiScale.apply(self, scale)


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
