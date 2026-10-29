# SummaryScreen: the end-of-day results panel. Hidden until the DayManager
# reports the day has ended, then shows the totals, what each chef did, and a
# button to start the next day. The Friends button flips to a page of which
# chefs each regular knows, and the Shop button to the upgrades you can buy.
# Runs while the game is paused.
extends CanvasLayer

enum Page { SUMMARY, FRIENDS, SHOP }

const INPUT_DELAY := 1.0  # Ignore input briefly so a held E doesn't skip the screen.
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
@onready var body_label: Label = $Panel/Content/Body
@onready var upgrade_scroll: ScrollContainer = $Panel/Content/UpgradeScroll
@onready var upgrade_list: VBoxContainer = $Panel/Content/UpgradeScroll/UpgradeList
@onready var friends_button: Button = $Panel/Content/Buttons/FriendsButton
@onready var shop_button: Button = $Panel/Content/Buttons/ShopButton
@onready var next_button: Button = $Panel/Content/Buttons/NextDayButton

var _input_delay_left := 0.0
var _summary: Dictionary = {}
var _page := Page.SUMMARY


func _ready() -> void:
	visible = false
	day_manager.day_ended.connect(_show_summary)
	next_button.pressed.connect(_on_next_pressed)
	friends_button.pressed.connect(_toggle_page.bind(Page.FRIENDS))
	shop_button.pressed.connect(_toggle_page.bind(Page.SHOP))


func _process(delta: float) -> void:
	if visible and _input_delay_left > 0.0:
		_input_delay_left -= delta
		next_button.disabled = _input_delay_left > 0.0


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


func _show_summary(summary: Dictionary) -> void:
	_summary = summary
	_page = Page.SUMMARY
	_refresh_page()
	next_button.text = "Start shift %d" % GameState.next_shift_number()
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
		lines.append("Reactions: %s" % _reaction_text(summary["reaction_counts"]))
		lines.append("Most ordered: %s" % GameData.get_dish(summary["top_dish"]).get("name", "?"))
	else:
		lines.append("A quiet day. Tomorrow will be busier!")

	lines.append("")
	lines.append_array(_chef_lines(summary))
	lines.append("")
	lines.append("Total money: $%d" % GameState.money)
	return "\n".join(lines)


# Friends and Shop open their page, or go back to the summary if already open.
func _toggle_page(page: Page) -> void:
	_page = Page.SUMMARY if _page == page else page
	_refresh_page()


func _refresh_page() -> void:
	upgrade_scroll.visible = _page == Page.SHOP
	body_label.size_flags_vertical = Control.SIZE_FILL if _page == Page.SHOP else Control.SIZE_EXPAND_FILL
	friends_button.text = "Back to summary" if _page == Page.FRIENDS else "Friends"
	shop_button.text = "Back to summary" if _page == Page.SHOP else _shop_button_text()
	match _page:
		Page.FRIENDS:
			title_label.text = "Friends"
			body_label.text = _friends_text()
		Page.SHOP:
			title_label.text = "Shop"
			body_label.text = "You have $%d. Treat the restaurant to something nice!" % GameState.money
			_build_upgrade_list()
		_:
			title_label.text = "%s - shift %d done!" % [GameClock.describe_date(_summary["date"]), _summary["shift"]]
			body_label.text = _summary_text(_summary)
			if not next_button.disabled:
				next_button.grab_focus()  # Back on the summary, interact starts the day again.


# "Shop (2 new!)" when there are upgrades or dishes you can afford right now.
func _shop_button_text() -> String:
	var affordable := 0
	for upgrade in GameData.upgrades:
		if not GameState.has_upgrade(upgrade["id"]) and GameState.money >= upgrade["price"]:
			affordable += 1
	for dish in GameData.shop_dishes():
		if not GameData.is_unlocked(dish["id"]) and GameState.money >= int(dish["unlock_cost"]):
			affordable += 1
	return "Shop (%d new!)" % affordable if affordable > 0 else "Shop"


# One button per upgrade, then per dish to add to the menu: buyable, too
# pricey, or already owned.
func _build_upgrade_list() -> void:
	for child in upgrade_list.get_children():
		upgrade_list.remove_child(child)
		child.queue_free()
	var buttons: Array[Button] = []
	for upgrade in GameData.upgrades:
		var button := _shop_button(upgrade["name"], upgrade["description"], int(upgrade["price"]), GameState.has_upgrade(upgrade["id"]), "Owned")
		button.pressed.connect(_buy.bind(upgrade["id"]))
		buttons.append(button)
	var heading := Label.new()
	heading.text = "New dishes"
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", body_label.get_theme_color("font_color"))
	upgrade_list.add_child(heading)
	for dish in GameData.shop_dishes():
		var button := _shop_button(dish["name"], dish["description"], int(dish["unlock_cost"]), GameData.is_unlocked(dish["id"]), "On the menu")
		button.pressed.connect(_buy_dish.bind(dish["id"]))
		buttons.append(button)
	var buyable := buttons.filter(func(b): return not b.disabled)
	(buyable[0] if not buyable.is_empty() else shop_button).grab_focus()


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


func _buy_dish(dish_id: String) -> void:
	if GameState.buy_dish(dish_id):
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


func _on_next_pressed() -> void:
	if next_button.disabled:
		return
	visible = false
	day_manager.start_next_day()
