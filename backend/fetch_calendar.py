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

    now = datetime.datetime.utcnow().isoformat() + 'Z'  
    
    events_result = service.events().list(
        calendarId='primary', 
        timeMin=now,
        maxResults=10, 
        singleEvents=True,
        orderBy='startTime'
    ).execute()
    
    events = events_result.get('items', [])
    
    output = []
    for event in events:
        start = event['start'].get('dateTime', event['start'].get('date'))
        end = event['end'].get('dateTime', event['end'].get('date'))
        
        output.append({
            "title": event.get('summary', 'Busy'),
            "start": start,
            "end": end,
            "link": event.get('htmlLink', '')
        })
        
    return output

if __name__ == '__main__':
    creds = authenticate()
    events = get_upcoming_events(creds)
    print(json.dumps(events, indent=2))
