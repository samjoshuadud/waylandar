# Waylandar

A Google Calendar widget and dashboard for Wayland compositors, built with Quickshell (QML) and Python.

![Demo](assets/demo.gif)

## Overview

Two modes:
- **waylandar-widget** — compact desktop widget showing your upcoming agenda, sits on your desktop via wlr-layer-shell
- **waylandar-dashboard** — full-month calendar overlay, toggled on demand

Background sync polls your calendar and fires `notify-send` notifications based on the reminder times you set per-event in Google Calendar (e.g. "10 minutes before"). Themes automatically via [Matugen](https://github.com/InioX/matugen) if you use it.

---

## Installation

### NixOS (Recommended)

**Try it without installing:**
```bash
nix run github:samjoshuadud/waylandar#waylandar-widget
```

**Declarative (flake.nix):**
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

**Imperative:**
```bash
nix profile install github:samjoshuadud/waylandar
```

### Arch Linux

AUR publishing is temporarily blocked due to the ongoing chain attack mitigation. Install locally for now:

```bash
# Install the quickshell dependency first
yay -S quickshell-git

# Clone and build
git clone https://github.com/samjoshuadud/waylandar.git
cd waylandar
makepkg -si
```

### Manual

Requirements: `quickshell`, `uv`

```bash
git clone https://github.com/samjoshuadud/waylandar.git
cd waylandar
quickshell -p frontend/widget.qml
```

---

## Google Calendar Setup

Waylandar uses OAuth 2.0 and requires your own Google Cloud credentials. One-time setup:

1. Go to [Google Cloud Console](https://console.cloud.google.com/) and create a project.
2. Enable the **Google Calendar API** for that project.
3. Under **APIs & Services → Credentials**, create an **OAuth 2.0 Client ID** (type: Desktop app).
4. Download the JSON and place it at `~/.config/waylandar/credentials.json`:
   ```bash
   mkdir -p ~/.config/waylandar
   mv ~/Downloads/your-credentials-file.json ~/.config/waylandar/credentials.json
   ```
5. Run the auth flow:
   ```bash
   # Nix or Arch install
   waylandar-auth

   # Manual / cloned repo
   cd backend && uv run python fetch_calendar.py
   ```
   A browser window will open for Google login. After completing it, the token is saved and you won't need to do this again unless it expires.

---

## Usage

### Hyprland

Auto-start the widget on login:
```conf
# ~/.config/hypr/hyprland.conf
exec-once = waylandar-widget
```

Bind the dashboard to a key:
```conf
bind = SUPER, C, exec, waylandar-dashboard
```

> If you installed manually, replace `waylandar-widget` / `waylandar-dashboard` with `quickshell -p /path/to/waylandar/frontend/widget.qml`.

---

## Matugen Theming (Optional)

On first run, Waylandar extracts a QML theme template to `~/.config/waylandar/theme_template.qml`. To keep colors in sync with your wallpaper, add this to `~/.config/matugen/config.toml`:

```toml
[templates.waylandar]
input_path = "~/.config/waylandar/theme_template.qml"
output_path = "~/.config/waylandar/frontend/Theme.qml"
```

---

## License

MIT — see [LICENSE](LICENSE).
