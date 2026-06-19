# Waylandar

A beautiful, standalone Google Calendar widget and dashboard for Wayland compositors (Hyprland, Sway, etc.). 

Built with Quickshell (QML) for the sleek native Wayland frontend and Python for the robust Google Calendar API backend.

## Features
* Native Wayland: Uses wlr-layer-shell to render perfectly as a desktop widget or full-screen overlay.
* Dual Modes: 
  * waylandar-widget: A compact, auto-resizing desktop widget showing your upcoming agenda.
  * waylandar-dashboard: A beautiful full-month calendar dashboard overlay.
* Smart Background Syncing: Silently auto-fetches your calendar in the background and gracefully pushes native system notifications (notify-send) for your upcoming reminders!
* Aesthetic: Modern, glassmorphic UI built in QML with smooth animations.
* Robust Auth: Gracefully handles expired or missing tokens by guiding you through an easy terminal-based Google OAuth flow.

---

## Installation

### NixOS / Nix Flake (Recommended)
Waylandar is fully packaged as a Nix Flake. You can test it instantly without installing:
```bash
nix run github:samjoshuadud/waylandar#waylandar-widget
```
Or install it permanently to your profile:
```bash
nix profile install github:samjoshuadud/waylandar
```

### Arch Linux
Waylandar includes a native PKGBUILD. You can build and install it locally using makepkg:
```bash
git clone https://github.com/samjoshuadud/waylandar.git
cd waylandar
makepkg -si
```

### Manual Installation
If you aren't using Nix or Arch, you can run it locally:
1. Ensure you have quickshell and uv installed on your system.
2. Clone this repository:
```bash
git clone https://github.com/samjoshuadud/waylandar.git
cd waylandar
```
3. Run the development shell or manually trigger Quickshell:
```bash
quickshell -p frontend/widget.qml
```

---

## Setup & Authentication

Waylandar needs to talk to your Google Calendar. You'll need to provide it with your own Google Cloud API credentials.

1. Go to the Google Cloud Console.
2. Create a New Project and enable the Google Calendar API.
3. Go to APIs & Services > Credentials and create an OAuth 2.0 Client ID (Choose "Desktop app").
4. Download the generated JSON file and rename it to credentials.json.
5. Place this file in the config directory:
```bash
mkdir -p ~/.config/waylandar
mv ~/Downloads/credentials.json ~/.config/waylandar/
```
6. Run the authentication tool in your terminal:
```bash
waylandar-auth
```
*(A browser window will pop up asking you to securely log in. Once complete, you can safely close the terminal!)*

---

## Usage

Once authenticated, simply run the binaries to spawn the UI:

* To launch the desktop widget (perfect for exec-once in your hyprland.conf):
```bash
waylandar-widget
```

* To launch the full-month dashboard:
```bash
waylandar-dashboard
```

## License
This project is licensed under the MIT License - see the LICENSE file for details.
