# TicketPopup: the order being written on a ticket, in the view of the player
# who took it. The ticket pops up, the order writes itself on, it holds a
# moment (press interact to hurry it), then it tucks into their pocket. The
# player stays put meanwhile. TicketPopup.write(...) does all of it and hands
# the order's ticket to the player at the end.
class_name TicketPopup
extends Control

signal done

const PAPER := Color(0.99, 0.97, 0.9)
const INK := Color(0.16, 0.2, 0.42)
const PENCIL := Color(0.45, 0.43, 0.4)
const WIDTH := 300.0
const TICKET_RAIL := "ticket_rail"  # The upgrade that clips tickets for you (data/upgrades.json).

@export var write_seconds := 0.6   # The dish's name writing itself on.
@export var hold_seconds := 0.9    # How long it stays up once written.

var _player: Player
var _order: Order
var _paper := PanelContainer.new()
var _dish := Label.new()
var _for := Label.new()
var _scratch := AudioStreamPlayer.new()
var _skippable := false
var _skipped := false


static func write(view_manager: ViewManager, player: Player, order: Order) -> void:
	var popup := TicketPopup.new()
	popup._player = player
	popup._order = order
	ConversationBox.parent_for(view_manager, player.player_index, player).add_child(popup)
	await popup.done


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.movement_locked = true
	_build()
	_scratch.stream = CookSounds.get_sound("drizzle")
	_scratch.volume_db = -20.0
	_scratch.pitch_scale = 2.2
	add_child(_scratch)
	_play()


func _process(_delta: float) -> void:
	var interact := InputSetup.action_name(_player.player_index, "interact")
	if not Input.is_action_pressed(interact):
		_skippable = true  # The press that took the order has been let go.
	elif _skippable and Input.is_action_just_pressed(interact):
		_skipped = true


func _play() -> void:
	await get_tree().process_frame  # Sized now: put it in the middle.
	var middle := (size - _paper.size) * Vector2(0.5, 0.42)
	_paper.pivot_offset = _paper.size * 0.5
	_paper.position = middle + Vector2(0.0, size.y * 0.5)
	_paper.scale = Vector2.ONE * 0.4
	_paper.rotation = -0.18
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_paper, "position", middle, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_paper, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_paper, "rotation", -0.04, 0.3)
	_play_sound("whoosh", -8.0)
	await tween.finished

	_scratch.play()
	var writing := create_tween()
	writing.tween_property(_dish, "visible_ratio", 1.0, write_seconds)
	writing.tween_property(_for, "visible_ratio", 1.0, write_seconds * 0.5)
	while writing.is_running() and not _skipped:
		await get_tree().process_frame
	writing.kill()
	_dish.visible_ratio = 1.0
	_for.visible_ratio = 1.0
	_scratch.stop()

	var left := hold_seconds
	while left > 0.0 and not _skipped:
		left -= get_process_delta_time()
		await get_tree().process_frame

	# Into the pocket: shrink away toward the bottom.
	var away := create_tween().set_parallel(true)
	away.tween_property(_paper, "position", Vector2(middle.x, size.y), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	away.tween_property(_paper, "scale", Vector2.ONE * 0.2, 0.3)
	away.tween_property(_paper, "rotation", 0.3, 0.3)
	_play_sound("whoosh", -12.0, 1.4)
	await away.finished
	_hand_over()
	_player.movement_locked = false
	_player.ignore_interact_until_released()  # A press to hurry it along shouldn't use the counter.
	done.emit()
	queue_free()


# Into their pocket, for the ticket wheel. With the Ticket Rail upgrade it goes
# straight up on the wheel instead: no trip to clip it.
func _hand_over() -> void:
	var wheel := get_tree().get_first_node_in_group(TicketWheel.GROUP) as TicketWheel
	if wheel != null and GameState.has_upgrade(TICKET_RAIL):
		wheel.clip_now(_order)
		GameEvents.announce("Ticket #%d went up on the rail: %s." % [_order.number, _order.dish.get("name", "")])
	else:
		_player.add_ticket(_order)


func _build() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	style.shadow_size = 10
	style.shadow_offset = Vector2(4.0, 6.0)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 22.0
	_paper.add_theme_stylebox_override("panel", style)
	_paper.custom_minimum_size.x = WIDTH
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper)

	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 6)
	_paper.add_child(lines)
	var header := HBoxContainer.new()
	lines.add_child(header)
	var number := _label("ORDER  #%d" % _order.number, 18, PENCIL)
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(number)
	header.add_child(_label(GameClock.describe_time(GameClock.now_local()), 18, PENCIL))
	var rule := ColorRect.new()
	rule.color = Color(0.55, 0.72, 0.9, 0.7)
	rule.custom_minimum_size.y = 2.0
	lines.add_child(rule)
	_dish = _label(_order.dish.get("name", "?"), 34, INK)
	_dish.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dish.visible_ratio = 0.0
	lines.add_child(_dish)
	_for = _label("for " + _order.for_name(), 22, INK)
	_for.visible_ratio = 0.0
	lines.add_child(_for)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _play_sound(sound: String, volume_db: float, pitch := 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = CookSounds.get_sound(sound)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	add_child(player)
	player.play()
