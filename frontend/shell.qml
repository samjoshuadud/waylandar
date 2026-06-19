import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components" as Components

ShellRoot {
    property var calendarEvents: []
    property int minutesUntilSync: 60

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
                        
                        // Add a flag so we don't spam notifications
                        parsed[i].notified = false;
                    }
                    
                    calendarEvents = parsed;
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
        
        width: 420
        height: Math.min(800, 100 + (calendarEvents.length * 75))
        color: "transparent"
        
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        
        // The Main Background
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(5/255, 5/255, 12/255, 0.92)
            radius: 20
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 15

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
                        color: "#cdd6f4"
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
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.4)
                    }

                    Rectangle {
                        id: syncButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 50
                        height: 26
                        radius: 6
                        color: syncMouseArea.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.15) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                        
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Sync"
                            font.pixelSize: 12
                            font.bold: true
                            font.family: "Inter"
                            color: pythonScript.running ? "#a6adc8" : "#89b4fa"
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
                            
                            if (diffMins === 10 && !event.notified) {
                                let timeStr = eventStart.toLocaleTimeString(Qt.locale("en_US"), "h:mm AP");
                                notifyProcess.sendNotification("Upcoming: " + event.title, "Starts at " + timeStr);
                                event.notified = true; // Mark as notified so we don't spam
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
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.1)
                }

                Item {
                    width: parent.width
                    height: parent.height - 50

                    Components.CalendarList {
                        anchors.fill: parent
                        events: calendarEvents
                        
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
                        border.color: "#89b4fa"
                        border.width: 3
                        visible: pythonScript.running

                        // Creates the cutout for the spinner
                        Rectangle {
                            width: 16; height: 16; 
                            color: Qt.rgba(5/255, 5/255, 12/255, 1) // Matches background
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
            
            Text {
                visible: calendarEvents.length === 0 && !pythonScript.running
                text: "Your schedule is clear! 󰄬"
                font.pixelSize: 14
                font.italic: true
                color: "#a6adc8"
                anchors.centerIn: parent
            }
        }
    }
}
