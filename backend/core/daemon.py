import json
import sys
from concurrent.futures import ThreadPoolExecutor
from .config import load_config

def background_sync():
    config = load_config()
    
    year = None
    month = None
    args = [arg for arg in sys.argv if arg != '--background']
    if len(args) == 3:
        year = int(args[1])
        month = int(args[2])
        
    tasks = []
    
    # 1. Google Accounts
    google_accounts = config.get("providers", {}).get("google", {}).get("accounts", [])
    enabled_google = [a for a in google_accounts if a.get("enabled", True)]
    if enabled_google:
        from providers import google
        for acc in enabled_google:
            def run_google(a=acc):
                try:
                    # Run setup to refresh tokens if needed
                    google.setup(is_background=True, account_id=a["id"])
                    return google.fetch(a["id"], a["name"], year, month)
                except Exception as e:
                    return {"events": [], "calendars": [], "error": f"Google Account {a.get('name')}: {str(e)}"}
            tasks.append(run_google)
            
    # 2. Nextcloud Accounts
    nc_accounts = config.get("providers", {}).get("nextcloud", {}).get("accounts", [])
    enabled_nc = [a for a in nc_accounts if a.get("enabled", True)]
    if enabled_nc:
        from providers import caldav
        for acc in enabled_nc:
            def run_nc(a=acc):
                try:
                    return caldav.fetch(a["id"], a["name"], a["url"], a["username"], a["password"], year, month)
                except Exception as e:
                    return {"events": [], "calendars": [], "error": f"Nextcloud {a.get('name')}: {str(e)}"}
            tasks.append(run_nc)
            
    # 3. iCloud Accounts
    ic_accounts = config.get("providers", {}).get("icloud", {}).get("accounts", [])
    enabled_ic = [a for a in ic_accounts if a.get("enabled", True)]
    if enabled_ic:
        from providers import caldav
        for acc in enabled_ic:
            def run_ic(a=acc):
                try:
                    return caldav.fetch(a["id"], a["name"], a["url"], a["username"], a["password"], year, month)
                except Exception as e:
                    return {"events": [], "calendars": [], "error": f"iCloud {a.get('name')}: {str(e)}"}
            tasks.append(run_ic)
            
    # 4. ICS Feeds
    ics_feeds = config.get("providers", {}).get("ics", {}).get("feeds", [])
    ics_provider_enabled = config.get("providers", {}).get("ics", {}).get("enabled", True)
    enabled_ics = [f for f in ics_feeds if f.get("enabled", True)] if ics_provider_enabled else []
    if enabled_ics:
        from providers import ics
        def run_ics():
            try:
                return ics.fetch(year, month)
            except Exception as e:
                return {"events": [], "calendars": [], "error": f"ICS Subscriptions: {str(e)}"}
        tasks.append(run_ics)
        
    # 5. Local Directories (Vdirsyncer)
    vdir_dirs = config.get("providers", {}).get("vdirsyncer", {}).get("directories", [])
    vdir_provider_enabled = config.get("providers", {}).get("vdirsyncer", {}).get("enabled", True)
    enabled_vdir = [d for d in vdir_dirs if d.get("enabled", True)] if vdir_provider_enabled else []
    if enabled_vdir:
        from providers import vdirsyncer
        def run_vdir():
            try:
                return vdirsyncer.fetch(year, month)
            except Exception as e:
                return {"events": [], "calendars": [], "error": f"Local Directories: {str(e)}"}
        tasks.append(run_vdir)
        
    if not tasks:
        # No tasks configured or enabled
        print(json.dumps({
            "events": [], 
            "calendars": [], 
            "error": "No calendar accounts configured or enabled.\nPlease run 'waylandar' in terminal to configure accounts."
        }, indent=2))
        return
        
    # Run tasks concurrently using ThreadPoolExecutor
    merged_events = []
    merged_calendars = {}
    errors = []
    
    with ThreadPoolExecutor(max_workers=len(tasks)) as executor:
        futures = [executor.submit(t) for t in tasks]
        for f in futures:
            try:
                res = f.result()
                if not res:
                    continue
                if "error" in res:
                    errors.append(res["error"])
                merged_events.extend(res.get("events", []))
                for c in res.get("calendars", []):
                    c_id = c.get("id")
                    if c_id:
                        merged_calendars[c_id] = c
            except Exception as e:
                errors.append(str(e))
                
    # Sort merged events chronologically
    merged_events.sort(key=lambda x: x.get("start", ""))
    
    output = {
        "events": merged_events,
        "calendars": list(merged_calendars.values())
    }
    if errors:
        output["errors"] = errors
        
    print(json.dumps(output, indent=2))
