# ToastAction: butter a slice of bread and put it in the toaster.
#   1. Spread: a slice of bread lies on the board; hold the button and move the
#      knife over it to spread the butter. Done once it's nearly all covered.
#   2. The slice drops into the toaster's slot. Hold the button and pull down
#      (the stick down, or the mouse toward you) to push the lever down: the
#      toast sinks into the slot as you pull. At the bottom it clicks and holds.
# Then it toasts in the background while the eggs and bacon cook, and pops up
# when it's time to plate (the first PlaceAction); the "Toast nose" step
# (PlaceAction toast_half) takes it out of the toaster.
# Scores how much of the slice got buttered.
class_name ToastAction
extends CookAction

enum Phase { SPREAD, LEVER, TOASTING, POPPED }

@export var board := "Board"
@export var toaster_at := Vector3(0.14, 0.0, 0.5)    # In the session, on the counter.
@export var spread_needed := 0.85
@export var pull_length := 0.09                        # How far to pull (cursor, meters) for the lever to reach the bottom.

const GRID := 7                    # The slice is buttered in GRID x GRID patches.
const SLICE := Vector3(0.1, 0.012, 0.1)
const BREAD := Color(0.96, 0.86, 0.66)
const CRUST := Color(0.72, 0.47, 0.24)
const BUTTER := Color(1.0, 0.9, 0.5)
const TOASTED := Color(0.86, 0.6, 0.3)
const BODY_SIZE := Vector3(0.17, 0.12, 0.1)

var _phase := Phase.SPREAD
var _slice: Node3D
var _patches := {}                 # Vector2i -> its butter patch (shown once spread).
var _knife: Node3D
var _toaster: Node3D
var _lever: Node3D
var _pull := 0.0
var _grab_z := INF
var _bread_faces: Array[StandardMaterial3D] = []
var _toast_time := 0.0
var _buttered := 0.0


func _init() -> void:
	view_distance = 0.5
	view_pitch = 60.0


func view_point() -> Vector3:
	var b := session.surface(board).position
	return b.lerp(toaster_at, 0.5) if _phase == Phase.SPREAD else toaster_at + Vector3(0.0, 0.06, 0.0)


func uses_cursor() -> bool:
	return false


func cursor_height() -> float:
	return session.surface(board).position.y + 0.02


func _begin() -> void:
	_toaster = _make_toaster()
	session.add_child(_toaster)
	_slice = _make_slice()
	session.add_child(_slice)
	var b := session.surface(board).position
	_slice.position = Vector3(b.x, b.y + SLICE.y * 0.5, b.z)
	_knife = _make_knife()
	session.add_child(_knife)
	_knife.position = _slice.position + Vector3(0.08, 0.05, 0.0)


func end() -> void:
	if is_instance_valid(_knife):
		_knife.queue_free()
	# The toaster and toast stay till the dish is done (the session goes with them).


func update(delta: float, input: CookInput) -> void:
	match _phase:
		Phase.SPREAD:
			_spread(delta, input)
		Phase.LEVER:
			_pull_lever(input)
		Phase.TOASTING, Phase.POPPED:
			_toasting(delta)


func _spread(delta: float, input: CookInput) -> void:
	var at := Vector3(input.cursor.x, _slice.position.y + SLICE.y * 0.5, input.cursor.z)
	var lift := 0.004 if input.held else 0.03
	_knife.position = _knife.position.lerp(at + Vector3(0.0, lift, 0.0), 1.0 - exp(-20.0 * delta))
	_knife.rotation.z = lerpf(_knife.rotation.z, deg_to_rad(-25.0) if input.held else 0.0, 1.0 - exp(-10.0 * delta))
	if input.held:
		var local := Vector2(at.x - _slice.position.x, at.z - _slice.position.z) / Vector2(SLICE.x, SLICE.z) + Vector2(0.5, 0.5)
		for dx in [-1, 0, 1]:  # The blade's as wide as a few patches.
			for dz in [0]:
				var cell := Vector2i(floori(local.x * GRID) + dx, floori(local.y * GRID) + dz)
				if cell.x >= 0 and cell.y >= 0 and cell.x < GRID and cell.y < GRID and not _patches[cell].visible:
					_patches[cell].visible = true
	var share := _spread_share()
	session.set_status("Butter: %d%%" % roundi(share * 100.0))
	if share >= spread_needed:
		_into_toaster()


