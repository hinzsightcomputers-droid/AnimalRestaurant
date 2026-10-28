# Emotion + dialogue starter (Godot 4, 3D)

Animal Crossing style reactions: each emotion is a **face** (texture swap), a **head icon**
(sparkles, "!", "?", rain cloud...), a **sound**, and a small **body animation**.
Dialogue lines and player choices decide which one plays.

## Try it right now

1. Open this folder as a project in Godot 4.2 or newer (Import, pick `project.godot`).
2. Press F5. A placeholder bear appears with a row of test buttons and a conversation.
   The emotions already work (faces, icons, animations). Sounds stay silent until you add some.

## Why texture swap (and not blend shapes)

* Works on **any** model, including free ones. Blend shapes need shape keys modelled per emotion,
  and most free bears have none.
* The face is just a quad in front of the head, so you can redraw all 12 faces in any paint program.
* It's the same trick Animal Crossing uses. Blend shapes are better for realistic lip-sync, which you don't need.

## Using it with your own bear

Scene layout (Stitches is the example):

```
Stitches            (Node3D, script: dialogue_character.gd)
├─ Body             (Node3D, pivot at the feet. Put the bear model under it)
│   └─ FaceQuad     (MeshInstance3D, QuadMesh ~0.7 x 0.7, sitting on the front of the face)
├─ HeadAnchor       (Marker3D, a little above the head: icons appear here)
├─ EmotionPlayer    (Node3D, script: emotion_player.gd)
└─ TalkBlips        (Node3D, script: talk_blips.gd, placed near the head)
```

Then in the inspector:

* **Stitches**: set `character_id` (`stitches`), `display_name`, and drag in EmotionPlayer and TalkBlips.
* **EmotionPlayer**: drag in `face_mesh` (FaceQuad), `head_anchor` (HeadAnchor), `body_root` (Body).
* If the bear is **rigged/animated**, make FaceQuad follow the head with a `BoneAttachment3D` on the head bone.

Trigger a reaction from your own code any time:

```gdscript
$Stitches.react(&"angry")          # returns to neutral after a couple of seconds
$Stitches.react(&"sad", 0.0)       # stays until the next emotion
```

To run a conversation, add a `DialogueRunner` node (or `DialogueRunner.new()`) and call `start()`.
Characters are found by `character_id`, so put one `DialogueCharacter` per speaker in the scene.

## Adding sounds

Drop files into `emotion_system/audio/<emotion>/` (e.g. `audio/happy/giggle.wav`). Add several per
emotion and one is picked at random with a little pitch variation. No code changes needed.
Talking babble blips go in `emotion_system/audio/blips/`. Use a different `base_pitch` on each
character's TalkBlips so they sound different.

## Replacing the art

* **Faces**: edit `emotion_system/face_atlas.png`. It's a 4 x 3 grid of 256 px cells, numbered left to right, top to bottom:
  `0 neutral, 1 happy, 2 joyful, 3 excited, 4 surprised, 5 sad, 6 angry, 7 nervous, 8 confused, 9 tired, 10 shy, 11 blink`.
* **Head icons**: replace the PNGs in `emotion_system/effects/` (same file names).

## Changing or adding emotions

Edit `PRESETS` in `emotion_library.gd`. Each entry has a face cell, icon style
(`none`, `float_up`, `burst`, `drop`, `pop`), icon count and body animation
(`none`, `hop`, `nod`, `shake`, `droop`, `wobble`, `recoil`). Add a matching `effects/<name>.png`
and `audio/<name>/` folder and it works.

## Writing dialogue (JSON)

See `dialogue/sample_dialogue.json`. In short:

```json
{
  "start": "greeting",
  "nodes": {
    "greeting": {
      "speaker": "stitches",
      "lines": [
        { "text": "I made pancakes!", "emotion": "excited" }
      ],
      "choices": [
        { "text": "Yes please!", "next": "yes",
          "reactions": { "stitches": "joyful" },
          "set": { "accepted_pancakes": true } },
        { "text": "No thanks.", "next": "no",
          "reactions": { "stitches": "sad" } }
      ]
    }
  }
}
```

* Each **line** has `text` (supports `[b]bbcode[/b]`), `emotion`, and an optional `speaker` override.
* Each **choice** has `next` (a node id, or `""` to end), `reactions` (how each character feels about what you said,
  shown right away), and optional `set` flags. Read flags later with `runner.flags["accepted_pancakes"]`.
* A node with no choices can continue with `"next": "other_node"`.
* Signals on `DialogueRunner`: `dialogue_started`, `line_shown`, `choice_made`, `dialogue_finished`.

## Files

| File | What it does |
|---|---|
| `emotion_player.gd` | Plays an emotion: face, icons, sound, body animation, blinking |
| `emotion_library.gd` | The emotion table (edit `PRESETS`), auto-loads sounds and icons |
| `emotion_data.gd` | The data for one emotion |
| `head_effect.gd` | The little icon that pops around the head |
| `talk_blips.gd` | Animal Crossing style talking blips |
| `dialogue_character.gd` | Put on each talking character |
| `dialogue_runner.gd` | Text box, typewriter, choices, reactions |
| `demo_scene.gd` / `demo.tscn` | Placeholder bear + tester buttons. Delete when you don't need them |

The placeholder faces and icons are original and free for you to use or replace.
