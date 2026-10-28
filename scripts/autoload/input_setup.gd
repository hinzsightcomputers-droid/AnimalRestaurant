# InputSetup (autoload): registers input actions for up to 4 local players and
# decides which device (keyboard half or gamepad) drives which player.
# Action names look like "p0_move_left", "p1_interact", etc.
# Gameplay code never reads keys directly. It asks a PlayerInput node,
# which builds these names from its player_index.
#
# Devices are named "keys_left" (WASD + E), "keys_right" (arrows + Enter) and
# "pad_0", "pad_1"... Player 0 starts on keys_left; other players join by pressing
# interact on a device nobody is using yet (see PlayerManager).
extends Node

const MAX_PLAYERS := 4
const DEADZONE := 0.2
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "interact"]

const KEYBOARD_LAYOUTS := {
	"keys_left": {"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S, "interact": KEY_E},
	"keys_right": {"move_left": KEY_LEFT, "move_right": KEY_RIGHT, "move_up": KEY_UP, "move_down": KEY_DOWN, "interact": KEY_ENTER},
}
const KEYBOARD_HINTS := {"keys_left": "E", "keys_right": "Enter"}
const PAD_HINT := "A"
const KEYBOARD_MOVE_HINTS := {"keys_left": "WASD", "keys_right": "the arrow keys"}
const PAD_MOVE_HINT := "the stick"
const KEYBOARD_UP_HINTS := {"keys_left": "W", "keys_right": "Up"}

# Gamepad stick direction for each move action: [axis, direction].
const PAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
}

# Gamepad buttons (d-pad for movement, A / Cross for interact).
const PAD_BUTTONS := {
	"move_left": JOY_BUTTON_DPAD_LEFT,
	"move_right": JOY_BUTTON_DPAD_RIGHT,
	"move_up": JOY_BUTTON_DPAD_UP,
	"move_down": JOY_BUTTON_DPAD_DOWN,
	"interact": JOY_BUTTON_A,
}

var _devices: Dictionary = {}  # player_index -> device name. Lasts across days (this is an autoload).


# Builds the full action name for one player, e.g. action_name(1, "interact") -> "p1_interact".
static func action_name(player_index: int, action: String) -> String:
	return "p%d_%s" % [player_index, action]


func _ready() -> void:
	for player_index in MAX_PLAYERS:
		for action in ACTIONS:
			var action_id := action_name(player_index, action)
			if not InputMap.has_action(action_id):
				InputMap.add_action(action_id, DEADZONE)
	assign_device(0, "keys_left")


# Players who have a device, in order, e.g. [0, 1].
func active_players() -> Array[int]:
	var result: Array[int] = []
	for player_index in MAX_PLAYERS:
		if _devices.has(player_index):
			result.append(player_index)
	return result


func is_device_used(device: String) -> bool:
	return device in _devices.values()


# Point all of a player's actions at one device (replacing any old one).
func assign_device(player_index: int, device: String) -> void:
	_devices[player_index] = device
	for action in ACTIONS:
		var action_id := action_name(player_index, action)
		InputMap.action_erase_events(action_id)
		for event in _events_for(device, action):
			InputMap.action_add_event(action_id, event)


# If `event` is an interact press, the device it came from ("" otherwise).
func device_of_interact_press(event: InputEvent) -> String:
	if event is InputEventKey and event.pressed and not event.echo:
		for device in KEYBOARD_LAYOUTS:
			if event.physical_keycode == KEYBOARD_LAYOUTS[device]["interact"]:
				return device
	if event is InputEventJoypadButton and event.pressed and event.button_index == PAD_BUTTONS["interact"]:
		return "pad_%d" % event.device
	return ""


# Text for the interact button in prompts, e.g. "E", "Enter" or "A".
func interact_hint(player_index: int) -> String:
	var device: String = _devices.get(player_index, "")
	return KEYBOARD_HINTS.get(device, PAD_HINT)


# Text for moving in prompts, e.g. "WASD" or "the stick".
func move_hint(player_index: int) -> String:
	var device: String = _devices.get(player_index, "")
	return KEYBOARD_MOVE_HINTS.get(device, PAD_MOVE_HINT)


# Text for the move-up key, e.g. "W" (or "the stick" on a gamepad).
func up_hint(player_index: int) -> String:
	var device: String = _devices.get(player_index, "")
	return KEYBOARD_UP_HINTS.get(device, PAD_MOVE_HINT)


# The gamepad a player is on, or -1 for a keyboard.
func pad_of(player_index: int) -> int:
	var device: String = _devices.get(player_index, "")
	return int(device.trim_prefix("pad_")) if device.begins_with("pad_") else -1


func _events_for(device: String, action: String) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	if KEYBOARD_LAYOUTS.has(device):
		var key := InputEventKey.new()
		key.device = -1  # -1 = any keyboard
		key.physical_keycode = KEYBOARD_LAYOUTS[device][action]
		events.append(key)
	elif device.begins_with("pad_"):
		var pad := int(device.trim_prefix("pad_"))
		if PAD_AXES.has(action):
			var motion := InputEventJoypadMotion.new()
			motion.device = pad
			motion.axis = PAD_AXES[action][0]
			motion.axis_value = PAD_AXES[action][1]
			events.append(motion)
		var button := InputEventJoypadButton.new()
		button.device = pad
		button.button_index = PAD_BUTTONS[action]
		events.append(button)
	return events