func _spread_share() -> float:
	var done := 0
	for patch in _patches.values():
		if patch.visible:
			done += 1
	return float(done) / (GRID * GRID)


# Up off the board and down into the slot, standing up.
func _into_toaster() -> void:
	_phase = Phase.LEVER
	_buttered = clampf(_spread_share() / spread_needed, 0.0, 1.0)
	session.pop_text("Nicely buttered!", _slice.position, 1)
	_knife.visible = false
	var tween := _slice.create_tween()
	tween.tween_property(_slice, "position", _slot_top() + Vector3(0.0, 0.08, 0.0), 0.3).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_slice, "rotation", Vector3(PI * 0.5, 0.0, 0.0), 0.3)
	tween.tween_property(_slice, "position", _slot_top(), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): session.play_sound("tick", toaster_at, -6.0, 0.9))
	session.set_status("Pull the lever down!")
	session.pop_text("Pull it down!", toaster_at + _lever.position + Vector3(0.0, 0.03, 0.0), 0)


# Where the slice stands up out of the slot, before it's pushed down.
func _slot_top() -> Vector3:
	return toaster_at + Vector3(0.0, BODY_SIZE.y + SLICE.x * 0.18, -0.022)  # The back slot.


func _pull_lever(input: CookInput) -> void:
	if input.held:
		if _grab_z == INF:
			_grab_z = input.cursor.z
		_pull = maxf(_pull, clampf((input.cursor.z - _grab_z) / pull_length, 0.0, 1.0))
	else:
		_grab_z = INF
	_lever.position.y = lerpf(BODY_SIZE.y * 0.85, BODY_SIZE.y * 0.25, _pull)
	_slice.position = _slot_top() - Vector3(0.0, SLICE.x * 0.6 * _pull, 0.0)
	session.set_status("Pull the lever down: %d%%" % roundi(_pull * 100.0))
	if _pull >= 1.0:
		_phase = Phase.TOASTING
		session.play_sound("clack", toaster_at, -2.0, 0.8)
		session.pop_text("Click!", toaster_at + Vector3(0.0, BODY_SIZE.y + 0.04, 0.0), 1)
		to_background = true  # It toasts while the eggs and bacon cook (done when it comes out).


