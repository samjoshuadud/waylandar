import json
import os
import sys

# ANSI Color Constants
C_HEADER = '\033[95m\033[1m'
C_BLUE = '\033[94m'
C_CYAN = '\033[96m'
C_GREEN = '\033[92m'
C_WARN = '\033[93m'
C_FAIL = '\033[91m'
C_END = '\033[0m'
C_BOLD = '\033[1m'

CONFIG_PATH = os.path.expanduser('~/.config/waylandar/config.json')

def load_config():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, 'r') as f:
                return json.load(f)
        except Exception:
            return {"active_provider": None, "providers": {}}
    else:
        # Backwards compatibility check
        creds_path = os.path.expanduser('~/.config/waylandar/credentials.json')
        if os.path.exists(creds_path):
            return {"active_provider": "google", "providers": {"google": {"configured": True}}}
        return {"active_provider": None, "providers": {}}

def save_config(config):
    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
    # 0600 permissions for security
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
    with os.fdopen(os.open(CONFIG_PATH, flags, 0o600), 'w') as f:
        json.dump(config, f, indent=2)

def background_sync():
    config = load_config()
    provider = config.get("active_provider")
    
    if not provider:
        print(json.dumps({"error": "No calendar configured.\nPlease run this in your terminal:\n\nwaylandar\n(or 'uv run python sync.py' if installed manually)"}))
        sys.exit(1)
        
    year = None
    month = None
    args = [arg for arg in sys.argv if arg != '--background']
    if len(args) == 3:
        year = int(args[1])
        month = int(args[2])
        
    if provider == "google":
        from providers import google
        google.setup(is_background=True)
        data = google.fetch(year, month)
        if isinstance(data, list):
            data = {"events": data, "calendars": []}
        print(json.dumps(data, indent=2))
    elif provider in ["nextcloud", "icloud"]:
        from providers import caldav
        caldav.setup(is_background=True, provider_key=provider)
        data = caldav.fetch(year, month, provider_key=provider)
        if isinstance(data, list):
            data = {"events": data, "calendars": []}
        print(json.dumps(data, indent=2))
    elif provider == "ics":
        from providers import ics
        ics.setup(is_background=True)
        data = ics.fetch(year, month)
        if isinstance(data, list):
            data = {"events": data, "calendars": []}
        print(json.dumps(data, indent=2))
    else:
        print(json.dumps({"error": f"Unknown provider: {provider}"}))
        sys.exit(1)

def interactive_wizard():
    config = load_config()
    
    # Zero-state: True First Run
    creds_path = os.path.expanduser('~/.config/waylandar/credentials.json')
    if not os.path.exists(CONFIG_PATH) and not os.path.exists(creds_path):
        print(f"{C_HEADER}Welcome to Waylandar Calendar Setup{C_END}")
        print(f"{C_CYAN}Please select a calendar provider to configure:{C_END}")
        print(f"  {C_BOLD}[1]{C_END} Google")
        print(f"  {C_BOLD}[2]{C_END} Nextcloud")
        print(f"  {C_BOLD}[3]{C_END} Apple iCloud")
        print(f"  {C_BOLD}[4]{C_END} ICS Link (Proton, Outlook, Yahoo, etc.)")
        choice = input(f"{C_BOLD}> {C_END}").strip()
        if choice == '1':
            setup_google(config, first_run=True)
        elif choice == '2':
            setup_nextcloud(config, first_run=True)
        elif choice == '3':
            setup_icloud(config, first_run=True)
        elif choice == '4':
            setup_ics(config, first_run=True)
        else:
            print(f"{C_FAIL}Invalid choice.{C_END}")
        return

    while True:
        print(f"\n{C_HEADER}--- Waylandar Calendar Setup ---{C_END}")
        active = config.get("active_provider")
        providers = config.get("providers", {})
        
        active_str = f"{C_GREEN}{active}{C_END}" if active else f"{C_WARN}None{C_END}"
        print(f"{C_CYAN}Current active provider:{C_END} {active_str}\n")
        
        options = []
        all_providers = [
            ("google", "Google"),
            ("nextcloud", "Nextcloud"),
            ("icloud", "Apple iCloud"),
            ("ics", "ICS Link (Proton, Outlook, Yahoo, etc.)")
        ]
        
        for key, name in all_providers:
            if active == key:
                if key == "google":
                    options.append((f"Re-auth {name}", lambda: setup_google(config, force_reauth=True)))
                elif key == "nextcloud":
                    options.append((f"Re-auth {name}", lambda: setup_nextcloud(config)))
                elif key == "icloud":
                    options.append((f"Re-auth {name}", lambda: setup_icloud(config)))
                elif key == "ics":
                    options.append((f"Add another {name}", lambda: setup_ics(config)))
                    options.append(("Manage ICS Feeds", lambda: manage_ics_feeds(config)))
            else:
                if key in providers:
                    options.append((f"Switch to {name}", lambda k=key: switch_provider(config, k)))
                else:
                    if key == "google":
                        options.append((f"Set up {name}", lambda: setup_google(config)))
                    elif key == "nextcloud":
                        options.append((f"Set up {name}", lambda: setup_nextcloud(config)))
                    elif key == "icloud":
                        options.append((f"Set up {name}", lambda: setup_icloud(config)))
                    elif key == "ics":
                        options.append((f"Set up {name}", lambda: setup_ics(config)))
                
        interval = config.get("sync_interval", 60)
        options.append((f"Change Sync Interval (Current: {interval}m)", lambda: change_sync_interval(config)))
        options.append(("Exit", sys.exit))
        
        for i, (text, func) in enumerate(options):
            print(f"  {C_BOLD}[{i+1}]{C_END} {text}")
            
        choice = input(f"\n{C_BOLD}Select an option:{C_END} ").strip()
        try:
            idx = int(choice) - 1
            if 0 <= idx < len(options):
                options[idx][1]()
            else:
                print(f"{C_FAIL}Invalid option.{C_END}")
        except ValueError:
            print("Invalid choice.")

