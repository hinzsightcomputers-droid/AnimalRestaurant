#!/bin/bash
# Then-and-now clips: every cooking minigame as a one-dish reel, recorded in an
# old copy of the game (then) and in this one (now), saved as MP4s in
# Videos/Dinner Time Reels/Then and now. From the project folder:
#   git worktree add ../animal-restaurant-old c22d278 --detach   (the day before the toon style)
#   OLD=../animal-restaurant-old bash reels/then_and_now.sh
#   git worktree remove ../animal-restaurant-old
# RECIPES="pancakes soup" does just those. Reels first worked on Nov 5, so
# nothing older can play itself.
godot="${GODOT:-/c/Users/alexw/Desktop/Godot_v4.7.2-stable_win64.exe}"
OLD="$(cd "${OLD:?set OLD to the old copy of the game}" && pwd)"
ffmpeg="$LOCALAPPDATA/DinnerTimeTools/ffmpeg.exe"
out="$USERPROFILE/Videos/Dinner Time Reels/Then and now"
mkdir -p "$out"
declare -A station=( [cherry_pie]=oven [pork_dumplings]=oven [croissant]=oven [soft_pretzel]=oven [egg_tarts]=oven [apple_strudel]=oven [acorn_cookies]=oven [mochi]=microwave [chopping]=board [filleting]=board [clear_table]=table [wipe_table]=table [wash_dishes]=sink )
recipes="${RECIPES:-pancakes big_breakfast omurice soup four_cheese_mac fire_noodles hotteok churros cloud_foam_salad fish_stew cherry_pie pork_dumplings croissant soft_pretzel egg_tarts apple_strudel acorn_cookies mochi chopping filleting clear_table wipe_table wash_dishes}"
for r in $recipes; do
	st="${station[$r]:-stove}"
	fov=40; [ "$st" = table ] && fov=45; [ "$st" = sink ] && fov=70
	extra=""; [ "$st" = table ] && extra=', "table": "kitchen"'
	json="{ \"title\": \"$r\", \"meal\": \"lunch\", \"regular\": { \"id\": \"cheddar\", \"relationship\": 40, \"first_visit\": false }, \"beats\": [ { \"do\": \"cook\", \"recipe\": \"$r\", \"station\": \"$st\"$extra, \"speed\": 1.0, \"fov\": $fov }, { \"do\": \"wait\", \"seconds\": 1.5 }, { \"do\": \"end\" } ] }"
	for era in then now; do
		tree="$PWD"; [ $era = then ] && tree="$OLD"
		echo "$json" > "$tree/reels/clip_$r.json"
		avi="$out/${era}_$r.avi"
		(cd "$tree" && timeout 600 "$godot" --path . --write-movie "$avi" --fixed-fps 30 res://reels/reel_player.tscn -- --scenario="clip_$r" > "$out/${era}_$r.log" 2>&1)
		rm -f "$tree/reels/clip_$r.json"
		if [ -s "$avi" ]; then
			"$ffmpeg" -y -loglevel error -i "$avi" -c:v libx264 -crf 18 -preset medium -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart "$out/${era}_$r.mp4" && rm -f "$avi"
		fi
		echo "$era $r $(ls -la "$out/${era}_$r.mp4" 2>/dev/null | awk '{print $5}')"
	done
done
echo ALL DONE
