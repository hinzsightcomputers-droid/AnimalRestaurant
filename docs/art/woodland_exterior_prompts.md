# Woodland exterior prompts (ChatGPT image → Meshy) (2026-11-21)

Replaces the free-pack outside: KayKit City Builder street (buildings, road,
streetlight, hydrant, car) and Forest Nature Pack trees, bushes, rocks and
grass, used by the street outside the restaurant, the intro, the back garden,
the beach and the car-trip view. 22 models + 2 tileable textures. Townsfolk
house interiors are a later, separate batch.

Pictures go in Desktop/Asset photos/ named `<id>.png`.

## 1. Style sheet (once, at the start of each chat)

```
I'm making concept art for the outdoor world of a cozy 3D restaurant game:
animal townsfolk live in a little woodland village, and the restaurant sits on
its main path at the edge of the forest. Everything you draw for me in this
chat should follow this style:

- Chunky, soft, toy-like shapes with rounded edges, slightly exaggerated
  proportions (a little short and wide, like a miniature).
- Flat, warm colours with simple soft shading, no fine texture detail, no
  realistic bark or leaf detail, no tiny thin parts (they become 3D models).
- Colour palette: dark wood #502312, wood #71412C, warm wood #90523C, light
  wood #A97251, brick #9A3A1B, rust red #C2542A, orange #E07228, peach #FAA562,
  tan #E2AA7B, cream #FBD6A0, sage #94A189, moss #6A7156, dark olive #494433,
  lantern yellow #FFD15C, leaf green #8DBE3E. Mostly woods, mossy greens,
  creams and warm reds.
- Cozy storybook woodland feel: thatch, timber frames, round doors, mossy
  stone, lanterns, mushrooms. Friendly and inviting, never gritty or modern.

Every single-item picture after the style sheet must be ready to turn into a
3D model:
- The whole object, centred, nothing cut off, filling most of the image.
- Three-quarter view from the front and slightly above (unless I say otherwise).
- Plain pure white background, no ground, no shadow, no other objects, no text.
- Even, soft front lighting so every colour is clear.
- Solid, simple shapes; nothing thinner than a pencil at the size given:
  thick ropes, chunky fronds, no thin curls or wires.
- No grass, stones, mushrooms or ground under or around it; it stands on its
  own (except the fern clump and the flower patch, which are ground plants).

First, make one style sheet showing 9 different things in this style (a
cottage, a big tree, a pine tree, a bush, a mossy rock, a lantern post, a
well, a wooden cart, a fern clump) arranged in a grid on a plain off-white
background, so I can check the look before we do them one at a time.
```

## 2. One item per message

### Trees (each about 4-6 m tall)
- `wood_tree_oak`: "Now just one item: a big round oak tree, a short thick trunk and a wide puffy canopy made of a few big rounded leaf clumps. About 5 m tall and 4 m wide."
- `wood_tree_pine`: "Now just one item: a chunky pine tree, a short trunk and three stacked rounded cone tiers of dark green. About 6 m tall and 3 m wide."
- `wood_tree_birch`: "Now just one item: a slim birch tree, a cream trunk with a few dark bands, and two or three soft light-green leaf clumps. About 5 m tall and 2.5 m wide."
- `wood_tree_fruit`: "Now just one item: a small round apple tree, a curvy trunk and one big round canopy dotted with chunky red apples. About 4 m tall and 3.5 m wide."

### Bushes, rocks and ground plants
- `wood_bush_round`: "Now just one item: a round leafy bush made of three or four soft green clumps. About 1.2 m wide and 0.9 m tall."
- `wood_bush_berry`: "Now just one item: a low wide bush with a few chunky red berries. About 1.4 m wide and 0.8 m tall."
- `wood_bush_flower`: "Now just one item: a round bush covered in chunky cream and peach flowers. About 1 m wide and 0.9 m tall."
- `wood_rock_big`: "Now just one item: a big rounded boulder, grey-brown with a soft cap of moss on top. About 1.2 m wide and 0.8 m tall."
- `wood_rock_flat`: "Now just one item: a low flat stone slab with a little moss on one edge. About 1 m wide and 0.3 m tall."
- `wood_rock_pile`: "Now just one item: a small pile of three rounded stones, one with a tiny mushroom beside it. About 0.8 m wide and 0.5 m tall."
- `wood_fern`: "Now just one item: a chunky fern clump, five or six thick rounded fronds fanning out from the middle. About 0.8 m wide and 0.6 m tall."
- `wood_flower_patch`: "Now just one item: a small patch of wildflowers in a tuft of grass, chunky daisies and orange poppies. About 0.7 m wide and 0.4 m tall."

### Cottages (each about 4-5 m wide, 4-6 m tall, front door facing us)
- `wood_cottage_thatch`: "Now just one item: a cosy thatched cottage, cream plaster with dark timber frame, a thick rounded straw roof, a round green door and two little windows with flower boxes."
- `wood_cottage_mushroom`: "Now just one item: a house shaped like a giant mushroom, a cream stalk with a round door and windows, and a big red cap with cream spots as the roof."
- `wood_cottage_stump`: "Now just one item: a house built inside a huge tree stump, a round wooden door, two round windows, a little chimney and moss on top."
- `wood_cottage_stone`: "Now just one item: a small stone cottage of rounded mossy stones, a red tiled roof, a chimney and a wooden door with a lantern beside it."
- `wood_cottage_mill`: "Now just one item: a little timber watermill house with a big chunky wooden wheel on its side and a steep warm-wood roof."
- `wood_cottage_shop`: "Now just one item: a village shop cottage with a striped cream-and-rust awning over a big front window, a timber frame and a hanging wooden sign with no writing."

