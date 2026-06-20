import json
import os
import sys
import calendar
import datetime

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

SCOPES = ['https://www.googleapis.com/auth/calendar.readonly']

def setup(is_background=False):
    config_dir = os.path.expanduser('~/.config/waylandar')
    cache_dir = os.path.expanduser('~/.cache/waylandar')
    
    os.makedirs(config_dir, exist_ok=True)
    os.makedirs(cache_dir, exist_ok=True)
    
    creds_path = os.path.join(config_dir, 'credentials.json')
    token_path = os.path.join(cache_dir, 'token.json')

    creds = None

    if os.path.exists(token_path):
        creds = Credentials.from_authorized_user_file(token_path, SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except Exception:
                creds = None
        
        if not creds or not creds.valid:
            if not os.path.exists(creds_path):
                if is_background:
                    print(json.dumps({"error": f"Missing credentials.json at {creds_path}. Please follow the tutorial."}))
                    sys.exit(1)
                else:
                    print(f"Error: Missing credentials.json at {creds_path}.")
                    print("Please follow the README tutorial to get your API key.")
                    return False

            if is_background:
                error_msg = "Google Auth Required/Expired.\nPlease run this in your terminal:\n\nwaylandar-auth\n(or 'uv run python sync.py' if installed manually)"
                print(json.dumps({"error": error_msg}))
                sys.exit(1)

            try:
                flow = InstalledAppFlow.from_client_secrets_file(creds_path, SCOPES)
                creds = flow.run_local_server(port=0)
            except Exception as e:
                print(f"Authentication failed: {e}")
                return False

        with open(token_path, 'w') as token:
            token.write(creds.to_json())

    return True

def fetch(year=None, month=None):
    cache_dir = os.path.expanduser('~/.cache/waylandar')
    token_path = os.path.join(cache_dir, 'token.json')
    
    creds = Credentials.from_authorized_user_file(token_path, SCOPES)
    service = build('calendar', 'v3', credentials=creds)

    if year is not None and month is not None:
        start_date = datetime.datetime(year, month, 1, 0, 0, 0, tzinfo=datetime.timezone.utc)
        last_day = calendar.monthrange(year, month)[1]
        end_date = datetime.datetime(year, month, last_day, 23, 59, 59, tzinfo=datetime.timezone.utc)
    else:
        now = datetime.datetime.now(datetime.timezone.utc)
        start_date = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        last_day = calendar.monthrange(now.year, now.month)[1]
        end_date = now.replace(day=last_day, hour=23, minute=59, second=59)
    
    timeMin = start_date.isoformat()
    timeMax = end_date.isoformat()
    
    events_result = service.events().list(
        calendarId='primary', 
        timeMin=timeMin,
        timeMax=timeMax,
        maxResults=250, 
        singleEvents=True,
        orderBy='startTime'
    ).execute()
    
    events = events_result.get('items', [])
    
    output = []
    for event in events:
        start = event['start'].get('dateTime', event['start'].get('date'))
        end = event['end'].get('dateTime', event['end'].get('date'))
        
        reminders_list = []
        reminders = event.get('reminders', {})
        if reminders.get('useDefault'):
            reminders_list.append(10)
        else:
            for override in reminders.get('overrides', []):
                if override.get('method') == 'popup':
                    reminders_list.append(override.get('minutes', 10))
        
        output.append({
            "title": event.get('summary', 'Busy'),
            "description": event.get('description', ''),
            "start": start,
            "end": end,
            "link": event.get('htmlLink', ''),
            "reminders": reminders_list
        })
        
    return output
