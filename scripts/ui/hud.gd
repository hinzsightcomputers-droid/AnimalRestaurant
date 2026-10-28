# HUD: on-screen info. Shows the day and money, lists current orders, and shows
# short messages from GameEvents. Display only.
extends CanvasLayer

const MESSAGE_TIME := 4.0
const MAX_MESSAGES := 3
const STATE_NAMES := {
	Order.State.WAITING: "waiting",
	Order.State.GATHERED: "ingredients out",
	Order.State.COOKING: "cooking",
	Order.State.READY: "ready to serve",
}

@export var order_board: OrderBoard
@export var day_manager: DayManager

@onready var orders_label: Label = $OrdersLabel
@onready var money_label: Label = $MoneyLabel
@onready var message_label: Label = $MessageLabel
@onready var join_label: Label = $JoinLabel

var _messages: Array[Dictionary] = []  # Recent messages, oldest first: { text, time_left }


func _ready() -> void:
	order_board.changed.connect(_refresh_orders)
	GameEvents.message.connect(_show_message)
	_refresh_orders()
	message_label.text = ""


func _process(delta: float) -> void:
	_refresh_day_and_money()
	_refresh_join_hint()
	if _messages.is_empty():
		return
	for message in _messages:
		message["time_left"] -= delta
	var count_before := _messages.size()
	_messages = _messages.filter(func(m): return m["time_left"] > 0.0)
	if _messages.size() != count_before:
		_refresh_messages()


# e.g. "Tue, Oct 27  8:42 PM   Shift 2  2:35 left   $18": the real date and time,
# then this shift and how long it stays open ("Closed" after closing time).
func _refresh_day_and_money() -> void:
	var shift_clock := "Closed"
	if day_manager.is_open:
		var seconds := ceili(day_manager.time_left)
		shift_clock = "%d:%02d left" % [floori(seconds / 60.0), seconds % 60]
	money_label.text = "%s  %s   Shift %d  %s   $%d" % [GameClock.describe_date(GameState.date, true),
		GameClock.describe_time(GameClock.now_local()), GameState.shift, shift_clock, GameState.money]


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


func _refresh_orders() -> void:
	var lines := PackedStringArray(["Orders"])
	if order_board.orders.is_empty():
		lines.append("  (none)")
	for order in order_board.orders:
		lines.append("  %s for %s - %s" % [
			order.dish.get("name", "?"), order.customer.species.get("name", "?"), STATE_NAMES[order.state]])
	orders_label.text = "\n".join(lines)


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