# Glowing slots, the bread browning; up it pops when it's time to plate.
func _toasting(delta: float) -> void:
	_toast_time += delta
	var brown := clampf(_toast_time / 12.0, 0.0, 1.0)
	for face in _bread_faces:
		face.albedo_color = BREAD.lerp(TOASTED, brown)
	if _phase == Phase.TOASTING and session.current is PlaceAction:
		_phase = Phase.POPPED
		for face in _bread_faces:
			face.albedo_color = TOASTED
		_lever.position.y = BODY_SIZE.y * 0.85
		var tween := _slice.create_tween()
		tween.tween_property(_slice, "position", _slot_top() + Vector3(0.0, 0.05, 0.0), 0.12).set_ease(Tween.EASE_OUT)
		tween.tween_property(_slice, "position", _slot_top() + Vector3(0.0, 0.02, 0.0), 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		session.play_sound("ding", toaster_at, -4.0, 1.2)
		session.pop_text("Toast's up!", toaster_at + Vector3(0.0, BODY_SIZE.y + 0.08, 0.0), 1)
	if _phase == Phase.POPPED and session.current is PlaceAction and (session.current as PlaceAction).item_shape == "toast_half":
		_slice.visible = false  # Out of the toaster, cut, and onto the plate.
		if not done:
			finish(_buttered)


func scripted_hold(delta: float, input: CookInput) -> bool:
	match _phase:
		Phase.SPREAD:  # Across the slice, a patch at a time.
			for z in GRID:
				for x in GRID:
					if not _patches[Vector2i(x, z)].visible:
						var goal := _slice.position + Vector3(((x + 0.5) / GRID - 0.5) * SLICE.x * 0.86, 0.0, ((z + 0.5) / GRID - 0.5) * SLICE.z * 0.86)
						input.move_to(goal, delta, 1.5)
						return true
			return true
		Phase.LEVER:
			if _slice.position.distance_to(_slot_top()) > 0.01 and _pull == 0.0:
				return false
			input.move_to(input.cursor + Vector3(0.0, 0.0, 0.3), delta, 0.6)
			return true
	return false


func _make_slice() -> Node3D:
	var slice := Node3D.new()
	var crust := MeshInstance3D.new()
	crust.mesh = PlaceAction.rounded_block(SLICE, 0.008)
	var crust_paint := StandardMaterial3D.new()
	crust_paint.albedo_color = CRUST
	crust_paint.set_meta(ToonStyle.FOOD, "baked")
	crust.material_override = crust_paint
	slice.add_child(crust)
	for side in [1.0, -1.0]:  # The soft middle, both faces.
		var face := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(SLICE.x * 0.86, 0.001, SLICE.z * 0.86)
		var paint := StandardMaterial3D.new()
		paint.albedo_color = BREAD
		paint.set_meta(ToonStyle.FOOD, "baked")
		mesh.material = paint
		face.mesh = mesh
		face.position.y = side * (SLICE.y * 0.5 + 0.0006)
		slice.add_child(face)
		_bread_faces.append(paint)
	var butter := StandardMaterial3D.new()
	butter.albedo_color = BUTTER
	butter.roughness = 0.25
	butter.set_meta(ToonStyle.FOOD, "butter")
	var patch_mesh := BoxMesh.new()
	patch_mesh.size = Vector3(SLICE.x * 0.86 / GRID * 1.08, 0.0012, SLICE.z * 0.86 / GRID * 1.08)
	patch_mesh.material = butter
	for x in GRID:
		for z in GRID:
			var patch := MeshInstance3D.new()
			patch.mesh = patch_mesh
			patch.position = Vector3(((x + 0.5) / GRID - 0.5) * SLICE.x * 0.86, SLICE.y * 0.5 + 0.0014, ((z + 0.5) / GRID - 0.5) * SLICE.z * 0.86)
			patch.visible = false
			slice.add_child(patch)
			_patches[Vector2i(x, z)] = patch
	return slice


# A cream toaster with two dark slots on top and a lever on its side.
func _make_toaster() -> Node3D:
	var toaster := Node3D.new()
	toaster.position = toaster_at
	var body := MeshInstance3D.new()
	body.mesh = PlaceAction.rounded_block(BODY_SIZE, 0.025)
	var cream := StandardMaterial3D.new()
	cream.albedo_color = Color(0.95, 0.9, 0.78)
	cream.roughness = 0.4
	body.material_override = cream
	body.position.y = BODY_SIZE.y * 0.5
	toaster.add_child(body)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.15, 0.12, 0.1)
	for z in [-0.022, 0.022]:
		var slot := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(SLICE.x * 1.05, 0.002, 0.016)
		mesh.material = dark
		slot.mesh = mesh
		slot.position = Vector3(0.0, BODY_SIZE.y + 0.0005, z)
		toaster.add_child(slot)
	_lever = Node3D.new()
	var knob := MeshInstance3D.new()
	knob.mesh = PlaceAction.rounded_block(Vector3(0.03, 0.014, 0.022), 0.006)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.3, 0.25)
	knob.material_override = red
	_lever.add_child(knob)
	_lever.position = Vector3(BODY_SIZE.x * 0.5 + 0.014, BODY_SIZE.y * 0.85, 0.0)
	toaster.add_child(_lever)
	return toaster


func _make_knife() -> Node3D:
	var knife := Node3D.new()
	var blade := MeshInstance3D.new()
	blade.mesh = PlaceAction.rounded_block(Vector3(0.07, 0.003, 0.016), 0.0014)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.82, 0.84, 0.87)
	steel.metallic = 0.7
	steel.roughness = 0.3
	blade.material_override = steel
	blade.position.x = 0.035
	knife.add_child(blade)
	var smear := MeshInstance3D.new()  # Butter on the blade.
	smear.mesh = PlaceAction.rounded_block(Vector3(0.03, 0.004, 0.012), 0.0018)
	var butter := StandardMaterial3D.new()
	butter.albedo_color = BUTTER
	smear.material_override = butter
	smear.position = Vector3(0.02, 0.0015, 0.0)
	knife.add_child(smear)
	var handle := MeshInstance3D.new()
	handle.mesh = PlaceAction.rounded_block(Vector3(0.06, 0.01, 0.014), 0.004)
	handle.material_override = KitchenProps.handle_wood()
	handle.position.x = 0.1
	knife.add_child(handle)
	return knife
