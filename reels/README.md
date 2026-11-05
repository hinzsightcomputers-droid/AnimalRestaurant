# Reels

Short vertical videos of the game, played from a script. Each file here is one
reel. A reel never reads or writes the real save, accounts or settings: its
state lives in memory and is gone when it closes (see `ReelSandbox`).

## Checking a scenario

    godot --path . --headless res://reels/reel_player.tscn -- --scenario=stitches_patches --check

It lists anything wrong with the file, or a summary of what it set up.

## Watching one

    godot --path . res://reels/reel_player.tscn -- --scenario=stitches_patches

The window plays it through and closes by itself.

## The format

- `title`: a name for it.
- `meal`: `breakfast`, `lunch` or `dinner` (`data/day.json`).
- `lighting`: which meal's lighting to use. Leave it out to use the meal's own.
- `wide_seconds`: how long the opening shot of the room lasts. Optional, 2 by
  default. After it the camera follows the regular, moves in close at their
  table for `line`, and cuts to a wider shot for `serve`.
- `chef`, `restaurant`: the names used in lines. Optional.
- `regular`: who it's about.
  - `id`: their file in `data/characters/`.
  - `relationship`: their relationship number.
  - `stage`: optional. Checked against `relationship`, to catch a mismatch.
  - `first_visit`: true if they've never been in. Otherwise they've been in a
    few times and know the chef.
  - `memory`: any of their memory fields, e.g. `{ "rude_streak": 1 }`.
- `extras`: townsfolk already eating: `table`, `species` and `dish` each.
- `beats`: what happens, in order. Each has a `do`:
  - `walk_in`: the regular comes in and sits at `table`.
  - `line`: the chef comes over and they say the line with this `line` id (from
    their character file). If it has replies, `choices` has to come next.
    Otherwise `hold` is how long it stays up once typed, in seconds.
  - `choices`: shows the line's replies. After `read` seconds the highlight
    moves through `highlight`, a list of `{ "tone", "hold" }`, then to `pick`,
    stays there for `hold` seconds and picks it. Tones are `warm`, `playful`,
    `straight` and `rude`. `reaction` has to come next.
  - `reaction`: their reply to the choice. `emotion` replaces the one in their
    character file, and `hold` is how long it stays up once typed.
  - `serve`: cuts to the chef arriving with `dish`, skipping the cooking and the
    trip to the kitchen, at `quality` (0 to 1).
  - `wait`: nothing happens for `seconds`.
  - `end`: stops. Has to be the last beat.

Tables are `corner`, `window`, `middle` and `kitchen`.
