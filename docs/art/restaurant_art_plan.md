# Restaurant art: replacing the free packs (2026-11-20)

Goal: no KayKit or Ultimate Food Pack art left in the restaurant. Gameplay,
layout and station spots stay the same; only the look changes.

## How each kind of thing gets made

| What | Made as | Why |
|---|---|---|
| Floor, walls, wainscot, trim, counter tops, cabinet fronts, outside brick | Tileable textures (ChatGPT), Claude builds the simple shapes in Godot | Flat surfaces repeat across the room; a texture tiles cleanly at any room size (the stages grow the room) |
| Windows, doors, appliances, tools, crates, dining furniture | Meshy models (same pipeline as decor) | Real objects with shape |
| Food | Meshy models, small and low-poly | Lots of small items; cooked/burnt looks done in the game |

Counter runs are built in Godot (box + cabinet-front texture + counter-top
texture) so they line up at any length; Meshy appliances (stove, sink,
griddle) sit into them.

## Batch 1: room textures (ChatGPT only, no Meshy credits) (done 2026-11-20)
floor_dining, floor_kitchen, wall_plaster, wainscot, wall_trim, counter_top,
cabinet_front, brick_outside. Pictures go in Desktop/Asset photos/textures/
named exactly as above.

## Batch 2: windows and doors (Meshy)
window_curtains, kitchen_door, front_door. Models and pictures live in
design/restaurant/ (sizes in parts.json; `node tools/meshy/make_decor.js --restaurant`).
Done 2026-11-20: window_curtains (every window, room side) and kitchen_door
(the back door). front_door skipped for now: the entrance stays an open gap.

## Batch 3: kitchen appliances and tools (Meshy)
stove, oven, fridge, sink, griddle, dish_rack, cutting_board, soup_pot,
frying_pan, rolling_pin, crates (carrots, potatoes, lettuce, cheese, ham,
dough), barrel, storage_box

## Batch 4: dining room (Meshy)
dining_table, dining_chair, plate, plate_dirty, bowl, bowl_dirty,
standing_lamp, picture_frame, rug

## Batch 5: food (Meshy)
pancake, pancake_stack, fried_egg, bread_loaf, bread_slice, croissant,
cupcake, donuts (3), fish, salmon_sashimi, soup, stew, stew_bowl,
ice_cream_bowl, chopped carrot / potato / lettuce, grated cheese, dough,
dinner plate. (Claude checks each recipe's raw/cooked/burnt states first.)

Outside (street, buildings, trees) waits for the woodland redesign.
