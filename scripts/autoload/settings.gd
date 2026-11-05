# Settings (autoload): what the players picked on the settings screen
# (SettingsScreen): volumes, how fast the close-up cursor moves, and whether
# two players' views join up when they're close (the hybrid camera). Kept in
# user://settings.json, apart from the save, so it's the same for every save;
# defaults come from data/settings.json.
#
# Sound goes through three buses: Master, then Music (the Music autoload) and
# SFX (everything else: any sound player still on Master when it joins the tree
# is moved to SFX). Escape or Start opens the settings screen from anywhere.
extends Node

const PATH := "user://settings.json"
const DATA_PATH := "res://data/settings.json"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const OPEN_ACTION := "open_settings"

signal changed

var master_volume := 1.0
var music_volume := 0.8
var sfx_volume := 1.0
var pad_cursor_speed := 1.0   # Times CookSession.pad_cursor_speed.
var key_cursor_speed := 1.0   # Times CookSession.cursor_speed.
var hybrid_camera := true
var guide_always := false  # Show the Guide's arrow every day, not just to new chefs.
var cursor_speed_range := Vector2(0.4, 2.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var data := _read_json(DATA_PATH)
	var range_list: Array = data.get("cursor_speed_range", [0.4, 2.0])
	cursor_speed_range = Vector2(float(range_list[0]), float(range_list[1]))
	_apply_values(data.get("defaults", {}))
	if not ReelSandbox.active():  # A reel always sounds the same: the defaults.
		_apply_values(_read_json(PATH))
	for bus in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_apply_volumes()
	MenuTheme.apply()
	get_tree().node_added.connect(_on_node_added)
	if not InputMap.has_action(OPEN_ACTION):
		InputMap.add_action(OPEN_ACTION)
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		InputMap.action_add_event(OPEN_ACTION, key)
		var button := InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_START
		button.device = -1  # Any gamepad.
		InputMap.action_add_event(OPEN_ACTION, button)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(OPEN_ACTION) and get_tree().get_first_node_in_group(SettingsScreen.GROUP) == null:
		get_viewport().set_input_as_handled()
		SettingsScreen.open(get_tree())


# Sounds play on the SFX bus, unless they asked for another (Music's are on Music).
func _on_node_added(node: Node) -> void:
	MenuTheme.watch(node)
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		if node.bus == &"Master":
			node.bus = SFX_BUS


func set_value(key: String, value: Variant) -> void:
	_apply_values({ key: value })
	_apply_volumes()
	save()
	changed.emit()


func save() -> void:
	if ReelSandbox.active():
		return
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Couldn't save settings to %s" % PATH)
		return
	file.store_string(JSON.stringify({
		"master_volume": master_volume, "music_volume": music_volume, "sfx_volume": sfx_volume,
		"pad_cursor_speed": pad_cursor_speed, "key_cursor_speed": key_cursor_speed,
		"hybrid_camera": hybrid_camera,
		"guide_always": guide_always,
	}, "\t"))


func _apply_values(values: Dictionary) -> void:
	master_volume = clampf(float(values.get("master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(values.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(values.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	pad_cursor_speed = clampf(float(values.get("pad_cursor_speed", pad_cursor_speed)), cursor_speed_range.x, cursor_speed_range.y)
	key_cursor_speed = clampf(float(values.get("key_cursor_speed", key_cursor_speed)), cursor_speed_range.x, cursor_speed_range.y)
	hybrid_camera = bool(values.get("hybrid_camera", hybrid_camera))
	guide_always = bool(values.get("guide_always", guide_always))


func _apply_volumes() -> void:
	for pair in [["Master", master_volume], [MUSIC_BUS, music_volume], [SFX_BUS, sfx_volume]]:
		var bus := AudioServer.get_bus_index(pair[0])
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(pair[1], 0.0001)))
			AudioServer.set_bus_mute(bus, pair[1] <= 0.0)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
