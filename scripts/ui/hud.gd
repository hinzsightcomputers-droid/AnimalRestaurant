# HUD: on-screen info. Shows the day and money, lists current orders, and shows
# short messages from GameEvents. Display only.
extends CanvasLayer

const MESSAGE_TIME := 4.0
const MAX_MESSAGES := 3
const STATE_NAMES := {
	Order.State.WAITING: "waiting",
	Order.State.COOKING: "cooking",
	Order.State.READY: "ready to serve",
}

@export var order_board: OrderBoard

@onready var orders_label: Label = $OrdersLabel
@onready var money_label: Label = $MoneyLabel
@onready var message_label: Label = $MessageLabel

var _messages: Array[Dictionary] = []  # Recent messages, oldest first: { text, time_left }


func _ready() -> void:
	order_board.changed.connect(_refresh_orders)
	GameEvents.message.connect(_show_message)
	GameState.money_changed.connect(_refresh_money.unbind(1))
	_refresh_orders()
	_refresh_money()
	message_label.text = ""


func _refresh_money() -> void:
	money_label.text = "Day %d   $%d" % [GameState.day, GameState.money]


func _process(delta: float) -> void:
	if _messages.is_empty():
		return
	for message in _messages:
		message["time_left"] -= delta
	var count_before := _messages.size()
	_messages = _messages.filter(func(m): return m["time_left"] > 0.0)
	if _messages.size() != count_before:
		_refresh_messages()


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
