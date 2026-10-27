# PlayerManager: spawns a Player for everyone who has joined, and lets new
# players join mid-game by pressing interact on a device nobody is using yet
# (the other half of the keyboard, or a gamepad). Up to InputSetup.MAX_PLAYERS.
# Who has joined is remembered by InputSetup, so players stay in across days.
class_name PlayerManager
extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

signal player_joined(player: Player)


func _ready() -> void:
	for player_index in InputSetup.active_players():
		_spawn(player_index)


func _unhandled_input(event: InputEvent) -> void:
	var device := InputSetup.device_of_interact_press(event)
	if device.is_empty() or InputSetup.is_device_used(device):
		return
	get_viewport().set_input_as_handled()

	# Playing alone and haven't touched the keyboard yet? Then this device
	# takes over Player 1 instead (e.g. someone who wants to use a gamepad).
	var players := InputSetup.active_players()
	if players.size() == 1:
		var only_player := Player.find(get_tree(), players[0])
		if only_player != null and not only_player.has_acted:
			InputSetup.assign_device(players[0], device)
			GameEvents.announce("Player %d is now using the %s." % [players[0] + 1, device_name(device)])
			return

	if players.size() >= InputSetup.MAX_PLAYERS:
		return
	var player_index := _first_free_index()
	InputSetup.assign_device(player_index, device)
	_spawn(player_index)
	GameEvents.announce("Player %d joined! (%s)" % [player_index + 1, device_name(device)])


# e.g. "keyboard (arrow keys)" or "gamepad 2".
static func device_name(device: String) -> String:
	match device:
		"keys_left":
			return "keyboard (WASD)"
		"keys_right":
			return "keyboard (arrow keys)"
	return "gamepad %d" % (int(device.trim_prefix("pad_")) + 1)


func _spawn(player_index: int) -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.player_index = player_index
	add_child(player)
	var spawn := get_node_or_null("Spawn%d" % player_index) as Node3D
	player.global_position = spawn.global_position if spawn != null else global_position
	player.reset_physics_interpolation()
	player_joined.emit(player)


func _first_free_index() -> int:
	var used := InputSetup.active_players()
	for player_index in InputSetup.MAX_PLAYERS:
		if not player_index in used:
			return player_index
	return -1
