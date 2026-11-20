# Decor concept prompts (ChatGPT image → Meshy)

Concept pictures of decorations made in ChatGPT, then turned into models with
Meshy's image-to-3D. Meshy works best with one object per image, seen whole,
on a plain background, so a style sheet comes first (for the look), then one
picture per item.

## 1. Style sheet (once, at the start of each chat)

```
I'm making concept art for decorations in a cozy 3D restaurant game where
animal townsfolk eat at a little restaurant on the edge of a woodland village.
Everything you draw for me in this chat should follow this style:

- Chunky, soft, low-poly-friendly toy-like shapes with rounded edges, slightly
  exaggerated proportions (a little short and wide, like a miniature).
- Flat, warm colours with simple soft shading, no fine texture detail, no
  realistic wood grain, no tiny thin parts (they need to work as a 3D model).
- Colour palette: dark wood #502312, wood #71412C, warm wood #90523C, light
  wood #A97251, brick #9A3A1B, rust red #C2542A, orange #E07228, peach #FAA562,
  rose #DB7B60, tan #E2AA7B, cream #FBD6A0, sage #94A189, moss #6A7156,
  dark olive #494433, lantern yellow #FFD15C, leaf green #8DBE3E,
  gingham red #D63C3C. Mostly woods, creams and warm reds, with sage and leaf
  green as accents.
- Cozy, handmade, countryside-café feel (think wooden furniture, gingham,
  potted plants, lanterns), friendly and inviting, never gritty or modern.

First, make one style sheet showing 9 different decorations in this style
(a small table, a chair, a potted plant, a shelf with jars, a lamp, a framed
picture, a rug, a barrel, a flower box) arranged in a grid on a plain
off-white background, so I can check the look before we do them one at a time.
```

## 2. One item (repeat for each)

Replace the parts in [brackets].

```
Now draw just one item in the same style: [a wooden bookcase with three
shelves of colourful books and a small plant on top].
It's a [floor / wall] decoration about [1 m wide, 0.5 m deep, 1.8 m tall].
Theme: [cozy café / garden / seaside / autumn harvest / winter holidays].

For turning into a 3D model:
- The whole object, centred, nothing cut off, filling most of the image.
- Three-quarter view from the front and slightly above.
- Plain pure white background, no floor, no shadow on the ground, no other
  objects, no text or labels.
- Even, soft front lighting so every colour is clear.
- Solid, simple shapes; nothing thinner than a pencil.
```

## 3. Optional: front, side and back (for Meshy's multi-image)

```
Same item, shown three times side by side on a plain white background:
straight from the front, straight from the side, and straight from the back.
Same size and height in all three, nothing cut off, no shadows, no text.
```

## Tips

- If a picture drifts from the style, say: "Closer to the style sheet:
  chunkier, flatter colours, fewer details."
- Start a new chat with the style sheet every ~20 items; long chats drift.
- Save each picture with the item's id (e.g. `cafe_bookcase.png`) so it
  matches its row in the catalogue and its model file later.

## Cozy café: first batch

1. `cafe_bookcase`, `cafe_chalkboard_sign`, `cafe_wall_shelf` (done in chat)
2. `cafe_lemon_tree`, `cafe_coat_stand`, `cafe_flower_barrel`, `cafe_cottage_painting`,
   `cafe_pie_clock`, `cafe_wall_lantern`, `cafe_cake_table`, `cafe_gingham_rug`,
   `cafe_radio_table`, `cafe_flower_cart`, `cafe_bunting`, `cafe_pot_rack`,
   `cafe_armchair`, `cafe_log_basket`, `cafe_wheat_wreath`: prompts as given in
   chat on 2026-11-20 (same pattern as section 2).
