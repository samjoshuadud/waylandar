import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components" as Components

ShellRoot {
    id: shellRoot
    property var allEvents: []
    property string selectedDateStr: ""
    
    property int currentViewYear: new Date().getFullYear()
    property int currentViewMonth: new Date().getMonth()
    
property var availableCalendars: []
    property var selectedCalendarIds: ({})
    
    // Dynamically computes what shows up in the right pane
    property var displayedEvents: {
        let evs = allEvents.filter(e => !e.calendar_id || selectedCalendarIds[e.calendar_id] === true);
        
        if (selectedDateStr === "") {
            let now = new Date();
            // If viewing the CURRENT month, hide past events
            if (currentViewYear === now.getFullYear() && currentViewMonth === now.getMonth()) {
                let todayStr = now.toDateString();
                return evs.filter(function(e) {
                    let isAllDay = e.start.length === 10;
                    let d = new Date(e.start);
                    if (isAllDay) {
                        let parts = e.start.split('-');
                        d = new Date(parts[0], parts[1] - 1, parts[2], 0, 0, 0);
                    }
                    
                    let endD = e.end ? new Date(e.end) : d;
                    if (e.end && e.end.length === 10) {
                        let parts = e.end.split('-');
                        endD = new Date(parts[0], parts[1] - 1, parts[2], 23, 59, 59);
                    }
                    
                    return d >= now || endD >= now || d.toDateString() === todayStr;
                });
            } else {
                return evs;
            }
        } else {
            // Filtered: Exact selected date 
            return evs.filter(function(e) {
                return new Date(e.start).toDateString() === selectedDateStr;
            });
        }
    }
    
    property var activeEventDays: {
        let active = {};
        for (let i = 0; i < allEvents.length; i++) {
            let e = allEvents[i];
            if (e.calendar_id && !selectedCalendarIds[e.calendar_id]) continue;
            active[new Date(e.start).toDateString()] = true;
        }
        return active;
    }
    property var monthDays: []
    property string currentMonthStr: ""
    property string authError: ""
    
    // Tracks when the python script is pulling data
    property bool isFetching: true

    // Generates the 42 cells for the visual calendar grid
    function updateMonthGrid() {
        let year = currentViewYear;
        let month = currentViewMonth;
        
        let d = new Date(year, month, 1);
        currentMonthStr = d.toLocaleDateString(Qt.locale("en_US"), "MMMM yyyy");
        
        let lastDay = new Date(year, month + 1, 0);
        let startOffset = d.getDay(); 
        
        let daysArray = [];
        for (let i = startOffset - 1; i >= 0; i--) {
            let pd = new Date(year, month, -i);
            daysArray.push({ dayNum: pd.getDate(), isCurrentMonth: false, dateStr: pd.toDateString() });
        }
        for (let i = 1; i <= lastDay.getDate(); i++) {
            let cd = new Date(year, month, i);
            daysArray.push({ dayNum: i, isCurrentMonth: true, dateStr: cd.toDateString() });
        }
        let remaining = 42 - daysArray.length;
        for (let i = 1; i <= remaining; i++) {
            let nd = new Date(year, month + 1, i);
            daysArray.push({ dayNum: i, isCurrentMonth: false, dateStr: nd.toDateString() });
        }
        monthDays = daysArray;
        
        // Clear selection when changing months!
        selectedDateStr = "";
        
        // Trigger loading state
        isFetching = true;
    }

    Component.onCompleted: updateMonthGrid()
    onCurrentViewMonthChanged: updateMonthGrid()
    onCurrentViewYearChanged: updateMonthGrid()


    property string activeProvider: "google" 

    FileView {
        id: configFileWatcher
        path: Quickshell.env("HOME") + "/.config/waylandar/config.json"
        
        onTextChanged: {
            let content = configFileWatcher.text();
            if (content.trim() !== "") {
                try {
                    let parsed = JSON.parse(content);
                    if (parsed.active_provider) {
                        activeProvider = parsed.active_provider;
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            configFileWatcher.reload();
        }
    }

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
        id: saveSelectedCals
        property string payload: ""
        command: ["sh", "-c", "mkdir -p ~/.cache/waylandar && echo \"$1\" > ~/.cache/waylandar/selected_cals.json", "sh", payload]
    }

    Timer {
        id: saveDebounceTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (saveSelectedCals.running) {
                saveDebounceTimer.start();
            } else {
                saveSelectedCals.running = true;
            }
        }
    }

    Process {

        id: pythonScript
        // Pass the year and month down to python!
        command: ["sh", "-c", "if [ -f backend/sync.py ]; then cd backend && uv run python sync.py \"$1\" \"$2\" --background; elif command -v waylandar >/dev/null 2>&1; then waylandar \"$1\" \"$2\" --background; else echo '{\"error\": \"Backend not found\"}'; fi", "waylandar", currentViewYear.toString(), (currentViewMonth + 1).toString()]
        running: true
        
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    let parsedData = JSON.parse(text);
                    let parsed = Array.isArray(parsedData) ? parsedData : (parsedData.events || []);
                    
let calendars = Array.isArray(parsedData) ? [] : (parsedData.calendars || []);
                    availableCalendars = calendars;
                    
                    let sel = Object.assign({}, selectedCalendarIds);
                    let hasSelected = false;
                    for (let i=0; i<calendars.length; i++) {
                        if (sel[calendars[i].id]) {
                            hasSelected = true;
                            break;
                        }
                    }
                    
                    if (!hasSelected && calendars.length > 0) {
                        for (let i=0; i<calendars.length; i++) {
                            if (calendars[i].selected !== false) {
                                sel[calendars[i].id] = true;
                            }
                        }
                        selectedCalendarIds = sel;
                    }
                    
                    if (parsedData.error) {
                        authError = parsedData.error;
                        allEvents = [];
                        isFetching = false;
                        return;
                    }
                    
                    authError = "";
                    
                    let now = new Date();
                    let todayStr = now.toDateString();
                    let tomorrow = new Date(now);
                    tomorrow.setDate(tomorrow.getDate() + 1);
                    let tomorrowStr = tomorrow.toDateString();

                    for (let i = 0; i < parsed.length; i++) {
                        let d = new Date(parsed[i].start);
                        let dStr = d.toDateString();
                        
                        if (dStr === todayStr) {
                            parsed[i].sectionTitle = "Today";
                        } else if (dStr === tomorrowStr) {
                            parsed[i].sectionTitle = "Tomorrow";
                        } else {
                            parsed[i].sectionTitle = d.toLocaleDateString(Qt.locale("en_US"), "dddd, MMM d");
                        }
                    }
                    
                    allEvents = parsed;
                    
                    // Finished loading!
                    isFetching = false;
                } catch(e) {
                    console.log("Failed to parse JSON");
                    isFetching = false;
                }
            }
        }
    }

    PanelWindow {
        id: dashboardWindow
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        
        // A fully transparent window layer so Hyprland accepts the overlay
        color: "transparent"

        // clicking the background closes the overlay
        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
        }

        // handle escape key to close
        Item {
            focus: true
            Keys.onEscapePressed: Qt.quit()
        }

        // the main centered dashboard
        Rectangle {
            // Reverted back to the stable fixed sizing
            width: 1250
            height: 700
            anchors.centerIn: parent
            color: Theme.background
            radius: 20
            border.color: Theme.outline
            border.width: 1
            clip: true

            // pop-in animation
            scale: 0.8
            opacity: 0.0
            
            NumberAnimation on scale {
                to: 1.0
                duration: 400
                easing.type: Easing.OutBack
                easing.overshoot: 1.1
            }
            
            NumberAnimation on opacity {
                to: 1.0
                duration: 300
                easing.type: Easing.OutCubic
            }

            // catch clicks so they dont pass through to the background and close the window
            MouseArea {
                anchors.fill: parent
            }
            
            Row {
                anchors.fill: parent
                anchors.margins: 30
                spacing: 30

                readonly property real overhead: spacing * 4 + 1 * 2
                readonly property real contentWidth: width - overhead


                // FAR LEFT: Calendars Sidebar
                Components.CalendarSidebar {
                    width: parent.contentWidth * 0.15
                    height: parent.height
                    
                    availableCalendars: shellRoot.availableCalendars
                    selectedCalendarIds: shellRoot.selectedCalendarIds
                    isFetching: shellRoot.isFetching
                    activeProvider: shellRoot.activeProvider
                    
                    onToggleCalendar: function(calendarId) {
                        let sel = Object.assign({}, shellRoot.selectedCalendarIds);
                        if (sel[calendarId]) {
                            delete sel[calendarId];
                        } else {
                            sel[calendarId] = true;
                        }
                        shellRoot.selectedCalendarIds = sel;
                        
                        saveSelectedCals.payload = JSON.stringify(sel);
                        saveDebounceTimer.restart();
                    }
                }

                Rectangle { width: 1; height: parent.height; color: Theme.outline }

                // left pane for the visual calendar grid
                Components.CalendarGridPane {
                    width: parent.contentWidth * 0.5
                    height: parent.height
                    
                    currentViewMonth: shellRoot.currentViewMonth
                    currentViewYear: shellRoot.currentViewYear
                    currentMonthStr: shellRoot.currentMonthStr
                    monthDays: shellRoot.monthDays
                    activeEventDays: shellRoot.activeEventDays
                    selectedDateStr: shellRoot.selectedDateStr
                    isFetching: shellRoot.isFetching
                    
                    onChangeMonth: function(offset) {
                        shellRoot.currentViewMonth += offset;
                        if (shellRoot.currentViewMonth < 0) { 
                            shellRoot.currentViewMonth = 11; 
                            shellRoot.currentViewYear--; 
                        } else if (shellRoot.currentViewMonth > 11) { 
                            shellRoot.currentViewMonth = 0; 
                            shellRoot.currentViewYear++; 
                        }
                        pythonScript.running = true;
                    }
                    
                    onDateSelected: function(dateStr) {
                        shellRoot.selectedDateStr = dateStr;
                    }
                }

                // vertical divider line
                Rectangle {
                    width: 1
                    height: parent.height
                    color: Theme.outline
                }

                // right pane for the agenda tasks
                Components.AgendaListPane {
                    width: parent.contentWidth * 0.35
                    height: parent.height
                    
                    selectedDateStr: shellRoot.selectedDateStr
                    displayedEvents: shellRoot.displayedEvents
                    authError: shellRoot.authError
                    isFetching: shellRoot.isFetching
                }
            }
        }
    }
}
