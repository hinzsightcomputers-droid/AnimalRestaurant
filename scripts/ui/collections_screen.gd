# CollectionsScreen: the Fish Log and the Forage Log, a tab each. Every fish or
# item gets a card with a little turning model of it, or a dark silhouette and
# "???" until someone finds one. The focused card's details show underneath:
# how many, the biggest, who found the first and when, or for one not found
# yet, a hint of where and when to look. Opened from the catalogue (the
# summary screen's Collections button) or the debug panel. Moving (any
# player's keys or stick, arrows, the mouse) picks a card; interact presses a
# tab; Close (or Escape / B) closes it. Pauses the game while open.
class_name CollectionsScreen
extends CanvasLayer

enum Tab { FISH, FORAGE }

const GROUP := "collections_screen"
const CARD_SIZE := Vector2(150, 150)
const PREVIEW_SIZE := Vector2i(150, 110)
const PANEL_MAX := Vector2(1000, 680)
const SCREEN_MARGIN := 24.0
const BROWN := Color(0.45, 0.28, 0.16)
const TEXT := Color(0.3, 0.22, 0.15)
const WHERE_WORDS := { "oak": "under the oaks", "pine": "under the pines", "meadow": "in the grass", "pond": "by the pond" }

signal closed

var _tab := Tab.FISH
var _was_paused := false
var _panel: PanelContainer
var _fish_button: Button
var _forage_button: Button
var _close_button: Button
var _grid: GridContainer
var _scroll: ScrollContainer
var _details: Label
var _cards: Array[Control] = []
var _models: Array[Node3D] = []


# Opens the screen (one at a time) on a tab.
static func open(tree: SceneTree, tab := Tab.FISH) -> CollectionsScreen:
	var screen := tree.get_first_node_in_group(GROUP) as CollectionsScreen
	if screen == null:
		screen = CollectionsScreen.new()
		tree.root.add_child(screen)
	screen._show_tab(tab)
	return screen


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	_was_paused = get_tree().paused
	get_tree().paused = true
	_build()
	get_viewport().size_changed.connect(_fit_to_screen)


func close() -> void:
	get_tree().paused = _was_paused
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	for model in _models:
		model.rotation.y += delta * 0.7


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	for player_index in InputSetup.MAX_PLAYERS:
		if event.is_action_pressed(InputSetup.action_name(player_index, "interact")):
			get_viewport().set_input_as_handled()
			var focused := get_viewport().gui_get_focus_owner() as Button
			if focused != null:
				focused.pressed.emit()
			return
		for side in [["move_left", SIDE_LEFT], ["move_right", SIDE_RIGHT], ["move_up", SIDE_TOP], ["move_down", SIDE_BOTTOM]]:
			if event.is_action_pressed(InputSetup.action_name(player_index, side[0])):
				get_viewport().set_input_as_handled()
				_move_focus(side[1])
				return


# WASD and the like move between cards and buttons (the arrows and gamepads
# already do, through the ui_ actions).
func _move_focus(side: Side) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
		_fish_button.grab_focus()
		return
	var next := focused.find_valid_focus_neighbor(side)
	if next != null:
		next.grab_focus()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.99, 0.95, 0.86)
	style.set_border_width_all(6)
	style.border_color = Color(0.55, 0.38, 0.25)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_panel.add_child(content)

	var title := Label.new()
	title.text = "Collections"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", BROWN)
	content.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(tabs)
	_fish_button = _button(tabs, "", _show_tab.bind(Tab.FISH))
	_forage_button = _button(tabs, "", _show_tab.bind(Tab.FORAGE))
	for button in [_fish_button, _forage_button]:
		button.toggle_mode = true  # The open tab shows pressed in.

	_scroll = ScrollContainer.new()
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)

	_details = Label.new()
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size = Vector2(0, 84)
	_details.add_theme_font_size_override("font_size", 18)
	_details.add_theme_color_override("font_color", TEXT)
	content.add_child(_details)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(bottom)
	_close_button = _button(bottom, "Close", close)
	_fit_to_screen()


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 46)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _fit_to_screen() -> void:
	if _panel == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var size := PANEL_MAX.min(screen - Vector2.ONE * SCREEN_MARGIN * 2.0)
	_panel.size = size
	_panel.position = (screen - size) / 2.0
	_grid.columns = maxi(1, floori((size.x - 60.0) / (CARD_SIZE.x + 10.0)))


