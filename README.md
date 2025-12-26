# Raku Music

A Linux-only music player built with Flutter.

## Features

- **Library Management**: Scan and manage your local music library.
- **Search**: Quickly find songs by title or artist.
- **Playback**: Play, pause, skip, and seek through your tracks.
- **Persistent Settings**: Remembers your music folders and theme preferences.
- **Theming**: Supports Light, Dark, and System themes.
- **Mini Player**: Always-visible bottom player for easy control.
- **Now Playing**: Detailed view with album art and scrubbing.

## Getting Started

This project is designed for Linux.

### Prerequisites

- Flutter SDK
- Linux development tools (e.g., `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`)
- **ffmpeg**: Required for waveform generation.
  - For Arch/Manjaro: `sudo pacman -S ffmpeg`
  - For Debian/Ubuntu: `sudo apt install ffmpeg`
  - For Fedora: `sudo dnf install ffmpeg`
- **libayatana-appindicator**: Required for the system tray icon.
  - For Arch/Manjaro: `sudo pacman -S libayatana-appindicator`
  - For Debian/Ubuntu: `sudo apt install libayatana-appindicator3-dev`
  - For Fedora: `sudo dnf install libappindicator-gtk3-devel`

### Installation

1.  Clone the repository.
2.  Make the installation script executable:
    ```bash
    chmod +x install.sh
    ```
3.  Run the script:
    ```bash
    ./install.sh
    ```
    This will build the release version of the app and install it to `~/.local/share/raku_music`, and create a desktop entry.

### Uninstallation

To remove the application from your system, run the uninstallation script:

```bash
chmod +x uninstall.sh
./uninstall.sh
```

## Project Structure

- `lib/`: Contains the Dart source code.
- `linux/`: Contains the Linux-specific runner code.
