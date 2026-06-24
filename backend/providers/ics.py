import json
import os
import sys
import datetime
import calendar
import urllib.request
from providers.caldav import parse_caldav_events

def setup(is_background=False):
    config_path = os.path.expanduser('~/.config/waylandar/config.json')
    if not os.path.exists(config_path):
        if is_background:
            print(json.dumps({"error": "ICS config missing. Please run waylandar."}))
            sys.exit(1)
        return False

    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
    except Exception:
        if is_background:
            print(json.dumps({"error": "Failed to parse config.json."}))
            sys.exit(1)
        return False

    ics_config = config.get("providers", {}).get("ics", {})
    feeds = ics_config.get("feeds", [])
    
    if "url" in ics_config and not feeds:
        feeds.append({"url": ics_config["url"]})

    if not feeds:
        if is_background:
            print(json.dumps({"error": "No ICS feeds configured. Please run waylandar."}))
            sys.exit(1)
        return False

    # Just validate the most recently added feed
    latest_url = feeds[-1].get("url")
    if latest_url:
        try:
            req = urllib.request.Request(latest_url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=10) as response:
                data = response.read().decode('utf-8')
                if "BEGIN:VCALENDAR" not in data:
                    raise Exception("URL does not return a valid iCalendar feed.")
        except Exception as e:
            if is_background:
                print(json.dumps({"error": f"ICS validation failed: {str(e)}"}))
                sys.exit(1)
            return False

    return True

def fetch(year=None, month=None):
    config_path = os.path.expanduser('~/.config/waylandar/config.json')
    with open(config_path, 'r') as f:
        config = json.load(f)

    ics_config = config.get("providers", {}).get("ics", {})
    feeds = ics_config.get("feeds", [])
    
    # Backwards compatibility
    if "url" in ics_config and not feeds:
        feeds.append({
            "url": ics_config["url"],
            "name": ics_config.get("name", "ICS Calendar"),
            "color": ics_config.get("color", "#9C27B0")
        })

    if year is not None and month is not None:
        start_date = datetime.datetime(year, month, 1, 0, 0, 0, tzinfo=datetime.timezone.utc)
        last_day = calendar.monthrange(year, month)[1]
        end_date = datetime.datetime(year, month, last_day, 23, 59, 59, tzinfo=datetime.timezone.utc)
    else:
        now = datetime.datetime.now(datetime.timezone.utc)
        start_date = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        last_day = calendar.monthrange(now.year, now.month)[1]
        end_date = now.replace(day=last_day, hour=23, minute=59, second=59)

    from concurrent.futures import ThreadPoolExecutor

    colors = ["#9C27B0", "#E91E63", "#00BCD4", "#FF9800", "#4CAF50", "#3F51B5"]
    
    def fetch_feed(item):
        idx, feed = item
        if not feed.get("enabled", True):
            return None
            
        url = feed.get("url")
        if not url:
            return None
            
        cal_name = feed.get("name", f"Feed {idx+1}")
        cal_color = feed.get("color", colors[idx % len(colors)])
        
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=10) as response:
                ics_data = response.read().decode('utf-8')

            events = parse_caldav_events([ics_data], start_date, end_date, cal_id=url, cal_name=cal_name, cal_color=cal_color, account_id="ics")
            meta = {
                "id": url,
                "name": cal_name,
                "color": cal_color,
                "selected": True,
                "account_id": "ics",
                "account_name": "ICS Subscriptions"
            }
            return meta, events
        except Exception:
            return None

    all_cal_events = []
    all_cals_meta = []

    with ThreadPoolExecutor(max_workers=min(len(feeds), 10)) as executor:
        results = list(executor.map(fetch_feed, enumerate(feeds)))
        
    for res in results:
        if res:
            meta, events = res
            all_cals_meta.append(meta)
            all_cal_events.extend(events)
            
    all_cal_events.sort(key=lambda x: x["start"])

    return {
        "events": all_cal_events,
        "calendars": all_cals_meta
    }
