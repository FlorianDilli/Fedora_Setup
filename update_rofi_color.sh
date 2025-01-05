
# used by the ml4w_post_install and ml4w_post_update to get the right color

fifth_color=$(sed -n '5p' /home/florian/.cache/wal/colors)
sed -i "s/bg3:    .*/bg3:    $fifth_color;/" ~/.local/share/rofi/themes/rounded-nord-dark.rasi
sed -i "s/fg3:    .*/fg3:    $fifth_color;/" ~/.local/share/rofi/themes/rounded-nord-dark.rasi

