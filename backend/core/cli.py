import os
import sys
import uuid
import getpass
from .config import (
    load_config, save_config, CONFIG_PATH,
    C_HEADER, C_BLUE, C_CYAN, C_GREEN, C_WARN, C_FAIL, C_END, C_BOLD
)

def print_dashboard(config):
    print(f"\n{C_HEADER}--- Waylandar Calendar Setup ---{C_END}")
    print(f"{C_CYAN}Configured Accounts & Sources:{C_END}")
    
    has_accounts = False
    providers = config.get("providers", {})
    
    # 1. Google
    google_accounts = providers.get("google", {}).get("accounts", [])
    for acc in google_accounts:
        has_accounts = True
        status = f"{C_GREEN}[Enabled]{C_END}" if acc.get("enabled", True) else f"{C_WARN}[Disabled]{C_END}"
        print(f"  - Google: {C_BOLD}{acc.get('email')}{C_END} ({acc.get('name')}) {status}")
        
    # 2. Nextcloud
    nc_accounts = providers.get("nextcloud", {}).get("accounts", [])
    for acc in nc_accounts:
        has_accounts = True
        status = f"{C_GREEN}[Enabled]{C_END}" if acc.get("enabled", True) else f"{C_WARN}[Disabled]{C_END}"
        print(f"  - Nextcloud: {C_BOLD}{acc.get('username')}{C_END} ({acc.get('name')}) {status}")
        
    # 3. iCloud
    ic_accounts = providers.get("icloud", {}).get("accounts", [])
    for acc in ic_accounts:
        has_accounts = True
        status = f"{C_GREEN}[Enabled]{C_END}" if acc.get("enabled", True) else f"{C_WARN}[Disabled]{C_END}"
        print(f"  - iCloud: {C_BOLD}{acc.get('username')}{C_END} ({acc.get('name')}) {status}")
        
    # 4. ICS
    ics_feeds = providers.get("ics", {}).get("feeds", [])
    for feed in ics_feeds:
        has_accounts = True
        status = f"{C_GREEN}[Enabled]{C_END}" if feed.get("enabled", True) else f"{C_WARN}[Disabled]{C_END}"
        url_trunc = feed.get('url', '')
        if len(url_trunc) > 30:
            url_trunc = url_trunc[:27] + "..."
        print(f"  - ICS Feed: {C_BOLD}{feed.get('name')}{C_END} ({url_trunc}) {status}")
        
    # 5. Local directories (vdirsyncer)
    vdir_dirs = providers.get("vdirsyncer", {}).get("directories", [])
    for directory in vdir_dirs:
        has_accounts = True
        status = f"{C_GREEN}[Enabled]{C_END}" if directory.get("enabled", True) else f"{C_WARN}[Disabled]{C_END}"
        print(f"  - Local Dir: {C_BOLD}{directory.get('name')}{C_END} ({directory.get('path')}) {status}")
        
    if not has_accounts:
        print(f"  {C_WARN}No accounts configured yet!{C_END}")
    print()

def interactive_wizard():
    config = load_config()
    while True:
        print_dashboard(config)
        print(f"{C_CYAN}Select an option to manage:{C_END}")
        print(f"  {C_BOLD}[1]{C_END} Google Accounts")
        print(f"  {C_BOLD}[2]{C_END} Nextcloud Accounts")
        print(f"  {C_BOLD}[3]{C_END} Apple iCloud Accounts")
        print(f"  {C_BOLD}[4]{C_END} ICS Subscriptions")
        print(f"  {C_BOLD}[5]{C_END} Local Directories (.ics files)")
        print(f"  {C_BOLD}[6]{C_END} Change Sync Interval (Current: {config.get('sync_interval', 60)}m)")
        print(f"  {C_BOLD}[7]{C_END} Exit")
        
        choice = input(f"\n{C_BOLD}Select choice:{C_END} ").strip()
        if choice == '1':
            manage_google_submenu(config)
        elif choice == '2':
            manage_nextcloud_submenu(config)
        elif choice == '3':
            manage_icloud_submenu(config)
        elif choice == '4':
            manage_ics_submenu(config)
        elif choice == '5':
            manage_vdirsyncer_submenu(config)
        elif choice == '6':
            change_sync_interval(config)
        elif choice == '7' or choice.lower() == 'q':
            sys.exit(0)
        else:
            print(f"{C_FAIL}Invalid choice.{C_END}")

