# Dinner Time: Art Style Guide

Built from your five concept images. Colors in the main palette were measured from the images. Colors marked **(by eye)** are small accent areas I picked out visually. Everything marked **(proposed)** is my suggestion, and **TBD** needs your decision.

## The one-sentence look

**A warm, golden-hour, cozy timber restaurant: chunky rounded shapes, soft glowing light, saturated appetizing food, and a little sparkle on everything you touch.**

## The seven rules (what makes it look like your concept)

1. **Warm light first.** Almost every image is lit by glowing lamps, lanterns, and fire. Amber light in, cool blue only as a small accent (a gas flame, water, a window).
2. **Chunky and rounded.** No sharp corners. Counters, chairs, pots, and tables have thick edges and soft bevels.
3. **Wood is the base material.** Dark beams, honey-colored floors and counters, with stainless steel and brick as supporting materials.
4. **Red-and-white gingham and warm rugs** carry the pattern. Keep everything else mostly solid color, so the patterns stand out.
5. **Plants everywhere.** Hanging ivy, potted leaves, and flower vases soften every scene and add the green.
6. **Food is the brightest thing on screen.** It is more saturated and glossy than the room around it, so the eye goes to it.
7. **Sparkles, steam, and glow mark what matters.** Four-point sparkles, stylized steam swirls, and emote bursts, used sparingly.

## Palette

### Main palette (measured)

| Role | Color | Where it shows up |
| --- | --- | --- |
| Dark wood | `#502312` | Beams, shadows, dark furniture |
| Wood | `#71412C` | Beams, chairs, counters |
| Warm wood | `#90523C` | Mid-tone wood |
| Light wood | `#A97251` | Floors, table tops |
| Brick and tomato | `#9A3A1B` | Oven brick, tomatoes, rugs |
| Rust red | `#C2542A` | Rugs, awnings, red details |
| Orange | `#E07228` | The penguin's feathers, flames, signage |
| Peach | `#FAA562` | Warm highlights, lamp glow |
| Rose | `#DB7B60` | Soft warm accents |
| Tan | `#E2AA7B` | Lit wood, plaster walls |
| Cream | `#FBD6A0` | Walls, plates, chef hats, UI panels |
| Sage | `#94A189` | Leaves, steel, soft shadows |
| Moss | `#6A7156` | Deeper foliage |
| Dark olive | `#494433` | Deep shadow, outlines |

### Accents (by eye, use small)

| Accent | Approx. | Use |
| --- | --- | --- |
| Cherry-blossom pink | `#F59BC4` | Windows and trees outside, flowers |
| Lantern yellow | `#FFD15C` | Lamp glow, sparkles |
| Gas-flame blue | `#4C8CFF` | Stove flames only |
| Water teal | `#3CB8D6` | Fishing pond |
| Leaf green | `#8DBE3E` | Fresh plants, ivy |
| Gingham red | `#D63C3C` | Tablecloths, awnings, the mouse's cap |

The palette is mostly warm and the room is lit from the warm side. Use the accents for contrast in small amounts only, because too much pink or blue will break the cozy mood.

## Lighting recipe (the cheapest big win)

This is the single biggest factor in why the concept looks the way it does, and it costs very little to copy.

- **Warm key light:** One soft directional light in a golden-orange tone, coming through the windows.
- **Pendant lamps and lanterns:** Warm point lights with a visible soft glow around the bulb. A few strong ones are better than many weak ones.
- **Fire glow:** The pizza oven and fireplace each get an orange flickering light.
- **Bloom (glow):** Turn on a gentle glow so lamps and sparkles bloom softly.
- **Soft ambient occlusion:** Darkens corners and under furniture so objects feel grounded.
- **Color grading:** Slightly warm, slightly saturated overall. Make food a little punchier than the room.
- **Performance note (proposed):** Split screen draws the scene once per player. Avoid heavy volumetric fog and dozens of real-time lights, and fake the rest with glowing materials and a few real lights.

## Shapes and materials

- **Silhouettes:** Thick, rounded, slightly oversized. Chairs have chunky legs, tables have round tops, pots are fat.
- **Surfaces:** Hand-painted look with soft gradients, no photo textures. Wood has gentle grain painted in, not realistic scans.
- **One shared material (proposed):** A soft toon-style shader with gentle shading steps, warm shadow tint, and an optional faint outline. Every asset uses it, which is what unifies assets from different sources.
- **Metal:** Stainless steel counters are soft gray-sage with rounded corners and a simple highlight, not mirror-shiny.
- **Windows:** Arched, wood-framed, with a glowing blossom-tree view outside. A pink-and-lavender sky at golden hour.

## Characters

- **Proportions:** Big heads, small chunky bodies, simple limbs. Faces carry the personality, so the eyes and mouths are the most expressive parts.
- **Texture styles in the concept differ:** Stitches reads as stitched fabric, the penguin as soft felt, and Mabel as a faceted low-poly shape. **Decided: every character uses one soft felt surface style, with a matte, slightly fuzzy, fabric-like finish and rounded edges. Mabel's faceted look from the concept is dropped so she matches the others**.
- **Costumes in the concept art:** The head chef wears a white chef hat, apron with a spoon-and-fork logo, and a red neckerchief. Stitches wears blue overalls, Cheddar a red-and-white cap and sunglasses (sometimes a red hoodie), Mabel round gold glasses, and Evaroo round black glasses. Keep these as separate swappable pieces.
- **The orange penguin chef:** **Decided: He is Zakk, a regular, not the player. The concept art shows him as the main chef, so don't treat that as the player's look. The player character still needs its own design (TBD), and it should not be an orange penguin**.
- **Expressions:** Closed-eye happy smiles, big open laughs, and sleepy half-lids. Reuse the same face set across characters where possible.

