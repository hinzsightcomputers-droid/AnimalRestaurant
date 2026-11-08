# Chef character asset spec

How to make hair, clothes, accessories, face parts and (later) a real base body for the player chefs, so they drop into the game with no code changes.

Everyone shares **one skeleton** and **one base body**. Any item works on any chef. The code that puts a chef together is `ChefBuilder`. The face is `ChefFace` (`assets/shaders/chef_face.gdshader`).

---

## 1. The skeleton (locked)

The shared skeleton is **KayKit Rig_Medium**, the rig behind the KayKit Adventurers characters and the KayKit Character Animations. All the chef's animations (idle, walk, run and the carry pose) are made for it.

**These bone names are locked.** Rig every item and the base body to them, with exactly these names (case and dots included) and the same parent chain:

```
root
└── hips
    ├── spine
    │   └── chest
    │       ├── head
    │       ├── upperarm.l ── lowerarm.l ── wrist.l ── hand.l ── handslot.l
    │       └── upperarm.r ── lowerarm.r ── wrist.r ── hand.r ── handslot.r
    ├── upperleg.l ── lowerleg.l ── foot.l ── toes.l
    └── upperleg.r ── lowerleg.r ── foot.r ── toes.r
```

- `.l` is the character's **left** (+X in Godot as they face +Z), `.r` their right.
- The armature object is named `Rig_Medium` and its skeleton `Skeleton3D` once imported (`Rig_Medium/Skeleton3D`). The carry pose and animations address bones by that path.
- Rest pose: **T-pose**, facing +Z (Blender: -Y forward, Z up; the glTF exporter converts it). The character is about **2.27 units tall** as modeled, feet at 0. The game scales the whole chef down to 1.5 m, so model at KayKit scale, not real-world scale.
- Rest-pose bone positions (Godot, model space) for lining things up:
  - `hips` (0, 0.41, 0)
  - `chest` (0, 0.97, 0)
  - `head` (0, 1.24, 0)
- `handslot.l/.r` are for held things. Don't skin to them.
- Never rename, add or remove bones in an item file. An item may carry the whole armature (easiest) or just the bones it uses, but the names must match.

The reference rig is in `design/assets/KayKit_Adventurers_2.0_FREE/Characters/gltf/` (any of the five characters). Import one into Blender to fit to.

---

## 2. Body regions (for hiding)

The base body is split into regions. An item lists the regions it covers in its `hides`, and those parts of the base body are hidden while it's worn, so skin can't poke through.

| Region | Covers |
|---|---|
| `torso` | chest, belly, back, hips |
| `arm_left` | left upper arm to hand |
| `arm_right` | right upper arm to hand |
| `leg_left` | left thigh to ankle |
| `leg_right` | right thigh to ankle |
| `feet` | both feet |

The head is never hidden. Hats and hair sit on it.

**A real base body** should be one mesh object per region, named so `data/appearance.json` → `base_body.regions` can list them, e.g. `Body_Torso`, `Body_ArmLeft`, `Body_ArmRight`, `Body_LegLeft`, `Body_LegRight`, `Body_Feet`, plus `Body_Head`. Split along clothing lines (at the neck, shoulders, wrists, waist and ankles) so a hidden region leaves no gaps under the clothes that cover it.

The current base body is a placeholder: KayKit's Barbarian body, skin colored, with an ellipsoid stand-in head.

---

## 3. Skin and hair color

Skin and hair are tinted in the shader (`assets/shaders/tint.gdshader`), so **one texture works for every color**:

- Paint skin and hair textures in **greyscale**. White = the chef's full chosen color, darker = shadow or detail. Only the red channel is read.
- No texture is fine too. It's then a flat color.
- Hair meshes get the hair tint automatically (any item with `"slot": "hair"`).
- Clothes keep their own textures (not tinted).

---

## 4. The face

The face is drawn by one shader on a **face canvas**: a square that is `0..1` across (u, left to right as you look at the chef) and `0..1` down (v, top to bottom).

### On the head

