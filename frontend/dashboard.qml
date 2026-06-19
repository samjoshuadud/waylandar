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
                    let d = new Date(e.start);
                    return d >= now || (e.end && new Date(e.end) >= now) || d.toDateString() === todayStr;
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
        
        // Clear selection when changing months
        selectedDateStr = "";
    }

    Component.onCompleted: updateMonthGrid()
    onCurrentViewMonthChanged: updateMonthGrid()
    onCurrentViewYearChanged: updateMonthGrid()

    Process {
        id: pythonScript
        workingDirectory: "/home/punisher/Documents/waylandar/backend"
        // Pass the year and month down to python!
        command: ["uv", "run", "fetch_calendar.py", currentViewYear.toString(), (currentViewMonth + 1).toString()]
        running: true
        
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(text);
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
                } catch(e) {
                    console.log("Failed to parse JSON");
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
        
        // darkens the entire screen behind the dashboard
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
            width: 1000
            height: 700
            anchors.centerIn: parent
            color: Qt.rgba(5/255, 5/255, 12/255, 0.95)
            radius: 20
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.1)
            border.width: 1

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
                    width: parent.width * 0.6
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
                                color: prevMouseArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.1) : "transparent"
                                Text { text: "◀"; anchors.centerIn: parent; color: "#89b4fa"; font.pixelSize: 14 }
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
                                color: "#cdd6f4"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            // Next Month Button
                            Rectangle {
                                width: 32; height: 32; radius: 16
                                color: nextMouseArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.1) : "transparent"
                                Text { text: "▶"; anchors.centerIn: parent; color: "#89b4fa"; font.pixelSize: 14 }
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
                                    color: "#89b4fa"
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                        
                        // The actual 7x6 month grid!
                        GridView {
                            id: calGrid
                            width: parent.width
                            height: parent.height - 100
                            cellWidth: width / 7
                            cellHeight: height / 6
                            model: monthDays
                            interactive: false // Lock scrolling so it stays perfectly shaped
                            
                            delegate: Rectangle {
                                width: calGrid.cellWidth - 10
                                height: calGrid.cellHeight - 10
                                color: modelData.isCurrentMonth ? Qt.rgba(255/255, 255/255, 255/255, 0.05) : "transparent"
                                radius: 12
                                
                                // Dim all unselected days to make the clicked one stand out!
                                opacity: selectedDateStr === "" || selectedDateStr === modelData.dateStr ? 1.0 : 0.3
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                
                                border.color: modelData.dateStr === new Date().toDateString() ? "#f38ba8" : "transparent"
                                border.width: 2
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.dayNum
                                    font.pixelSize: 18
                                    font.family: "Inter"
                                    font.bold: modelData.dateStr === new Date().toDateString()
                                    color: modelData.isCurrentMonth ? "#cdd6f4" : "#45475a"
                                }
                                
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    color: "#89b4fa"
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: activeEventDays[modelData.dateStr] === true
                                }
                                
                                // Click to select/unselect the day
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (selectedDateStr === modelData.dateStr) {
                                            selectedDateStr = ""; // unpress
                                        } else {
                                            selectedDateStr = modelData.dateStr; // press
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // vertical divider line
                Rectangle {
                    width: 1
                    height: parent.height
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.1)
                }

                // right pane for the agenda tasks
                Item {
                    width: parent.width * 0.4 - 31 
                    height: parent.height

                    Column {
                        anchors.fill: parent
                        spacing: 20
                        
                        Text {
                            // Automatically changes the title if a day is selected
                            text: selectedDateStr === "" ? "Agenda" : "Agenda - " + new Date(selectedDateStr).toLocaleDateString(Qt.locale("en_US"), "ddd, MMM d")
                            font.pixelSize: 24
                            font.bold: true
                            font.family: "Inter"
                            color: "#cdd6f4"
                        }
                        
                        // Re-using our modular widget list directly in the dashboard
                        Components.CalendarList {
                            width: parent.width
                            height: parent.height - 44
                            events: displayedEvents
                        }
                    }
                }
            }
        }
    }
}
