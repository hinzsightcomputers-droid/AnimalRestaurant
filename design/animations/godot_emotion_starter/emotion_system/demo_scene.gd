extends Node3D
## Builds a tiny stage with a placeholder bear so you can test faces, effects, sounds
## and dialogue before you have any real art. Run the project (F5) to try it.
## Delete this file (and demo.tscn) when you're ready to use your own scenes.

const EMOTIONS := ["neutral", "happy", "joyful", "excited", "surprised", "sad",
		"angry", "nervous", "confused", "tired", "shy"]

var _bear: DialogueCharacter
var _runner: DialogueRunner
var _talk_button: Button


func _ready() -> void:
	_build_stage()
	_bear = _build_bear()
	_build_tester_ui()
	_runner = DialogueRunner.new()
	add_child(_runner)
	_runner.dialogue_finished.connect(func() -> void: _talk_button.visible = true)
	_runner.start.call_deferred()


func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#bfe3f2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	add_child(sun)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 4.2)
	add_child(cam)
	cam.look_at(Vector3(0, 1.1, 0))
	cam.current = true

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 14)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#8fc77a")
	ground.material_override = gm
	add_child(ground)


func _ball(parent: Node3D, pos: Vector3, radius: float, color: Color, squash := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mi.material_override = m
	mi.position = pos
	mi.scale = squash
	parent.add_child(mi)
	return mi


func _build_bear() -> DialogueCharacter:
	var root := DialogueCharacter.new()
	root.character_id = &"stitches"
	root.display_name = "Stitches"

	var body_root := Node3D.new()
	body_root.name = "Body"
	root.add_child(body_root)

	var fur := Color("#b9824f")
	_ball(body_root, Vector3(0, 0.5, 0), 0.45, fur, Vector3(1.0, 1.1, 0.9))
	_ball(body_root, Vector3(0, 1.35, 0), 0.5, fur)
	_ball(body_root, Vector3(-0.36, 1.78, 0.0), 0.16, fur)
	_ball(body_root, Vector3(0.36, 1.78, 0.0), 0.16, fur)
	_ball(body_root, Vector3(0, 0.55, 0.36), 0.26, Color("#f1d9b5"), Vector3(1.0, 1.1, 0.5))

	# The face is a flat quad on the front of the head. Its texture gets swapped per emotion.
	var face := MeshInstance3D.new()
	face.name = "FaceQuad"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.75, 0.75)
	face.mesh = quad
	face.position = Vector3(0, 1.32, 0.505)
	body_root.add_child(face)

	var anchor := Marker3D.new()
	anchor.name = "HeadAnchor"
	anchor.position = Vector3(0, 2.05, 0)
	root.add_child(anchor)

	var ep := EmotionPlayer.new()
	ep.name = "EmotionPlayer"
	ep.face_mesh = face
	ep.head_anchor = anchor
	ep.body_root = body_root
	root.add_child(ep)

	var blips := TalkBlips.new()
	blips.name = "TalkBlips"
	blips.position = Vector3(0, 1.4, 0.3)
	blips.base_pitch = 1.0
	root.add_child(blips)

	root.emotion_player = ep
	root.talk_blips = blips
	add_child(root)
	return root


func _build_tester_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var flow := HFlowContainer.new()
	layer.add_child(flow)
	flow.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 12)

	var label := Label.new()
	label.text = "Test an emotion:"
	flow.add_child(label)
	for id in EMOTIONS:
		var b := Button.new()
		b.text = id
		b.pressed.connect(func() -> void: _bear.react(StringName(id), 2.5))
		flow.add_child(b)

	_talk_button = Button.new()
	_talk_button.text = "Talk to Stitches again"
	_talk_button.visible = false
	_talk_button.pressed.connect(func() -> void:
		_talk_button.visible = false
		_runner.start())
	flow.add_child(_talk_button)
