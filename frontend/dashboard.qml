import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components" as Components

ShellRoot {
    property var allEvents: []
    property string selectedDateStr: ""
    
    property int currentViewYear: new Date().getFullYear()
    property int currentViewMonth: new Date().getMonth()
    
    // Dynamically computes what shows up in the right pane
    property var displayedEvents: {
        if (selectedDateStr === "") {
            let now = new Date();
            // If viewing the CURRENT month, hide past events
            if (currentViewYear === now.getFullYear() && currentViewMonth === now.getMonth()) {
                let todayStr = now.toDateString();
                return allEvents.filter(function(e) {
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
                return allEvents;
            }
        } else {
            // Filtered: Exact selected date 
            return allEvents.filter(function(e) {
                return new Date(e.start).toDateString() === selectedDateStr;
            });
        }
    }
    
    property var activeEventDays: ({})
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

    Process {
        id: pythonScript
        // Pass the year and month down to python!
        command: ["sh", "-c", "if [ -f backend/sync.py ]; then cd backend && uv run python sync.py \"$1\" \"$2\" --background; elif command -v waylandar-auth >/dev/null 2>&1; then waylandar-auth \"$1\" \"$2\" --background; else echo '{\"error\": \"Backend not found\"}'; fi", "waylandar-auth", currentViewYear.toString(), (currentViewMonth + 1).toString()]
        running: true
        
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(text);
                    
                    if (parsed.error) {
                        authError = parsed.error;
                        allEvents = [];
                        activeEventDays = {};
                        isFetching = false;
                        return;
                    }
                    
                    authError = "";
                    let active = {};
                    
                    let now = new Date();
                    let todayStr = now.toDateString();
                    let tomorrow = new Date(now);
                    tomorrow.setDate(tomorrow.getDate() + 1);
                    let tomorrowStr = tomorrow.toDateString();

                    for (let i = 0; i < parsed.length; i++) {
                        let d = new Date(parsed[i].start);
                        let dStr = d.toDateString();
                        
                        active[dStr] = true;
                        
                        if (dStr === todayStr) {
                            parsed[i].sectionTitle = "Today";
                        } else if (dStr === tomorrowStr) {
                            parsed[i].sectionTitle = "Tomorrow";
                        } else {
                            parsed[i].sectionTitle = d.toLocaleDateString(Qt.locale("en_US"), "dddd, MMM d");
                        }
                    }
                    
                    allEvents = parsed;
                    activeEventDays = active;
                    
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
            width: 1000
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

                // left pane for the visual calendar grid
                Item {
                    width: parent.width * 0.6 - 30
                    height: parent.height

                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 20
                        
                        Row {
                            spacing: 20
                            anchors.horizontalCenter: parent.horizontalCenter
                            
                            // Previous Month Button
                            Rectangle {
                                width: 32; height: 32; radius: 16
                                color: prevMouseArea.containsMouse ? Theme.outline : "transparent"
                                Text { text: "◀"; anchors.centerIn: parent; color: Theme.primary; font.pixelSize: 14 }
                                MouseArea {
                                    id: prevMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        currentViewMonth--;
                                        if (currentViewMonth < 0) { currentViewMonth = 11; currentViewYear--; }
                                        pythonScript.running = true;
                                    }
                                }
                            }
                            
                            Text {
                                text: currentMonthStr // e.g. "June 2026"
                                font.pixelSize: 28
                                font.bold: true
                                font.family: "Inter"
                                color: Theme.colorOnBackground
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            // Next Month Button
                            Rectangle {
                                width: 32; height: 32; radius: 16
                                color: nextMouseArea.containsMouse ? Theme.outline : "transparent"
                                Text { text: "▶"; anchors.centerIn: parent; color: Theme.primary; font.pixelSize: 14 }
                                MouseArea {
                                    id: nextMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        currentViewMonth++;
                                        if (currentViewMonth > 11) { currentViewMonth = 0; currentViewYear++; }
                                        pythonScript.running = true;
                                    }
                                }
                            }
                        }
                        
                        Row {
                            width: parent.width
                            spacing: 0
                            Repeater {
                                model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                                Text {
                                    width: parent.width / 7
                                    text: modelData
                                    font.pixelSize: 14
                                    font.bold: true
                                    font.family: "Inter"
                                    color: Theme.primary
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                        
                        // The actual 7x6 month grid
                        GridView {
                            id: calGrid
                            width: parent.width
                            height: parent.height - 100
                            cellWidth: width / 7
                            cellHeight: height / 6
                            model: monthDays
                            interactive: false
                            
                            // Dim the grid when fetching
                            opacity: isFetching ? 0.3 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                            
                            delegate: Rectangle {
                                width: calGrid.cellWidth - 10
                                height: calGrid.cellHeight - 10
                                
                                color: modelData.isCurrentMonth ? Theme.outline : Theme.surface
                                radius: 12
                                
                                // Dim all unselected days, but less aggressively (from 0.3 up to 0.5)
                                opacity: selectedDateStr === "" || selectedDateStr === modelData.dateStr ? 1.0 : 0.5
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                
                                border.color: modelData.dateStr === new Date().toDateString() ? Theme.tertiary : "transparent"
                                border.width: 2
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.dayNum
                                    font.pixelSize: 18
                                    font.family: "Inter"
                                    font.bold: modelData.dateStr === new Date().toDateString()
                                    // Text color is more solid now
                                    color: modelData.isCurrentMonth ? Theme.colorOnBackground : Theme.colorOnSurfaceVariant
                                }
                                
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    color: Theme.primary
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: activeEventDays[modelData.dateStr] === true
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (selectedDateStr === modelData.dateStr) {
                                            selectedDateStr = ""; 
                                        } else {
                                            selectedDateStr = modelData.dateStr; 
                                        }
                                    }
                                }
                            }
                        }
                        
                    }
                    
                    // Custom Sleek Loading Spinner for Left Pane
                    Rectangle {
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        color: "transparent"
                        radius: 16
                        border.color: Theme.primary
                        border.width: 3
                        visible: opacity > 0
                        opacity: isFetching ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        Rectangle {
                            width: 16; height: 16; 
                            color: Theme.background
                            anchors.top: parent.top; anchors.right: parent.right
                        }

                        RotationAnimation on rotation {
                            loops: Animation.Infinite
                            from: 0; to: 360
                            duration: 800
                            running: isFetching
                        }
                    }
                }

                // vertical divider line
                Rectangle {
                    width: 1
                    height: parent.height
                    color: Theme.outline
                }

                // right pane for the agenda tasks
                Item {
                    width: parent.width * 0.4 - 31 
                    height: parent.height

                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 20
                        
                        Text {
                            id: agendaTitle
                            // Automatically changes the title if a day is selected
                            text: selectedDateStr === "" ? "Agenda" : "Agenda - " + new Date(selectedDateStr).toLocaleDateString(Qt.locale("en_US"), "ddd, MMM d")
                            font.pixelSize: 24
                            font.bold: true
                            font.family: "Inter"
                            color: Theme.colorOnBackground
                        }
                        
                        // Re-using our modular widget list directly in the dashboard
                        Components.CalendarList {
                            id: rightAgendaList
                            width: parent.width
                            height: parent.height - agendaTitle.height - 20
                            events: displayedEvents
                            errorMessage: authError
                            
                            // Dim the agenda list when fetching
                            opacity: isFetching ? 0.3 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                        }
                        
                    }
                    
                    // Custom Sleek Loading Spinner for Right Pane
                    Rectangle {
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        color: "transparent"
                        radius: 16
                        border.color: Theme.primary
                        border.width: 3
                        visible: opacity > 0
                        opacity: isFetching ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        Rectangle {
                            width: 16; height: 16; 
                            color: Theme.background
                            anchors.top: parent.top; anchors.right: parent.right
                        }

                        RotationAnimation on rotation {
                            loops: Animation.Infinite
                            from: 0; to: 360
                            duration: 800
                            running: isFetching
                        }
                    }
                }
            }
        }
    }
}
