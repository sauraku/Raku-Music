#!/bin/bash

# Define variables
PROD_APP_NAME="Raku Music"
DEV_APP_NAME="Raku Music Dev"
PROD_APP_ID="com.sauraku.raku_music"
DEV_APP_ID="com.sauraku.raku_music.dev"

BINARY_NAME="raku_music"
INSTALL_DIR="$HOME/.local/share/raku_music"
DESKTOP_FILE="$HOME/.local/share/applications/raku_music.desktop"
ICON_PATH="$INSTALL_DIR/data/flutter_assets/assets/app.png"

# Function to update app name and ID
update_app_config() {
    local name="$1"
    local id="$2"
    echo "Updating app config to: Name=$name, ID=$id"

    # Update pubspec.yaml description
    sed -i "s/^description: .*/description: \"$name\"/" pubspec.yaml

    # Update main.dart title
    sed -i "s/title: '.*'/title: '$name'/" lib/main.dart

    # Update Linux CMakeLists.txt APPLICATION_ID
    sed -i "s/set(APPLICATION_ID \".*\")/set(APPLICATION_ID \"$id\")/" linux/CMakeLists.txt

    # Update my_application.cc title
    sed -i "s/gtk_header_bar_set_title(header_bar, \".*\");/gtk_header_bar_set_title(header_bar, \"$name\");/" linux/runner/my_application.cc
    sed -i "s/gtk_window_set_title(window, \".*\");/gtk_window_set_title(window, \"$name\");/" linux/runner/my_application.cc
}

# 1. Change config to Production
update_app_config "$PROD_APP_NAME" "$PROD_APP_ID"

# 2. Build the application
echo "Building Flutter application..."
flutter build linux --release

if [ $? -ne 0 ]; then
    echo "Build failed! Reverting changes..."
    update_app_config "$DEV_APP_NAME" "$DEV_APP_ID"
    exit 1
fi

# 3. Install
echo "Installing to $INSTALL_DIR..."

# Create directory if not exists
mkdir -p "$INSTALL_DIR"

# Remove old installation
rm -rf "$INSTALL_DIR/*"

# Copy bundle to install directory
cp -r build/linux/x64/release/bundle/* "$INSTALL_DIR/"

# Create .desktop file
echo "Creating desktop entry..."
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Name=$PROD_APP_NAME
Comment=A Linux-only music player built with Flutter
Exec=$INSTALL_DIR/$BINARY_NAME
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Audio;Music;Player;
StartupWMClass=$PROD_APP_ID
EOF

# Make .desktop file executable
chmod +x "$DESKTOP_FILE"

# Update desktop database
update-desktop-database "$HOME/.local/share/applications"

echo "Installation complete!"

# 4. Revert config to Dev
update_app_config "$DEV_APP_NAME" "$DEV_APP_ID"

echo "Reverted app config to development version."
