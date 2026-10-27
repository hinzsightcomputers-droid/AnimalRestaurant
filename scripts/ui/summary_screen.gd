# SummaryScreen: the end-of-day results panel. Hidden until the DayManager
# reports the day has ended, then shows the totals and a button to start the
# next day. Runs while the game is paused.
extends CanvasLayer

const INPUT_DELAY := 1.0  # Ignore input briefly so a held E doesn't skip the screen.

@export var day_manager: DayManager

@onready var title_label: Label = $Panel/Content/Title
@onready var body_label: Label = $Panel/Content/Body
@onready var next_button: Button = $Panel/Content/NextDayButton

var _input_delay_left := 0.0


func _ready() -> void:
	visible = false
	day_manager.day_ended.connect(_show_summary)
	next_button.pressed.connect(_on_next_pressed)


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
	title_label.text = "Day %d complete!" % GameState.day
	body_label.text = _summary_text(summary)
	next_button.text = "Start Day %d" % (GameState.day + 1)
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
	lines.append("Total money: $%d" % GameState.money)
	return "\n".join(lines)


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
