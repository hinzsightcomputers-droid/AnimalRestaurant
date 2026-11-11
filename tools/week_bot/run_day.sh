#!/bin/bash
# Usage: tools/week_bot/run_day.sh <day> [bot args, e.g. --seconds=1800 --after=180]
# Plays one day of the TEST week. The game runs with APPDATA pointed at a
# folder of its own, so its user:// (save, accounts, settings) is a separate
# test folder: the real save is never opened or written, even if the run is
# killed. The test week's save is kept in $WEEK_BOT_DIR/state between days
# (missing = a blank first launch). The real save is still backed up fresh
# first and checked unchanged afterwards.
#
# Settings (environment variables):
#   GODOT         the Godot exe (default: the one on the Desktop)
#   WEEK_BOT_DIR  where the test save, logs and screenshots go
#                 (default: $TEMP/dinner-time-week-bot)
#   DAY_TIMEOUT   most real seconds for the day (default 2400)
set -u
DAY="${1:?usage: run_day.sh <day> [bot args]}"
shift
cd "$(dirname "$0")/../.." || exit 1
GODOT="${GODOT:-/c/Users/alexw/Desktop/Godot_v4.7.2-stable_win64.exe}"
DIR="${WEEK_BOT_DIR:-$TEMP/dinner-time-week-bot}"
DIR="$(cygpath -u "$DIR")"
REAL="$(cygpath -u "$APPDATA")/Godot/app_userdata/AnimalRestaurant"
FAKE="$DIR/fake_appdata"
TU="$FAKE/Godot/app_userdata/AnimalRestaurant"
STATE="$DIR/state"
OUT="$DIR/out"
BACKUP="$DIR/real_save_backup"
mkdir -p "$OUT"

# A fresh backup of the real save, right now (never an old one).
rm -rf "$BACKUP" && mkdir -p "$BACKUP" || exit 1
if [ -e "$REAL/save.json" ]; then
	cp "$REAL"/*.json "$BACKUP"/ || { echo "backup failed, not running"; exit 1; }
fi

# The test's own user folder: the week so far, or nothing for a first day.
rm -rf "$TU" && mkdir -p "$TU"
if [ -d "$STATE" ]; then cp "$STATE"/*.json "$TU"/ 2>/dev/null; fi

APPDATA="$(cygpath -w "$FAKE")" WEEK_BOT_OUT="$(cygpath -m "$OUT")" timeout "${DAY_TIMEOUT:-2400}" \
	"$GODOT" --path . res://tools/week_bot/bot_week.tscn -- --day="$DAY" "$@" > "$OUT/d${DAY}_raw.txt" 2>&1
echo "day $DAY: godot exited with $?"

if [ -e "$TU/save.json" ]; then
	rm -rf "$STATE.new" && mkdir -p "$STATE.new" && cp "$TU"/*.json "$STATE.new"/ && rm -rf "$STATE" && mv "$STATE.new" "$STATE"
	cp -r "$STATE" "$DIR/state_after_day$DAY"  # So a day can be replayed from here.
fi
grep -h "END OF RUN\|OUT OF TIME" "$OUT/d${DAY}_log.txt" 2>/dev/null | cut -c1-220

for f in "$BACKUP"/*.json; do
	[ -e "$f" ] || continue
	if ! cmp -s "$f" "$REAL/$(basename "$f")"; then
		# The bot can't write there (its APPDATA is elsewhere), so this is
		# someone playing the real game meanwhile, or a bug in this script.
		echo "!!! The real save changed during the run ($(basename "$f")). Fine if someone was playing; the copy from before is in $BACKUP"
		exit 2
	fi
done
echo "[real save untouched: verified identical]"
