#!/bin/bash

INSTALL_DIR="$HOME/.local/share/raku_music"
DESKTOP_FILE="$HOME/.local/share/applications/raku_music.desktop"

echo "Uninstalling Raku Music..."

# Remove application files
if [ -d "$INSTALL_DIR" ]; then
    echo "Removing application files from $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
else
    echo "Application directory not found."
fi

# Remove desktop entry
if [ -f "$DESKTOP_FILE" ]; then
    echo "Removing desktop entry..."
    rm "$DESKTOP_FILE"
else
    echo "Desktop entry not found."
fi

# Update desktop database
echo "Updating desktop database..."
update-desktop-database "$HOME/.local/share/applications"

echo "Uninstallation complete!"
