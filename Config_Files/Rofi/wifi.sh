#!/bin/bash
# This script provides a user-friendly Wi-Fi connection switcher using nmcli and rofi.
# It requires nmcli, rofi, and notify-send.

# --- Check dependencies ---
for cmd in nmcli rofi notify-send; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: \"$cmd\" is not installed or not in your PATH." >&2
    exit 1
  fi
done

# Get the list of saved connection names (SSIDs)
saved_connections=$(nmcli -g NAME connection 2>/dev/null)
if [ $? -ne 0 ]; then
  notify-send -u critical --app-name="Wi-Fi Switcher" "Error" "Failed to get saved Wi-Fi connections."
  exit 1
fi

build_wifi_menu() {
  wifi_menu_conn=""
  wifi_menu_saved=""
  wifi_menu_unsaved=""

  # Trigger a Wi-Fi rescan (discard output) & wait a little bit to let scan finish
  nmcli device wifi rescan >/dev/null 2>&1
  sleep 1

  # Retrieve list of available networks using a tab-separated list
  # Fields: IN-USE:SSID:SIGNAL:SECURITY
  wifi_list=$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null)
  if [ -z "$wifi_list" ]; then
    notify-send -u normal --app-name="Wi-Fi Switcher" "Info" "No Wi-Fi networks available."
    return
  fi

  while IFS=: read -r in_use ssid signal security; do
    # Skip blank SSID entries
    [ -z "$ssid" ] && continue

    # Trim whitespace (if needed)
    ssid=$(echo "$ssid" | xargs)

    # Determine if network is currently connected
    if [ "$in_use" = "*" ]; then
      connected=1
    else
      connected=0
    fi

    # Check if SSID is saved
    if echo "$saved_connections" | grep -Fxq "$ssid"; then
      saved=1
    else
      saved=0
    fi

    # Calculate signal strength index (0 to 4)
    # Handle missing or non-number signal values.
    if [[ "$signal" =~ ^[0-9]+$ ]]; then
      idx=$((signal / 20))
    else
      idx=0
    fi
    [ $idx -gt 4 ] && idx=4

    # Choose an icon set based on state:
    if [ $connected -eq 1 ]; then
      icons=("󰤯" "󰤟" "󰤢" "󰤥" "󰤨")
    elif [ $saved -eq 1 ]; then
      icons=("󱛏" "󱛋" "󱛌" "󱛍" "󱛎")
    else
      icons=("󰤬" "󰤡" "󰤤" "󰤧" "󰤪")
    fi
    icon="${icons[$idx]}"

    # Create a line with icon and SSID (tab-separated)
    line="${icon}\t${ssid}"
    if [ $connected -eq 1 ]; then
      wifi_menu_conn+="\t${line}\n"
    else
      if [ $saved -eq 1 ]; then
        wifi_menu_saved+="${line}\n"
      else
        wifi_menu_unsaved+="${line}\n"
      fi
    fi
  done <<< "$wifi_list"
  # Combine the lists: connected first, then saved, then unsaved
  wifi_menu="${wifi_menu_conn}${wifi_menu_saved}${wifi_menu_unsaved}"
}

# --- Main Loop ---
while true; do

  # Determine current Wi-Fi state.
  wifi_status=$(nmcli radio wifi 2>/dev/null)
  if [ $? -ne 0 ]; then
    notify-send -u critical --app-name="Wi-Fi Switcher" "Error" "Failed to retrieve Wi-Fi state."
    exit 1
  fi

  if [ "$wifi_status" = "enabled" ]; then
    wifi_toggle="Disable Wi-Fi"
  else
    wifi_toggle="Enable Wi-Fi"
  fi

  # Rebuild the Wi-Fi menu list.
  build_wifi_menu
  
  # Combine toggle and Wi-Fi networks entries into the final menu.
  menu_list=""
  menu_list+="            ${wifi_toggle}\n"
  menu_list+="${wifi_menu}"
  # Remove any empty lines.
  menu_list=$(printf "%b" "$menu_list" | sed '/^[[:space:]]*$/d')

  # If no Wi-Fi networks exist and the radio is enabled, let the user know.
  if [ -z "$menu_list" ]; then
    if [ "$wifi_status" = "enabled" ]; then
      notify-send -u normal --app-name="Wi-Fi Switcher" "Info" "No available Wi-Fi networks found. Please try again later."
    fi
    exit 0
  fi

