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
                    let parsed = JSON.parse(text);
                    calendarEvents = parsed;
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
        
        // anchor to all sides to make the window full screen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        
        // darkens the entire screen behind the dashboard
        color: Qt.rgba(0, 0, 0, 0.5)

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

                    Text {
                        text: "calendar visual grid will go here"
                        color: "#a6adc8"
                        font.pixelSize: 16
                        anchors.centerIn: parent
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

                    Text {
                        text: "detailed tasks will go here"
                        color: "#a6adc8"
                        font.pixelSize: 16
                        anchors.centerIn: parent
                    }
                }
            }
        }
    }
}
