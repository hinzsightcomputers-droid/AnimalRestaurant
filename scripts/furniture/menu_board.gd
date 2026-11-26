# MenuBoard: the chalkboard standing just inside the front door. Before each
# meal opens, a chef writes that meal's menu on it (ChalkAction in a close-up):
# no customers come in till it's up (DayManager waits on `written`). Then it
# shows the meal's name and a chalk drawing of each dish on the menu, till
# the bell's rung for the next meal and it wants writing again.
class_name MenuBoard
extends Station

signal written(meal: int)

const GROUP := "menu_board"
const CLOSEUP := "res://scenes/cooking/menu_board_closeup.tscn"
const FACE := Vector2(0.8, 0.55)              # The slate on the stand.
const FACE_MIDDLE := 0.95                     # How high its middle is.
const CLOSEUP_AT := Vector3(0.0, 0.92, 0.45)  # Where the close-up's slate lies while it's written.
const RESULT_SHOW_TIME := 1.2

@export var view_manager: ViewManager

var session: CookSession = null
var _writer: Player = null
var _waiting_meal := -1
var _display: Node3D
var _nudge: Label3D
var _nudge_time := 0.0


static func find(tree: SceneTree) -> MenuBoard:
	return tree.get_first_node_in_group(GROUP) as MenuBoard


func _init() -> void:
	display_name = "Menu Board"
	add_to_group(GROUP)
	var parts := Node3D.new()
	parts.name = "Visual"
	add_child(parts)
	var spot := Interactable.new()
	spot.name = "Interactable"
	spot.radius = 1.4
	spot.prompt_height = 1.5
	spot.priority = 1
	add_child(spot)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.3, 0.5)
	shape.shape = box
	shape.position.y = 0.65
	add_child(shape)


func _ready() -> void:
	super._ready()
	interactable.prompt_for_player = _prompt_for
	_build_stand()
	show_menu()


func _process(delta: float) -> void:
	if _nudge != null and _nudge.visible:  # "Write the menu!" bobs till someone does.
		_nudge_time += delta
		_nudge.position.y = FACE_MIDDLE + FACE.y * 0.5 + 0.18 + sin(_nudge_time * 3.0) * 0.03


# The meal's about to open: it wants writing.
func ask(meal: int) -> void:
	_waiting_meal = meal
	show_menu()


func is_waiting() -> bool:
	return _waiting_meal >= 0


# Written straight away, no close-up (the debug panel, a bot playing).
func write_now() -> void:
	if is_waiting() and session == null:
		_written()


func _prompt_for(_player_index: int) -> String:
	if session != null or not is_waiting():
		return ""
	return "Write the %s menu" % String(GameState.phase_info(_waiting_meal).get("name", "")).to_lower()


func _on_interacted(player_index: int) -> void:
	if session != null or not is_waiting():
		return
	var player := Player.find(get_tree(), player_index)
	if player == null or player.held_item != null:
		if player != null:
			GameEvents.announce("Hands free to write the menu!")
		return
	open_closeup(player)
	used.emit(self, player_index)


# Writing it: the slate comes down flat onto its stand and the chef chalks it up.
func open_closeup(player: Player, scripted := false) -> void:
	_writer = player
	var recipe := CookRecipe.new()
	var meal_name := String(GameState.phase_info(_waiting_meal).get("name", "Menu"))
	recipe.display_name = "%s Menu" % meal_name
	recipe.serve_on = ""
	recipe.pieces = 0
	var chalk := ChalkAction.new()
	chalk.title = "Write the menu"
	chalk.hint = "Hold [button] on the green ring and follow the dots with [stick] to chalk each drawing. Stray too far and it slips: hold it again where you stopped."
	chalk.meal_name = meal_name
	chalk.dishes.assign(GameData.meal_menu())
	recipe.steps.assign([chalk])
	session = load(CLOSEUP).instantiate()
	session.position = CLOSEUP_AT
	add_child(session)
	visual.visible = false  # Taken down off its stand to write on.
	player.movement_locked = true
	player.interactor.lock_to(interactable)
	var zoom := CameraZoomSettings.new()
	zoom.distance = 0.85
	zoom.pitch_degrees = 62.0
	zoom.yaw_degrees = rad_to_deg(global_rotation.y)
	zoom.duration = 0.5
	var look := to_global(CLOSEUP_AT)
	player.request_camera_focus(look, zoom)
	player.hide_from_own_view(true)
	session.home_view = [look, zoom]
	session.finished.connect(_on_session_finished)
	session.start(recipe, player, view_manager if view_manager != null else get_tree().root.find_children("*", "ViewManager", true, false).front())
	if scripted:
		session.input.scripted = true
	_play_bounce()


