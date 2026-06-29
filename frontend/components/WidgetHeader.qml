import QtQuick
import Quickshell
import ".."

Item {
    id: root
    width: parent.width
    height: 45
    
    property int calendarCount
    property int minutesUntilSync
    property bool isSyncing
    
    signal syncRequested()

    Column {
        anchors.left: parent.left
        anchors.right: countdownText.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        
        Text {
            width: parent.width
            text: "Upcoming Schedule"
            font.pixelSize: 18
            font.bold: true
            font.family: "Inter"
            color: Theme.colorOnBackground
            elide: Text.ElideRight
        }
        
        Text {
            width: parent.width
            text: root.calendarCount > 0 ? root.calendarCount + " Active Calendars" : ""
            font.pixelSize: 12
            font.family: "Inter"
            color: Theme.tertiary
            visible: root.calendarCount > 0
            elide: Text.ElideRight
        }
    }

    Text {
        id: countdownText
        anchors.right: syncButton.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.isSyncing ? "" : "Syncs in " + root.minutesUntilSync + "m"
        font.pixelSize: 12
        font.italic: true
        color: Theme.colorOnSurfaceVariant
        elide: Text.ElideRight
        visible: root.width > 280
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
            color: root.isSyncing ? Theme.colorOnSurfaceVariant : Theme.primary
        }

        MouseArea {
            id: syncMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.syncRequested()
        }
    }
}
