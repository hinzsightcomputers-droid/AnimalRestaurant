# SummaryScreen: the end-of-day results panel. Hidden until the DayManager
# reports the day has ended, then shows the totals, what each chef did, and
# how long until the restaurant opens again (5 AM); its button heads out into
# After Hours. After hours the host stand opens it again (the same summary,
# kept by DayCycle), and then its button closes it, or opens up for the new
# day once 5 AM has been. The Friends button flips to a page of which chefs
# each regular knows, the Shop button to the upgrades you can buy, Rating to
# how close the next star is (see Rating), and
# Collections opens the Fish and Forage Logs (CollectionsScreen) on top.
# Runs while the game is paused.
extends CanvasLayer

enum Page { SUMMARY, FRIENDS, SHOP, RATING }

const INPUT_DELAY := 1.0  # Ignore input briefly so a held E doesn't skip the screen.
# The panel keeps this far inside the window: on a small window (or a long day)
# the text shrinks, down to BODY_FONT_MIN, and the shop list gets shorter.
const SCREEN_MARGIN := 24.0
const BODY_FONT_MIN := 12
const PANEL_SIZE := Vector2(720, 460)  # At least this big.
# Chef actions in the order they're listed, with how to say each count.
const ACTION_WORDS := [
	["chopped", "chopped"],
	["cooked", "cooked"],
	["served", "served"],
	["cleared", "tables cleared"],
	["cleaned", "tables wiped"],
	["washed", "dishes washed"],
]

@export var day_manager: DayManager

@onready var title_label: Label = $Panel/Content/Title
@onready var panel: PanelContainer = $Panel
@onready var body_label: Label = $Panel/Content/Body
@onready var upgrade_scroll: ScrollContainer = $Panel/Content/UpgradeScroll
@onready var upgrade_list: VBoxContainer = $Panel/Content/UpgradeScroll/UpgradeList
@onready var friends_button: Button = $Panel/Content/Buttons/FriendsButton
@onready var shop_button: Button = $Panel/Content/Buttons/ShopButton
@onready var next_button: Button = $Panel/Content/Buttons/NextDayButton

var _input_delay_left := 0.0
var _summary: Dictionary = {}
var _page := Page.SUMMARY
var _from_host_stand := false  # Reopened after hours, rather than the day just ending.
var _collections_button: Button
var _rating_button: Button


func _ready() -> void:
	visible = false
	day_manager.day_ended.connect(_show_summary)
	day_manager.summary_requested.connect(func(): _show_summary(DayCycle.summary, true))
	next_button.pressed.connect(_on_next_pressed)
	get_viewport().size_changed.connect(func(): if visible: _fit_to_screen())
	friends_button.pressed.connect(_toggle_page.bind(Page.FRIENDS))
	shop_button.pressed.connect(_toggle_page.bind(Page.SHOP))
	_collections_button = friends_button.duplicate(0) as Button  # Its look, not its signals.
	_collections_button.name = "CollectionsButton"
	_collections_button.text = "Collections"
	friends_button.add_sibling(_collections_button)
	_collections_button.pressed.connect(_open_collections)
	_rating_button = friends_button.duplicate(0) as Button
	_rating_button.name = "RatingButton"
	friends_button.add_sibling(_rating_button)
	_rating_button.pressed.connect(_toggle_page.bind(Page.RATING))


func _process(delta: float) -> void:
	if not visible:
		return
	_input_delay_left = maxf(_input_delay_left - delta, 0.0)
	next_button.disabled = _input_delay_left > 0.0
	next_button.text = _next_button_text()


# Any player's interact button presses the focused button (Start Day at first;
# the button itself handles Enter / click / gamepad accept).
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	for player_index in InputSetup.MAX_PLAYERS:
		if event.is_action_pressed(InputSetup.action_name(player_index, "interact")):
			get_viewport().set_input_as_handled()
			var focused := get_viewport().gui_get_focus_owner() as Button
			if focused != null and focused != next_button and not focused.disabled:
				focused.pressed.emit()
			else:
				_on_next_pressed()
			return


func _show_summary(summary: Dictionary, from_host_stand := false) -> void:
	_summary = summary
	_from_host_stand = from_host_stand
	_page = Page.SUMMARY
	_refresh_page()
	next_button.disabled = true
	_input_delay_left = INPUT_DELAY
	visible = true
	next_button.grab_focus()


