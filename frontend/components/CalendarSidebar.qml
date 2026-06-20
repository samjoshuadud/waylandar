import QtQuick
import ".."

Item {
    id: root
    
    property var availableCalendars: []
    property var selectedCalendarIds: ({})
    property bool isFetching: false
    
    signal toggleCalendar(string calendarId)

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        
        Text {
            text: "Calendars"
            font.pixelSize: 24
            font.bold: true
            font.family: "Inter"
            color: Theme.colorOnBackground
        }
        
        ListView {
            width: parent.width
            height: parent.height - 40
            model: availableCalendars
            spacing: 12
            clip: true
            
            opacity: root.isFetching ? 0.3 : 1.0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            
            delegate: Row {
                spacing: 10
                width: parent.width
                
                Rectangle {
                    width: 18; height: 18; radius: 4
                    color: root.selectedCalendarIds[modelData.id] ? modelData.color : "transparent"
                    border.color: modelData.color
                    border.width: 2
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: Theme.background
                        visible: root.selectedCalendarIds[modelData.id] === true
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
                
                Text {
                    text: modelData.name
                    font.pixelSize: 13
                    font.family: "Inter"
                    color: Theme.colorOnBackground
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    width: parent.width - 28
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.toggleCalendar(modelData.id);
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
        opacity: root.isFetching ? 1.0 : 0.0
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
            running: root.isFetching
        }
    }
}
