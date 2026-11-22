# MooberOrders: delivery orders from town come in on the chefs' own phones (a
# MyFone, a cute take on a smartphone),
# through the Moober Treats app, instead of ringing the wall phone. An order
# pings and a badge in the corner says how many are waiting; any chef presses
# their phone button (InputSetup "phone": Tab, ], or View on a gamepad) to pull
# their phone out and see who ordered what, then presses interact to accept:
# it's written on a ticket (TicketPopup) and a courier comes for it (see
# DeliveryManager), the same as a phoned-in order was.
# Orders never expire (nobody is punished for being busy), but they do have to
# be done: the bell for the next meal or closing waits until every app order
# is accepted and delivered (DayManager.bell_ready), and the night shift ends
# only once they're all done. At most max_app_orders wait at once (data/phone.json);
# Phone decides when one comes in, the same timing calls used to have.
# Regulars' own calls (a Withdrawn regular ordering, a friend calling to chat)
# still ring the wall phone: they're personal.
# Handing an app order's bag to its courier finishes it: the chef's phone comes
# out again with the app's "Order picked up!" (a big tick popping in, confetti,
# a chime and the pay counting up), then goes away by itself (picked_up).
class_name MooberOrders
extends Node

const GROUP := "moober_orders"
const GREEN := Color(0.36, 0.74, 0.38)
const PICKED_UP_SECONDS := 2.6            # How long "Order picked up!" stays (interact puts it away sooner).

const ORANGE := Color(0.94, 0.45, 0.16)
const SCREEN := Color(0.99, 0.97, 0.92)
const CASE := Color(0.12, 0.1, 0.1)
const RIM := Color(0.98, 0.72, 0.6)       # The MyFone's pastel peach rim.
const INK := Color(0.22, 0.16, 0.12)
const WIDTH := 300.0
const PHONE_CAMERA_DISTANCE := 2.3        # The camera close in front of the chef on their phone...
const PHONE_CAMERA_PITCH := 14.0          # ...and only a little above.

var delivery_manager: DeliveryManager
var view_manager: ViewManager
var _viewing := {}                  # player_index -> true while their phone is out.
var _badge := PanelContainer.new()
var _badge_label := Label.new()
var _ping := AudioStreamPlayer.new()
var _chime := AudioStreamPlayer.new()
var _tick := AudioStreamPlayer.new()
var _busy := {}                     # player_index -> true while "Order picked up!" is showing.
var _time := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_ping.stream = _ping_stream()
	_ping.volume_db = -4.0
	add_child(_ping)
	_chime.stream = _chime_stream()
	_chime.volume_db = -3.0
	add_child(_chime)
	_tick.stream = _tick_stream()
	_tick.volume_db = -12.0
	add_child(_tick)
	_build_badge()


static func app_name() -> String:
	return String(GameData.phone_settings.get("app_name", "Moober Treats"))


func has_orders() -> bool:
	return not GameState.app_orders.is_empty() or not _viewing.is_empty()


func is_full() -> bool:
	return GameState.app_orders.size() >= int(GameData.phone_settings.get("max_app_orders", 3))


# A new order from `call` ({ kind: "townsfolk", id }): ping, and it waits.
func add_order(call: Dictionary) -> void:
	GameState.app_orders.append(call)
	PhoneCalls.start_ringing(call)  # They've ordered this meal.
	SaveGame.save_game()
	_ping.play()
	var who: String = PhoneCalls.caller_info(call)["name"]
	GameEvents.announce("%s: new order from %s! Press %s to view it." % [app_name(), who, _phone_buttons()])


func _process(delta: float) -> void:
	_time += delta
	_show_badge()
	if not GameState.phone_unlocked:
		return
	for player_index in InputSetup.active_players():
		if _viewing.has(player_index) or _busy.has(player_index):
			continue
		if not Input.is_action_just_pressed(InputSetup.action_name(player_index, "phone")):
			continue
		var player := Player.find(get_tree(), player_index)
		if player == null or player.movement_locked or player.in_conversation():
			continue  # Mid close-up or chat: the phone can wait.
		if GameState.app_orders.is_empty():
			GameEvents.announce("No %s orders right now." % app_name())
		elif TicketWheel.is_full(get_tree()):
			GameEvents.announce("The ticket wheel is full! Finish an order first.")
		else:
			_view(player)


