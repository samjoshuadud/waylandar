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

def setup(is_background=False, force_reauth=False, account_id=None):
    import uuid
    config_dir = os.path.expanduser('~/.config/waylandar')
    cache_dir = os.path.expanduser('~/.cache/waylandar')
    
    os.makedirs(config_dir, exist_ok=True)
    os.makedirs(cache_dir, exist_ok=True)
    
    creds_path = os.path.join(config_dir, 'credentials.json')
    
    if not account_id:
        account_id = str(uuid.uuid4())
        
    token_path = os.path.join(cache_dir, f'token_{account_id}.json')
    creds = None

    backup_path = token_path + '.bak'
    if force_reauth and os.path.exists(token_path):
        try:
            os.rename(token_path, backup_path)
        except OSError:
            pass

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
                    return False, None, None

            if is_background:
                error_msg = "Google Auth Required/Expired.\nPlease run this in your terminal:\n\nwaylandar\n(or 'uv run python sync.py' if installed manually)"
                print(json.dumps({"error": error_msg}))
                sys.exit(1)

            try:
                flow = InstalledAppFlow.from_client_secrets_file(creds_path, SCOPES)
                creds = flow.run_local_server(port=0)
            except BaseException as e:
                if isinstance(e, KeyboardInterrupt):
                    print("\nAuthentication cancelled by user.")
                else:
                    print(f"Authentication failed: {e}")
                    
                if force_reauth and os.path.exists(backup_path):
                    try:
                        os.rename(backup_path, token_path)
                    except OSError:
                        pass
                
                if isinstance(e, KeyboardInterrupt):
                    sys.exit(1)
                return False, None, None

            if force_reauth and os.path.exists(backup_path):
                try:
                    os.remove(backup_path)
                except OSError:
                    pass

        with open(token_path, 'w') as token:
            token.write(creds.to_json())

    # Fetch primary calendar ID (which is the email address)
    email = "Google Account"
    try:
        service = build('calendar', 'v3', credentials=creds)
        primary_cal = service.calendarList().get(calendarId='primary').execute()
        email = primary_cal.get('id', 'Google Account')
    except Exception:
        pass

    return True, account_id, email

def fetch(account_id, account_name, year=None, month=None):
    cache_dir = os.path.expanduser('~/.cache/waylandar')
    token_path = os.path.join(cache_dir, f'token_{account_id}.json')
    
    if not os.path.exists(token_path):
        return {"events": [], "calendars": []}
    
    try:
        creds = Credentials.from_authorized_user_file(token_path, SCOPES)
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        service = build('calendar', 'v3', credentials=creds)
    except Exception as e:
        return {"events": [], "calendars": [], "error": f"Google Auth Error for {account_name}: {str(e)}"}

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
    
    try:
        cals = service.calendarList().list().execute().get('items', [])
    except Exception as e:
        return {"events": [], "calendars": [], "error": f"Failed to list calendars: {str(e)}"}
    
    all_events = []
    
    def callback(request_id, response, exception):
        if exception:
            return
        cal_meta = next((c for c in cals if c['id'] == request_id), {})
        cal_name = cal_meta.get('summary', 'Google')
        cal_color = cal_meta.get('backgroundColor', '#4285F4')
        
        for event in response.get('items', []):
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
            
            all_events.append({
                "title": event.get('summary', 'Busy'),
                "description": event.get('description', ''),
                "start": start,
                "end": end,
                "link": event.get('htmlLink', ''),
                "reminders": sorted(reminders_list),
                "calendar_id": request_id,
                "calendar_name": cal_name,
                "calendar_color": cal_color,
                "account_id": account_id
            })

    batch = service.new_batch_http_request(callback=callback)
    
    output_calendars = []
    for c in cals:
        output_calendars.append({
            "id": c['id'],
            "name": c.get('summary', 'Google'),
            "color": c.get('backgroundColor', '#4285F4'),
            "selected": c.get('selected', False),
            "account_id": account_id,
            "account_name": account_name
        })
        
        req = service.events().list(
            calendarId=c['id'],
            timeMin=timeMin,
            timeMax=timeMax,
            maxResults=250,
            singleEvents=True,
            orderBy='startTime'
        )
        batch.add(req, request_id=c['id'])
        
    try:
        batch.execute()
    except Exception:
        pass
        
    all_events.sort(key=lambda x: x['start'])
    
    return {
        "events": all_events,
        "calendars": output_calendars
    }