## Food

- **Stylized, not photoreal.** Thick, fluffy, glossy, a bit exaggerated: tall pancakes with berries and dripping syrup, a burger with a bright cheese slice, steak with bold grill marks.
- **Color:** The most saturated things in the scene. Tomato red, golden brown, bright greens.
- **Highlights:** A soft white shine on glossy surfaces (syrup, sauces, fruit).
- **Doneness shows through color,** not detail: raw is pale, perfect is golden, burnt is dark brown.
- **Steam:** Soft, curly, stylized swirls that fade, not realistic smoke.

## Minigame look (for the pancake target scene)

Taken from your concept's minigame panels:

- **Close-up on the station** with a warm blurred background of the kitchen.
- **Rainbow timing bar:** Red, orange, yellow, green, with a white marker. Used for chopping and timing.
- **Arc meter** curved over the pan for heat and cooking progress.
- **Round ingredient badges** on the side (milk, chocolate, whipped cream) that light up as you add them.
- **Circular timer ring** in a top corner.
- **Sparkles and a small flame icon** to show good heat or a perfect result.
- **Tools** (knife, sponge, bottle) are chunky and slightly oversized so they read in a quarter-screen.

## UI style

- **Panels:** Rounded cream and wood panels with a thin darker outline. Chalkboard menus use white line-art icons.
- **Dialogue:** A cream rounded box with a bold orange name tag pill (like the Stitches tag in your concept), a small down arrow to continue, and floating emotes (hearts, music notes, exclamation bursts).
- **Fonts (proposed):** A rounded, friendly display font for titles, like the carved sign lettering, and a very readable rounded sans for dialogue.
- **Logo:** The carved wooden "Dinner Time" sign with a chef hat, spoon and fork, and ivy.

## Outdoors (for later)

The concept shows a cottage with a striped awning, cherry-blossom trees, pines, an orange autumn tree, a waterfall, a fishing pond with a wooden dock and rope-wrapped posts, a plank bridge, lanterns, a jar of fireflies, and a dragonfly. Treat these as a **later-phase wish list**, not part of the first slice.

## Reality check: concept art vs. what you'll ship

These images are far more detailed than what a solo project will render in real time. Use them as a **north star**, not a spec. For the first slice, copy these five things and you'll be most of the way there:

1. Warm golden-hour lighting with glowing lamps
2. Chunky, rounded, soft-bevel shapes
3. The palette above
4. Gingham, wood, and plants as the main set dressing
5. Sparkles and steam on the food and minigame

Everything else (the waterfall, fireflies, fishing, detailed shelves of jars) comes later.

## Master prompt prefix

Paste this at the start of every Meshy or image-generator prompt, then add the object after it:

```
Cozy stylized 3D game asset, chunky rounded shapes with soft bevels, hand-painted look with soft gradients, warm golden-hour color palette of honey wood, cream, tomato red, and sage green, matte surface with gentle highlights, no sharp edges, no photorealism, no text, clean simple silhouette, centered on a plain background.
```

Then add the object, for example: *a round wooden dining table with a red-and-white gingham tablecloth*.

**Negative prompt:**

```
realistic, photorealistic, sharp edges, thin parts, dark moody lighting, cold blue tones, rusty, dirty, scary, text, logo, extra objects, complex ornament
```

## Prompt for tiling textures (floors and walls)

```
Seamless tileable texture, top-down flat view, hand-painted cozy style, [warm honey wood planks / red and white gingham / cream plaster with soft brush marks / terracotta floor tiles], soft color variation, warm golden palette, no perspective, no shadows, no objects, no text, stylized video game texture
```

## Message for Claude Code: set up the look

Send this once the pancake scene runs, so every later asset inherits the look:

```
Set up the shared visual style for the game in Godot 4. Use GDScript and Godot 4 only.

1. Create one reusable soft toon-style material (a ShaderMaterial in a shaders/ folder) with: a base color and optional texture, 2 to 3 soft shading steps, a warm tint in the shadows, and an optional thin outline. Expose the shading steps, shadow tint, and outline thickness as shader parameters.
2. Create a shared WorldEnvironment resource with: warm ambient light, glow (bloom) turned on gently, SSAO turned on softly, and a warm color adjustment. Keep volumetric fog off and keep it light enough for 4-player split screen.
3. Set up one warm directional light and a reusable pendant-lamp scene (a point light with a soft glowing bulb mesh).
4. Add a small helper that applies the shared material to any imported model, keeping each model's own base color or texture.
5. Apply it to the pancake minigame scene and to the character models, then tell me how to compare before and after. Do not change gameplay code.

Use these palette values as exported colors so I can tweak them in the editor: dark wood #502312, wood #71412C, light wood #A97251, brick #9A3A1B, orange #E07228, peach #FAA562, cream #FBD6A0, sage #94A189, moss #6A7156.

When done, tell me exactly how to test it and wait for me to try it. Commit when it works.
```

## Open decisions

1. What does the player character look like? Species, outfit, and colors, and not an orange penguin, since that's Zakk.
2. Should the chef hat and apron from the concept art be the player's starting outfit?
3. Should Mabel keep her gold glasses from the concept? Her sketch had none.
4. Is the game name "Dinner Time" final? It's a common phrase, so search Steam and trademark databases before building branding. I'm not a lawyer.
5. Which accent colors stay and which are cut for the first slice?

## Build order

1. Shared material, lighting, and environment (the Claude Code message above)
2. Pancake minigame scene: griddle, tools, food, and effects
3. Restaurant interior: floor, walls, tables, chairs, counters, stove, oven, fridge, and sink
4. Exterior and the fishing pond, last