def select_account_index(accounts):
    print("\nSelect item:")
    for i, acc in enumerate(accounts):
        print(f"  [{i+1}] {acc.get('name')} ({acc.get('email', acc.get('username', acc.get('url', acc.get('path', ''))))})")
    choice = input("Enter number: ").strip()
    try:
        idx = int(choice) - 1
        if 0 <= idx < len(accounts):
            return idx
    except ValueError:
        pass
    print(f"{C_FAIL}Invalid selection.{C_END}")
    return None

def manage_google_submenu(config):
    while True:
        print(f"\n{C_HEADER}--- Manage Google Accounts ---{C_END}")
        accounts = config.setdefault("providers", {}).setdefault("google", {}).setdefault("accounts", [])
        
        if accounts:
            for i, acc in enumerate(accounts):
                status = f"{C_GREEN}[Enabled]{C_END}" if acc.get("enabled", True) else f"{C_WARN}[Disabled]{C_END}"
                print(f"  {C_BOLD}[{i+1}]{C_END} {acc.get('name')} ({acc.get('email')}) {status}")
        else:
            print("  No Google accounts configured.")
            
        print(f"\nOptions:")
        print(f"  {C_BOLD}[A]{C_END} Add a Google Account")
        if accounts:
            print(f"  {C_BOLD}[T]{C_END} Toggle account status (Enable/Disable)")
            print(f"  {C_BOLD}[R]{C_END} Rename account label")
            print(f"  {C_BOLD}[D]{C_END} Delete account")
        print(f"  {C_BOLD}[B]{C_END} Back to main menu")
        
        choice = input(f"\n{C_BOLD}Select option:{C_END} ").strip().lower()
        if choice == 'b':
            break
        elif choice == 'a':
            setup_google(config)
        elif choice == 't' and accounts:
            acc_idx = select_account_index(accounts)
            if acc_idx is not None:
                accounts[acc_idx]["enabled"] = not accounts[acc_idx].get("enabled", True)
                save_config(config)
                print(f"Toggled status of {accounts[acc_idx]['name']}.")
        elif choice == 'r' and accounts:
            acc_idx = select_account_index(accounts)
            if acc_idx is not None:
                new_name = input(f"Enter new name for {accounts[acc_idx]['name']}: ").strip()
                if new_name:
                    accounts[acc_idx]["name"] = new_name
                    save_config(config)
                    print("Account renamed.")
        elif choice == 'd' and accounts:
            acc_idx = select_account_index(accounts)
            if acc_idx is not None:
                confirm = input(f"Are you sure you want to delete {accounts[acc_idx]['name']}? [y/N]: ").strip().lower()
                if confirm == 'y':
                    cache_dir = os.path.expanduser('~/.cache/waylandar')
                    token_path = os.path.join(cache_dir, f"token_{accounts[acc_idx]['id']}.json")
                    if os.path.exists(token_path):
                        try:
                            os.remove(token_path)
                        except OSError:
                            pass
                    del accounts[acc_idx]
                    save_config(config)
                    print("Account deleted.")
        else:
            print(f"{C_FAIL}Invalid option.{C_END}")