def switch_provider(config, new_provider):
    config["active_provider"] = new_provider
    save_config(config)
    print(f"\n{C_GREEN}Switched active provider to {C_BOLD}{new_provider}{C_END}")

def change_sync_interval(config):
    current = config.get("sync_interval", 60)
    print(f"\n{C_CYAN}Current sync interval: {current} minutes{C_END}")
    val = input(f"{C_CYAN}Enter new sync interval in minutes (minimum 5):{C_END} ").strip()
    try:
        val = int(val)
        if val < 5:
            print("Enforcing minimum interval of 5 minutes to prevent API rate limiting.")
            val = 5
        config["sync_interval"] = val
        save_config(config)
        print(f"Sync interval updated to {val} minutes.")
    except ValueError:
        print("Invalid input. Must be an integer.")

def setup_google(config, first_run=False, force_reauth=False):
    from providers import google
    print("\nStarting Google Calendar Setup...")
    success = google.setup(is_background=False, force_reauth=force_reauth)
    if success:
        config["active_provider"] = "google"
        if "providers" not in config:
            config["providers"] = {}
        if "google" not in config["providers"]:
            config["providers"]["google"] = {}
        config["providers"]["google"]["configured"] = True
        save_config(config)
        print("\nSuccessfully authenticated with Google Calendar!")
        if first_run:
            print("You can now safely close this terminal and use the Waylandar widget.")
            sys.exit(0)
    else:
        print("\nGoogle Calendar setup failed.")

def setup_nextcloud(config, first_run=False):
    import getpass
    print("\nStarting Nextcloud Calendar Setup...")
    
    # Backup old config in case of failure or cancellation
    old_nc_config = None
    if "providers" in config and "nextcloud" in config["providers"]:
        old_nc_config = config["providers"]["nextcloud"].copy()
        
    try:
        url = input("Enter Nextcloud CalDAV URL (e.g. https://domain.com/remote.php/dav): ").strip()
        username = input("Enter Username: ").strip()
        password = getpass.getpass("Enter App Password: ").strip()
        
        if "providers" not in config:
            config["providers"] = {}
        if "nextcloud" not in config["providers"]:
            config["providers"]["nextcloud"] = {}
            
        config["providers"]["nextcloud"]["url"] = url
        config["providers"]["nextcloud"]["username"] = username
        config["providers"]["nextcloud"]["password"] = password
        
        # Save config temporarily so caldav.setup() can read it to verify
        save_config(config)
        
        from providers import caldav
        success = caldav.setup(is_background=False, provider_key="nextcloud")
        
        if success:
            config["active_provider"] = "nextcloud"
            save_config(config)
            print("\nSuccessfully authenticated with Nextcloud Calendar!")
            if first_run:
                print("You can now safely close this terminal and use the Waylandar widget.")
                sys.exit(0)
        else:
            print("\nNextcloud Calendar setup failed.")
            # Revert config to backup since verification failed
            if old_nc_config is not None:
                config["providers"]["nextcloud"] = old_nc_config
                save_config(config)
                
    except (KeyboardInterrupt, EOFError):
        print("\n\nSetup cancelled. Restoring previous configuration if available.")
        if old_nc_config is not None:
            if "providers" not in config:
                config["providers"] = {}
            config["providers"]["nextcloud"] = old_nc_config
            save_config(config)
        sys.exit(1)

