import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components" as Components

ShellRoot {
    property var calendarEvents: []
    property int minutesUntilSync: 60
    property string authError: ""

    Process {
        id: pythonScript
        command: ["waylandar-auth", "--background"]
        running: true
        
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(text);
                    
                    if (parsed.error) {
                        authError = parsed.error;
                        calendarEvents = [];
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
                        let d = new Date(parsed[i].start);
                        
                        // The backend fetches the whole month, but the widget only shows UPCOMING events!
                        if (d < now && parsed[i].end && new Date(parsed[i].end) < now) {
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
                    height: 24

                    Text {
                        anchors.left: parent.left
                        anchors.right: countdownText.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Upcoming Schedule"
                        font.pixelSize: 18
                        font.bold: true
                        font.family: "Inter"
                        color: Theme.colorOnBackground
                        elide: Text.ElideRight
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