def manage_nextcloud_submenu(config):
    while True:
        print(f"\n{C_HEADER}--- Manage Nextcloud Accounts ---{C_END}")
        accounts = config.setdefault("providers", {}).setdefault("nextcloud", {}).setdefault("accounts", [])
        
        if accounts:
            for i, acc in enumerate(accounts):
                status = f"{C_GREEN}[Enabled]{C_END}" if acc.get("enabled", True) else f"{C_WARN}[Disabled]{C_END}"
                print(f"  {C_BOLD}[{i+1}]{C_END} {acc.get('name')} ({acc.get('username')}) {status}")
        else:
            print("  No Nextcloud accounts configured.")
            
        print(f"\nOptions:")
        print(f"  {C_BOLD}[A]{C_END} Add a Nextcloud Account")
        if accounts:
            print(f"  {C_BOLD}[T]{C_END} Toggle account status (Enable/Disable)")
            print(f"  {C_BOLD}[R]{C_END} Rename account label")
            print(f"  {C_BOLD}[D]{C_END} Delete account")
        print(f"  {C_BOLD}[B]{C_END} Back to main menu")
        
        choice = input(f"\n{C_BOLD}Select option:{C_END} ").strip().lower()
        if choice == 'b':
            break
        elif choice == 'a':
            setup_nextcloud(config)
        elif choice == 't' and accounts:
            acc_idx = select_account_index(accounts)
            if acc_idx is not None:
                accounts[acc_idx]["enabled"] = not accounts[acc_idx].get("enabled", True)
                save_config(config)
                print(f"Toggled status.")
        elif choice == 'r' and accounts:
            acc_idx = select_account_index(accounts)
            if acc_idx is not None:
                new_name = input(f"Enter new name: ").strip()
                if new_name:
                    accounts[acc_idx]["name"] = new_name
                    save_config(config)
                    print("Account renamed.")
        elif choice == 'd' and accounts:
            acc_idx = select_account_index(accounts)
            if acc_idx is not None:
                confirm = input(f"Are you sure you want to delete {accounts[acc_idx]['name']}? [y/N]: ").strip().lower()
                if confirm == 'y':
                    del accounts[acc_idx]
                    save_config(config)
                    print("Account deleted.")
        else:
            print(f"{C_FAIL}Invalid option.{C_END}")

def manage_icloud_submenu(config):
    while True:
        print(f"\n{C_HEADER}--- Manage iCloud Accounts ---{C_END}")
        accounts = config.setdefault("providers", {}).setdefault("icloud", {}).setdefault("accounts", [])
        
        if accounts:
            for i, acc in enumerate(accounts):
                status = f"{C_GREEN}[Enabled]{C_END}" if acc.get("enabled", True) else f"{C_WARN}[Disabled]{C_END}"
                print(f"  {C_BOLD}[{i+1}]{C_END} {acc.get('name')} ({acc.get('username')}) {status}")
        else:
            print("  No iCloud accounts configured.")
            
        print(f"\nOptions:")
        print(f"  {C_BOLD}[A]{C_END} Add an iCloud Account")
        if accounts:
            print(f"  {C_BOLD}[T]{C_END} Toggle account status (Enable/Disable)")
            print(f"  {C_BOLD}[R]{C_END} Rename account label")
            print(f"  {C_BOLD}[D]{C_END} Delete account")
        print(f"  {C_BOLD}[B]{C_END} Back to main menu")
        
        choice = input(f"\n{C_BOLD}Select option:{C_END} ").strip().lower()
        if choice == 'b':
            break
        elif choice == 'a':
            setup_icloud(config)
        elif choice == 't' and accounts:
            acc_idx = select_account_index(accounts)
            if acc_idx is not None:
                accounts[acc_idx]["enabled"] = not accounts[acc_idx].get("enabled", True)
                save_config(config)
                print(f"Toggled status.")
        elif choice == 'r' and accounts:
            acc_idx = select_account_index(accounts)
            if acc_idx is not None:
                new_name = input(f"Enter new name: ").strip()
                if new_name:
                    accounts[acc_idx]["name"] = new_name
                    save_config(config)
                    print("Account renamed.")
        elif choice == 'd' and accounts:
            acc_idx = select_account_index(accounts)
            if acc_idx is not None:
                confirm = input(f"Are you sure you want to delete {accounts[acc_idx]['name']}? [y/N]: ").strip().lower()
                if confirm == 'y':
                    del accounts[acc_idx]
                    save_config(config)
                    print("Account deleted.")
        else:
            print(f"{C_FAIL}Invalid option.{C_END}")

