# Week bot

Plays the real game, a day per run, like a new player who follows the Guide's
arrow: opening, every meal, closing, the summary and shop, then a while of
after hours. Cooking close-ups play themselves (scripted input), so it cooks
perfectly and serves at once: its money is a ceiling, not what a new player
earns. It shops like a new player too: the Ticket Rail, then the cheapest new
dish or drink, a bit of decor and upgrades, until the money runs out.

It never touches the real save: the game runs with `APPDATA` pointed at a test
folder, and the real save is backed up first and checked unchanged after.

## Running it (Git Bash, from anywhere)

    tools/week_bot/run_week.sh 1 7 --fresh    # a new test save, days 1 to 7 (~12 min a day)
    tools/week_bot/run_week.sh 4 7            # days 4 to 7, carrying on from day 3's save
    tools/week_bot/run_day.sh 5 --seconds=1800 --after=180   # one day
    node tools/week_bot/report.js             # report.md: money, stars, shopping, repeats, trouble

Bot arguments: `--seconds=1800` (most game seconds for the day),
`--after=180` (game seconds of after hours), `--speed=2` (game speed).
Settings by environment variable: `GODOT` (the exe; default the Desktop one),
`WEEK_BOT_DIR` (default `%TEMP%\dinner-time-week-bot`), `DAY_TIMEOUT` (real
seconds per day, default 2400).

In `WEEK_BOT_DIR`: `out/` has each day's log (`d3_log.txt`), the raw Godot
output (`d3_raw.txt`), up to 12 screenshots a day and `report.md`; `state/` is
the test save; `state_after_dayN/` lets you replay from any day.

## When the game changes

The bot finds things by what the player sees, so a new screen or popup can
stop it. The log then shows `PAUSED with buttons [...]` or `STUCK?`. Add the
button's text to the lists in `intro_step()` (before the restaurant) or
`play_step()` (during the day) in `bot_week.gd`.

`tools/` should be left out of release builds (export filter `tools/*`).