- **A real head** gets a material slot (surface) named **`Face`**, UV-unwrapped so the face area fills the `0..1` square with the layout below. In practice, project from the front view and fit to bounds.
  - The game draws skin on that surface and the face over it.
  - Everything else on the head mesh is skin.
  - Then name the head mesh in `base_body.head.mesh` in `data/appearance.json`. No code changes are needed.
- **For now**, the stand-in head carries a **face plate**: a thin patch over its front, with UVs laid out the same way.

### Canvas layout

The canvas is 512 px square. Part centres and sizes are fractions of the canvas, and they're set in `data/appearance.json` → `face.layout`:

| Part | Center (u, v) | Size | Notes |
|---|---|---|---|
| eyes | (0.5, 0.52) | 0.20 | drawn twice, 0.15 either side of center |
| brows | (0.5, 0.39) | 0.18 | drawn twice, 0.16 either side |
| nose | (0.5, 0.62) | 0.13 | |
| mouth | (0.5, 0.73) | 0.22 | |
| face paint | whole canvas | 1.0 | |

```
 v=0  ┌──────────────────────────┐
      │                          │
 0.39 │     ~~~        ~~~       │  brows
 0.52 │    (o)          (o)      │  eyes
 0.62 │           .              │  nose
 0.73 │          \_/             │  mouth
      │                          │
 v=1  └──────────────────────────┘
      u=0         0.5         u=1
```

Each chef can move their parts up and down, move eyes and brows further apart, and resize them (Mii-style). Those moves are stored as offsets and a scale on top of this layout.

### Face part textures

Every eye, brow, nose and mouth texture is **128 × 128 px**, PNG with alpha, with the part centered. Face paint is **256 × 256** (or 512 × 512) and covers the whole canvas, so paint it where it belongs on the face.

