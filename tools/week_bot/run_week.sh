#!/bin/bash
# Usage: tools/week_bot/run_week.sh [first day] [last day] [--fresh] [bot args]
#   run_week.sh 1 7 --fresh   a new test save, days 1 to 7
#   run_week.sh 4 7           days 4 to 7, carrying on from the saved test week
# Then: node tools/week_bot/report.js  (writes report.md next to the logs).
# Same settings as run_day.sh. Stops if a day goes wrong.
set -u
FIRST="${1:-1}"
LAST="${2:-7}"
shift $(( $# < 2 ? $# : 2 ))
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$(cygpath -u "${WEEK_BOT_DIR:-$TEMP/dinner-time-week-bot}")"
if [ "${1:-}" = "--fresh" ]; then
	shift
	rm -rf "$DIR/state" "$DIR"/state_after_day* "$DIR/out"
	echo "fresh test save"
elif [ "$FIRST" -gt 1 ]; then
	# Start from the save as it was after the day before, if there is one.
	if [ -d "$DIR/state_after_day$((FIRST - 1))" ]; then
		rm -rf "$DIR/state" && cp -r "$DIR/state_after_day$((FIRST - 1))" "$DIR/state"
	elif [ ! -d "$DIR/state" ]; then
		echo "no test save to carry on from: run days 1 to $((FIRST - 1)) first (or use --fresh from day 1)"
		exit 1
	fi
fi
[ $# -eq 0 ] && set -- --seconds=1800 --after=180
echo "=== week bot: days $FIRST to $LAST, started $(date +%H:%M)"
for d in $(seq "$FIRST" "$LAST"); do
	bash "$HERE/run_day.sh" "$d" "$@" || { echo "!!! stopping after day $d"; exit 1; }
	if ! grep -q "END OF RUN" "$DIR/out/d${d}_log.txt" 2>/dev/null; then
		echo "!!! day $d didn't finish (see $DIR/out/d${d}_raw.txt); stopping"
		exit 1
	fi
done
echo "=== done $(date +%H:%M)"
