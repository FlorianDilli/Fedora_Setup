
# used by the ml4w_post_install and ml4w_post_update to get the right color

fourth_color=$(sed -n '5p' /home/florian/.cache/wal/colors)
sed -i "s/bg3:    .*/bg3:    $fourth_color;/" ~/.local/share/rofi/themes/rounded-nord-dark.rasi
