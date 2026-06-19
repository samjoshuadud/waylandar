import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components" as Components

ShellRoot {
    property var calendarEvents: []

    Process {
        id: pythonScript
        workingDirectory: "/home/punisher/Documents/waylandar/backend"
        command: ["uv", "run", "fetch_calendar.py"]
        running: true
        
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    calendarEvents = JSON.parse(text);
                } catch(e) {
                    console.log("Failed to parse JSON.");
                }
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
        
        width: 380
        height: Math.min(800, 100 + (calendarEvents.length * 75))
        color: "transparent"
        
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

                Text {
                    text: "Upcoming Schedule"
                    font.pixelSize: 18
                    font.bold: true
                    font.family: "Inter"
                    color: "#cdd6f4"
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.1)
                }

                Components.CalendarList {
                    width: parent.width
                    height: parent.height - 50
                    events: calendarEvents
                }
            }
            
            Text {
                visible: calendarEvents.length === 0
                text: "Your schedule is clear! 󰄬"
                font.pixelSize: 14
                font.italic: true
                color: "#a6adc8"
                anchors.centerIn: parent
            }
        }
    }
}
