# Store screenshots

`first_pass/`: 13 candidates at 1920x1080 (2026-11-28), taken by the week bot
on a copy of the day-8 save: the room from above, across the dining room, the
fireplace, the kitchen, evening and night, and seven cooking close-ups (no HUD,
just the close-up's own screen). Frozen with PhotoMode, so no prompts or icons.

Not final: many townsfolk are still placeholder shapes (no 3D models yet), so
retake these once they have models (and after the Meshy outside pieces are in).

## Taking more

- In the game: **F10** photo mode (frozen, no UI, free camera: WASD move, Q/E
  turn, R/F tilt, wheel or Z/X zoom, right-drag orbit, Shift faster, H hides the
  help line), **F12** saves a PNG to the user folder's `screenshots`.
- A whole set by itself (about 40 minutes): copy a save into
  `WEEK_BOT_DIR/state`, then
  `GODOT_ARGS="--resolution 1920x1080" tools/week_bot/run_day.sh <day after the save's> --photos`.
  Pictures land in `WEEK_BOT_DIR/out/dN_photo_*.png` (see tools/week_bot/README.md).
  The angles are `PHOTO_ANGLES` in tools/week_bot/bot_week.gd; tools/photo_mode_check
  pictures each one in about a minute.
