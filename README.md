# Waylandar

A standalone Wayland Calendar widget and dashboard built with Quickshell (QML) and Python. Fully compatible with modern Wayland compositors like **Hyprland** and Sway.

Officially supports **Google Calendar**, **Nextcloud Calendar (CalDAV)**, **Apple iCloud Calendar**, **ICS Feed Subscriptions**, and **Local Directories** (for parsing local `.ics` files managed by vdirsyncer, Nextcloud Client, or custom scripts).

> **Note:** Waylandar is currently read-only. You can reliably view your schedule and receive background notifications, but you cannot create or edit events directly from the widget yet. Push support for event creation is planned for a future release.

![Demo](assets/demo-v1.1.gif)

## Overview

Two modes:
- **waylandar-widget** — compact desktop widget showing your upcoming agenda, sits on your desktop via wlr-layer-shell
- **waylandar-dashboard** — full-month calendar overlay, toggled on demand

Background sync polls your calendars and fires `notify-send` notifications based on the reminder times you set per-event in Google Calendar or Nextcloud (e.g. "10 minutes before"). Themes automatically via [Matugen](https://github.com/InioX/matugen) if you use it.

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

> **Note:** `quickshell-git` and `uv` are required before running `makepkg -si`.

```bash
# Install the required dependencies first
yay -S quickshell-git uv

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

## Configuration & Setup

Waylandar includes an interactive setup wizard that allows you to easily configure your providers and switch between them.

Run the wizard from your terminal:
```bash
# Nix or Arch install
waylandar

# Manual / cloned repo
cd backend && uv run python sync.py
```

### Option A: Nextcloud Calendar (CalDAV)
When prompted in the wizard, simply provide:
1. Your Nextcloud CalDAV URL (e.g. `https://your-server.com/remote.php/dav`)
2. Your Nextcloud Username
3. An App Password (create this in Nextcloud Settings → Security → Devices & sessions)

### Option B: Google Calendar
Waylandar uses OAuth 2.0 and requires your own Google Cloud credentials. One-time setup:

1. Go to [Google Cloud Console](https://console.cloud.google.com/) and create a project.
2. Enable the **Google Calendar API** for that project.
3. Under **APIs & Services → Credentials**, create an **OAuth 2.0 Client ID** (type: Desktop app).
4. Download the JSON and place it at `~/.config/waylandar/credentials.json`:
   ```bash
   mkdir -p ~/.config/waylandar
   mv ~/Downloads/your-credentials-file.json ~/.config/waylandar/credentials.json
   ```
5. **Important:** In your Google Cloud Console, go to the **OAuth consent screen** and click **Publish App**. If you leave it in "Testing" mode, Google will force your login token to expire every 7 days.
6. Run `waylandar` and follow the prompts to complete the Google login via your web browser.

### Option C: Apple iCloud Calendar
When prompted in the wizard, select Apple iCloud. You will need to provide:
1. Your Apple ID Email.
2. An App-Specific Password. 

Apple requires an App-Specific Password for third-party calendar access. To generate one:
1. Log into your Apple account at [account.apple.com](https://account.apple.com).
2. Navigate to **App-Specific Passwords** and generate a new password.
3. Paste the generated password into the terminal wizard when prompted. Do not use your main Apple ID password.

### Option D: ICS Feed Subscriptions
If your calendar provider is not natively supported but offers a public or secret `.ics` or `webcal://` share link (e.g., Proton Calendar, Microsoft Outlook, Yahoo Calendar, or standard holiday feeds), you can use the ICS Link option in the setup wizard.

You can subscribe to as many ICS feeds as you want. The widget will seamlessly merge them and color-code them appropriately.

### Option E: Local Directory (.ics files)
If you prefer to sync your calendar files manually using tools like `vdirsyncer`, Nextcloud Desktop, Syncthing, or custom bash scripts, you can point Waylandar to a local directory.

Waylandar acts as a decoupled filesystem parser. It will safely recurse through the folder you provide, bypass hidden metadata folders (like `.vdirsyncer/`), and instantly sync any `.ics` files it finds directly into the widget UI. You remain fully responsible for downloading/syncing those files via your external tool of choice.

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

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release notes and version history.

## License

MIT — see [LICENSE](LICENSE).
