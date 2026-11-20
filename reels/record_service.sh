#!/bin/bash
# Records the "service" and "tidy" reels (the chef played like a person) and
# cuts each whole visit into its parts, from the MARK lines the reel prints.
# Saves to Videos/Dinner Time Reels/Service. From the project folder:
#   bash reels/record_service.sh                      every service_* and tidy_* reel
#   bash reels/record_service.sh service_stitches     just those
# Parts of a visit: 1 arrival (greeting and seating), 2 orders (drink, food and
# the ticket wheel), 3 cooking, 4 served (serving and the chat), 5 bill.
godot="${GODOT:-/c/Users/alexw/Desktop/Godot_v4.7.2-stable_win64.exe}"
ffmpeg="${FFMPEG:-$LOCALAPPDATA/DinnerTimeTools/ffmpeg.exe}"
fps=30
out="$USERPROFILE/Videos/Dinner Time Reels/Service"
mkdir -p "$out"
names="$*"
[ -z "$names" ] && names="$(cd reels && ls service_*.json tidy_*.json | sed 's/\.json$//')"
parts=("arrival:drink_order:1_arrival" "drink_order:cooking:2_orders" "cooking:serving:3_cooking" "serving:bill:4_served" "bill::5_bill")
for name in $names; do
	avi="$out/$name.avi"
	log="$out/$name.log"
	timeout 1200 "$godot" --path . --write-movie "$avi" --fixed-fps $fps res://reels/reel_player.tscn -- --scenario="$name" > "$log" 2>&1
	if grep -q "Reel stopped" "$log" || [ ! -s "$avi" ]; then
		echo "$name FAILED: $(grep -m1 'Reel stopped' "$log")"
		continue
	fi
	full="$out/$name.mp4"
	"$ffmpeg" -y -loglevel error -i "$avi" -c:v libx264 -crf 18 -preset medium -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart "$full" && rm -f "$avi"
	if [[ $name == service_* ]]; then
		who="${name#service_}"
		for part in "${parts[@]}"; do
			IFS=: read -r from to label <<< "$part"
			start=$(grep "^MARK $from " "$log" | awk '{print $3}')
			end=$(grep "^MARK $to " "$log" | awk '{print $3}')
			[ -z "$start" ] && continue
			length=""
			[ -n "$end" ] && length="-t $(awk "BEGIN{print ($end-$start)/$fps + 0.5}")"
			"$ffmpeg" -y -loglevel error -ss "$(awk "BEGIN{print $start/$fps}")" -i "$full" $length -c:v libx264 -crf 18 -preset medium -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart "$out/${who}_$label.mp4"
		done
	fi
	rm -f "$log"
	echo "$name done"
done