def setup_icloud(config, first_run=False):
    import getpass
    print("\nStarting Apple iCloud Setup...")
    print("Note: You MUST use an App-Specific Password generated from your Apple ID settings, NOT your main password.")
    
    old_ic_config = None
    if "providers" in config and "icloud" in config["providers"]:
        old_ic_config = config["providers"]["icloud"].copy()
        
    try:
        # iCloud CalDAV standard URL
        url = "https://caldav.icloud.com/"
        username = input("Enter your Apple ID Email: ").strip()
        password = getpass.getpass("Enter App-Specific Password: ").strip()
        
        if "providers" not in config:
            config["providers"] = {}
        if "icloud" not in config["providers"]:
            config["providers"]["icloud"] = {}
            
        config["providers"]["icloud"]["url"] = url
        config["providers"]["icloud"]["username"] = username
        config["providers"]["icloud"]["password"] = password
        
        save_config(config)
        
        from providers import caldav
        success = caldav.setup(is_background=False, provider_key="icloud")
        
        if success:
            config["active_provider"] = "icloud"
            save_config(config)
            print("\nSuccessfully authenticated with Apple iCloud!")
            if first_run:
                print("You can now safely close this terminal and use the Waylandar widget.")
                sys.exit(0)
        else:
            print("\niCloud setup failed. Make sure you are using an App-Specific Password!")
            if old_ic_config is not None:
                config["providers"]["icloud"] = old_ic_config
                save_config(config)
                
    except (KeyboardInterrupt, EOFError):
        print("\n\nSetup cancelled. Restoring previous configuration if available.")
        if old_ic_config is not None:
            if "providers" not in config:
                config["providers"] = {}
            config["providers"]["icloud"] = old_ic_config
            save_config(config)
        sys.exit(1)

def clear_ics_feeds(config):
    if "providers" in config and "ics" in config["providers"]:
        config["providers"]["ics"]["feeds"] = []
        save_config(config)
        print(f"\n{C_GREEN}Successfully cleared all ICS feeds!{C_END}")
    else:
        print(f"\n{C_WARN}No ICS feeds to clear.{C_END}")

def manage_ics_feeds(config):
    feeds = config.get("providers", {}).get("ics", {}).get("feeds", [])
    if not feeds:
        print(f"\n{C_WARN}No ICS feeds configured.{C_END}")
        return
        
    print(f"\n{C_HEADER}--- Managed ICS Feeds ---{C_END}")
    for i, feed in enumerate(feeds):
        url_trunc = feed.get('url', '')
        if len(url_trunc) > 40:
            url_trunc = url_trunc[:37] + "..."
        print(f"  {C_BOLD}[{i+1}]{C_END} {C_CYAN}{feed.get('name', 'Unnamed')}{C_END} ({url_trunc})")
        
    print(f"  {C_BOLD}[{len(feeds)+1}]{C_END} Cancel")
    print(f"  {C_BOLD}[{len(feeds)+2}]{C_END} {C_FAIL}Clear ALL Feeds{C_END}")
    
    choice = input(f"\n{C_BOLD}Enter the number of the feed to REMOVE, or choose an option:{C_END} ").strip()
    
    try:
        idx = int(choice) - 1
        if idx == len(feeds):
            return
        elif idx == len(feeds) + 1:
            clear_ics_feeds(config)
        elif 0 <= idx < len(feeds):
            removed = feeds.pop(idx)
            save_config(config)
            print(f"\n{C_GREEN}Removed ICS Feed: {C_BOLD}{removed.get('name', 'Unnamed')}{C_END}")
        else:
            print(f"\n{C_FAIL}Invalid choice.{C_END}")
    except ValueError:
        print(f"\n{C_FAIL}Invalid input.{C_END}")

def setup_ics(config, first_run=False):
    print(f"\n{C_HEADER}Starting ICS Subscription Setup...{C_END}")
    print(f"{C_BLUE}Note: ICS links are read-only and usually start with http:// or webcal://{C_END}")
    
    old_ics_config = None
    if "providers" in config and "ics" in config["providers"]:
        old_ics_config = config["providers"]["ics"].copy()
        
    try:
        url = input(f"{C_CYAN}Enter public ICS / Webcal Link:{C_END} ").strip()
        if url.startswith("webcal://"):
            url = url.replace("webcal://", "https://", 1)
            
        name = input(f"{C_CYAN}Enter a custom name for this calendar (e.g. Proton, Outlook, Yahoo, etc.):{C_END} ").strip()
        if not name:
            name = "ICS Calendar"
            
        if "providers" not in config:
            config["providers"] = {}
        if "ics" not in config["providers"]:
            config["providers"]["ics"] = {}
        if "feeds" not in config["providers"]["ics"]:
            config["providers"]["ics"]["feeds"] = []
            
        config["providers"]["ics"]["feeds"].append({
            "url": url,
            "name": name
        })
        
        save_config(config)
        
        from providers import ics
        success = ics.setup(is_background=False)
        
        if success:
            config["active_provider"] = "ics"
            save_config(config)
            print("\nSuccessfully subscribed to the ICS Feed!")
            if first_run:
                print("You can now safely close this terminal and use the Waylandar widget.")
                sys.exit(0)
        else:
            print("\nICS setup failed. Make sure the URL is accessible and returns valid iCalendar data.")
            if old_ics_config is not None:
                config["providers"]["ics"] = old_ics_config
                save_config(config)
                
    except (KeyboardInterrupt, EOFError):
        print("\n\nSetup cancelled. Restoring previous configuration if available.")
        if old_ics_config is not None:
            if "providers" not in config:
                config["providers"] = {}
            config["providers"]["ics"] = old_ics_config
            save_config(config)
        sys.exit(1)
    
if __name__ == '__main__':
    if '--background' in sys.argv:
        background_sync()
    else:
        interactive_wizard()
