#!/bin/bash

# Funktion zum Überprüfen, ob ein Befehl erfolgreich war
check_success() {
    if [ $? -ne 0 ]; then
        echo "Fehler: $1"
        exit 1
    fi
}

# Funktion zum Setzen des Scaling-Faktors
setup_scaling() {
    echo "Konfiguriere Scaling..."
    
    CUSTOM_CONF="$HOME/.config/hypr/conf/custom.conf"
    SCALING_LINE="monitor=,preferred,auto,1.666667"
    
    # Use grep with word boundaries and exclude commented lines
    if ! grep -q "^${SCALING_LINE}$" "$CUSTOM_CONF"; then
        echo "Adding scaling line..."
        echo "$SCALING_LINE" >> "$CUSTOM_CONF"
        check_success "Konnte Scaling nicht konfigurieren"
        echo "Scaling erfolgreich konfiguriert"
    else
        echo "Scaling bereits konfiguriert"
    fi
}

# Funktion zum Einrichten der Rofi-Themes
setup_rofi_themes() {
    echo "Konfiguriere Rofi-Themes..."
    
    # Erstelle notwendige Verzeichnisse
    mkdir -p ~/.local/share/rofi/themes/
    mkdir -p ~/.config/rofi/custom/
    
    # Clone Rofi-Themes Repository, falls noch nicht vorhanden
    if [ ! -d "rofi-themes-collection" ]; then
        git clone https://github.com/lr-tech/rofi-themes-collection.git
        check_success "Konnte Rofi-Themes nicht klonen"
    fi
    
    # Kopiere Theme-Dateien
    cp rofi-themes-collection/themes/rounded-nord-dark.rasi ~/.local/share/rofi/themes/
    cp rofi-themes-collection/themes/rounded-common.rasi ~/.local/share/rofi/themes/
    check_success "Konnte Theme-Dateien nicht kopieren"
    
    # Erstelle Rofi-Konfiguration
    cat > ~/.config/rofi/custom/config.rasi << EOL
@theme "~/.local/share/rofi/themes/rounded-nord-dark.rasi"
configuration {
    show-icons: true;
    display-drun: "";
}
EOL
    check_success "Konnte Rofi-Konfiguration nicht erstellen"
    
    # Setze Symlink
    if [ -f ~/.config/rofi/config.rasi ]; then
        rm ~/.config/rofi/config.rasi
    fi
    ln -s ~/.config/rofi/custom/config.rasi ~/.config/rofi/config.rasi
    check_success "Konnte Symlink nicht erstellen"
    
    echo "Rofi-Themes erfolgreich konfiguriert"
}

# Hauptfunktion
main() {
    echo "Starte Konfiguration..."
    
    setup_scaling
    setup_rofi_themes
    
    echo "Konfiguration abgeschlossen!"
}

# Führe das Skript aus
main