func _show_tab(tab: Tab) -> void:
	_tab = tab
	_fish_button.text = "Fish  %d/%d" % [GameState.fish_log.size(), GameData.fish.size()]
	_forage_button.text = "Forage  %d/%d" % [GameState.forage_log.size(), GameData.forage.size()]
	_fish_button.set_pressed_no_signal(tab == Tab.FISH)
	_forage_button.set_pressed_no_signal(tab == Tab.FORAGE)
	for card in _cards:
		card.queue_free()
	_cards.clear()
	_models.clear()
	var entries: Array[Dictionary] = GameData.fish if tab == Tab.FISH else GameData.forage
	for entry in entries:
		_add_card(entry)
	# Tabs go down into the first card; the first row of cards goes up to the tabs.
	var tab_button := _fish_button if tab == Tab.FISH else _forage_button
	if not _cards.is_empty():
		for button in [_fish_button, _forage_button]:
			button.focus_neighbor_bottom = button.get_path_to(_cards[0])
		for i in mini(_grid.columns, _cards.size()):
			_cards[i].focus_neighbor_top = _cards[i].get_path_to(tab_button)
		var last_row_start := (_cards.size() - 1) / _grid.columns * _grid.columns
		for i in range(last_row_start, _cards.size()):
			_cards[i].focus_neighbor_bottom = _cards[i].get_path_to(_close_button)
		_close_button.focus_neighbor_top = _close_button.get_path_to(_cards[last_row_start])
	tab_button.grab_focus()
	_details.text = "Pick a card to see more. %s" % ("Fish are caught at the pond after hours." if tab == Tab.FISH else "Things to gather turn up around the garden after hours, new every day.")


func _found(entry: Dictionary) -> bool:
	return (GameState.fish_log if _tab == Tab.FISH else GameState.forage_log).has(entry["id"])


func _add_card(entry: Dictionary) -> void:
	var found := _found(entry)
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_ALL
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.95, 0.88, 0.74) if found else Color(0.88, 0.84, 0.78)
	normal.set_corner_radius_all(10)
	normal.set_border_width_all(3)
	normal.border_color = normal.bg_color
	normal.set_content_margin_all(4)
	var focused: StyleBoxFlat = normal.duplicate()
	focused.border_color = Color(0.85, 0.45, 0.15)
	card.add_theme_stylebox_override("panel", normal)
	card.focus_entered.connect(func():
		card.add_theme_stylebox_override("panel", focused)
		_details.text = _describe(entry))
	card.focus_exited.connect(func(): card.add_theme_stylebox_override("panel", normal))
	card.mouse_entered.connect(card.grab_focus)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	box.add_child(_preview(entry, found))
	var label := Label.new()
	label.text = entry.get("name", "?") if found else "???"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", TEXT)
	box.add_child(label)
	_grid.add_child(card)
	_cards.append(card)


# A little world of its own with the model in it, lit, or black as a silhouette.
func _preview(entry: Dictionary, found: bool) -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(PREVIEW_SIZE)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.size = PREVIEW_SIZE
	container.add_child(viewport)
	var pivot := Node3D.new()
	viewport.add_child(pivot)
	var model: Node3D
	if _tab == Tab.FISH:
		model = Fishing.make_model(entry, 1.0)
		model.rotation.y = PI / 2.0  # Side on.
		pivot.position.y = 0.0
	else:
		model = Forage.make_model(entry, 1.0)
		model.position.y = -0.4
	pivot.add_child(model)
	_models.append(pivot)
	if not found:
		var shadow := StandardMaterial3D.new()
		shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shadow.albedo_color = Color(0.22, 0.17, 0.13)
		for node in model.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_override = shadow
	var camera := Camera3D.new()
	camera.fov = 45.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.35, 1.6), Vector3.ZERO)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, 30.0, 0.0)
	viewport.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.78, 0.74)
	environment.environment.ambient_light_energy = 0.6
	viewport.add_child(environment)
	return container


func _describe(entry: Dictionary) -> String:
	if not _found(entry):
		return "???\n%s%s" % [_hint(entry), "\nA rare one!" if entry.get("rarity", "") == "rare" else ""]
	var lines := PackedStringArray()
	if _tab == Tab.FISH:
		var log: Dictionary = GameState.fish_log[entry["id"]]
		lines.append("%s: caught %d, the biggest %d cm (%s)." % [entry["name"], int(log.get("caught", 0)), int(log.get("biggest_cm", 0)), _chef(log.get("biggest_by", ""))])
		lines.append("First caught %s by %s." % [GameClock.describe_date(log.get("first_date", ""), true), _chef(log.get("first_by", ""))])
	else:
		var log: Dictionary = GameState.forage_log[entry["id"]]
		lines.append("%s: found %d%s." % [entry["name"], int(log.get("found", 0)), "" if entry.get("pantry", true) else " (a keepsake, not for cooking)"])
		lines.append("First found %s by %s." % [GameClock.describe_date(log.get("first_date", ""), true), _chef(log.get("first_by", ""))])
	lines.append(entry.get("description", ""))
	return "\n".join(lines)


# Where and when to look for one not found yet.
func _hint(entry: Dictionary) -> String:
	var seasons: Array = entry.get("seasons", [])
	var hours: Array = entry.get("hours", [])
	var when := "all year" if seasons.is_empty() else "in " + ", ".join(seasons.map(func(s): return String(s)))
	if not hours.is_empty():
		when += ", " + ", ".join(hours.map(func(h): return String(h).replace("_", " ")))
	if _tab == Tab.FISH:
		return "Bites at the %s %s." % [entry.get("habitat", "pond"), when]
	var places := ", ".join(entry.get("where", []).map(func(w): return WHERE_WORDS.get(w, w)))
	return "Grows %s, %s." % [places, when]


func _chef(account_id: String) -> String:
	return Accounts.get_account(account_id).get("name", "someone") if not account_id.is_empty() else "someone"
