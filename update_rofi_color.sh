fourth_color=$(sed -n '5p' /home/florian/.cache/wal/colors)
sed -i "s/bg3:    .*/bg3:    $fourth_color;/" ~/.local/share/rofi/themes/rounded-nord-dark.rasi
