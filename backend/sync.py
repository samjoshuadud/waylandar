import json
import os
import sys

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
        print(json.dumps({"error": "No calendar configured.\nPlease run this in your terminal:\n\nwaylandar-auth\n(or 'uv run python sync.py' if installed manually)"}))
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
    elif provider == "nextcloud":
        from providers import caldav
        caldav.setup(is_background=True)
        data = caldav.fetch(year, month)
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
        print("Welcome to Waylandar Calendar Setup!")
        print("Which calendar do you want to configure?")
        print("[1] Google")
        print("[2] Nextcloud")
        choice = input("> ").strip()
        if choice == '1':
            setup_google(config, first_run=True)
        elif choice == '2':
            setup_nextcloud(config, first_run=True)
        else:
            print("Invalid choice.")
        return

    while True:
        print("\n--- Waylandar Calendar Setup ---")
        active = config.get("active_provider")
        providers = config.get("providers", {})
        
        print(f"Current active provider: {active if active else 'None'}")
        
        options = []
        if active == "google":
            options.append(("Re-auth Google", lambda: setup_google(config)))
            if "nextcloud" in providers:
                options.append(("Switch to Nextcloud", lambda: switch_provider(config, "nextcloud")))
            else:
                options.append(("Set up Nextcloud", lambda: setup_nextcloud(config)))
        elif active == "nextcloud":
            options.append(("Re-auth Nextcloud", lambda: setup_nextcloud(config)))
            if "google" in providers:
                options.append(("Switch to Google", lambda: switch_provider(config, "google")))
            else:
                options.append(("Set up Google", lambda: setup_google(config)))
        else:
            if "google" in providers:
                options.append(("Switch to Google", lambda: switch_provider(config, "google")))
            else:
                options.append(("Set up Google", lambda: setup_google(config)))
                
            if "nextcloud" in providers:
                options.append(("Switch to Nextcloud", lambda: switch_provider(config, "nextcloud")))
            else:
                options.append(("Set up Nextcloud", lambda: setup_nextcloud(config)))
                
        options.append(("Exit", sys.exit))
        
        for i, (text, _) in enumerate(options, 1):
            print(f"{i}) {text}")
            
        choice = input("> ").strip()
        try:
            idx = int(choice) - 1
            if 0 <= idx < len(options):
                options[idx][1]()
            else:
                print("Invalid choice.")
        except ValueError:
            print("Invalid choice.")

def switch_provider(config, provider):
    config["active_provider"] = provider
    save_config(config)
    print(f"Successfully switched active provider to {provider}.")

def setup_google(config, first_run=False):
    from providers import google
    print("\nStarting Google Calendar Setup...")
    success = google.setup(is_background=False)
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
    success = caldav.setup(is_background=False)
    
    if success:
        config["active_provider"] = "nextcloud"
        save_config(config)
        print("\nSuccessfully authenticated with Nextcloud Calendar!")
        if first_run:
            print("You can now safely close this terminal and use the Waylandar widget.")
            sys.exit(0)
    else:
        print("\nNextcloud Calendar setup failed.")
        # Revert config if first setup? Leaving it is fine, they can re-run.
    
if __name__ == '__main__':
    if '--background' in sys.argv:
        background_sync()
    else:
        interactive_wizard()
