# Reels

Short vertical videos of the game, played from a script. Each file here is one
reel. A reel never reads or writes the real save, accounts or settings: its
state lives in memory and is gone when it closes (see `ReelSandbox`).

## Checking a scenario

    godot --path . --headless res://reels/reel_player.tscn -- --scenario=stitches_patches

It lists anything wrong with the file, or a summary of what it set up.

## The format

- `title`: a name for it.
- `meal`: `breakfast`, `lunch` or `dinner` (`data/day.json`).
- `lighting`: which meal's lighting to use. Leave it out to use the meal's own.
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
  - `line`: they say the line with this `line` id (from their character file).
  - `choices`: shows the line's replies. `highlight` is a list of
    `{ "tone", "hold" }` the cursor stops on (`hold` in seconds), then it moves
    to `pick` and picks it. Tones are `warm`, `playful`, `straight` and `rude`.
  - `reaction`: their reply to the choice. `emotion` replaces the one in their
    character file.
  - `serve`: a chef brings `dish`, skipping the cooking, at `quality` (0 to 1).
  - `wait`: nothing happens for `seconds`.
  - `end`: stops. Has to be the last beat.

Tables are `corner`, `window`, `middle` and `kitchen`.
