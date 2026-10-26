# InputSetup (autoload): registers input actions for up to 4 local players.
# Action names look like "p0_move_left", "p1_interact", etc.
# Gameplay code never reads keys directly. It asks a PlayerInput node,
# which builds these names from its player_index.
extends Node

const MAX_PLAYERS := 4
const DEADZONE := 0.2
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "interact"]

# Keyboard layouts for players 0 and 1. Players 2 and 3 use gamepads only.
const KEYBOARD_LAYOUTS := [
	{"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S, "interact": KEY_E},
	{"move_left": KEY_LEFT, "move_right": KEY_RIGHT, "move_up": KEY_UP, "move_down": KEY_DOWN, "interact": KEY_ENTER},
]

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


# Builds the full action name for one player, e.g. action_name(1, "interact") -> "p1_interact".
static func action_name(player_index: int, action: String) -> String:
	return "p%d_%s" % [player_index, action]


func _ready() -> void:
	for player_index in MAX_PLAYERS:
		_register_player(player_index)


func _register_player(player_index: int) -> void:
	for action in ACTIONS:
		var action_id := action_name(player_index, action)
		if InputMap.has_action(action_id):
			continue
		InputMap.add_action(action_id, DEADZONE)

		# Keyboard (only the first two players have a keyboard layout).
		if player_index < KEYBOARD_LAYOUTS.size():
			var key := InputEventKey.new()
			key.device = -1  # -1 = any device
			key.physical_keycode = KEYBOARD_LAYOUTS[player_index][action]
			InputMap.action_add_event(action_id, key)

		# Gamepad number N belongs to player N.
		if PAD_AXES.has(action):
			var motion := InputEventJoypadMotion.new()
			motion.device = player_index
			motion.axis = PAD_AXES[action][0]
			motion.axis_value = PAD_AXES[action][1]
			InputMap.action_add_event(action_id, motion)

		var button := InputEventJoypadButton.new()
		button.device = player_index
		button.button_index = PAD_BUTTONS[action]
		InputMap.action_add_event(action_id, button)
