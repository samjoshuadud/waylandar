import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

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
            color: Qt.rgba(17/255, 17/255, 27/255, 0.75) 
            radius: 20
            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 15

                Row {
                    spacing: 12
                    Text {
                        text: "Upcoming Schedule"
                        font.pixelSize: 18
                        font.bold: true
                        font.family: "Inter"
                        color: "#cdd6f4" // Soft white
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.1)
                }

                ListView {
                    id: eventList
                    width: parent.width
                    height: parent.height - 50
                    model: calendarEvents
                    spacing: 10
                    clip: true

                    delegate: Rectangle {
                        width: eventList.width
                        height: 65
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.04) // Very subtle highlight
                        radius: 12
                        
                        Row {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 15

                            Rectangle {
                                width: 4
                                height: parent.height
                                radius: 2
                                color: "#f38ba8" // Red accent
                            }

                            Column {
                                spacing: 4
                                width: parent.width - 30

                                Text {
                                    text: modelData.title
                                    font.pixelSize: 14
                                    font.bold: true
                                    font.family: "Inter"
                                    color: "#cdd6f4"
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    text: {
                                        var d = new Date(modelData.start);
                                        return d.toLocaleDateString(Qt.locale(), "ddd MMM d") + " at " + d.toLocaleTimeString(Qt.locale(), "h:mm AP");
                                    }
                                    font.pixelSize: 12
                                    font.family: "Inter"
                                    color: "#a6adc8"
                                }
                            }
                        }
                    }
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