func _on_session_finished(quality: float) -> void:
	await get_tree().create_timer(RESULT_SHOW_TIME).timeout
	session.queue_free()
	session = null
	visual.visible = true
	var meal_name := String(GameState.phase_info(_waiting_meal).get("name", "")).to_lower()
	if _writer != null and is_instance_valid(_writer):
		_writer.movement_locked = false
		_writer.interactor.unlock()
		_writer.release_camera_focus()
		_writer.hide_from_own_view(false)
		GameEvents.announce("%s wrote up the %s menu%s" % [Accounts.name_of(_writer.player_index), meal_name, "." if quality >= 0.7 else " (a bit wobbly)."])
	_writer = null
	_written()


func _written() -> void:
	var meal := _waiting_meal
	_waiting_meal = -1
	GameState.menu_written_meal = meal
	SaveGame.save_game()
	show_menu()
	written.emit(meal)


# The face: this meal's menu once written, a blank slate asking for it while
# it's wanted, and wiped clean when the restaurant's closed.
func show_menu() -> void:
	if _display != null:
		_display.queue_free()
	_display = Node3D.new()
	# The chalk is drawn lying flat; stood up, the board's "up" is the face's up.
	_display.rotation.x = PI * 0.5
	_display.position = Vector3(0.0, FACE_MIDDLE, 0.026)
	_display.scale = Vector3.ONE * (FACE.x / ChalkAction.BOARD.x)
	visual.add_child(_display)
	var shown := DayCycle.is_open() and not is_waiting() and GameState.menu_written_meal == DayCycle.meal
	if shown:
		ChalkAction.draw_menu(_display, String(GameState.phase_info(DayCycle.meal).get("name", "Menu")), GameData.meal_menu(), 0.0)
	_nudge.visible = is_waiting()


func _build_stand() -> void:
	var wood := KitchenProps.board_wood()
	for side in [-1.0, 1.0]:  # The A-frame's legs, the back pair splayed behind.
		for back in [0.0, 1.0]:
			var leg := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.05, 1.42, 0.04)
			mesh.material = wood
			leg.mesh = mesh
			leg.position = Vector3(side * (FACE.x * 0.5 + 0.03), 0.69, -0.12 * back)
			leg.rotation.x = deg_to_rad(-10.0 if back > 0.0 else 4.0)
			visual.add_child(leg)
	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(FACE.x + 0.08, FACE.y + 0.08, 0.035)
	frame_mesh.material = wood
	frame.mesh = frame_mesh
	frame.position = Vector3(0.0, FACE_MIDDLE, 0.0)
	visual.add_child(frame)
	var slate := MeshInstance3D.new()
	var slate_mesh := BoxMesh.new()
	slate_mesh.size = Vector3(FACE.x, FACE.y, 0.01)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = ChalkAction.SLATE
	paint.roughness = 0.95
	slate_mesh.material = paint
	slate.mesh = slate_mesh
	slate.position = Vector3(0.0, FACE_MIDDLE, 0.02)
	visual.add_child(slate)
	var ledge := MeshInstance3D.new()  # A chalk ledge, with a stick on it.
	var ledge_mesh := BoxMesh.new()
	ledge_mesh.size = Vector3(FACE.x, 0.02, 0.05)
	ledge_mesh.material = wood
	ledge.mesh = ledge_mesh
	ledge.position = Vector3(0.0, FACE_MIDDLE - FACE.y * 0.5 - 0.04, 0.04)
	visual.add_child(ledge)
	_nudge = Label3D.new()
	_nudge.text = "Write the menu!"
	_nudge.font = load("res://assets/fonts/Fredoka.ttf")
	_nudge.font_size = 64
	_nudge.pixel_size = 0.004
	_nudge.outline_size = 14
	_nudge.modulate = Color(1.0, 0.95, 0.6)
	_nudge.outline_modulate = Color(0.25, 0.16, 0.1)
	_nudge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nudge.no_depth_test = true
	add_child(_nudge)