func _summary_text(summary: Dictionary) -> String:
	var served: int = summary["customers_served"]
	var lines := PackedStringArray()
	lines.append("Customers served: %d" % served)
	lines.append("Earned today: $%d  (tips $%d)" % [summary["earnings"], summary["tips"]])

	if served > 0:
		var quality: float = summary["average_quality"]
		lines.append("Average cooking: %s (%d%%)" % [CookingMinigame.quality_label(quality), roundi(quality * 100)])
		lines.append("Average wait: %ds" % roundi(summary["average_wait"]))
		if int(summary.get("best_streak", 0)) >= 2:
			lines.append("Best streak: x%d" % summary["best_streak"])
		lines.append("Reactions: %s" % _reaction_text(summary["reaction_counts"]))
		lines.append("Most ordered: %s" % GameData.get_dish(summary["top_dish"]).get("name", "?"))
	else:
		lines.append("A quiet day. Tomorrow will be busier!")

	lines.append("")
	lines.append_array(_chef_lines(summary))
	lines.append("")
	lines.append("Total money: $%d" % GameState.money)
	if summary.has("stars"):
		lines.append("Rating: %d of %d stars%s" % [summary["stars"], Rating.MAX_STARS, "  (new today!)" if summary.get("new_star", false) else ""])
	if int(summary.get("day_number", 0)) == int(GameData.difficulty.get("hard_unlock_day", 7)):
		lines.append("")
		lines.append(String(GameData.difficulty.get("hard_unlocked_news", "Hard mode unlocked!")))
	return "\n".join(lines)


func _open_collections() -> void:
	var screen := CollectionsScreen.open(get_tree())
	if not screen.closed.is_connected(_collections_button.grab_focus):
		screen.closed.connect(_collections_button.grab_focus)


# Friends and Shop open their page, or go back to the summary if already open.
func _toggle_page(page: Page) -> void:
	_page = Page.SUMMARY if _page == page else page
	_refresh_page()


func _refresh_page() -> void:
	upgrade_scroll.visible = _page == Page.SHOP
	body_label.size_flags_vertical = Control.SIZE_FILL if _page == Page.SHOP else Control.SIZE_EXPAND_FILL
	friends_button.text = "Back to summary" if _page == Page.FRIENDS else "Friends"
	shop_button.text = "Back to summary" if _page == Page.SHOP else _shop_button_text()
	_rating_button.text = "Back to summary" if _page == Page.RATING else "Rating"
	match _page:
		Page.FRIENDS:
			title_label.text = "Friends"
			body_label.text = _friends_text()
		Page.RATING:
			title_label.text = "Rating"
			body_label.text = Rating.page_text()
		Page.SHOP:
			title_label.text = "Shop"
			body_label.text = "You have $%d. Treat the restaurant to something nice!" % GameState.money
			_build_upgrade_list()
		_:
			if _summary.is_empty():  # A day that ended before summaries were kept.
				title_label.text = "After hours"
				body_label.text = "Today's summary wasn't kept, sorry!

%s

Total money: $%d" % [_opens_text(), GameState.money]
			else:
				title_label.text = "%s - day %d done!" % [GameClock.describe_date(_summary["date"]), _summary["day_number"]]
				body_label.text = _summary_text(_summary) + "

" + _opens_text()
			if not next_button.disabled:
				next_button.grab_focus()  # Back on the summary, interact starts the day again.
	_fit_to_screen()


# Smaller body text, then a shorter shop list, until the panel fits the window.
func _fit_to_screen() -> void:
	if not body_label.has_meta(&"base_font_size"):
		body_label.set_meta(&"base_font_size", body_label.get_theme_font_size("font_size"))
		upgrade_scroll.set_meta(&"base_height", upgrade_scroll.custom_minimum_size.y)
	var room := get_viewport().get_visible_rect().size - Vector2.ONE * SCREEN_MARGIN * 2.0
	var font_size: int = body_label.get_meta(&"base_font_size")
	upgrade_scroll.custom_minimum_size.y = upgrade_scroll.get_meta(&"base_height")
	body_label.add_theme_font_size_override("font_size", font_size)
	while font_size > BODY_FONT_MIN and _too_big(room):
		font_size -= 1
		body_label.add_theme_font_size_override("font_size", font_size)
	var over := panel.get_combined_minimum_size().y - room.y
	if over > 0.0 and upgrade_scroll.visible:
		upgrade_scroll.custom_minimum_size.y = maxf(80.0, upgrade_scroll.custom_minimum_size.y - over)
	var needed := panel.get_combined_minimum_size()
	var least := PANEL_SIZE.min(room)
	panel.size = Vector2(maxf(least.x, needed.x), maxf(least.y, needed.y))  # Back down when the text got shorter.
	panel.position = (get_viewport().get_visible_rect().size - panel.size) / 2.0