def manage_ics_submenu(config):
    while True:
        print(f"\n{C_HEADER}--- Manage ICS Subscriptions ---{C_END}")
        feeds = config.setdefault("providers", {}).setdefault("ics", {}).setdefault("feeds", [])
        
        if feeds:
            for i, feed in enumerate(feeds):
                status = f"{C_GREEN}[Enabled]{C_END}" if feed.get("enabled", True) else f"{C_WARN}[Disabled]{C_END}"
                url_trunc = feed.get('url', '')
                if len(url_trunc) > 40:
                    url_trunc = url_trunc[:37] + "..."
                print(f"  {C_BOLD}[{i+1}]{C_END} {feed.get('name')} ({url_trunc}) {status}")
        else:
            print("  No ICS feeds subscribed.")
            
        print(f"\nOptions:")
        print(f"  {C_BOLD}[A]{C_END} Add another ICS Subscription")
        if feeds:
            print(f"  {C_BOLD}[T]{C_END} Toggle feed status (Enable/Disable)")
            print(f"  {C_BOLD}[R]{C_END} Rename feed label")
            print(f"  {C_BOLD}[D]{C_END} Delete feed subscription")
        print(f"  {C_BOLD}[B]{C_END} Back to main menu")
        
        choice = input(f"\n{C_BOLD}Select option:{C_END} ").strip().lower()
        if choice == 'b':
            break
        elif choice == 'a':
            setup_ics(config)
        elif choice == 't' and feeds:
            feed_idx = select_account_index(feeds)
            if feed_idx is not None:
                feeds[feed_idx]["enabled"] = not feeds[feed_idx].get("enabled", True)
                save_config(config)
                print("Toggled status.")
        elif choice == 'r' and feeds:
            feed_idx = select_account_index(feeds)
            if feed_idx is not None:
                new_name = input("Enter new name: ").strip()
                if new_name:
                    feeds[feed_idx]["name"] = new_name
                    save_config(config)
                    print("Feed renamed.")
        elif choice == 'd' and feeds:
            feed_idx = select_account_index(feeds)
            if feed_idx is not None:
                confirm = input(f"Are you sure you want to delete {feeds[feed_idx]['name']}? [y/N]: ").strip().lower()
                if confirm == 'y':
                    del feeds[feed_idx]
                    save_config(config)
                    print("Feed deleted.")
        else:
            print(f"{C_FAIL}Invalid option.{C_END}")

def manage_vdirsyncer_submenu(config):
    while True:
        print(f"\n{C_HEADER}--- Manage Local Directories ---{C_END}")
        directories = config.setdefault("providers", {}).setdefault("vdirsyncer", {}).setdefault("directories", [])
        
        if directories:
            for i, directory in enumerate(directories):
                status = f"{C_GREEN}[Enabled]{C_END}" if directory.get("enabled", True) else f"{C_WARN}[Disabled]{C_END}"
                print(f"  {C_BOLD}[{i+1}]{C_END} {directory.get('name')} ({directory.get('path')}) {status}")
        else:
            print("  No local directories configured.")
            
        print(f"\nOptions:")
        print(f"  {C_BOLD}[A]{C_END} Add another Local Directory")
        if directories:
            print(f"  {C_BOLD}[T]{C_END} Toggle directory status (Enable/Disable)")
            print(f"  {C_BOLD}[R]{C_END} Rename directory label")
            print(f"  {C_BOLD}[D]{C_END} Delete directory config")
        print(f"  {C_BOLD}[B]{C_END} Back to main menu")
        
        choice = input(f"\n{C_BOLD}Select option:{C_END} ").strip().lower()
        if choice == 'b':
            break
        elif choice == 'a':
            setup_vdirsyncer(config)
        elif choice == 't' and directories:
            dir_idx = select_account_index(directories)
            if dir_idx is not None:
                directories[dir_idx]["enabled"] = not directories[dir_idx].get("enabled", True)
                save_config(config)
                print("Toggled status.")
        elif choice == 'r' and directories:
            dir_idx = select_account_index(directories)
            if dir_idx is not None:
                new_name = input("Enter new name: ").strip()
                if new_name:
                    directories[dir_idx]["name"] = new_name
                    save_config(config)
                    print("Directory renamed.")
        elif choice == 'd' and directories:
            dir_idx = select_account_index(directories)
            if dir_idx is not None:
                confirm = input(f"Are you sure you want to delete {directories[dir_idx]['name']}? [y/N]: ").strip().lower()
                if confirm == 'y':
                    del directories[dir_idx]
                    save_config(config)
                    print("Directory configuration deleted.")
        else:
            print(f"{C_FAIL}Invalid option.{C_END}")