# The phone comes up with the oldest order: who, what they said, the dish.
# Interact accepts it: onto a ticket, and a courier's sent for it.
func _view(player: Player) -> void:
	var index := player.player_index
	_viewing[index] = true
	var call: Dictionary = GameState.app_orders.pop_front()
	var built := PhoneCalls.build(call, Accounts.id_of(index))
	player.on_phone = true
	player.movement_locked = true
	_phone_out(player, true)
	var phone := _build_phone(_fill_order.bind(built, InputSetup.interact_hint(index)))
	await _raise(player, phone)
	await _press_or_wait(index, INF)
	await _lower(phone)
	_phone_out(player, false)
	player.on_phone = false
	player.ignore_interact_until_released()
	if not built["dish"].is_empty():
		var order := delivery_manager.add_delivery(built["dish"], PhoneCalls.caller_info(call))
		GameEvents.announce("%s ordered %s for delivery." % [built["name"], built["dish"].get("name", "something")])
		await TicketPopup.write(view_manager, player, order)
	player.movement_locked = false
	_viewing.erase(index)
	SaveGame.save_game()


# The bag's gone off with its courier (DeliveryManager): out comes the phone
# with "Order picked up!", a tick popping in, confetti, a chime and the pay
# counting up, and after a moment (or a press) it's put away. Any chef can be
# mid-something else: then it's just the message.
func picked_up(player: Player, who: String, dish_name: String, amount: int) -> void:
	var index := player.player_index
	if _viewing.has(index) or _busy.has(index) or player.movement_locked or player.in_conversation():
		return
	_busy[index] = true
	player.on_phone = true
	player.movement_locked = true
	_phone_out(player, true)
	var parts := {}
	var phone := _build_phone(_fill_picked_up.bind(who, dish_name, parts))
	await _raise(player, phone)
	_celebrate(parts, amount)
	await _press_or_wait(index, PICKED_UP_SECONDS)
	await _lower(phone)
	_phone_out(player, false)
	player.on_phone = false
	player.ignore_interact_until_released()
	player.movement_locked = false
	_busy.erase(index)


