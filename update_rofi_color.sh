
# used by the ml4w_post_install and ml4w_post_update to get the right color

fifth_color=$(sed -n '5p' /home/florian/.cache/wal/colors)
sed -i "s/bg3:    .*/bg3:    $fifth_color;/" /home/florian/Fedora_Setup/Config_Files/Rofi/my_rofi_theme.rasi
sed -i "s/fg3:    .*/fg3:    $fifth_color;/" /home/florian/Fedora_Setup/Config_Files/Rofi/my_rofi_theme.rasi