### Street things
- `wood_lantern_post`: "Now just one item: a wooden lantern post, a thick warm-wood post with a curved arm holding a glowing yellow lantern. About 2.5 m tall."
- `wood_well`: "Now just one item: a round stone well with a little wooden roof, a crank and a bucket. About 1.5 m wide and 2.2 m tall."
- `wood_mailbox`: "Now just one item: a chunky wooden mailbox on a post, shaped like a tiny house with a round red flag. About 1.2 m tall."

### Vehicle
- `wood_cart`: "Now just one item: a small wooden passenger cart with seats for two passengers, four chunky spoked wheels, a cream canvas cover and a lantern hanging at the front, no cargo and no animal pulling it (not a handcart or wheelbarrow). About 2.5 m long and 1.8 m tall. Seen from the side and slightly above."

## 3. Tileable ground textures (no Meshy)

```
Make a seamless, tileable square texture seen from straight above, in the same
style (flat warm colours, soft simple shading, no realistic detail):
[a packed dirt path, warm tan and light brown with a few small rounded pebbles
and tiny grass tufts at random]. It must tile with no visible seams on any
edge, fill the whole square with no border, and have no shadows, lighting
direction, objects or text.
```
- `dirt_path`: as written.
- `mossy_cobbles`: replace the brackets with "rounded grey-brown cobblestones with soft green moss in the gaps".

## 4. The regulars' houses (added 2026-11-26)

Same chat style sheet as above. Each house's front faces us, flat and plain
where the door and two windows go: the game puts its own door (it swings
open on visits), lit windows, porch, porch light and nameplate on the front.
So draw the front wall with **no door, no windows and no sign**, just the wall
itself, and everything else round it.

- `wood_house_mabel`: "Now just one item: an old cottage built of big rounded mossy stones, a thick sagging roof completely covered in soft green moss, a crooked stone chimney, and clay pots of plants along the sides. The front wall is plain flat stone with no door and no windows. Like a wise old tortoise has lived there a hundred years. About 4.4 m wide, 4 m deep and 4.6 m tall."
- `wood_house_stitches`: "Now just one item: a cozy log cabin of chunky round logs, a steep dark wood roof mended with a few colourful fabric patches, a stone chimney, and a patchwork quilt hung over a rail at one side. The front wall is plain flat logs with no door and no windows. About 4.4 m wide, 4 m deep and 4.4 m tall."
- `wood_house_cheddar`: "Now just one item: a painted wooden showbiz caravan on four chunky wheels, sunny yellow with a rust-red rounded roof and skirt, a gold star sign on the roof and a row of round marquee bulbs along the roof edge. The long front side faces us and is plain flat painted wood with no door and no windows. About 4.4 m long, 2.6 m deep and 3.8 m tall."

## 5. The restaurant's outside (added 2026-11-26)

Pieces to dress the restaurant's own walls (its walls themselves get a
tileable texture, below). Kept low or on the wall so they never block the
camera, which looks in over the front.

- `wood_rest_sign`: "Now just one item: a chunky carved wooden shop sign board with a rounded top edge, warm wood with a darker painted border, hanging from two short chains on a wooden bracket, with no writing on it. About 2.2 m wide and 0.8 m tall."
- `wood_rest_awning`: "Now just one item: a short scalloped fabric awning with chunky rust-red and cream stripes on a wooden frame, as if over a shop door. About 2.4 m wide, 1.2 m deep and 0.9 m tall."
- `wood_rest_lantern`: "Now just one item: a small wall lantern on a curly iron bracket, a warm glowing yellow glass box with a dark roof. About 0.6 m tall."
- `wood_rest_flower_box`: "Now just one item: a long wooden window flower box overflowing with chunky red, cream and peach flowers and trailing leaves. About 1.2 m wide and 0.45 m tall."
- `wood_rest_chimney`: "Now just one item: a tall chimney stack of rounded warm stones with a little cap on top. About 1 m wide and 3 m tall."
- `wood_rest_porch`: "Now just one item: a small open wooden porch roof on two thick posts, a little peaked shingle roof, like over a cottage's front door, with nothing under it. About 2.4 m wide, 1.6 m deep and 2.8 m tall."

Tileable texture (ChatGPT, section 3's prompt): `timber_plaster`, with the
brackets as "cream plaster wall with chunky dark timber beams in a simple
cottage frame pattern", to replace the brick outside walls.

## Status (2026-11-21)
All 22 pictures and both textures are in design/woodland/. Meshy ran out of
credits after wood_tree_oak and wood_tree_pine; the rest wait for the credit
reset (around 2026-12-05): `node tools/meshy/make_decor.js --woodland` makes
only the missing ones. Then swap the whole outdoors in one go.

**2026-11-26:** the outdoors is built with placeholders (WoodPiece): each model
shows by itself once its .glb is in design/woodland/. Sections 4 and 5 still
need their pictures made (`make_decor.js` skips anything without one).

## Tips
- The style sheet (2026-11-21) was approved: keep that look. It drew ground
  tufts under things and a one-wheel handcart; the rules above and the cart
  prompt now ask for neither.
- If a picture drifts from the style: "Closer to the style sheet: chunkier,
  flatter colours, fewer details."
- Start a new chat with the style sheet every ~20 items.
