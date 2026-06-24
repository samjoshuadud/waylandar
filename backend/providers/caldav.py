import caldav
import datetime
import calendar
import json
import os
import sys
import icalendar
import recurring_ical_events

def setup(is_background=False, provider_key="nextcloud", url=None, username=None, password=None):
    if url and username and password:
        try:
            client = caldav.DAVClient(url=url, username=username, password=password, timeout=10)
            principal = client.principal()
            principal.calendars()
            return True
        except Exception:
            return False

    name = provider_key.capitalize()
    config_path = os.path.expanduser('~/.config/waylandar/config.json')
    if not os.path.exists(config_path):
        if is_background:
            print(json.dumps({"error": f"{name} config missing. Please run waylandar."}))
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

    accounts = config.get("providers", {}).get(provider_key, {}).get("accounts", [])
    if not accounts:
        if is_background:
            print(json.dumps({"error": f"No {name} accounts configured. Please run waylandar."}))
            sys.exit(1)
        return False

    enabled_accounts = [a for a in accounts if a.get("enabled", True)]
    if not enabled_accounts:
        return True

    for acc in enabled_accounts:
        try:
            client = caldav.DAVClient(url=acc.get("url"), username=acc.get("username"), password=acc.get("password"), timeout=10)
            principal = client.principal()
            principal.calendars()
        except Exception as e:
            if is_background:
                print(json.dumps({"error": f"{name} auth failed for {acc.get('name')}: {str(e)}"}))
                sys.exit(1)
            return False

    return True

def fetch(account_id, account_name, url, username, password, year=None, month=None):
    try:
        client = caldav.DAVClient(url=url, username=username, password=password, timeout=10)
        principal = client.principal()
    except Exception as e:
        return {"events": [], "calendars": [], "error": f"CalDAV connection failed for {account_name}: {str(e)}"}

    if year is not None and month is not None:
        start_date = datetime.datetime(year, month, 1, 0, 0, 0, tzinfo=datetime.timezone.utc)
        last_day = calendar.monthrange(year, month)[1]
        end_date = datetime.datetime(year, month, last_day, 23, 59, 59, tzinfo=datetime.timezone.utc)
    else:
        now = datetime.datetime.now(datetime.timezone.utc)
        start_date = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        last_day = calendar.monthrange(now.year, now.month)[1]
        end_date = now.replace(day=last_day, hour=23, minute=59, second=59)

    try:
        calendars = principal.calendars()
    except Exception as e:
        return {"events": [], "calendars": [], "error": f"Failed to list calendars: {str(e)}"}
        
    if not calendars:
        return {"events": [], "calendars": []}
    
    from concurrent.futures import ThreadPoolExecutor

    fallback_colors = ["#4285F4", "#0F9D58", "#F4B400", "#DB4437", "#673AB7", "#00BCD4", "#FF9800", "#9C27B0"]
    
    def fetch_cal_data(item):
        i, cal = item
        cal_id = str(cal.url)
        cal_name = cal.name if hasattr(cal, 'name') and cal.name else f"Calendar {i+1}"
        
        cal_color = fallback_colors[i % len(fallback_colors)]
        try:
            props = cal.get_properties(['{http://apple.com/ns/ical/}calendar-color'])
            if props and '{http://apple.com/ns/ical/}calendar-color' in props:
                cal_color = props['{http://apple.com/ns/ical/}calendar-color']
                if cal_color and len(cal_color) == 9 and cal_color.startswith('#'):
                    cal_color = cal_color[:7]
        except Exception:
            pass

        meta = {
            "id": cal_id,
            "name": cal_name,
            "color": cal_color,
            "selected": True,
            "account_id": account_id,
            "account_name": account_name
        }
        
        events = []
        try:
            results = cal.date_search(start=start_date, end=end_date, expand=False)
            events = parse_caldav_events(
                results, start_date, end_date, 
                nc_url=url, cal_id=cal_id, cal_name=cal_name, cal_color=cal_color,
                account_id=account_id
            )
        except Exception:
            pass
            
        return meta, events

    all_events = []
    all_cals_meta = []

    with ThreadPoolExecutor(max_workers=min(len(calendars), 10)) as executor:
        results = list(executor.map(fetch_cal_data, enumerate(calendars)))
        
    for meta, events in results:
        all_cals_meta.append(meta)
        all_events.extend(events)
    
    all_events.sort(key=lambda x: x["start"])
    
    return {
        "events": all_events,
        "calendars": all_cals_meta
    }


def parse_caldav_events(caldav_events_or_ics_strings, start_date, end_date, nc_url="", cal_id="", cal_name="", cal_color="", account_id=""):
    output = []
    master_cal = icalendar.Calendar()
    
    # Generate fallback calendar link from the CalDAV URL
    fallback_link = ""
    if nc_url:
        if "icloud.com" in nc_url:
            fallback_link = "https://www.icloud.com/calendar/"
        elif "/remote.php" in nc_url:
            fallback_link = nc_url.split('/remote.php')[0] + "/apps/calendar/"
        else:
            fallback_link = nc_url
    
    for ev in caldav_events_or_ics_strings:
        if isinstance(ev, str):
            ics_data = ev
        else:
            ics_data = ev.data
            
        try:
            cal = icalendar.Calendar.from_ical(ics_data)
            for component in cal.walk():
                if component.name == "VEVENT":
                    master_cal.add_component(component)
        except Exception:
            pass

    events = recurring_ical_events.of(master_cal).between(start_date, end_date)
    
    for event in events:
        summary = str(event.get('SUMMARY', 'Busy'))
        description = str(event.get('DESCRIPTION', ''))
        
        # Use event URL if exists, otherwise fallback to the Nextcloud Calendar web UI
        url = str(event.get('URL', ''))
        if not url or url == "None":
            url = fallback_link
        
        dtstart = event.get('DTSTART')
        dtend = event.get('DTEND')
        
        if not dtstart:
            continue
            
        start_val = dtstart.dt
        start_iso = start_val.isoformat()
            
        if dtend:
            end_val = dtend.dt
            end_iso = end_val.isoformat()
        else:
            end_iso = start_iso
            
        reminders_list = []
        
        for component in event.walk():
            if component.name == "VALARM":
                trigger = component.get('TRIGGER')
                if trigger:
                    td = trigger.dt
                    if isinstance(td, datetime.timedelta):
                        minutes_before = int(td.total_seconds() / -60)
                        if minutes_before >= 0:
                            reminders_list.append(minutes_before)
                    elif isinstance(td, datetime.datetime):
                        # Calculate difference from event start time
                        # Ensure both are offset-aware or offset-naive before subtracting
                        s_val = start_val
                        if s_val.tzinfo is not None and td.tzinfo is None:
                            td = td.replace(tzinfo=datetime.timezone.utc)
                        elif s_val.tzinfo is None and td.tzinfo is not None:
                            s_val = s_val.replace(tzinfo=datetime.timezone.utc)
                            
                        diff = s_val - td
                        minutes_before = int(diff.total_seconds() / 60)
                        if minutes_before >= 0:
                            reminders_list.append(minutes_before)
            
        output.append({
            "title": summary,
            "description": description,
            "start": start_iso,
            "end": end_iso,
            "link": url,
            "reminders": sorted(reminders_list),
            "calendar_id": cal_id,
            "calendar_name": cal_name,
            "calendar_color": cal_color,
            "account_id": account_id
        })
        
    return output
