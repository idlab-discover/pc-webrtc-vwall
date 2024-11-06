#!/bin/bash

DIRECTORY_TO_WATCH="/control_data"

inotifywait -m -e close_write "$DIRECTORY_TO_WATCH" |
while read -r path action file; do
    if [[ "$file" == *.txt ]]; then
        content=$(cat "$path/$file")
        echo "File '$file' was modified and closed. Content: $content"

        case "$content" in
            "status=0")
                echo "Stopping sfu.exe if it is running" >> /output.txt
                pkill -f "sfu.exe"
                ;;
            "status=1")
                echo "Action for status=1" >> /output.txt
                # Add commands or actions for status=1
                (cd /usr/local/bin/sfu && sfu.exe -t 3 > /dev/null 2>&1 &)
                ;;
            "status=2")
                echo "Action for status=2" >> /output.txt
                # Add commands or actions for status=2
                (cd /usr/local/bin/sfu && sfu.exe -t 3 -d > /dev/null 2>&1 &)
                ;;
            "status=3")
                echo "Action for status=3" >> /output.txt
                # Add commands or actions for status=2
                (cd /usr/local/bin/sfu && sfu.exe -t 3 -d -b > /dev/null 2>&1 &)
                ;;
            *)
                echo "Unrecognized status in file content" >> /output.txt
                ;;
        esac
    fi
done
