import json
import sys
import os
from concurrent.futures import ThreadPoolExecutor
from .config import load_config

def background_sync():
    config = load_config()
    
    year = None
    month = None
    args = [arg for arg in sys.argv if arg != '--background']
    if len(args) == 3:
        try:
            year = int(args[1])
            month = int(args[2])
        except ValueError:
            pass
        
    cache_dir = os.path.expanduser('~/.cache/waylandar')
    y_str = str(year) if year is not None else "current"
    m_str = str(month) if month is not None else "current"
    cache_path = os.path.join(cache_dir, f"cache_{y_str}_{m_str}.json")
    
    previous_cache = {}
    if os.path.exists(cache_path):
        try:
            with open(cache_path, 'r') as f:
                previous_cache = json.load(f)
        except Exception:
            pass

    def recover_from_cache(account_id, feed_url=None):
        recovered_events = []
        recovered_calendars = []
        if not previous_cache:
            return recovered_events, recovered_calendars
        
        prev_events = previous_cache.get("events", [])
        prev_cals = previous_cache.get("calendars", [])
        
        if feed_url:
            recovered_events = [e for e in prev_events if e.get("calendar_id") == feed_url]
            recovered_calendars = [c for c in prev_cals if c.get("id") == feed_url]
        else:
            recovered_events = [e for e in prev_events if e.get("account_id") == account_id]
            recovered_calendars = [c for c in prev_cals if c.get("account_id") == account_id]
            
        return recovered_events, recovered_calendars

    tasks = []
    
    google_accounts = config.get("providers", {}).get("google", {}).get("accounts", [])
    enabled_google = [a for a in google_accounts if a.get("enabled", True)]
    if enabled_google:
        from providers import google
        for acc in enabled_google:
            def run_google(a=acc):
                try:
                    google.setup(is_background=True, account_id=a["id"])
                    res = google.fetch(a["id"], a["name"], year, month)
                    res["account_id"] = a["id"]
                    return res
                except Exception as e:
                    from core.errors import is_network_error
                    is_off = is_network_error(e)
                    return {
                        "events": [], 
                        "calendars": [], 
                        "error": f"Google Account {a.get('name')}: offline ({str(e)})" if is_off else f"Google Account {a.get('name')}: {str(e)}", 
                        "offline": is_off,
                        "account_id": a["id"]
                    }
            tasks.append(run_google)
            
    nc_accounts = config.get("providers", {}).get("nextcloud", {}).get("accounts", [])
    enabled_nc = [a for a in nc_accounts if a.get("enabled", True)]
    if enabled_nc:
        from providers import caldav
        for acc in enabled_nc:
            def run_nc(a=acc):
                try:
                    res = caldav.fetch(a["id"], a["name"], a["url"], a["username"], a["password"], year, month)
                    res["account_id"] = a["id"]
                    return res
                except Exception as e:
                    from core.errors import is_network_error
                    is_off = is_network_error(e)
                    return {
                        "events": [], 
                        "calendars": [], 
                        "error": f"Nextcloud {a.get('name')}: offline ({str(e)})" if is_off else f"Nextcloud {a.get('name')}: {str(e)}", 
                        "offline": is_off,
                        "account_id": a["id"]
                    }
            tasks.append(run_nc)
            
    ic_accounts = config.get("providers", {}).get("icloud", {}).get("accounts", [])
    enabled_ic = [a for a in ic_accounts if a.get("enabled", True)]
    if enabled_ic:
        from providers import caldav
        for acc in enabled_ic:
            def run_ic(a=acc):
                try:
                    res = caldav.fetch(a["id"], a["name"], a["url"], a["username"], a["password"], year, month)
                    res["account_id"] = a["id"]
                    return res
                except Exception as e:
                    from core.errors import is_network_error
                    is_off = is_network_error(e)
                    return {
                        "events": [], 
                        "calendars": [], 
                        "error": f"iCloud {a.get('name')}: offline ({str(e)})" if is_off else f"iCloud {a.get('name')}: {str(e)}", 
                        "offline": is_off,
                        "account_id": a["id"]
                    }
            tasks.append(run_ic)
            
    ics_feeds = config.get("providers", {}).get("ics", {}).get("feeds", [])
    ics_provider_enabled = config.get("providers", {}).get("ics", {}).get("enabled", True)
    enabled_ics = [f for f in ics_feeds if f.get("enabled", True)] if ics_provider_enabled else []
    if enabled_ics:
        from providers import ics
        def run_ics():
            try:
                res = ics.fetch(year, month)
                res["account_id"] = "ics"
                return res
            except Exception as e:
                from core.errors import is_network_error
                is_off = is_network_error(e)
                return {
                    "events": [], 
                    "calendars": [], 
                    "error": f"ICS Subscriptions: offline ({str(e)})" if is_off else f"ICS Subscriptions: {str(e)}", 
                    "offline": is_off,
                    "account_id": "ics"
                }
        tasks.append(run_ics)
        
    vdir_dirs = config.get("providers", {}).get("vdirsyncer", {}).get("directories", [])
    vdir_provider_enabled = config.get("providers", {}).get("vdirsyncer", {}).get("enabled", True)
    enabled_vdir = [d for d in vdir_dirs if d.get("enabled", True)] if vdir_provider_enabled else []
    if enabled_vdir:
        from providers import vdirsyncer
        def run_vdir():
            try:
                res = vdirsyncer.fetch(year, month)
                res["account_id"] = "vdirsyncer"
                return res
            except Exception as e:
                return {
                    "events": [], 
                    "calendars": [], 
                    "error": f"Local Directories: {str(e)}",
                    "account_id": "vdirsyncer"
                }
        tasks.append(run_vdir)
        
    if not tasks:
        print(json.dumps({
            "events": [], 
            "calendars": [], 
            "error": "No calendar accounts configured or enabled.\nPlease run 'waylandar' in terminal to configure accounts."
        }, indent=2))
        return
        
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
                
                if isinstance(res, dict) and "failed_feeds" in res:
                    merged_events.extend(res.get("events", []))
                    for c in res.get("calendars", []):
                        c_id = c.get("id")
                        if c_id:
                            merged_calendars[c_id] = c
                    
                    for ff in res["failed_feeds"]:
                        errors.append(ff["error"])
                        feed_url = ff["feed_url"]
                        rec_events, rec_cals = recover_from_cache("ics", feed_url=feed_url)
                        if rec_events:
                            merged_events.extend(rec_events)
                        if rec_cals:
                            for rc in rec_cals:
                                merged_calendars[rc["id"]] = rc
                        else:
                            merged_calendars[feed_url] = {
                                "id": feed_url,
                                "name": ff["name"],
                                "color": ff["color"],
                                "selected": True,
                                "account_id": "ics",
                                "account_name": "ICS Subscriptions"
                            }
                elif isinstance(res, dict) and "error" in res:
                    errors.append(res["error"])
                    acc_id = res.get("account_id")
                    if acc_id:
                        rec_events, rec_cals = recover_from_cache(acc_id)
                        merged_events.extend(rec_events)
                        for rc in rec_cals:
                            merged_calendars[rc["id"]] = rc
                else:
                    merged_events.extend(res.get("events", []))
                    for c in res.get("calendars", []):
                        c_id = c.get("id")
                        if c_id:
                            merged_calendars[c_id] = c
            except Exception as e:
                errors.append(str(e))
                
    merged_events.sort(key=lambda x: x.get("start", ""))
    
    output = {
        "events": merged_events,
        "calendars": list(merged_calendars.values())
    }
    if errors:
        output["errors"] = errors
        
    os.makedirs(cache_dir, exist_ok=True)
    try:
        with open(cache_path, 'w') as f:
            json.dump(output, f, indent=2)
    except Exception:
        pass
        
    print(json.dumps(output, indent=2))
