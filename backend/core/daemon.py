import json
import sys
from .config import load_config

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
    elif provider == "vdirsyncer":
        from providers import vdirsyncer
        vdirsyncer.setup(is_background=True)
        data = vdirsyncer.fetch(year, month)
        if isinstance(data, list):
            data = {"events": data, "calendars": []}
        print(json.dumps(data, indent=2))
    else:
        print(json.dumps({"error": f"Unknown provider: {provider}"}))
        sys.exit(1)
