# HUD: on-screen info. Lists current orders and shows short messages from
# GameEvents. Display only.
extends CanvasLayer

const MESSAGE_TIME := 3.0
const STATE_NAMES := {
	Order.State.WAITING: "waiting",
	Order.State.COOKING: "cooking",
	Order.State.READY: "ready to serve",
}

@export var order_board: OrderBoard

@onready var orders_label: Label = $OrdersLabel
@onready var message_label: Label = $MessageLabel

var _message_timer := 0.0


func _ready() -> void:
	order_board.changed.connect(_refresh_orders)
	GameEvents.message.connect(_show_message)
	_refresh_orders()
	message_label.text = ""


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			message_label.text = ""


func _refresh_orders() -> void:
	var lines := PackedStringArray(["Orders"])
	if order_board.orders.is_empty():
		lines.append("  (none)")
	for order in order_board.orders:
		lines.append("  %s for %s - %s" % [
			order.dish.get("name", "?"), order.customer.species.get("name", "?"), STATE_NAMES[order.state]])
	orders_label.text = "\n".join(lines)


func _show_message(text: String) -> void:
	message_label.text = text
	_message_timer = MESSAGE_TIME
