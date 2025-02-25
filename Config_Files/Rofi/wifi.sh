#!/bin/bash
# A compact and readable Wi-Fi connection switcher using nmcli, rofi, and notify-send.

# --- Check Dependencies ---
for cmd in nmcli rofi notify-send; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' is not installed or not in your PATH." >&2
    exit 1
  fi
done

# Retrieve saved Wi-Fi connection names (SSIDs)
get_saved_connections() {
  nmcli -g NAME connection 2>/dev/null || {
    notify-send -u critical --app-name="Wi-Fi Switcher" "Error" "Failed to get saved Wi-Fi connections."
    exit 1
  }
}
saved_connections=$(get_saved_connections)

# --- Helper Functions ---
notify_msg() {
  local urgency="$1" title="$2" message="$3"
  notify-send -u "$urgency" --app-name="Wi-Fi Switcher" "$title" "$message"
}

calc_signal_index() {
  local signal="$1"
  if [[ "$signal" =~ ^[0-9]+$ ]]; then
    local index=$((signal / 20))
    (( index > 4 )) && index=4
  else
    index=0
  fi
  echo "$index"
}

build_wifi_menu() {
  local menu_conn="" menu_saved="" menu_unsaved=""
  
  # Scan for networks and wait a moment
  nmcli device wifi rescan &>/dev/null && sleep 1
  
  local wifi_list
  wifi_list=$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null)
  [[ -z "$wifi_list" ]] && { notify_msg normal "Info" "No Wi-Fi networks available."; return; }
  
  while IFS=: read -r in_use ssid signal security; do
    [[ -z "$ssid" ]] && continue
    ssid=$(echo "$ssid" | xargs)  # Trim whitespace
    local connected=0 saved=0
    [[ "$in_use" == "*" ]] && connected=1
    echo "$saved_connections" | grep -Fxq "$ssid" && saved=1

    local idx
    idx=$(calc_signal_index "$signal")
    if (( connected )); then
      icons=("󰤯" "󰤟" "󰤢" "󰤥" "󰤨")
    elif (( saved )); then
      icons=("󱛏" "󱛋" "󱛌" "󱛍" "󱛎")
    else
      icons=("󰤬" "󰤡" "󰤤" "󰤧" "󰤪")
    fi
    local icon="${icons[$idx]}"
    local line="${icon}\t${ssid}"
    
    if (( connected )); then
      menu_conn+="\t${line}\n"
    elif (( saved )); then
      menu_saved+="${line}\n"
    else
      menu_unsaved+="${line}\n"
    fi
  done <<< "$wifi_list"
  
  # Order: Connected > Saved > Unsaved 
  printf "%b" "${menu_conn}${menu_saved}${menu_unsaved}"
}

# --- Main Loop ---
while true; do
  wifi_status=$(nmcli radio wifi 2>/dev/null) || {
    notify_msg critical "Error" "Failed to retrieve Wi-Fi state."
    exit 1
  }
  
  if [ "$wifi_status" = "enabled" ]; then
    wifi_toggle="Disable Wi-Fi"
  else
    wifi_toggle="Enable Wi-Fi"
  fi
  
  # Center the toggle text. Adjust target_width (in characters) as needed.
  target_width=30
  toggle_length=${#wifi_toggle}
  left_padding=$(( (target_width - toggle_length) / 2 ))
  padding=$(printf "%${left_padding}s" "")
  centered_toggle="${padding}${wifi_toggle}"

  wifi_menu=$(build_wifi_menu)
  menu_list=$(printf "%b\n%s" "$centered_toggle" "$wifi_menu" | sed '/^[[:space:]]*$/d')
  
  if [[ -z "$menu_list" ]]; then
    [[ "$wifi_status" == "enabled" ]] && notify_msg normal "Info" "No available Wi-Fi networks found. Please try again later."
    exit 0
  fi
  
  chosen=$(printf "%b" "$menu_list" | rofi -dmenu -i \
    -theme-str '  
      configuration { show-icons: false; }  
      window { location: north east; x-offset: -50; y-offset: 4; width: 350px; }  
      listview { columns: 1; lines: 50; }  
      inputbar { enabled: false; }  
      mode-switcher { enabled: false; }
    ')
  
  [[ -z "$chosen" ]] && exit 0
  
  # Process Wi-Fi toggle
  if [[ "$chosen" == "$centered_toggle" ]]; then
    if [ "$wifi_toggle" == "Disable Wi-Fi" ]; then
      if nmcli radio wifi off; then
        notify_msg normal "Wi-Fi Disabled" "Wi-Fi has been turned off."
      else
        notify_msg critical "Error" "Failed to disable Wi-Fi."
      fi
      exit 0
    elif [ "$wifi_toggle" == "Enable Wi-Fi" ]; then
      if nmcli radio wifi on; then
        notify_msg normal "Wi-Fi Enabled" "Enabling Wi-Fi, please wait..."
        sleep 3
        continue
      else
        notify_msg critical "Error" "Failed to enable Wi-Fi."
        exit 1
      fi
    fi
  fi
  
  # Process network selection.
  selected_ssid=$(echo "$chosen" | awk -F'\t' '{print $2}')
  if [[ -z "$selected_ssid" ]]; then
    notify_msg normal "Selection Error" "Could not determine network from selection."
    exit 1
  fi
  
  if echo "$saved_connections" | grep -Fxq "$selected_ssid"; then
    if nmcli connection up id "$selected_ssid"; then
      notify_msg normal "Connected" "You are now connected to \"$selected_ssid\"."
    else
      notify_msg critical "Error" "Failed to connect to \"$selected_ssid\"."
    fi
  else
    security=$(nmcli -t -f SSID,SECURITY device wifi list 2>/dev/null | awk -F: -v ssid="$selected_ssid" '$1==ssid {print $2; exit}')
    if [[ "$security" != "--" && -n "$security" ]]; then
      pass=$(rofi -dmenu -theme-str 'window { location: north east; x-offset: -50; y-offset: 2; width: 350px; } listview { enabled: false; } mode-switcher { enabled: false; } element { enabled: false; }' \
                -dmenu -mesg "Password for $selected_ssid:" -password)
      [[ -z "$pass" ]] && { notify_msg normal "Cancelled" "No password provided for \"$selected_ssid\"."; exit 0; }
      if nmcli device wifi connect "$selected_ssid" password "$pass"; then
        notify_msg normal "Connected" "You are now connected to \"$selected_ssid\"."
      else
        notify_msg critical "Error" "Failed to connect to \"$selected_ssid\" with provided password."
      fi
    else
      if nmcli device wifi connect "$selected_ssid"; then
        notify_msg normal "Connected" "You are now connected to \"$selected_ssid\"."
      else
        notify_msg critical "Error" "Failed to connect to \"$selected_ssid\"."
      fi
    fi
  fi
  
  exit 0
done

exit 0

