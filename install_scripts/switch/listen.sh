#!/bin/bash

DIRECTORY_TO_WATCH="/control_data"

inotifywait -m -e close_write "$DIRECTORY_TO_WATCH" |
while read -r path action file; do
    if [[ "$file" == *.txt ]]; then
        content=$(cat "$path/$file")
        echo "File '$file' was modified and closed. Content: $content"
        read -a prms <<< "$content"
        ./usr/local/bin/qd.sh ${prms[0]} ${prms[1]} ${prms[2]} ${prms[3]} ${prms[4]}
    fi
done