# Display the menu using rofi with a custom theme  
chosen=$(printf "%b" "$menu_list" | rofi -dmenu -i \
    -theme-str '  
        configuration { show-icons: false; }  
        window {  
            location: north east;  
            x-offset: -50;  
            y-offset: 4;  
            width: 225px;  
        }  
        listview {  
            columns: 1;  
            lines: 50;  
        }  
        inputbar { enabled: false; }  
        mode-switcher { enabled: false; }  
    ')

  # If no selection is made, exit.
  [ -z "$chosen" ] && exit 0

  # Process toggle selection.
  if [[ "$chosen" == "            Disable Wi-Fi" ]]; then
    if nmcli radio wifi off; then
      notify-send -u normal --app-name="Wi-Fi Switcher" "Wi-Fi Disabled" "Wi-Fi has been turned off."
    else
      notify-send -u critical --app-name="Wi-Fi Switcher" "Error" "Failed to disable Wi-Fi."
    fi
    exit 0

  elif [[ "$chosen" == "            Enable Wi-Fi" ]]; then
    if nmcli radio wifi on; then
      notify-send -u normal --app-name="Wi-Fi Switcher" "Wi-Fi Enabled" "Enabling Wi-Fi, please wait..."
      # Wait a bit to allow networks to appear.
      sleep 3
      continue
    else
      notify-send -u critical --app-name="Wi-Fi Switcher" "Error" "Failed to enable Wi-Fi."
      exit 1
    fi
  fi

  # Process Wi-Fi network selection.
  # Expecting each network entry format: "ICON<TAB>SSID" or with a prefix marker.
  ssid=$(echo "$chosen" | awk -F'\t' '{print $2}')
  if [ -z "$ssid" ]; then
    notify-send -u normal --app-name="Wi-Fi Switcher" "Selection Error" "Could not determine network from selection."
    exit 1
  fi

  # If the network is known (saved) then try that first.
  if echo "$saved_connections" | grep -Fxq "$ssid"; then
    if nmcli connection up id "$ssid"; then
      notify-send -u normal --app-name="Wi-Fi Switcher" "Connected" "You are now connected to \"$ssid\"."
    else
      notify-send -u critical --app-name="Wi-Fi Switcher" "Error" "Failed to connect to \"$ssid\"."
    fi

  else
    # For unknown networks, check if it is secured.
    sec=$(nmcli -t -f SSID,SECURITY device wifi list 2>/dev/null | grep -F "$ssid" | cut -d: -f2 | head -n1)
    if [ "$sec" != "--" ] && [ -n "$sec" ]; then
      pass=$(rofi -dmenu -theme-str 'window { location: north east; x-offset: -155; y-offset: 2; width: 225px; } listview { enabled: false; } mode-switcher { enabled: false; } element { enabled: false; }' -dmenu -mesg "Password for $ssid:" -password)
      if [ -z "$pass" ]; then
        notify-send -u normal --app-name="Wi-Fi Switcher" "Cancelled" "No password provided for \"$ssid\"."
        exit 0
      fi
      if nmcli device wifi connect "$ssid" password "$pass"; then
        notify-send -u normal --app-name="Wi-Fi Switcher" "Connected" "You are now connected to \"$ssid\"."
      else
        notify-send -u critical --app-name="Wi-Fi Switcher" "Error" "Failed to connect to \"$ssid\" with provided password."
      fi
    else
      if nmcli device wifi connect "$ssid"; then
        notify-send -u normal --app-name="Wi-Fi Switcher" "Connected" "You are now connected to \"$ssid\"."
      else
        notify-send -u critical --app-name="Wi-Fi Switcher" "Error" "Failed to connect to \"$ssid\"."
      fi
    fi
  fi

  # Exit after processing selection.
  exit 0
done

exit 0

