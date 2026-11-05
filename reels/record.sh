#!/bin/bash
# Records a reel to a video outside the project. From the project folder, in Git Bash:
#   bash reels/record.sh stitches_patches
# Godot's Movie Maker writes an .avi (1080x1920, from the ".movie" settings in
# project.godot). If ffmpeg is there it's turned into an MP4 and the .avi is
# deleted; if not, the .avi stays. Videos go in Videos/Dinner Time Reels.
set -e
scenario="${1:-stitches_patches}"
godot="${GODOT:-/c/Users/alexw/Desktop/Godot_v4.7.2-stable_win64.exe}"
ffmpeg="${FFMPEG:-$LOCALAPPDATA/DinnerTimeTools/ffmpeg.exe}"
out="$USERPROFILE/Videos/Dinner Time Reels"
mkdir -p "$out"
avi="$out/$scenario.avi"
mp4="$out/$scenario.mp4"

"$godot" --path . --write-movie "$avi" --fixed-fps 60 res://reels/reel_player.tscn -- --scenario="$scenario"
if [ -x "$ffmpeg" ]; then
	"$ffmpeg" -y -loglevel error -i "$avi" -c:v libx264 -crf 18 -preset medium -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart "$mp4"
	rm -f "$avi"
	echo "Saved: $mp4"
else
	echo "No ffmpeg at $ffmpeg, so it's still an AVI."
	echo "Saved: $avi"
fi
