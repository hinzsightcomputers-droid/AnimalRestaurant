# Reels

Short vertical videos of the game, played from a script. Each file here is one
reel. A reel never reads or writes the real save, accounts or settings: its
state lives in memory and is gone when it closes (see `ReelSandbox`).

## Checking a scenario

    godot --path . --headless res://reels/reel_player.tscn -- --scenario=stitches_patches --check

It lists anything wrong with the file, or a summary of what it set up.

## Watching one

    godot --path . res://reels/reel_player.tscn -- --scenario=stitches_patches

A small tall window plays it through and closes by itself. Don't press anything
while it plays: real key presses still reach the game.

You can also pick one in the debug panel (F3, under Reels): it opens in its own
window, a separate launch of the game, so the game you're in isn't touched.

From the editor, open `reels/reel_player.tscn` and press F6. Its `Preview
Scenario` field in the Inspector says which one to play (empty is the first).

## Recording one

    bash reels/record.sh stitches_patches

It takes about twice as long as the reel and saves to
`Videos/Dinner Time Reels`, outside the project. The size comes from the
`.movie` settings in `project.godot` (`--resolution` doesn't change it), which
only apply while recording. Godot writes an AVI; with `ffmpeg.exe` in
`%LOCALAPPDATA%/DinnerTimeTools` it's turned into an MP4.

## The format

- `title`: a name for it.
- `meal`: `breakfast`, `lunch` or `dinner` (`data/day.json`).
- `lighting`: which meal's lighting to use. Leave it out to use the meal's own.
- `wide_seconds`: how long the opening shot of the room lasts. Optional, 2 by
  default. After it the camera follows the regular, moves in close at their
  table for `line`, and cuts to a wider shot for `serve`.
- `hour`: the time of day outdoors, for the sky on a drive and the beach campfire:
  `early_morning`, `morning`, `midday`, `afternoon`, `evening` or `late_night`.
  Leave it out to use the real time.
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
    `straight` and `rude`. A reply with no tone is named by how its text starts,
    e.g. `"pick": "Knock knock"`, in `highlight` too. `reaction` has to come next.
  - `reaction`: their reply to the choice. `emotion` replaces the one in their
    character file, and `hold` is how long it stays up once typed. If the reply
    leads to a follow-up question, another `choices` and `reaction` come next,
    for as many as it goes on (see `cheddar_knock_knock.json`).
  - `serve`: cuts to the chef arriving with `dish`, skipping the cooking and the
    trip to the kitchen, at `quality` (0 to 1).
  - `drive`: opens on Cheddar's car out front for `wide_seconds`, then the drive to
    the beach (he has to be the regular), `seconds` long, then the chef on the
    beach. `lines` is a list of his line ids to say on the way; leave it out and
    they're picked at random.
  - `beach`: starts at the beach instead, the chef just out of the car.
  - `walk`: after `drive` or `beach`, the chef walks the beach through `to`, a list
    of `[x, z]` points. The sand runs from -14 to 14 across and from 4 at the road
    to -9.6 at the water, where the pier starts, at `[0, -9.6]`.
  - `fish`: after `drive` or `beach`, the chef walks to the end of the pier and
    fishes: casts, waits for the bite, reels in and holds up `fish` (an id from
    `data/fish.json`, a beach one). It takes about 15 seconds.
  - `wait`: nothing happens for `seconds`.
  - `end`: stops. Has to be the last beat.

Tables are `corner`, `window`, `middle` and `kitchen`.
