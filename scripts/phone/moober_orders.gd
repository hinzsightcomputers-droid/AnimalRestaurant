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
class_name MooberOrders
extends Node

const ORANGE := Color(0.94, 0.45, 0.16)
const SCREEN := Color(0.99, 0.97, 0.92)
const CASE := Color(0.12, 0.1, 0.1)
const RIM := Color(0.98, 0.72, 0.6)       # The MyFone's pastel peach rim.
const INK := Color(0.22, 0.16, 0.12)
const WIDTH := 300.0

var delivery_manager: DeliveryManager
var view_manager: ViewManager
var _viewing := {}                  # player_index -> true while their phone is out.
var _badge := PanelContainer.new()
var _badge_label := Label.new()
var _ping := AudioStreamPlayer.new()
var _time := 0.0


func _ready() -> void:
	_ping.stream = _ping_stream()
	_ping.volume_db = -4.0
	add_child(_ping)
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
		if _viewing.has(player_index):
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
	var built := PhoneCalls.build(call, Accounts.id_of(index), true)
	player.on_phone = true
	player.movement_locked = true
	var phone := _build_phone(built, InputSetup.interact_hint(index))
	ConversationBox.parent_for(view_manager, index, player).add_child(phone)
	var shown := phone.position.y
	phone.position.y = shown + 700.0
	var rise := phone.create_tween()
	rise.tween_property(phone, "position:y", shown, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await rise.finished
	var interact := InputSetup.action_name(index, "interact")
	var was_down := true  # A press already down (e.g. the one before) doesn't count: wait for a new one.
	while true:
		await get_tree().process_frame
		var down := Input.is_action_pressed(interact)
		if down and not was_down:
			break
		was_down = down
	var drop := phone.create_tween()
	drop.tween_property(phone, "position:y", shown + 700.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await drop.finished
	phone.queue_free()
	player.on_phone = false
	player.ignore_interact_until_released()
	if not built["dish"].is_empty():
		var order := delivery_manager.add_delivery(built["dish"], PhoneCalls.caller_info(call))
		GameEvents.announce("%s ordered %s for delivery." % [built["name"], built["dish"].get("name", "something")])
		await TicketPopup.write(view_manager, player, order)
	player.movement_locked = false
	_viewing.erase(index)
	SaveGame.save_game()


# The phone in hand: a dark case round a cream screen with the app's orange
# header, then who ordered, their message, the dish and how to accept.
func _build_phone(built: Dictionary, button: String) -> Control:
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
	column.add_child(_label("New order from", 15, INK.lightened(0.35)))
	var who := _label(built["name"], 26, INK)
	UiStyle.title(who)
	column.add_child(who)
	for line in built["lines"]:
		var bubble := PanelContainer.new()
		var bubble_style := StyleBoxFlat.new()
		bubble_style.bg_color = Color(0.93, 0.88, 0.8)
		bubble_style.set_corner_radius_all(14)
		bubble_style.set_content_margin_all(10)
		bubble.add_theme_stylebox_override("panel", bubble_style)
		var text := _label(String(line), 16, INK)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bubble.add_child(text)
		column.add_child(bubble)
	if not built["dish"].is_empty():
		var dish := _label("Order: %s" % built["dish"].get("name", "something"), 19, ORANGE.darkened(0.25))
		UiStyle.title(dish)
		column.add_child(dish)
	var accept := _label("Press %s to accept" % button, 16, INK.lightened(0.2))
	accept.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(accept)
	var home := Panel.new()  # The home bar along the bottom.
	var home_style := StyleBoxFlat.new()
	home_style.bg_color = INK
	home_style.set_corner_radius_all(3)
	home.add_theme_stylebox_override("panel", home_style)
	home.custom_minimum_size = Vector2(110.0, 6.0)
	home.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	screen.add_child(home)
	return holder


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
