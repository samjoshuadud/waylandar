import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components" as Components

ShellRoot {
    id: shellRoot
    property var allRawEvents: []
    property var allRawCalendars: []
    property var currentTime: new Date()
    
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
        let now = currentTime;
        let todayStr = now.toDateString();
        let tomorrow = new Date(now);
        tomorrow.setDate(tomorrow.getDate() + 1);
        let tomorrowStr = tomorrow.toDateString();

        for (let i = 0; i < allRawEvents.length; i++) {
            if (!allRawEvents[i].notified_for) {
                allRawEvents[i].notified_for = [];
            }
            let ev = Object.assign({}, allRawEvents[i]); // copy to avoid mutation sharing issues
            ev.notified_for = allRawEvents[i].notified_for; // Reference the same array so timer mutations persist
            
            if (ev.calendar_id && Object.keys(selectedCalendarIds).length > 0 && !selectedCalendarIds[ev.calendar_id]) {
                continue;
            }
            
            if (ev.account_id && enabledAccountIds[ev.account_id] !== true) {
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
    property var enabledAccountIds: ({})
    property int syncInterval: 60
    property int minutesUntilSync: 60

    FileView {
        id: selectedCalsFile
        path: Quickshell.env("HOME") + "/.cache/waylandar/selected_cals.json"
        
        onTextChanged: {
            let fileContent = selectedCalsFile.text();
            if (fileContent.trim() !== "") {
                try {
                    selectedCalendarIds = JSON.parse(fileContent);
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            selectedCalsFile.reload();
        }
    }

    FileView {
        id: configFileWatcher
        path: Quickshell.env("HOME") + "/.config/waylandar/config.json"
        
        onTextChanged: {
            let content = text();
            if (content) {
                try {
                    let cfg = JSON.parse(content);
                    if (cfg.sync_interval !== undefined && cfg.sync_interval !== syncInterval) {
                        syncInterval = cfg.sync_interval;
                    }
                    
                    let enabled = {};
                    let providers = cfg.providers || {};
                    for (let p in providers) {
                        let providerEnabled = providers[p].enabled !== false;
                        if (providerEnabled) {
                            enabled[p] = true;
                        }
                        
                        let accounts = providers[p].accounts || [];
                        for (let i = 0; i < accounts.length; i++) {
                            if (accounts[i].enabled !== false && providerEnabled) {
                                enabled[accounts[i].id] = true;
                            }
                        }
                    }
                    enabledAccountIds = enabled;
                } catch(e) {}
            }
            if (!pythonScript.running) {
                minutesUntilSync = syncInterval; // Reset countdown
                countdownTimer.restart(); 
                pythonScript.running = true;
            }
        }
    }

    function loadSyncData(parsedData) {
        if (parsedData.error) {
            authError = parsedData.error;
            allRawEvents = [];
            allRawCalendars = [];
            return;
        } else if (parsedData.errors && parsedData.errors.length > 0) {
            authError = parsedData.errors.join("\n");
        } else {
            authError = "";
        }
        allRawEvents = Array.isArray(parsedData) ? parsedData : (parsedData.events || []);
        allRawCalendars = Array.isArray(parsedData) ? [] : (parsedData.calendars || []);
        
        // Auto-select fallback for new providers
        let sel = Object.assign({}, selectedCalendarIds);
        let hasSelected = false;
        for (let i = 0; i < allRawCalendars.length; i++) {
            if (sel[allRawCalendars[i].id]) {
                hasSelected = true;
                break;
            }
        }
        
        if (!hasSelected && allRawCalendars.length > 0) {
            for (let i = 0; i < allRawCalendars.length; i++) {
                if (allRawCalendars[i].selected !== false) {
                    sel[allRawCalendars[i].id] = true;
                }
            }
            selectedCalendarIds = sel;
        }
    }

    FileView {
        id: cacheLoader
        path: Quickshell.env("HOME") + "/.cache/waylandar/cache_current_current.json"
        
        onTextChanged: {
            let content = text();
            if (content.trim() !== "") {
                try {
                    let parsedData = JSON.parse(content);
                    loadSyncData(parsedData);
                } catch (e) {}
            }
        }
    }

    Timer {
        id: configReloadTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            configFileWatcher.reload();
            if (typeof cacheLoader !== "undefined") {
                cacheLoader.reload();
            }
        }
    }

    Process {

        id: pythonScript
        command: ["sh", "-c", "if [ -f backend/sync.py ]; then cd backend && uv run python sync.py --background; elif command -v waylandar >/dev/null 2>&1; then waylandar --background; else echo '{\"error\": \"Backend not found\"}'; fi"]
        running: true
        
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    let parsedData = JSON.parse(text);
                    loadSyncData(parsedData);
                } catch(e) {
                    console.log("Failed to parse JSON.");
                }
            }
        }
    }

    Process {
        id: notifyProcess
        property var queue: []
        command: []
        
        onExited: {
            if (queue.length > 0) {
                let nextCmd = queue.shift();
                command = nextCmd;
                running = true;
            }
        }
        
        function sendNotification(title, body) {
            let cmd = ["notify-send", "-a", "Waylandar", "-i", "calendar", title, body];
            if (running) {
                queue.push(cmd);
            } else {
                command = cmd;
                running = true;
            }
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
        
        implicitWidth: Math.max(360, Math.min(480, Screen.width * 0.22))
        property real chromeHeight: 45 + 1 + 60 + 40  

        implicitHeight: Math.max(450, Math.min(800, Screen.height * 0.65))
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

                Components.WidgetHeader {
                    calendarCount: shellRoot.calendarCount // Referring to the property on ShellRoot
                    minutesUntilSync: shellRoot.minutesUntilSync
                    isSyncing: pythonScript.running
                    
                    onSyncRequested: {
                        if (!pythonScript.running) {
                            shellRoot.minutesUntilSync = shellRoot.syncInterval; // Reset countdown
                            countdownTimer.restart();
                            pythonScript.running = true; 
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
                        shellRoot.currentTime = now;
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
                            minutesUntilSync = syncInterval; // Reset to syncInterval for the next hour
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
                        isSyncing: pythonScript.running
                        
                        // Fades the list out slightly while fetching new data
                        opacity: pythonScript.running ? 0.3 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                    }

                    Components.LoadingSpinner {
                        active: pythonScript.running
                    }
                }
            }
        }
    }
}
