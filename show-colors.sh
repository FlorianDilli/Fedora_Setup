#!/bin/bash
# Path to the colors file
FILE="/home/florian/.cache/wal/colors"

# Array to hold valid colors
colors=()

# Read the file and store the first 15 valid colors into the array.
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    hex="${line/#\#/}"
    if [[ "$hex" =~ ^[0-9A-Fa-f]{6}$ ]]; then
        colors+=("#$hex")
    fi
    if (( ${#colors[@]} >= 16 )); then
        break
    fi
done < "$FILE"

# Ensure the first color is visible by adjusting dark colors
for ((i=0; i<${#colors[@]}; i++)); do
    hex="${colors[i]}"
    hex_nohash="${hex/#\#/}"
    r=$((16#${hex_nohash:0:2}))
    g=$((16#${hex_nohash:2:2}))
    b=$((16#${hex_nohash:4:2}))
    
    # Adjust dark colors for visibility
    (( r < 10 )) && r=10
    (( g < 10 )) && g=10
    (( b < 10 )) && b=10
    
    printf "Color %2d: %-10s " "$i" "$hex"
    printf "\033[48;2;%d;%d;%dm    \033[0m\n" "$r" "$g" "$b"
done

