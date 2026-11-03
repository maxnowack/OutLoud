#!/bin/bash
# Downloads each listed video, cuts it into 6 s pieces (25 fps video, 16 kHz mono audio), keeps the
# pieces that show a speaker as samples (`outloud lips harvest`) and deletes video and pieces:
# only mouth crops are kept (plans/LIP_READING.md, "German data").
# usage: harvest.sh LIST_JSON WORK_DIR TRIAL_ROOT CLI LANGUAGE
set -u
list=$1; work=$2; export OUTLOUD_LIPS=$3; cli=$4; language=$5
mkdir -p "$work"
/usr/bin/python3 -c "import json,sys; [print(f['url']) for f in json.load(open(sys.argv[1]))]" "$list" |
while read -r url; do
  id=$(printf %s "$url" | shasum | cut -c1-12)
  [ -f "$work/$id.done" ] && continue
  dir="$work/$id"; rm -rf "$dir"; mkdir -p "$dir/pieces"
  curl -sfL -A "outloud-lipreading-research/0.1 (non-commercial; one-off dataset)" -o "$dir/video" "$url" || { echo "$id download failed"; sleep 30; continue; }
  nice -n 10 ffmpeg -nostdin -v error -threads 4 -i "$dir/video" \
    -map 0:v:0 -vf "fps=25,scale=-2:480" -an -c:v libx264 -preset veryfast -crf 20 \
      -force_key_frames "expr:gte(t,n_forced*6)" -f segment -segment_time 6 -reset_timestamps 1 "$dir/pieces/p%05d.mp4" \
    -map 0:a:0 -vn -ac 1 -ar 16000 -f segment -segment_time 6 "$dir/pieces/p%05d.wav" || { echo "$id cut failed"; rm -rf "$dir"; touch "$work/$id.done"; continue; }
  echo "$id $url"
  echo "$id $(ls "$dir/pieces" | grep -c mp4) pieces: $("$cli" lips harvest "$dir/pieces" "$language" < /dev/null 2>/dev/null | tail -1)"
  rm -rf "$dir"; touch "$work/$id.done"
done
"$cli" lips samples 2>/dev/null