func _too_big(room: Vector2) -> bool:
	var needed := panel.get_combined_minimum_size()
	return needed.x > room.x or needed.y > room.y


# "Shop (2 new!)" when there are upgrades, dishes or drinks in stock you can afford right now.
func _shop_button_text() -> String:
	var affordable := 0
	for upgrade in GameData.upgrades:
		if not GameState.has_upgrade(upgrade["id"]) and GameData.in_stock(upgrade["id"]) and GameState.money >= upgrade["price"]:
			affordable += 1
	for item in GameData.shop_dishes() + GameData.shop_drinks():
		if not GameData.is_unlocked(item["id"]) and GameData.in_stock(item["id"]) and GameState.money >= int(item["unlock_cost"]):
			affordable += 1
	return "Shop (%d new!)" % affordable if affordable > 0 else "Shop"


# One button per upgrade, then per dish and per drink to add to the menu:
# buyable, too pricey, or already owned. Only what's arrived in the shop
# (GameData.in_stock) or was bought already, with what's coming tomorrow named at the bottom.
func _build_upgrade_list() -> void:
	for child in upgrade_list.get_children():
		upgrade_list.remove_child(child)
		child.queue_free()
	var buttons: Array[Button] = []
	if _from_host_stand and DayCycle.is_after_hours():
		var decorate := _shop_button("Decorate", "Place what's in storage, or move things around.", 0, false, "")
		decorate.text = "Decorate\nPlace what's in storage, or move things around."
		decorate.disabled = false
		decorate.pressed.connect(_decorate)
		buttons.append(decorate)
	for upgrade in GameData.upgrades.filter(func(u): return GameData.in_stock(u["id"]) or GameState.has_upgrade(u["id"])):
		var button := _shop_button(upgrade["name"], upgrade["description"], int(upgrade["price"]), GameState.has_upgrade(upgrade["id"]), "Owned")
		button.pressed.connect(_buy.bind(upgrade["id"]))
		buttons.append(button)
	_shop_heading("New dishes")
	for dish in GameData.shop_dishes().filter(func(d): return GameData.in_stock(d["id"]) or GameData.is_unlocked(d["id"])):
		var button := _shop_button(dish["name"], dish["description"], int(dish["unlock_cost"]), GameData.is_unlocked(dish["id"]), "On the menu")
		button.pressed.connect(_buy_dish.bind(dish["id"]))
		buttons.append(button)
	_shop_heading("New drinks")
	for drink in GameData.shop_drinks().filter(func(d): return GameData.in_stock(d["id"]) or GameData.is_unlocked(d["id"])):
		var button := _shop_button(drink["name"], drink["description"], int(drink["unlock_cost"]), GameData.is_unlocked(drink["id"]), "On the menu")
		button.pressed.connect(_buy_drink.bind(drink["id"]))
		buttons.append(button)
	_shop_heading("Decor today (it goes in storage until you place it)")
	for item in Decor.stock():
		var stored := int(GameState.decor_stored.get(item["id"], 0))
		var button := _shop_button(item["name"], "%s  (%s, %d in storage)" % [item["description"], item["category"], stored], int(item["price"]), false, "")
		button.pressed.connect(_buy_decor.bind(item["id"]))
		buttons.append(button)
	_coming_tomorrow()
	var buyable := buttons.filter(func(b): return not b.disabled)
	(buyable[0] if not buyable.is_empty() else shop_button).grab_focus()


# "Arriving tomorrow: Croissant, Apple Cider" under the list, if anything is.
func _coming_tomorrow() -> void:
	var names: Array[String] = []
	for item in GameData.upgrades + GameData.shop_dishes() + GameData.shop_drinks():
		if GameData.arrival_day(item["id"]) == GameState.day_number + 1:
			names.append(item["name"])
	if not names.is_empty():
		_shop_heading("Arriving tomorrow: " + ", ".join(names))


func _shop_heading(text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", body_label.get_theme_color("font_color"))
	upgrade_list.add_child(heading)


# A shop entry, e.g. "Cherry Pie  -  Buy for $60" over its description, added
# to the list. Disabled when owned or too pricey.
func _shop_button(item_name: String, description: String, price: int, owned: bool, owned_text: String) -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 60)
	button.add_theme_font_size_override("font_size", 18)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var status: String
	if owned:
		status = owned_text
		button.disabled = true
	elif GameState.money < price:
		status = "$%d (need $%d more)" % [price, price - GameState.money]
		button.disabled = true
	else:
		status = "Buy for $%d" % price
	button.text = "%s  -  %s\n%s" % [item_name, status, description]
	upgrade_list.add_child(button)
	return button