| Part | How it's colored |
|---|---|
| **Eyes** | **Channel-coded**:<br>- **R** = ink (outline, pupil)<br>- **G** = iris (tinted with the chef's eye color)<br>- **B** = highlight (white)<br>- anything else = white of the eye<br>- **A** = where the eye is<br><br>Draw **one eye: the chef's right eye** (on the left as you look at them). The game mirrors it for the other side. |
| **Brows** | White shape with alpha, tinted with the hair color. Draw the chef's right brow, which gets mirrored too. |
| **Nose, mouth, face paint** | Normal colors with alpha, drawn as they are. |

### Expressions and blinking

These are eye and mouth textures that stand in for the chef's own for a moment:
- Shared defaults are in `face.expressions`: `blink` (eyes), and `happy`, `surprised` and `sad` (eyes and mouth).
- A face part can have its own instead. Add `"happy_eyes": "res://…"` (or `blink_eyes`, `sad_mouth` and so on) to that part's entry.

### File names and listing

- Put the files in `assets/face/` and name them `<part>_<id>.png`, for example `eyes_round.png`, `mouth_grin.png`, `paint_blush.png`.
- List each one in `data/appearance.json` → `face.parts.<part>` with an `id`, `name` and `texture`.

---

## 5. Wardrobe items

There's one JSON file per item in `data/wardrobe/` (see `_template.json`; files starting with `_` are skipped).

```json
{
	"id": "striped_shirt",
	"name": "Striped Shirt",
	"slot": "top",
	"mesh": { "scene": "res://assets/wardrobe/tops/striped_shirt.glb" },
	"hides": ["torso", "arm_left", "arm_right"]
}
```

| Field | |
|---|---|
| `slot` | `hair`, `top`, `bottom`, `dress`, `shoes`, `hat`, `glasses`, `face_accessory`. A dress replaces the top and bottom. |
| `mesh` | `scene`: the .glb. `nodes`: which meshes in it to use (leave out to use them all). The meshes must be **skinned** to the shared skeleton. |
| `parts` | Instead of a mesh: simple shapes held by a bone. See `Wardrobe`. Mostly for placeholders. |
| `hides` | Body regions it covers. |
| `hat_variant` | Hair only: the id of a flatter version to wear under hats (usually with `"hidden": true` so it isn't offered on its own). Without one, the hair stays as is under a hat. |
| `unlock` | Only wearable once the game unlocks it (e.g. a reward). |
| `hidden` | Not offered in the customizer. |
| `placeholder` | `true` for stand-in art waiting to be replaced. Every current item has it. Search `"placeholder": true` to find them all. |

**Accessories that don't bend** (glasses, earrings, hats that don't need skinning) can still be skinned. Weight them 100% to `head`.

**File layout and names:**
- `assets/wardrobe/<slot>s/<id>.glb`, e.g. `assets/wardrobe/tops/striped_shirt.glb`, `assets/wardrobe/hair/curly.glb` and `assets/wardrobe/hair/curly_hat.glb`.
- Use snake_case ids, the same as the file name. Mesh objects get `<Id>_<Part>` names, e.g. `StripedShirt_Body` and `StripedShirt_ArmLeft`.

---

## 6. Fitting a Meshy clothing item to the shared skeleton

Meshy gives you a mesh with its own (or no) rig. Here's how to put it on ours:

1. **Import the reference.** In Blender, import `design/assets/KayKit_Adventurers_2.0_FREE/Characters/gltf/Barbarian.glb` (or the real base body once it exists). This gives you the `Rig_Medium` armature and a body to fit to. Leave the rig in rest pose (Pose Position → Rest Position).
2. **Import the Meshy item.** Delete any armature and vertex groups it came with. Keep only the clothing mesh, and apply its transforms (Ctrl+A → All Transforms).
3. **Fit it.** Scale, move and sculpt the item over the base body in T-pose until it sits just outside the skin everywhere (about 0.01–0.02 units). Shrinkwrap (with an offset) or the sculpt Grab brush help at the shoulders, armpits and waist. Leave a little room at the joints.
4. **Clean up.** Decimate if it's heavy (aim under about 3k triangles per item). Recalculate normals. Make sure there's a single UV map, and bake or keep its texture as one image.
5. **Skin it.**
   1. Select the item, then shift-select `Rig_Medium`.
   2. Use Ctrl+P → **With Automatic Weights**.
   3. Or, more reliably: copy weights from the body with Data Transfer (Vertex Data → Vertex Groups, Nearest Face Interpolated) and then parent With Empty Groups.
   4. Check the vertex groups are named exactly like the bones.
6. **Test the bend.** Pose the arms and legs (or play a KayKit walk) and fix any spikes with Weight Paint. Shoulders and hips need the most care. Then go back to rest pose.
7. **Name things.** Mesh object `StripedShirt_Body` and so on. Keep the armature named `Rig_Medium`.
8. **Export.** File → Export → glTF 2.0 (.glb):
   - Include: Selected Objects (the item **and** `Rig_Medium`).
   - Mesh: Apply Modifiers on. Use **+Y Up** on (the default).
   - Armature: export Deformation Bones Only **off** (keep all bone names). No animations (uncheck Animation).
   - Save to `assets/wardrobe/<slot>s/<id>.glb`.
9. **Add the item file.** Create `data/wardrobe/<id>.json` with the slot, the mesh (and `nodes` if the .glb holds more than the item) and `hides`. Open the game, then use the debug panel (F3) → **Look: P1** to try it on.

**Hair:**
- Make it the same way, weighted almost entirely to `head`.
- Make a second, flatter version for under hats (nothing above the hat band) and point `hat_variant` at it.
- Use a greyscale texture so hair color works.

**A hat:** sit it on the base head, weight it to `head`, and use `"slot": "hat"`. Hair switches to its hat version automatically.

---

## 7. Checklist before handing an item over

- [ ] Rigged to `Rig_Medium` with the locked bone names, rest pose T-pose facing +Z
- [ ] KayKit scale (about 2.27 units tall), feet at 0, transforms applied
- [ ] Bends cleanly in walk and carry poses, and nothing pokes through
- [ ] `hides` lists every region it covers
- [ ] Hair: greyscale texture, plus a `hat_variant`
- [ ] Face parts: 128 px, centered, eyes channel-coded, right side only for eyes and brows
- [ ] File names match ids. Remove `"placeholder"` once it's the real thing
