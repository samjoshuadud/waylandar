import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components" as Components

ShellRoot {
property var allRawEvents: []
    property var allRawCalendars: []
    
    property int calendarCount: {
        let count = 0;
        if (Object.keys(selectedCalendarIds).length > 0) {
            for (let i=0; i<allRawCalendars.length; i++) {
                if (selectedCalendarIds[allRawCalendars[i].id]) count++;
            }
        } else {
            for (let i=0; i<allRawCalendars.length; i++) {
                if (allRawCalendars[i].selected) count++;
            }
        }
        return count > 0 ? count : allRawCalendars.length;
    }

    property var calendarEvents: {
        let filtered = [];
        let now = new Date();
        let todayStr = now.toDateString();
        let tomorrow = new Date(now);
        tomorrow.setDate(tomorrow.getDate() + 1);
        let tomorrowStr = tomorrow.toDateString();

        for (let i = 0; i < allRawEvents.length; i++) {
            let ev = Object.assign({}, allRawEvents[i]); // copy to avoid mutation sharing issues
            
            if (ev.calendar_id && Object.keys(selectedCalendarIds).length > 0 && !selectedCalendarIds[ev.calendar_id]) {
                continue;
            }
            
            let isAllDay = ev.start.length === 10;
            let d = new Date(ev.start);
            
            if (isAllDay) {
                let parts = ev.start.split('-');
                d = new Date(parts[0], parts[1] - 1, parts[2], 0, 0, 0);
            }
            
            let endD = ev.end ? new Date(ev.end) : d;
            if (ev.end && ev.end.length === 10) {
                let parts = ev.end.split('-');
                endD = new Date(parts[0], parts[1] - 1, parts[2], 23, 59, 59);
            }
            
            if (d < now && endD < now) {
                continue;
            }
            
            let dStr = d.toDateString();
            if (dStr === todayStr) {
                ev.sectionTitle = "Today";
            } else if (dStr === tomorrowStr) {
                ev.sectionTitle = "Tomorrow";
            } else {
                ev.sectionTitle = d.toLocaleDateString(Qt.locale("en_US"), "dddd, MMM d");
            }
            
            filtered.push(ev);
        }
        return filtered;
    }

    property string authError: ""
    property var selectedCalendarIds: ({})
    property int minutesUntilSync: 60

    FileView {
        id: selectedCalsFile
        path: Quickshell.env("HOME") + "/.cache/waylandar/selected_cals.json"
        watchChanges: true
        
        function syncCals() {
            let fileContent = selectedCalsFile.text();
            if (fileContent.trim() !== "") {
                try {
                    selectedCalendarIds = JSON.parse(fileContent);
                } catch(e) {}
            }
        }
        
        onLoaded: syncCals()
        onFileChanged: syncCals()
    }

    FileView {
        id: configFileWatcher
        path: Quickshell.env("HOME") + "/.config/waylandar/config.json"
        watchChanges: true
        
        onFileChanged: {
            // When config changes (e.g. provider is switched), trigger a background sync!
            if (!pythonScript.running) {
                minutesUntilSync = 60; // Reset countdown
                countdownTimer.restart(); 
                pythonScript.running = true;
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
                    if (parsedData.error) {
                        authError = parsedData.error;
                        allRawEvents = [];
                        allRawCalendars = [];
                        return;
                    }
                    
                    authError = "";
                    allRawEvents = Array.isArray(parsedData) ? parsedData : (parsedData.events || []);
                    allRawCalendars = Array.isArray(parsedData) ? [] : (parsedData.calendars || []);
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
        property real chromeHeight: 45 + 1 + 60 + 40  

        implicitHeight: {
            if (authError !== "") {
                return 250;
            }
            if (calendarEvents.length === 0) {
                return pythonScript.running ? 250 : 180;
            }
            return Math.min(800, chromeHeight + calendarList.contentHeight);
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
                        id: calendarList
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
