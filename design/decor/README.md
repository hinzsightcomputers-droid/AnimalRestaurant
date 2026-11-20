# Decor drop-in folder

Every decoration made in Meshy goes here, named after its row in
`data/decor_catalogue/<theme>.json`:

- `<id>.png`: the ChatGPT concept picture (and `<id>_side.png`, `<id>_back.png`)
- `<id>.glb`: the Meshy model (download as GLB)

That's all. The next time the game starts, any row with a `<id>.glb` becomes a
real decoration: scaled to the row's width, height and depth, standing on the
floor (or hung on a wall), given the game's toon look, and sold in the shop
once the stars allow. Rows without a model stay hidden.

Check what's in and what's missing (and get a picture of every model in the
room): `godot --path . res://tools/decor_drop_check.tscn` (see the tool).

Prompts for the pictures: `docs/art/decor_concept_prompts.md`.
