import os
import sys
import json
import datetime
import calendar
from .caldav import parse_caldav_events

def setup(is_background=False):
    config_path = os.path.expanduser('~/.config/waylandar/config.json')
    if not os.path.exists(config_path):
        if not is_background:
            print("Config file not found.")
            sys.exit(1)
        return False
        
    with open(config_path, 'r') as f:
        config = json.load(f)
        
    vdir_config = config.get("providers", {}).get("vdirsyncer", {})
    if not vdir_config.get("directories"):
        if not is_background:
            print("No vdirsyncer directories configured.")
            sys.exit(1)
        return False

    return True

def fetch(year=None, month=None):
    config_path = os.path.expanduser('~/.config/waylandar/config.json')
    with open(config_path, 'r') as f:
        config = json.load(f)

    directories = config.get("providers", {}).get("vdirsyncer", {}).get("directories", [])

    if year is not None and month is not None:
        start_date = datetime.datetime(year, month, 1, 0, 0, 0, tzinfo=datetime.timezone.utc)
        last_day = calendar.monthrange(year, month)[1]
        end_date = datetime.datetime(year, month, last_day, 23, 59, 59, tzinfo=datetime.timezone.utc)
    else:
        now = datetime.datetime.now(datetime.timezone.utc)
        start_date = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        last_day = calendar.monthrange(now.year, now.month)[1]
        end_date = now.replace(day=last_day, hour=23, minute=59, second=59)

    all_cal_events = []
    all_cals_meta = []
    colors = ["#FF5722", "#607D8B", "#795548", "#8BC34A", "#CDDC39", "#009688"]

    for idx, dir_info in enumerate(directories):
        if not dir_info.get("enabled", True):
            continue
            
        folder_path = os.path.expanduser(dir_info.get("path", ""))
        if not os.path.isdir(folder_path):
            continue
            
        cal_name = dir_info.get("name", f"Local Calendar {idx+1}")
        cal_color = dir_info.get("color", colors[idx % len(colors)])
        
        all_cals_meta.append({
            "id": folder_path,
            "name": cal_name,
            "color": cal_color,
            "read_only": True,
            "account_id": "vdirsyncer",
            "account_name": "Local Directories"
        })
        
        ics_data_list = []
        visited_dirs = set()
        
        # Scan the directory and read all .ics files
        for root, dirs, files in os.walk(folder_path, followlinks=True):
            # Prevent infinite recursion from circular symlinks
            real_root = os.path.realpath(root)
            if real_root in visited_dirs:
                dirs[:] = [] # Stop traversing this branch
                continue
            visited_dirs.add(real_root)
            
            # Ignore hidden directories (e.g. .git, .vdirsyncer metadata)
            dirs[:] = [d for d in dirs if not d.startswith('.')]
            
            for file in files:
                if file.endswith(".ics"):
                    file_path = os.path.join(root, file)
                    try:
                        # Ensure it's a regular file and not a named pipe/device
                        if not os.path.isfile(file_path):
                            continue
                            
                        # Prevent memory exhaustion from massive files (Limit: 50MB)
                        if os.path.getsize(file_path) > 50 * 1024 * 1024:
                            print(f"Warning: {file_path} exceeds 50MB limit. Skipping.", file=sys.stderr)
                            continue
                            
                        try:
                            with open(file_path, 'r', encoding='utf-8') as ics_file:
                                content = ics_file.read()
                        except UnicodeDecodeError:
                            # Fallback for legacy systems (e.g. older Outlook exports)
                            with open(file_path, 'r', encoding='latin-1') as ics_file:
                                content = ics_file.read()
                        ics_data_list.append(content)
                    except Exception as e:
                        print(f"Error reading {file_path}: {e}", file=sys.stderr)
        
        if ics_data_list:
            cal_events = parse_caldav_events(
                ics_data_list, start_date, end_date, 
                cal_id=folder_path, cal_name=cal_name, cal_color=cal_color,
                account_id="vdirsyncer"
            )
            all_cal_events.extend(cal_events)

    all_cal_events.sort(key=lambda x: x["start"])
    return {"events": all_cal_events, "calendars": all_cals_meta}