def handle_toggle_account_cli(args):
    if len(args) < 5:
        print("Error: Missing arguments for toggle-account. Usage: waylandar toggle-account <provider> <account_id> <true/false>", file=sys.stderr)
        sys.exit(1)
        
    provider = args[2]
    account_id = args[3]
    enabled_str = args[4].lower()
    enabled = enabled_str in ['true', '1', 'yes', 'on']
    
    config = load_config()
    provider_config = config.setdefault("providers", {}).setdefault(provider, {})
    
    found = False
    
    if provider in ["google", "nextcloud", "icloud"]:
        accounts = provider_config.setdefault("accounts", [])
        for acc in accounts:
            if acc.get("id") == account_id:
                acc["enabled"] = enabled
                found = True
                break
    elif provider == "ics":
        feeds = provider_config.setdefault("feeds", [])
        for feed in feeds:
            if feed.get("url") == account_id:
                feed["enabled"] = enabled
                found = True
                break
    elif provider == "vdirsyncer":
        directories = provider_config.setdefault("directories", [])
        for directory in directories:
            if directory.get("path") == account_id:
                directory["enabled"] = enabled
                found = True
                break
                
    if not found:
        print(f"Error: Account/Source '{account_id}' not found under provider '{provider}'", file=sys.stderr)
        sys.exit(1)
        
    save_config(config)
    print(f"Success: Toggled account '{account_id}' to enabled={enabled}")
    sys.exit(0)

def setup_google(config, first_run=False, force_reauth=False):
    from providers import google
    print("\nStarting Google Calendar Setup...")
    success, acc_id, email = google.setup(is_background=False, force_reauth=force_reauth)
    if success:
        google_prov = config.setdefault("providers", {}).setdefault("google", {})
        accounts = google_prov.setdefault("accounts", [])
        
        # Check duplicates
        duplicate = next((a for a in accounts if a.get("email") == email), None)
        if duplicate:
            print(f"\nWarning: Account for {email} is already configured. Re-authenticating.")
            # Move the newly generated token file to the existing UUID's filename
            cache_dir = os.path.expanduser('~/.cache/waylandar')
            new_token = os.path.join(cache_dir, f"token_{acc_id}.json")
            old_token = os.path.join(cache_dir, f"token_{duplicate['id']}.json")
            if os.path.exists(new_token):
                if os.path.exists(old_token):
                    try:
                        os.remove(old_token)
                    except OSError:
                        pass
                try:
                    os.rename(new_token, old_token)
                except OSError:
                    pass
        else:
            accounts.append({
                "id": acc_id,
                "email": email,
                "name": f"Google - {email}",
                "enabled": True
            })
            
        save_config(config)
        print("\nSuccessfully authenticated with Google Calendar!")
        if first_run:
            print("You can now safely close this terminal and use the Waylandar widget.")
            sys.exit(0)
    else:
        print("\nGoogle Calendar setup failed.")

def setup_nextcloud(config, first_run=False):
    print("\nStarting Nextcloud Calendar Setup...")
    try:
        url = input("Enter Nextcloud CalDAV URL (e.g. https://domain.com/remote.php/dav): ").strip()
        username = input("Enter Username: ").strip()
        password = getpass.getpass("Enter App Password: ").strip()
        
        from providers import caldav
        success = caldav.setup(is_background=False, provider_key="nextcloud", url=url, username=username, password=password)
        
        if success:
            custom_name = input(f"Enter custom label (default: Nextcloud - {username}): ").strip()
            if not custom_name:
                custom_name = f"Nextcloud - {username}"
                
            accounts = config.setdefault("providers", {}).setdefault("nextcloud", {}).setdefault("accounts", [])
            acc_id = str(uuid.uuid4())
            accounts.append({
                "id": acc_id,
                "name": custom_name,
                "url": url,
                "username": username,
                "password": password,
                "enabled": True
            })
            save_config(config)
            print("\nSuccessfully authenticated and added Nextcloud account!")
            if first_run:
                print("You can now safely close this terminal and use the Waylandar widget.")
                sys.exit(0)
        else:
            print("\nNextcloud Calendar connection failed. Please check your credentials.")
    except (KeyboardInterrupt, EOFError):
        print("\n\nSetup cancelled.")

