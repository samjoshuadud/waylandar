import caldav
import datetime
import calendar
import json
import os
import sys
import icalendar
import recurring_ical_events

def setup(is_background=False):
    config_path = os.path.expanduser('~/.config/waylandar/config.json')
    if not os.path.exists(config_path):
        if is_background:
            print(json.dumps({"error": "Nextcloud config missing. Please run waylandar-auth."}))
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

    nc_config = config.get("providers", {}).get("nextcloud", {})
    url = nc_config.get("url")
    username = nc_config.get("username")
    password = nc_config.get("password")

    if not (url and username and password):
        if is_background:
            print(json.dumps({"error": "Nextcloud credentials incomplete. Please run waylandar-auth."}))
            sys.exit(1)
        return False

    try:
        client = caldav.DAVClient(url=url, username=username, password=password)
        principal = client.principal()
        principal.calendars()
    except Exception as e:
        if is_background:
            print(json.dumps({"error": f"Nextcloud auth failed: {str(e)}"}))
            sys.exit(1)
        return False

    return True

def fetch(year=None, month=None):
    config_path = os.path.expanduser('~/.config/waylandar/config.json')
    with open(config_path, 'r') as f:
        config = json.load(f)

    nc_config = config.get("providers", {}).get("nextcloud", {})
    url = nc_config.get("url")
    username = nc_config.get("username")
    password = nc_config.get("password")

    client = caldav.DAVClient(url=url, username=username, password=password)
    principal = client.principal()
    
    if year is not None and month is not None:
        start_date = datetime.datetime(year, month, 1, 0, 0, 0, tzinfo=datetime.timezone.utc)
        last_day = calendar.monthrange(year, month)[1]
        end_date = datetime.datetime(year, month, last_day, 23, 59, 59, tzinfo=datetime.timezone.utc)
    else:
        now = datetime.datetime.now(datetime.timezone.utc)
        start_date = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        last_day = calendar.monthrange(now.year, now.month)[1]
        end_date = now.replace(day=last_day, hour=23, minute=59, second=59)

    calendars = principal.calendars()
    if not calendars:
        return {"events": [], "calendars": []}
    
    all_events = []
    all_cals_meta = []
    
    # fallback colors if no provided colors from nextcloud
    fallback_colors = ["#4285F4", "#0F9D58", "#F4B400", "#DB4437", "#673AB7", "#00BCD4", "#FF9800", "#9C27B0"]
    
    for i, cal in enumerate(calendars):
        # meta data extrac
        cal_id = str(cal.url)
        cal_name = cal.name if hasattr(cal, 'name') and cal.name else f"Calendar {i+1}"
        
        cal_color = fallback_colors[i % len(fallback_colors)]
        try:
            props = cal.get_properties(['{http://apple.com/ns/ical/}calendar-color'])
            if props and '{http://apple.com/ns/ical/}calendar-color' in props:
                cal_color = props['{http://apple.com/ns/ical/}calendar-color']
        except Exception:
            pass

        all_cals_meta.append({
            "id": cal_id,
            "name": cal_name,
            "color": cal_color,
            "selected": True
        })
        
        try:
            results = cal.date_search(start=start_date, end=end_date, expand=False)
            cal_events = parse_caldav_events(results, start_date, end_date, nc_url=url, cal_id=cal_id)
            all_events.extend(cal_events)
        except Exception:
            # Skip calendars that fail or don't support date_search (like tasks) but idk man
            continue
    
    all_events.sort(key=lambda x: x["start"])
    
    return {
        "events": all_events,
        "calendars": all_cals_meta
    }

def parse_caldav_events(caldav_events_or_ics_strings, start_date, end_date, nc_url="", cal_id=""):
    output = []
    master_cal = icalendar.Calendar()
    
    # Generate fallback calendar link from the CalDAV URL
    fallback_link = ""
    if nc_url:
        fallback_link = nc_url.split('/remote.php')[0] + "/apps/calendar/"
    
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
        has_alarm = False
        
        for component in event.walk():
            if component.name == "VALARM":
                has_alarm = True
                trigger = component.get('TRIGGER')
                if trigger:
                    td = trigger.dt
                    if isinstance(td, datetime.timedelta):
                        minutes_before = int(td.total_seconds() / -60)
                        if minutes_before > 0:
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
                        if minutes_before > 0:
                            reminders_list.append(minutes_before)
                            
        if not has_alarm:
            reminders_list.append(10)
            
        output.append({
            "title": summary,
            "description": description,
            "start": start_iso,
            "end": end_iso,
            "link": url,
            "reminders": sorted(reminders_list),
            "calendar_id": cal_id
        })
        
    return output
