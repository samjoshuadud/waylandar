import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components" as Components

ShellRoot {
    property var calendarEvents: []
    property int minutesUntilSync: 60
    property int calendarCount: 0
    property string authError: ""


    property var selectedCalendarIds: ({})

    Process {
        id: loadSelectedCals
        command: ["sh", "-c", "cat ~/.cache/waylandar/selected_cals.json 2>/dev/null || echo ''"]
        running: true
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (text.trim() !== "") {
                    try {
                        selectedCalendarIds = JSON.parse(text);
                    } catch (e) {}
                }
            }
        }
    }

    Process {

        id: pythonScript
        command: ["sh", "-c", "if [ -f backend/sync.py ]; then cd backend && uv run python sync.py --background; elif command -v waylandar-auth >/dev/null 2>&1; then waylandar-auth --background; else echo '{\"error\": \"Backend not found\"}'; fi"]
        running: true
        
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    let parsedData = JSON.parse(text);
                    let parsed = Array.isArray(parsedData) ? parsedData : (parsedData.events || []);
                    let calendars = Array.isArray(parsedData) ? [] : (parsedData.calendars || []);
                    let count = 0;
                    if (Object.keys(selectedCalendarIds).length > 0) {
                        for (let i=0; i<calendars.length; i++) {
                            if (selectedCalendarIds[calendars[i].id]) count++;
                        }
                    } else {
                        for (let i=0; i<calendars.length; i++) {
                            if (calendars[i].selected) count++;
                        }
                    }
                    calendarCount = count > 0 ? count : calendars.length;
                    
                    if (parsedData.error) {
                        authError = parsedData.error;
                        calendarEvents = [];
                        calendarCount = 0;
                        return;
                    }
                    
                    authError = "";
                    let now = new Date();
                    let todayStr = now.toDateString();
                    
                    let tomorrow = new Date(now);
                    tomorrow.setDate(tomorrow.getDate() + 1);
                    let tomorrowStr = tomorrow.toDateString();
                    
                    let filteredEvents = [];
                    for (let i = 0; i < parsed.length; i++) {
                        let isAllDay = parsed[i].start.length === 10;
                        let d = new Date(parsed[i].start);
                        
                        // Fix JS UTC-parsing bug: YYYY-MM-DD parses as UTC
                        if (isAllDay) {
                            let parts = parsed[i].start.split('-');
                            d = new Date(parts[0], parts[1] - 1, parts[2], 0, 0, 0);
                        }
                        
                        let endD = parsed[i].end ? new Date(parsed[i].end) : d;
                        if (parsed[i].end && parsed[i].end.length === 10) {
                            let parts = parsed[i].end.split('-');
                            endD = new Date(parts[0], parts[1] - 1, parts[2], 23, 59, 59);
                        }
                        

                        // Filter out unselected calendars
                        if (parsed[i].calendar_id && Object.keys(selectedCalendarIds).length > 0 && !selectedCalendarIds[parsed[i].calendar_id]) {
                            continue;
                        }

                        // The backend fetches the whole month, but the widget only shows UPCOMING events!

                        if (d < now && endD < now) {
                            continue;
                        }
                        
                        let dStr = d.toDateString();
                        
                        if (dStr === todayStr) {
                            parsed[i].sectionTitle = "Today";
                        } else if (dStr === tomorrowStr) {
                            parsed[i].sectionTitle = "Tomorrow";
                        } else {
                            parsed[i].sectionTitle = d.toLocaleDateString(Qt.locale("en_US"), "dddd, MMM d");
                        }
                        
                        parsed[i].notified_for = [];
                        filteredEvents.push(parsed[i]);
                    }
                    
                    calendarEvents = filteredEvents;
                } catch(e) {
                    console.log("Failed to parse JSON.");
                }
            }
        }
    }

    // Silent background process to trigger system notifications!
    Process {
        id: notifyProcess
        command: []
        
        function sendNotification(title, body) {
            command = ["notify-send", "-a", "Waylandar", "-i", "calendar", title, body];
            running = true;
        }
    }

    PanelWindow {
        id: calendarWindow
        WlrLayershell.layer: WlrLayer.Bottom
        
        anchors {
            top: true
            right: true
        }
        margins {
            top: 20
            right: 20
        }
        
        implicitWidth: 420
        implicitHeight: {
            if (authError !== "") {
                return 250;
            }
            if (calendarEvents.length === 0) {
                return pythonScript.running ? 250 : 180;
            }
            return Math.min(800, 130 + (calendarEvents.length * 75));
        }
        color: "transparent"
        
        // The Main Background
        Rectangle {
            anchors.fill: parent
            color: Theme.background
            radius: 20
            border.color: Theme.outline
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 30
                spacing: 20

                Item {
                    width: parent.width
                    height: 45

                    Column {
                        anchors.left: parent.left
                        anchors.right: countdownText.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        
                        Text {
                            text: "Upcoming Schedule"
                            font.pixelSize: 18
                            font.bold: true
                            font.family: "Inter"
                            color: Theme.colorOnBackground
                        }
                        
                        Text {
                            text: calendarCount > 0 ? calendarCount + " Active Calendars" : ""
                            font.pixelSize: 12
                            font.family: "Inter"
                            color: Theme.tertiary
                            visible: calendarCount > 0
                        }
                    }

                    // Countdown Text
                    Text {
                        id: countdownText
                        anchors.right: syncButton.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: pythonScript.running ? "" : "Syncs in " + minutesUntilSync + "m"
                        font.pixelSize: 12
                        font.italic: true
                        color: Theme.colorOnSurfaceVariant
                    }

                    Rectangle {
                        id: syncButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 50
                        height: 26
                        radius: 6
                        color: syncMouseArea.containsMouse ? Theme.surfaceVariant : Theme.surface
                        
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Sync"
                            font.pixelSize: 12
                            font.bold: true
                            font.family: "Inter"
                            color: pythonScript.running ? Theme.colorOnSurfaceVariant : Theme.primary
                        }

                        MouseArea {
                            id: syncMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!pythonScript.running) {
                                    minutesUntilSync = 60; // Reset countdown
                                    countdownTimer.restart(); 
                                    pythonScript.running = true; 
                                }
                            }
                        }
                    }
                }

                Timer {
                    id: countdownTimer
                    interval: 60000 // 1 minute
                    running: true
                    repeat: true
                    onTriggered: {
                        let now = new Date();
                        for (let i = 0; i < calendarEvents.length; i++) {
                            let event = calendarEvents[i];
                            let eventStart = new Date(event.start);
                            let diffMins = Math.floor((eventStart.getTime() - now.getTime()) / 60000);
                            
                            if (event.reminders && event.reminders.includes(diffMins) && !event.notified_for.includes(diffMins)) {
                                let timeStr = eventStart.toLocaleTimeString(Qt.locale("en_US"), "h:mm AP");
                                notifyProcess.sendNotification("󰃭 " + event.title, "Starts in " + diffMins + " minutes at " + timeStr);
                                event.notified_for.push(diffMins); // Mark this specific reminder as fired
                            }
                        }

                        if (minutesUntilSync > 0) {
                            minutesUntilSync--;
                        }
                        
                        if (minutesUntilSync <= 0) {
                            minutesUntilSync = 60; // Reset to 60 for the next hour
                            if (!pythonScript.running) {
                                pythonScript.running = true;
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                }

                Item {
                    width: parent.width
                    height: parent.height - 65

                    Components.CalendarList {
                        anchors.fill: parent
                        events: calendarEvents
                        errorMessage: authError
                        
                        // Fades the list out slightly while fetching new data
                        opacity: pythonScript.running ? 0.3 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                    }

                    // Custom Sleek Loading Spinner
                    Rectangle {
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        color: "transparent"
                        radius: 16
                        border.color: Theme.primary
                        border.width: 3
                        visible: pythonScript.running

                        // Creates the cutout for the spinner
                        Rectangle {
                            width: 16; height: 16; 
                            color: Theme.background // Matches background
                            anchors.top: parent.top; anchors.right: parent.right
                        }

                        // Spins it forever while loading!
                        RotationAnimation on rotation {
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 800
                            running: pythonScript.running
                        }
                    }
                }
            }
        }
    }
}