func _buy(upgrade_id: String) -> void:
	if GameState.buy_upgrade(upgrade_id):
		_refresh_page()


func _buy_decor(item_id: String) -> void:
	if GameState.buy_decor(item_id):
		_refresh_page()


func _decorate() -> void:
	visible = false
	day_manager.start_decorating()


func _buy_dish(dish_id: String) -> void:
	if GameState.buy_dish(dish_id):
		_refresh_page()


func _buy_drink(drink_id: String) -> void:
	if GameState.buy_drink(drink_id):
		_refresh_page()


# One line per chef playing (and anyone who did something today), e.g.
# "Alex: 2 chopped, 3 cooked, 4 served  (1h 05m played)", plus who served most.
func _chef_lines(summary: Dictionary) -> PackedStringArray:
	var chefs: Dictionary = summary.get("chefs", {})
	var ids: Array[String] = Accounts.ids_in_play()
	for account_id in chefs:
		if not account_id in ids:
			ids.append(account_id)
	var lines := PackedStringArray()
	if ids.is_empty():
		return lines
	lines.append("Chefs:")
	for account_id in ids:
		var account := Accounts.get_account(account_id)
		var actions: Dictionary = chefs.get(account_id, {})
		var parts := PackedStringArray()
		for entry in ACTION_WORDS:
			if actions.get(entry[0], 0) > 0:
				parts.append("%d %s" % [actions[entry[0]], entry[1]])
		var did := ", ".join(parts) if not parts.is_empty() else "took it easy"
		lines.append("  %s: %s  (%s played)" % [
			account.get("name", "?"), did, Accounts.format_playtime(account.get("playtime_seconds", 0.0))])
	var top: String = summary.get("top_server", "")
	if not top.is_empty() and ids.size() > 1:
		lines.append("Star server: %s!" % Accounts.get_account(top).get("name", "?"))
	return lines


# For each regular: how close they are to the restaurant, and which chefs they
# know by name (and how often each has served them). Regulars nobody has met yet
# stay a mystery.
func _friends_text() -> String:
	var lines := PackedStringArray()
	for regular_id in GameState.regulars:
		var record: Dictionary = GameState.regulars[regular_id]
		var species_name: String = GameData.get_species(record["species"]).get("name", "?")
		if record["times_visited"] == 0:
			lines.append("??? the %s - not met yet" % species_name)
			lines.append("")
			continue
		lines.append("%s the %s - %s (friendship %+d, %d visits)" % [
			record["name"], species_name, RegularMemory.stage_name(record),
			record["relationship"], record["times_visited"]])

		var known := PackedStringArray()
		var unknown := PackedStringArray()
		for account in Accounts.accounts:
			var served: int = record["served_by"].get(account["id"], 0)
			if account["id"] in record["known_players"]:
				known.append("%s (served %d)" % [account["name"], served] if served > 0 else account["name"])
			elif served > 0:
				unknown.append("%s (served %d)" % [account["name"], served])
		lines.append("  Knows: %s" % (", ".join(known) if not known.is_empty() else "nobody's name yet"))
		if not unknown.is_empty():
			lines.append("  Still learning: %s" % ", ".join(unknown))
		lines.append("")
	return "\n".join(lines).strip_edges()


# e.g. "2 delighted, 1 happy", in the order reactions.json lists them.
func _reaction_text(counts: Dictionary) -> String:
	var parts := PackedStringArray()
	for reaction in GameData.reactions.get("reactions", []):
		var count: int = counts.get(reaction["id"], 0)
		if count > 0:
			parts.append("%d %s" % [count, reaction["id"]])
	return ", ".join(parts)


# When the restaurant opens again, or that it can now.
func _opens_text() -> String:
	if DayCycle.is_new_day_waiting():
		return "It's a new day! Open up from the sign or the host stand."
	return "After hours until 5 AM (in %s), then we open again." % GameClock.describe_duration(GameClock.seconds_until_next_day())


func _next_button_text() -> String:
	if not _from_host_stand:
		return "Head out for the evening"
	return "Open for a new day" if DayCycle.is_new_day_waiting() else "Close"


# The day just ended: on into After Hours. Reopened at the host stand: close
# it, or open up if it's a new day.
func _on_next_pressed() -> void:
	if next_button.disabled:
		return
	visible = false
	if not _from_host_stand:
		day_manager.enter_after_hours()
	elif not day_manager.start_next_day():
		get_tree().paused = false
