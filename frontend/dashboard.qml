import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components" as Components

ShellRoot {
    property var calendarEvents: []
    property var activeEventDays: ({})
    property var monthDays: []
    property string currentMonthStr: ""

    // Generates the 42 cells for a visual calendar grid
    Component.onCompleted: {
        let now = new Date();
        let year = now.getFullYear();
        let month = now.getMonth();
        
        currentMonthStr = now.toLocaleDateString(Qt.locale("en_US"), "MMMM yyyy");
        
        let firstDay = new Date(year, month, 1);
        let lastDay = new Date(year, month + 1, 0);
        let startOffset = firstDay.getDay(); 
        
        let daysArray = [];
        for (let i = startOffset - 1; i >= 0; i--) {
            let d = new Date(year, month, -i);
            daysArray.push({ dayNum: d.getDate(), isCurrentMonth: false, dateStr: d.toDateString() });
        }
        for (let i = 1; i <= lastDay.getDate(); i++) {
            let d = new Date(year, month, i);
            daysArray.push({ dayNum: i, isCurrentMonth: true, dateStr: d.toDateString() });
        }
        let remaining = 42 - daysArray.length;
        for (let i = 1; i <= remaining; i++) {
            let d = new Date(year, month + 1, i);
            daysArray.push({ dayNum: i, isCurrentMonth: false, dateStr: d.toDateString() });
        }
        monthDays = daysArray;
    }

    Process {
        id: pythonScript
        workingDirectory: "/home/punisher/Documents/waylandar/backend"
        command: ["uv", "run", "fetch_calendar.py"]
        running: true
        
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(text);
                    let active = {};
                    let upcomingList = [];
                    
                    let now = new Date();
                    let todayStr = now.toDateString();
                    let tomorrow = new Date(now);
                    tomorrow.setDate(tomorrow.getDate() + 1);
                    let tomorrowStr = tomorrow.toDateString();

                    for (let i = 0; i < parsed.length; i++) {
                        let d = new Date(parsed[i].start);
                        let dStr = d.toDateString();
                        
                        active[dStr] = true;
                        
                        if (d >= now || (parsed[i].end && new Date(parsed[i].end) >= now) || dStr === todayStr) {
                            if (dStr === todayStr) {
                                parsed[i].sectionTitle = "Today";
                            } else if (dStr === tomorrowStr) {
                                parsed[i].sectionTitle = "Tomorrow";
                            } else {
                                parsed[i].sectionTitle = d.toLocaleDateString(Qt.locale("en_US"), "dddd, MMM d");
                            }
                            upcomingList.push(parsed[i]);
                        }
                    }
                    
                    calendarEvents = upcomingList;
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
                        
                        Text {
                            text: currentMonthStr // e.g. "June 2026"
                            font.pixelSize: 32
                            font.bold: true
                            font.family: "Inter"
                            color: "#cdd6f4"
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
                                
                                // Highlight today's date!
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
                                
                                // Event indicator dot!
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    color: "#89b4fa"
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: activeEventDays[modelData.dateStr] === true
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
                            text: "Agenda"
                            font.pixelSize: 24
                            font.bold: true
                            font.family: "Inter"
                            color: "#cdd6f4"
                        }
                        
                        // Re-using our modular widget list directly in the dashboard
                        Components.CalendarList {
                            width: parent.width
                            height: parent.height - 44
                            events: calendarEvents
                        }
                    }
                }
            }
        }
    }
}