def setup_icloud(config, first_run=False):
    print("\nStarting Apple iCloud Setup...")
    print("Note: You MUST use an App-Specific Password generated from your Apple ID settings, NOT your main password.")
    try:
        url = "https://caldav.icloud.com/"
        username = input("Enter your Apple ID Email: ").strip()
        password = getpass.getpass("Enter App-Specific Password: ").strip()
        
        from providers import caldav
        success = caldav.setup(is_background=False, provider_key="icloud", url=url, username=username, password=password)
        
        if success:
            custom_name = input(f"Enter custom label (default: iCloud - {username}): ").strip()
            if not custom_name:
                custom_name = f"iCloud - {username}"
                
            accounts = config.setdefault("providers", {}).setdefault("icloud", {}).setdefault("accounts", [])
            acc_id = str(uuid.uuid4())
            accounts.append({
                "id": acc_id,
                "name": custom_name,
                "url": url,
                "username": username,
                "password": password,
                "enabled": True
            })
            save_config(config)
            print("\nSuccessfully authenticated and added Apple iCloud account!")
            if first_run:
                print("You can now safely close this terminal and use the Waylandar widget.")
                sys.exit(0)
        else:
            print("\niCloud setup failed. Make sure you are using an App-Specific Password!")
    except (KeyboardInterrupt, EOFError):
        print("\n\nSetup cancelled.")

def setup_ics(config, first_run=False):
    print(f"\n{C_HEADER}Starting ICS Subscription Setup...{C_END}")
    print(f"{C_BLUE}Note: ICS links are read-only and usually start with http:// or webcal://{C_END}")
    try:
        url = input(f"{C_CYAN}Enter public ICS / Webcal Link:{C_END} ").strip()
        if url.startswith("webcal://"):
            url = url.replace("webcal://", "https://", 1)
            
        name = input(f"{C_CYAN}Enter a custom name for this calendar (e.g. Proton, Outlook):{C_END} ").strip()
        if not name:
            name = "ICS Calendar"
            
        feeds = config.setdefault("providers", {}).setdefault("ics", {}).setdefault("feeds", [])
        
        # Prevent duplicates
        if any(f.get("url") == url for f in feeds):
            print(f"{C_WARN}Error: You have already subscribed to this feed URL.{C_END}")
            return
            
        feeds.append({
            "url": url,
            "name": name,
            "enabled": True
        })
        save_config(config)
        print("\nSuccessfully subscribed to the ICS Feed!")
    except (KeyboardInterrupt, EOFError):
        print("\n\nSetup cancelled.")

def setup_vdirsyncer(config, first_run=False):
    print(f"\n{C_HEADER}Starting Local Directory Setup...{C_END}")
    print(f"{C_BLUE}Provide the path to a local directory containing your .ics files.{C_END}")
    try:
        path = input(f"{C_CYAN}Enter directory path (e.g. ~/.local/share/calendars/personal):{C_END} ").strip()
        expanded_path = os.path.expanduser(path)
        
        if not os.path.isdir(expanded_path):
            print(f"{C_FAIL}Error: Directory does not exist! ({expanded_path}){C_END}")
            return
            
        directories = config.setdefault("providers", {}).setdefault("vdirsyncer", {}).setdefault("directories", [])
        existing_paths = [os.path.expanduser(d.get("path", "")) for d in directories]
        if expanded_path in existing_paths:
            print(f"{C_WARN}Error: You have already added this directory!{C_END}")
            return
            
        name = input(f"{C_CYAN}Enter a custom name for this calendar:{C_END} ").strip()
        if not name:
            name = "Local Calendar"
            
        directories.append({
            "path": path,
            "name": name,
            "enabled": True
        })
        save_config(config)
        print(f"\n{C_GREEN}Successfully added local directory!{C_END}")
    except (KeyboardInterrupt, EOFError):
        print("\n\nSetup cancelled.")

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
