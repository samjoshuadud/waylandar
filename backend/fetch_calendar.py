#!/usr/bin/env python3
import json
import os.path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow

SCOPES = ['https://www.googleapis.com/auth/calendar.readonly']

def authenticate():
    """Shows basic usage of the Google Calendar API.
    Prints the start and name of the next 10 events on the user's calendar.
    """
    creds = None

    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists('credentials.json'):
                print(json.dumps({"error": "Missing credentials.json. Please follow the tutorial to get your API key."}))
                exit(1)

            flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)

        with open('token.json', 'w') as token:
            token.write(creds.to_json())

    return creds

def get_upcoming_events(creds):
    from googleapiclient.discovery import build
    import datetime
    
    service = build('calendar', 'v3', credentials=creds)

    # Get the first day of the current month
    now = datetime.datetime.utcnow()
    start_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0).isoformat() + 'Z'
    
    events_result = service.events().list(
        calendarId='primary', 
        timeMin=start_of_month,
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
    creds = authenticate()
    events = get_upcoming_events(creds)
    print(json.dumps(events, indent=2))
