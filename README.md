# Waylandar

![Waylandar Showcase](placeholder.png)

A beautiful, standalone Google Calendar widget and dashboard for Wayland compositors (Hyprland, Sway, etc.). 

Built with Quickshell (QML) for the sleek native Wayland frontend and Python for the robust Google Calendar API backend.

## Features
* Native Wayland: Uses wlr-layer-shell to render perfectly as a desktop widget or full-screen overlay.
* Dual Modes: 
  * waylandar-widget: A compact, auto-resizing desktop widget showing your upcoming agenda.
  * waylandar-dashboard: A beautiful full-month calendar dashboard overlay.
* Smart Background Syncing: Silently auto-fetches your calendar in the background and gracefully pushes native system notifications (notify-send) for your upcoming reminders!
* Matugen Compatible: Automatically themes itself dynamically with your system colors if you use Matugen to generate Qt/QML materials.
* Aesthetic: Modern, glassmorphic UI built in QML with smooth animations.
* Robust Auth: Gracefully handles expired or missing tokens by guiding you through an easy terminal-based Google OAuth flow.

---

## Installation

### NixOS / Nix Flake (Recommended)
Waylandar is fully packaged as a Nix Flake. 

**Option 1: Try it instantly**
```bash
nix run github:samjoshuadud/waylandar#waylandar-widget
```

**Option 2: Install declaratively in your system `flake.nix`**
```nix
inputs.waylandar.url = "github:samjoshuadud/waylandar";

outputs = { self, nixpkgs, waylandar, ... }: {
  nixosConfigurations.myhostname = nixpkgs.lib.nixosSystem {
    modules = [
      ({ pkgs, ... }: {
        environment.systemPackages = [
          waylandar.packages.x86_64-linux.default
        ];
      })
    ];
  };
};
```

**Option 3: Install imperatively to your user profile**
```bash
nix profile install github:samjoshuadud/waylandar
```

### Arch Linux
Waylandar includes a native PKGBUILD. *(Note: Because the Arch Linux team has temporarily disabled new AUR registrations to mitigate chain attacks, this package is not currently on the AUR.)*

You can easily build and install it locally using makepkg:
```bash
# First, install the quickshell AUR dependency using your favorite helper
yay -S quickshell-git

# Then clone and install waylandar
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

**If you installed via Nix or Arch Linux (global command):**
```bash
waylandar-auth
```

**If you are running it manually from the cloned repo:**
```bash
cd ~/path/to/waylandar/backend
uv run python fetch_calendar.py
```
*(A browser window will pop up asking you to securely log in. Once complete, you can safely close the terminal!)*

---

## Usage

Once authenticated, simply run the binaries to spawn the UI.

### Hyprland Integration
To make the desktop widget launch automatically when you start your computer, add this to your `~/.config/hyprland/hyprland.conf`:
```conf
exec-once = waylandar-widget
```

To bind the full-month dashboard overlay to a keyboard shortcut (e.g., `SUPER + C`), add this to your `hyprland.conf`:
```conf
bind = SUPER, C, exec, waylandar-dashboard
```

*(Note: If you installed manually from the cloned repo instead of using Nix or Arch, replace `waylandar-widget` with `quickshell -p /path/to/waylandar/frontend/widget.qml`)*

## License
This project is licensed under the MIT License - see the LICENSE file for details.
