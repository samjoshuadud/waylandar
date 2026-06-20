import json
import os
import os.path
import sys

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow

SCOPES = ['https://www.googleapis.com/auth/calendar.readonly']

def authenticate():
    """Shows basic usage of the Google Calendar API.
    Prints the start and name of the next 10 events on the user's calendar.
    """
    config_dir = os.path.expanduser('~/.config/waylandar')
    cache_dir = os.path.expanduser('~/.cache/waylandar')
    
    os.makedirs(config_dir, exist_ok=True)
    os.makedirs(cache_dir, exist_ok=True)
    
    creds_path = os.path.join(config_dir, 'credentials.json')
    token_path = os.path.join(cache_dir, 'token.json')

    creds = None
    just_authenticated = False

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
                print(json.dumps({"error": f"Missing credentials.json at {creds_path}. Please follow the tutorial to get your API key."}))
                exit(1)

            if '--background' in sys.argv:
                error_msg = "Google Auth Required/Expired.\nPlease run this in your terminal:\n\nwaylandar-auth\n(or 'uv run python fetch_calendar.py' if installed manually)"
                print(json.dumps({"error": error_msg}))
                exit(1)

            flow = InstalledAppFlow.from_client_secrets_file(creds_path, SCOPES)
            creds = flow.run_local_server(port=0)
            just_authenticated = True

        with open(token_path, 'w') as token:
            token.write(creds.to_json())

    return creds, just_authenticated

def get_upcoming_events(creds):
    from googleapiclient.discovery import build
    import sys
    import calendar
    import datetime

    service = build('calendar', 'v3', credentials=creds)

    args = [arg for arg in sys.argv if arg != '--background']

    if len(args) == 3:
        year = int(args[1])
        month = int(args[2])
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
        
        # Extract the user's custom reminders!
        reminders_list = []
        reminders = event.get('reminders', {})
        if reminders.get('useDefault'):
            reminders_list.append(10) # Google's standard default
        else:
            for override in reminders.get('overrides', []):
                if override.get('method') == 'popup':
                    reminders_list.append(override.get('minutes', 10))
        
        output.append({
            "title": event.get('summary', 'Busy'),
            "description": event.get('description', ''), # ADDED FULL DESCRIPTION!
            "start": start,
            "end": end,
            "link": event.get('htmlLink', ''),
            "reminders": reminders_list
        })
        
    return output

if __name__ == '__main__':
    creds, just_authenticated = authenticate()
    
    if just_authenticated:
        print("\nSuccessfully authenticated with Google Calendar!")
        print("You can now safely close this terminal and use the Waylandar widget.")
        sys.exit(0)
        
    events = get_upcoming_events(creds)
    print(json.dumps(events, indent=2))