# "Order picked up!": a green tick (popped in by _celebrate), the dish on its
# way, the app's own message, and the pay. Fills `parts` with what animates.
func _fill_picked_up(column: VBoxContainer, who: String, dish_name: String, parts: Dictionary) -> void:
	var tick_holder := CenterContainer.new()
	tick_holder.custom_minimum_size.y = 96.0
	column.add_child(tick_holder)
	var tick := PanelContainer.new()
	var tick_style := StyleBoxFlat.new()
	tick_style.bg_color = GREEN
	tick_style.set_corner_radius_all(44)
	tick.add_theme_stylebox_override("panel", tick_style)
	tick.custom_minimum_size = Vector2(88.0, 88.0)
	tick_holder.add_child(tick)
	var mark := _label("✓", 56, Color.WHITE)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tick.add_child(mark)
	tick.scale = Vector2.ZERO
	parts["tick"] = tick
	var title := _label("Order picked up!", 26, GREEN.darkened(0.25))
	UiStyle.title(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var what := _label("%s's %s is on its way." % [who, dish_name], 16, INK)
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(what)
	var bubble := PanelContainer.new()
	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = ORANGE.lightened(0.75)
	bubble_style.set_corner_radius_all(14)
	bubble_style.corner_radius_top_left = 4
	bubble_style.set_content_margin_all(10)
	bubble.add_theme_stylebox_override("panel", bubble_style)
	var message := _label("%s: Your courier has the order. Delivery complete. Thanks for cooking with us!" % app_name(), 15, INK)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_child(message)
	column.add_child(bubble)
	var pay := _label("+$0", 34, GREEN.darkened(0.2))
	UiStyle.title(pay)
	pay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(pay)
	parts["pay"] = pay
	parts["column"] = column


# The tick pops in with a chime, confetti bursts from it, and the pay counts up
# with little ticks.
func _celebrate(parts: Dictionary, amount: int) -> void:
	var tick: Control = parts["tick"]
	tick.pivot_offset = tick.custom_minimum_size * 0.5
	var pop := tick.create_tween()
	pop.tween_property(tick, "scale", Vector2.ONE * 1.25, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(tick, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE)
	_chime.play()
	_confetti(tick)
	var pay: Label = parts["pay"]
	var count := pay.create_tween()
	count.tween_interval(0.25)
	count.tween_method(_show_pay.bind(pay), 0.0, float(amount), clampf(0.04 * amount, 0.4, 0.9)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	count.tween_callback(_bump_pay.bind(pay))


func _show_pay(value: float, pay: Label) -> void:
	var text := "+$%d" % roundi(value)
	if text != pay.text:
		pay.text = text
		if not _tick.playing:
			_tick.play()


func _bump_pay(pay: Label) -> void:
	pay.pivot_offset = pay.size * 0.5
	var bump := pay.create_tween()
	bump.tween_property(pay, "scale", Vector2.ONE * 1.2, 0.1)
	bump.tween_property(pay, "scale", Vector2.ONE, 0.15)


# Little bits of colored paper bursting out round the tick, falling and fading.
func _confetti(from: Control) -> void:
	var colors := [ORANGE, GREEN, RIM, Color(1.0, 0.82, 0.3), Color(0.55, 0.75, 0.95)]
	var center := from.global_position + from.size * 0.5
	for i in 22:
		var bit := ColorRect.new()
		bit.color = colors[i % colors.size()]
		bit.size = Vector2(randf_range(6.0, 10.0), randf_range(9.0, 14.0))
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bit.top_level = true
		from.add_child(bit)
		bit.global_position = center
		bit.pivot_offset = bit.size * 0.5
		var angle := randf_range(-PI, 0.0) if i % 3 != 0 else randf_range(0.0, PI)
		var reach := randf_range(70.0, 150.0)
		var out := center + Vector2(cos(angle), sin(angle)) * reach
		var fly := bit.create_tween().set_parallel()
		fly.tween_property(bit, "global_position", out, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.tween_property(bit, "rotation", randf_range(-6.0, 6.0), 1.1)
		fly.chain().tween_property(bit, "global_position:y", out.y + randf_range(60.0, 120.0), 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.parallel().tween_property(bit, "modulate:a", 0.0, 0.75)
		fly.chain().tween_callback(bit.queue_free)


# The phone slides up into `player`'s view (springing a little at the top).
func _raise(player: Player, phone: Control) -> void:
	ConversationBox.parent_for(view_manager, player.player_index, player).add_child(phone)
	phone.set_meta("shown_y", phone.position.y)
	phone.position.y += 700.0
	var rise := phone.create_tween()
	rise.tween_property(phone, "position:y", float(phone.get_meta("shown_y")), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await rise.finished


func _lower(phone: Control) -> void:
	var drop := phone.create_tween()
	drop.tween_property(phone, "position:y", float(phone.get_meta("shown_y")) + 700.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await drop.finished
	phone.queue_free()


# Until a fresh interact press (one already down doesn't count), or `seconds`.
func _press_or_wait(player_index: int, seconds: float) -> void:
	var interact := InputSetup.action_name(player_index, "interact")
	var was_down := true
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
		var down := Input.is_action_pressed(interact)
		if down and not was_down:
			return
		was_down = down


# The chef gets their phone out (or puts it away): they turn to face the
# camera's side of the room, hold a little MyFone up in both hands, and their
# camera swings down in front of them, low and close, with them on the left so
# the phone's screen fits on the right. Putting it away undoes all that.
func _phone_out(player: Player, out: bool) -> void:
	var chef := player.visual.get_node_or_null("Chef") as ChefModel
	if chef != null:
		chef.show_phone(out)
		chef.carrying = out or player.held_item != null  # Both hands up to hold it.
	if not out:
		player.release_camera_focus()
		return
	var yaw := deg_to_rad(CameraRig.VIEW_YAW)  # Facing the side the room's seen from: never a wall in the way.
	var turn := player.create_tween()
	turn.tween_property(player.visual, "rotation:y", player.visual.rotation.y + wrapf(yaw - player.visual.rotation.y, -PI, PI), 0.25)
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))  # The camera's right, looking at them from that side.
	var zoom := CameraZoomSettings.new()
	zoom.distance = PHONE_CAMERA_DISTANCE
	zoom.pitch_degrees = PHONE_CAMERA_PITCH
	zoom.yaw_degrees = CameraRig.VIEW_YAW
	zoom.duration = 0.45
	player.request_camera_focus(player.global_position + Vector3(0.0, 0.8, 0.0) + right * 0.42, zoom)


# The phone in hand: a dark case round a cream screen with the app's orange
# header; `fill` puts what's on the screen into its column.
func _build_phone(fill: Callable) -> Control:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var case := PanelContainer.new()  # The MyFone: thin dark bezel, pastel rim, very round corners.
	var case_style := StyleBoxFlat.new()
	case_style.bg_color = CASE
	case_style.set_corner_radius_all(52)
	case_style.set_border_width_all(5)
	case_style.border_color = RIM
	case_style.set_content_margin_all(11)
	case.add_theme_stylebox_override("panel", case_style)
	case.custom_minimum_size.x = WIDTH
	holder.add_child(case)
	case.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)  # Off to the side, clear of the clock and messages.
	case.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	case.grow_vertical = Control.GROW_DIRECTION_BOTH
	case.offset_right = -48.0
	case.offset_left = -48.0
	var glass := PanelContainer.new()  # The screen, round-cornered inside the bezel.
	var glass_style := StyleBoxFlat.new()
	glass_style.bg_color = SCREEN
	glass_style.set_corner_radius_all(42)
	glass_style.content_margin_top = 10
	glass_style.content_margin_bottom = 10
	glass.add_theme_stylebox_override("panel", glass_style)
	glass.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	case.add_child(glass)
	var screen := VBoxContainer.new()
	screen.add_theme_constant_override("separation", 6)
	glass.add_child(screen)
	screen.add_child(_status_bar())
	var header := PanelContainer.new()
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = ORANGE
	header_style.set_content_margin_all(12)
	header.add_theme_stylebox_override("panel", header_style)
	screen.add_child(header)
	var title := _label(app_name(), 22, Color.WHITE)
	UiStyle.title(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	var body := PanelContainer.new()
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = SCREEN
	body_style.set_content_margin_all(18)
	body_style.content_margin_top = 8
	body.add_theme_stylebox_override("panel", body_style)
	screen.add_child(body)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	body.add_child(column)
	fill.call(column)
	var home := Panel.new()  # The home bar along the bottom.
	var home_style := StyleBoxFlat.new()
	home_style.bg_color = INK
	home_style.set_corner_radius_all(3)
	home.add_theme_stylebox_override("panel", home_style)
	home.custom_minimum_size = Vector2(110.0, 6.0)
	home.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	screen.add_child(home)
	return holder


# An order on the screen: who ordered what, the order number, their note, and
# how to accept.
func _fill_order(column: VBoxContainer, built: Dictionary, button: String) -> void:
	var who := _label("%s ordered" % built["name"], 22, INK)
	UiStyle.title(who)
	column.add_child(who)
	var dish := _label(String(built["dish"].get("name", "something")), 24, ORANGE.darkened(0.2))
	dish.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.title(dish)
	column.add_child(dish)
	column.add_child(_label("Order #%06d" % randi_range(1, 999999), 15, INK.lightened(0.4)))
	if not built["lines"].is_empty():
		var said := _label("They sent a message with their order:", 15, INK.lightened(0.3))
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(said)
	for line in built["lines"]:
		var bubble := PanelContainer.new()
		var bubble_style := StyleBoxFlat.new()
		bubble_style.bg_color = Color(0.93, 0.88, 0.8)
		bubble_style.set_corner_radius_all(14)
		bubble_style.corner_radius_top_left = 4  # A message bubble's tail corner.
		bubble_style.set_content_margin_all(10)
		bubble.add_theme_stylebox_override("panel", bubble_style)
		var text := _label(String(line), 16, INK)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bubble.add_child(text)
		column.add_child(bubble)
	var accept := _label("Press %s to accept" % button, 16, INK.lightened(0.2))
	accept.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(accept)


# The top of the MyFone's screen: the time (real, like the restaurant's), the
# little black pill in the middle, and a full battery.
func _status_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 30.0
	var now := Time.get_time_dict_from_system()
	var hour := int(now["hour"]) % 12
	var time := _label("%d:%02d" % [12 if hour == 0 else hour, now["minute"]], 16, INK)
	UiStyle.title(time)
	time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(time)
	var pill := Panel.new()
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color(0.05, 0.05, 0.05)
	pill_style.set_corner_radius_all(14)
	pill.add_theme_stylebox_override("panel", pill_style)
	pill.custom_minimum_size = Vector2(96.0, 28.0)
	bar.add_child(pill)
	var battery := HBoxContainer.new()
	battery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battery.alignment = BoxContainer.ALIGNMENT_CENTER
	battery.add_theme_constant_override("separation", 1)
	var cell := Panel.new()
	var cell_style := StyleBoxFlat.new()
	cell_style.bg_color = Color(0.45, 0.8, 0.4)
	cell_style.set_border_width_all(2)
	cell_style.border_color = INK
	cell_style.set_corner_radius_all(4)
	cell.add_theme_stylebox_override("panel", cell_style)
	cell.custom_minimum_size = Vector2(26.0, 13.0)
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	battery.add_child(cell)
	var nub := Panel.new()
	var nub_style := StyleBoxFlat.new()
	nub_style.bg_color = INK
	nub_style.set_corner_radius_all(1)
	nub.add_theme_stylebox_override("panel", nub_style)
	nub.custom_minimum_size = Vector2(3.0, 6.0)
	nub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	battery.add_child(nub)
	bar.add_child(battery)
	return bar


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


# The corner badge: "Moober Treats: 2 orders (Tab)", bobbing while any wait.
func _build_badge() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var style := StyleBoxFlat.new()
	style.bg_color = ORANGE
	style.set_corner_radius_all(16)
	style.set_content_margin_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	_badge.add_theme_stylebox_override("panel", style)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_badge)
	_badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_badge.offset_left = 18.0
	_badge.offset_top = 40.0
	_badge_label.add_theme_font_size_override("font_size", 22)
	_badge_label.add_theme_color_override("font_color", Color.WHITE)
	UiStyle.title(_badge_label)
	_badge.add_child(_badge_label)
	_badge.visible = false


func _show_badge() -> void:
	var waiting := GameState.app_orders.size()
	_badge.visible = GameState.phone_unlocked and waiting > 0
	if not _badge.visible:
		return
	_badge_label.text = "%s: %d order%s (%s)" % [app_name(), waiting, "" if waiting == 1 else "s", _phone_buttons()]
	_badge.scale = Vector2.ONE * (1.0 + 0.04 * maxf(sin(_time * 5.0), 0.0))


# The phone button for everyone playing, e.g. "Tab" or "Tab / View".
func _phone_buttons() -> String:
	var hints: Array[String] = []
	for player_index in InputSetup.active_players():
		var hint: String = InputSetup.phone_hint(player_index)
		if not hint in hints:
			hints.append(hint)
	return " / ".join(hints)


# A placeholder two-note ping (until there's a real sound).
# A bright rising three-note chime (C, E, G, then a high C ringing on): done!
func _chime_stream() -> AudioStream:
	var notes := [[0.0, 1046.5], [0.09, 1318.5], [0.18, 1568.0], [0.27, 2093.0]]
	return _wav(0.9, func(t: float) -> float:
		var value := 0.0
		for note in notes:
			if t >= note[0]:
				var since: float = t - note[0]
				var ring := 9.0 if note[0] < 0.27 else 4.0
				value += (sin(TAU * note[1] * t) + 0.3 * sin(TAU * note[1] * 2.0 * t)) * exp(-since * ring) * 0.16
		return value)


# A tiny coin tick, played as the pay counts up.
func _tick_stream() -> AudioStream:
	return _wav(0.05, func(t: float) -> float: return sin(TAU * 2400.0 * t) * exp(-t * 90.0) * 0.4)


func _wav(seconds: float, sample: Callable) -> AudioStream:
	var rate := 22050
	var total := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		data.encode_s16(i * 2, int(clampf(sample.call(float(i) / rate), -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


func _ping_stream() -> AudioStream:
	var rate := 22050
	var total := int(rate * 0.36)
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var t := float(i) / rate
		var pitch := 880.0 if t < 0.15 else 1320.0
		var since := t if t < 0.15 else t - 0.15
		var value := sin(TAU * pitch * t) * exp(-since * 14.0) * 0.3
		data.encode_s16(i * 2, int(value * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
