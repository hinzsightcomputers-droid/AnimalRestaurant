# SummaryScreen: the end-of-day results panel. Hidden until the DayManager
# reports the day has ended, then shows the totals, what each chef did, and a
# button to start the next day. The Friends button flips to a page of which
# chefs each regular knows. Runs while the game is paused.
extends CanvasLayer

const INPUT_DELAY := 1.0  # Ignore input briefly so a held E doesn't skip the screen.
# Chef actions in the order they're listed, with how to say each count.
const ACTION_WORDS := [
	["chopped", "chopped"],
	["cooked", "cooked"],
	["served", "served"],
	["cleaned", "tables cleaned"],
]

@export var day_manager: DayManager

@onready var title_label: Label = $Panel/Content/Title
@onready var body_label: Label = $Panel/Content/Body
@onready var friends_button: Button = $Panel/Content/Buttons/FriendsButton
@onready var next_button: Button = $Panel/Content/Buttons/NextDayButton

var _input_delay_left := 0.0
var _summary: Dictionary = {}
var _showing_friends := false


func _ready() -> void:
	visible = false
	day_manager.day_ended.connect(_show_summary)
	next_button.pressed.connect(_on_next_pressed)
	friends_button.pressed.connect(_toggle_friends)


func _process(delta: float) -> void:
	if visible and _input_delay_left > 0.0:
		_input_delay_left -= delta
		next_button.disabled = _input_delay_left > 0.0


# Any player's interact button also continues (the button itself handles Enter / click).
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	for player_index in InputSetup.MAX_PLAYERS:
		if event.is_action_pressed(InputSetup.action_name(player_index, "interact")):
			get_viewport().set_input_as_handled()
			_on_next_pressed()
			return


func _show_summary(summary: Dictionary) -> void:
	_summary = summary
	_showing_friends = false
	_refresh_page()
	next_button.text = "Start Day %d" % GameState.day
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


func _toggle_friends() -> void:
	_showing_friends = not _showing_friends
	_refresh_page()


func _refresh_page() -> void:
	if _showing_friends:
		title_label.text = "Friends"
		body_label.text = _friends_text()
		friends_button.text = "Back to summary"
	else:
		title_label.text = "Day %d complete!" % _summary["day"]
		body_label.text = _summary_text(_summary)
		friends_button.text = "Friends"


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
		lines.append("%s the %s - %s (friendship %d/%d, %d visits)" % [
			record["name"], species_name, RegularMemory.relationship_title(record),
			record["relationship"], GameData.regular_settings.get("relationship_max", 10), record["times_visited"]])

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
